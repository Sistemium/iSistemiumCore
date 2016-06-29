//
//  STMScriptMessagesController.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 29/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

#import <WebKit/WebKit.h>


@interface STMScriptMessagesController : STMCoreController

+ (NSPredicate *)predicateForScriptMessage:(WKScriptMessage *)scriptMessage
                                     error:(NSError **)error;


@end
