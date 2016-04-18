//
//  STMPicturesController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMPicturesController.h"
#import "STMFunctions.h"
#import "STMConstants.h"
#import "STMSessionManager.h"
#import "STMCoreObjectsController.h"

#import <objc/runtime.h>


@interface STMPicturesController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSOperationQueue *uploadQueue;
@property (nonatomic, strong) NSMutableDictionary *hrefDictionary;
@property (nonatomic) BOOL waitingForDownloadPicture;

@property (nonatomic, strong) STMSession *session;
@property (nonatomic, strong) NSMutableDictionary *settings;

@property (nonatomic, strong) NSFetchedResultsController *nonloadedPicturesResultsController;


@end

@implementation STMPicturesController


+ (STMPicturesController *)sharedController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedController = nil;
    
    dispatch_once(&pred, ^{
        
        //        NSLog(@"STMObjectsController init");
        _sharedController = [[self alloc] init];
        
    });
    
    return _sharedController;
    
}


#pragma mark - instance properties

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        [self addObservers];
//        [self performFetch];
        
    }
    return self;
    
}

- (void)addObservers {
 
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(authStateChanged)
               name:@"authControllerStateChanged"
             object:[STMAuthController authController]];

}

- (void)authStateChanged {
    
    if ([STMAuthController authController].controllerState != STMAuthSuccess) {
        
        self.downloadingPictures = NO;
        
        self.uploadQueue.suspended = YES;
        [self.uploadQueue cancelAllOperations];
        self.uploadQueue = nil;
        
        self.hrefDictionary = nil;
        self.session = nil;
        self.settings = nil;
        self.nonloadedPicturesResultsController = nil;
        
    }
    
}

- (STMSession *)session {
    
    return [STMSessionManager sharedManager].currentSession;
    
}

- (void)setDownloadingPictures:(BOOL)downloadingPictures {
    
    if (_downloadingPictures != downloadingPictures) {
        
        _downloadingPictures = downloadingPictures;

        (_downloadingPictures) ? [self startDownloadingPictures] : [self stopDownloadingPictures];
        
    }
    
}

- (NSMutableDictionary *)hrefDictionary {
    
    if (!_hrefDictionary) {
        _hrefDictionary = [NSMutableDictionary dictionary];
    }
    return _hrefDictionary;
    
}

- (NSOperationQueue *)uploadQueue {
    
    if (!_uploadQueue) {
        
        _uploadQueue = [[NSOperationQueue alloc] init];
        
    }
    
    return _uploadQueue;
    
}

- (NSFetchedResultsController *)nonloadedPicturesResultsController {
    
    if (!_nonloadedPicturesResultsController) {
        
        NSManagedObjectContext *context = self.session.document.managedObjectContext;
        
        if (context && [self.session.status isEqualToString:@"running"]) {
            
            STMFetchRequest *request = [[STMFetchRequest alloc] initWithEntityName:NSStringFromClass([STMPicture class])];
            
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(href != %@) AND (imageThumbnail == %@)", nil, nil];
            
            request.sortDescriptors = @[sortDescriptor];
            request.predicate = [STMPredicate predicateWithNoFantomsFromPredicate:predicate];
            
            _nonloadedPicturesResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                     managedObjectContext:context
                                                                                       sectionNameKeyPath:nil
                                                                                                cacheName:nil];
            _nonloadedPicturesResultsController.delegate = self;
            
            [_nonloadedPicturesResultsController performFetch:nil];

        } else {
            
            _nonloadedPicturesResultsController = nil;
            
        }
        
    }
    return _nonloadedPicturesResultsController;
    
}

- (NSArray *)photoEntitiesNames {
    return @[];
}

- (NSArray *)instantLoadPicturesEntityNames {
    return @[];
}

- (NSArray *)nonloadedPictures {
    
    NSArray *predicateArray = [[self photoEntitiesNames] arrayByAddingObjectsFromArray:[self instantLoadPicturesEntityNames]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (entity.name IN %@)", predicateArray];
    return [self.nonloadedPicturesResultsController.fetchedObjects filteredArrayUsingPredicate:predicate];
    
}

- (NSUInteger)nonloadedPicturesCount {
    
    NSUInteger nonloadedPicturesCount = [self nonloadedPictures].count;
    
    if (nonloadedPicturesCount == 0) {

        [self.session.document saveDocument:^(BOOL success) {
            
        }];
        
        self.downloadingPictures = NO;
    
    }
    
    return nonloadedPicturesCount;
    
}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"nonloadedPicturesCountDidChange" object:self];
    
}


#pragma mark - class methods

+ (CGFloat)jpgQuality {
    
    NSDictionary *appSettings = [self.session.settingsController currentSettingsForGroup:@"appSettings"];
    CGFloat jpgQuality = [[appSettings valueForKey:@"jpgQuality"] floatValue];

    return jpgQuality;
    
}

+ (void)checkPhotos {
    
    [self checkPicturesPaths];
    [self checkBrokenPhotos];
    [self checkUploadedPhotos];
    
}


#pragma mark - checkPicturesPaths

+ (void)checkPicturesPaths {
    
    NSString *sessionUID = [STMSessionManager sharedManager].currentSessionUID;
    
    if (sessionUID) {
        
        NSString *keyToCheck = [@"picturePathsDidCheckedAlready_" stringByAppendingString:sessionUID];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL picturePathsDidCheckedAlready = [[defaults objectForKey:keyToCheck] boolValue];
        
        if (!picturePathsDidCheckedAlready) {
            
            [self startCheckingPicturesPaths];
            
            [defaults setObject:@YES forKey:keyToCheck];
            [defaults synchronize];
            
        }

    }
    
}

+ (void)startCheckingPicturesPaths {
    
    NSArray *result = [STMCoreObjectsController objectsForEntityName:NSStringFromClass([STMPicture class])];
    
    if (result.count > 0) {

        NSLogMethodName;

        for (STMPicture *picture in result) {
            
            NSArray *pathComponents = [picture.imagePath pathComponents];
            
            if (pathComponents.count == 0) {
                
                if (picture.href) {
                    [self hrefProcessingForObject:picture];
                } else {
                    NSLog(@"picture %@ has no both imagePath and href, will be deleted", picture.xid);
                    [self deletePicture:picture];
                }
                
            } else {
                
                if (pathComponents.count > 1) {
                    [self imagePathsConvertingFromAbsoluteToRelativeForPicture:picture];
                }
                
            }
            
        }

    }
    
}

+ (void)imagePathsConvertingFromAbsoluteToRelativeForPicture:(STMPicture *)picture {

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *newImagePath = [self convertImagePath:picture.imagePath];
    NSString *newResizedImagePath = [self convertImagePath:picture.resizedImagePath];
    
    if (newImagePath) {

        NSLog(@"set new imagePath for picture %@", picture.xid);
        picture.imagePath = newImagePath;

        if (newResizedImagePath) {
            
            NSLog(@"set new resizedImagePath for picture %@", picture.xid);
            picture.resizedImagePath = newResizedImagePath;
            
        } else {
            
            NSLog(@"! new resizedImagePath for picture %@", picture.xid);

            if ([fileManager fileExistsAtPath:(NSString * _Nonnull)picture.resizedImagePath]) {
                [fileManager removeItemAtPath:(NSString * _Nonnull)picture.resizedImagePath error:nil];
            }

            NSLog(@"save new resizedImage file for picture %@", picture.xid);
            NSData *imageData = [NSData dataWithContentsOfFile:[STMFunctions absolutePathForPath:newImagePath]];
            [self saveResizedImageFile:[@"resized_" stringByAppendingString:newImagePath] forPicture:picture fromImageData:imageData];
            
        }
        
    } else {

        NSLog(@"! new imagePath for picture %@", picture.xid);

        if (picture.href) {
            
            NSLog(@"have href, flush picture and download data again");
            
            [self removeImageFilesForPicture:picture];
            [self hrefProcessingForObject:picture];
            
        } else {

            NSLog(@"no href, delete picture");
            
            [self deletePicture:picture];
            
        }

    }

}

+ (NSString *)convertImagePath:(NSString *)path {
    
    NSString *lastPathComponent = [path lastPathComponent];
    NSString *imagePath = [STMFunctions absolutePathForPath:lastPathComponent];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return lastPathComponent;
    } else {
        return nil;
    }

}


#pragma mark - check Broken & Uploaded Photos

+ (void)checkBrokenPhotos {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMPicture class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"imageThumbnail == %@", nil];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    for (STMPicture *picture in result) {
        
        if (picture.imagePath) {
            
            NSData *photoData = [NSData dataWithContentsOfFile:[STMFunctions absolutePathForPath:picture.imagePath]];
            
            if (photoData && photoData.length > 0) {
                
                [self setImagesFromData:photoData forPicture:picture andUpload:NO];
                
            } else {
                
                if (picture.href) {
                    
                    [self hrefProcessingForObject:picture];
                    
                } else {
                
                    NSString *logMessage = [NSString stringWithFormat:@"attempt to set images for picture %@, photoData %@, length %lu", picture, photoData, (unsigned long)photoData.length];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
                    
                    [self deletePicture:picture];

                }
                
            }
            
        } else {
            
            [self hrefProcessingForObject:picture];
            
        }

    }
    
}

+ (void)checkUploadedPhotos {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMPhoto class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"href == %@", nil];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    for (STMPicture *picture in result) {
        
        if (!picture.hasChanges) {
            
            NSData *photoData = [NSData dataWithContentsOfFile:[STMFunctions absolutePathForPath:picture.imagePath]];
            
            if (photoData && photoData.length > 0) {
                
                [[self sharedController] addUploadOperationForPicture:picture data:photoData];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"attempt to upload picture %@, photoData %@, length %lu — object will be deleted", picture, photoData, (unsigned long)photoData.length];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
                [self deletePicture:picture];
                
            }

        }
        
    }
    
}


#pragma mark - other methods

+ (void)hrefProcessingForObject:(NSManagedObject *)object {
    
    NSString *href = [object valueForKey:@"href"];
    
    if (href) {
        
        if ([object isKindOfClass:[STMPicture class]]) {
            
            STMPicturesController *pc = [self sharedController];
            
            if (![pc.hrefDictionary.allKeys containsObject:href]) {
                
                (pc.hrefDictionary)[href] = object;
                
                if (pc.downloadingPictures) {
                    
                    [pc downloadNextPicture];
                    
                } else {
                    
                    if ([[pc instantLoadPicturesEntityNames] containsObject:NSStringFromClass([object class])]) {
                        [self downloadConnectionForObjectID:object.objectID];
                    }

                }
                
            }
            
        }
        
    }
    
}

+ (void)setImagesFromData:(NSData *)data forPicture:(STMPicture *)picture andUpload:(BOOL)shouldUpload {
    
    NSData *weakData = data;
    STMPicture *weakPicture = picture;
    
    NSString *xid = (picture.xid) ? [STMFunctions UUIDStringFromUUIDData:(NSData *)picture.xid] : nil;
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    if ([picture isKindOfClass:[STMPhoto class]]) {
        
        if (shouldUpload) {
            [[self sharedController] addUploadOperationForPicture:picture data:weakData];
        }

    } else if ([picture isKindOfClass:[STMPicture class]]) {
        
    }
    
    if (fileName) {
        
        [self saveImageFile:fileName forPicture:weakPicture fromImageData:weakData];
        [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:weakPicture fromImageData:weakData];
        [self setThumbnailForPicture:weakPicture fromImageData:weakData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadPicture" object:weakPicture];
            //        NSLog(@"images set for %@", weakPicture.href);
            
        });

    } else {
        
        CLS_LOG(@"nil filename for picture %@", picture);
        
    }
    
}

+ (void)saveImageFile:(NSString *)fileName forPicture:(STMPicture *)picture fromImageData:(NSData *)data {
    
    UIImage *image = [UIImage imageWithData:data];
    CGFloat maxDimension = MAX(image.size.height, image.size.width);
    
    if (maxDimension > MAX_PICTURE_SIZE) {
        
        image = [STMFunctions resizeImage:image toSize:CGSizeMake(MAX_PICTURE_SIZE, MAX_PICTURE_SIZE) allowRetina:NO];
        data = UIImageJPEGRepresentation(image, [self jpgQuality]);

    }
    
    NSString *imagePath = [STMFunctions absolutePathForPath:fileName];
    [data writeToFile:imagePath atomically:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        picture.imagePath = fileName;
    });

}

+ (void)saveResizedImageFile:(NSString *)resizedFileName forPicture:(STMPicture *)picture fromImageData:(NSData *)data {

    NSString *resizedImagePath = [STMFunctions absolutePathForPath:resizedFileName];
    
    UIImage *resizedImage = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(1024, 1024) allowRetina:NO];
    NSData *resizedImageData = nil;
    resizedImageData = UIImageJPEGRepresentation(resizedImage, [self jpgQuality]);
    [resizedImageData writeToFile:resizedImagePath atomically:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        picture.resizedImagePath = resizedFileName;
    });

}

+ (void)setThumbnailForPicture:(STMPicture *)picture fromImageData:(NSData *)data {
    
    UIImage *imageThumbnail = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(150, 150)];
    NSData *thumbnail = UIImageJPEGRepresentation(imageThumbnail, [self jpgQuality]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        picture.imageThumbnail = thumbnail;
    });
    
}


#pragma mark - queues

- (void)startDownloadingPictures {
    [self downloadNextPicture];
}

- (void)downloadNextPicture {
    
    if (self.downloadingPictures && !self.waitingForDownloadPicture) {
        
        NSManagedObject *object = self.hrefDictionary.allValues.firstObject;
        
        if (object) {
            
            [self downloadConnectionForObjectID:object.objectID];
            
        } else {
            
            self.downloadingPictures = NO;
            [STMPicturesController checkBrokenPhotos];
            self.downloadingPictures = (self.hrefDictionary.allValues.count > 0);
            
        }
        
    } else {

    }
    
}

- (void)stopDownloadingPictures {

}

+ (void)downloadConnectionForObjectID:(NSManagedObjectID *)objectID {
    [[self sharedController] downloadConnectionForObjectID:objectID];
}

- (void)downloadConnectionForObjectID:(NSManagedObjectID *)objectID {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSError *error;
        
        NSManagedObject *object = [[STMPicturesController document].managedObjectContext existingObjectWithID:objectID error:&error];
        
        if (!error && object) {
            
            [self downloadConnectionForObject:object];
            
        } else {
            NSLog(@"existingObjectWithID %@ error: %@", objectID, error.localizedDescription);
        }
        
    });

}

+ (void)downloadConnectionForObject:(NSManagedObject *)object {
    [[self sharedController] downloadConnectionForObject:object];
}

- (void)downloadConnectionForObject:(NSManagedObject *)object {
    
    __block NSString *href = nil;
    
    href = [object valueForKey:@"href"];
    
    if (href) {
        
        if ([object valueForKey:@"imageThumbnail"]) {

            [self didProcessHref:href];
            
        } else {
        
            self.waitingForDownloadPicture = YES;
            
            NSURL *url = [NSURL URLWithString:href];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            
            //        NSLog(@"start loading %@", url.lastPathComponent);
            
            [NSURLConnection sendAsynchronousRequest:request
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {

                self.waitingForDownloadPicture = NO;
                                       
                if (connectionError) {
                   
                    NSLog(@"error %@ in %@", connectionError.description, [object valueForKey:@"name"]);
                    [self didProcessHref:href];

                } else {
                   
                   //                NSLog(@"%@ load successefully", href);
                   
                    [self didProcessHref:href];

                    if ([object isKindOfClass:[STMPicture class]]) {
                       [[self class] setImagesFromData:data forPicture:(STMPicture *)object andUpload:NO];
                    }
                   
                }

            }];
            
        }
        
    }
    
}

- (void)didProcessHref:(NSString *)href {

    [self.hrefDictionary removeObjectForKey:href];
    [self downloadNextPicture];

}

- (void)repeatUploadOperationForObject:(NSManagedObject *)object {
    
    if ([object isKindOfClass:[STMPicture class]]) {
        
        STMPicture *picture = (STMPicture *)object;
        
        NSData *data = [NSData dataWithContentsOfFile:[STMFunctions absolutePathForPath:picture.imagePath]];

        [self addUploadOperationForPicture:picture data:data];
        
    }
    
}

- (void)addUploadOperationForPicture:(STMPicture *)picture data:(NSData *)data {

    NSString *url = @"https://api.sistemium.com/ims/dr50?folder=";
    NSString *entityName = picture.entity.name;
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy";
    NSString *year = [dateFormatter stringFromDate:currentDate];
    dateFormatter.dateFormat = @"MM";
    NSString *month = [dateFormatter stringFromDate:currentDate];
    dateFormatter.dateFormat = @"dd";
    NSString *day = [dateFormatter stringFromDate:currentDate];
    NSURL *imsURL = [NSURL URLWithString:[url stringByAppendingString:[NSString stringWithFormat:@"%@/%@/%@/%@", entityName, year, month, day]]];
    NSMutableURLRequest *request = [[[STMAuthController authController] authenticateRequest:[NSURLRequest requestWithURL:imsURL]] mutableCopy];
    [request setHTTPMethod:@"POST"];
    [request setValue: @"image/jpeg" forHTTPHeaderField:@"content-type"];
    [request setHTTPBody:data];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

        if (!error) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode == 200){
                NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                NSData *picturesJson = [NSJSONSerialization dataWithJSONObject: (NSDictionary * _Nonnull) dictionary[@"pictures"] options:0 error: &error];
                if (!error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (NSDictionary* dict in dictionary[@"pictures"]){
                            if ([dict[@"name"]  isEqual: @"original"]){
                                picture.href = dict[@"src"];
                            }
                        }
                        NSString *info = [[NSString alloc] initWithData:picturesJson encoding:NSUTF8StringEncoding];
                        picture.picturesInfo = [info stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
                        NSLog(@"%@", picture.picturesInfo);
                        __block STMSession *session = [STMSessionManager sharedManager].currentSession;
                        [session.document saveDocument:^(BOOL success) {
                        }];
                        
                    });
                }
            } else {
                NSLog(@"Request error, statusCode: %d", statusCode);
            }
        } else {
            
            NSLog(@"connectionError %@", error.localizedDescription);
        }

    }];

}


#pragma mark

+ (void)deletePicture:(STMPicture *)picture {

//    NSLog(@"delete picture %@", picture);
    
    [self removeImageFilesForPicture:picture];
    
    [STMCoreObjectsController removeObject:picture];

    [[self document] saveDocument:^(BOOL success) {
        
    }];
    
}

+ (void)removeImageFilesForPicture:(STMPicture *)picture {
    
    if (picture.imagePath) [self removeImageFile:picture.imagePath];
    if (picture.resizedImagePath) [self removeImageFile:picture.resizedImagePath];
    
}

+ (void)removeImageFile:(NSString *)filePath {
    
    NSString *imagePath = [STMFunctions absolutePathForPath:filePath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:imagePath isDirectory:nil]) {

        NSError *error;
        BOOL success = [fileManager removeItemAtPath:imagePath error:&error];
        
        if (success) {
            
            NSLog(@"file %@ was successefully removed", [filePath lastPathComponent]);
            
        } else {
            
            NSLog(@"removeItemAtPath error: %@ ",[error localizedDescription]);
            
        }

    }
    
}


@end
