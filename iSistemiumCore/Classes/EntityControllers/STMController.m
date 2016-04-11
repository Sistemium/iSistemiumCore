//
//  STMController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"
#import "STMSessionManager.h"

@implementation STMController

+ (STMSession *)session {
    
    return [STMSessionManager sharedManager].currentSession;
    
}

+ (STMDocument *)document {
    
    return [self session].document;
    
}

+ (STMSyncer *)syncer {
    
    return [self session].syncer;
    
}

@end
