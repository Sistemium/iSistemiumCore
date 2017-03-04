//
//  STMCorePicturesController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCorePicturesController.h"

#import "STMConstants.h"
#import "STMCoreSessionManager.h"
#import "STMCoreObjectsController.h"
#import "STMOperationQueue.h"

@interface STMCorePicturesController()

@property (nonatomic, strong) NSOperationQueue *uploadQueue;
@property (nonatomic, strong) NSMutableDictionary *hrefDictionary;
@property (nonatomic,readonly) BOOL waitingForDownloadPicture;

@property (nonatomic, strong) NSMutableDictionary *settings;

@property (nonatomic, strong) NSString *imagesCachePath;

@property (nonatomic, strong) STMPersistingObservingSubscriptionID nonloadedPicturesSubscriptionID;

@property (nonatomic,strong) STMOperationQueue *downloadQueue;

@property (readonly) NSSet <NSString *> *pictureEntitiesNames;
@property (readonly) NSArray <NSString *> *photoEntitiesNames;
@property (readonly) NSArray <NSString *> *instantLoadEntityNames;
@property (readonly) NSArray <NSDictionary *> *allPictures;

@end


@implementation STMCorePicturesController

@synthesize nonloadedPicturesCount = _nonloadedPicturesCount;

+ (STMCorePicturesController *)sharedController {
    return [super sharedInstance];
}

+ (id <STMPersistingPromised,STMPersistingAsync,STMPersistingSync>)persistenceDelegate {
    return [[self sharedController] persistenceDelegate];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.downloadQueue = [[STMOperationQueue alloc] init];
        self.downloadQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

#pragma mark - instance properties

- (BOOL)waitingForDownloadPicture {
    return !!self.downloadQueue.operationCount;
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

+ (NSArray *)allPictures {
    return [self sharedController].allPictures;
}

- (NSSet <NSString *> *)pictureEntitiesNames {
    return [self.persistenceDelegate hierarchyForEntityName:@"STMCorePicture"];
}

- (NSArray *)allPictures {

    return [self allPicturesWithPredicate:nil];
    
}

- (NSArray *)allPicturesWithPredicate:(NSPredicate*)predicate{
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSString *entityName in self.pictureEntitiesNames) {
        NSArray *objects = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:nil error:nil];
        [result addObjectsFromArray:[STMFunctions mapArray:objects withBlock:^id _Nonnull(id  _Nonnull value) {
            return @{@"entityName":entityName, @"attributes":value};
        }]];
    }
    
    return result.copy;
    
}

- (NSArray *)photoEntitiesNames {
    return @[@"STMVisitPhoto",@"STMOutletPhoto"];
}

- (NSArray *)instantLoadEntityNames {
    return @[@"STMMessagePicture"];
}

- (NSArray *)nonloadedPictures {
    
    NSString *loadablePictures = @"NOT (entityName IN %@) AND (attributes.href != nil) AND (attributes.thumbnailPath == nil)";
    NSArray *excludingPhotosAndInstant = [self.photoEntitiesNames arrayByAddingObjectsFromArray:self.instantLoadEntityNames];
    NSPredicate *nonloadedPicturesPredicate = [NSPredicate predicateWithFormat:loadablePictures, excludingPhotosAndInstant];
    
    return [self.allPictures filteredArrayUsingPredicate:nonloadedPicturesPredicate];
    
}

- (NSUInteger)nonloadedPicturesCount {

    if (!self.nonloadedPicturesSubscriptionID) {
        
        _nonloadedPicturesCount = [self nonloadedPictures].count;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"href != %@", nil];
        
        self.nonloadedPicturesSubscriptionID = [self.persistenceDelegate observeEntityNames:self.pictureEntitiesNames.allObjects predicate:predicate callback:^(NSString * entityName, NSArray *data) {
            
            _nonloadedPicturesCount = [self nonloadedPictures].count;
            
            [self postAsyncMainQueueNotification:@"nonloadedPicturesCountDidChange"];
            
        }];
        
    }

    if (_nonloadedPicturesCount == 0) self.downloadingPictures = NO;

    return _nonloadedPicturesCount;
}


- (NSString *)imagesCachePath {
    
    if (!_imagesCachePath) {
        _imagesCachePath = [self.session.filing picturesBasePath];
    }
    return _imagesCachePath;

}

#pragma mark - class methods

+ (CGFloat)jpgQuality {
    
    NSDictionary *appSettings = [[self session].settingsController currentSettingsForGroup:@"appSettings"];
    CGFloat jpgQuality = [appSettings[@"jpgQuality"] floatValue];

    return jpgQuality;
    
}

+ (void)checkPhotos {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    
        [self startCheckingPicturesPaths];
        
        [self checkBrokenPhotos];
        [self checkNotUploadedPhotos];
        
#warning counts large downloaded images as unused
        
        NSLog(@"checkPhotos finish");
    });
    
}

+ (NSString *)imagesCachePath {
    return [self sharedController].imagesCachePath;
}

#pragma mark - checkPicturesPaths

+ (void)startCheckingPicturesPaths {
    
    NSArray *allPictures = [STMCorePicturesController allPictures];
    
    if (!allPictures.count) return;

    NSLogMethodName;

    for (NSDictionary *picture in allPictures) {
        
        NSString *entityName = picture[@"entityName"];
        NSMutableDictionary *attributes = [picture[@"attributes"] mutableCopy];
        
        if (![STMFunctions isNotNull:attributes[@"thumbnailPath"]] && [STMFunctions isNotNull:attributes[@"thumbnailHref"]]){
            
            NSString* thumbnailHref = attributes[@"thumbnailHref"];
            NSURL *thumbnailUrl = [NSURL URLWithString: thumbnailHref];
            NSData *thumbnailData = [[NSData alloc] initWithContentsOfURL: thumbnailUrl];
            
            if (thumbnailData) [STMCorePicturesController setThumbnailForPicture:attributes fromImageData:thumbnailData];
            
            NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"thumbnailPath"],STMPersistingOptionSetTs:@NO};
            
            [self.persistenceDelegate update:entityName attributes:attributes.copy options:options]
            .then(^(NSDictionary * result){
                NSLog(@"thumbnail set %@ id: %@", entityName, attributes[STMPersistingKeyPrimary]);
            })
            .catch(^(NSError *error){
                NSLog(@"thumbnail set %@ id: %@ error:",entityName, attributes[STMPersistingKeyPrimary], [error localizedDescription]);
            });
            
            continue;
        }
        
        NSArray *pathComponents = ![attributes[@"imagePath"] isKindOfClass:NSNull.class] ? [attributes[@"imagePath"] pathComponents] : nil;
        
        if (pathComponents.count == 0) {
            
            if ([STMFunctions isNotNull:attributes[@"href"]]) {
                
                [self hrefProcessingForObject:picture.copy];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"checkingPicturesPaths picture %@ has no both imagePath and href, will be deleted", attributes[@"id"]];
                [[self sharedController].logger errorMessage:logMessage];
                [self deletePicture:picture];
                
            }
            
        } else {
            
            if (pathComponents.count > 1) {
                
                NSMutableDictionary *mutPicture = picture.mutableCopy;
                
                [self imagePathsConvertingFromAbsoluteToRelativeForPicture:mutPicture];
                
                attributes = mutPicture[@"attributes"];
                
                NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"imagePath",@"resizedImagePath"],STMPersistingOptionSetTs:@NO};
                [self.persistenceDelegate update:entityName attributes:attributes options:options];
            }
            
        }
        
    }
    
}

+ (void)imagePathsConvertingFromAbsoluteToRelativeForPicture:(NSMutableDictionary *)picture {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSMutableDictionary *attributes = [picture[@"attributes"] mutableCopy];
    
    NSString *newImagePath = [self convertImagePath:attributes[@"imagePath"]];
    NSString *newResizedImagePath = [self convertImagePath:attributes[@"resizedImagePath"]];
    
    if (newImagePath) {

        NSLog(@"set new imagePath for picture %@", attributes[@"id"]);
        attributes[@"imagePath"] = newImagePath;

        if (newResizedImagePath) {
            
            NSLog(@"set new resizedImagePath for picture %@", attributes[@"id"]);
            attributes[@"resizedImagePath"] = newResizedImagePath;
            
        } else {
            
            NSLog(@"! new resizedImagePath for picture %@", attributes[@"id"]);

            if ([fileManager fileExistsAtPath:(NSString * _Nonnull)attributes[@"resizedImagePath"]]) {
                [fileManager removeItemAtPath:(NSString * _Nonnull)attributes[@"resizedImagePath"] error:nil];
            }

            NSLog(@"save new resizedImage file for picture %@", attributes[@"id"]);
            NSData *imageData = [NSData dataWithContentsOfFile:[[self imagesCachePath] stringByAppendingPathComponent:newImagePath]];
            
            [self saveResizedImageFile:[@"resized_" stringByAppendingString:newImagePath]
                            forPicture:attributes
                         fromImageData:imageData];
            
        }
        picture[@"attributes"] = attributes.copy;
        
    } else {

        NSLog(@"! new imagePath for picture %@", attributes[@"id"]);

        if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
            
            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no newImagePath and have href for picture %@, flush picture and download data again", attributes[@"id"]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self removeImageFilesForPicture:attributes.copy];
            [self hrefProcessingForObject:picture];
            
        } else {

            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no newImagePath and no href for picture %@, will be deleted", attributes[@"id"]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self deletePicture:picture.copy];
            
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
    
    STMCorePicturesController *controller = [self sharedController];
    
    NSPredicate *anyNilPaths = [NSPredicate predicateWithFormat:@"thumbnailPath == nil OR imagePath == nil"];
    
    NSArray *result = [controller allPicturesWithPredicate:anyNilPaths];
    
    for (NSDictionary *picture in result) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        if (!attributes[@"imagePath"] || [attributes[@"imagePath"] isKindOfClass:NSNull.class]) {
            
            if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
                
                [self hrefProcessingForObject:picture];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"picture %@ have no both imagePath and href", picture];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
                [self deletePicture:picture];
                
            }
            
            continue;
            
        }
            
        NSError *error = nil;
        NSString *path = [[self imagesCachePath] stringByAppendingPathComponent:picture[@"imagePath"]];
        NSData *photoData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (photoData && photoData.length > 0) {
            
            attributes = [self setImagesFromData:photoData forPicture:attributes withEntityName:entityName andUpload:NO];
            
            if (!attributes) continue;
            
            [controller.persistenceDelegate updateAsync:entityName attributes:attributes options:@{STMPersistingOptionSetTs:@NO} completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                [controller postAsyncMainQueueNotification:NOTIFICATION_PICTURE_WAS_DOWNLOADED
                                                  userInfo:[STMFunctions setValue:result forKey:@"attributes" inDictionary:picture]];
            }];
            
            
        } else if (error) {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos dataWithContentsOfFile %@ error: %@", picture[@"imagePath"], error.localizedDescription];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
            
        } else if (picture[@"href"] && ![picture[@"href"] isKindOfClass:NSNull.class]) {
            
            [self hrefProcessingForObject:picture.mutableCopy];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos attempt to set images for picture %@, photoData %@, length %lu, have no photoData and have no href, will be deleted", picture, photoData, (unsigned long)photoData.length];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
            
            [self deletePicture:picture];
            
        }

    }
    
}

+ (void)checkNotUploadedPhotos {

    NSUInteger counter = 0;

    NSPredicate *notUploaded = [NSPredicate predicateWithFormat:@"href == nil"];
    STMCorePicturesController *controller = [self sharedController];
    
    for (NSDictionary *picture in [controller allPicturesWithPredicate:notUploaded].copy) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        if ([STMFunctions isNotNull:attributes[@"imagePath"]]) continue;
            
        NSError *error = nil;
        NSString *path = [[self imagesCachePath] stringByAppendingPathComponent:attributes[@"imagePath"]];
        NSData *imageData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (imageData && imageData.length > 0) {
            
            [controller uploadImageEntityName:entityName attributes:attributes data:imageData];
            counter++;
            
            return;
            
        }
        
        
        if (error) {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkUploadedPhotos dataWithContentsOfFile error: %@", error.localizedDescription];
            [[self sharedController].logger errorMessage:logMessage];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"attempt to upload picture %@, imageData %@, length %lu — object will be deleted", entityName, imageData, (unsigned long)imageData.length];
            
            [controller.logger errorMessage:logMessage];
            
            [self deletePicture:picture];
            
        }
        
    }
    
    if (counter > 0) {
		[controller.logger importantMessage:[NSString stringWithFormat:@"Sending %@ photos",@(counter)]];
    }
    
}


#pragma mark - other methods

+ (void)hrefProcessingForObject:(NSDictionary *)object {
    
    STMCorePicturesController *controlller = [self sharedController];

    NSString *entityName = object[@"entityName"];
    NSMutableDictionary *attributes = [object[@"attributes"] mutableCopy];
    NSString *href = attributes[@"href"];
    
    if (![STMFunctions isNotNull:href]) return;
        
    if (![controlller.pictureEntitiesNames containsObject:entityName]) return;
    
    if (controlller.hrefDictionary[href]) return;
        
    controlller.hrefDictionary[href] = object;
    
    if ([controlller.instantLoadEntityNames containsObject:entityName]) {
        [controlller downloadImagesEntityName:entityName attributes:attributes];
    }

}

+ (NSDictionary *)setImagesFromData:(NSData *)data forPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName andUpload:(BOOL)shouldUpload{
    
    NSString *xid = picture[STMPersistingKeyPrimary];
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    if (shouldUpload) {
        [[self sharedController] uploadImageEntityName:entityName attributes:picture data:data];
    }
    
    if (!fileName) return nil;
        
    BOOL result = YES;
    NSMutableDictionary *mutablePicture = picture.mutableCopy;
    
    result = result && [self saveImageFile:fileName forPicture:mutablePicture fromImageData:data];
    result = result && [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:mutablePicture fromImageData:data];
    
    result = result && [self setThumbnailForPicture:mutablePicture fromImageData:data];
    
    if (!result) {
        NSString *logMessage = [NSString stringWithFormat:@"have problem while save image files %@", fileName];
        [[STMLogger sharedLogger] errorMessage:logMessage];
        return nil;
    }
    
    return mutablePicture.copy;
    
}

+ (BOOL)saveImageFile:(NSString *)fileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data {
    
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
    
    if (!result) {
        
        NSString *logMessage = [NSString stringWithFormat:@"saveImageFile %@ writeToFile %@ error: %@", fileName, imagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
        return NO;
        
    }
    
    picture[@"imagePath"] = fileName;

    return result;
    
}

+ (BOOL)saveResizedImageFile:(NSString *)resizedFileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data {

    NSString *resizedImagePath = [[self imagesCachePath] stringByAppendingPathComponent:resizedFileName];
    
    UIImage *resizedImage = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(1024, 1024) allowRetina:NO];
    NSData *resizedImageData = UIImageJPEGRepresentation(resizedImage, [self jpgQuality]);

    NSError *error = nil;
    BOOL result = [resizedImageData writeToFile:resizedImagePath
                                        options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                          error:&error];
    
    if (!result) {
        NSString *logMessage = [NSString stringWithFormat:@"saveResizedImageFile %@ writeToFile %@ error: %@", resizedFileName, resizedImagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
        return NO;
	}

    picture[@"resizedImagePath"] = resizedFileName;

    return result;

}

+ (BOOL)setThumbnailForPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data {
    
    NSString *xid = picture[@"id"];
    NSString *fileName = [NSString stringWithFormat:@"thumbnail_%@.jpg",xid];
    
    UIImage *thumbnailPath = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:CGSizeMake(150, 150)];
    NSData *thumbnail = UIImageJPEGRepresentation(thumbnailPath, [self jpgQuality]);
    
    NSString *imagePath = [[self imagesCachePath] stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL result = [thumbnail writeToFile:imagePath
                                 options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                   error:&error];
    
    if (result) {
        
        picture[@"thumbnailPath"] = fileName;
        
        return YES;
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"saveImageThumbnailFile %@ writeToFile %@ error: %@", fileName, imagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        return NO;
        
    }
    
}


#pragma mark - queues

- (void)startDownloadingPictures {
    [self downloadNextPicture];
}

- (void)downloadNextPicture {
    
    if (!self.downloadingPictures) return;
    
    NSDictionary *picture = self.hrefDictionary.allValues.firstObject;
    
    NSString *entityName = picture[@"entityName"];
    NSMutableDictionary *attributes = picture[@"attributes"];
    
    if (attributes) {
        
        [self downloadImagesEntityName:entityName attributes:attributes];

    } else {
        
        self.downloadingPictures = NO;
        [STMCorePicturesController checkBrokenPhotos];
        self.downloadingPictures = (self.hrefDictionary.allValues.count > 0);
        
    }

}

- (void)stopDownloadingPictures {

}


- (AnyPromise *)downloadImagesEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes {
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        
        NSString *href = attributes[@"href"];
        
        if (![STMFunctions isNotNull:href] || ![self.pictureEntitiesNames containsObject:entityName]) {
            return resolve([STMFunctions errorWithMessage:@"no href or not a Picture"]);
        }
        
        if ([STMFunctions isNotNull:attributes[@"imagePath"]]) {
            [self didProcessHref:href];
            return resolve(attributes);
        }
        
        NSURL *url = [NSURL URLWithString:href];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        NSLog(@"start: %@", href);
        
        [NSURLConnection sendAsynchronousRequest:request queue:self.downloadQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            [self didProcessHref:href];
            
            if (connectionError) return resolve(connectionError);
                
            NSDictionary *pictureWithPaths = [self.class setImagesFromData:data forPicture:attributes withEntityName:entityName andUpload:NO];
            
            NSArray *attributesToUpdate = @[@"imagePath", @"resizedImagePath", @"thumbnailPath"];
            
            NSDictionary *options = @{
                                      STMPersistingOptionFieldstoUpdate: attributesToUpdate,
                                      STMPersistingOptionSetTs: @NO
                                      };
            
            resolve([self.persistenceDelegate update:entityName attributes:pictureWithPaths.copy options:options]);

        }];

    }]
    .then(^(NSDictionary *success) {
        
        NSLog(@"success: %@ %@", entityName, success[@"href"]);
        [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_WAS_DOWNLOADED userInfo:success];
   
    })
    .catch(^(NSError *error) {
        
        NSLog(@"error: %@ %@", entityName, error);
        [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_DOWNLOAD_ERROR
                                    userInfo:@{@"error" : error.localizedDescription}];
   
    });
    
}

- (void)didProcessHref:(NSString *)href {

    [self.hrefDictionary removeObjectForKey:href];
    [self downloadNextPicture];

}

- (void)uploadImageEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes data:(NSData *)data {

    NSDictionary *appSettings = [self.session.settingsController currentSettingsForGroup:@"appSettings"];
    NSString *url = [[appSettings valueForKey:@"IMS.url"] stringByAppendingString:@"?folder="];
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy";
    NSString *year = [dateFormatter stringFromDate:currentDate];
    dateFormatter.dateFormat = @"MM";
    NSString *month = [dateFormatter stringFromDate:currentDate];
    dateFormatter.dateFormat = @"dd";
    NSString *day = [dateFormatter stringFromDate:currentDate];
    
    NSURL *imsURL = [NSURL URLWithString:[url stringByAppendingString:[NSString stringWithFormat:@"%@/%@/%@/%@", entityName, year, month, day]]];
    
    NSMutableURLRequest *request = [self.authController authenticateRequest:[NSURLRequest requestWithURL:imsURL]].mutableCopy;
    [request setHTTPMethod:@"POST"];
    [request setValue: @"image/jpeg" forHTTPHeaderField:@"content-type"];
    [request setHTTPBody:data];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

       if (error) {
           NSLog(@"connectionError %@", error.localizedDescription);
           return;
       }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        
        if (statusCode != 200) {
            NSLog(@"Request error, statusCode: %ld", (long)statusCode);
            return;
        }
            
        NSError *localError = nil;
        
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&localError];
        
        if (!dictionary) {
            NSLog(@"error in json serialization: %@", localError.localizedDescription);
            return;
        }

        NSArray *picturesDicts = dictionary[@"pictures"];

        NSData *picturesJson = [NSJSONSerialization dataWithJSONObject:picturesDicts options:0 error:&localError];
        
        if (!picturesJson) {
            NSLog(@"error in json serialization: %@", localError.localizedDescription);
            return;
        }
        
        NSMutableDictionary *picture = attributes.mutableCopy;
        
        for (NSDictionary *dict in picturesDicts){
            if ([dict[@"name"] isEqual:@"original"]){
                picture[@"href"] = dict[@"src"];
            }
        }
        
        NSString *info = [[NSString alloc] initWithData:picturesJson encoding:NSUTF8StringEncoding];
        
        picture[@"picturesInfo"] = [info stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        
        NSLog(@"%@", picture[@"picturesInfo"]);
        
        NSDictionary *fieldstoUpdate = @{STMPersistingOptionFieldstoUpdate:@[@"href", @"picturesInfo"]};
        
        [self.persistenceDelegate updateAsync:entityName attributes:picture options:fieldstoUpdate completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
            if (result) return;
            [self.persistenceDelegate mergeSync:entityName attributes:attributes options:nil error:&error];
            if (error) {
                NSLog(@"error: %@", error);
            }
        }];

    }];

}


#pragma mark

+ (void)deletePicture:(NSDictionary *)picture {

//    NSLog(@"delete picture %@", picture);
    
    NSString *entityName = picture[@"entityName"];
    NSDictionary *attributes = picture[@"attributes"];
    
    [self removeImageFilesForPicture:attributes];
    
    NSError *error;

    [self.persistenceDelegate destroySync:entityName
                               identifier:[STMFunctions hexStringFromData:attributes[@"id"]]
                                  options:nil error:&error];
    
}

+ (void)removeImageFilesForPicture:(NSDictionary *)picture {
    
    if (picture[@"imagePath"] && ![picture[@"imagePath"] isKindOfClass:NSNull.class]) [self removeImageFile:picture[@"imagePath"]];
    if (picture[@"resizedImagePath"] && ![picture[@"resizedImagePath"] isKindOfClass:NSNull.class]) [self removeImageFile:picture[@"resizedImagePath"]];
    
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
