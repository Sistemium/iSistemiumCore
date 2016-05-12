//
//  STMCorePhotosController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

@interface STMCorePhotosController : STMCoreController

@property (nonatomic, strong) NSMutableArray *waitingLocationPhotos;

+ (instancetype)sharedController;

- (STMCoreLocationTracker *)locationTracker;


@end
