//
//  STMRemoteDataEventHandling.h
//  iSisSales
//
//  Created by Alexander Levin on 10/07/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMRemoteDataEventHandling

- (void)remoteHasNewData:(NSString *)entityName;

- (void)remoteUpdated:(NSString *)entityName attributes:(NSDictionary *)attributes;

- (void)remoteDestroyed:(NSString *)entityName identifier:(NSString *)identifier;

@end
