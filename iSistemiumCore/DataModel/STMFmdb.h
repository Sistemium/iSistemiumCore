//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

@import PromiseKit;

@interface STMFmdb : NSObject

+ (STMFmdb * _Nonnull)sharedInstance;
- (AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name;
- (AnyPromise * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename array:(NSArray<NSDictionary<NSString *, id> *> * _Nonnull)array;
- (AnyPromise * _Nonnull)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary;
-(AnyPromise * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name PK:(NSString * _Nonnull)PK;
- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name;

@end
