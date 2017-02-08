//
//  STMPersistingObservable.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingObservable.h"

@implementation STMPersistingObservingSubscription

+ (instancetype)subscriptionWithPredicate:(NSPredicate *)predicate {
    
    STMPersistingObservingSubscriptionID subscriptionId = NSUUID.UUID.UUIDString;
    STMPersistingObservingSubscription *subscription = [[self alloc] init];
    
    subscription.identifier = subscriptionId;
    subscription.predicate = predicate;
    
    return subscription;
    
}

@end


@implementation STMPersistingObservable

- (instancetype)init {
    
    self = [super init];
    _subscriptions = [NSMutableDictionary dictionary];
    return self;
    
}


#pragma mark - PersistingObserving protocol

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    
    STMPersistingObservingSubscription *subscription = [STMPersistingObservingSubscription subscriptionWithPredicate:predicate];
    
    subscription.entityName = entityName;
    subscription.callback = callback;
    
    self.subscriptions[subscription.identifier] = subscription;
    
    return subscription.identifier;
    
}

- (STMPersistingObservingSubscriptionID) observeAllWithPredicate:(NSPredicate *)predicate callback:(STMPersistingObservingEntityNameArrayCallback)callback {
    
    STMPersistingObservingSubscription *subscription = [STMPersistingObservingSubscription subscriptionWithPredicate:predicate];
    
    subscription.callbackWithEntityName = callback;
    
    self.subscriptions[subscription.identifier] = subscription;
    
    return subscription.identifier;
}

- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID)subscriptionId {
    
    BOOL result = self.subscriptions[subscriptionId] != nil;
    
    if (result) {
        [self.subscriptions removeObjectForKey:subscriptionId];
    }
    
    return result;
}


#pragma mark - Private helpers

- (void)notifyObservingEntityName:(NSString *)entityName
                        ofUpdated:(NSDictionary *)item {
    if (!item) return;
    [self notifyObservingEntityName:entityName
                     ofUpdatedArray:[NSArray arrayWithObject:item]];
}

- (void)notifyObservingEntityName:(NSString *)entityName
                   ofUpdatedArray:(NSArray *)items {
    
    if (!items.count) return;
    
    // TODO: maybe we need to cache subscriptions by entityName
    for (STMPersistingObservingSubscriptionID key in self.subscriptions) {
        
        STMPersistingObservingSubscription *subscription = self.subscriptions[key];
        
        if (subscription.entityName && ![subscription.entityName isEqualToString:entityName]) continue;
        
        NSArray *itemsFiltered = items;
        
        if (subscription.predicate) {
            @try {
                itemsFiltered = [items filteredArrayUsingPredicate:subscription.predicate];
            } @catch (NSException *exception) {
                NSLog(@"notifyObservingEntityName catch: %@", exception);
                itemsFiltered = nil;
            }
            if (!itemsFiltered.count) continue;
        }
        
        if (!itemsFiltered.count) return;
        
        if (subscription.entityName) {
            subscription.callback(itemsFiltered);
        } else {
            subscription.callbackWithEntityName(entityName, itemsFiltered);
        }
    }
    
}

@end
