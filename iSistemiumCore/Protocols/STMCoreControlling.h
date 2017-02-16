//
//  STMCoreControlling.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 16/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMCoreControlling <NSObject>

+ (instancetype)controllerWithPersistenceDelegate:(id)persistenceDelegate;

+ (instancetype)sharedInstance;

@end
