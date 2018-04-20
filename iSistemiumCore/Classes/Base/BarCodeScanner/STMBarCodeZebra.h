//
// Created by Alexander Levin on 16/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "ZBRBarcodeTypes.h"
#import <ZebraIos/SbtSdkFactory.h>
#import "STMBarCodeScanning.h"

@interface STMBarCodeZebra : NSObject <ISbtSdkApiDelegate, STMBarCodeScanningDevice>

@property (nonatomic, weak) id <STMBarCodeScannerDelegate> stmScanningDelegate;

- (void)showPairingAlertInViewController:(UIViewController *)viewController;
- (BOOL)isDeviceConnected;

@end