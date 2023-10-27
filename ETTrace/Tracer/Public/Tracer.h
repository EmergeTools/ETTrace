//
//  EMGWriteLibraries.h
//  PerfAnalysis
//
//  Created by Noah Martin on 12/9/22.
//

#ifndef EMGWriteLibraries_h
#define EMGWriteLibraries_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSDictionary *EMGLibrariesData(void);
void EMGBeginCollectingLibraries(void);

#ifdef __cplusplus
}
#endif

@interface EMGTracer : NSObject

+ (void)setupStackRecording:(BOOL)recordAllThreads;
+ (void)stopRecording:(void (^)(NSDictionary *))stopped;
// Must be called on the main thread, before setupStackRecording is called
+ (void)setup;
+ (NSDictionary *)getResults;
+ (BOOL)isRecording;

@end


#endif /* EMGWriteLibraries_h */
