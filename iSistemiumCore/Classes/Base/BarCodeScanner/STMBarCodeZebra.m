//
// Created by Alexander Levin on 16/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMBarCodeZebra.h"
#import <ZebraIos/RMDAttributes.h>

@interface STMBarCodeZebra ()

@property (nonatomic, strong) id <ISbtSdkApi> api;
@property (nonatomic) int connectedId;

@end

@implementation STMBarCodeZebra

- (instancetype)init {

    self = [super init];

    if (!self) {
        return self;
    }

    id <ISbtSdkApi> api = [SbtSdkFactory createSbtSdkApiInstance];

    NSLog(@"Zebra API init version %@", [api sbtGetVersion]);

    self.api = api;

    [api sbtSetDelegate:self];

    [api sbtSubsribeForEvents:SBT_EVENT_SCANNER_APPEARANCE |
            SBT_EVENT_SCANNER_DISAPPEARANCE | SBT_EVENT_SESSION_ESTABLISHMENT |
            SBT_EVENT_SESSION_TERMINATION | SBT_EVENT_BARCODE];

    [api sbtSetOperationalMode:SBT_OPMODE_ALL];
    [api sbtEnableAvailableScannersDetection:YES];

    return self;

}

- (void)test {

    id <ISbtSdkApi> apiInstance = [SbtSdkFactory createSbtSdkApiInstance];
    NSString *version = [apiInstance sbtGetVersion];
    NSLog(@"Zebra SDK version: %@\n", version);

}


#pragma mark ISbtSdkApiDelegate Protocol


- (void)sbtEventScannerAppeared:(SbtScannerInfo *)availableScanner {

    NSString *status = [availableScanner isActive] ? @"active" : @"available";
    int scannerId = [availableScanner getScannerID];

    NSLog(@"Scanner is %@: scannerId: %d name: %@", status, scannerId, [availableScanner getScannerName]);

    [self.api sbtEnableAvailableScannersDetection:NO];

    SBT_RESULT result = [self.api sbtEstablishCommunicationSession:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Connection to scannerId %d successful", scannerId);
    } else {
        NSLog(@"Failed to establish a connection with scannerId: %d", scannerId);
    }

}

- (void)sbtEventCommunicationSessionEstablished:(SbtScannerInfo *)activeScanner {

    int scannerId = [activeScanner getScannerID];

    self.connectedId = scannerId;

    SBT_RESULT result = [self.api sbtEnableAutomaticSessionReestablishment:YES forScanner:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Automatic Session Reestablishment for scannerId %d has been set successfully", scannerId);
    } else {
        NSLog(@"Automatic Session Reestablishment for scannerId %d could not be set", scannerId);
    }

}

- (void)sbtEventScannerDisappeared:(int)scannerID {

}

- (void)sbtEventCommunicationSessionTerminated:(int)scannerID {
    NSLog(@"sbtEventCommunicationSessionTerminated scannerId: %d", scannerID);
}

- (void)sbtEventBarcode:(NSString *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {

    NSString *typeName = get_barcode_type_name(barcodeType);

    NSLog(@"Got barcode: '%@' of type: '%@' from scannerId: %d", barcodeData, typeName, scannerID);

    [self.stmScanningDelegate barCodeScanner:self receiveBarCode:barcodeData withType:STMBarCodeTypeUnknown];

}

- (void)sbtEventBarcodeData:(NSData *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {
    // Need to implement this because "sbtEventBarcode" is deprecated
}

- (void)sbtEventFirmwareUpdate:(FirmwareUpdateEvent *)fwUpdateEventObj {
    // Won't implement
}

- (void)sbtEventImage:(NSData *)imageData fromScanner:(int)scannerID {
    // Won't implement

}

- (void)sbtEventVideo:(NSData *)videoFrame fromScanner:(int)scannerID {
    // Won't implement
}


@end