#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#import "dyld_libs.h"

#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include <sys/stat.h>
#include <pthread.h>

// #ifdef __arm64__


kern_return_t mach_vm_allocate
(
        vm_map_t target,
        mach_vm_address_t *address,
        mach_vm_size_t size,
        int flags
);

kern_return_t mach_vm_write
(
        vm_map_t target_task,
        mach_vm_address_t address,
        vm_offset_t data,
        mach_msg_type_number_t dataCnt
);


#define STACK_SIZE 65536
#define CODE_SIZE 128

// Based on https://gist.github.com/vocaeq/fbac63d5d36bc6e1d6d99df9c92f75dc/
// Modified to work when targeting a process on the ios simulator. Removed x86 support
// so this can only be used on arm64.
char injectedCode[] =
//"\x20\x8e\x38\xd4" //brk    #0xc471
"\xe0\x03\x00\x91\x00\x40\x00\xd1\xe1\x03\x1f\xaa\xe3\x03\x1f\xaa\xc4\x00\x00\x10\x62\x01\x00\x10\x85\x00\x40\xf9\xa0\x00\x3f\xd6\x07\x00\x00\x10\xe0\x00\x1f\xd6\x50\x54\x48\x52\x44\x43\x52\x54\x44\x4c\x4f\x50\x45\x4e\x5f\x5f\x50\x54\x48\x52\x44\x45\x58\x54\x21\x00\x80\xd2\xc0\x00\x00\x10\x47\xff\xff\x10\xe8\x00\x40\xf9\x00\x01\x3f\xd6\x67\xfe\xff\x10\xe0\x00\x1f\xd6\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42\x4c\x49\x42";
/*
Compile: as shellcode.asm -o shellcode.o && ld ./shellcode.o -o shellcode -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path`

 .global _main
 .align 4

 _main:
         mov x0, sp
         sub x0, x0, #16


         mov x1, xzr
         mov x3, xzr
         adr x4, pthrdcrt

         adr x2, _thread

         ldr x5, [x4]
         blr x5


 _loop:
         adr x7, _loop
         br x7


 pthrdcrt: .ascii "PTHRDCRT"
 dlllopen: .ascii "DLOPEN__"
 pthrdext: .ascii "PTHRDEXT"

 _thread:
         mov x1, #1
         adr x0, lib
         adr x7, dlllopen
         ldr x8, [x7]
         blr x8
         adr x7, _loop
         br x7
  

 lib: .ascii "LIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIB"
 */

int inject(int pid, const char *lib)
{
    struct stat buf;

    /**
     * First, check we have the library. Otherwise, we won't be able to inject..
     */
    int rc = stat(lib, &buf);
    if (rc != 0) {
        fprintf(stderr, "Unable to open library file %s (%s) - Cannot inject\n", lib, strerror(errno));
        return -9;
    }

    mach_error_t kr = 0;
  
  mach_port_t remoteTask;
  kr = task_for_pid(mach_task_self(), pid, &remoteTask);
  if (kr != KERN_SUCCESS) {
    printf("task_for_pid failed %s\n", mach_error_string(kr));
    return -1;
  }
  
  struct symbol_info si;
  if (getSymbolInfo(remoteTask, &si) != 0) {
    fprintf(stderr, "Error getting symbol info\n");
    return -1;
  }
  

    /**
     * From here on, it's pretty much straightforward -
     * Allocate stack and code. We don't really care *where* they get allocated. Just that they get allocated.
     * So, first, stack:
     */
    mach_vm_address_t remoteStack64 = (vm_address_t)NULL;
    mach_vm_address_t remoteCode64 = (vm_address_t)NULL;
    kr = mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Unable to allocate memory for remote stack in thread: Error %s\n", mach_error_string(kr));
        return (-2);
    }
    else {
        fprintf(stderr, "Allocated remote stack @0x%llx\n", remoteStack64);
    }
    /**
     * Then we allocate the memory for the thread
     */
    remoteCode64 = (vm_address_t)NULL;
    kr = mach_vm_allocate(remoteTask, &remoteCode64, CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Unable to allocate memory for remote code in thread: Error %s\n", mach_error_string(kr));
        return (-2);
    }
  
  if (strlen(lib) >= 84) {
    printf("Path to library is too long for injected code, must be under 84 characters\n");
    return -1;
  }

    /**
     * Patch code before injecting: That is, insert correct function addresses (and lib name) into placeholders
     */
    int i = 0;
    char *possiblePatchLocation = (injectedCode);
    for (i = 0; i < 0x100; i++) {
        // Patching is crude, but works.
        //
        extern void *_pthread_set_self;
        possiblePatchLocation++;

        if (memcmp(possiblePatchLocation, "PTHRDCRT", 8) == 0) {
          memcpy(possiblePatchLocation, &si.pThreadCreateAddr, 8);
        }

        if (memcmp(possiblePatchLocation, "DLOPEN__", 6) == 0) {
          memcpy(possiblePatchLocation, &si.dlOpenAddr, sizeof(uint64_t));
        }

        if (memcmp(possiblePatchLocation, "LIBLIBLIB", 9) == 0) {
            strcpy(possiblePatchLocation, lib);
        }
    }

    /**
        * Write the (now patched) code
      */
    kr = mach_vm_write(remoteTask,                 // Task port
                       remoteCode64,               // Virtual Address (Destination)
                       (vm_address_t)injectedCode, // Source
                       sizeof(injectedCode));                      // Length of the source

    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Unable to write remote thread memory: Error %s\n", mach_error_string(kr));
        return (-3);
    }

    /*
     * Mark code as executable - This also requires a workaround on iOS, btw.
     */
    kr = vm_protect(remoteTask, remoteCode64, sizeof(injectedCode), FALSE, VM_PROT_READ | VM_PROT_EXECUTE);

    /*
        * Mark stack as writable  - not really necessary
     */
    kr = vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Unable to set memory permissions for remote thread: Error %s\n", mach_error_string(kr));
        return (-4);
    }

    /*
     * Create thread - This is obviously hardware specific.
     */
    // Using unified thread state for backporting to ARMv7, if anyone's interested..
    struct arm_unified_thread_state remoteThreadState64;
        thread_act_t         remoteThread;

        memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64) );

        remoteStack64 += (STACK_SIZE / 2); // this is the real stack
    //remoteStack64 -= 8;  // need alignment of 16

        const char* p = (const char*) remoteCode64;
    // Note the similarity - all we change are a couple of regs.
    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (u_int64_t) remoteCode64;
    remoteThreadState64.ts_64.__sp = (u_int64_t) remoteStack64;
// __uint64_t    __x[29];  /* General purpose registers x0-x28 */

    printf ("Remote Stack 64  0x%llx, Remote code is %p\n", remoteStack64, p );

    /*
     * create thread and launch it in one go
     */
kr = thread_create_running( remoteTask, ARM_THREAD_STATE64, // ARM_THREAD_STATE64,
(thread_state_t) &remoteThreadState64.ts_64, ARM_THREAD_STATE64_COUNT , &remoteThread );
    if (kr != KERN_SUCCESS) { fprintf(stderr,"Unable to create remote thread: error %s", mach_error_string (kr));
                  return (-3); }

    return (0);
}
