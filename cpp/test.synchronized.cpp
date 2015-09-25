#include "synchronized.hpp"

#include <unistd.h>
#include <stdexcept>

#include <iostream>
#include <map>
#include <string>

std::map<std::string, std::string> container;

void synchronizedFunction(){
    Synchronized synToken(__func__);

    std::cout << __func__ << std::endl;
    sleep(5);
}

void* thread1(void *ptr){
    std::cout << "thread 1 started" << std::endl;
    synchronized(container){
        std::cout << "container is locked in thread 1" << std::endl;
        container.insert(std::make_pair("a", "b"));
        std::cout << "sleeping" << std::endl;
        sleep(3);
        std::cout << "insert again" << std::endl;
        container.insert(std::make_pair("c", "d"));
        std::cout << "leaving syncronization on thread1" << std::endl;
    }
    std::cout << "thread 1 using synchronized function" << std::endl;
    synchronizedFunction();
    std::cout << "thread 1 finished synchronized function" << std::endl;
    return NULL;
}
void* thread2(void *ptr){
    sleep(1);
    std::cout << "thread 2 started - using synchronized function" << std::endl;
    synchronizedFunction();
    std::cout << "thread 2: synchronized function finished" << std::endl;
    synchronized(container){
        std::cout << "container is locked in thread 2" << std::endl;
        std::map<std::string,std::string>::iterator it = container.begin();
        for(;it!=container.end();it++){
            std::cout << it->first << " maps " << it->second << std::endl;
        }
        std::cout << "leaving syncronization on thread2" << std::endl;
    }
    return NULL;
}

void* syncThread1(void *ptr){
    std::cout << "Thread 1 synchronizing on container" << std::endl;
    synchronized(container){
        std::cout << "Thread 1 acquired container lock - waiting for 15 seconds max" << std::endl;
        Synchronized::wait(container, 15000); // wait 15 seconds
        std::cout << "Thread 1 woke up on wait" << std::endl;
    }
    std::cout << "Thread 1 exit" << std::endl;
}
void* syncThread2(void *ptr){
    sleep(1);
    std::cout << "Thread 2 synchronizing on container" << std::endl;
    synchronized(container){
        std::cout << "Thread 2 acquired container lock" << std::endl;
        Synchronized::notify(container); // wait 3 seconds
        std::cout << "Thread 2 notified container" << std::endl;
    }
    std::cout << "Thread 2 exit" << std::endl;
}

int main(int argc, char **argv){
    std::cout << "creating threads" << std::endl;


    pthread_t th1, th2;

    pthread_create(&th1, NULL, thread1, NULL);
    pthread_create(&th2, NULL, thread2, NULL);
    pthread_join(th1, NULL);
    pthread_join(th2, NULL);
    
    std::cout << "thread test finished - testing more cases:" << std::endl;
    
    {
        int somevar;
        int *someptr = &somevar;
        void *ptr = NULL;
        std::string object = "asdf";
        const char *cstr = "asdf";
        
        Synchronized s1(somevar, false), s2(someptr, false), s3(&somevar, false), s4(&someptr, false),
                     s6(&ptr, false), s7(object, false), s8(&object, false), s9("asdf", false);

        std::cout << "somevar addr: " << (&somevar) << "=" << s1.getSynchronizedAddress() << std::endl;
        std::cout << "someptr addr: " << (someptr) << "=" << s2.getSynchronizedAddress() << std::endl;
        std::cout << "somevar addr: " << (&somevar) << "=" << s3.getSynchronizedAddress() << std::endl;
        std::cout << "s1 equals s3: " << s1.getSynchronizedAddress() << "=" << s3.getSynchronizedAddress() << std::endl;
        std::cout << "s2 different s4: " << s2.getSynchronizedAddress() << "!=" << s4.getSynchronizedAddress() << std::endl;

        std::cout << "Object test: " << (&object) << "=" << s7.getSynchronizedAddress() << std::endl;
        std::cout << "Object ptrtest: " << (&object) << "=" << s8.getSynchronizedAddress() << std::endl;
        std::cout << "Constant c-string test: " << ((const void*)cstr) << "=" << s9.getSynchronizedAddress() << std::endl;

        std::cout << "Null pointer test2: " << (&ptr) << "=" << s6.getSynchronizedAddress() << std::endl;
        try{
            Synchronized s5(ptr, false);
            std::cout << "Null pointer test: " << (ptr) << "=" << s5.getSynchronizedAddress() << std::endl;
        }catch(const std::runtime_error &ex){
            std::cout  << "catched exception:" << ex.what() << std::endl;
        }
    }

    pthread_create(&th1, NULL, syncThread1, NULL);
    pthread_create(&th2, NULL, syncThread2, NULL);
    pthread_join(th1, NULL);
    pthread_join(th2, NULL);

    return 0;
}
