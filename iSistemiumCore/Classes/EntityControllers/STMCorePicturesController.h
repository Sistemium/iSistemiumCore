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
@property (nonatomic, readonly) NSUInteger nonloadedPicturesCount;
@property (nonatomic, weak) id <STMFiling> filing;

+ (STMCorePicturesController *)sharedController;

- (NSArray *)allPictures;

- (CGFloat)jpgQuality;

+ (void)checkNotUploadedPhotos;

- (void)checkPhotos;

- (void)hrefProcessingForObject:(NSDictionary *)object;

- (NSDictionary *)setImagesFromData:(NSData *)data forPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName;

- (AnyPromise *)downloadImagesEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes;

- (void)uploadImageEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes data:(NSData *)data;

- (NSData *)saveImageFile:(NSString *)fileName forPicture:(NSMutableDictionary *)picture fromImageData:(NSData *)data withEntityName:(NSString *)entityName;

- (UIImage *)imageFileForPrimaryKey:(NSString *)identifier;

- (AnyPromise *)loadImageForPrimaryKey:(NSString *)identifier;

@end
