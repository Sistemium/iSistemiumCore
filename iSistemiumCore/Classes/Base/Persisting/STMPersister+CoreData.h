//
//  STMPersister+CoreData.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 26/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister.h"

@interface STMPersister (CoreData)

- (void)removeObjects:(NSArray*)objects;

- (NSUInteger)removeObjectForPredicate:(NSPredicate*)predicate
                      entityName:(NSString *)name;

- (NSDictionary *)mergeWithoutSave:entityName
                        attributes:(NSDictionary *)attributes
                           options:(NSDictionary *)options
                             error:(NSError **)error
            inManagedObjectContext:(NSManagedObjectContext *)context;

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate
                      entityName:(NSString *)entityName;

- (NSArray *)objectsForEntityName:(NSString *)entityName
                          orderBy:(NSString *)orderBy
                        ascending:(BOOL)ascending
                       fetchLimit:(NSUInteger)fetchLimit
                      fetchOffset:(NSUInteger)fetchOffset
                      withFantoms:(BOOL)withFantoms
                        predicate:(NSPredicate *)predicate
                       resultType:(NSFetchRequestResultType)resultType
           inManagedObjectContext:(NSManagedObjectContext *)context
                            error:(NSError **)error;

- (NSDictionary *)update:(NSString *)entityName
              attributes:(NSDictionary *)attributes
                 options:(NSDictionary *)options
                   error:(NSError **)error
  inManagedObjectContext:(NSManagedObjectContext *)context;

- (NSArray *)arrayForJSWithObjects:(NSArray <STMDatum *> *)objects;

@end
