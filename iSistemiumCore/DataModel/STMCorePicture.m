//
//  STMCorePicture.m
//  iSistemiumCore
//
//  Created by Maxim Grigoriev on 12/05/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCorePicture.h"

#import "STMCorePicturesController.h"


@implementation STMCorePicture

- (void)willSave {
    
    if (self.isDeleted) {
        
        [self checkPictureClass];
        
        [STMCorePicturesController removeImageFilesForPicture:self];
        
    }
    
    [super willSave];
    
}

- (void)checkPictureClass {

}


@end
