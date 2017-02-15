//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMModelling.h"

@interface STMFmdb : NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithModelling:(id <STMModelling>)modelling fileName:(NSString *)fileName;

- (NSUInteger)count:(NSString *)name
      withPredicate:(NSPredicate *)predicate;

- (NSArray *)getDataWithEntityName:(NSString *)name
                              withPredicate:(NSPredicate *)predicate
                                    orderBy:(NSString * _Nullable)orderBy
                                  ascending:(BOOL)ascending
                                 fetchLimit:(NSUInteger * _Nullable)fetchLimit
                                fetchOffset:(NSUInteger * _Nullable)fetchOffset;

- (BOOL)mergeInto:(NSString *)tablename
       dictionary:(NSDictionary<NSString *, id> *)dictionary
            error:(NSError **)error;

- (NSDictionary *)update:(NSString *)tablename
                       attributes:(NSDictionary<NSString *, id> *)attributes
                            error:(NSError **)error;

- (NSDictionary * _Nullable)mergeIntoAndResponse:(NSString *)tablename
                                      dictionary:(NSDictionary<NSString *, id> *)dictionary
                                           error:(NSError **)error;

- (NSUInteger)destroy:(NSString *)tablename
            predicate:(NSPredicate*)predicate
              options:(NSDictionary *)options 
                error:(NSError **)error;

- (BOOL)hasTable:(NSString *)name;

- (BOOL)commit;
- (BOOL)startTransaction;
- (BOOL)rollback;

NS_ASSUME_NONNULL_END

@end
