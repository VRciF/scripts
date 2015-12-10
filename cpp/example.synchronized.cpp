#include <unistd.h>
#include <iostream>

#include "synchronized.hpp"

int data = 0;

void* distributeData(void *ptr){
    while(true){
        {
            Synchronized readerSyncToken(&data);

            readerSyncToken.wait();  // wait for writer to modify data

            std::cout << "current data value: " << data << std::endl;
            if(data>=10){ break; }
        }
    }
    std::cout << "thread finished" << std::endl;
    return NULL;
}

int main(int argc, char **argv){
    pthread_t th;
    pthread_create(&th, NULL, distributeData, NULL);
    
    for(int i=0;i<20;i++){
        sleep(1);
        {
            Synchronized writerSyncToken(&data);
            data++;
            writerSyncToken.notify();
        }
    }
}

