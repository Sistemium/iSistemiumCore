//
//  STMPersistingObserving.h
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#define STMPersistingObservingSubscriptionID NSString *

typedef void (^STMPersistingObservingSubscriptionCallback)(NSArray * _Nullable data);

@protocol STMPersistingObserving

- (STMPersistingObservingSubscriptionID _Nonnull)observeEntity:(NSString * _Nonnull)entityName
                                                     predicate:(NSPredicate * _Nullable)predicate
                                                      callback:(STMPersistingObservingSubscriptionCallback _Nonnull)callback;

- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID _Nonnull)subscriptionId;

@end
