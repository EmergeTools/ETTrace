//
//  TestClass.h
//  ETTrace
//
//  Created by Noah Martin on 4/13/23.
//

#ifndef TestClass_h
#define TestClass_h

@import Foundation;

@interface JSONWrapper : NSObject

// Use NSObject here because we cannot import Swift packages from the public header to avoid circular dependencies
+ (NSData *)toData:(NSObject *)input;

@end


#endif /* TestClass_h */
