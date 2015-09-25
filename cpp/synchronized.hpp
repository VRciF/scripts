/**
 * Usage guidance:
 *    Facts:
 *        o) For every synchronized(){} block a memory address (pointer value)
 *           is associated with a pthread_mutex_t and a reference counter
 *        o) IF synchronized(somevar){} is used on a simple variable,
 *           then it's address &somevar will be used
 *        o) IF ptrToSomevar=&somevar; synchronized(&somevar){} OR synchronized(ptrToSomevar) is used on a pointer,
 *           then the pointers address &somevar, the address of somevar, will be used
 *        o) IF ptrToSomevar=&somevar; synchronized(&ptrToSomevar){} is used THEN
 *           the variable ptrToSomevar gets locked! NOT somevar AND NOT &somevar
 *           this is because, synchronized(&ptrToSomevar){} receives a
 *           pointer to a pointer to somevar
 *
 * So keep in mind for a given variable, e.g. int somevar=0; then
 *   synchronized(somevar){} AND synchronized(&somevar){}
 * hold a lock an the exact same memory address,
 * but synchronized(&ptrToSomevar){} won't
 *
 * Design Pattern:
 *   to have a whole function synchronized like it's done in java with
 *   java: public synchronized void fooBar(){}
 *   you can use static member's like
 *   c++: void fooBar(){ Synchronized functionLock(__func__); }
 *
 * License:
java like synchronized(){} keyword for c++
Copyright (c) 2015, (VRciF, vrcif0@gmail.com). All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3.0 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library.
* 
* 
* Full license: http://www.gnu.org/licenses/lgpl-3.0.txt
 */
#ifndef __SYNCHRONIZED_HPP__
#define __SYNCHRONIZED_HPP__

#include <pthread.h>
#include <map>
#include <iostream>
#include <stdexcept>
#include <typeinfo>
#include <sys/time.h>
#include <errno.h>

class Synchronized{
    protected:
        typedef struct metaMutex{
            pthread_mutex_t lock;
            pthread_cond_t cond;

            pthread_t lockOwner;

            int counter;
        } metaMutex;

        pthread_mutex_t& getMutex(){
            static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
            return lock;
        }
        std::map<const void*, metaMutex*>& getMutexMap(){
            static std::map<const void*, metaMutex*> mmap;
            return mmap;
        }

        const void *accessPtr;
        metaMutex *metaPtr;
        int dereference;
        
        template<typename T>
        T * getAccessPtr(T & obj) { return &obj; } //turn reference into pointer!
        template<typename T>
        T * getAccessPtr(T * obj) { return obj; } //obj is already pointer, return it!

    public:
        template<typename T>
        Synchronized(const T &ptr, bool lockit=true) : accessPtr(getAccessPtr(ptr)){
            //std::cout << "type: " << typeid(ptr).name() << std::endl;

            if(this->accessPtr==NULL){
                throw std::runtime_error(std::string("Synchronizing on NULL pointer is not valid, referenced type is: ")+typeid(ptr).name());
            }

            pthread_mutex_lock(&this->getMutex());

            std::map<const void*, metaMutex*>& mmap = this->getMutexMap();
            std::map<const void*, metaMutex*>::iterator it = mmap.find(this->accessPtr);
            if(it != mmap.end()){
                this->metaPtr = it->second;
                this->metaPtr->counter++;
            }
            else{
                this->metaPtr = new metaMutex();
                pthread_mutex_init(&this->metaPtr->lock, NULL);
                pthread_cond_init(&this->metaPtr->cond, NULL);
                this->metaPtr->counter = 1;
                mmap.insert(std::make_pair(this->accessPtr, this->metaPtr));
            }

            pthread_mutex_unlock(&this->getMutex());

            if(lockit){
                pthread_mutex_lock(&this->metaPtr->lock);
                this->metaPtr->lockOwner = pthread_self();
            }
        }

        operator int() { return 1; }
        const void* getSynchronizedAddress(){
            return this->accessPtr;
        }

        ~Synchronized(){
            pthread_mutex_unlock(&this->metaPtr->lock);

            pthread_mutex_lock(&this->getMutex());
            metaPtr->counter--;
            if(metaPtr->counter<=0){
                this->getMutexMap().erase(this->accessPtr);
                delete metaPtr;
            }
            pthread_mutex_unlock(&this->getMutex());
        }

        void wait(unsigned long milliseconds=0, unsigned int nanos=0){
            if(pthread_equal(pthread_self(), this->metaPtr->lockOwner)==0){
                throw std::runtime_error(std::string("trying to wait is only allowed in the same thread holding the mutex"));
            }

            int rval = 0;
            if(milliseconds == 0 && nanos == 0){
                rval = pthread_cond_wait(&this->metaPtr->cond, &this->metaPtr->lock);
            }
            else{
                struct timespec timeUntilToWait;
                struct timeval now;
                int rt;

                gettimeofday(&now,NULL);

                timeUntilToWait.tv_sec = now.tv_sec;
                long seconds = 0;
                if(milliseconds >= 1000){
                    seconds = (milliseconds/1000);
                    milliseconds -= seconds*1000;
                }
                timeUntilToWait.tv_sec += seconds;
                timeUntilToWait.tv_nsec = (now.tv_usec+1000UL*milliseconds)*1000UL + nanos;
                rval = pthread_cond_timedwait(&this->metaPtr->cond, &this->metaPtr->lock, &timeUntilToWait);
            }
            switch(rval){
                case 0: break;
                case EINVAL: throw std::runtime_error("invalid time or condition or mutex given");
                case EPERM: throw std::runtime_error("trying to wait is only allowed in the same thread holding the mutex");
            }
        }
        void notify(){
            if(pthread_cond_signal(&this->metaPtr->cond)!=0){
                std::runtime_error("non initialized condition variable");
            }
        }
        void notifyAll(){
            if(pthread_cond_broadcast(&this->metaPtr->cond)!=0){
                std::runtime_error("non initialized condition variable");
            }
        }

        template<typename T>
        static void wait(const T &ptr, unsigned long milliseconds=0, unsigned int nanos=0){
            Synchronized syncToken(ptr, false);
            syncToken.wait(milliseconds, nanos);
        }
        template<typename T>
        static void notify(const T &ptr){
            Synchronized syncToken(ptr, false);
            syncToken.notify();
        }
        template<typename T>
        static void notifyAll(const T &ptr){
            Synchronized syncToken(ptr, false);
            syncToken.notifyAll();
        }
};

#define synchronized(ptr) if(Synchronized sync_##__LINE__ = Synchronized(ptr))

#endif
