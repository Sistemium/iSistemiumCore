//
//  STMUIImagePickerController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STMImagePickerOwnerProtocol.h"


@interface STMImagePickerController : UIImagePickerController

@property (nonatomic, strong) UIViewController <STMImagePickerOwnerProtocol> *ownerVC;

- (instancetype)initWithSourceType:(UIImagePickerControllerSourceType)sourceType;

- (void)setFrameForCameraOverlayView:(UIView *)cameraOverlayView;

- (IBAction)cameraButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)photoLibraryButtonPressed:(id)sender;


@end
