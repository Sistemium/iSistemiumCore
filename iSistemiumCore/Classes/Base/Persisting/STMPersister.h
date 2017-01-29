//
//  STMPersister.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSessionManagement.h"

#import "STMPersistingSync.h"
#import "STMDocument.h"

#import "STMModeller.h"
#import "STMFmdb.h"

@interface STMPersistingObservingSubscription : NSObject

@property (nonatomic, strong, nonnull) NSString *entityName;
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, strong, nonnull) STMPersistingObservingSubscriptionCallback callback;

@end

NS_ASSUME_NONNULL_BEGIN

@interface STMPersister : STMModeller <STMPersistingSync>

@property (nonatomic, strong) STMFmdb *fmdb;
@property (nonatomic, strong) STMDocument *document;

@property (nonatomic, strong, readonly) NSMutableDictionary <STMPersistingObservingSubscriptionID, STMPersistingObservingSubscription *> *subscriptions;

+ (instancetype)initWithSession:(id <STMSession>)session;

@end

NS_ASSUME_NONNULL_END

