//
//  STMBarCodeScanner.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMBarCodeScannerDelegate.h"


typedef NS_ENUM(NSUInteger, STMBarCodeScannerMode) {
    STMBarCodeScannerCameraMode,
    STMBarCodeScannerHIDKeyboardMode,
    STMBarCodeScannerIOSMode
};

typedef NS_ENUM(NSUInteger, STMBarCodeScannerStatus) {
    STMBarCodeScannerStopped,
    STMBarCodeScannerStarted
};


@interface STMBarCodeScanner : NSObject

+ (BOOL)isCameraAvailable;

@property (nonatomic, readonly) STMBarCodeScannerMode mode;
@property (nonatomic, readonly) STMBarCodeScannerStatus status;
@property (nonatomic, readonly) NSString *scannerName;
@property (nonatomic, readonly) BOOL isDeviceConnected;

@property (nonatomic, strong) id <STMBarCodeScannerDelegate> delegate;

- (instancetype)initWithMode:(STMBarCodeScannerMode)mode;

- (void)startScan;
- (void)stopScan;

- (void)getBeepStatus;
- (void)getRumbleStatus;
- (void)setBeepStatus:(BOOL)beepStatus andRumbleStatus:(BOOL)rumbleStatus;

- (void)getBatteryStatus;
- (void)getVersion;


@end
