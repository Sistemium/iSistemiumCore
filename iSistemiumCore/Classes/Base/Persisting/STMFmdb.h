//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMModelling.h"

@interface STMFmdb : NSObject

- (instancetype _Nonnull)initWithModelling:(id <STMModelling> _Nonnull)modelling;

- (NSUInteger)count:(NSString * _Nonnull)name
      withPredicate:(NSPredicate * _Nonnull)predicate;

- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name
                              withPredicate:(NSPredicate * _Nonnull)predicate
                                    orderBy:(NSString * _Nullable)orderBy
                                  ascending:(BOOL)ascending
                                 fetchLimit:(NSUInteger * _Nullable)fetchLimit
                                fetchOffset:(NSUInteger * _Nullable)fetchOffset;

- (BOOL)mergeInto:(NSString * _Nonnull)tablename
       dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary
            error:(NSError *_Nonnull * _Nonnull)error;

- (NSDictionary * _Nonnull)update:(NSString * _Nonnull)tablename
                       attributes:(NSDictionary<NSString *, id> * _Nonnull)attributes
                            error:(NSError *_Nonnull * _Nonnull)error;

- (NSDictionary * _Nullable)mergeIntoAndResponse:(NSString * _Nonnull)tablename
                                      dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary
                                           error:(NSError *_Nonnull * _Nonnull)error;

- (NSUInteger)destroy:(NSString * _Nonnull)tablename
            predicate:(NSPredicate* _Nonnull)predicate
                error:(NSError *_Nonnull * _Nonnull)error;

- (BOOL)hasTable:(NSString * _Nonnull)name;

- (BOOL)commit;
- (BOOL)startTransaction;
- (BOOL)rollback;


@end
