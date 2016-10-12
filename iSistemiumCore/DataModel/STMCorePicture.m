//
//  STMCorePicture+CoreDataClass.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
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
