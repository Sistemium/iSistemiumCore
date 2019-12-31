//
//  STMModeller.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "STMModelling.h"
#import "STMPersistingObservable.h"

@interface STMModeller : STMPersistingObservable <STMModelling>

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;

- (instancetype)initWithModelName:(NSString *)modelName;

- (instancetype)initWithModel:(NSManagedObjectModel *)model;

+ (NSManagedObjectModel *)modelWithName:(NSString *)modelName;

+ (instancetype)modellerWithModel:(NSManagedObjectModel *)model;

+ (NSManagedObjectModel *)modelWithPath:(NSString *)modelPath;

@end
