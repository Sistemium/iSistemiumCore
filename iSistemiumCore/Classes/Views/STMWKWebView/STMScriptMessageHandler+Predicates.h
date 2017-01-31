//
//  STMScriptMessagesController.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 29/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMScriptMessageHandler.h"

#import <WebKit/WebKit.h>


@interface STMScriptMessageHandler (Predicates)

- (NSPredicate *)predicateForScriptMessage:(WKScriptMessage *)scriptMessage
                                     error:(NSError **)error;


@end
