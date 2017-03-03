//
//  STMCoreSessionManager.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSessionManagement.h"
#import "STMCoreSession.h"

@interface STMCoreSessionManager : NSObject <STMSessionManager>

@property (nonatomic, strong) NSMutableDictionary <NSString *, STMCoreSession *> *sessions;
@property (nonatomic, weak) id <STMSession> currentSession;
@property (nonatomic, strong) NSString *currentSessionUID;

+ (instancetype)sharedManager;


@end
