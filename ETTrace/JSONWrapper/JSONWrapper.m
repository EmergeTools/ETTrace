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
        @"nodes": [self flameNodeToDictionary:flamegraph.nodes],
        @"libraries": flamegraph.libraries
    }];
    if (flamegraph.device != nil) {
        [result setObject:flamegraph.device forKey:@"device"];
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
