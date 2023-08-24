//
//  EMGPerfAnalysis_Private.h
//  PerfAnalysis
//
//  Created by Itay Brenner on 6/3/23.
//

#ifndef EMGPerfAnalysis_Private_h
#define EMGPerfAnalysis_Private_h
#import "PerfAnalysis.h"

@interface EMGPerfAnalysis (Private)
+ (void)setupStackRecording:(BOOL) recordAllThreads;
+ (void)setupRunAtStartup:(BOOL) recordAllThreads;
+ (void)stopRecordingThread;
+ (NSURL *)outputPath;
@end


#endif /* EMGPerfAnalysis_Private_h */
