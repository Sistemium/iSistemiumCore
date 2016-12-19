//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

@interface STMFmdb : NSObject

+ (STMFmdb * _Nonnull)sharedInstance;
- (NSArray<NSDictionary *> * _Nonnull)getDataWithEntityName:(NSString * _Nonnull)name;
- (void)insertWithTablename:(NSString * _Nonnull)tablename array:(NSArray<NSDictionary<NSString *, id> *> * _Nonnull)array withCompletionHandler:(void (^ _Nonnull)(BOOL success))completionHandler;
- (void)insertWithTablename:(NSString * _Nonnull)tablename dictionary:(NSDictionary<NSString *, id> * _Nonnull)dictionary withCompletionHandler:(void (^ _Nonnull)(BOOL success))completionHandler;
- (BOOL)containstTableWithNameWithName:(NSString * _Nonnull)name;

@end
