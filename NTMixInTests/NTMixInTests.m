//
//  NTMixInTests.m
//  NTMixInTests
//
//  Created by Nickolay Tarbayev on 19.05.14.
//  Copyright (c) 2014 Tarbayev. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NTMixIn.h"
#include <asl.h>


@protocol TestMixInProtocol <NSObject>
@optional
- (int)mixInMethod;

@end


@interface TestMixInClass1 : NSObject <TestMixInProtocol>
@end


@implementation TestMixInClass1

- (int)mixInMethod {
    return 1;
}

@end


@interface TestMixInClass2 : NSObject <TestMixInProtocol>
@end


@implementation TestMixInClass2

- (int)mixInMethod {
    return 2;
}

@end


@interface TestClassUseMixIn : NSObject <TestMixInProtocol>
@end


@implementation TestClassUseMixIn

+ (void)initialize {
    UseMixIn(TestMixInClass1);
}

@end


@interface TestClassMixInOverrided : NSObject <TestMixInProtocol>
@end


@implementation TestClassMixInOverrided

+ (void)initialize {
    UseMixIn(TestMixInClass1);
}

- (int)mixInMethod {
    return 3;
}

@end


@interface TestClassMixInCollision : NSObject <TestMixInProtocol>
@end


@implementation TestClassMixInCollision

+ (void)initialize {
    UseMixIn(TestMixInClass1);
    UseMixIn(TestMixInClass2);
}

@end


@interface TestClassMixInCollisionResolved : NSObject <TestMixInProtocol>
@end


@implementation TestClassMixInCollisionResolved

+ (void)initialize {
    UseMixIn(TestMixInClass1);
    UseMixIn(TestMixInClass2);
}

- (int)mixInMethod {
    return [MixIn(TestMixInClass2) mixInMethod];
}

@end


static NSArray *readLogMessages() {
    
    aslclient client = asl_open(NULL, NULL, ASL_OPT_STDERR);
    
    aslmsg query = asl_new(ASL_TYPE_QUERY);
    asl_set_query(query, ASL_KEY_MSG, NULL, ASL_QUERY_OP_NOT_EQUAL);
    aslresponse response = asl_search(client, query);
    
    asl_free(query);
    
    NSMutableArray *result = [NSMutableArray new];
    
    aslmsg message;
    while((message = aslresponse_next(response)))
    {
        const char *msg = asl_get(message, ASL_KEY_MSG);
        [result addObject:[NSString stringWithFormat:@"%s" , msg]];
    }

    return result;
}


@interface NTMixInTests : XCTestCase

@end

@implementation NTMixInTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testUseMixIn {
    
    TestClassUseMixIn *instance = [TestClassUseMixIn new];
    
    XCTAssertTrue([instance respondsToSelector:@selector(mixInMethod)], @"method 'mixInMethod' has not been added");
    XCTAssert([instance mixInMethod] == 1, @"Method 'mixInMethod' returns wrong value");
}

- (void)testOverrideMixIn {
    
    TestClassMixInOverrided *instance = [TestClassMixInOverrided new];

    XCTAssert([instance mixInMethod] == 3, @"Method 'mixInMethod' returns wrong value. Failed to override mixIn's method");
}

- (void)testMixInCollision {
    
    static NSString *const markerMessage = @"testMixInCollision marker log message";
    
    NSLog(markerMessage);
    
    [TestClassMixInCollision new];
    
    NSArray *logMessages = readLogMessages();
    
    XCTAssertTrue([logMessages[logMessages.count - 2] isEqualToString:markerMessage], @"No marker message in log. Log system seems not working correctly");
    
    XCTAssertTrue([[logMessages lastObject] hasPrefix:@"WARNING: Multiple implementation of method"], @"No collision warning printed to log");
}

- (void)testMixInCollisionResolved {
    
    static NSString *const markerMessage = @"testMixInCollisionResolved marker log message";
    
    NSLog(markerMessage);
    
    TestClassMixInCollisionResolved *instance = [TestClassMixInCollisionResolved new];
    
    NSArray *logMessages = readLogMessages();
    
    XCTAssertTrue([[logMessages lastObject] isEqualToString:markerMessage], @"Unexpected log message");
    XCTAssert([instance mixInMethod] == 2, @"'mixInMethod' returns wrong value");
}

@end
