//
//  STMPersistingObserving.h
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "STMPersisting.h"

#define STMPersistingObservingSubscriptionID NSString *

typedef void (^STMPersistingObservingSubscriptionCallback)(NSArray * _Nullable data);
typedef void (^STMPersistingObservingEntityNameArrayCallback)(NSString * _Nonnull entityName, NSArray * _Nullable data);

@protocol STMPersistingObserving

NS_ASSUME_NONNULL_BEGIN

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                                     predicate:(NSPredicate * _Nullable)predicate
                                                      callback:(STMPersistingObservingSubscriptionCallback)callback;

- (STMPersistingObservingSubscriptionID)observeAllWithPredicate:(NSPredicate * _Nullable)predicate
                                                       callback:(STMPersistingObservingEntityNameArrayCallback)callback;

- (STMPersistingObservingSubscriptionID)observeEntityNames:(NSArray *)entityNames
                                                 predicate:(NSPredicate * _Nullable)predicate
                                                  callback:(STMPersistingObservingEntityNameArrayCallback)callback;

- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID)subscriptionId;

@optional

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate * _Nullable)predicate
                                              options:(STMPersistingOptions _Nullable)options
                                             callback:(STMPersistingObservingSubscriptionCallback)callback;


NS_ASSUME_NONNULL_END

@end
