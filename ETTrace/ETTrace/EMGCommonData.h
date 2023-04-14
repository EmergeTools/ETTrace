//
//  EMGCommonData.h
//  ETTrace
//
//  Created by Itay Brenner on 8/4/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMGCommonData : NSObject
+ (BOOL)isRunningOnSimulator;
+ (NSString *)osBuild;
@end

NS_ASSUME_NONNULL_END
