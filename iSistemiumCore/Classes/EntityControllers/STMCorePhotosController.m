//
//  STMCorePhotosController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCorePhotosController.h"

#import "STMCoreSessionManager.h"
#import "STMLocationController.h"
#import "STMCoreObjectsController.h"
#import "STMCorePicturesController.h"


@interface STMCorePhotosController()

@property (nonatomic) BOOL isPhotoLocationProcessing;


@end


@implementation STMCorePhotosController

+ (instancetype)sharedController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedController = nil;
    
    dispatch_once(&pred, ^{
        
        _sharedController = [[self alloc] init];
        
    });
    
    return _sharedController;
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self addObservers];
    }
    return self;
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(currentLocationWasUpdated:)
               name:@"currentLocationWasUpdated"
             object:[self locationTracker]];
    
}

- (STMCoreLocationTracker *)locationTracker {
    return [(STMCoreSession *)[STMCoreSessionManager sharedManager].currentSession locationTracker];
}

- (NSMutableArray *)waitingLocationPhotos {
    
    if (!_waitingLocationPhotos) {
        _waitingLocationPhotos = [NSMutableArray array];
    }
    
    return _waitingLocationPhotos;
    
}


#pragma mark - update locations

- (void)currentLocationWasUpdated:(NSNotification *)notification {
    
    if (self.waitingLocationPhotos.count > 0 && !self.isPhotoLocationProcessing) {
        
        CLLocation *currentLocation = (notification.userInfo)[@"currentLocation"];
        NSLog(@"currentLocation %@", currentLocation);
        
        STMCoreLocation *location = [STMLocationController locationObjectFromCLLocation:currentLocation];
        
        [self setLocationForWaitingLocationPhotos:location];
        
    }
    
}

- (void)setLocationForWaitingLocationPhotos:(STMCoreLocation *)location {
    
    self.isPhotoLocationProcessing = YES;
    NSArray *photos = self.waitingLocationPhotos.copy;
    
    for (STMCorePhoto *photo in photos) {
        
        photo.location = location;
        
        [self.waitingLocationPhotos removeObject:photo];
        
    }
    
    if (self.waitingLocationPhotos.count > 0) {
        [self setLocationForWaitingLocationPhotos:location];
    } else {
        self.isPhotoLocationProcessing = NO;
    }
    
}


#pragma mark - class methods

+ (NSDictionary *)newPhotoObjectEntityName:(NSString *)entityName photoData:(NSData *)photoData {
	
    if (!photoData.length) {
        NSLog(@"photoData is empty", entityName);
        return nil;
    }
    
    NSMutableDictionary *picture = [STMCorePicturesController.sharedController setImagesFromData:photoData
                                                              forPicture:@{@"id": [STMFunctions uuidString]}
                                                          withEntityName:entityName].mutableCopy;
    
    NSString *xid = picture[STMPersistingKeyPrimary];
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    [STMCorePicturesController.sharedController saveImageFile:fileName forPicture:picture fromImageData:photoData withEntityName:entityName];
    
    return picture.copy;
    
}

+ (void)uploadPhotoEntityName:(NSString *)entityName antributes:(NSDictionary *)atributes photoData:(NSData *)photoData {
    
    
    [STMCorePicturesController.sharedController uploadImageEntityName:entityName attributes:atributes data:photoData];
    
}



@end
