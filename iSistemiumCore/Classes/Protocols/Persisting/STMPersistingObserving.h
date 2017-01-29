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

@protocol STMPersistingObserving

- (STMPersistingObservingSubscriptionID)observeEntity:(NSString *)entityName
                                            predicate:(NSPredicate *)predicate
                                             callback:(void (^)(NSArray *data))callback;

- (BOOL)cancelSubscription:(STMPersistingObservingSubscriptionID)subscriptionId;

@end
