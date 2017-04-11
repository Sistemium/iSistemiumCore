//
//  STMPersistingObservable.m
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingObservable.h"

@interface STMPersistingObservingSubscription : NSObject

@property (nonatomic, strong, nonnull) NSString *identifier;

@property (nonatomic, strong, nullable) NSString *entityName;
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, strong, nullable) STMPersistingObservingSubscriptionCallback callback;
@property (nonatomic, strong, nullable) STMPersistingObservingEntityNameArrayCallback callbackWithEntityName;
@property (nonatomic, strong, nullable) STMPersistingOptions options;

@end


@implementation STMPersistingObservingSubscription

+ (instancetype)subscriptionWithPredicate:(NSPredicate *)predicate {
    
    STMPersistingObservingSubscriptionID subscriptionId = NSUUID.UUID.UUIDString;
    STMPersistingObservingSubscription *subscription = [[self alloc] init];
    
    subscription.identifier = subscriptionId;
    subscription.predicate = predicate;
    
    return subscription;
    
}

@end


@interface STMPersistingObservable ()

@property (nonatomic, strong) NSMutableDictionary <STMPersistingObservingSubscriptionID, STMPersistingObservingSubscription *> *subscriptions;

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
                                              options:(STMPersistingOptions)options
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    
    STMPersistingObservingSubscription *subscription = [STMPersistingObservingSubscription subscriptionWithPredicate:predicate];
    
    subscription.entityName = entityName;
    subscription.callback = callback;
    subscription.options = options;
    
    self.subscriptions[subscription.identifier] = subscription;
    
    NSLog(@"%@ %@", entityName, subscription.identifier);
    
    return subscription.identifier;
    
}

- (STMPersistingObservingSubscriptionID)observeAllWithPredicate:(NSPredicate *)predicate callback:(STMPersistingObservingEntityNameArrayCallback)callback {
    
    STMPersistingObservingSubscription *subscription = [STMPersistingObservingSubscription subscriptionWithPredicate:predicate];
    
    subscription.callbackWithEntityName = callback;
    
    self.subscriptions[subscription.identifier] = subscription;
    
    NSLog(@"%@", subscription.identifier);
    
    return subscription.identifier;
}

- (STMPersistingObservingSubscriptionID)observeEntityNames:(NSArray *)entityNames predicate:(NSPredicate *)predicate callback:(STMPersistingObservingEntityNameArrayCallback)callback {
    
    NSSet *names = [NSSet setWithArray:entityNames];
    
    return [self observeAllWithPredicate:predicate
                                callback:^(NSString *entityName, NSArray *data) {
                                    if ([names containsObject:entityName]) {
                                        callback(entityName, data);
                                    }
                                }];
    
}

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate * _Nullable)predicate
                                             callback:(STMPersistingObservingSubscriptionCallback)callback {
    
    return [self observeEntity:entityName predicate:predicate options:nil callback:callback];
    
}


- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID)subscriptionId {
    
    BOOL result = subscriptionId && self.subscriptions[subscriptionId] != nil;
    
    if (result) {
        [self.subscriptions removeObjectForKey:subscriptionId];
    }
    
    return result;
}


#pragma mark - Public methods

- (void)notifyObservingEntityName:(NSString *)entityName ofUpdated:(NSDictionary *)item options:(STMPersistingOptions)options {
    
    if (!item) return;
    
    [self notifyObservingEntityName:entityName
                     ofUpdatedArray:[NSArray arrayWithObject:item]
                            options:options];
    
}

- (void)notifyObservingEntityName:(NSString *)entityName ofUpdatedArray:(NSArray *)items options:(STMPersistingOptions)options;{
    
    if (!items.count) return;
    
    for (STMPersistingObservingSubscriptionID key in self.subscriptions.allKeys) {
        
        STMPersistingObservingSubscription *subscription = self.subscriptions[key];
        
        if (!subscription) {
            NSLog(@"no subscription: %@", key);
            continue;
        }
        
        if (subscription.entityName && ![subscription.entityName isEqualToString:entityName]) continue;
        
        NSSet *unmatchedOptions = [subscription.options keysOfEntriesPassingTest:^BOOL(NSString *optionName, id optionValue, BOOL *stop) {
            if ([optionValue isKindOfClass:NSNumber.class]) {
//                if (![optionValue respondsToSelector:@selector(boolValue)] || ![options[optionName] respondsToSelector:@selector(boolValue)]) {
//                    return [optionValue isEqual:options[optionName]];
//                }
                return [optionValue boolValue] != [(NSNumber *)options[optionName] boolValue];
            }
            return [optionValue isEqual:options[optionName]];
        }];
        
        if (unmatchedOptions.count) continue;
        
        NSArray *itemsFiltered = items;
        
        if (subscription.predicate) {
            @try {
                itemsFiltered = [items filteredArrayUsingPredicate:subscription.predicate];
            } @catch (NSException *exception) {
                NSLog(@"notifyObservingEntityName catch: %@", exception);
                itemsFiltered = nil;
            }
        }

        if (!itemsFiltered.count) continue;
        
        if (subscription.entityName) {
            if (subscription.callback) subscription.callback(itemsFiltered);
        } else {
            if (subscription.callbackWithEntityName) subscription.callbackWithEntityName(entityName, itemsFiltered);
        }
        
    }
    
}

@end
