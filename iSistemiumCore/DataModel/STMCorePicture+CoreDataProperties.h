//
//  STMCorePicture+CoreDataProperties.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCorePicture.h"


NS_ASSUME_NONNULL_BEGIN

@interface STMCorePicture (CoreDataProperties)

+ (NSFetchRequest<STMCorePicture *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *commentText;
@property (nullable, nonatomic, copy) NSDate *deviceCts;
@property (nullable, nonatomic, copy) NSDate *deviceTs;
@property (nullable, nonatomic, copy) NSString *href;
@property (nullable, nonatomic, copy) NSNumber *id;
@property (nullable, nonatomic, copy) NSString *imageFormat;
@property (nullable, nonatomic, copy) NSString *imagePath;
@property (nullable, nonatomic, retain) NSString *thumbnailPath;
@property (nullable, nonatomic, copy) NSNumber *isFantom;
@property (nullable, nonatomic, copy) NSDate *lts;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, retain) NSData *ownerXid;
@property (nullable, nonatomic, copy) NSString *picturesInfo;
@property (nullable, nonatomic, copy) NSString *resizedImagePath;
@property (nullable, nonatomic, copy) NSString *source;
@property (nullable, nonatomic, copy) NSString *target;
@property (nullable, nonatomic, copy) NSString *thumbnailHref;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, copy) NSDate *deviceAts;

@end

NS_ASSUME_NONNULL_END
