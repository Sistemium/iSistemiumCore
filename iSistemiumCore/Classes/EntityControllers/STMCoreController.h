//
//  STMCoreController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMDocument.h"
#import "STMSyncer.h"
#import "STMCoreSession.h"

#import "STMNS.h"

#import "STMFunctions.h"
#import "STMConstants.h"

#import "STMAuthController.h"

#import "STMCoreDataModel.h"


@interface STMCoreController : NSObject

+ (STMCoreSession *)session;
+ (STMDocument *)document;
+ (STMSyncer *)syncer;

@end
