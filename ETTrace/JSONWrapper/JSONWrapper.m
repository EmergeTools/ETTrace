//
//  TestClass.m
//  ETTraceRunner
//
//  Created by Noah Martin on 4/13/23.
//

#import <Foundation/Foundation.h>
#import "JSONWrapper.h"
@import ETModels;

@implementation JSONWrapper

+ (NSDictionary *)flameNodeToDictionary:(FlameNode *)node {
    NSObject *children;
    if (node.children.count == 1) {
        children = [JSONWrapper flameNodeToDictionary:node.children[0]];
    } else {
        children = [[NSMutableArray alloc] init];
        for (FlameNode * c in node.children) {
            [(NSMutableArray *) children addObject:[JSONWrapper flameNodeToDictionary:c]];
        }
    }
    
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"name": node.name,
        @"start": @(node.start),
        @"duration": @(node.duration),
        @"library": node.library ? node.library : @"",
        @"children": children,
    }];
    
    if (node.address != nil) {
        [result setObject:node.address forKey:@"address"];
    }

    return result;
}

+ (NSDictionary *)flamegraphToDictionary:(Flamegraph *)flamegraph {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"osBuild": flamegraph.osBuild,
        @"isSimulator": @(flamegraph.isSimulator),
        @"libraries": flamegraph.libraries,
        @"events": [self eventsToArray:flamegraph.events],
        @"device": flamegraph.device,
    }];

    NSMutableArray *threads = [NSMutableArray array];
    for (ThreadNode *node in flamegraph.threadNodes) {
      [threads addObject:@{
        @"name": node.threadName,
        @"nodes": [self flameNodeToDictionary:node.nodes]
      }];
    }
    [result setObject:threads forKey:@"threads"];

    return result;
}

+ (NSArray *)eventsToArray:(NSArray<FlamegraphEvent *> *)events {
    NSMutableArray *result = [NSMutableArray array];
    
    for (FlamegraphEvent *event in events) {
        [result addObject:@{
            @"name": event.name,
            @"type": [event.type uppercaseString],
            @"time": @(event.time),
        }];
    }
    
    return result;
}

+ (NSData *)toData:(NSObject *)anyInput {
  Flamegraph *input = (Flamegraph *)anyInput;
    
  return [NSJSONSerialization dataWithJSONObject:[JSONWrapper flamegraphToDictionary:input]
                                         options:NSJSONWritingWithoutEscapingSlashes
                                           error:nil];
}

@end
