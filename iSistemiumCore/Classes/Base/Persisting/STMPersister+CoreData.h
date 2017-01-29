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
- (void)removeObjectForPredicate:(NSPredicate*)predicate entityName:(NSString *)name;

- (NSArray *)objectsForPredicate:(NSPredicate *)predicate entityName:(NSString *)entityName;
- (NSArray *)objectsForEntityName:(NSString *)entityName;

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error;

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error;

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms predicate:(NSPredicate *)predicate inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error;

- (NSArray *)objectsForEntityName:(NSString *)entityName orderBy:(NSString *)orderBy ascending:(BOOL)ascending fetchLimit:(NSUInteger)fetchLimit fetchOffset:(NSUInteger)fetchOffset withFantoms:(BOOL)withFantoms predicate:(NSPredicate *)predicate resultType:(NSFetchRequestResultType)resultType inManagedObjectContext:(NSManagedObjectContext *)context error:(NSError **)error;

@end