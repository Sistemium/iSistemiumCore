//
//  STMCorePhotosController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMCorePhoto.h"
#import "STMCoreLocationTracker.h"

@interface STMCorePhotosController : STMCoreController

@property (nonatomic, strong) NSMutableArray *waitingLocationPhotos;

+ (instancetype)sharedController;

+ (NSDictionary *)newPhotoObjectEntityName:(NSString *)entityName photoData:(NSData *)photoData;

+ (void)uploadPhotoEntityName:(NSString *)entityName antributes:(NSDictionary *)atributes photoData:(NSData *)photoData;

- (STMCoreLocationTracker *)locationTracker;


@end
