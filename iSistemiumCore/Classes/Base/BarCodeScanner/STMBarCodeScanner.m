
//
//  STMBarCodeScanner.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreSessionManager.h"
#import "STMCoreBarCodeController.h"
#import "STMBarCodeScanner.h"

#import <AVFoundation/AVFoundation.h>
#import "STMBarCodeZebra.h"

@interface STMBarCodeScanner () <UITextFieldDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) UITextField *hiddenBarCodeTextField;

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureMetadataOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;

@property (nonatomic, strong) NSTimer *scanApiConsumer;

@property (nonatomic, strong) NSArray *barCodeTypes;
@property (nonatomic, strong) STMBarCodeZebra *zebra;

@end


@implementation STMBarCodeScanner

- (instancetype)initWithMode:(STMBarCodeScannerMode)mode {

    self = mode == STMBarCodeScannerIOSMode ? [STMBarCodeScanner iOSModeScanner] : [self init];

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
        }
        case STMBarCodeScannerHIDKeyboardMode: {
            return @"HID scanner";
        }
        case STMBarCodeScannerIOSMode: {
            return nil;
        }
    }

}

- (BOOL)isDeviceConnected {

    if (self.mode != STMBarCodeScannerIOSMode) {
        return NO;
    } else if (self.zebra) {
        return [self.zebra isDeviceConnected];
    }

    return NO;

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

//        self.delegate = nil;

    }

}

//- (NSFetchedResultsController *)barCodeTypesRC {
//    
//    if (!_barCodeTypesRC) {
//        
//        NSManagedObjectContext *context = [STMCoreSessionManager sharedManager].currentSession.document.managedObjectContext;
//        
//        if (context) {
//            
//            STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMBarCodeType class])];
//            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
//            request.predicate = [STMPredicate predicateWithNoFantoms];
//            
//            NSFetchedResultsController *rc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
//                                                                                 managedObjectContext:context
//                                                                                   sectionNameKeyPath:nil
//                                                                                            cacheName:nil];
//            [rc performFetch:nil];
//            
//            _barCodeTypesRC = rc;
//            
//        }
//        
//    }
//    return _barCodeTypesRC;
//    
//}

- (id <STMPersistingSync>)persistenceDelegate {
    return [[STMCoreSessionManager sharedManager].currentSession persistenceDelegate];
}

- (NSArray *)barCodeTypes {

    if (!_barCodeTypes) {

        NSArray *barCodeTypes = [self.persistenceDelegate findAllSync:@"STMBarCodeType"
                                                            predicate:nil
                                                              options:nil
                                                                error:nil];
        _barCodeTypes = barCodeTypes;

    }

    return _barCodeTypes;

}

- (void)checkScannedBarcode:(NSString *)barcode {

    STMBarCodeScannedType type = [STMCoreBarCodeController barcodeTypeFromTypesDics:self.barCodeTypes forBarcode:barcode];

    STMBarCodeScan *barCodeScan = [[STMBarCodeScan alloc] init];
    barCodeScan.code = barcode;

    [self.delegate barCodeScanner:self receiveBarCode:barcode withType:type];
    [self.delegate barCodeScanner:self receiveBarCodeScan:barCodeScan withType:type];

}


#pragma mark - STMBarCodeScannerCameraMode

- (void)prepareForCameraMode {

    if ([STMBarCodeScanner isCameraAvailable]) {

        [self setupScanner];

    } else {

        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;

        NSError *error = [NSError errorWithDomain:bundleId
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

        if ([current isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {

            NSString *scannedValue = [(AVMetadataMachineReadableCodeObject *) current stringValue];
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [self checkScannedBarcode:textField.text];
    textField.text = @"";

    return NO;

}


#pragma mark - STMBarCodeScannerIOSMode

+ (NSString *)scannerType {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *scannerType = [defaults objectForKey:@"ScannerType"];

    if (!scannerType) {
        scannerType = @"zebra";
        [defaults setValue:scannerType forKey:@"ScannerType"];
        [defaults synchronize];
    }

    NSLog(@"ScannerType is %@", scannerType);

    return scannerType;

}

+ (STMBarCodeScanner *)iOSModeScanner {

    static dispatch_once_t pred = 0;
    __strong static STMBarCodeScanner *_iOSModeScanner = nil;

    dispatch_once(&pred, ^{

        _iOSModeScanner = [[STMBarCodeScanner alloc] init];

        NSString *scannerType = [self scannerType];
        
        bool connectZebra = [scannerType isEqualToString:@"zebra"];
        bool connectSocket = [scannerType isEqualToString:@"socketMobile"];
        
        if ([scannerType isEqualToString:@"both"]) {
            connectZebra = connectSocket = YES;
        }

        if (connectSocket) {
            [self addScanHelperToScanner:_iOSModeScanner];
        }
        
        if (connectZebra) {
            STMBarCodeZebra *zebra = [[STMBarCodeZebra alloc] init];
            _iOSModeScanner.zebra = zebra;
            _iOSModeScanner.zebra.stmScanningDelegate = _iOSModeScanner;
        }

    });

    return _iOSModeScanner;

}

+ (void)addScanHelperToScanner:(STMBarCodeScanner *)scanner {

}

- (void)setDelegate:(UIViewController <STMBarCodeScannerDelegate> *)delegate {

    _delegate = delegate;

    if (delegate && self.zebra && !self.zebra.isDeviceConnected) {
        [self.zebra showPairingAlertInViewController:delegate];
    }

}

- (void)prepareForIOSScanMode {

}

- (void)onScanApiConsumerTimer:(NSTimer *)timer {


}

- (void)finishIOSScanMode {
    if (self.zebra) {
        [self.zebra disconnect];
    }
}

- (void)getBeepStatus {

}

- (void)getRumbleStatus {

}

- (void)setBeepStatus:(BOOL)beepStatus andRumbleStatus:(BOOL)rumbleStatus {

}

- (void)getBatteryStatus {


}

- (void)getVersion {
}

- (void)barCodeScanner:(id <STMBarCodeScanningDevice>)scanner receiveBarCode:(NSString *)barcode withType:(STMBarCodeScannedType)type {

    [self checkScannedBarcode:barcode];

}

- (void)deviceArrivalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner {
    
    if ([self.delegate respondsToSelector:@selector(deviceArrivalForBarCodeScanner:)]) {
            [self.delegate deviceArrivalForBarCodeScanner:self];
        }

}

- (void)deviceRemovalForBarCodeScanner:(id <STMBarCodeScanningDevice>)scanner {
    if ([self.delegate respondsToSelector:@selector(deviceRemovalForBarCodeScanner:)]) {
        [self.delegate deviceRemovalForBarCodeScanner:self];
    }
}


@end
