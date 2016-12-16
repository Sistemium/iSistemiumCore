//
//  STMFMDB_OBJC.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

@interface STMFMDB_OBJC : NSObject

- (instancetype _Nonnull)init;
- (NSArray<NSDictionary *> * _Nonnull)getDataByEntityNameWithName:(NSString * _Nonnull)name;

@end
