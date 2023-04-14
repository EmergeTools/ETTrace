//
//  EMGMemoryAnalysis.h
//  ETTrace
//
//  Created by Itay Brenner on 7/4/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMGMemoryAnalysis : NSObject
+ (void)setupMemoryRecording;
+ (void)stopRecordingThread;
+ (NSURL *)outputPath;
@end

NS_ASSUME_NONNULL_END
