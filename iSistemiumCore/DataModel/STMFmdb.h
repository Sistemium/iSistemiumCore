//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

@interface STMFmdb : NSObject

+ (STMFmdb * _Nonnull)sharedInstance;
- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate orderBy:(NSString * _Nullable)orderBy fetchLimit:(NSUInteger * _Nullable)fetchLimit fetchOffset:(NSUInteger * _Nullable)fetchOffset;
- (BOOL)mergeInto:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error;
- (NSDictionary * _Nullable)mergeIntoAndResponse:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary error:(NSError *_Nonnull * _Nonnull)error;
- (BOOL)destroy:(NSString * _Nonnull)tablename identifier:(NSString*  _Nonnull)idendifier error:(NSError *_Nonnull * _Nonnull)error;
- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name;
- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj;
- (BOOL) commit;
- (BOOL)startTransaction;
- (BOOL)rollback;

@end
