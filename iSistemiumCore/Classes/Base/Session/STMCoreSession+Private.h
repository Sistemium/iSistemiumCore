//
//  STMCoreSession+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 16/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession.h"

@interface STMCoreSession ()

@property (nonatomic, strong) NSMutableDictionary <NSString *, id> *controllers;

@property (nonatomic, strong) STMPersistingObservingSubscriptionID subscriptionId;

- (void)initController:(Class)controllerClass;

@end
