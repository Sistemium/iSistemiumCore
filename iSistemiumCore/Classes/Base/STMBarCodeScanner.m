
//
//  STMBarCodeScanner.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMBarCodeScanner.h"

#import <CoreData/CoreData.h>
#import <AVFoundation/AVFoundation.h>
#import "STMScanApiHelper.h"

#import "STMNS.h"
#import "STMDataModel.h"
#import "STMSessionManager.h"
#import "STMLogger.h"
#import "STMObjectsController.h"


@interface STMBarCodeScanner() <UITextFieldDelegate, AVCaptureMetadataOutputObjectsDelegate, STMScanApiHelperDelegate>

@property (nonatomic, strong) UITextField *hiddenBarCodeTextField;

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureMetadataOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;

@property (nonatomic, strong) STMScanApiHelper *iOSScanHelper;
@property (nonatomic, strong) NSTimer* scanApiConsumer;
@property (nonatomic, strong) DeviceInfo *deviceInfo;

@property (nonatomic, strong) NSFetchedResultsController *barCodeTypesRC;


@end


@implementation STMBarCodeScanner

- (instancetype)initWithMode:(STMBarCodeScannerMode)mode {
    
    self = (mode == STMBarCodeScannerIOSMode) ? [STMBarCodeScanner iOSModeScanner] : [super init];
    
    if (self) {
        
        _mode = mode;
        _status = STMBarCodeScannerStopped;
        
    }
    return self;
    
}

- (NSString *)scannerName {
    
    switch (self.mode) {
        case STMBarCodeScannerCameraMode: {
            return @"Camera scanner";
            break;
        }
        case STMBarCodeScannerHIDKeyboardMode: {
            return @"HID scanner";
            break;
        }
        case STMBarCodeScannerIOSMode: {
            return ([self.iOSScanHelper isDeviceConnected]) ? [self.deviceInfo getName] : nil;
            break;
        }
    }
    
}

- (BOOL)isDeviceConnected {
    return (self.mode == STMBarCodeScannerIOSMode) ? [self.iOSScanHelper isDeviceConnected] : NO;
}

- (void)startScan {
    
    if (self.status != STMBarCodeScannerStarted) {
        
        _status = STMBarCodeScannerStarted;
        
        switch (self.mode) {
            case STMBarCodeScannerCameraMode: {
                
                [self prepareForCameraMode];
                break;
                
            }
            case STMBarCodeScannerHIDKeyboardMode: {
                
                [self prepareForHIDScanMode];
                break;
                
            }
            case STMBarCodeScannerIOSMode: {
                
                [self prepareForIOSScanMode];
                break;
            }
            default: {
                break;
            }
        }
        
    }
    
}

- (void)stopScan {
    
    if (self.status != STMBarCodeScannerStopped) {
        
        _status = STMBarCodeScannerStopped;
        
        switch (self.mode) {
            case STMBarCodeScannerCameraMode: {
                
                [self finishCameraMode];
                break;
                
            }
            case STMBarCodeScannerHIDKeyboardMode: {
                
                [self finishHIDScanMode];
                break;
                
            }
            case STMBarCodeScannerIOSMode: {
                
                [self finishIOSScanMode];
                break;
            }
            default: {
                break;
            }
        }
        
        self.delegate = nil;
        
    }
    
}

- (NSFetchedResultsController *)barCodeTypesRC {
    
    if (!_barCodeTypesRC) {
        
        NSManagedObjectContext *context = [[STMSessionManager sharedManager].currentSession document].managedObjectContext;
        
        if (context) {
            
            STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMBarCodeType class])];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
            request.predicate = [STMPredicate predicateWithNoFantoms];
            
            NSFetchedResultsController *rc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                 managedObjectContext:context
                                                                                   sectionNameKeyPath:nil
                                                                                            cacheName:nil];
            [rc performFetch:nil];
            
            _barCodeTypesRC = rc;
            
        }
        
    }
    return _barCodeTypesRC;
    
}

- (void)checkScannedBarcode:(NSString *)barcode {
    
    STMBarCodeScannedType type = [STMBarCodeController barcodeTypeFromTypes:self.barCodeTypesRC.fetchedObjects forBarcode:barcode];
    
    STMBarCodeScan *barCodeScan = (STMBarCodeScan *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMBarCodeScan class])
                                                                                        isFantom:NO];
    barCodeScan.code = barcode;
    
    [self.delegate barCodeScanner:self receiveBarCode:barcode withType:type];
    [self.delegate barCodeScanner:self receiveBarCodeScan:barCodeScan withType:type];
    
    [[STMObjectsController document] saveDocument:^(BOOL success) {
        
    }];
    
}


#pragma mark - STMBarCodeScannerCameraMode

- (void)prepareForCameraMode {
    
    if ([STMBarCodeScanner isCameraAvailable]) {
        
        [self setupScanner];
        
    } else {
        
        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
        
        NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey: @"No camera available"}];
        
        [self.delegate barCodeScanner:self receiveError:error];
        
        [self stopScan];
        
    }
    
}

- (void)finishCameraMode {
    
    [self.session stopRunning];
    [self.preview removeFromSuperlayer];
    
    self.preview = nil;
    self.output = nil;
    self.session = nil;
    self.input = nil;
    self.device = nil;
    
}

+ (BOOL)isCameraAvailable {
    
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    return ([videoDevices count] > 0);
    
}

- (void)setupScanner {
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    self.session = [[AVCaptureSession alloc] init];
    self.output = [[AVCaptureMetadataOutput alloc] init];
    
    [self.session addOutput:self.output];
    [self.session addInput:self.input];
    
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    //    self.output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    
    self.output.metadataObjectTypes = self.output.availableMetadataObjectTypes;
    
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    UIView *superView = [self.delegate viewForScanner:self];
    self.preview.frame = CGRectMake(0, 0, superView.frame.size.width, superView.frame.size.height);
    
    AVCaptureConnection *con = self.preview.connection;
    
    con.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [superView.layer insertSublayer:self.preview above:superView.layer];
    
    [self.session startRunning];
    
}


#pragma mark AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    for (AVMetadataObject *current in metadataObjects) {
        
        if([current isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            
            NSString *scannedValue = [(AVMetadataMachineReadableCodeObject *)current stringValue];
            [self didSuccessfullyScan:scannedValue];
            
        }
        
    }
    
}

- (void)didSuccessfullyScan:(NSString *)aScannedValue {
    
    //    NSLog(@"aScannedValue %@", aScannedValue);
    
    [self checkScannedBarcode:aScannedValue];
    [self stopScan];
    
}


#pragma mark - STMBarCodeScannerHIDKeyboardMode

- (void)prepareForHIDScanMode {
    
    
    self.hiddenBarCodeTextField = [[UITextField alloc] init];
    
    self.hiddenBarCodeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.hiddenBarCodeTextField.keyboardType = UIKeyboardTypeASCIICapable;
    
    if ([self.hiddenBarCodeTextField respondsToSelector:@selector(inputAssistantItem)]) {
        
        UITextInputAssistantItem *inputAssistantItem = self.hiddenBarCodeTextField.inputAssistantItem;
        inputAssistantItem.leadingBarButtonGroups = @[];
        inputAssistantItem.trailingBarButtonGroups = @[];
        
    }
    
    [self.hiddenBarCodeTextField becomeFirstResponder];
    
    self.hiddenBarCodeTextField.delegate = self;
    
    [[self.delegate viewForScanner:self] addSubview:self.hiddenBarCodeTextField];
    
}

- (void)finishHIDScanMode {
    
    [self.hiddenBarCodeTextField resignFirstResponder];
    [self.hiddenBarCodeTextField removeFromSuperview];
    self.hiddenBarCodeTextField.delegate = nil;
    self.hiddenBarCodeTextField = nil;
    
}


#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    [self checkScannedBarcode:textField.text];
    textField.text = @"";
    
    return NO;
    
}


#pragma mark - STMBarCodeScannerIOSMode

+ (STMBarCodeScanner *)iOSModeScanner {
    
    static dispatch_once_t pred = 0;
    __strong static id _iOSModeScanner = nil;
    
    dispatch_once(&pred, ^{
        
        _iOSModeScanner = [[STMBarCodeScanner alloc] init];
        [self addScanHelperToScanner:_iOSModeScanner];
        
    });
    
    return _iOSModeScanner;
    
}

+ (void)addScanHelperToScanner:(STMBarCodeScanner *)scanner {
    
    scanner.iOSScanHelper = [[STMScanApiHelper alloc] init];
    [scanner.iOSScanHelper setDelegate:scanner];
    [scanner.iOSScanHelper open];
    
    scanner.scanApiConsumer = [NSTimer scheduledTimerWithTimeInterval:.2
                                                               target:scanner
                                                             selector:@selector(onScanApiConsumerTimer:)
                                                             userInfo:nil
                                                              repeats:YES];
    
}

- (void)prepareForIOSScanMode {
    
}

-(void)onScanApiConsumerTimer:(NSTimer*)timer {
    
    if (timer == self.scanApiConsumer){
        [self.iOSScanHelper doScanApiReceive];
    }
    
}

- (void)finishIOSScanMode {
    
}

- (void)getBeepStatus {
    
    [self.iOSScanHelper postGetDecodeAction:self.deviceInfo
                                     Target:self
                                   Response:@selector(onGetBeepStatus:)];
    
}

- (void)getRumbleStatus {
    
    [self.iOSScanHelper postGetDecodeAction:self.deviceInfo
                                     Target:self
                                   Response:@selector(onGetRumbleStatus:)];
    
}

- (void)setBeepStatus:(BOOL)beepStatus andRumbleStatus:(BOOL)rumbleStatus {
    
    int beepDecodeAction = (beepStatus) ? kSktScanLocalDecodeActionBeep : kSktScanLocalDecodeActionNone;
    int rumbleDecodeAction = (rumbleStatus) ? kSktScanLocalDecodeActionRumble : kSktScanLocalDecodeActionNone;
    int flashDecodeAction = kSktScanLocalDecodeActionFlash;
    
    int combineDecodeAction = (beepDecodeAction|rumbleDecodeAction|flashDecodeAction);
    
    [self.iOSScanHelper postSetDecodeAction:self.deviceInfo
                               DecodeAction:combineDecodeAction
                                     Target:self
                                   Response:@selector(onSetDecodeAction:)];
    
}

- (void)getBatteryStatus {
    
    [self.iOSScanHelper postGetBattery:self.deviceInfo
                                Target:self
                              Response:@selector(onGetBatteryStatus:)];
    
}

- (void)getVersion {
    [self getVersionForDevice:self.deviceInfo];
}


#pragma mark - Scan API callbacks

- (void)onGetBeepStatus:(ISktScanObject *)scanObj {
    [self getBeepStatusFrom:scanObj];
}

- (void)onGetRumbleStatus:(ISktScanObject *)scanObj {
    [self getRumbleStatusFrom:scanObj];
}

- (void)onSetDecodeAction:(ISktScanObject *)scanObj {

    SKTRESULT result = [[scanObj Msg] Result];

    NSLog(@"onSetDecodeAction result: %@", @(result));
    
}

- (void)onGetBatteryStatus:(ISktScanObject *)scanObj {
    
    unsigned long batteryStatus = [[scanObj Property] getUlong];
    
    unsigned char currentLevel = SKTBATTERY_GETCURLEVEL(batteryStatus);
    
    NSNumber *batteryLevel = [NSNumber numberWithUnsignedChar:currentLevel];

    if ([self.delegate respondsToSelector:@selector(receiveBatteryLevel:)]) {
        [self.delegate receiveBatteryLevel:batteryLevel];
    }
    
}

- (void)getBeepStatusFrom:(ISktScanObject *)scanObj {
    
    BOOL isBeepEnabled = ([[scanObj Property] getByte] & kSktScanLocalDecodeActionBeep);

    if ([self.delegate respondsToSelector:@selector(receiveScannerBeepStatus:)]) {
        [self.delegate receiveScannerBeepStatus:isBeepEnabled];
    }
    
}

- (void)getRumbleStatusFrom:(ISktScanObject *)scanObj {
    
    BOOL isRumbleEnabled = ([[scanObj Property] getByte] & kSktScanLocalDecodeActionRumble);
    
    if ([self.delegate respondsToSelector:@selector(receiveScannerRumbleStatus:)]) {
        [self.delegate receiveScannerRumbleStatus:isRumbleEnabled];
    }

}

- (void)postGetPostamble:(ISktScanObject *)scanObj {
    NSLog(@"%@", scanObj);
}

- (void)postGetSymbology:(ISktScanObject *)scanObj {

    SKTRESULT result = [[scanObj Msg] Result];
    
    if (SKTSUCCESS(result)) {
        
        DeviceInfo *deviceInfo=[self.iOSScanHelper getDeviceInfoFromScanObject:scanObj];
        
        if (deviceInfo){
            
            ISktScanSymbology *symbology = [[scanObj Property] Symbology];
            
            enum ESktScanSymbologyID symbologyID = [symbology getID];
            
            NSArray *availableSymbologies = [self.barCodeTypesRC.fetchedObjects valueForKeyPath:@"symbology"];
            
            if ([availableSymbologies containsObject:[symbology getName]]) {
                
                if ([symbology getStatus] == kSktScanSymbologyStatusDisable) {
                    
                    [self.iOSScanHelper postSetSymbologyInfo:deviceInfo
                                                 SymbologyId:symbologyID
                                                      Status:TRUE
                                                      Target:nil
                                                    Response:nil];
                    
                }

            } else {
                
                if ([symbology getStatus] == kSktScanSymbologyStatusEnable) {
                    
                    [self.iOSScanHelper postSetSymbologyInfo:deviceInfo
                                                 SymbologyId:symbologyID
                                                      Status:FALSE
                                                      Target:nil
                                                    Response:nil];
                    
                }

            }
            
        }
        
    }

}

- (void)checkSymbologiesOnDevice:(DeviceInfo *)deviceInfo {
    
    for (enum ESktScanSymbologyID symbology = kSktScanSymbologyNotSpecified; symbology < kSktScanSymbologyLastSymbologyID; symbology++) {
        
        [self.iOSScanHelper postGetSymbologyInfo:deviceInfo
                                     SymbologyId:symbology
                                          Target:self
                                        Response:@selector(postGetSymbology:)];
        
    }
    
}

- (void)setBatteryLevelNotificationForDevice:(DeviceInfo *)deviceInfo {
    
    ISktScanObject*scanObj=[SktClassFactory createScanObject];
    
    [[scanObj Property] setID:kSktScanPropIdNotificationsDevice];
    [[scanObj Property] setType:kSktScanPropTypeUlong];
    [[scanObj Property] setUlong:kSktScanNotificationsBatteryLevelChange];
    
    CommandContext *command = [[CommandContext alloc] initWithParam:NO
                                                            ScanObj:scanObj
                                                         ScanDevice:[deviceInfo getSktScanDevice]
                                                             Device:deviceInfo
                                                             Target:self
                                                           Response:@selector(onSetBatteryLevelNotification:)];
    
    [self.iOSScanHelper addCommand:command];
    
}

- (void)setPowerButtonPressNotificationForDevice:(DeviceInfo *)deviceInfo {
    
    ISktScanObject*scanObj=[SktClassFactory createScanObject];
    
    [[scanObj Property] setID:kSktScanPropIdNotificationsDevice];
    [[scanObj Property] setType:kSktScanPropTypeUlong];
    [[scanObj Property] setUlong:kSktScanNotificationsPowerButtonPress];
    
    CommandContext *command = [[CommandContext alloc] initWithParam:NO
                                                            ScanObj:scanObj
                                                         ScanDevice:[deviceInfo getSktScanDevice]
                                                             Device:deviceInfo
                                                             Target:self
                                                           Response:@selector(onSetPowerButtonPressNotification:)];
    
    [self.iOSScanHelper addCommand:command];
    
}

- (void)getVersionForDevice:(DeviceInfo *)deviceInfo {
    
    ISktScanObject*scanObj=[SktClassFactory createScanObject];
    
    [[scanObj Property] setID:kSktScanPropIdVersionDevice];
    [[scanObj Property] setType:kSktScanPropTypeNone];
    
    CommandContext *command = [[CommandContext alloc] initWithParam:YES
                                                            ScanObj:scanObj
                                                         ScanDevice:[deviceInfo getSktScanDevice]
                                                             Device:deviceInfo
                                                             Target:self
                                                           Response:@selector(onGetVersion:)];
    
    [self.iOSScanHelper addCommand:command];
    
}



#pragma mark ScanApiHelperDelegate

- (void)onDeviceArrival:(SKTRESULT)result device:(DeviceInfo *)deviceInfo {
    
    self.deviceInfo = deviceInfo;
    
    NSString *logMessage = [NSString stringWithFormat:@"Connect scanner: %@", [deviceInfo getName]];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"important"];
    
    [self.iOSScanHelper postSetPostambleDevice:deviceInfo Postamble:@"" Target:nil Response:nil];
    
    [self checkSymbologiesOnDevice:deviceInfo];
    
    [self setBatteryLevelNotificationForDevice:deviceInfo];
    [self setPowerButtonPressNotificationForDevice:deviceInfo];
    [self getVersionForDevice:deviceInfo];
    
    if ([self.delegate respondsToSelector:@selector(deviceArrivalForBarCodeScanner:)]) {
        [self.delegate deviceArrivalForBarCodeScanner:self];
    }
    
}

- (void)onDeviceRemoval:(DeviceInfo *)deviceRemoved {
    
    self.deviceInfo = nil;
    
    NSString *logMessage = [NSString stringWithFormat:@"Disconnect scanner: %@", [deviceRemoved getName]];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"important"];
    
    if ([self.delegate respondsToSelector:@selector(deviceRemovalForBarCodeScanner:)]) {
        [self.delegate deviceRemovalForBarCodeScanner:self];
    }
    
}

- (void)onDecodedDataResult:(long)result device:(DeviceInfo *)device decodedData:(ISktScanDecodedData *)decodedData {
    
    if (SKTSUCCESS(result)) {
        
        NSString *resultString = [NSString stringWithUTF8String:(const char *)[decodedData getData]];
        
        [self checkScannedBarcode:resultString];
        
    }
    
}

- (void)onError:(SKTRESULT)result {
    
    NSLog(@"error: %ld", result);
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                         code:0
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", @(result)]}];
    
    [self.delegate barCodeScanner:self receiveError:error];
    
}

- (void)onErrorRetrievingScanObject:(SKTRESULT)result {
    [self onError:result];
}

- (void)onButtonsEvent:(ISktScanObject *)scanObj {
    NSLogMethodName;
}

- (void)onSetBatteryLevelNotification:(ISktScanObject *)scanObj {
    
    SKTRESULT result = [[scanObj Msg] Result];
    
    if (SKTSUCCESS(result)) {
        NSLog(@"setBatteryLevelNotification SUCCESS");
    } else {
        NSLog(@"setBatteryLevelNotification NOT SUCCESS");
    }
    
}

- (void)onSetPowerButtonPressNotification:(ISktScanObject *)scanObj {
    
    SKTRESULT result = [[scanObj Msg] Result];
    
    if (SKTSUCCESS(result)) {
        NSLog(@"setPowerButtonPressNotification SUCCESS");
    } else {
        NSLog(@"setPowerButtonPressNotification NOT SUCCESS");
    }
    
}

- (void)onGetVersion:(ISktScanObject *)scanObj {
    
    SKTRESULT result = [[scanObj Msg] Result];
    
    if (SKTSUCCESS(result)) {
        
        ISktScanProperty *property = [scanObj Property];
        
        if ([property getType] == kSktScanPropTypeVersion) {
            
            NSString *version = [NSString stringWithFormat:@"%lx.%lx.%lx.%ld",
                                            [[property Version] getMajor],
                                            [[property Version] getMiddle],
                                            [[property Version] getMinor],
                                            [[property Version] getBuild]];

            NSLog(@"scanner version: %@", version);
            
            if ([self.delegate respondsToSelector:@selector(receiveVersion:)]) {
                [self.delegate receiveVersion:version];
            }

        } else {
            
            NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
            
            NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                 code:0
                                             userInfo:@{NSLocalizedDescriptionKey: @"getVersion NOT SUCCESS"}];
            
            [self.delegate barCodeScanner:self receiveError:error];

            NSLog(error.localizedDescription);

        }

        
    } else {
        
        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
        
        NSError *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey: @"getVersion NOT SUCCESS"}];
        
        [self.delegate barCodeScanner:self receiveError:error];
        
        NSLog(error.localizedDescription);
        
    }
    
}


@end