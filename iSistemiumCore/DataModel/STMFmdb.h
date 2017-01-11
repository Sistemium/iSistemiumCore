//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

@interface STMFmdb : NSObject

+ (STMFmdb * _Nonnull)sharedInstance;
- (NSArray * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name withPredicate:(NSPredicate * _Nonnull)predicate;
- (NSDictionary * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary;
- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name;
- (NSArray * _Nonnull) allKeysForObject:(NSString * _Nonnull)obj;
- (BOOL) commit;

@end
