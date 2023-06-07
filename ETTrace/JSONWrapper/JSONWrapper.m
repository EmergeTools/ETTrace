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

+ (NSDictionary *)toDictionary:(NSObject *)anyObject {
  FlameNode *node = (FlameNode *)anyObject;
    
  NSObject *children;
  if (node.children.count == 1) {
    children = [JSONWrapper toDictionary:node.children[0]];
  } else {
    children = [[NSMutableArray alloc] init];
    for (FlameNode * c in node.children) {
      [(NSMutableArray *) children addObject:[JSONWrapper toDictionary:c]];
    }
  }

  return @{
    @"name": node.name,
    @"start": @(node.start),
    @"duration": @(node.duration),
    @"library": node.library ? node.library : @"",
    @"children": children,
  };
}

+ (NSData *)toData:(NSObject *)anyInput {
  FlameNode *input = (FlameNode *)anyInput;
    
  return [NSJSONSerialization dataWithJSONObject:[JSONWrapper toDictionary:input] options:NSJSONWritingWithoutEscapingSlashes error:nil];
}

@end
