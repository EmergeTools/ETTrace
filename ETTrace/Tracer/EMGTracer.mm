//
//  Tracer.m
//  
//
//  Created by Noah Martin on 10/27/23.
//

#import "Tracer.h"
#import <Foundation/Foundation.h>
#import <vector>
#import <mutex>
#import <map>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/arch.h>
#import <sys/utsname.h>
#import <QuartzCore/QuartzCore.h>
#import "EMGStackTraceRecorder.h"

static NSThread *sStackRecordingThread = nil;

static thread_t sMainMachThread = {0};

static useconds_t sSampleRate = 0;

// To avoid static initialization order fiasco, we access it from a function
EMGStackTraceRecorder &getRecorder() {
    static EMGStackTraceRecorder recorder;
    return recorder;
}

@implementation EMGTracer

+ (BOOL)isRecording {
  return sStackRecordingThread != nil;
}

+ (void)stopRecording:(void (^)(NSDictionary *))stopped {
    [sStackRecordingThread cancel];
    sStackRecordingThread = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        stopped([EMGTracer getResults]);
    });
}

+ (NSDictionary *)getResults {
    NSMutableDictionary <NSString *, NSDictionary<NSString *, id> *> *threads = [NSMutableDictionary dictionary];
    
    auto threadSummaries = getRecorder().collectThreadSummaries();
    for (const auto &thread : threadSummaries) {
        NSString *threadId = [@(thread.threadId) stringValue];
        threads[threadId] = @{
            @"name": @(thread.name.c_str()),
            @"stacks": [self arrayFromStacks:thread.stacks]
        };
    }

    const NXArchInfo *archInfo = NXGetLocalArchInfo();
    NSString *cpuType = [NSString stringWithUTF8String:archInfo->description];
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    return @{
        @"libraryInfo": EMGLibrariesData(),
        @"isSimulator": @([self isRunningOnSimulator]),
        @"osBuild": [self osBuild],
        @"osVersion": [NSString stringWithFormat:@"%ld.%ld.%ld", (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion],
        @"cpuType": cpuType,
        @"device": [self deviceName],
        @"threads": threads,
        @"sampleRate": @(sSampleRate),
    };
}

+ (NSArray <NSDictionary <NSString *, id> *> *) arrayFromStacks: (const std::vector<StackSummary> &)stacks {
    NSMutableArray <NSDictionary <NSString *, id> *> *threadStacks = [NSMutableArray array];
    for (const auto &cStack : stacks) {
        NSMutableArray <NSNumber *> *stack = [NSMutableArray array];
        for (const auto &address : cStack.stack) {
            [stack addObject:@((NSUInteger)address)];
        }
        NSDictionary *stackDictionary = @{
            @"stack": [stack copy],
            @"time": @(cStack.time)
        };
        [threadStacks addObject:stackDictionary];
    }
    return threadStacks;
}

+ (BOOL)isRunningOnSimulator
{
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
}

+ (NSString *)osBuild {
    int mib[2] = {CTL_KERN, KERN_OSVERSION};
    u_int namelen = sizeof(mib) / sizeof(mib[0]);
    size_t bufferSize = 0;

    NSString *osBuildVersion = nil;

    // Get the size for the buffer
    sysctl(mib, namelen, NULL, &bufferSize, NULL, 0);

    u_char buildBuffer[bufferSize];
    int result = sysctl(mib, namelen, buildBuffer, &bufferSize, NULL, 0);

    if (result >= 0) {
        osBuildVersion = [[NSString alloc] initWithBytes:buildBuffer length:bufferSize encoding:NSUTF8StringEncoding];
    }

    NSCharacterSet *nonAlphanumericStrings = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

    // Remove final NULL character
    return [osBuildVersion stringByTrimmingCharactersInSet:nonAlphanumericStrings];
}

+ (NSString *)deviceName {
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

+ (void)setup {
  sMainMachThread = mach_thread_self();
  EMGBeginCollectingLibraries();
}

+ (void)setupStackRecording:(BOOL)recordAllThreads rate:(useconds_t)sampleRate
{
    if (sStackRecordingThread != nil) {
        return;
    }
    sSampleRate = sampleRate;

    // Make sure that +recordStack is always called on the same (non-main) thread.
    // This is because a Process keeps its own "current thread" variable which we need
    // to keep separate
    // from the main thread. This is because unwinding itself from the main thread
    // requires Crashlyics to use a hack, and because the stack recording would show up
    // in the trace. The current strategy is to sleep for 4.5 ms because
    // usleep is guaranteed to sleep more than that, in practice ~5ms. We could use a
    // dispatch_timer, which at least tries to compensate for drift etc., but the
    // timer's queue could theoretically end up run on the main thread
    sStackRecordingThread = [[NSThread alloc] initWithBlock:^{
        thread_t etTraceThread = mach_thread_self();

        NSThread *thread = [NSThread currentThread];
        while (!thread.cancelled) {
            getRecorder().recordStackForAllThreads(recordAllThreads, sMainMachThread, etTraceThread);
            usleep(sampleRate > 0 ? sampleRate : 4500);
        }
    }];
    sStackRecordingThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [sStackRecordingThread start];
}

@end
