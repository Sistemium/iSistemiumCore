//
// Created by Alexander Levin on 16/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMBarCodeZebra.h"
#import "STMCoreBarCodeController.h"
#import <ZebraIos/RMDAttributes.h>

@import PMAlertController;

@interface STMBarCodeZebra ()

@property (nonatomic, strong) id <ISbtSdkApi> api;
@property (nonatomic) int connectedId;
@property (nonatomic, weak) UIViewController *pairingAlert;

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

- (NSString *)getVersion {

    NSString *version = [self.api sbtGetVersion];
    NSLog(@"Zebra SDK version: %@\n", version);

    return version;

}

- (NSString *)randomBTAddress {
    NSString *uuid = [STMFunctions uuidString];

    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];

    uuid = [uuid substringFromIndex:(uuid.length - 12)];

    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(..)"
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:nil];

    uuid = [re stringByReplacingMatchesInString:uuid
                                        options:NSMatchingReportProgress
                                          range:NSMakeRange(0, uuid.length)
                                   withTemplate:@"$1:"];

    uuid = [uuid substringToIndex:uuid.length - 1];

    return [uuid uppercaseString];

}

- (void)showPairingAlertInViewController:(UIViewController *)viewController {

    NSString *title = NSLocalizedString(@"ZEBRA PAIRING", nil);
    NSString *description = NSLocalizedString(@"ZEBRA PAIRING DESCRIPTION", nil);

    CGRect frame = CGRectMake(0, 0, 350, 250);

    NSString *btAddress = [self randomBTAddress];

    NSLog(@"Connection using BTAddress: %@", btAddress);

    [self.api sbtSetBTAddress:btAddress];

    NSMutableArray <SbtScannerInfo *> *activeList = @[].mutableCopy;

    [self.api sbtGetActiveScannersList:&activeList];

    NSLog(@"Active scanners: %@", activeList);

    for (SbtScannerInfo *scannerInfo in activeList) {
        [self.api sbtTerminateCommunicationSession:[scannerInfo getScannerID]];
    }

    UIImage *barcode = [self.api sbtGetPairingBarcode:BARCODE_TYPE_STC
                                      withComProtocol:STC_SSI_BLE
                                 withSetDefaultStatus:SETDEFAULT_NO
                                        withBTAddress:btAddress
                                       withImageFrame:frame];

    PMAlertController *alert = [[PMAlertController alloc] initWithTitle:title
                                                            description:description
                                                                  image:barcode
                                                                  style:PMAlertControllerStyleAlert];

    [alert addAction:[[PMAlertAction alloc] initWithTitle:NSLocalizedString(@"CANCEL", nil)
                                                    style:PMAlertActionStyleCancel
                                                   action:^() {
                                                       NSLog(@"OK action");
                                                       [self.api sbtEnableAvailableScannersDetection:NO];
                                                   }]];

    self.pairingAlert = alert;

    [viewController presentViewController:alert animated:NO completion:^{
        NSLog(@"Presented");
        [self.api sbtEnableAvailableScannersDetection:YES];
    }];

}


- (void)applySettingsToScanner:(int)scannerId {

    NSString *format = @"<inArgs><scannerID>%d</scannerID><cmdArgs><arg-xml><attrib_list><attribute><id>%d</id><datatype>B</datatype><value>%d</value></attribute></attrib_list></arg-xml></cmdArgs></inArgs>";

    NSString *xmlInput = [NSString stringWithFormat:format, scannerId,
                    RMD_ATTR_BEEPER_VOLUME,
                    RMD_ATTR_VALUE_BEEPER_VOLUME_LOW];

    NSLog(@"Sending beeper command to scannerId: %d", scannerId);

    SBT_RESULT result = [self.api sbtExecuteCommand:SBT_RSM_ATTR_SET
                                             aInXML:xmlInput
                                            aOutXML:nil
                                         forScanner:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Successfully updated beeper settings for scanner ID %d", scannerId);
    } else {
        NSLog(@"Failed to update beeper settings from scanner ID %d", scannerId);
    }

}

#pragma mark ISbtSdkApiDelegate Protocol


- (void)sbtEventScannerAppeared:(SbtScannerInfo *)availableScanner {

    NSString *status = [availableScanner isActive] ? @"active" : @"available";
    int scannerId = [availableScanner getScannerID];

    NSLog(@"Scanner is %@: scannerId: %d name: %@", status, scannerId, [availableScanner getScannerName]);


//    SBT_RESULT result = [self.api sbtEstablishCommunicationSession:scannerId];
//
//    if (result == SBT_RESULT_SUCCESS) {
//        NSLog(@"Connection to scannerId %d successful", scannerId);
//        [self.api sbtEnableAvailableScannersDetection:NO];
//    } else {
//        NSLog(@"Failed to establish a connection with scannerId: %d", scannerId);
//    }

}

- (void)sbtEventCommunicationSessionEstablished:(SbtScannerInfo *)activeScanner {

    int scannerId = [activeScanner getScannerID];

    self.connectedId = scannerId;

    SBT_RESULT result = [self.api sbtEnableAutomaticSessionReestablishment:YES forScanner:scannerId];

    if (result != SBT_RESULT_SUCCESS) {
        NSLog(@"Automatic Session Reestablishment for scannerId %d could not be set", scannerId);
        return;
    }

    NSLog(@"Automatic Session Reestablishment for scannerId %d has been set successfully", scannerId);

    [self.api sbtEnableAvailableScannersDetection:NO];
    [self.pairingAlert dismissViewControllerAnimated:NO completion:nil];

    [self applySettingsToScanner:scannerId];
    [self.stmScanningDelegate deviceArrivalForBarCodeScanner:self];

}

- (void)sbtEventScannerDisappeared:(int)scannerID {
    NSLog(@"sbtEventScannerDisappeared scannerId: %d", scannerID);
//    [self.stmScanningDelegate deviceRemovalForBarCodeScanner:self];
}

- (void)sbtEventCommunicationSessionTerminated:(int)scannerID {

    NSLog(@"sbtEventCommunicationSessionTerminated scannerId: %d", scannerID);

    [self.stmScanningDelegate deviceRemovalForBarCodeScanner:self];
    [self.api sbtEnableAvailableScannersDetection:YES];

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
