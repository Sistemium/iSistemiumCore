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
                                 fetchLimit:(NSUInteger)fetchLimit
                                fetchOffset:(NSUInteger)fetchOffset;

- (BOOL)hasTable:(NSString *)name;

NS_ASSUME_NONNULL_END

@end
