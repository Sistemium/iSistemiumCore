//
//  FilingTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 28/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "STMFiling.h"
#import "STMFunctions.h"

#define TEST_ORG @"testOrg"
#define TEST_UID @"testUid"
#define SHARED_PATH @"shared"


@interface FilingTests : XCTestCase

@property (nonatomic, strong) id <STMDirectoring> directoring;
@property (nonatomic, strong) id <STMFiling> filing;


@end


@interface STMDirectoring : NSObject <STMDirectoring>

@property (nonatomic, strong) NSString *org;
@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *documentsPath;
@property (nonatomic, strong) NSString *orgPath;


@end


@implementation STMDirectoring

#pragma mark - STMDirectoring

- (instancetype)initWithOrg:(NSString *)org userId:(NSString *)uid {
    
    self = [super init];
    
    if (self) {
        
        self.org = org;
        self.uid = uid;
        
    }
    return self;
    
}

- (NSString *)documentsPath {
    
    if (!_documentsPath) {
        _documentsPath = [STMFunctions documentsDirectory];
    }
    return _documentsPath;
    
}

- (void)setOrg:(NSString *)org {
    
    _org = org;
    
    self.orgPath = [self.documentsPath stringByAppendingPathComponent:org];
    
    [STMFunctions dirExistsOrCreateItAtPath:self.orgPath];
    
}

- (NSString *)userDocuments {

    NSString *userPath = [self.orgPath stringByAppendingPathComponent:self.uid];
    return [STMFunctions dirExistsOrCreateItAtPath:userPath] ? userPath : nil;
    
}

- (NSString *)sharedDocuments {

    NSString *sharedPath = [self.orgPath stringByAppendingPathComponent:SHARED_PATH];
    return [STMFunctions dirExistsOrCreateItAtPath:sharedPath] ? sharedPath : nil;

}


@end


@interface STMFiling : NSObject <STMFiling>

@end


@implementation STMFiling

#pragma mark - STMFiling

- (NSString *)persistencePath:(NSString *)folderName {
    return nil;
}

- (NSString *)picturesPath:(NSString *)folderName {
    return nil;
}

- (NSString *)webViewsPath:(NSString *)folderName {
    return nil;
}

- (BOOL)copyFile:(NSString *)filePath toPath:(NSString *)newPath {
    return nil;
}

- (NSString *)bundledModelFile:(NSString *)name {
    return nil;
}


@end


@implementation FilingTests

- (void)setUp {
    
    [super setUp];
    
    self.directoring = [[STMDirectoring alloc] initWithOrg:TEST_ORG
                                                    userId:TEST_UID];
    self.filing = [[STMFiling alloc] init];
    
}

- (void)tearDown {

    [super tearDown];
    
}

- (void)testDirectoring {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *userPath = [[[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG] stringByAppendingPathComponent:TEST_UID];
    NSString *sharedPath = [[[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG] stringByAppendingPathComponent:SHARED_PATH];
    
    XCTAssertEqualObjects(userPath, [self.directoring userDocuments]);
    XCTAssertEqualObjects(sharedPath, [self.directoring sharedDocuments]);
    
    BOOL isDir = NO;
    BOOL result = [fm fileExistsAtPath:userPath
                           isDirectory:&isDir];
    
    XCTAssertEqual(result, YES);
    XCTAssertEqual(isDir, YES);
    
}



@end
