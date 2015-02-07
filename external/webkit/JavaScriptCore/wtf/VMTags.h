

#ifndef VMTags_h
#define VMTags_h

#include <wtf/Platform.h>

// On Mac OS X, the VM subsystem allows tagging memory requested from mmap and vm_map
// in order to aid tools that inspect system memory use. 
#if OS(DARWIN) && !defined(BUILDING_ON_TIGER)

#include <mach/vm_statistics.h>

#if defined(VM_MEMORY_JAVASCRIPT_CORE) && defined(VM_MEMORY_JAVASCRIPT_JIT_REGISTER_FILE) && defined(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR) && defined(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR)
#define VM_TAG_FOR_COLLECTOR_MEMORY VM_MAKE_TAG(VM_MEMORY_JAVASCRIPT_CORE)
#define VM_TAG_FOR_REGISTERFILE_MEMORY VM_MAKE_TAG(VM_MEMORY_JAVASCRIPT_JIT_REGISTER_FILE)
#define VM_TAG_FOR_EXECUTABLEALLOCATOR_MEMORY VM_MAKE_TAG(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR)
#else
#define VM_TAG_FOR_COLLECTOR_MEMORY VM_MAKE_TAG(63)
#define VM_TAG_FOR_EXECUTABLEALLOCATOR_MEMORY VM_MAKE_TAG(64)
#define VM_TAG_FOR_REGISTERFILE_MEMORY VM_MAKE_TAG(65)
#endif // defined(VM_MEMORY_JAVASCRIPT_CORE) && defined(VM_MEMORY_JAVASCRIPT_JIT_REGISTER_FILE) && defined(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR) && defined(VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR)

#else // OS(DARWIN) && !defined(BUILDING_ON_TIGER)

#define VM_TAG_FOR_COLLECTOR_MEMORY -1
#define VM_TAG_FOR_EXECUTABLEALLOCATOR_MEMORY -1
#define VM_TAG_FOR_REGISTERFILE_MEMORY -1

#endif // OS(DARWIN) && !defined(BUILDING_ON_TIGER)

#endif // VMTags_h
