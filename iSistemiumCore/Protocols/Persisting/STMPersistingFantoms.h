//
//  STMPersistingFantoms.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"


@protocol STMPersistingFantoms <NSObject>

@property (nonatomic, weak) id <STMPersistingSync, STMPersistingAsync> persistenceDelegate;

- (NSArray *)findAllFantomsIdsSync:(NSString *)entityName
                      excludingIds:(NSArray *)excludingIds;

- (BOOL)destroyFantomSync:(NSString *)entityName
               identifier:(NSString *)identifier;

- (NSDictionary *)mergeFantomSync:(NSString *)entityName
                       attributes:(NSDictionary *)attributes
                            error:(NSError **)error;


- (void)mergeFantomAsync:(NSString *)entityName
              attributes:(NSDictionary *)attributes
                callback:(STMPersistingAsyncDictionaryResultCallback)callback;

@end
