//
//  STMScriptMessageHandler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 07/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreObject.h"
#import <WebKit/WebKit.h>

#import "STMCoreWKWebViewVC.h"
#import "STMScriptMessaging.h"
#import "STMPersistingFullStack.h"
#import "STMOperationQueue.h"
#import "STMImagePickerOwnerProtocol.h"
#import "STMSpinnerView.h"
#import "STMPersistingWithHeadersAsync.h"

@interface STMScriptMessagingSubscription : NSObject

@property (nonatomic, strong) NSString *callbackName;
@property (nonatomic, strong) NSMutableSet <NSString *> *entityNames;
@property (nonatomic, strong) NSSet <STMPersistingObservingSubscriptionID> *persisterSubscriptions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *ltsOffset;

@end


@interface STMScriptMessageHandler : STMCoreObject <STMScriptMessaging,STMImagePickerOwnerProtocol>

@property (nonatomic, weak) UIViewController <STMScriptMessagingOwner>* owner;

// TODO: create subsription id and store subscriptions by id and add a cancelSubscription:subscriptionId method
@property (nonatomic, strong) NSMutableDictionary <NSString *, STMScriptMessagingSubscription *> *subscriptions;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *subscribedObjects;

@property (nonatomic, weak) id <STMModelling> modellingDelegate;
@property (nonatomic, weak) id <STMPersistingPromised, STMPersistingObserving, STMModelling, STMPersistingSync> persistenceDelegate;

@property (nonatomic, strong) id <STMPersistingWithHeadersAsync> socketTransport;

@property (nonatomic) BOOL waitingPhoto;
@property (nonatomic, strong) NSString *photoEntityName;
@property (nonatomic, strong) NSDictionary *takePhotoMessageParameters;
@property (nonatomic, strong) NSDictionary *photoData;
@property (nonatomic, strong) NSString *takePhotoCallbackJSFunction;
@property (nonatomic, strong) STMSpinnerView *spinnerView;
@property (nonatomic, strong) NSString *syncerInfoJSFunction;

@end
