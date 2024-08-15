//
//  EMGTracer+PrintThreads.m
//  
//
//  Created by Itay Brenner on 15/8/24.
//

#import <Foundation/Foundation.h>
#import <Tracer.h>
@import TracerSwift;

@implementation EMGTracer (PrintThread)

+ (void)printThreads {
  [ThreadHelper printThreads];
}

@end
