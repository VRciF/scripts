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
    syncronized(container){
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
}
void* thread2(void *ptr){
    std::cout << "thread 2 started - using synchronized function" << std::endl;
    synchronizedFunction();
    std::cout << "thread 2: synchronized function finished" << std::endl;
    syncronized(container){
        std::cout << "container is locked in thread 2" << std::endl;
        std::map<std::string,std::string>::iterator it = container.begin();
        for(;it!=container.end();it++){
            std::cout << it->first << " maps " << it->second << std::endl;
        }
        std::cout << "leaving syncronization on thread2" << std::endl;
    }
}

int main(int argc, char **argv){

    pthread_t th1, th2;
    
    std::cout << "creating threads" << std::endl;
    
    pthread_create(&th1, NULL, thread1, NULL);
    sleep(1);
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

        std::cout << "somevar addr: " << (&somevar) << "=" << s1.getSyncronizedAddress() << std::endl;
        std::cout << "someptr addr: " << (someptr) << "=" << s2.getSyncronizedAddress() << std::endl;
        std::cout << "somevar addr: " << (&somevar) << "=" << s3.getSyncronizedAddress() << std::endl;
        std::cout << "s1 equals s3: " << s1.getSyncronizedAddress() << "=" << s3.getSyncronizedAddress() << std::endl;
        std::cout << "s2 different s4: " << s2.getSyncronizedAddress() << "!=" << s4.getSyncronizedAddress() << std::endl;

        std::cout << "Object test: " << (&object) << "=" << s7.getSyncronizedAddress() << std::endl;
        std::cout << "Object ptrtest: " << (&object) << "=" << s8.getSyncronizedAddress() << std::endl;
        std::cout << "Constant c-string test: " << ((const void*)cstr) << "=" << s9.getSyncronizedAddress() << std::endl;

        std::cout << "Null pointer test2: " << (&ptr) << "=" << s6.getSyncronizedAddress() << std::endl;
        try{
            Synchronized s5(ptr, false);
            std::cout << "Null pointer test: " << (ptr) << "=" << s5.getSyncronizedAddress() << std::endl;
        }catch(const std::runtime_error &ex){
            std::cout  << "catched exception:" << ex.what() << std::endl;
        }
    }

    std::cout << "exit" << std::endl;
    return 0;
}
