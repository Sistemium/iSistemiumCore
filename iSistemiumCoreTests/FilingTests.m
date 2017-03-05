//
//  FilingTests.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 28/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <CoreData/CoreData.h>

#import "STMCoreSessionFiler.h"
#import "STMFunctions.h"


#define TEST_PATH @"testPath"

#define TEST_ORG @"testOrg"
#define TEST_UID @"testUid"

#define TEST_DATA_MODEL_NAME @"testModel"
#define TEST_CHANGED_DATA_MODEL_NAME @"testModelChanged"


@interface STMTestDirectoring : STMCoreSessionFiler

@end


@implementation STMTestDirectoring

- (NSBundle *)bundle {
    return [STMFunctions currentTestTarget] ? [NSBundle bundleForClass:[self class]] : [NSBundle mainBundle];
}

@end


#pragma mark -

@interface FilingTests : XCTestCase

@property (nonatomic, strong) id <STMDirectoring> directoring;
@property (nonatomic, strong) id <STMFiling> filing;


@end


#pragma mark -

@implementation FilingTests

- (void)setUp {
    
    [super setUp];
    
    self.directoring = [[STMTestDirectoring alloc] initWithOrg:TEST_ORG userId:TEST_UID];
    self.filing = [STMCoreSessionFiler coreSessionFilerWithDirectoring:self.directoring];
    
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
    
    [self firstTimeDataModelCheck];
    [self compareBundledAndUserDataModels];
    
}

- (void)firstTimeDataModelCheck {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *userDataModelPath = [self.filing userModelFile:TEST_DATA_MODEL_NAME];
    
    BOOL result = [fm fileExistsAtPath:userDataModelPath];
    
    XCTAssertFalse(result);
    
    [self copyBundledDataModelToUsersDocs:TEST_DATA_MODEL_NAME];
    
}

- (void)compareBundledAndUserDataModels {

    NSFileManager *fm = [NSFileManager defaultManager];
    
// check userDataModel exists
    NSString *userDataModelPath = [self.filing userModelFile:TEST_DATA_MODEL_NAME];
    
    BOOL result = [fm fileExistsAtPath:userDataModelPath];
    XCTAssertTrue(result);
    
// for tests here use TEST_CHANGED_DATA_MODEL_NAME as bundled dataModel's name
    
    NSString *bundledDataModelPath = [self.filing bundledModelFile:TEST_CHANGED_DATA_MODEL_NAME];

    result = [fm fileExistsAtPath:bundledDataModelPath];
    XCTAssertTrue(result);

// compare user's and bundled data models
    NSManagedObjectModel *userDataModel = [self modelWithPath:userDataModelPath];
    NSManagedObjectModel *bundledDataModel = [self modelWithPath:bundledDataModelPath];
    
    result = [userDataModel isEqual:bundledDataModel];
    XCTAssertFalse(result);
    
// check mappingModel
/*
 
 for example:
    mapping model can not be created if we change property type
    
    here the error if TestEntity1.attribute1 type changed from String to Binary Data:
 
        mappingModel error: The operation couldn’t be completed. (Cocoa error 134190.), 
        userInfo: {
            entity = TestEntity1;
            property = attribute1;
            reason = "Source and destination attribute types are incompatible";
        }
 
*/
    NSError *error = nil;
    NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:userDataModel
                                                                     destinationModel:bundledDataModel
                                                                                error:&error];
    if (!mappingModel) {
        NSLog(@"mappingModel error: %@, userInfo: %@", error.localizedDescription, error.userInfo);
    }
    XCTAssertNotNil(mappingModel);
    
    [self parseMappingModel:mappingModel];

// copy bundeled to user
    [self copyBundledDataModelToUsersDocs:TEST_CHANGED_DATA_MODEL_NAME];

// check new user's data model
    userDataModelPath = [self.filing userModelFile:TEST_CHANGED_DATA_MODEL_NAME];
    
    result = [fm fileExistsAtPath:userDataModelPath];
    XCTAssertTrue(result);

// compare bundeled and new user's data model
    userDataModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL URLWithString:userDataModelPath]];

    result = [userDataModel isEqual:bundledDataModel];
    XCTAssertTrue(result);

}

- (NSManagedObjectModel *)modelWithPath:(NSString *)modelPath {
    
    if (!modelPath) return nil;
    
    NSURL *url = [NSURL fileURLWithPath:modelPath];
    
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
}

- (void)copyBundledDataModelToUsersDocs:(NSString *)bundledDataModelName {
    
    NSString *modelPath = [self.filing bundledModelFile:bundledDataModelName];
    NSString *testPath = [[self.directoring bundle].bundlePath stringByAppendingPathComponent:bundledDataModelName];
    
    BOOL result = [modelPath hasPrefix:testPath];
    
    XCTAssertTrue(result);
    
    NSString *persistencePath = [self.filing persistencePath:nil];
    
    NSError *error = nil;
    result = [self.filing copyItemAtPath:modelPath
                                  toPath:persistencePath
                                   error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self checkPathForProtectionNone:persistencePath];
    
}

- (void)checkPathForProtectionNone:(NSString *)pathToCheck {
    
    // simulator does not have NSFileProtectionKey
#if !TARGET_OS_SIMULATOR
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL result = [self.filing enumerateDirAtPath:pathToCheck withBlock:^BOOL(NSString * _Nonnull path, NSError * _Nullable __autoreleasing * _Nullable error) {
        
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


#pragma mark - parse mapping model

- (void)parseMappingModel:(NSMappingModel *)mappingModel {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType != %d", NSCopyEntityMappingType];
    NSArray *changedEntityMappings = [mappingModel.entityMappings filteredArrayUsingPredicate:predicate];
    
    NSArray *entityMappingTypes = @[@(NSAddEntityMappingType),
                                    @(NSCustomEntityMappingType),
                                    @(NSRemoveEntityMappingType),
                                    @(NSTransformEntityMappingType),
                                    @(NSUndefinedEntityMappingType)];
    
    for (NSNumber *mapType in entityMappingTypes) {
        
        NSUInteger mappingType = mapType.integerValue;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType == %d", mappingType];
        NSArray *result = [changedEntityMappings filteredArrayUsingPredicate:predicate];
        
        if (result.count) {
            
            switch (mappingType) {
                case NSAddEntityMappingType:
                    [self parseAddEntityMappings:result];
                    break;
                    
                case NSCustomEntityMappingType:
                    [self parseCustomEntityMappings:result];
                    break;
                    
                case NSRemoveEntityMappingType:
                    [self parseRemoveEntityMappings:result];
                    break;
                    
                case NSTransformEntityMappingType:
                    [self parseTransformEntityMappings:result];
                    break;
                    
                case NSUndefinedEntityMappingType:
                    [self parseUndefinedEntityMappings:result];
                    break;
                    
                default:
                    break;
            }
            
        }
        
    }
    
}

- (void)parseAddEntityMappings:(NSArray *)addEntityMappings {
    
    //    NSLog(@"addEntityMappings %@", addEntityMappings);
    NSLog(@"!!! next entities should be added: ");
    
    for (NSEntityMapping *entityMapping in addEntityMappings) {
        
        NSLog(@"!!! add %@", entityMapping.destinationEntityName);
        
    }
    
}

- (void)parseCustomEntityMappings:(NSArray *)customEntityMappings {
    NSLog(@"customEntityMappings %@", customEntityMappings);
}

- (void)parseRemoveEntityMappings:(NSArray *)removeEntityMappings {
    
    //    NSLog(@"removeEntityMappings %@", removeEntityMappings);
    NSLog(@"!!! next entities should be removed: ");
    
    for (NSEntityMapping *entityMapping in removeEntityMappings) {
        
        NSLog(@"!!! remove %@", entityMapping.sourceEntityName);
        
    }
    
}

- (void)parseTransformEntityMappings:(NSArray *)transformEntityMappings {
    
    //    NSLog(@"transformEntityMappings %@", transformEntityMappings);
    NSLog(@"!!! next entities should be transformed: ");
    
    for (NSEntityMapping *entityMapping in transformEntityMappings) {
        
        NSLog(@"!!! transform %@", entityMapping.destinationEntityName);
        
        NSSet *addedProperties = entityMapping.userInfo[@"addedProperties"];
        if (addedProperties.count) {
            for (NSString *propertyName in addedProperties) {
                NSLog(@"    !!! add property: %@", propertyName);
            }
        }
        
        NSSet *removedProperties = entityMapping.userInfo[@"removedProperties"];
        if (removedProperties.count) {
            for (NSString *propertyName in removedProperties) {
                NSLog(@"    !!! remove property: %@", propertyName);
            }
        }
        
        NSSet *mappedProperties = entityMapping.userInfo[@"mappedProperties"];
        if (mappedProperties.count) {
            for (NSString *propertyName in mappedProperties) {
                NSLog(@"    !!! remains the same property: %@", propertyName);
            }
        }
        
    }
    
}

- (void)parseUndefinedEntityMappings:(NSArray *)undefinedEntityMappings {
    NSLog(@"undefinedEntityMappings %@", undefinedEntityMappings);
}


@end
