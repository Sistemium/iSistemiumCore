//
//  STMBarCodeScannerDelegate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "STMCoreBarCodeController.h"

@class STMBarCodeScanner;

@protocol STMBarCodeScannerDelegate <NSObject>

@required

- (UIView *)viewForScanner:(STMBarCodeScanner *)scanner;

- (void)barCodeScanner:(STMBarCodeScanner *)scanner
    receiveBarCodeScan:(STMBarCodeScan *)barCodeScan
              withType:(STMBarCodeScannedType)type;

- (void)barCodeScanner:(STMBarCodeScanner *)scanner
        receiveBarCode:(NSString *)barcode
              withType:(STMBarCodeScannedType)type;

- (void)barCodeScanner:(STMBarCodeScanner *)scanner
          receiveError:(NSError *)error;


@optional

- (void)deviceArrivalForBarCodeScanner:(STMBarCodeScanner *)scanner;
- (void)deviceRemovalForBarCodeScanner:(STMBarCodeScanner *)scanner;

- (void)receiveScannerBeepStatus:(BOOL)isBeepEnabled;
- (void)receiveScannerRumbleStatus:(BOOL)isRumbleEnabled;
- (void)receiveBatteryLevel:(NSNumber *)batteryLevel;
- (void)receiveVersion:(NSString *)version;

- (void)powerButtonPressedOnBarCodeScanner:(STMBarCodeScanner *)scanner;


@end
