//
//  STMPersistingTransaction.h
//  iSisSales
//
//  Created by Alexander Levin on 18/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMPersistingTransaction

- (NSUInteger)destroyWithoutSave:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error;

- (NSDictionary *)mergeWithoutSave:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options error:(NSError **)error;

- (NSDictionary *)updateWithoutSave:(NSString *)entityName
                         attributes:(NSDictionary *)attributes
                            options:(NSDictionary *)options
                              error:(NSError **)error;


@optional

- (NSArray <NSDictionary *> *)findAllSync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options error:(NSError **)error;

- (NSArray *)findAllSync:(NSString *)name
               predicate:(NSPredicate *)predicate
                 orderBy:(NSString *)orderBy
               ascending:(BOOL)ascending
              fetchLimit:(NSUInteger)fetchLimit
             fetchOffset:(NSUInteger)fetchOffset;

@end
