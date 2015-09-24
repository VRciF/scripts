#include "synchronized.hpp"

#include <unistd.h>

#include <iostream>
#include <map>
#include <string>

std::map<std::string, std::string> container;

void* thread1(void *ptr){
    std::cout << "thread 1 started" << std::endl;
    syncronized(container){
        std::cout << "container is locked in thread 1" << std::endl;
        container.insert(std::make_pair("a", "b"));
        std::cout << "sleeping" << std::endl;
        sleep(5);
        std::cout << "insert again" << std::endl;
        container.insert(std::make_pair("c", "d"));
        std::cout << "leaving syncronization on thread1" << std::endl;
    }
}
void* thread2(void *ptr){
    std::cout << "thread 2 started" << std::endl;
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

    std::cout << "exit" << std::endl;
    return 0;
}
