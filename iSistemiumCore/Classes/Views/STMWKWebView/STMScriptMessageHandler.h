//
//  STMScriptMessageHandler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "STMCoreWKWebViewVC.h"
#import "STMScriptMessaging.h"
#import "STMPersistingObserving.h"

@interface STMScriptMessagingSubscription : NSObject

@property (nonatomic, strong) NSString *callbackName;
@property (nonatomic, strong) NSMutableSet <NSString *> *entityNames;
@property (nonatomic, strong) NSDictionary <NSString *, STMPersistingObservingSubscriptionID> *persisterSubscriptions;

@end

@interface STMScriptMessageHandler : NSObject <STMScriptMessaging>

@property (nonatomic, weak) id <STMScriptMessagingOwner> owner;

// TODO: create subsription id and store subscriptions by id and add a cancelSubscription:subscriptionId method
@property (nonatomic, strong) NSMutableDictionary <NSString *, STMScriptMessagingSubscription *> *subscriptions;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *subscribedObjects;

@property (nonatomic, weak) id <STMModelling> modellingDelegate;
@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingObserving, STMModelling> persistenceDelegate;

@end
