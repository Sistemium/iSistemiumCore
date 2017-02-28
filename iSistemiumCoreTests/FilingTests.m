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
#define PERSISTENCE_PATH @"persistence"
#define PICTURES_PATH @"pictures"
#define WEBVIEWS_PATH @"webViews"


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

@synthesize directoring = _directoring;


#pragma mark - STMFiling

- (NSString *)persistencePath:(NSString *)folderName {
    
    NSString *persistencePath = [[self.directoring userDocuments] stringByAppendingPathComponent:PERSISTENCE_PATH];
    NSString *resultPath = [persistencePath stringByAppendingPathComponent:folderName];
    
    return [STMFunctions dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;

}

- (NSString *)picturesPath:(NSString *)folderName {

    NSString *picturesPath = [[self.directoring sharedDocuments] stringByAppendingPathComponent:PICTURES_PATH];
    NSString *resultPath = [picturesPath stringByAppendingPathComponent:folderName];
    
    return [STMFunctions dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;

}

- (NSString *)webViewsPath:(NSString *)folderName {

    NSString *webViewsPath = [[self.directoring sharedDocuments] stringByAppendingPathComponent:WEBVIEWS_PATH];
    NSString *resultPath = [webViewsPath stringByAppendingPathComponent:folderName];
    
    return [STMFunctions dirExistsOrCreateItAtPath:resultPath] ? resultPath : nil;

}

- (BOOL)copyFile:(NSString *)filePath toPath:(NSString *)newPath {
    return YES;
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL result = [fm removeItemAtPath:path
                                 error:error];
    return result;
    
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
    
    STMFiling *filing = [[STMFiling alloc] init];
    filing.directoring = self.directoring;

    self.filing = filing;
    
}

- (void)tearDown {

    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *orgPath = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG];

    NSError *error = nil;
    BOOL result = [fm removeItemAtPath:orgPath
                                 error:&error];
    
    XCTAssertEqual(result, YES);
    XCTAssertNil(error);
    
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
