//
//  STMPicturesController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCorePicturesController.h"
#import "STMFunctions.h"
#import "STMConstants.h"
#import "STMCoreSessionManager.h"
#import "STMCoreObjectsController.h"

#import <objc/runtime.h>


@interface STMCorePicturesController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSOperationQueue *uploadQueue;
@property (nonatomic, strong) NSMutableDictionary *hrefDictionary;
@property (nonatomic) BOOL waitingForDownloadPicture;

@property (nonatomic, strong) STMCoreSession *session;
@property (nonatomic, strong) NSMutableDictionary *settings;

@property (nonatomic, strong) NSFetchedResultsController *nonloadedPicturesResultsController;

@property (nonatomic, strong) NSString *imagesCachePath;


@end


@implementation STMCorePicturesController


+ (STMCorePicturesController *)sharedController {
    
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
             object:[STMCoreAuthController authController]];

}

- (void)authStateChanged {
    
    if ([STMCoreAuthController authController].controllerState != STMAuthSuccess) {
        
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

- (STMCoreSession *)session {
    
    return [STMCoreSessionManager sharedManager].currentSession;
    
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
        
        if (context && self.session.status == STMSessionRunning) {
            
            STMFetchRequest *request = [[STMFetchRequest alloc] initWithEntityName:NSStringFromClass([STMCorePicture class])];
            
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
    return @[NSStringFromClass([STMMessagePicture class])];
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

- (NSString *)imagesCachePath {
    
    if (!_imagesCachePath) {
        
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSString *imagesCachePath = [STMFunctions absoluteDataCachePathForPath:IMAGES_CACHE_PATH];
        
        if ([fm fileExistsAtPath:imagesCachePath]) {
            
            _imagesCachePath = imagesCachePath;
            
        } else {
            
            NSError *error = nil;
            BOOL result = [fm createDirectoryAtPath:imagesCachePath
                        withIntermediateDirectories:YES
                                         attributes:nil
                                              error:&error];
            
            if (result) {
                
                _imagesCachePath = imagesCachePath;
                
            } else {
                
                NSLog(@"can not create imagesCachePath: %@", error.localizedDescription);
                
            }
            
        }
        
    }
    
    return _imagesCachePath;

}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"nonloadedPicturesCountDidChange" object:self];
    
}


#pragma mark - class methods

+ (CGFloat)jpgQuality {
    
    NSDictionary *appSettings = [[self session].settingsController currentSettingsForGroup:@"appSettings"];
    CGFloat jpgQuality = [appSettings[@"jpgQuality"] floatValue];

    return jpgQuality;
    
}

+ (void)checkPhotos {
    
    [self checkPicturesPaths];
    [self checkBrokenPhotos];
    [self checkUploadedPhotos];
    
}

+ (NSString *)imagesCachePath {
    return [self sharedController].imagesCachePath;
}

#pragma mark - checkPicturesPaths

+ (void)checkPicturesPaths {
    
    NSString *sessionUID = [STMCoreSessionManager sharedManager].currentSessionUID;
    
    if (sessionUID) {
        
        NSString *keyToCheck = [@"picturePathsDidCheckedAlready_" stringByAppendingString:sessionUID];
        
        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        BOOL picturePathsDidCheckedAlready = [[defaults objectForKey:keyToCheck] boolValue];
        
        if (!picturePathsDidCheckedAlready) {
            
            [self startCheckingPicturesPaths];
            
            [defaults setObject:@YES forKey:keyToCheck];
            [defaults synchronize];
            
        }

    }
    
}

+ (void)startCheckingPicturesPaths {
    
    NSMutableArray *result = @[].mutableCopy;
    
    NSArray *objects = [self.persistenceDelegate findAllSync:@"STMArticlePicture" predicate:nil options:nil error:nil];
    
    for (NSDictionary *object in objects){
        STMDatum *managedObject = (STMDatum *)[self.persistenceDelegate newObjectForEntityName:@"STMArticlePicture"];
        [self.persistenceDelegate setObjectData:object toObject:managedObject withRelations:true];
        [result addObject:managedObject];
    }
    
    objects = [objects arrayByAddingObjectsFromArray:[self.persistenceDelegate findAllSync:@"STMOutletPhoto" predicate:nil options:nil error:nil]];
    
    for (NSDictionary *object in objects){
        STMDatum *managedObject = (STMDatum *)[self.persistenceDelegate newObjectForEntityName:@"STMOutletPhoto"];
        [self.persistenceDelegate setObjectData:object toObject:managedObject withRelations:true];
        [result addObject:managedObject];
    }
    
    objects = [objects arrayByAddingObjectsFromArray:[self.persistenceDelegate findAllSync:@"STMVisitPhoto" predicate:nil options:nil error:nil]];
    
    for (NSDictionary *object in objects){
        STMDatum *managedObject = (STMDatum *)[self.persistenceDelegate newObjectForEntityName:@"STMVisitPhoto"];
        [self.persistenceDelegate setObjectData:object toObject:managedObject withRelations:true];
        [result addObject:managedObject];
    }
    
    objects = [objects arrayByAddingObjectsFromArray:[self.persistenceDelegate findAllSync:@"STMMessagePicture" predicate:nil options:nil error:nil]]
    ;
    
    for (NSDictionary *object in objects){
        STMDatum *managedObject = (STMDatum *)[self.persistenceDelegate newObjectForEntityName:@"STMMessagePicture"];
        [self.persistenceDelegate setObjectData:object toObject:managedObject withRelations:true];
        [result addObject:managedObject];
    }
    
    NSMutableDictionary <NSString*,NSMutableArray*> *picturesWithThumbnails = @{}.mutableCopy;
    
    if (result.count > 0) {

        NSLogMethodName;

        for (STMCorePicture *picture in result) {
            
            if (picture.imageThumbnail == nil && picture.thumbnailHref != nil){
                
                NSString* thumbnailHref = picture.thumbnailHref;
                NSURL *thumbnailUrl = [NSURL URLWithString: thumbnailHref];
                NSData *thumbnailData = [[NSData alloc] initWithContentsOfURL: thumbnailUrl];
                
                if (thumbnailData) [STMCorePicturesController setThumbnailForPicture:picture fromImageData:thumbnailData];
                
                NSDictionary *picDict = [STMCoreObjectsController dictionaryForJSWithObject:picture];
                
                if (!picturesWithThumbnails[picture.entity.name]){
                    picturesWithThumbnails[picture.entity.name] = @[].mutableCopy;
                }
                
                [picturesWithThumbnails[picture.entity.name] addObject:picDict];
                
                continue;
            }
            
            NSArray *pathComponents = [picture.imagePath pathComponents];
            
            if (pathComponents.count == 0) {
                
                if (picture.href) {
                    
                    [self hrefProcessingForObject:picture];
                    
                } else {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"checkingPicturesPaths picture %@ has no both imagePath and href, will be deleted", picture.xid];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
                    [self deletePicture:picture];
                    
                }
                
            } else {
                
                if (pathComponents.count > 1) {
                    [self imagePathsConvertingFromAbsoluteToRelativeForPicture:picture];
                }
                
            }
            
        }

    }
    
    for (NSString* entityName in picturesWithThumbnails.allKeys){
    
        if (picturesWithThumbnails[entityName].count > 0){
            [STMCoreController.persistenceDelegate mergeMany:entityName attributeArray:picturesWithThumbnails[entityName] options:nil].then(^(NSArray *result){
                NSLog(@"Thumbnail set for %i %@ pictures",result.count,entityName);
            }).catch(^(NSError *error){
                NSLog(@"Error setting thumbnail%@ for %@ pictures",error, entityName);
            });
        }
        
    }
    
}

+ (void)imagePathsConvertingFromAbsoluteToRelativeForPicture:(STMCorePicture *)picture {

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
            NSData *imageData = [NSData dataWithContentsOfFile:[[self imagesCachePath] stringByAppendingPathComponent:newImagePath]];
            
            [self saveResizedImageFile:[@"resized_" stringByAppendingString:newImagePath]
                            forPicture:picture
                         fromImageData:imageData];
            
        }
        
    } else {

        NSLog(@"! new imagePath for picture %@", picture.xid);

        if (picture.href) {
            
            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no newImagePath and have href for picture %@, flush picture and download data again", picture.xid];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self removeImageFilesForPicture:picture];
            [self hrefProcessingForObject:picture];
            
        } else {

            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no newImagePath and no href for picture %@, will be deleted", picture.xid];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self deletePicture:picture];
            
        }

    }

}

+ (NSString *)convertImagePath:(NSString *)path {
    
    NSString *lastPathComponent = [path lastPathComponent];
    NSString *imagePath = [[self imagesCachePath] stringByAppendingPathComponent:lastPathComponent];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return lastPathComponent;
    } else {
        return nil;
    }

}


#pragma mark - check Broken & Uploaded Photos

+ (void)checkBrokenPhotos {
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMCorePicture class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"imageThumbnail == %@ OR imagePath == %@", nil, nil];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    for (STMCorePicture *picture in result) {
        
        if (picture.imagePath) {
            
            NSError *error = nil;
            NSData *photoData = [NSData dataWithContentsOfFile:[[self imagesCachePath] stringByAppendingPathComponent:picture.imagePath]
                                                       options:0
                                                         error:&error];
            
            if (photoData && photoData.length > 0) {
                
                [self setImagesFromData:photoData
                             forPicture:picture
                              andUpload:NO];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PICTURE_WAS_DOWNLOADED object:picture];
                    
                });
                
            } else {
                
                if (!error) {
                    
                    if (picture.href) {
                        
                        [self hrefProcessingForObject:picture];
                        
                    } else {
                        
                        NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos attempt to set images for picture %@, photoData %@, length %lu, have no photoData and have no href, will be deleted", picture, photoData, (unsigned long)photoData.length];
                        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                                 numType:STMLogMessageTypeError];
                        [self deletePicture:picture];
                        
                    }
                    
                } else {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos dataWithContentsOfFile %@ error: %@", picture.imagePath, error.localizedDescription];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                             numType:STMLogMessageTypeError];
                    
                }
                
            }
            
        } else {
            
            if (picture.href) {
                
                [self hrefProcessingForObject:picture];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"picture %@ have no both imagePath and href", picture];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                         numType:STMLogMessageTypeError];
                [self deletePicture:picture];
                
            }
            
        }

    }
    
}

+ (void)checkUploadedPhotos {

    int counter = 0;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMCorePhoto class])];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
    request.predicate = [NSPredicate predicateWithFormat:@"href == %@", nil];
    
    NSError *error;
    NSArray *result = [[self document].managedObjectContext executeFetchRequest:request error:&error];
    
    for (STMCorePicture *picture in result) {
        
        if (!picture.hasChanges && picture.imagePath) {
            
            NSError *error = nil;
            NSData *photoData = [NSData dataWithContentsOfFile:[[self imagesCachePath] stringByAppendingPathComponent:picture.imagePath]
                                                       options:0
                                                         error:&error];
            
            if (photoData && photoData.length > 0) {
                
                [[self sharedController] addUploadOperationForPicture:picture
                                                                 data:photoData];
                counter++;
                
            } else {
                
                if (!error) {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"attempt to upload picture %@, photoData %@, length %lu — object will be deleted", picture, photoData, (unsigned long)photoData.length];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                             numType:STMLogMessageTypeError];
                    [self deletePicture:picture];
                    
                } else {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"checkUploadedPhotos dataWithContentsOfFile error: %@", error.localizedDescription];
                    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                             numType:STMLogMessageTypeError];
                    
                }
                
            }
            
        }
        
    }
    
    if (counter > 0) {
		NSString *logMessage = [NSString stringWithFormat:@"Sending %i photos",counter];
		[[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"important"];
    }
    
}


#pragma mark - other methods

+ (void)hrefProcessingForObject:(NSManagedObject *)object {
    
    NSString *href = [object valueForKey:@"href"];
    
    if (href) {
        
        if ([object isKindOfClass:[STMCorePicture class]]) {
            
            STMCorePicturesController *pc = [self sharedController];
            
            if (![pc.hrefDictionary objectForKey:href]) {
                
                (pc.hrefDictionary)[href] = object;
                
                if (pc.downloadingPictures) {
                    
                    [pc downloadNextPicture];
                    
                } else {
                    
                    if ([[pc instantLoadPicturesEntityNames] containsObject:NSStringFromClass([object class])]) {
                        [self downloadConnectionForObject:object];
                    }

                }
                
            }
            
        }
        
    }
    
}

+ (void)setImagesFromData:(NSData *)data forPicture:(STMCorePicture *)picture andUpload:(BOOL)shouldUpload {
    
    NSData *weakData = data;
    STMCorePicture *weakPicture = picture;
    
    NSString *xid = (picture.xid) ? [STMFunctions UUIDStringFromUUIDData:(NSData *)picture.xid] : nil;
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    if ([picture isKindOfClass:[STMCorePhoto class]]) {
        
        if (shouldUpload) {
            [[self sharedController] addUploadOperationForPicture:picture data:weakData];
        }

    } else if ([picture isKindOfClass:[STMCorePicture class]]) {
        
    }
    
    if (fileName) {
        
        BOOL result = YES;
        
        result = (result && [self saveImageFile:fileName forPicture:weakPicture fromImageData:weakData]);
        result = (result && [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:weakPicture fromImageData:weakData]);
        [self setThumbnailForPicture:weakPicture fromImageData:weakData];
        
        if (!result) {
            
            NSString *logMessage = [NSString stringWithFormat:@"have problem while save image files %@", fileName];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];

        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PICTURE_WAS_DOWNLOADED
                                                                object:weakPicture];
            
        });

    } else {
        
//        CLS_LOG(@"nil filename for picture %@", picture);
        
    }
    
}

+ (BOOL)saveImageFile:(NSString *)fileName forPicture:(STMCorePicture *)picture fromImageData:(NSData *)data {
    
    UIImage *image = [UIImage imageWithData:data];
    CGFloat maxDimension = MAX(image.size.height, image.size.width);
    
    if (maxDimension > MAX_PICTURE_SIZE) {
        
        image = [STMFunctions resizeImage:image toSize:CGSizeMake(MAX_PICTURE_SIZE, MAX_PICTURE_SIZE) allowRetina:NO];
        data = UIImageJPEGRepresentation(image, [self jpgQuality]);

    }
    
    NSString *imagePath = [[self imagesCachePath] stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL result = [data writeToFile:imagePath
                            options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                              error:&error];
    
    if (result) {
    
        if ([NSThread isMainThread]) {
            
            picture.imagePath = fileName;
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                picture.imagePath = fileName;
            });
            
        }

    } else {

        NSString *logMessage = [NSString stringWithFormat:@"saveImageFile %@ writeToFile %@ error: %@", fileName, imagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];

	}

    return result;
    
}

+ (BOOL)saveResizedImageFile:(NSString *)resizedFileName forPicture:(STMCorePicture *)picture fromImageData:(NSData *)data {

    NSString *resizedImagePath = [[self imagesCachePath] stringByAppendingPathComponent:resizedFileName];
    
    UIImage *resizedImage = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(1024, 1024) allowRetina:NO];
    NSData *resizedImageData = nil;
    resizedImageData = UIImageJPEGRepresentation(resizedImage, [self jpgQuality]);

    NSError *error = nil;
    BOOL result = [resizedImageData writeToFile:resizedImagePath
                                        options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                          error:&error];
    
    if (result) {
        
        if ([NSThread isMainThread]) {
            
            picture.resizedImagePath = resizedFileName;
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                picture.resizedImagePath = resizedFileName;
            });
            
        }
        
    } else {

        NSString *logMessage = [NSString stringWithFormat:@"saveResizedImageFile %@ writeToFile %@ error: %@", resizedFileName, resizedImagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];

	}

    return result;

}

+ (void)setThumbnailForPicture:(STMCorePicture *)picture fromImageData:(NSData *)data {
    
    NSString *xid = (picture.xid) ? [STMFunctions UUIDStringFromUUIDData:(NSData *)picture.xid] : nil;
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    UIImage *imageThumbnail = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(150, 150)];
    NSData *thumbnail = UIImageJPEGRepresentation(imageThumbnail, [self jpgQuality]);
    
    NSString *imagePath = [[self imagesCachePath] stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL result = [thumbnail writeToFile:imagePath
                            options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                              error:&error];
    
    if (result) {
        
        if ([NSThread isMainThread]) {
            
            picture.imageThumbnail = fileName;
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                picture.imageThumbnail = fileName;
            });
            
        }
        
    } else {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            picture.imageThumbnail = thumbnail;
        });
        
    }
    
}


#pragma mark - queues

- (void)startDownloadingPictures {
    [self downloadNextPicture];
}

- (void)downloadNextPicture {
    
    if (self.downloadingPictures && !self.waitingForDownloadPicture) {
        
        NSManagedObject *object = self.hrefDictionary.allValues.firstObject;
        
        if (object) {
            
            [self downloadConnectionForObject:object];
            
        } else {
            
            self.downloadingPictures = NO;
            [STMCorePicturesController checkBrokenPhotos];
            self.downloadingPictures = (self.hrefDictionary.allValues.count > 0);
            
        }
        
    } else {

    }
    
}

- (void)stopDownloadingPictures {

}

+ (void)downloadConnectionForObject:(NSManagedObject *)object {
    [[self sharedController] downloadConnectionForObject:object];
}

- (void)downloadConnectionForObject:(NSManagedObject *)object {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSError *error = nil;
        
        if (object) {
            
            __block NSString *href = nil;
            
            href = [object valueForKey:@"href"];
            
            if (href) {
                
                if ([object valueForKey:@"imagePath"]) {
                    
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
                                                   
                                                   [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PICTURE_DOWNLOAD_ERROR
                                                                                                       object:object
                                                                                                     userInfo:@{@"error" : connectionError.description}];
                                                   
                                                   [self didProcessHref:href];
                                                   
                                               } else {
                                                   
                                                   //                NSLog(@"%@ load successefully", href);
                                                   
                                                   [self didProcessHref:href];
                                                   
                                                   if ([object isKindOfClass:[STMCorePicture class]]) {
                                                       [[self class] setImagesFromData:data forPicture:(STMCorePicture *)object andUpload:NO];
                                                       
                                                       NSDictionary* dictObject = [STMCoreObjectsController dictionaryForJSWithObject:(STMDatum*)object];
                                                       
                                                       [STMCoreController.persistenceDelegate merge:object.entity.name attributes:dictObject options:nil].then(^(NSArray *result){
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               
                                                               [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PICTURE_WAS_DOWNLOADED object:object];
                                                               
                                                           });
                                                       }).catch(^(NSError *error){
                                                           NSLog(@"Error:%@",error);
                                                       });
                                                       
                                                   }
                                                   
                                               }
                                               
                                           }];
                    
                }
                
            }
            
        } else {
            NSLog(@"existingObjectWithID %@ error: %@", object, error.localizedDescription);
        }
        
    });
    
}

- (void)didProcessHref:(NSString *)href {

    [self.hrefDictionary removeObjectForKey:href];
    [self downloadNextPicture];

}

- (void)addUploadOperationForPicture:(STMCorePicture *)picture data:(NSData *)data {

    NSDictionary *appSettings = [self.session.settingsController currentSettingsForGroup:@"appSettings"];
    NSString *url = [[appSettings valueForKey:@"IMS.url"] stringByAppendingString:@"?folder="];
    
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
    
    NSMutableURLRequest *request = [[[STMCoreAuthController authController] authenticateRequest:[NSURLRequest requestWithURL:imsURL]] mutableCopy];
    [request setHTTPMethod:@"POST"];
    [request setValue: @"image/jpeg" forHTTPHeaderField:@"content-type"];
    [request setHTTPBody:data];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

        if (!error) {
            
            if (picture.managedObjectContext) {
                
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                
                if (statusCode == 200) {
                    
                    NSError *localError = nil;
                    
                    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                               options:0
                                                                                 error:&localError];
                    
                    if (dictionary) {

                        NSArray *picturesDicts = dictionary[@"pictures"];

                        NSData *picturesJson = [NSJSONSerialization dataWithJSONObject:picturesDicts
                                                                               options:0
                                                                                 error:&localError];
                        
                        if (picturesJson) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                
                                for (NSDictionary *dict in picturesDicts){
                                    if ([dict[@"name"] isEqual:@"original"]){
                                        picture.href = dict[@"src"];
                                    }
                                }
                                
                                NSString *info = [[NSString alloc] initWithData:picturesJson
                                                                       encoding:NSUTF8StringEncoding];
                                
                                picture.picturesInfo = [info stringByReplacingOccurrencesOfString:@"\\/"
                                                                                       withString:@"/"];
                                
                                NSLog(@"%@", picture.picturesInfo);
                                
                                __block STMCoreSession *session = [STMCoreSessionManager sharedManager].currentSession;
                                
                                [session.document saveDocument:^(BOOL success) {
                                }];
                                
                            });

                        } else {
                            NSLog(@"error in json serialization: %@", localError.localizedDescription);
                        }
                        
                    } else {
                        NSLog(@"error in json serialization: %@", localError.localizedDescription);
                    }
                    
                } else {
                    NSLog(@"Request error, statusCode: %ld", (long)statusCode);
                }

            } else {
                NSLog(@"picture have no managedObjectContext, probably it was deleted");
            }
            
        } else {
            NSLog(@"connectionError %@", error.localizedDescription);
        }

    }];

}


#pragma mark

+ (void)deletePicture:(STMCorePicture *)picture {

//    NSLog(@"delete picture %@", picture);
    
    [self removeImageFilesForPicture:picture];
    
    NSError *error;
    
    [self.persistenceDelegate destroySync:@"STMEntity" identifier:[STMFunctions hexStringFromData:picture.xid] options:nil error:&error];
    
}

+ (void)removeImageFilesForPicture:(STMCorePicture *)picture {
    
    if (picture.imagePath) [self removeImageFile:picture.imagePath];
    if (picture.resizedImagePath) [self removeImageFile:picture.resizedImagePath];
    
}

+ (void)removeImageFile:(NSString *)filePath {
    
    NSString *imagePath = [[self imagesCachePath] stringByAppendingPathComponent:filePath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:imagePath isDirectory:nil]) {

        NSError *error;
        BOOL success = [fileManager removeItemAtPath:imagePath error:&error];
        
        if (success) {
            
            NSString *logMessage = [NSString stringWithFormat:@"file %@ was successefully removed", [filePath lastPathComponent]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeInfo];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"removeItemAtPath error: %@ ",[error localizedDescription]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
        }

    }
    
}


@end
