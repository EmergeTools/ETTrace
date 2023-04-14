//
//  EMGMemoryAnalysis.m
//  ETTrace
//
//  Created by Itay Brenner on 7/4/23.
//

#import "EMGMemoryAnalysis_Private.h"
#import <mach/mach.h>
#import <mach-o/arch.h>
#import "EMGWriteLibraries.h"
#import "EMGChannelListener.h"
#import "EMGCommonData.h"

// MARK: - Models
static const int kMaxFramesPerStack = 512;
typedef struct {
    CFTimeInterval time;
    uint64_t frameCount;
    uintptr_t frames[kMaxFramesPerStack];
    uint64_t allocatedMemory;
} Stack;

// MARK: - Original Pointers
#import <malloc/malloc.h>
static void *(*orig_malloc_zone_malloc)(malloc_zone_t *, size_t);
static void *(*orig_malloc_zone_calloc)(malloc_zone_t *, size_t, size_t);
static void *(*orig_malloc_zone_valloc)(malloc_zone_t *, size_t);
static void *(*orig_malloc_zone_realloc)(malloc_zone_t *, void *, size_t);

// MARK: - Variables
#import <vector>
#import <mutex>
static BOOL isRebinded = false;
static std::vector<Stack> *sStacks;
static std::mutex sStacksLock;
static thread_t sMainMachThread = {0};
extern "C" {
    void FIRCLSWriteThreadStack(thread_t thread, uintptr_t *frames, uint64_t framesCapacity, uint64_t *framesWritten);
}
#include <execinfo.h>
#include <stdio.h>

// MARK: - Rebindings
#import <QuartzCore/QuartzCore.h>
void *my_malloc_zone_malloc(malloc_zone_t *zone, size_t size) {
    Stack stack;
    // Freezes if we try to suspend the thread
//    thread_suspend(sMainMachThread);
    stack.time = CACurrentMediaTime();
    stack.allocatedMemory = size;
//    int i, frames = backtrace(callstack, 128);
    FIRCLSWriteThreadStack(sMainMachThread, stack.frames, kMaxFramesPerStack, &(stack.frameCount));
//    thread_resume(sMainMachThread);
    sStacksLock.lock();
    try {
      sStacks->emplace_back(stack);
    } catch (const std::length_error& le) {
      fflush(stdout);
      fflush(stderr);
      throw le;
    }
    sStacksLock.unlock();
    
    return orig_malloc_zone_malloc(zone, size);
}

void *my_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size) {
    Stack stack;
//    thread_suspend(sMainMachThread);
    stack.time = CACurrentMediaTime();
    stack.allocatedMemory = size * num_items;
    FIRCLSWriteThreadStack(sMainMachThread, stack.frames, kMaxFramesPerStack, &(stack.frameCount));
    sStacksLock.lock();
    try {
      sStacks->emplace_back(stack);
    } catch (const std::length_error& le) {
      fflush(stdout);
      fflush(stderr);
      throw le;
    }
    sStacksLock.unlock();
    
    return orig_malloc_zone_calloc(zone, num_items, size);
}

void *my_malloc_zone_valloc(malloc_zone_t *zone, size_t size) {
    Stack stack;
//    thread_suspend(sMainMachThread);
    stack.time = CACurrentMediaTime();
    stack.allocatedMemory = size;
    FIRCLSWriteThreadStack(sMainMachThread, stack.frames, kMaxFramesPerStack, &(stack.frameCount));
    sStacksLock.lock();
    try {
      sStacks->emplace_back(stack);
    } catch (const std::length_error& le) {
      fflush(stdout);
      fflush(stderr);
      throw le;
    }
    sStacksLock.unlock();
    
    return orig_malloc_zone_valloc(zone, size);
}

void *my_malloc_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size) {
    size_t previousSize = malloc_size(ptr);
    
    Stack stack;
//    thread_suspend(sMainMachThread);
    stack.time = CACurrentMediaTime();
    stack.allocatedMemory = size - previousSize;
    FIRCLSWriteThreadStack(sMainMachThread, stack.frames, kMaxFramesPerStack, &(stack.frameCount));
    sStacksLock.lock();
    try {
      sStacks->emplace_back(stack);
    } catch (const std::length_error& le) {
      fflush(stdout);
      fflush(stderr);
      throw le;
    }
    sStacksLock.unlock();
    return orig_malloc_zone_realloc(zone, ptr, size);
}

@implementation EMGMemoryAnalysis
+ (void)load {
    sMainMachThread = mach_thread_self();
    sStacks = new std::vector<Stack>;
    sStacks->reserve(4000);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runAtStartupMemory"]) {
        [EMGMemoryAnalysis setupMemoryRecording];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"runAtStartupMemory"];
    }
}

+ (void)setupMemoryRecording {
//    rebind_symbols((struct rebinding[4]) {
//        {"malloc_zone_malloc", (void *)my_malloc_zone_malloc, (void **)&orig_malloc_zone_malloc},
//        {"malloc_zone_calloc", (void *)my_malloc_zone_calloc, (void **)&orig_malloc_zone_calloc},
//        {"malloc_zone_valloc", (void *)my_malloc_zone_valloc, (void **)&orig_malloc_zone_valloc},
//        {"malloc_zone_realloc", (void *)my_malloc_zone_realloc, (void **)&orig_malloc_zone_realloc},
//    }, 4);
    isRebinded = YES;
}

+ (void)stopRecordingThread {
    if (!isRebinded) {
        return;
    }
    
//    rebind_symbols((struct rebinding[4]) {
//        {"malloc_zone_malloc", (void *)orig_malloc_zone_malloc, (void **)&orig_malloc_zone_malloc},
//        {"malloc_zone_calloc", (void *)orig_malloc_zone_calloc, (void **)&orig_malloc_zone_calloc},
//        {"malloc_zone_valloc", (void *)orig_malloc_zone_valloc, (void **)&orig_malloc_zone_valloc},
//        {"malloc_zone_realloc", (void *)orig_malloc_zone_realloc, (void **)&orig_malloc_zone_realloc},
//    }, 4);
    
    NSLog(@"************** EMG done");
    sStacksLock.lock();
    NSMutableArray <NSDictionary <NSString *, id> *> *stacks = [NSMutableArray array];
    for (const auto &cStack : *sStacks) {
        NSMutableArray <NSNumber *> *stack = [NSMutableArray array];
        // Add the addrs in reverse order so that they start with the lowest frame, e.g. `start`
        for (int j = (int)cStack.frameCount - 1; j >= 0; j--) {
            [stack addObject:@((NSUInteger)cStack.frames[j])];
        }
        NSDictionary *stackDictionary = @{
            @"stack": [stack copy],
            @"time": @(cStack.time),
            @"allocatedMemory": @(cStack.allocatedMemory)
        };
        [stacks addObject:stackDictionary];
    }
    sStacks->clear();
    sStacksLock.unlock();
    const NXArchInfo *archInfo = NXGetLocalArchInfo();
    NSString *cpuType = [NSString stringWithUTF8String:archInfo->description];
    NSMutableDictionary *info = [@{
        @"stacks": stacks,
        @"libraryInfo": EMGLibrariesData(),
        @"isSimulator": @([EMGCommonData isRunningOnSimulator]),
        @"osBuild": [EMGCommonData osBuild],
        @"cpuType": cpuType
    } mutableCopy];
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:info options:0 error:&error];
    if (error) {
        @throw error;
    }
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *emergeDirectoryURL = [documentsURL URLByAppendingPathComponent:@"emerge-output"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:emergeDirectoryURL.path isDirectory:NULL]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:emergeDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *outputURL = [emergeDirectoryURL URLByAppendingPathComponent:@"output_memory.json"];
    NSLog(@"SAving to: %@", outputURL);
    BOOL result = [data writeToURL:outputURL options:NSDataWritingAtomic error:&error];
    if (!result || error) {
        NSLog(@"Error writing PerfAnalysis state %@", error);
    } else {
        NSLog(@"PerfAnalysis result written");
    }
    
    [[EMGChannelListener sharedChannelListener] sendReportCreatedMemoryMessage];
}

+ (NSURL *)outputPath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *emergeDirectoryURL = [documentsURL URLByAppendingPathComponent:@"emerge-output"];
    return [emergeDirectoryURL URLByAppendingPathComponent:@"output_memory.json"];
}
@end
