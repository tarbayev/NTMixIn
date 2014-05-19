//
//  NSObject+NTMixIn.m
//  NTMixIn
//
//  Created by Nickolay Tarbayev on 29.05.13.
//  Copyright (c) 2013 Tarbayev. All rights reserved.
//

#import "NSObject+NTMixIn.h"


static SEL sel_regixterMixIn(Class mixInClass, SEL sel) {
    const char *selName = sel_getName(sel);
    
    const char *className = class_getName(mixInClass);
    char *mixInSel;
    
    asprintf(&mixInSel, "%s%s", className, selName);
    
    SEL result = sel_registerName(mixInSel);
    
    free(mixInSel);
    
    return result;
}


@interface MixInProxy : NSProxy
@end


@implementation MixInProxy {
    Class _mixInClass;
    id _caller;
}

+ (id)proxyForMixInClass:(Class)class caller:(id)caller {
    MixInProxy *result = [self alloc];
    result->_mixInClass = class;
    result->_caller = caller;
    
    return result;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    
    sel = sel_regixterMixIn(_mixInClass, sel);
    
    return [_caller methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    invocation.selector = sel_regixterMixIn(_mixInClass, invocation.selector);
    invocation.target = _caller;
    
    [invocation invoke];
}

@end


@implementation NSObject (NTMixIn)

+ (void)useMixIn:(Class)mixInClass {
    [self registerMixInClass:mixInClass];
}

static char MixInProxyKey;

+ (id)mixInOfClass:(Class)mixInClass caller:(id)caller {
    NSMutableSet *mixInClasses = objc_getAssociatedObject([caller class], &MixInClassesKey);
    
    if (![mixInClasses containsObject:mixInClass])
        return nil;

    MixInProxy *mixInProxy = objc_getAssociatedObject(caller, &MixInProxyKey);
    
    if (mixInProxy == nil) {
        mixInProxy = [MixInProxy proxyForMixInClass:mixInClass caller:caller];
        objc_setAssociatedObject(caller, &MixInProxyKey, mixInProxy, OBJC_ASSOCIATION_RETAIN);
    }
    
    return mixInProxy;
}


#pragma mark - Private Methods

static char MixInClassesKey;

+ (void)warnDuplicatedMixIns:(NSSet *)duplicated forSelector:(SEL)selector instance:(BOOL)isInstance {
    
    NSString *methodName = [isInstance ? @"-" : @"+" stringByAppendingString:NSStringFromSelector(selector)];
    
    NSLog(@"WARNING: Multiple implementation of method %@ "
          "in mixin classes %@ "
          "used in %@."
          "Behavior is unpredicted. You should implement %@"
          " in %@ "
          "and call the method of appropriate mixin class directly.",
          methodName,
          [duplicated.allObjects componentsJoinedByString:@", "],
          NSStringFromClass(self),
          methodName,
          NSStringFromClass(self));
}

+ (void)registerMixInClass:(Class)mixInClass {
    if (self == mixInClass)
        return;
    
    NSMutableSet *mixInClasses = objc_getAssociatedObject(self, &MixInClassesKey);
    
    if (mixInClasses == nil) {
        mixInClasses = [NSMutableSet new];
        objc_setAssociatedObject(self, &MixInClassesKey, mixInClasses, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    unsigned int count;
    Method *instanceMethodList = class_copyMethodList(mixInClass, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        
        Method method = instanceMethodList[i];
        SEL selector = method_getName(method);
        
        IMP selfMethodImplementation = class_getMethodImplementation(self, selector);

        [mixInClasses enumerateObjectsUsingBlock:^(Class registeredMixInClass, BOOL *stop) {
            if ([registeredMixInClass instancesRespondToSelector:selector]) {
                IMP registeredMixInImplementation = class_getMethodImplementation(registeredMixInClass, selector);
                
                if (registeredMixInImplementation == selfMethodImplementation) {
                    [self warnDuplicatedMixIns:[NSSet setWithArray:@[registeredMixInClass, mixInClass]]
                                   forSelector:selector instance:YES];
                }
            }
        }];
        
        IMP implementation = class_getMethodImplementation(mixInClass, selector);
        const char *types = method_getTypeEncoding(method);

        class_addMethod(self, selector, implementation, types);
        class_addMethod(self, sel_regixterMixIn(mixInClass, selector), implementation, types);
    }
    
    free(instanceMethodList);
    
    Method *classMethodList = class_copyMethodList(object_getClass(mixInClass), &count);
    
    for (unsigned int i = 0; i < count; i++) {
        
        Method method = classMethodList[i];
        SEL selector = method_getName(method);
        
        IMP selfMethodImplementation = class_getMethodImplementation(object_getClass(self), selector);
        
        [mixInClasses enumerateObjectsUsingBlock:^(Class registeredMixInClass, BOOL *stop) {
            if ([registeredMixInClass respondsToSelector:selector]) {
                IMP registeredMixInImplementation = class_getMethodImplementation(object_getClass(registeredMixInClass), selector);
                
                if (registeredMixInImplementation == selfMethodImplementation) {
                    [self warnDuplicatedMixIns:[NSSet setWithArray:@[registeredMixInClass, mixInClass]]
                                   forSelector:selector instance:NO];
                }
            }
        }];

        IMP implementation = class_getMethodImplementation(object_getClass(mixInClass), selector);
        const char *types = method_getTypeEncoding(method);
        
        class_addMethod(object_getClass(self), selector, implementation, types);
        class_addMethod(self, sel_regixterMixIn(mixInClass, selector), implementation, types);
    }
    
    free(classMethodList);
    
    [mixInClasses addObject:mixInClass];
}

+ (NSSet *)mixInClasses {
    return objc_getAssociatedObject(self, &MixInClassesKey);
}

- (NSSet *)mixInClasses {
    return objc_getAssociatedObject([self class], &MixInClassesKey);
}

+ (BOOL)mixedIn {
    NSMutableSet *mixInClasses = objc_getAssociatedObject(self, &MixInClassesKey);
    return mixInClasses != nil;
}

@end

