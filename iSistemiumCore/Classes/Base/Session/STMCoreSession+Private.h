//
//  STMCoreSession+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 16/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession.h"
#import "PromiseKit.h"

@interface STMCoreSession ()

@property (nonatomic, strong) NSMutableDictionary <NSString *, id> *controllers;

- (void)initController:(Class)controllerClass;
- (AnyPromise *)downloadModel;

@end
