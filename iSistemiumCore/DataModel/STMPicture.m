//
//  STMPicture.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 17/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMPicture.h"

#import "STMPicturesController.h"
#import "STMPhotosController.h"


@implementation STMPicture

- (void)willSave {
    
    if (self.isDeleted) {
        
#warning should override
//        if ([self isKindOfClass:[STMPhotoReport class]]) {
//            [[STMPhotosController sharedController] photoReportWasDeleted:(STMPhotoReport *)self];
//        }
        
        [STMPicturesController removeImageFilesForPicture:self];
        
    }
    
    [super willSave];
    
}


@end
