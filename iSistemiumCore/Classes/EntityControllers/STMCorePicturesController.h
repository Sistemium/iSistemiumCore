//
//  STMCorePicturesController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"


@interface STMCorePicturesController : STMCoreController

@property (nonatomic) BOOL downloadingPictures;

+ (STMCorePicturesController *)sharedController;

- (NSUInteger)nonloadedPicturesCount;

+ (CGFloat)jpgQuality;

+ (void)checkPhotos;
+ (void)checkUploadedPhotos;

+ (void)hrefProcessingForObject:(NSManagedObject *)object;
+ (void)downloadConnectionForObject:(NSManagedObject *)object;
+ (void)downloadConnectionForObjectID:(NSManagedObjectID *)objectID;

+ (void)setImagesFromData:(NSData *)data forPicture:(STMPicture *)picture andUpload:(BOOL)shouldUpload;
+ (void)saveImageFile:(NSString *)fileName forPicture:(STMPicture *)picture fromImageData:(NSData *)data;

+ (void)removeImageFilesForPicture:(STMPicture *)picture;

+ (void)setThumbnailForPicture:(STMPicture *)picture fromImageData:(NSData *)data ;


@end
