//
//  ModelVersioningTests.m
//  iSisSales
//
//  Created by Alexander Levin on 26/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "<CoreData/CoreData.h"
#import "STMFunctions.h"

@interface ModelVersioningTests : XCTestCase

//@property (nonatomic,strong) STMModelVersioner *versioner;

@end

@implementation ModelVersioningTests

- (void)setUp {
    [super setUp];
//    self.versioner = self;
}

- (void)testExample {
    
    NSError *error = nil;
    NSMappingModel *mappingModel;
    
    XCTAssertNil(error);
    
    XCTAssertNotNil(mappingModel, @"documentsModel was empty or can't create it or the same as bundleModel, should use the last one");

    [self parseMappingModel:mappingModel];
}


- (NSManagedObjectModel *)modelWithPath:(NSString *)modelPath {
    
    if (!modelPath) return nil;
    
    NSURL *url = [NSURL fileURLWithPath:modelPath];
    
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    
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


#pragma mark - check data models

- (NSMappingModel *)checkDataModelsWithBundlePath:(NSString *)bundlePath error:(NSError **)error {
    
    NSString *modelDirInDocuments = [[STMFunctions documentsDirectory] stringByAppendingPathComponent:@"model"];
    
    if (![STMFunctions dirExistsOrCreateItAtPath:modelDirInDocuments]) return nil;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *documentsModelPath = [modelDirInDocuments stringByAppendingPathComponent:bundlePath.lastPathComponent];
    
    NSManagedObjectModel *documentsModel = [fm fileExistsAtPath:documentsModelPath] ? [self modelWithPath:documentsModelPath] : nil;
    
    if (!documentsModel) {
        
        [self copyModelToPath:modelDirInDocuments
                     fromPath:bundlePath];
        return nil;
        
    }
    
    NSManagedObjectModel *bundleModel = [self modelWithPath:bundlePath];
    
    if ([bundleModel isEqual:documentsModel]) {
        
        NSLog(@"model have no changes");
        return nil;
        
    }
    
    NSLog(@"!!! model have changes, old should be replaced with new one !!!");
    
#warning - maybe copy new model to Documents only after successful creating of db with the new model
    
    [self copyModelToPath:modelDirInDocuments
                 fromPath:bundlePath];
    
    NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:documentsModel destinationModel:bundleModel error:error];
    
    if (!mappingModel) {
        NSLog(@"mappingModel error: %@, userInfo: %@", [*error localizedDescription], [*error userInfo]);
    }
    
    return mappingModel;
    
}

- (BOOL)copyModelToPath:(NSString *)newPath fromPath:(NSString *)modelPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *modelInDocuments = [newPath stringByAppendingPathComponent:modelPath.lastPathComponent];
    
    if ([fm fileExistsAtPath:modelInDocuments]) {
        if (![STMFunctions flushDirAtPath:newPath]) return NO;
    }
    
    NSError *error = nil;
    BOOL result = [fm copyItemAtPath:modelPath
                              toPath:modelInDocuments
                               error:&error];
    
    if (!result) {
        
        NSLog(@"can't copy model, error: %@", error.localizedDescription);
        return NO;
        
    } else {
        
        NSLog(@"model copy successfully");
        
    }
    
    result = [STMFunctions enumerateDirAtPath:newPath withBlock:^BOOL(NSString *path, NSError **error) {
        
        BOOL enumResult = [fm setAttributes:@{ATTRIBUTE_FILE_PROTECTION_NONE}
                               ofItemAtPath:path
                                      error:error];
        
        if (!enumResult) {
            NSLog(@"can't set attributes to %@, error: %@", path, [*error localizedDescription]);
        } else {
            NSLog(@"set attributes to %@", path);
        }
        
        return enumResult;
        
    }];
    
    return result;
    
}

@end
