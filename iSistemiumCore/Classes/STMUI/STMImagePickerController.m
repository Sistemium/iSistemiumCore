//
//  STMUIImagePickerController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMImagePickerController.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import "STMConstants.h"


@interface STMImagePickerController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end


@implementation STMImagePickerController

- (instancetype)initWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    
    self = [super init];
    
    if (self) {

        self.delegate = self;
        
        self.sourceType = sourceType;
        
        if (sourceType == UIImagePickerControllerSourceTypeCamera) {
            
            self.showsCameraControls = NO;
            
            UIView *cameraOverlayView = [[NSBundle mainBundle] loadNibNamed:@"STMCameraOverlayView" owner:self options:nil].firstObject;
            
            cameraOverlayView.backgroundColor = [UIColor clearColor];
            cameraOverlayView.autoresizesSubviews = YES;
            cameraOverlayView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
            
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                
                UIView *rootView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
                CGRect originalFrame = [UIScreen mainScreen].bounds;
                CGRect screenFrame = [rootView convertRect:originalFrame fromView:nil];
                cameraOverlayView.frame = screenFrame;
                
                CGFloat camHeight = screenFrame.size.width * 4 / 3; // 4/3 — camera aspect ratio
                
                CGFloat toolbarHeight = TOOLBAR_HEIGHT;
                
                for (UIView *subview in self.cameraOverlayView.subviews)
                    if ([subview isKindOfClass:[UIToolbar class]])
                        toolbarHeight = subview.frame.size.height;
                
                CGFloat translationDistance = (screenFrame.size.height - toolbarHeight - camHeight) / 2;
                
                CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, translationDistance);
                self.cameraViewTransform = translate;

            }
            
            self.cameraOverlayView = cameraOverlayView;
            
        }
        
    }
    return self;
    
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
            
            [self.ownerVC saveImage:image andWaitForLocation:YES];
            
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
        [self.ownerVC imagePickerWasDissmised:picker];
    }];
    
//    [self.spinnerView removeFromSuperview];
//    
//    STMPhotoReport *photoReportToRemove = self.selectedPhotoReport;
//    self.selectedPhotoReport = nil;
//    
//    [STMObjectsController removeObject:photoReportToRemove];
//    self.imagePickerController = nil;
    
}


#pragma mark - image picker view buttons

- (IBAction)cameraButtonPressed:(id)sender {
    
    UIView *view = [[UIView alloc] initWithFrame:self.cameraOverlayView.frame];
    view.backgroundColor = [UIColor grayColor];
    view.alpha = 0.75;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = view.center;
    [spinner startAnimating];
    [view addSubview:spinner];
    
    [self.cameraOverlayView addSubview:view];
    
    [self takePicture];
    
}

- (IBAction)cancelButtonPressed:(id)sender {
    
    [self imagePickerControllerDidCancel:self];
    
}

- (IBAction)photoLibraryButtonPressed:(id)sender {
    
    [self cancelButtonPressed:sender];
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


#pragma mark - view lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
