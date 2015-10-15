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
 * Changelog:
 *   2015-10-15 added deadlock detection
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

#if __cplusplus > 199711L
#include <unordered_map>
#include <condition_variable>
#include <thread>
#include <chrono>
#include <exception>
#endif

#include <map>

#include <pthread.h>
#include <iostream>
#include <stdexcept>
#include <typeinfo>
#include <sys/time.h>
#include <errno.h>

class Synchronized{
    public:
        enum LockType{ READ, WRITE };

    protected:
        LockType ltype;

#if __cplusplus > 199711L
        typedef std::multimap<std::thread::id, LockType> t_lockmap;
#else
        typedef std::multimap<pthread_id_np_t, LockType> t_lockmap;
#endif

        typedef struct metaMutex{
            pthread_rwlock_t rwlock;
            
#if __cplusplus > 199711L
            std::unique_lock<std::mutex> ulock;
            std::mutex lock;
            std::condition_variable cond;
            t_lockmap lockingThreads;
#else
            pthread_mutex_t lock;
            pthread_cond_t cond;
            t_lockmap lockingThreads;
#endif
        } metaMutex;


#if __cplusplus > 199711L
        std::mutex& getMutex(){
            static std::mutex lock;
            return lock;
        }

        std::unordered_map<const void*, metaMutex*>& getMutexMap(){
            static std::unordered_map<const void*, metaMutex*> mmap;
            return mmap;
        }
#else
        pthread_mutex_t& getMutex(){
            static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
            return lock;
        }

        std::map<const void*, metaMutex*>& getMutexMap(){
            static std::map<const void*, metaMutex*> mmap;
            return mmap;
        }
#endif

        const void *accessPtr;
        metaMutex *metaPtr;
        int dereference;

        template<typename T>
        T * getAccessPtr(T & obj) { return &obj; } //turn reference into pointer!
        template<typename T>
        T * getAccessPtr(T * obj) { return obj; } //obj is already pointer, return it!

public:
        template<typename T>
        Synchronized(const T &ptr, LockType ltype = LockType::WRITE) : ltype(ltype),accessPtr(getAccessPtr(ptr)){
            //std::cout << "type: " << typeid(ptr).name() << std::endl;

            if(this->accessPtr==NULL){
                throw std::runtime_error(std::string("Synchronizing on NULL pointer is not valid, referenced type is: ")+typeid(ptr).name());
            }

#if __cplusplus > 199711L
            {
                std::lock_guard<std::mutex> lockMapMutex(this->getMutex());

                std::unordered_map<const void*, metaMutex*>& mmap = this->getMutexMap();
                std::unordered_map<const void*, metaMutex*>::iterator it = mmap.find(this->accessPtr);

                if(it != mmap.end()){
                    this->metaPtr = it->second;

                    std::pair<t_lockmap::iterator, t_lockmap::iterator> range = this->metaPtr->lockingThreads.equal_range(std::this_thread::get_id());
                    for(;range.first!=range.second;range.first++){
                        if(range.first->second == LockType::WRITE || ltype==LockType::WRITE){
                            throw std::runtime_error(std::string("deadlock detected"));
                        }
                    }
                    this->metaPtr->lockingThreads.insert(std::make_pair(std::this_thread::get_id(), ltype));
                }
                else{
                    this->metaPtr = new metaMutex();
                    pthread_rwlock_init(&this->metaPtr->rwlock, NULL);

                    this->metaPtr->ulock = std::unique_lock<std::mutex>(this->metaPtr->lock);
                    this->metaPtr->lockingThreads.insert(std::make_pair(std::this_thread::get_id(), ltype));
                    mmap.insert(std::make_pair(this->accessPtr, this->metaPtr));
                }
            }
            
#else
            pthread_mutex_lock(&this->getMutex());

            std::map<const void*, metaMutex*>& mmap = this->getMutexMap();
            std::map<const void*, metaMutex*>::iterator it = mmap.find(this->accessPtr);

            if(it != mmap.end()){
                this->metaPtr = it->second;

                std::pair<t_lockmap::iterator, t_lockmap::iterator> range = this->metaPtr->lockingThreads.equal_range(pthread_getthreadid_np());
                for(;range.first!=range.second;range.first++){
                    if(range.first->second == LockType::WRITE || ltype==LockType::WRITE){
                        throw std::runtime_error(std::string("deadlock detected"));
                    }
                }
                this->metaPtr->lockingThreads.insert(std::make_pair(pthread_getthreadid_np(), ltype));
            }
            else{
                this->metaPtr = new metaMutex();
                pthread_rwlock_init(&this->metaPtr->rwlock, NULL);
                pthread_mutex_init(&this->metaPtr->lock, NULL);
                pthread_cond_init(&this->metaPtr->cond, NULL);
                this->metaPtr->lockingThreads.insert(std::make_pair(pthread_getthreadid_np(), ltype));
                mmap.insert(std::make_pair(this->accessPtr, this->metaPtr));
            }

            pthread_mutex_unlock(&this->getMutex());
#endif
            if(this->ltype == LockType::WRITE){
                pthread_rwlock_wrlock(&this->metaPtr->rwlock);
            }
            else{
                pthread_rwlock_rdlock(&this->metaPtr->rwlock);
            }
        }

        operator int() { return 1; }
        const void* getSynchronizedAddress(){
            return this->accessPtr;
        }

        ~Synchronized(){
#if __cplusplus > 199711L
            this->metaPtr->ulock.unlock();
#else
            pthread_mutex_unlock(&this->metaPtr->lock);
#endif

            pthread_rwlock_unlock(&this->metaPtr->rwlock);
            {
#if __cplusplus > 199711L
                std::lock_guard<std::mutex> lockMapMutex(this->getMutex());
                t_lockmap::iterator it = metaPtr->lockingThreads.find(std::this_thread::get_id());
#else
                pthread_mutex_lock(&this->getMutex());
                t_lockmap::iterator it = metaPtr->lockingThreads.find(pthread_getthreadid_np());
#endif
                if(it!=metaPtr->lockingThreads.end()){
                    metaPtr->lockingThreads.erase(it);
                }
                if(metaPtr->lockingThreads.size()<=0){  // if none holds lock any more - free resources
                    this->getMutexMap().erase(this->accessPtr);
                    delete this->metaPtr;
                }
            }
#if __cplusplus > 199711L
#else
            pthread_mutex_unlock(&this->getMutex());
#endif
        }

#if __cplusplus > 199711L
        template< class Rep, class Period >
        void wait(std::chrono::duration<Rep, Period> d){
            this->metaPtr->cond.wait_for(this->metaPtr->ulock, d);
        }
#endif

        void wait(unsigned long milliseconds=0, unsigned int nanos=0){
            // keep in mind: it's not possible that the exact same thread call's wait concurrently
            // thus there is no need to think about deadlock's here - but we need to make sure
            // that rwlock will hold the exact same lock as before

            pthread_rwlock_unlock(&this->metaPtr->rwlock);
#if __cplusplus > 199711L
            std::exception_ptr eptr;
            try{
                this->metaPtr->lock.lock();

                if(milliseconds==0 && nanos==0){
                    this->metaPtr->cond.wait(this->metaPtr->ulock);
                }
                else{
                    this->metaPtr->cond.wait_for(this->metaPtr->ulock, std::chrono::milliseconds(milliseconds) + std::chrono::nanoseconds(nanos));
                }

                this->metaPtr->lock.unlock();
            }catch(...){
                eptr = std::current_exception();
            }
            if(this->ltype == LockType::WRITE){
                pthread_rwlock_wrlock(&this->metaPtr->rwlock);
            }
            else{
                pthread_rwlock_rdlock(&this->metaPtr->rwlock);
            }

            if(eptr){
                std::rethrow_exception(eptr);
            }
#else
            pthread_mutex_lock(&this->metaPtr->lock);
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
            pthread_mutex_unlock(&this->metaPtr->lock);
            if(this->ltype == LockType::WRITE){
                pthread_rwlock_wrlock(&this->metaPtr->rwlock);
            }
            else{
                pthread_rwlock_rdlock(&this->metaPtr->rwlock);
            }

            switch(rval){
                case 0: break;
                case EINVAL: throw std::runtime_error("invalid time or condition or mutex given");
                case EPERM: throw std::runtime_error("trying to wait is only allowed in the same thread holding the mutex");
            }
#endif
        }
        void notify(){
#if __cplusplus > 199711L
            this->metaPtr->cond.notify_one();
#else
            if(pthread_cond_signal(&this->metaPtr->cond)!=0){
                std::runtime_error("non initialized condition variable");
            }
#endif
        }
        void notifyAll(){
#if __cplusplus > 199711L
            this->metaPtr->cond.notify_all();
#else
            if(pthread_cond_broadcast(&this->metaPtr->cond)!=0){
                std::runtime_error("non initialized condition variable");
            }
#endif
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

/* from http://stackoverflow.com/questions/1597007/creating-c-macro-with-and-line-token-concatenation-with-positioning-macr */
#define synchronizedTokenPaste(x,y) x ## y
#define synchronizedTokenPaste2(x,y) synchronizedTokenPaste(x,y)

#define jsynchronized(ptr) if(Synchronized synchronizedTokenPaste2(sync_, __LINE__) = Synchronized(ptr))


#if __cplusplus > 199711L

template <typename T, typename F>
void synchronizedCPP11(const T &ptr, F&& func)
{
    Synchronized localVar(ptr);
    std::forward<F>(func)();
}

#else

#define synchronized(ptr, ...) { Synchronized synchronizedTokenPaste2(sync_,_LINE__)(ptr); __VA_ARGS__; }

#endif

#endif
