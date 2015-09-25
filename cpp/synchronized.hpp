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
#ifndef __SYNCRONIZED_HPP__
#define __SYNCRONIZED_HPP__

#include <pthread.h>
#include <map>
#include <iostream>
#include <stdexcept>
#include <typeinfo>

class Synchronized{
    protected:
        typedef struct metaMutex{
            pthread_mutex_t lock;
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
                throw std::runtime_error(std::string("Syncronizing on NULL pointer is not valid, referenced type is: ")+typeid(ptr).name());
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
                this->metaPtr->counter = 1;
                mmap.insert(std::make_pair(this->accessPtr, this->metaPtr));
            }

            pthread_mutex_unlock(&this->getMutex());

            if(lockit){
                pthread_mutex_lock(&this->metaPtr->lock);
            }
        }

        operator int() { return 1; }
        const void* getSyncronizedAddress(){
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
};

#define syncronized(ptr) if(Synchronized sync_##__LINE__ = Synchronized(ptr))

#endif
