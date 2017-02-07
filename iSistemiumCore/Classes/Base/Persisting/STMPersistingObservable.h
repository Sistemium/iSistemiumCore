//
//  STMPersistingObservable.h
//  iSisSales
//
//  Created by Alexander Levin on 28/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingObserving.h"

@interface STMPersistingObservingSubscription : NSObject

@property (nonatomic, strong, nonnull) NSString *entityName;
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, strong, nonnull) STMPersistingObservingSubscriptionCallback callback;

@end

NS_ASSUME_NONNULL_BEGIN

@interface STMPersistingObservable : NSObject <STMPersistingObserving>

@property (nonatomic, strong, readonly) NSMutableDictionary <STMPersistingObservingSubscriptionID, STMPersistingObservingSubscription *> *subscriptions;

- (void)notifyObservingEntityName:(NSString *)entityName
                        ofUpdated:(NSDictionary *)item;

- (void)notifyObservingEntityName:(NSString *)entityName
                   ofUpdatedArray:(NSArray *)items;

@end

NS_ASSUME_NONNULL_END
