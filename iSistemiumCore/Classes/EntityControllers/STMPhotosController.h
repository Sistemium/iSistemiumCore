//
//  STMPhotosController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"

@interface STMPhotosController : STMController

+ (STMPhotosController *)sharedController;

#warning should override
//- (void)addPhotoReportToWaitingLocation:(STMPhotoReport *)photoReport;
//- (void)photoReportWasDeleted:(STMPhotoReport *)photoReport;

@end
