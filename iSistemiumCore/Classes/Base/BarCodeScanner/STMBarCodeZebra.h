//
// Created by Alexander Levin on 16/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "ZBRBarcodeTypes.h"
#import "STMBarCodeScanning.h"

@interface STMBarCodeZebra : NSObject <STMBarCodeScanningDevice>

@property (nonatomic, weak) id <STMBarCodeScannerDelegate> stmScanningDelegate;

- (void)showPairingAlertInViewController:(UIViewController *)viewController;
- (BOOL)isDeviceConnected;
- (void)disconnect;

@end
