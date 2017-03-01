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


#pragma mark - interfaces

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


@interface STMFiling : NSObject <STMFiling>

@end


#pragma mark -

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


#pragma mark -

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

- (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error {

    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL sourceIsDir = NO;
    
    if (![fm fileExistsAtPath:sourcePath isDirectory:&sourceIsDir]) {
        return NO;
    }
    
    if ([fm fileExistsAtPath:destinationPath]) {
        if (![self removeItemAtPath:destinationPath error:error]) return NO;
    }
    
    BOOL result = [fm copyItemAtPath:sourcePath
                              toPath:destinationPath
                               error:error];
    
    if (!result) {
        
        NSLog(@"copyItemAtPath: %@ toPath: %@ error: %@", [*error localizedDescription]);
        return NO;
        
    }
    
    result = [self setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                    ofItemAtPath:destinationPath
                           error:error];
    
    if (!result) {
        return NO;
    }
    
    __block NSError *localError = nil;
    
    result = [STMFunctions enumerateDirAtPath:destinationPath withBlock:^BOOL(NSString *path, NSError **enumError) {
        
        localError = *enumError; // ???
        
        return [self setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                      ofItemAtPath:path
                             error:enumError];
        
    }];
    
    *error = localError; // ???
    
    return result;

}

- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL result = [fm setAttributes:attributes
                       ofItemAtPath:path
                              error:error];
    
    if (!result) {
        NSLog(@"set attribute NSFileProtectionNone ofItemAtPath: %@ error: %@", path, [*error localizedDescription]);
    }

    return result;
    
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


#pragma mark -

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


#pragma mark - tests

- (void)testDirectoring {
    
    NSString *orgPath = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:TEST_ORG];
    NSString *userPath = [orgPath stringByAppendingPathComponent:TEST_UID];
    NSString *sharedPath = [orgPath stringByAppendingPathComponent:SHARED_PATH];
    
    XCTAssertEqualObjects(userPath, [self.directoring userDocuments]);
    XCTAssertEqualObjects(sharedPath, [self.directoring sharedDocuments]);
    
    [self checkDirExists:userPath];
    
}

- (void)testFiling {
    
    [self persistencePathTest];
    [self picturesPathTest];
    [self webViewsPathTest];
    
    [self dataModelTesting];
    
}

- (void)checkDirExists:(NSString *)dirPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    BOOL result = [fm fileExistsAtPath:dirPath
                           isDirectory:&isDir];
    
    XCTAssertEqual(result, YES);
    XCTAssertEqual(isDir, YES);
    
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
    
    NSString *userModelPath = [self.filing persistencePath:nil];
    
    NSError *error = nil;
    result = [self.filing copyItemAtPath:modelPath
                                  toPath:userModelPath
                                   error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
#if !TARGET_OS_SIMULATOR

    NSFileManager *fm = [NSFileManager defaultManager];

    result = [STMFunctions enumerateDirAtPath:userModelPath withBlock:^BOOL(NSString * _Nonnull path, NSError * _Nullable __autoreleasing * _Nullable error) {
       
        NSDictionary *checkAttribute = @{ATTRIBUTE_FILE_PROTECTION_NONE};
        NSFileAttributeKey checkKey = checkAttribute.allKeys.firstObject;
        NSFileAttributeType checkValue = checkAttribute.allValues.firstObject;
        
        NSDictionary <NSFileAttributeKey, id> *attributes = [fm attributesOfItemAtPath:path
                                                                                 error:error];

        XCTAssertNil(*error);
        
        BOOL enumResult = [checkValue isEqual:attributes[checkKey]];
        
        XCTAssertTrue(enumResult);
        
        return enumResult;
        
    }];
    
    XCTAssertTrue(result);

#endif
    
}


@end
