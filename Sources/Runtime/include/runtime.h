#pragma once

#ifdef __cplusplus
extern "C" {
#endif

    /// A garbage collected object.
    typedef struct azn_gc_object {

        /// A pointer to the managed object.
        void* value;
        /// A pointer to the destructor of the object.
        void (*destructor)(void*);
        /// The number of references to the object.
        size_t* count;

    } azn_gc_object_t;

    /// Initializes a garbage collected object.
    void azn_gc_object_init(azn_gc_object_t* object, size_t size, void (*destructor)(void*));

    /// Retain a reference on a managed object.
    void azn_gc_object_retain(azn_gc_object_t* object);

    /// Release a reference on a managed object, calling its destructor if needed.
    void azn_gc_object_release(azn_gc_object_t* object);

#ifdef __cplusplus
}
#endif
