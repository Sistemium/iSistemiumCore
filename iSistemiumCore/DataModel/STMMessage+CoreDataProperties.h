//
//  STMMessage+CoreDataProperties.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "STMMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMMessage (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *body;
@property (nullable, nonatomic, retain) NSString *commentText;
@property (nullable, nonatomic, retain) NSDate *cts;
@property (nullable, nonatomic, retain) NSDate *deviceCts;
@property (nullable, nonatomic, retain) NSDate *deviceTs;
@property (nullable, nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, retain) NSNumber *isFantom;
@property (nullable, nonatomic, retain) NSDate *lts;
@property (nullable, nonatomic, retain) NSData *ownerXid;
@property (nullable, nonatomic, retain) NSString *processing;
@property (nullable, nonatomic, retain) NSString *processingMessage;
@property (nullable, nonatomic, retain) NSString *schedule;
@property (nullable, nonatomic, retain) NSNumber *showOnEnterForeground;
@property (nullable, nonatomic, retain) NSString *source;
@property (nullable, nonatomic, retain) NSDate *sqts;
@property (nullable, nonatomic, retain) NSDate *sts;
@property (nullable, nonatomic, retain) NSString *subject;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, retain) NSSet<STMMessagePicture *> *pictures;
@property (nullable, nonatomic, retain) STMWorkflow *workflow;

@end

@interface STMMessage (CoreDataGeneratedAccessors)

- (void)addPicturesObject:(STMMessagePicture *)value;
- (void)removePicturesObject:(STMMessagePicture *)value;
- (void)addPictures:(NSSet<STMMessagePicture *> *)values;
- (void)removePictures:(NSSet<STMMessagePicture *> *)values;

@end

NS_ASSUME_NONNULL_END
