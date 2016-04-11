//
//  STMPicturesController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMController.h"


@interface STMPicturesController : STMController

@property (nonatomic) BOOL downloadingPictures;

+ (STMPicturesController *)sharedController;

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


@end
