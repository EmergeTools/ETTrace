//
//  EMGChannelListener.h
//  PerfAnalysis
//
//  Created by Itay Brenner on 6/3/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMGChannelListener : NSObject
- (instancetype) init;
- (void) sendReportCreatedMessage;
@end

NS_ASSUME_NONNULL_END
