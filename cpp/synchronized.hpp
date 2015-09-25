#ifndef __SYNCRONIZED_HPP__
#define __SYNCRONIZED_HPP__

#include <pthread.h>
#include <map>
#include <iostream>
#include <typeinfo>

class Synchronized{
    protected:
        typedef struct metaMutex{
            pthread_mutex_t lock;
            int counter;
        } metaMutex;

        static pthread_mutex_t& getMutex(){
            static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
            return lock;
        }
        static std::map<const void*, metaMutex*>& getMutexMap(){
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
        Synchronized(const T &ptr) : accessPtr(getAccessPtr(ptr)){
            //std::cout << "type: " << typeid(ptr).name() << std::endl;

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

            pthread_mutex_lock(&this->metaPtr->lock);
        }

        operator int() { return 1; }

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

#define syncronized(ptr) if(Synchronized sync = Synchronized(ptr))

#endif
