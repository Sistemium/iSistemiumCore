//
//  STMModelMapper.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/03/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModelMapper.h"

#import "STMModeller.h"
#import "STMFunctions.h"


@implementation STMModelMapper

@synthesize sourceModel = _sourceModel;
@synthesize sourceModeling = _sourceModeling;
@synthesize destinationModel = _destinationModel;
@synthesize destinationModeling = _destinationModeling;
@synthesize mappingModel = _mappingModel;
@synthesize migrationManager = _migrationManager;
@synthesize addedEntities = _addedEntities;


- (instancetype)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel error:(NSError **)error {
    
    self = [super init];
    
    if (self) {
    
        _sourceModel = sourceModel;
        _sourceModeling = [STMModeller modellerWithModel:sourceModel];
        
        _destinationModel = destinationModel;
        _destinationModeling = [STMModeller modellerWithModel:destinationModel];
        
        _mappingModel = [NSMappingModel inferredMappingModelForSourceModel:sourceModel
                                                          destinationModel:destinationModel
                                                                     error:error];
        
        _migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                           destinationModel:destinationModel];
        
    }
    
    return self;
    
}


#pragma mark - STMModelMapping

- (NSArray <NSEntityDescription *> *)addedEntities {
    
    if (!_addedEntities) {
        _addedEntities = [self mappedEntitiesWithType:NSAddEntityMappingType];
    }
    return _addedEntities;

}

- (NSArray <NSEntityDescription *> *)mappedEntitiesWithType:(NSEntityMappingType)mappingType {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mappingType == %d", mappingType];
    NSArray <NSEntityMapping *> *entityMappings = [self.mappingModel.entityMappings filteredArrayUsingPredicate:predicate];
    
    NSArray <NSEntityDescription *> *result = [STMFunctions mapArray:entityMappings withBlock:^id _Nonnull(NSEntityMapping *  _Nonnull entityMapping) {
        return [self.migrationManager destinationEntityForEntityMapping:entityMapping];
    }];
    
    return result;
    
}


@end
