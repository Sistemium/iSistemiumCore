//
//  STMCorePicture+CoreDataProperties.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMCorePicture+CoreDataProperties.h"

@implementation STMCorePicture (CoreDataProperties)

+ (NSFetchRequest<STMCorePicture *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"STMCorePicture"];
}

@dynamic commentText;
@dynamic deviceCts;
@dynamic deviceTs;
@dynamic href;
@dynamic id;
@dynamic imageFormat;
@dynamic imagePath;
@dynamic thumbnailPath;
@dynamic isFantom;
@dynamic lts;
@dynamic name;
@dynamic ownerXid;
@dynamic picturesInfo;
@dynamic resizedImagePath;
@dynamic source;
@dynamic target;
@dynamic thumbnailHref;
@dynamic xid;
@dynamic deviceAts;

@end
