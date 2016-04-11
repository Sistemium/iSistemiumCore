//
//  STMPhotosController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMPhotosController.h"

#import "STMSessionManager.h"
#import "STMLocationController.h"


@interface STMPhotosController()

@property (nonatomic, strong) NSMutableArray *waitingLocationPhotos;
@property (nonatomic) BOOL isPhotoLocationProcessing;


@end


@implementation STMPhotosController

+ (STMPhotosController *)sharedController {
    
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

- (STMLocationTracker *)locationTracker {
    return [(STMSession *)[STMSessionManager sharedManager].currentSession locationTracker];
}

- (NSMutableArray *)waitingLocationPhotos {
    
    if (!_waitingLocationPhotos) {
        _waitingLocationPhotos = [NSMutableArray array];
    }
    
    return _waitingLocationPhotos;
    
}

#warning should override
//- (void)addPhotoReportToWaitingLocation:(STMPhotoReport *)photoReport {
//    
//    [self.waitingLocationPhotos addObject:photoReport];
//    [[self locationTracker] getLocation];
//
//}


#pragma mark - update locations

- (void)currentLocationWasUpdated:(NSNotification *)notification {
    
    if (self.waitingLocationPhotos.count > 0 && !self.isPhotoLocationProcessing) {
        
        CLLocation *currentLocation = (notification.userInfo)[@"currentLocation"];
        NSLog(@"currentLocation %@", currentLocation);
        
        STMLocation *location = [STMLocationController locationObjectFromCLLocation:currentLocation];
        
        [self setLocationForWaitingLocationPhotos:location];
        
    }
    
}

- (void)setLocationForWaitingLocationPhotos:(STMLocation *)location {
    
    self.isPhotoLocationProcessing = YES;
    NSArray *photos = self.waitingLocationPhotos.copy;
    
    for (STMPhoto *photo in photos) {
        
        photo.location = location;
        
        [self.waitingLocationPhotos removeObject:photo];
        
    }
    
    if (self.waitingLocationPhotos.count > 0) {
        [self setLocationForWaitingLocationPhotos:location];
    } else {
        self.isPhotoLocationProcessing = NO;
    }
    
}

#warning should override
//- (void)photoReportWasDeleted:(STMPhotoReport *)photoReport {
//    [self.waitingLocationPhotos removeObject:photoReport];
//}



@end
