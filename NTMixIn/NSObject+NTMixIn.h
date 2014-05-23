//
//  NSObject+NTMixIn.h
//  NTMixIn
//
//  Created by Nickolay Tarbayev on 29.05.13.
//  Copyright (c) 2013 Tarbayev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>


@interface NSObject (NTMixIn)

+ (void)useMixIn:(Class)mixInClass;
+ (id)mixInOfClass:(Class)mixInClass;
- (id)mixInOfClass:(Class)mixInClass;

@end

#define MixIn(mixinClassType) [self mixInOfClass:[mixinClassType class]]

#define UseMixIn(mixInClassType) if ([[NSString stringWithFormat:@"%s", __PRETTY_FUNCTION__] rangeOfString:[@"[" stringByAppendingFormat:@"%s ", class_getName(self)]].location != NSNotFound)\
[[self class] useMixIn:[mixInClassType class]]
