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
+ (void)startRecording:(BOOL) recordAllThreads rate:(NSInteger)sampleRate;
+(void)stopRecording;
+ (void)setupRunAtStartup:(BOOL) recordAllThreads rate:(NSInteger)sampleRate;
+ (NSURL *)outputPath;
@end


#endif /* EMGPerfAnalysis_Private_h */
