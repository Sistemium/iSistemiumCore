//
//  STMPersister+Observable.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersister+Observable.h"

@implementation STMPersister (Observable)

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    
    STMPersistingObservingSubscriptionID subscriptionId = NSUUID.UUID.UUIDString;
    
    STMPersistingObservingSubscription *subscription = [[STMPersistingObservingSubscription alloc] init];
    
    subscription.entityName = entityName;
    subscription.predicate = predicate;
    subscription.callback = callback;
    
    self.subscriptions[subscriptionId] = subscription;
    
    return subscriptionId;
    
}

- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID)subscriptionId {
    
    BOOL result = self.subscriptions[subscriptionId] != nil;
    
    if (result) {
        [self.subscriptions removeObjectForKey:subscriptionId];
    }
    
    return result;
}

- (void)notifyObservingEntityName:(NSString *)entityName
                        ofUpdated:(NSDictionary *)item {
#warning CoreData observing is not working yet
    if (!item) return;
    [self notifyObservingEntityName:entityName
                     ofUpdatedArray:[NSArray arrayWithObject:item]];
}

- (void)notifyObservingEntityName:(NSString *)entityName
                   ofUpdatedArray:(NSArray *)items {
    
    // TODO: maybe we need to cache subscriptions by entityName
    for (STMPersistingObservingSubscriptionID key in self.subscriptions) {
        
        STMPersistingObservingSubscription *subscription = self.subscriptions[key];
        
        if (![subscription.entityName isEqualToString:entityName]) continue;
        
        if (subscription.predicate) {
            items = [items filteredArrayUsingPredicate:subscription.predicate];
        }
        
        if (!items.count) continue;
        
        subscription.callback(items);
        
    }
    
}

@end
