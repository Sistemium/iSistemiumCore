//
//  STMBarCodeScanning.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "STMBarCodeScan.h"
#import "STMBarCodeType.h"


typedef NS_ENUM(NSUInteger, STMBarCodeScannedType) {
    STMBarCodeTypeUnknown,
    STMBarCodeTypeArticle,
    STMBarCodeTypeExciseStamp,
    STMBarCodeTypeStockBatch
};

@protocol STMBarCodeScanningDevice <NSObject>


@end

@protocol STMBarCodeScannerDelegate <NSObject>

@required

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner
        receiveBarCode:(NSString *)barcode
             symbology:(NSString *)symbology
              withType:(STMBarCodeScannedType)type;

@optional

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner
          receiveError:(NSError *)error;

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner
    receiveBarCodeScan:(STMBarCodeScan *)barCodeScan
              withType:(STMBarCodeScannedType)type;

- (UIView *)viewForScanner:(id <STMBarCodeScanningDevice>)scanner;

- (void)deviceArrivalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner;

- (void)deviceRemovalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner;

- (void)receiveScannerBeepStatus:(BOOL)isBeepEnabled;

- (void)receiveScannerRumbleStatus:(BOOL)isRumbleEnabled;

- (void)receiveBatteryLevel:(NSNumber *)batteryLevel;

- (void)receiveVersion:(NSString *)version;

- (void)powerButtonPressedOnBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner;


@end
