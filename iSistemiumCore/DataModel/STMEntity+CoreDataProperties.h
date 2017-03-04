//
//  STMEntity+CoreDataProperties.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMEntity.h"


NS_ASSUME_NONNULL_BEGIN

@interface STMEntity (CoreDataProperties)

+ (NSFetchRequest<STMEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *commentText;
@property (nullable, nonatomic, copy) NSDate *deviceCts;
@property (nullable, nonatomic, copy) NSDate *deviceTs;
@property (nullable, nonatomic, copy) NSString *eTag;
@property (nullable, nonatomic, copy) NSNumber *id;
@property (nullable, nonatomic, copy) NSNumber *isFantom;
@property (nullable, nonatomic, copy) NSNumber *isResolveFantoms;
@property (nullable, nonatomic, copy) NSNumber *isUploadable;
@property (nullable, nonatomic, copy) NSNumber *lifeTime;
@property (nullable, nonatomic, copy) NSString *lifeTimeDateField;
@property (nullable, nonatomic, copy) NSDate *lts;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, retain) NSData *ownerXid;
@property (nullable, nonatomic, copy) NSString *roleName;
@property (nullable, nonatomic, copy) NSString *roleOwner;
@property (nullable, nonatomic, copy) NSString *source;
@property (nullable, nonatomic, copy) NSString *target;
@property (nullable, nonatomic, copy) NSString *url;
@property (nullable, nonatomic, copy) NSString *workflow;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, copy) NSNumber *pictureLifeTime;
@property (nullable, nonatomic, retain) STMWorkflow *wf;

@end

NS_ASSUME_NONNULL_END
