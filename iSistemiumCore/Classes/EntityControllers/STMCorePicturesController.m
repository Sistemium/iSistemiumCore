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

@interface STMCorePicturesController()

@property (nonatomic, strong) NSOperationQueue *uploadQueue;
@property (nonatomic, strong) NSMutableDictionary *hrefDictionary;
@property (nonatomic) BOOL waitingForDownloadPicture;

@property (nonatomic, strong) NSMutableDictionary *settings;

@property (nonatomic, strong) NSString *imagesCachePath;

@property (nonatomic, strong) STMPersistingObservingSubscriptionID nonloadedPicturesSubscriptionID;

@end


@implementation STMCorePicturesController

@synthesize nonloadedPicturesCount = _nonloadedPicturesCount;

+ (STMCorePicturesController *)sharedController {
    return [super sharedInstance];
}

+ (id <STMPersistingPromised,STMPersistingAsync,STMPersistingSync>)persistenceDelegate {
    return [[self sharedController] persistenceDelegate];
}

#pragma mark - instance properties


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

+ (NSSet <NSString *> *)pictureEntitiesNames {
    
    return [[self persistenceDelegate] hierarchyForEntityName:@"STMCorePicture"];
    
}

+ (NSArray *)allPictures {
    
    return [self allPicturesWithPredicate:nil];
    
}

+ (NSArray *)allPicturesWithPredicate:(NSPredicate*)predicate{
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSString *entityName in [self pictureEntitiesNames]) {
        NSArray *objects = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:nil error:nil];
        [result addObjectsFromArray:[STMFunctions mapArray:objects withBlock:^id _Nonnull(id  _Nonnull value) {
            return @{@"entityName":entityName, @"data":value};
        }]];
    }
    
    return result.copy;
    
}

- (NSArray *)photoEntitiesNames {
    return @[@"STMVisitPhoto",@"STMOutletPhoto"];
}

- (NSArray *)instantLoadPicturesEntityNames {
    return @[@"STMMessagePicture"];
}

- (NSArray *)nonloadedPictures {
    
    NSArray *predicateArray = [[self photoEntitiesNames] arrayByAddingObjectsFromArray:[self instantLoadPicturesEntityNames]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (entity.name IN %@) AND (href != %@) AND (thumbnailPath == %@)", predicateArray,nil,nil];
    return [[self.class allPictures] filteredArrayUsingPredicate:predicate];
    
}

- (NSUInteger)nonloadedPicturesCount {

    if (!self.nonloadedPicturesSubscriptionID) {
        
        _nonloadedPicturesCount = [self nonloadedPictures].count;
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"href != %@", nil];
        
        self.nonloadedPicturesSubscriptionID = [self.persistenceDelegate observeEntityNames:[self.class pictureEntitiesNames].allObjects predicate:predicate callback:^(NSString * entityName, NSArray *data) {
            
            _nonloadedPicturesCount = [self nonloadedPictures].count;
            
            [self postAsyncMainQueueNotification:@"nonloadedPicturesCountDidChange"];
            
        }];
        
    }

    if (_nonloadedPicturesCount == 0) self.downloadingPictures = NO;

    return _nonloadedPicturesCount;
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
        [self checkUploadedPhotos];
        
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
        NSMutableDictionary *attributes = [picture[@"data"] mutableCopy];
        
        if ((attributes[@"thumbnailPath"] == nil || [attributes[@"thumbnailPath"] isKindOfClass:NSNull.class]) && attributes[@"thumbnailHref"] != nil && ![attributes[@"thumbnailHref"] isKindOfClass:NSNull.class]){
            
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
            
            if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
                
                [self hrefProcessingForObject:picture.mutableCopy];
                
            } else {
                
<<<<<<< HEAD
                NSString *logMessage = [NSString stringWithFormat:@"checkingPicturesPaths picture %@ has no both imagePath and href, will be deleted", attributes[@"id"]];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
=======
                NSString *logMessage = [NSString stringWithFormat:@"checkingPicturesPaths picture %@ has no both imagePath and href, will be deleted", picture.xid];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
>>>>>>> persisting
                [self deletePicture:picture];
                
            }
            
        } else {
            
            if (pathComponents.count > 1) {
                
                NSMutableDictionary *mutPicture = picture.mutableCopy;
                
                [self imagePathsConvertingFromAbsoluteToRelativeForPicture:mutPicture];
                
                attributes = mutPicture[@"data"];
                
                NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"imagePath",@"resizedImagePath"],STMPersistingOptionSetTs:@NO};
                [self.persistenceDelegate update:entityName attributes:attributes options:options];
            }
            
        }
        
    }
    
}

+ (void)imagePathsConvertingFromAbsoluteToRelativeForPicture:(NSMutableDictionary *)picture {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSMutableDictionary *attributes = [picture[@"data"] mutableCopy];
    
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
        picture[@"data"] = attributes.copy;
        
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
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"thumbnailPath == %@ OR imagePath == %@", nil, nil];
    
    NSArray *result = [self.class allPicturesWithPredicate:predicate];
    
    for (NSDictionary *picture in result) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"data"];
        
        if (!attributes[@"imagePath"] || [attributes[@"imagePath"] isKindOfClass:NSNull.class]) {
            
            if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
                
                [self hrefProcessingForObject:picture.mutableCopy];
                
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
            
            [self setImagesFromData:photoData forPicture:attributes.mutableCopy withEntityName:entityName andUpload:NO];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PICTURE_WAS_DOWNLOADED object:self userInfo:picture];
                
            });
            
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

+ (void)checkUploadedPhotos {

    int counter = 0;

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"href == %@", nil];
    
    NSArray *result = [self.class allPicturesWithPredicate:predicate];
    
    for (NSDictionary *picture in result) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"data"];
        
        if (attributes[@"imagePath"] && ![attributes[@"imagePath"] isKindOfClass:NSNull.class]) continue;
            
        NSError *error = nil;
        NSString *path = [[self imagesCachePath] stringByAppendingPathComponent:attributes[@"imagePath"]];
        NSData *photoData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (photoData && photoData.length > 0) {
            
            [[self sharedController] addUploadOperationForPicture:attributes.mutableCopy withEntityName:entityName data:photoData];
            counter++;
            
        } else if (!error) {
                
            NSString *logMessage = [NSString stringWithFormat:@"attempt to upload picture %@, photoData %@, length %lu — object will be deleted", entityName, photoData, (unsigned long)photoData.length];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            [self deletePicture:picture];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkUploadedPhotos dataWithContentsOfFile error: %@", error.localizedDescription];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
        }
        
    }
    
    if (counter > 0) {
		NSString *logMessage = [NSString stringWithFormat:@"Sending %i photos",counter];
		[[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
    }
    
}


#pragma mark - other methods

+ (void)hrefProcessingForObject:(NSDictionary *)object {
    
    NSString *entityName = object[@"entityName"];
    NSMutableDictionary *attributes = [object[@"data"] mutableCopy];
    
    NSString *href = attributes[@"href"];
    
    if (!href || [href isKindOfClass:NSNull.class]) return;
        
    if (![[self pictureEntitiesNames] containsObject:entityName]) return;
        
    STMCorePicturesController *pc = [self sharedController];
    
    if ([pc.hrefDictionary objectForKey:href]) return;
        
    pc.hrefDictionary[href] = object;
    
    if (pc.downloadingPictures) {
        [pc downloadNextPicture];
    } else if ([[pc instantLoadPicturesEntityNames] containsObject:entityName]) {
        [self downloadConnectionForPicture:attributes withEntityName:entityName];
    }

}

+ (void)setImagesFromData:(NSData *)data forPicture:(NSMutableDictionary *)picture withEntityName:(NSString *)entityName andUpload:(BOOL)shouldUpload{
    
    NSString *xid = picture[@"id"];
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
    
    if ([entityName isEqualToString:@"STMCorePhoto"]) {
        
        if (shouldUpload) {
            [[self sharedController] addUploadOperationForPicture:picture withEntityName:entityName data:data];
        }

    }
    
    if (!fileName) return;
        
    BOOL result = YES;
    
    result = (result && [self saveImageFile:fileName forPicture:picture fromImageData:data]);
    result = (result && [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:picture fromImageData:data]);
    
    result = (result && [self setThumbnailForPicture:picture fromImageData:data]);
    
    if (!result) {
        
        NSString *logMessage = [NSString stringWithFormat:@"have problem while save image files %@", fileName];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];

    }

    
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
    
    if (!self.downloadingPictures || self.waitingForDownloadPicture) return;
        
    NSDictionary *picture = self.hrefDictionary.allValues.firstObject;
    
    NSString *entityName = picture[@"entityName"];
    NSMutableDictionary *attributes = picture[@"data"];
    
    if (attributes) {
        
        [self downloadConnectionForPicture:attributes withEntityName:entityName];
        
    } else {
        
        self.downloadingPictures = NO;
        [STMCorePicturesController checkBrokenPhotos];
        self.downloadingPictures = (self.hrefDictionary.allValues.count > 0);
        
    }

}

- (void)stopDownloadingPictures {

}

+ (void)downloadConnectionForPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName{
    [[self sharedController] downloadConnectionForPicture:picture withEntityName:entityName];
}

- (void)downloadConnectionForPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName{

    NSString *href = picture[@"href"];
    
    if (!href || [href isKindOfClass:NSNull.class] || ![self.class.pictureEntitiesNames containsObject:entityName]) return;
        
    if (picture[@"imagePath"] && ![picture[@"imagePath"] isKindOfClass:NSNull.class]) return [self didProcessHref:href];
    
    self.waitingForDownloadPicture = YES;
    
    NSURL *url = [NSURL URLWithString:href];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSLog(@"downloadConnectionForObject start: %@", href);
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               
        self.waitingForDownloadPicture = NO;
        
        if (connectionError) {
            
            NSLog(@"error %@ in %@", connectionError.description, entityName);
            
            [self.notificationCenter postNotificationName:NOTIFICATION_PICTURE_DOWNLOAD_ERROR
                                                   object:picture
                                                 userInfo:@{@"error" : connectionError.description}];

        } else {
            
            NSMutableDictionary *mutPict = picture.mutableCopy;
            
            [self.class setImagesFromData:data forPicture:mutPict withEntityName:entityName andUpload:NO];
            
            NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"imagePath",@"resizedImagePath",@"thumbnailPath"],STMPersistingOptionSetTs:@NO};
            
            [self.persistenceDelegate update:entityName attributes:mutPict.copy options:options].then(^(NSDictionary *result){
                NSLog(@"downloadConnectionForObject saved: %@", href);
                [self.notificationCenter postNotificationName:NOTIFICATION_PICTURE_WAS_DOWNLOADED object:self userInfo:result];
            }).catch(^(NSError *error){
                NSLog(@"Error: %@", error);
            });

        }
        
        [self didProcessHref:href];
        
    }];

    
}

- (void)didProcessHref:(NSString *)href {

    [self.hrefDictionary removeObjectForKey:href];
    [self downloadNextPicture];

}

- (void)addUploadOperationForPicture:(NSMutableDictionary *)picture withEntityName:(NSString *)entityName data:(NSData *)data {

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
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

        if (!error) {
                
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
                                    picture[@"href"] = dict[@"src"];
                                }
                            }
                            
                            NSString *info = [[NSString alloc] initWithData:picturesJson
                                                                   encoding:NSUTF8StringEncoding];
                            
                            picture[@"picturesInfo"] = [info stringByReplacingOccurrencesOfString:@"\\/"
                                                                                   withString:@"/"];
                            
                            NSLog(@"%@", picture[@"picturesInfo"]);
                                                                                    
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
            NSLog(@"connectionError %@", error.localizedDescription);
        }

    }];

}


#pragma mark

+ (void)deletePicture:(NSDictionary *)picture {

//    NSLog(@"delete picture %@", picture);
    
    NSString *entityName = picture[@"entityName"];
    NSDictionary *attributes = picture[@"data"];
    
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
