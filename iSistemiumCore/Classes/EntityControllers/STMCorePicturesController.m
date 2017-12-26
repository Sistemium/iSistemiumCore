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
@property (nonatomic, strong) NSArray *nonloadedPictures;

@property (nonatomic,strong) NSOperationQueue *downloadQueue;

@property (readonly, nonatomic, strong) NSSet <NSString *> *pictureEntitiesNames;
@property (readonly) NSArray <NSString *> *photoEntitiesNames;
@property (readonly) NSArray <NSString *> *instantLoadEntityNames;
@property (readonly) NSArray <NSDictionary *> *allPictures;

@end


@implementation STMCorePicturesController

@synthesize nonloadedPicturesCount = _nonloadedPicturesCount;
@synthesize pictureEntitiesNames = _pictureEntitiesNames;

+ (STMCorePicturesController *)sharedController {
    return [super sharedInstance];
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        self.downloadQueue = [[NSOperationQueue alloc] init];
        self.downloadQueue.maxConcurrentOperationCount = 2;
        
        [self observeNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                         selector:@selector(syncerGetBunchOfObjects)];
        
    }
    return self;
    
}

- (void)dealloc {
    [self removeObservers];
}


#pragma mark - instance properties

- (void)syncerGetBunchOfObjects {
    self.nonloadedPictures = nil;
}

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
        _uploadQueue.maxConcurrentOperationCount = 2;
    }
    return _uploadQueue;
    
}

- (NSSet <NSString *> *)pictureEntitiesNames {
    if (!_pictureEntitiesNames) {
        _pictureEntitiesNames = [self.persistenceDelegate hierarchyForEntityName:@"STMCorePicture"];
    }
    return _pictureEntitiesNames;
}

- (NSArray *)allPictures {
    return [self allPicturesWithPredicate:nil];
}

- (NSArray *)allPicturesWithPredicate:(NSPredicate*)predicate{
    
    NSMutableArray *result = @[].mutableCopy;
    
    NSLog(@"predicate: %@", predicate)
    
    for (NSString *entityName in self.pictureEntitiesNames) {
        NSArray *objects = [self.persistenceDelegate findAllSync:entityName predicate:predicate options:nil error:nil];
        [result addObjectsFromArray:[STMFunctions mapArray:objects withBlock:^id _Nonnull(NSDictionary *value) {
            return @{@"entityName":entityName, @"attributes":value.copy};
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
    
    if (!_nonloadedPictures) {
    
        NSString *loadablePictures = @"NOT (entityName IN %@) AND (attributes.href != nil) AND (attributes.thumbnailPath == nil)";
        NSArray *excludingPhotosAndInstant = [self.photoEntitiesNames arrayByAddingObjectsFromArray:self.instantLoadEntityNames];
        NSPredicate *nonloadedPicturesPredicate = [NSPredicate predicateWithFormat:loadablePictures, excludingPhotosAndInstant];
        
        NSArray *result = [self.allPictures filteredArrayUsingPredicate:nonloadedPicturesPredicate];
        
        _nonloadedPictures = result.count ? result.mutableCopy : nil;

    }
    return _nonloadedPictures;
    
}

- (NSUInteger)nonloadedPicturesCount {

    if (!self.nonloadedPicturesSubscriptionID) {
        
        _nonloadedPicturesCount = self.nonloadedPictures.count;
        [self subscribeToNonloadedPictures];
        
    }

    if (_nonloadedPicturesCount == 0) self.downloadingPictures = NO;

    return _nonloadedPicturesCount;

}

- (void)subscribeToNonloadedPictures {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"href != %@", nil];
    
    self.nonloadedPicturesSubscriptionID = [self.persistenceDelegate observeEntityNames:self.pictureEntitiesNames.allObjects predicate:predicate callback:^(NSString *entityName, NSArray *data) {
        
        NSDictionary *pic = data.firstObject;
        
        if (!pic[@"thumbnailPath"]) return;
        
        NSString *dataId = pic[@"id"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"attributes.id != %@", dataId];
        self.nonloadedPictures = [self.nonloadedPictures filteredArrayUsingPredicate:predicate];
        
        _nonloadedPicturesCount = self.nonloadedPictures.count;
        
        [self postAsyncMainQueueNotification:@"nonloadedPicturesCountDidChange"];
        
    }];

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
    
    NSPredicate *hasThumbnailHrefButNoThumbnailPath = [NSPredicate predicateWithFormat:@"thumbnailHref != nil AND thumbnailPath == nil"];
    
    NSArray *allPictures = [self allPicturesWithPredicate:hasThumbnailHrefButNoThumbnailPath];
    
    NSLogMethodName;

    if (!allPictures.count) {
        NSLog(@"no thumbnail to fix");
        return;
    }

    for (NSDictionary *picture in allPictures) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        if ([STMFunctions isNull:attributes[@"thumbnailPath"]] &&
            [STMFunctions isNotNull:attributes[@"thumbnailHref"]]) {
            
            NSString *thumbnailHref = attributes[@"thumbnailHref"];
            NSURL *thumbnailUrl = [NSURL URLWithString: thumbnailHref];
            NSData *thumbnailData = [[NSData alloc] initWithContentsOfURL: thumbnailUrl];
            
            if (thumbnailData) {
            
                NSString *xid = attributes[STMPersistingKeyPrimary];
                NSString *fileName = [@[@"thumbnail_", xid, @".jpg"] componentsJoinedByString:@""];
                
                // we already have thumbnail data and in method below generate it via resizeImage: and UIImageJPEGRepresentation() again
                // have to check if filename already exist?
                
                NSMutableDictionary *mutablePicture = attributes.mutableCopy;
                
                [self saveThumbnailImageFile:fileName
                                  forPicture:mutablePicture
                               fromImageData:thumbnailData
                              withEntityName:entityName];
                
                attributes = mutablePicture.copy;

            }
            
            //---------
            // mv it in if(thumbnailData){…} ?
            NSDictionary *options = @{STMPersistingOptionFieldstoUpdate : @[@"thumbnailPath"],STMPersistingOptionSetTs:@NO};
            
            [self.persistenceDelegate update:entityName attributes:attributes.copy options:options]
            .then(^(NSDictionary *result){
                NSLog(@"thumbnail set %@ id: %@", entityName, attributes[STMPersistingKeyPrimary]);
            })
            .catch(^(NSError *error){
                NSLog(@"thumbnail set %@ id: %@ error:",entityName, attributes[STMPersistingKeyPrimary], [error localizedDescription]);
            });
            //---------
            
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
                NSLog(@"this should not happened, was used earlier to convert image's paths from absolute to relative");
                
            }
            
        }
        
    }
    
}


#pragma mark - check Broken & Uploaded Photos

- (void)checkBrokenPhotos {
    
    NSPredicate *anyNilPaths = [NSPredicate predicateWithFormat:@"thumbnailPath == nil OR imagePath == nil OR resizedImagePath == nil"];
    
    BOOL foundSomeBroken = NO;
    
    NSString *picturesBasePath = [self.filing picturesBasePath];
    
    for (NSDictionary *picture in [self allPicturesWithPredicate:anyNilPaths]) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        NSString *xid = attributes[STMPersistingKeyPrimary];
        NSString *resizedFileName = [entityName stringByAppendingPathComponent:[@[@"resized_", xid, @".jpg"] componentsJoinedByString:@""]];
        NSString *thumbnailFileName = [entityName stringByAppendingPathComponent:[@[@"thumbnail_", xid, @".jpg"] componentsJoinedByString:@""]];
        
        // we don't check picturesBasePath/entityName is exist here ?
        NSString *resizedImagePath = [picturesBasePath stringByAppendingPathComponent:resizedFileName];
        NSString *thumbnailPath = [picturesBasePath stringByAppendingPathComponent:thumbnailFileName];
        
        NSError *error;
        
        NSMutableArray *fieldsToUpdate = @[].mutableCopy;
        
        NSMutableDictionary *mutAttributes = attributes.mutableCopy;
        
        if ([self.filing fileExistsAtPath:resizedImagePath] &&
            [STMFunctions isNull:mutAttributes[@"resizedImagePath"]]) {
            
            mutAttributes[@"resizedImagePath"] = resizedFileName;
            [fieldsToUpdate addObject:@"resizedImagePath"];
            
            mutAttributes[@"imagePath"] = resizedFileName;
            [fieldsToUpdate addObject:@"imagePath"];
            
        }
        
        if ([self.filing fileExistsAtPath:thumbnailPath] &&
            [STMFunctions isNull:mutAttributes[@"thumbnailPath"]]) {
            
            mutAttributes[@"thumbnailPath"] = thumbnailFileName;
            
            [fieldsToUpdate addObject:@"thumbnailPath"];
            
        }
        
        if (fieldsToUpdate.count > 0){
            
            foundSomeBroken = YES;
            
            NSString *fieldsToUpdateMessage = [NSString stringWithFormat:@"broken photo fieldsToUpdate id = %@", attributes[STMPersistingKeyPrimary]];
            
            [self.logger importantMessage:fieldsToUpdateMessage];
            
            NSDictionary *options = @{STMPersistingOptionSetTs          :   @NO,
                                      STMPersistingOptionFieldstoUpdate :   fieldsToUpdate.copy};

            attributes = [self.persistenceDelegate updateSync:entityName
                                                   attributes:mutAttributes.copy
                                                      options:options
                                                        error:&error];
            
            if (error) {
                NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos error: %@", error.localizedDescription];
                [self.logger errorMessage:logMessage];
                continue;
            }
            
            NSString *href = attributes[@"href"];
            
            [self.hrefDictionary removeObjectForKey:href];
            
            if ([STMFunctions isNotNull:attributes[@"imagePath"]] &&
                [STMFunctions isNotNull:attributes[@"resizedImagePath"]] &&
                [STMFunctions isNotNull:attributes[@"thumbnailPath"]]) {
                
                continue;
                
            }
            
        }
        
        if ([STMFunctions isNull:attributes[@"imagePath"]]) {
            
            if ([STMFunctions isNotNull:attributes[@"href"]]) {
                
                [self hrefProcessingForObject:picture];
            } else if ([STMFunctions isNotNull:picture[@"thumbnailHref"]]) {

                NSString *logMessage = [NSString stringWithFormat:@"Broken picture with thumbnailHref id = '%@'", picture[STMPersistingKeyPrimary]];
                [self.logger errorMessage:logMessage];
                
                continue;
                
            } else {
                
                foundSomeBroken = YES;
                NSString *logMessage = [NSString stringWithFormat:@"picture %@ have no both imagePath and href", picture];
                [self.logger errorMessage:logMessage];
                [self deletePicture:picture];
                
            }
            
            continue;
            
        }
        
        if ([STMFunctions isNotNull:attributes[@"thumbnailPath"]]){
            continue;
        }
            
        NSString *path = [picturesBasePath stringByAppendingPathComponent:attributes[@"imagePath"]];
        
        // what will happend if we don't have @"imagePath"?
        // photoData will try to load picturesBasePath — we should have an error
        
        if ([STMFunctions isNull:attributes[@"imagePath"]]) {
            NSLog(@"imagePath isNull, something wrong should happened further");
        }
        
        unsigned long long fileSize = [self.filing fileSizeAtPath:path];
        
        if (fileSize > 0) {
            
            error = nil;
            
            NSString *logFileSizeButNoPaths = [NSString stringWithFormat:@"broken photo id = %@ size: %llu", attributes[STMPersistingKeyPrimary], fileSize];
            
            [self.logger importantMessage:logFileSizeButNoPaths];
            
            NSData *photoData = [NSData dataWithContentsOfFile:path options:0 error:&error];
            
            if (error) {
                
                NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos dataWithContentsOfFile %@ error: %@", attributes[@"imagePath"], error.localizedDescription];
            
                [self.logger errorMessage:logMessage];
                
                continue;
                
            }
            
            foundSomeBroken = YES;
            
            attributes = [self setImagesFromData:photoData forPicture:attributes withEntityName:entityName];
            
            if (!attributes) {
                NSString *cantResizeImage = [NSString stringWithFormat:@"can't resize - delete image path %@", path];
                [self.logger importantMessage:cantResizeImage];
                [self.filing removeItemAtPath:path error:&error];
                continue;
            }
            
            NSArray *fields = @[@"resizedImagePath",
                                @"thumbnailPath",
                                @"imagePath"];
            
            [self.persistenceDelegate updateAsync:entityName attributes:attributes options:@{STMPersistingOptionSetTs:@NO,STMPersistingOptionFieldstoUpdate:fields} completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
                
                [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_WAS_DOWNLOADED
                                            userInfo:[STMFunctions setValue:result
                                                                     forKey:@"attributes"
                                                               inDictionary:picture]];
                
            }];
            
        } else if ([STMFunctions isNotNull:attributes[@"href"]]) {
            
            // are we already do it earlier in line 367?
            // in if ([STMFunctions isNull:attributes[@"imagePath"]]){
            //       if ([STMFunctions isNotNull:attributes[@"href"]]) {
            
            [self hrefProcessingForObject:picture];
            
        } else {
            
            foundSomeBroken = YES;
            NSString *logMessage = [NSString stringWithFormat:@"checkBrokenPhotos attempt to set images for picture %@, length %llu, have no photoData and have no href, will be deleted", picture, fileSize];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
            
            [self deletePicture:picture];
            
        }

    }
    
    if (foundSomeBroken) {
        [self.logger importantMessage:@"checkBrokenPhotos found some broken"];
        [self postAsyncMainQueueNotification:NOTIFICATION_PICTURE_UNUSED_CHANGE];
    }
    
}

- (void)checkNotUploadedPhotos {

    NSLogMethodName;
    
    NSUInteger counter = 0;

    NSPredicate *notUploaded = [NSPredicate predicateWithFormat:@"href == nil"];
    
    NSString *picturesBasePath = [self.filing picturesBasePath];
    
    for (NSDictionary *picture in [self allPicturesWithPredicate:notUploaded].copy) {
        
        NSString *entityName = picture[@"entityName"];
        NSDictionary *attributes = picture[@"attributes"];
        
        if ([STMFunctions isNull:attributes[@"imagePath"]]) continue;
            
        NSError *error = nil;
        NSString *path = [picturesBasePath stringByAppendingPathComponent:attributes[@"imagePath"]];
        NSData *imageData = [NSData dataWithContentsOfFile:path options:0 error:&error];
        
        if (imageData && imageData.length > 0) {
            
            [self uploadImageEntityName:entityName attributes:attributes data:imageData];
            counter++;
            
            continue;
            
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
    NSDictionary *attributes = object[@"attributes"];
    NSString *href = attributes[@"href"];
    
    if (![STMFunctions isNotNull:href]) return;
        
    if (![self.pictureEntitiesNames containsObject:entityName]) return;
    
    if (self.hrefDictionary[href]) return;
        
    self.hrefDictionary[href] = object;
    
    if ([self.instantLoadEntityNames containsObject:entityName]) {
        [self downloadImagesEntityName:entityName attributes:attributes];
    }

}

- (NSDictionary *)setImagesFromData:(NSData *)data forPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName{
    
    NSString *xid = picture[STMPersistingKeyPrimary];
    NSString *fileName = [xid stringByAppendingString:@".jpg"];
        
    BOOL result = YES;
    NSMutableDictionary *mutablePicture = picture.mutableCopy;
    
    NSLog(@"saveResized: %@", fileName);
    
    NSData *resizedData = [self saveResizedImageFile:[@"resized_" stringByAppendingString:fileName] forPicture:mutablePicture fromImageData:data withEntityName:entityName];
    
    result = !!resizedData;
    
    NSLog(@"saveThumbnail: %@", fileName);
    
    result = result && [self saveThumbnailImageFile:[@"thumbnail_" stringByAppendingString:fileName] forPicture:mutablePicture fromImageData:data withEntityName:entityName];
    
    if (!result) {
        NSString *logMessage = [NSString stringWithFormat:@"have problem while save image files %@", fileName];
        [[STMLogger sharedLogger] errorMessage:logMessage];
        return nil;
    }
    
    mutablePicture[@"imagePath"] = mutablePicture[@"resizedImagePath"];
    
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
    
    if (!image) {
        return nil;
    }
    
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

- (UIImage *)imageFileForPrimaryKey:(NSString *)idendtifier{
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ == %@", STMPersistingKeyPrimary, idendtifier];
    
    NSDictionary *picture = [self allPicturesWithPredicate:predicate].firstObject;
    
    if (!picture){
        return nil;
    }
    
    NSString *path = picture[@"attributes"][@"imagePath"];
    
    if ([STMFunctions isNull:path]){
    
        return nil;
        
    }
    
    NSString *imagePath = [[self.filing picturesBasePath] stringByAppendingPathComponent:picture[@"attributes"][@"imagePath"]];
    
    if ([self.filing fileExistsAtPath:imagePath]) {
        
        return [UIImage imageWithContentsOfFile:imagePath];
        
    }
    
    return nil;
    
}

- (AnyPromise *)loadImageForPrimaryKey:(NSString *)idendtifier{

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ == %@", STMPersistingKeyPrimary, idendtifier];
    
    NSDictionary *picture = [self allPicturesWithPredicate:predicate].firstObject;
    
    if (!picture){
        return nil;
    }
    
    NSDictionary *attributes = picture[@"attributes"];
    NSString *entityName = picture[@"entityName"];
    
    return [self downloadImagesEntityName:entityName attributes:attributes];

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
        
        if ([STMFunctions isNotNull:attributes[@"imagePath"]]) {
            
            if ([STMFunctions isNotNull:href]){
                [self didProcessHref:href];
            }
            
            return resolve(attributes);
        }
        
        if (![STMFunctions isNotNull:href] || ![self.pictureEntitiesNames containsObject:entityName]) {
            return resolve([STMFunctions errorWithMessage:@"no href or not a Picture"]);
        }
        
        NSURL *url = [NSURL URLWithString:href];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        NSLog(@"start: %@", href);
        
        [NSURLConnection sendAsynchronousRequest:request queue:self.downloadQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            [self didProcessHref:href];
            
            if (connectionError) return resolve(connectionError);
                
            NSDictionary *pictureWithPaths = [self setImagesFromData:data forPicture:attributes withEntityName:entityName].mutableCopy;
            
            NSArray *attributesToUpdate = @[@"imagePath", @"resizedImagePath", @"thumbnailPath"];
            
            NSDictionary *options = @{
                                      STMPersistingOptionFieldstoUpdate: attributesToUpdate,
                                      STMPersistingOptionSetTs: @NO
                                      };
            
            resolve([self.persistenceDelegate update:entityName attributes:pictureWithPaths options:options]);

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
    
    [NSURLConnection sendAsynchronousRequest:request queue:self.uploadQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

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
        
        if (!picturesDicts) {
            NSLog(@"error in json serialization: %@", localError.localizedDescription);
            return;
        }
        
        NSMutableDictionary *picture = attributes.mutableCopy;
        
        for (NSDictionary *dict in picturesDicts){
            if ([dict[@"name"] isEqual:@"original"]){
                picture[@"href"] = dict[@"src"];
            }
        }
        
        picture[@"picturesInfo"] = picturesDicts;
        
        NSLog(@"%@", picture[@"picturesInfo"]);
        
        NSString *imagePath = picture[@"imagePath"];
        
        picture[@"imagePath"] = picture[@"resizedImagePath"];
        
        NSDictionary *fieldstoUpdate = @{STMPersistingOptionFieldstoUpdate:@[@"href", @"picturesInfo", @"imagePath"]};
        
        [self.persistenceDelegate updateAsync:entityName attributes:picture options:fieldstoUpdate completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {
            
            if (!error && result) {
                
                [self removeImageFile:imagePath withEntityName:entityName];
                
            }
            
            if (error){
                NSString *logMessage = [NSString stringWithFormat:@"Error on update after upload: %@", [error localizedDescription]];
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
            }
            
            if (!result){
                
                NSString *logMessage = @"No update result after upload";
                [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];
                
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
    NSDictionary *options = @{
                              STMPersistingOptionRecordstatuses:@(NO)
                              };

    [self.persistenceDelegate destroySync:entityName
                               identifier:attributes[@"id"]
                                  options:options
                                    error:&error];
    
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
