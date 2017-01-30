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

typedef NSMutableDictionary <NSString *, NSArray <UIViewController <STMEntitiesSubscribable> *> *> STMScriptMessageHandlerSubscriptionsType;

@interface STMScriptMessageHandler : NSObject <STMScriptMessaging>

@property (nonatomic, strong) STMScriptMessageHandlerSubscriptionsType *entitiesToSubscribe;
@property (nonatomic, weak) id <STMPersistingPromised, STMModelling, STMPersistingSync> persistenceDelegate;

@property (nonatomic, strong) NSMutableArray <NSDictionary *> *subscribedObjects;

@end
