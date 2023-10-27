//
//  Constructor.m
//  PerfAnalysis
//
//  Created by Noah Martin on 11/23/22.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Tracer.h>
#import <vector>
#import <mutex>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach-o/arch.h>
#import <sys/utsname.h>
#import "EMGChannelListener.h"
#import <QuartzCore/QuartzCore.h>
#import "PerfAnalysis.h"
#include <map>

NSString *const kEMGSpanStarted = @"EmergeMetricStarted";
NSString *const kEMGSpanEnded = @"EmergeMetricEnded";

@implementation EMGPerfAnalysis

static dispatch_queue_t fileEventsQueue;

static EMGChannelListener *channelListener;
static NSMutableArray <NSDictionary *> *sSpanTimes;

+ (void)startRecording:(BOOL)recordAllThreads {
  sSpanTimes = [NSMutableArray array];
  [EMGTracer setupStackRecording:recordAllThreads];
}

+ (void)setupRunAtStartup:(BOOL) recordAllThreads {
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"runAtStartup"];
    [[NSUserDefaults standardUserDefaults] setBool:recordAllThreads forKey:@"recordAllThreads"];
    exit(0);
}

+ (void)startObserving {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
        NSURL *emergeDirectoryURL = [documentsURL URLByAppendingPathComponent:@"emerge-perf-analysis"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:emergeDirectoryURL.path isDirectory:NULL]) {
            [[NSFileManager defaultManager] createDirectoryAtURL:emergeDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        channelListener = [[EMGChannelListener alloc] init];
    });
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kEMGSpanStarted
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull notification) {
        if (![EMGTracer isRecording]) {
            return;
        }
        
        NSString *span = notification.userInfo[@"metric"];
        [sSpanTimes addObject:@{
            @"span": span,
            @"type": @"start",
            @"time": @(CACurrentMediaTime())
        }];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:kEMGSpanEnded
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull notification) {
        if (![EMGTracer isRecording]) {
            return;
        }
        
        NSString *span = notification.userInfo[@"metric"];
        [sSpanTimes addObject:@{
            @"span": span,
            @"type": @"stop",
            @"time": @(CACurrentMediaTime())
        }];
    }];
}

+ (void)stopRecording {
  [EMGTracer stopRecording:^(NSDictionary *results) {
    NSMutableDictionary *info = [results mutableCopy];
    info[@"events"] = sSpanTimes;

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
    NSURL *outputURL = [emergeDirectoryURL URLByAppendingPathComponent:@"output.json"];
    BOOL result = [data writeToURL:outputURL options:NSDataWritingAtomic error:&error];
    if (!result || error) {
        NSLog(@"Error writing ETTrace state %@", error);
    } else {
        NSLog(@"ETTrace result written");
    }
    [channelListener sendReportCreatedMessage];
  }];
}

+ (void)load {
    NSLog(@"Starting ETTrace");
    [EMGTracer setup];
    fileEventsQueue = dispatch_queue_create("com.emerge.file_queue", DISPATCH_QUEUE_SERIAL);
    BOOL infoPlistRunAtStartup = ((NSNumber *) NSBundle.mainBundle.infoDictionary[@"ETTraceRunAtStartup"]).boolValue;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runAtStartup"] || infoPlistRunAtStartup) {
        BOOL recordAllThreads = [[NSUserDefaults standardUserDefaults] boolForKey:@"recordAllThreads"];
        [EMGPerfAnalysis startRecording:recordAllThreads];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"runAtStartup"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"recordAllThreads"];
    }
    [EMGPerfAnalysis startObserving];
}

+ (NSURL *) outputPath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *emergeDirectoryURL = [documentsURL URLByAppendingPathComponent:@"emerge-output"];
    return [emergeDirectoryURL URLByAppendingPathComponent:@"output.json"];
}

@end
