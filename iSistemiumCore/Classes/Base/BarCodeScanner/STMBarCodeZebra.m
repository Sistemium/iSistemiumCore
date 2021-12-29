//
// Created by Alexander Levin on 16/04/2018.
// Copyright (c) 2018 Sistemium UAB. All rights reserved.
//

#import "STMBarCodeZebra.h"
#import "STMCoreBarCodeController.h"

@import PMAlertController;

@interface STMBarCodeZebra ()

@property (nonatomic) int connectedId;
@property (nonatomic, weak) UIViewController *pairingAlert;
@property (nonatomic) BOOL isConnected;

@end

@implementation STMBarCodeZebra

- (instancetype)init {

    self = [super init];

    if (!self) {
        return self;
    }

    self.connectedId = 0;

    return self;

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


}

- (BOOL)isDeviceConnected {
    return [self isConnected];
}

- (void)disconnect {

}

- (void)applySettingsToScanner:(int)scannerId {

    NSString *format = @"<inArgs><scannerID>%d</scannerID><cmdArgs><arg-xml><attrib_list><attribute><id>%d</id><datatype>B</datatype><value>%d</value></attribute></attrib_list></arg-xml></cmdArgs></inArgs>";

    NSLog(@"Sending beeper command to scannerId: %d", scannerId);

}

#pragma mark ISbtSdkApiDelegate Protocol

- (void)sbtEventScannerDisappeared:(int)scannerID {
    NSLog(@"sbtEventScannerDisappeared scannerId: %d", scannerID);
//    [self.stmScanningDelegate deviceRemovalForBarCodeScanner:self];
}

- (void)sbtEventCommunicationSessionTerminated:(int)scannerID {

    NSLog(@"sbtEventCommunicationSessionTerminated scannerId: %d", scannerID);

    self.isConnected = NO;

    [self.stmScanningDelegate deviceRemovalForBarCodeScanner:self];

}


@end
