//
//  STMCoreController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMSessionManager.h"

@implementation STMCoreController

+ (STMCoreSession *)session {
    
    return [STMSessionManager sharedManager].currentSession;
    
}

+ (STMDocument *)document {
    
    return [self session].document;
    
}

+ (STMSyncer *)syncer {
    
    return [self session].syncer;
    
}

@end
