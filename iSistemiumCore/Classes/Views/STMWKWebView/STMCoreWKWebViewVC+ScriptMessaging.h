//
// Created by Alexander Levin on 11/06/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMCoreWKWebViewVC.h"

#import "STMSoundController.h"
#import "STMScriptMessageHandler.h"
#import "STMCoreBarCodeController.h"

@interface STMCoreWKWebViewVC (ScriptMessaging) <
        WKScriptMessageHandler,
        STMBarCodeScannerDelegate,
        STMSoundCallbackable
        >
@end