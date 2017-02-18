//
//  STMFmdb+Transactions.h
//  iSisSales
//
//  Created by Alexander Levin on 19/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Private.h"
#import "STMPersistingTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMFmdbTransaction : NSObject <STMPersistingTransaction>

+ (instancetype)persistingTransactionWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB;
- (instancetype)initWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB;

@end

@interface STMFmdbTransaction ()

@property (nonatomic,weak) FMDatabase *database;
@property (nonatomic,weak) STMFmdb *stmFMDB;

@end

@interface STMFmdb (Transactions)

- (NSString *)mergeInto:(NSString *)tablename
             dictionary:(NSDictionary<NSString *, id> *)dictionary
                  error:(NSError **)error
                     db:(FMDatabase *)db;

- (NSArray *)getDataWithEntityName:(NSString *)name
                     withPredicate:(NSPredicate *)predicate
                           orderBy:(NSString * _Nullable)orderBy
                         ascending:(BOOL)ascending
                        fetchLimit:(NSUInteger)fetchLimit
                       fetchOffset:(NSUInteger)fetchOffset
                                db:(FMDatabase *)db;

- (NSUInteger)destroy:(NSString *)tablename
            predicate:(NSPredicate * _Nullable)predicate
              options:(NSDictionary * _Nullable)options
                error:(NSError **)error
           inDatabase:(FMDatabase *)db;

- (NSDictionary *)update:(NSString *)tablename
              attributes:(NSDictionary<NSString *, id> *)attributes
                   error:(NSError **)error
              inDatabase:(FMDatabase *)db;

@end

NS_ASSUME_NONNULL_END
