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
@property (nonatomic,readonly) NSUInteger nonloadedPicturesCount;

+ (STMCorePicturesController *)sharedController;

+ (NSArray *)allPictures;

+ (CGFloat)jpgQuality;

+ (NSString *)imagesCachePath;

+ (void)checkPhotos;

+ (void)hrefProcessingForObject:(NSDictionary *)object;
+ (void)downloadConnectionForPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName;

+ (void)setImagesFromData:(NSData *)data forPicture:(NSMutableDictionary *)picture withEntityName:(NSString *)entityName andUpload:(BOOL)shouldUpload;
+ (BOOL)saveImageFile:(NSString *)fileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data;

+ (void)removeImageFilesForPicture:(NSDictionary *)picture;

+ (BOOL)setThumbnailForPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data ;

- (AnyPromise *)downloadImagesEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes;

@end
