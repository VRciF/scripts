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
        
        const void* getAccessPointer(){
            if(dereference){
                return (const void*)accessPtr;
            }
            else{
                return this->accessPtr;
            }
        }

    public:
        template<typename T>
        Synchronized(const T &ptr) : accessPtr(&ptr){
            dereference = 0;

            if(typeid(ptr).name()[0]=='P'){
                dereference = 1;
            }
            //std::cout << "type: " << typeid(ptr).name() << std::endl;

            pthread_mutex_lock(&this->getMutex());

            std::map<const void*, metaMutex*>& mmap = this->getMutexMap();
            std::map<const void*, metaMutex*>::iterator it = mmap.find(this->getAccessPointer());
            if(it != mmap.end()){
                this->metaPtr = it->second;
                this->metaPtr->counter++;
            }
            else{
                this->metaPtr = new metaMutex();
                pthread_mutex_init(&this->metaPtr->lock, NULL);
                this->metaPtr->counter = 1;
                mmap.insert(std::make_pair(this->getAccessPointer(), this->metaPtr));
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
                this->getMutexMap().erase(this->getAccessPointer());
                delete metaPtr;
            }
            pthread_mutex_unlock(&this->getMutex());
        }
};

#define syncronized(ptr) if(Synchronized sync = Synchronized(ptr))

#endif
