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
#define TEST_PATH @"testPath"

#define TEST_DATA_MODEL_NAME @"testModel"


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
    
    NSString *path = [[NSBundle mainBundle] pathForResource:name
                                                     ofType:@"momd"];
    
    if (!path) path = [[NSBundle mainBundle] pathForResource:name
                                                      ofType:@"mom"];
    
    if (!path) {
        
        NSLog(@"there is no path for data model with name %@", name);
        return nil;
        
    }
    
    return path;

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

    NSString *orgPath = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG];

    NSError *error = nil;

    BOOL result = [self.filing removeItemAtPath:orgPath
                                          error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    result = [fm fileExistsAtPath:orgPath];
    
    XCTAssertFalse(result);
    
    [super tearDown];
    
}

- (void)testDirectoring {
    
    NSString *userPath = [[[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG] stringByAppendingPathComponent:TEST_UID];
    NSString *sharedPath = [[[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG] stringByAppendingPathComponent:SHARED_PATH];
    
    XCTAssertEqualObjects(userPath, [self.directoring userDocuments]);
    XCTAssertEqualObjects(sharedPath, [self.directoring sharedDocuments]);
    
    [self checkDirExists:userPath];
    
}

- (void)checkDirExists:(NSString *)dirPath {

    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isDir = NO;
    BOOL result = [fm fileExistsAtPath:dirPath
                           isDirectory:&isDir];
    
    XCTAssertEqual(result, YES);
    XCTAssertEqual(isDir, YES);

}

- (void)testFiling {
    
    [self persistencePathTest];
    [self picturesPathTest];
    [self webViewsPathTest];
    
    [self dataModelTesting];
    
}

- (void)persistencePathTest {
    
    NSString *rootPersistencePath = [[self.directoring userDocuments] stringByAppendingPathComponent:PERSISTENCE_PATH];
    NSString *persistencePath = [self.filing persistencePath:nil];
    XCTAssertEqualObjects(rootPersistencePath, persistencePath);

    [self checkDirExists:persistencePath];
    
    persistencePath = [rootPersistencePath stringByAppendingPathComponent:TEST_PATH];
    XCTAssertEqualObjects(persistencePath, [self.filing persistencePath:TEST_PATH]);

    [self checkDirExists:persistencePath];

}

- (void)picturesPathTest {
    
    NSString *rootPicturesPath = [[self.directoring sharedDocuments] stringByAppendingPathComponent:PICTURES_PATH];
    NSString *picturesPath = [self.filing picturesPath:nil];
    XCTAssertEqualObjects(rootPicturesPath, picturesPath);

    [self checkDirExists:picturesPath];

    picturesPath = [rootPicturesPath stringByAppendingPathComponent:TEST_PATH];
    XCTAssertEqualObjects(picturesPath, [self.filing picturesPath:TEST_PATH]);

    [self checkDirExists:picturesPath];

}

- (void)webViewsPathTest {
    
    NSString *rootWebViewsPath = [[self.directoring sharedDocuments] stringByAppendingPathComponent:WEBVIEWS_PATH];
    NSString *webViewsPath = [self.filing webViewsPath:nil];
    XCTAssertEqualObjects(rootWebViewsPath, webViewsPath);

    [self checkDirExists:webViewsPath];

    webViewsPath = [rootWebViewsPath stringByAppendingPathComponent:TEST_PATH];
    XCTAssertEqualObjects(webViewsPath, [self.filing webViewsPath:TEST_PATH]);

    [self checkDirExists:webViewsPath];

}

- (void)dataModelTesting {
    
    NSString *modelPath = [self.filing bundledModelFile:TEST_DATA_MODEL_NAME];
    NSString *testPath = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:TEST_DATA_MODEL_NAME];

    BOOL result = [modelPath hasPrefix:testPath];
    
    XCTAssertTrue(result);
    
}


@end
