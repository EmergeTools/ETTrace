//
//  EMGChannelListener.h
//  PerfAnalysis
//
//  Created by Itay Brenner on 6/3/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMGChannelListener : NSObject
+ (instancetype) sharedChannelListener;
- (instancetype) init;
- (void) sendReportCreatedMessage;
- (void) sendReportCreatedMemoryMessage;
@end

NS_ASSUME_NONNULL_END
