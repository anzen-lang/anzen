#include <cstdlib>
#include "runtime.h"

extern "C" {

void azn_gc_object_init(azn_gc_object_t* object, size_t size, void (*destructor)(void*)) {
    object->value = malloc(size);
    object->destructor = destructor;
    object->count = (size_t*)malloc(sizeof(size_t));
    *(object->count) = 1;
}

void azn_gc_object_retain(azn_gc_object_t* object) {
    *(object->count) += 1;
}

void azn_gc_object_release(azn_gc_object_t* object) {
    *(object->count) -= 1;
    if (*(object->count) == 0) {
        if (object->destructor != nullptr) {
            object->destructor(object->value);
        }
        free(object->value);
    }
}

}
