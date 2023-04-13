//
//  TestClass.h
//  ETTrace
//
//  Created by Noah Martin on 4/13/23.
//

#ifndef TestClass_h
#define TestClass_h

@import Foundation;
@import ETModels;

@interface JSONWrapper : NSObject

+ (NSDictionary *)toDictionary:(FlameNode *)dictionary;
+ (NSData *)toData:(FlameNode *)input;

@end


#endif /* TestClass_h */
