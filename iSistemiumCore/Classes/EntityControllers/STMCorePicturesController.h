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

- (void)checkPhotos;

- (void)hrefProcessingForObject:(NSDictionary *)object;

- (NSDictionary *)setImagesFromData:(NSData *)data forPicture:(NSDictionary *)picture withEntityName:(NSString *)entityName andUpload:(BOOL)shouldUpload;

- (AnyPromise *)downloadImagesEntityName:(NSString *)entityName attributes:(NSDictionary *)attributes;

@end
