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
#import "STMEntityController.h"


#define THUMBNAIL_SIZE CGSizeMake(150, 150)


@interface STMCorePicturesController()

@property (nonatomic, strong) NSOperationQueue *uploadQueue;
@property (nonatomic, strong) NSMutableDictionary *hrefDictionary;
@property (nonatomic,readonly) BOOL waitingForDownloadPicture;

@property (nonatomic, strong) NSMutableDictionary *settings;

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

- (id <STMFiling>)filing {
    
    if (!_filing){
        
        _filing = self.session.filing;
        
    }
    
    return _filing;
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

#pragma mark - class methods

- (CGFloat)jpgQuality {
    
    NSDictionary *appSettings = [[self session].settingsController currentSettingsForGroup:@"appSettings"];
    CGFloat jpgQuality = [appSettings[@"jpgQuality"] floatValue];

    return jpgQuality;
    
}

- (void)checkPhotos {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    
        [self startCheckingPicturesPaths];
        
        [self checkBrokenPhotos];
        [self checkNotUploadedPhotos];
        
        NSLog(@"checkPhotos finish");
        
    });
    
}

#pragma mark - checkPicturesPaths

- (void)startCheckingPicturesPaths {
    
    NSArray *allPictures = [self allPictures];
    
    if (!allPictures.count) return;

    NSLogMethodName;

    for (NSDictionary *picture in allPictures) {
        
        NSString *entityName = picture[@"entityName"];
        NSMutableDictionary *attributes = [picture[@"attributes"] mutableCopy];
        
        // use STMFunctions isNull: here?
        if (![STMFunctions isNotNull:attributes[@"thumbnailPath"]] && [STMFunctions isNotNull:attributes[@"thumbnailHref"]]){
            
            NSString *thumbnailHref = attributes[@"thumbnailHref"];
            NSURL *thumbnailUrl = [NSURL URLWithString: thumbnailHref];
            NSData *thumbnailData = [[NSData alloc] initWithContentsOfURL: thumbnailUrl];
            
            if (thumbnailData) {
            
                NSString *xid = attributes[STMPersistingKeyPrimary];
                NSString *fileName = [@[@"thumbnail_", xid, @".jpg"] componentsJoinedByString:@""];
                
                // we already have thumbnail data and in method below generate it via resizeImage: and UIImageJPEGRepresentation() again
                // have to check if filename already exist?
                
                [self saveThumbnailImageFile:fileName
                                  forPicture:attributes
                               fromImageData:thumbnailData
                              withEntityName:entityName];

            }
            
            //___________
            // mv it in if (thumbnailData) {} ?
            NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"thumbnailPath"],STMPersistingOptionSetTs:@NO};
            
            [self.persistenceDelegate update:entityName attributes:attributes.copy options:options]
            .then(^(NSDictionary *result){
                NSLog(@"thumbnail set %@ id: %@", entityName, attributes[STMPersistingKeyPrimary]);
            })
            .catch(^(NSError *error){
                NSLog(@"thumbnail set %@ id: %@ error:",entityName, attributes[STMPersistingKeyPrimary], [error localizedDescription]);
            });
            // ___________
            
            continue;
        }
        
        NSArray *pathComponents = [STMFunctions isNotNull:attributes[@"imagePath"]] ? [attributes[@"imagePath"] pathComponents] : nil;
        
        if (pathComponents.count == 0) {
            
            if ([STMFunctions isNotNull:attributes[@"href"]]) {
                
                [self hrefProcessingForObject:picture.copy];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"checkingPicturesPaths picture %@ has no both imagePath and href, will be deleted", attributes[@"id"]];
                [self.logger errorMessage:logMessage];
                [self deletePicture:picture];
                
            }
            
        } else {
            
            if (pathComponents.count > 2) {
                
                NSLog(@"pathComponents.count > 2");
                NSLog(@"this should not happened");
                
                NSMutableDictionary *mutPicture = picture.mutableCopy;
                
                [self imagePathsConvertingFromAbsoluteToRelativeForPicture:mutPicture];
                
                attributes = mutPicture[@"attributes"];
                
                NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"imagePath",@"resizedImagePath",@"imageThumbnail"],STMPersistingOptionSetTs:@NO};
                [self.persistenceDelegate update:entityName attributes:attributes options:options];
            }
            
        }
        
    }
    
}

- (void)imagePathsConvertingFromAbsoluteToRelativeForPicture:(NSMutableDictionary *)picture {
    
    NSLogMethodName;
    NSLog(@"this method should not be using any more");
    
    NSString *entityName = picture[@"entityName"];
    
    NSMutableDictionary *attributes = [picture[@"attributes"] mutableCopy];
    
    NSString *newImagePath = [self convertImagePath:attributes[@"imagePath"] withEntityName:entityName];
    NSString *newResizedImagePath = [self convertImagePath:attributes[@"resizedImagePath"] withEntityName:entityName];
    NSString *newThumbnailPath = [self convertImagePath:attributes[@"thumbnailPath"] withEntityName:entityName];
    
    if (newImagePath && newResizedImagePath && newThumbnailPath) {

        NSLog(@"set new imagePath for picture %@", attributes[@"id"]);
        attributes[@"imagePath"] = newImagePath;
        NSLog(@"set new resizedImagePath for picture %@", attributes[@"id"]);
        attributes[@"resizedImagePath"] = newResizedImagePath;
        NSLog(@"set new thumbnaiPath for picture %@", attributes[@"id"]);
        attributes[@"thumbnailPath"] = newThumbnailPath;
        
    } else {

        NSLog(@"! new imagePath for picture %@", attributes[@"id"]);

        if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
            
            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no newImagePath and have href for picture %@, flush picture and download data again", attributes[@"id"]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self removeImageFilesForPicture:attributes.copy withEntityName:entityName];
            [self hrefProcessingForObject:picture];
            
        } else {

            NSString *logMessage = [NSString stringWithFormat:@"imagePathsConvertingFromAbsoluteToRelativeForPicture no relative image path and no href for picture %@, will be deleted", attributes[@"id"]];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                     numType:STMLogMessageTypeError];
            
            [self deletePicture:picture.copy];
            
        }

    }

}

- (NSString *)convertImagePath:(NSString *)path withEntityName:(NSString *)entityName{
    
    NSString *lastPathComponent = [path lastPathComponent];
    NSString *imagePath = [[self.filing picturesPath:entityName] stringByAppendingPathComponent:lastPathComponent];
    
    if ([self.filing fileExistsAtPath:imagePath]) {
        return [entityName stringByAppendingPathComponent:lastPathComponent];
    } else {
        return nil;
    }

}


#pragma mark - check Broken & Uploaded Photos

- (void)checkBrokenPhotos {
    
    NSPredicate *anyNilPaths = [NSPredicate predicateWithFormat:@"thumbnailPath == nil OR imagePath == nil OR resizedImagePath == nil"];
    
    for (NSDictionary *picture in [self allPicturesWithPredicate:anyNilPaths]) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        NSString *xid = attributes[STMPersistingKeyPrimary];
        NSString *resizedFileName = [entityName stringByAppendingPathComponent:[@[@"resized_", xid, @".jpg"] componentsJoinedByString:@""]];
        NSString *thumbnailFileName = [entityName stringByAppendingPathComponent:[@[@"thumbnail_", xid, @".jpg"] componentsJoinedByString:@""]];
        
        // we don't check picturesBasePath/entityName is exist here ?
        NSString *resizedImagePath = [[self.filing picturesBasePath] stringByAppendingPathComponent:resizedFileName];
        NSString *thumbnailPath = [[self.filing picturesBasePath] stringByAppendingPathComponent:thumbnailFileName];
        
        NSError *error;
        
        NSMutableArray *fieldsToUpdate = @[].mutableCopy;
        
        NSMutableDictionary *mutAttributes = attributes.mutableCopy;
        
        // use STMFunctions isNull: here?
        if ([self.filing fileExistsAtPath:resizedImagePath] && ![STMFunctions isNotNull:mutAttributes[@"resizedImagePath"]]) {
            
            mutAttributes[@"resizedImagePath"] = resizedFileName;
            
            [fieldsToUpdate addObject:@"resizedImagePath"];
            
            // we don't check imagePath is exist?
            mutAttributes[@"imagePath"] = resizedFileName;
            
            // add wrong obeject? should be @"imagePath"?
            [fieldsToUpdate addObject:@"resizedImagePath"];
            
        }
        
        // use STMFunctions isNull: here?
        if ([self.filing fileExistsAtPath:thumbnailPath] && ![STMFunctions isNotNull:mutAttributes[@"thumbnailPath"]]) {
            
            mutAttributes[@"thumbnailPath"] = thumbnailFileName;
            
            [fieldsToUpdate addObject:@"thumbnailPath"];
            
        }
        
        if (fieldsToUpdate.count > 0){
            
            attributes = [self.persistenceDelegate updateSync:entityName attributes:mutAttributes.copy options:@{STMPersistingOptionSetTs:@NO,STMPersistingOptionFieldstoUpdate:fieldsToUpdate.copy} error:&error];

            // check if attributes is correct here
            NSLog(@"attributes after update", attributes);
            
            if (error){
                NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos error: %@", error.localizedDescription];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
                continue;
            }
            
            NSString *href = attributes[@"href"];
            
            [self.hrefDictionary removeObjectForKey:href];
            
            if (([STMFunctions isNotNull:attributes[@"imagePath"]] &&
                 [STMFunctions isNotNull:attributes[@"resizedImagePath"]] &&
                 [STMFunctions isNotNull:attributes[@"thumbnailPath"]])) {
                
                // why double (()) here?
                
                continue;
                
            }
            
        }
        
        
        // use STMFunctions isNull: here?
        if (![STMFunctions isNotNull:attributes[@"imagePath"]]) {
            
            if ([STMFunctions isNotNull:attributes[@"href"]]) {
                
                [self hrefProcessingForObject:picture];
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"picture %@ have no both imagePath and href", picture];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
                [self deletePicture:picture];
                
            }
            
            continue;
            
        }
        
        if ([STMFunctions isNotNull:attributes[@"thumbnailPath"]]){
            continue;
        }
            
        error = nil;
        NSString *path = [[self.filing picturesBasePath] stringByAppendingPathComponent:attributes[@"imagePath"]];
        
        // what will happend if we don't have @"imagePath"?
        // photoData will try to load picturesBasePath — we should have an error
        
        if ([STMFunctions isNull:attributes[@"imagePath"]]) {
            NSLog(@"imagePath isNull, something wrong should happened further");
        }
        
        NSData *photoData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (photoData && photoData.length > 0) {
            
            NSLog(@"photoData && photoData.length > 0");
            
            attributes = [self setImagesFromData:photoData forPicture:attributes withEntityName:entityName andUpload:NO];
            
            // mv it at begining of block? why we check it here?
            if (!picture) continue;
            
            NSArray *fields = @[@"resizedImagePath",
                                @"thumbnailPath",
                                @"imagePath"];
            
            [self.persistenceDelegate updateAsync:entityName attributes:attributes options:@{STMPersistingOptionSetTs:@NO,STMPersistingOptionFieldstoUpdate:fields} completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                
                [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_WAS_DOWNLOADED
                                            userInfo:[STMFunctions setValue:result
                                                                     forKey:@"attributes"
                                                               inDictionary:picture]];
                
            }];
            
        } else if (error) {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos dataWithContentsOfFile %@ error: %@", attributes[@"imagePath"], error.localizedDescription];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
            
        // use STMFunctions isNotNull: here?
        } else if (attributes[@"href"] && ![attributes[@"href"] isKindOfClass:NSNull.class]) {
            
            // are we already do it earlier?
            [self hrefProcessingForObject:picture.mutableCopy];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos attempt to set images for picture %@, photoData %@, length %lu, have no photoData and have no href, will be deleted", picture, photoData, (unsigned long)photoData.length];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
            
            [self deletePicture:picture];
            
        }

    }
    
    //should we post this notification after all cycle complete or inside each iteration?
    [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_UNUSED_CHANGE];
    
}

- (void)checkNotUploadedPhotos {

    NSLogMethodName;
    
    NSUInteger counter = 0;

    NSPredicate *notUploaded = [NSPredicate predicateWithFormat:@"href == nil"];
    
    for (NSDictionary *picture in [self allPicturesWithPredicate:notUploaded].copy) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        if ([STMFunctions isNotNull:attributes[@"imagePath"]]) continue;
            
        NSError *error = nil;
        NSString *path = [[self.filing picturesBasePath] stringByAppendingPathComponent:attributes[@"imagePath"]];
        NSData *imageData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (imageData && imageData.length > 0) {
            
            [self uploadImageEntityName:entityName attributes:attributes data:imageData];
            counter++;
            
            return;
            
        }
        
        
        if (error) {
            
            NSString *logMessage = [NSString stringWithFormat:@"checkUploadedPhotos dataWithContentsOfFile error: %@", error.localizedDescription];
            [self.logger errorMessage:logMessage];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"attempt to upload picture %@, imageData %@, length %lu — object will be deleted", entityName, imageData, (unsigned long)imageData.length];
            
            [self.logger errorMessage:logMessage];
            
            [self deletePicture:picture];
            
        }
        
    }
    
    if (counter > 0) {
		[self.logger importantMessage:[NSString stringWithFormat:@"Sending %@ photos",@(counter)]];
    }
    
}


#pragma mark - other methods

- (void)hrefProcessingForObject:(NSDictionary *)object {

    NSString *entityName = object[@"entityName"];
    NSMutableDictionary *attributes = [object[@"attributes"] mutableCopy];
    NSString *href = attributes[@"href"];
    
    if (![STMFunctions isNotNull:href]) return;
        
    if (![self.pictureEntitiesNames containsObject:entityName]) return;
    
    if (self.hrefDictionary[href]) return;
        
    self.hrefDictionary[href] = object;
    
    if ([self.instantLoadEntityNames containsObject:entityName]) {
        [self downloadImagesEntityName:entityName attributes:attributes];
    }

}

- (NSDictionary *)setImagesFromData:(NSData *)data forPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName andUpload:(BOOL)shouldUpload{
    
    NSString *xid = picture[STMPersistingKeyPrimary];
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
        
    BOOL result = YES;
    NSMutableDictionary *mutablePicture = picture.mutableCopy;
    
    NSData *resizedData = [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:mutablePicture fromImageData:data withEntityName:entityName];
    
    result = !!resizedData;
    
    if (shouldUpload) {
        
        data = [self saveImageFile:fileName forPicture:mutablePicture fromImageData:data withEntityName:entityName];
        
        result = !!data;
        
        [self uploadImageEntityName:entityName attributes:mutablePicture.copy data:data];
        
    }else{
        mutablePicture[@"imagePath"] = mutablePicture[@"resizedImagePath"];
    }
    
    result = result && [self saveThumbnailImageFile:[@"thumbnail_" stringByAppendingString:fileName] forPicture:mutablePicture fromImageData:data withEntityName:entityName];
    
    if (!result) {
        NSString *logMessage = [NSString stringWithFormat:@"have problem while save image files %@", fileName];
        [[STMLogger sharedLogger] errorMessage:logMessage];
        return nil;
    }
    
    return mutablePicture.copy;
    
}

- (NSData *)saveImageFile:(NSString *)fileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data withEntityName:(NSString *)entityName{
    
    NSString *imagePath = [entityName stringByAppendingPathComponent:fileName];
    
    NSString *absoluteImagePath = [[self.filing picturesPath:entityName] stringByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    BOOL result = absoluteImagePath && data && [data writeToFile:absoluteImagePath
                            options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                              error:&error];
    
    if (!result) {
        
        NSString *logMessage = [NSString stringWithFormat:@"saveImageFile %@ writeToFile %@ error: %@", fileName, absoluteImagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
        return nil;
        
    }
    
    picture[@"imagePath"] = imagePath;

    return result ? data : nil;
    
}

- (NSData *)saveResizedImageFile:(NSString *)resizedFileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data withEntityName:(NSString *)entityName{
    
    double maxPictureScale = [STMFunctions isNotNull:[STMEntityController entityWithName:entityName][@"maxPictureScale"]] ?
    [[STMEntityController entityWithName:entityName][@"maxPictureScale"] doubleValue] : 1;
    
    UIImage *image = [UIImage imageWithData:data];
    CGFloat maxPictureDimension = MAX(image.size.height, image.size.width);
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    CGFloat maxScreenDimension = MAX(screenWidth,screenHeight);
    
    CGFloat MAX_PICTURE_SIZE = maxScreenDimension * maxPictureScale;
    
    if (maxPictureDimension > MAX_PICTURE_SIZE * [UIScreen mainScreen].scale) {
        
        image = [STMFunctions resizeImage:image toSize:CGSizeMake(MAX_PICTURE_SIZE, MAX_PICTURE_SIZE)];
        data = UIImageJPEGRepresentation(image, [self jpgQuality]);
        
    }
    
    NSString *imagePath = [entityName stringByAppendingPathComponent:resizedFileName];
    
    NSString *absoluteImagePath = [[self.filing picturesPath:entityName] stringByAppendingPathComponent:resizedFileName];
    
    NSError *error = nil;
    BOOL result = absoluteImagePath && data && [data writeToFile:absoluteImagePath
                                                         options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                                           error:&error];
    
    if (!result) {
        
        NSString *logMessage = [NSString stringWithFormat:@"saveImageFile %@ writeToFile %@ error: %@", resizedFileName, absoluteImagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
        return nil;
        
    }
    
    picture[@"resizedImagePath"] = imagePath;
    
    return result ? data : nil;

}

- (BOOL)saveThumbnailImageFile:(NSString *)thumbnailFileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data withEntityName:(NSString *)entityName{
    
    UIImage *thumbnailPath = [STMFunctions resizeImage:[UIImage imageWithData:data] toSize:THUMBNAIL_SIZE];
    NSData *thumbnail = UIImageJPEGRepresentation(thumbnailPath, [self jpgQuality]);
    
    NSString *imagePath = [entityName stringByAppendingPathComponent:thumbnailFileName];
    
    NSString *absoluteImagePath = [[self.filing picturesPath:entityName] stringByAppendingPathComponent:thumbnailFileName];
    
    NSError *error = nil;
    BOOL result = absoluteImagePath && thumbnail && [thumbnail writeToFile:absoluteImagePath
                                                                   options:(NSDataWritingAtomic|NSDataWritingFileProtectionNone)
                                                                     error:&error];
    
    if (result) {
        picture[@"thumbnailPath"] = imagePath;
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"saveImageThumbnailFile %@ writeToFile %@ error: %@", thumbnailFileName, absoluteImagePath, error.localizedDescription];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
    return result;
    
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
        [self checkBrokenPhotos];
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
                
            NSDictionary *pictureWithPaths = [self setImagesFromData:data forPicture:attributes withEntityName:entityName andUpload:NO];
            
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
        return success;
   
    })
    .catch(^(NSError *error) {
        
        NSLog(@"error: %@ %@", entityName, error);
        [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_DOWNLOAD_ERROR
                                    userInfo:@{@"error" : error.localizedDescription}];
        return error;
   
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
        
        [self removeImageFile:picture[@"imagePath"] withEntityName:entityName];
        
        picture[@"imagePath"] = picture[@"resizedImagePath"];
        
        NSDictionary *fieldstoUpdate = @{STMPersistingOptionFieldstoUpdate:@[@"href", @"picturesInfo", @"imagePath"]};
        
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

- (void)deletePicture:(NSDictionary *)picture {

//    NSLog(@"delete picture %@", picture);
    
    NSString *entityName = picture[@"entityName"];
    NSDictionary *attributes = picture[@"attributes"];
    
    [self removeImageFilesForPicture:attributes withEntityName:entityName];
    
    NSError *error;

    [self.persistenceDelegate destroySync:entityName
                               identifier:[STMFunctions hexStringFromData:attributes[@"id"]]
                                  options:nil error:&error];
    
}

- (void)removeImageFilesForPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName{
    
    if (picture[@"imagePath"] && ![picture[@"imagePath"] isKindOfClass:NSNull.class]) [self removeImageFile:picture[@"imagePath"] withEntityName:entityName];
    if (picture[@"resizedImagePath"] && ![picture[@"resizedImagePath"] isKindOfClass:NSNull.class]) [self removeImageFile:picture[@"resizedImagePath"] withEntityName:entityName];
    
}

- (void)removeImageFile:(NSString *)filePath withEntityName:(NSString *)entityName{
    
    if (filePath == nil) return;
    
    NSString *imagePath = [[self.filing picturesBasePath] stringByAppendingPathComponent:filePath];

    if ([self.filing fileExistsAtPath:imagePath]) {

        NSError *error;
        BOOL success = [self.filing removeItemAtPath:imagePath error:&error];
        
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
