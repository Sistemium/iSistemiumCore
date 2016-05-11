//
//  STMPhotosController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"

@interface STMPhotosController : STMController

@property (nonatomic, strong) NSMutableArray *waitingLocationPhotos;

+ (STMPhotosController *)sharedController;

- (STMCoreLocationTracker *)locationTracker;


@end
