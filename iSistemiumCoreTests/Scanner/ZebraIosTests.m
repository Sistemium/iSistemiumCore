//
//  ZebraIos.m
//  iSisSalesOfLibsTests
//
//  Created by Alexander Levin on 16/04/2018.
//  Copyright © 2018 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ZebraIos/RMDAttributes.h>
#import <ZebraIos/SbtSdkFactory.h>

#import "ZBRBarcodeTypes.h"

@interface ZebraIosTests : XCTestCase

@end

@interface ZebraIosTestEventReceiver : NSObject <ISbtSdkApiDelegate>

@property (nonatomic, strong) XCTestExpectation *discoveryExpectation;
@property (nonatomic, strong) XCTestExpectation *connectExpectation;
@property (nonatomic, strong) XCTestExpectation *barcodeExpectation;
@property (nonatomic, strong) XCTestExpectation *symbologyExpectation;
@property (nonatomic, strong) XCTestExpectation *disconnectExpectation;

@property (nonatomic, strong) id <ISbtSdkApi> apiInstance;

@property (nonatomic) int connectedId;

@end

@implementation ZebraIosTestEventReceiver

- (void)sbtEventScannerAppeared:(SbtScannerInfo *)availableScanner {

    NSString *status = [availableScanner isActive] ? @"active" : @"available";
    int scannerId = [availableScanner getScannerID];

    NSLog(@"Scanner is %@: scannerId: %d name: %@", status, scannerId, [availableScanner getScannerName]);

    [self.discoveryExpectation fulfill];
    [self.apiInstance sbtEnableAvailableScannersDetection:NO];

    SBT_RESULT result = [self.apiInstance sbtEstablishCommunicationSession:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Connection to scannerId %d successful", scannerId);
    } else {
        NSLog(@"Failed to establish a connection with scannerId: %d", scannerId);
    }

}

- (void)sbtEventScannerDisappeared:(int)scannerID {
    NSLog(@"sbtEventScannerDisappeared scannerId: %d", scannerID);
}

- (void)sbtEventCommunicationSessionEstablished:(SbtScannerInfo *)activeScanner {

    [self.connectExpectation fulfill];

    int scannerId = [activeScanner getScannerID];

    self.connectedId = scannerId;

    SBT_RESULT result = [self.apiInstance sbtEnableAutomaticSessionReestablishment:YES forScanner:scannerId];

    [self setVolumeForScannerId:scannerId];
//    [self getSymbologiesFromScannerId:scannerId];
    [self getSymbologiesValuesFromScannerId:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Automatic Session Reestablishment for scannerId %d has been set successfully", scannerId);
    } else {
        NSLog(@"Automatic Session Reestablishment for scannerId %d could not be set", scannerId);
    }

}

- (void)sbtEventCommunicationSessionTerminated:(int)scannerID {

    NSLog(@"sbtEventCommunicationSessionTerminated scannerId: %d", scannerID);
    [self.disconnectExpectation fulfill];

}

- (void)sbtEventBarcode:(NSString *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {
    NSLog(@"Got barcode: %@ of type: %@ from scannerId: %d", barcodeData, get_barcode_type_name(barcodeType), scannerID);
    [self.barcodeExpectation fulfill];
}

- (void)sbtEventBarcodeData:(NSData *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {

}

- (void)sbtEventImage:(NSData *)imageData fromScanner:(int)scannerID {

}

- (void)sbtEventVideo:(NSData *)videoFrame fromScanner:(int)scannerID {
}

- (void)sbtEventFirmwareUpdate:(FirmwareUpdateEvent *)event {
}

#pragma mark Private helpers

- (void)setVolumeForScannerId:(int)scannerId {

    NSString *format = @"<inArgs><scannerID>%d</scannerID><cmdArgs><arg-xml><attrib_list><attribute><id>%d</id><datatype>B</datatype><value>%d</value></attribute></attrib_list></arg-xml></cmdArgs></inArgs>";

    NSString *xmlInput = [NSString stringWithFormat:format, scannerId,
                    RMD_ATTR_BEEPER_VOLUME,
                    RMD_ATTR_VALUE_BEEPER_VOLUME_LOW];

//    NSMutableString *xmlResponse = @"".mutableCopy;

    NSLog(@"Sending beeper command to scannerId: %d", scannerId);

    SBT_RESULT result = [self.apiInstance sbtExecuteCommand:SBT_RSM_ATTR_SET
                                                     aInXML:xmlInput
                                                    aOutXML:nil
                                                 forScanner:scannerId];

//    NSLog(@"ExecuteCommand output: %@", xmlResponse);

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Successfully updated beeper settings for scanner ID %d", scannerId);
    } else {
        NSLog(@"Failed to update beeper settings from scanner ID %d", scannerId);
    }

}

- (void)getSymbologiesFromScannerId:(int)scannerId {

    // Create XML string to request supported symbologies of scannerId

    NSString *xmlInput = [NSString stringWithFormat:@"<inArgs><scannerID>%d</scannerID></inArgs>", scannerId];
    NSMutableString *xmlResponse = @"".mutableCopy;

    SBT_RESULT result = [self.apiInstance sbtExecuteCommand:SBT_RSM_ATTR_GETALL
                                                     aInXML:xmlInput
                                                    aOutXML:&xmlResponse
                                                 forScanner:scannerId];

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Supported symbologies from scanner ID %d: %@", scannerId, xmlResponse);
    } else {
        NSLog(@"Failed to retrieve supported symbologies from scanner ID %d", scannerId);
    }
}

- (void)getSymbologiesValuesFromScannerId:(int)scannerId {

    NSString *format = @"<inArgs><scannerID>%d</scannerID><cmdArgs><arg-xml><attrib_list>%@</attrib_list></arg-xml></cmdArgs></inArgs>";

    NSArray *symbologies = @[
            @(RMD_ATTR_SYM_DATAMATRIXQR),
            @(RMD_ATTR_SYM_EAN_13_JAN_13),
            @(RMD_ATTR_SYM_CODE_128)
    ];

    NSString *xmlInput = [NSString stringWithFormat:format, scannerId, [symbologies componentsJoinedByString:@","]];

    NSMutableString *xmlResponse = @"".mutableCopy;

    SBT_RESULT result = [self.apiInstance sbtExecuteCommand:SBT_RSM_ATTR_GET
                                                     aInXML:xmlInput
                                                    aOutXML:&xmlResponse
                                                 forScanner:scannerId];

    XCTAssertEqual(result, SBT_RESULT_SUCCESS, @"getSymbologiesValues expected to be success");

    if (result == SBT_RESULT_SUCCESS) {
        NSLog(@"Supported symbology values from scanner ID %d: %@", scannerId, xmlResponse);
        [self.symbologyExpectation fulfill];
    } else {
        NSLog(@"Failed to retrieve symbology values from scanner ID %d", scannerId);
    }

}

@end

@implementation ZebraIosTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInit {

    id <ISbtSdkApi> apiInstance = [SbtSdkFactory createSbtSdkApiInstance];
    NSString *version = [apiInstance sbtGetVersion];

    NSLog(@"Zebra SDK version: %@", version);

    XCTAssertEqualObjects(@"1.3.23", version);

    ZebraIosTestEventReceiver *eventListener = [[ZebraIosTestEventReceiver alloc] init];

    eventListener.discoveryExpectation = [self expectationWithDescription:@"Successful discovery"];
    eventListener.connectExpectation = [self expectationWithDescription:@"Successful connect"];
    eventListener.barcodeExpectation = [self expectationWithDescription:@"Successful scan"];
    eventListener.symbologyExpectation = [self expectationWithDescription:@"Successful symbology test"];

    eventListener.apiInstance = apiInstance;

    [apiInstance sbtSetDelegate:eventListener];

    [apiInstance sbtSubsribeForEvents:SBT_EVENT_SCANNER_APPEARANCE |
            SBT_EVENT_SCANNER_DISAPPEARANCE | SBT_EVENT_SESSION_ESTABLISHMENT |
            SBT_EVENT_SESSION_TERMINATION | SBT_EVENT_BARCODE | SBT_EVENT_IMAGE |
            SBT_EVENT_VIDEO];

    [apiInstance sbtSetOperationalMode:SBT_OPMODE_ALL];
    [apiInstance sbtEnableAvailableScannersDetection:YES];
//
//    NSMutableArray *availableScanners = [[NSMutableArray alloc] init];
//    NSMutableArray *activeScanners = [[NSMutableArray alloc] init];
//
//    [apiInstance sbtGetAvailableScannersList:&availableScanners];
//    [apiInstance sbtGetActiveScannersList:&activeScanners];
//
//    NSMutableArray *allScanners = [[NSMutableArray alloc] init];
//    [allScanners addObjectsFromArray:availableScanners];
//    [allScanners addObjectsFromArray:activeScanners];
//
//    for (SbtScannerInfo *info in allScanners) {
//        NSLog(@"Scanner is %@: ID = %d name = %@", (([info isActive] == YES) ? @"active" : @"available"), [info getScannerID], [info getScannerName]);
//    }

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {

        NSLog(@"Done waiting primary expectations");
        
        XCTAssertNil(error, "Should be no errors");
        
        if (error) {
            return;
        }

        int scannerId = eventListener.connectedId;

        eventListener.disconnectExpectation = [self expectationWithDescription:@"Successful disconnect"];

        SBT_RESULT result = [apiInstance sbtTerminateCommunicationSession:scannerId];

        BOOL success = result == SBT_RESULT_SUCCESS;

        XCTAssertTrue(success, "Disconnect should be success");

        if (success) {
            NSLog(@"Disconnect from scanner ID %d successful", scannerId);
        } else {
            NSLog(@"Failed to disconnect from scanner ID %d", scannerId);
        }
        
        [self waitForExpectations:(@[eventListener.disconnectExpectation]) timeout:5];
        
        NSLog(@"Done all\n");
        
    }];

}

@end
