//
//  STMPersistingFantoms.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingSync.h"
#import "STMPersistingAsync.h"

@protocol STMPersistingFantoms <NSObject>

@property (nonatomic, weak) id <STMPersistingAsync,STMPersistingSync> persistenceDelegate;

- (NSArray *)findAllFantomsSync:(NSString *)entityName;

- (BOOL)destroyFantomSync:(NSString *)entityName
               identifier:(NSString *)identifier;

- (void)mergeFantomAsync:(NSString *)entityName
              attributes:(NSDictionary *)attributes
       completionHandler:(STMPersistingAsyncDictionaryResultCallback)completionHandler;


@end
