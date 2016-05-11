//
//  STMPicture.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 17/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMPicture.h"

#import "STMCorePicturesController.h"
#import "STMPhotosController.h"


@implementation STMPicture

- (void)willSave {
    
    if (self.isDeleted) {
        
#warning should override
//        if ([self isKindOfClass:[STMPhotoReport class]]) {
//            [[STMPhotosController sharedController] photoReportWasDeleted:(STMPhotoReport *)self];
//        }
        
        [STMCorePicturesController removeImageFilesForPicture:self];
        
    }
    
    [super willSave];
    
}


@end
