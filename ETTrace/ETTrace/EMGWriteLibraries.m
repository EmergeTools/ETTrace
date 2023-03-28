//
//  EMGWriteLibraries.m
//  PerfAnalysis
//
//  Created by Noah Martin on 12/9/22.
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach/mach_init.h>
#import <mach/task.h>
#import <mach-o/dyld_images.h>
#import <mach-o/dyld.h>
#import <pthread.h>
#import <QuartzCore/QuartzCore.h>

#import "EMGWriteLibraries.h"

static NSRecursiveLock *sLock;
static NSMutableArray *sLoadedLibraries;
static uint64_t sMainThreadID;

static void addLibrary(const char *path, const void *loadAddress, NSUUID *binaryUUID) {
    // Note that the slide given is very odd (seems incorrect, and many binaries share the same slide value)
    // So, just print out the header address
    [sLoadedLibraries addObject:@{
        @"path": @(path),
        // Although it's undefined if JSON can handle 64-bit integers, Apple's NSJSONSerialization seems to write them
        // out correctly
        @"loadAddress": @((uint64_t)loadAddress),
        @"uuid": binaryUUID.UUIDString
    }];
}

static NSUUID* uuid(const struct mach_header *header) {
    BOOL is64bit = header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64;
    uintptr_t cursor = (uintptr_t)header + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const struct segment_command *segmentCommand = NULL;
    for (uint32_t i = 0; i < header->ncmds; i++, cursor += segmentCommand->cmdsize) {
        segmentCommand = (struct segment_command *)cursor;
        if (segmentCommand->cmd == LC_UUID) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)segmentCommand;
            return [[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid];
        }
    }
    return NULL;
}

static void printLibrary(const struct mach_header *header, intptr_t slide) {
    // Lock just in case this function isn't called in a thread-safe manner
    [sLock lock];
    Dl_info info = {0};
    dladdr(header, &info);
    addLibrary(info.dli_fname, header, uuid(header));
    [sLock unlock];
}

void EMGBeginCollectingLibraries() {
    sLoadedLibraries = [NSMutableArray array];
    sLock = [NSRecursiveLock new];

    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    task_info(mach_task_self_, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    struct dyld_all_image_infos *infos = (struct dyld_all_image_infos *)dyld_info.all_image_info_addr;
    void *header = (void *)infos->dyldImageLoadAddress;
    addLibrary("/usr/lib/dyld", header, uuid(header));

    pthread_threadid_np(NULL, &sMainThreadID);

    _dyld_register_func_for_add_image(printLibrary);
}

NSDictionary *EMGLibrariesData() {
    [sLock lock];
    NSString *runId = [NSProcessInfo processInfo].environment[@"EMERGE_RUN_ID"];
    NSDictionary *result = @{
        @"runId": runId ?: [NSNull null],
        @"relativeTime": @(CACurrentMediaTime()),
        @"mainThreadId": @(sMainThreadID),
        @"loadedLibraries": [sLoadedLibraries copy]
    };
    [sLock unlock];
    return result;
}
