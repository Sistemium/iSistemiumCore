//
//  STMImagePickerOwnerProtocol.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MapKit/MapKit.h>


@protocol STMImagePickerOwnerProtocol <NSObject>

@required

- (void)saveImage:(UIImage *)image withLocation:(CLLocation *)location;
- (void)saveImage:(UIImage *)image andWaitForLocation:(BOOL)waitForLocation;

- (BOOL)shouldWaitForLocation;

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)imageSourceType;
- (void)imagePickerWasDissmised:(UIImagePickerController *)picker;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;


@end
