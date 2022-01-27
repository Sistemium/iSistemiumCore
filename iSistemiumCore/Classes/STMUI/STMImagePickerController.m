//
//  STMUIImagePickerController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMImagePickerController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "STMConstants.h"
#import "STMLogger.h"


@interface STMImagePickerController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIAlertViewDelegate>

@end


@implementation STMImagePickerController

- (instancetype)initWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    
    self = [super init];
    
    if (self) {
        
        self.delegate = self;
        
        self.sourceType = sourceType;
        
        if (sourceType == UIImagePickerControllerSourceTypeCamera) {
            
            self.showsCameraControls = NO;
            
            UIView *cameraOverlayView = [[NSBundle mainBundle] loadNibNamed:@"STMCameraOverlayView"
                                                                      owner:self
                                                                    options:nil].firstObject;
            
            [self setFrameForCameraOverlayView:cameraOverlayView];
            
            self.cameraOverlayView = cameraOverlayView;
            
        }
        
    }
    return self;
    
}

- (void)setFrameForCameraOverlayView:(UIView *)cameraOverlayView {
    
    cameraOverlayView.backgroundColor = [UIColor clearColor];
    cameraOverlayView.autoresizesSubviews = YES;
    cameraOverlayView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    
    if (SYSTEM_VERSION >= 8.0) {
        
        UIView *rootView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
        CGRect originalFrame = [UIScreen mainScreen].bounds;
        CGRect screenFrame = [rootView convertRect:originalFrame fromView:nil];
        cameraOverlayView.frame = screenFrame;
        
        if (IPHONE) {
            
            CGFloat camHeight = screenFrame.size.width * 4 / 3; // 4/3 — camera aspect ratio

            CGFloat toolbarHeight = TOOLBAR_HEIGHT;

            for (UIView *subview in self.cameraOverlayView.subviews)
                if ([subview isKindOfClass:[UIToolbar class]])
                    toolbarHeight = subview.frame.size.height;

            CGFloat translationDistance = (screenFrame.size.height - toolbarHeight - camHeight) / 2;

            CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, translationDistance);
            self.cameraViewTransform = translate;
            
        }
        
    }
    
}

- (BOOL)shouldAutorotate {
    
    return (IPHONE && SYSTEM_VERSION >= 8.0) ? NO : [super shouldAutorotate];
    
}


#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    //    NSLog(@"picker didFinishPickingMediaWithInfo");
    
    [picker dismissViewControllerAnimated:NO completion:^{
        
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
            
            [self.ownerVC saveImage:image andWaitForLocation:[self.ownerVC shouldWaitForLocation]];
            
        } else {
            
            NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
            
            if (assetURL) {
                
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                
                [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
                    
                    if ([[asset valueForProperty:ALAssetPropertyLocation] isKindOfClass:[CLLocation class]]) {
                        
                        [self.ownerVC saveImage:image withLocation:[asset valueForProperty:ALAssetPropertyLocation]];
                        
                    } else {
                        
                        [self.ownerVC saveImage:image andWaitForLocation:NO];
                        
                    }
                    
                } failureBlock:^(NSError *error) {
                    
                    NSLog(@"assetForURL %@ error %@", assetURL, error.localizedDescription);
                    
                    [self.ownerVC saveImage:image andWaitForLocation:NO];
                    
                }];
                
            } else {
                
                [self.ownerVC saveImage:image andWaitForLocation:NO];
                
            }
            
        }
        
        [self.ownerVC imagePickerWasDissmised:picker];
        
    }];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    [picker dismissViewControllerAnimated:NO completion:^{
        [self.ownerVC imagePickerControllerDidCancel:picker];
    }];
    
}


#pragma mark - image picker view buttons

- (IBAction)cameraButtonPressed:(id)sender {
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    if (status != AVAuthorizationStatusAuthorized) {
        return [self checkAuthorizationStatus];
    }
    
//    UIView *view = [[UIView alloc] initWithFrame:self.cameraOverlayView.frame];
//    view.backgroundColor = [UIColor grayColor];
//    view.alpha = 0.75;
//    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    spinner.center = view.center;
//    [spinner startAnimating];
//    [view addSubview:spinner];
//    
//    [self.cameraOverlayView addSubview:view];
    
    [self takePicture];
    
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self.delegate imagePickerControllerDidCancel:self];
}

- (IBAction)photoLibraryButtonPressed:(id)sender {
    
    [self dismissViewControllerAnimated:NO completion:^{
    }];
    
    [self.ownerVC showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    
}



#pragma mark - orientation fix

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    
    if (IPHONE) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
    
}


#pragma mark - authorizationStatus

- (void)checkAuthorizationStatus {
    
    NSString *statusString = @"";
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    switch (status) {
        case AVAuthorizationStatusNotDetermined:
            statusString = @"not determined";
            break;
            
        case AVAuthorizationStatusRestricted:
            statusString = @"restricted";
            [self showCameraPermissionAlert:statusString];
            break;
            
        case AVAuthorizationStatusDenied:
            statusString = @"denied";
            [self showCameraPermissionAlert:statusString];
            break;
            
        case AVAuthorizationStatusAuthorized:
            statusString = @"authorized";
            break;
            
        default:
            break;
    }
    
    NSString *logMessage = [@"Camera permission: " stringByAppendingString:statusString];
    
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                             numType:STMLogMessageTypeImportant];
    
}

- (void)showCameraPermissionAlert:(NSString *)alertReason {
    
    NSString *alertMessage = nil;
    NSString *settingButtonTitle = nil;
    
    if ([alertReason isEqualToString:@"restricted"]) {
        
        alertMessage = NSLocalizedString(@"CAMERA PERMISSION RESTRICTED", nil);
        
    } else if ([alertReason isEqualToString:@"denied"]) {
        
        alertMessage = NSLocalizedString(@"CAMERA PERMISSION DENIED", nil);
        settingButtonTitle = NSLocalizedString(@"SETTINGS", nil);
        
    }
    
    if (alertMessage) {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"WARNING", nil)
                                                            message:alertMessage
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
            
            if (settingButtonTitle) [alert addButtonWithTitle:settingButtonTitle];
            [alert show];
            
        }];
        
    }
    
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 1) {
        
        NSURL *appSettings = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:appSettings];
        
        [self cancelButtonPressed:self];
        
    }
    
}


#pragma mark - view lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
        [self checkAuthorizationStatus];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
