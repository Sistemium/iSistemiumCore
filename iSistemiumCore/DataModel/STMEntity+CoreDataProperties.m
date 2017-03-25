//
//  STMEntity+CoreDataProperties.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMEntity.h"

@implementation STMEntity (CoreDataProperties)

+ (NSFetchRequest<STMEntity *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"STMEntity"];
}

@dynamic commentText;
@dynamic deviceCts;
@dynamic deviceTs;
@dynamic eTag;
@dynamic id;
@dynamic isFantom;
@dynamic isResolveFantoms;
@dynamic isUploadable;
@dynamic lifeTime;
@dynamic lifeTimeDateField;
@dynamic lts;
@dynamic name;
@dynamic ownerXid;
@dynamic pictureLifeTime;
@dynamic roleName;
@dynamic roleOwner;
@dynamic source;
@dynamic target;
@dynamic url;
@dynamic workflow;
@dynamic xid;
@dynamic maxPictureScale;
@dynamic wf;

@end
