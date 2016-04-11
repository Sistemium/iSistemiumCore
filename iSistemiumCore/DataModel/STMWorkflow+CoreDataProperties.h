//
//  STMWorkflow+CoreDataProperties.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "STMWorkflow.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMWorkflow (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *code;
@property (nullable, nonatomic, retain) NSString *commentText;
@property (nullable, nonatomic, retain) NSDate *deviceCts;
@property (nullable, nonatomic, retain) NSDate *deviceTs;
@property (nullable, nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, retain) NSNumber *isFantom;
@property (nullable, nonatomic, retain) NSDate *lts;
@property (nullable, nonatomic, retain) NSData *ownerXid;
@property (nullable, nonatomic, retain) NSString *source;
@property (nullable, nonatomic, retain) NSDate *sqts;
@property (nullable, nonatomic, retain) NSDate *sts;
@property (nullable, nonatomic, retain) NSString *workflow;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, retain) NSSet<STMEntity *> *entities;
#warning should override
//@property (nullable, nonatomic, retain) NSSet<STMMessage *> *messages;

@end

@interface STMWorkflow (CoreDataGeneratedAccessors)

- (void)addEntitiesObject:(STMEntity *)value;
- (void)removeEntitiesObject:(STMEntity *)value;
- (void)addEntities:(NSSet<STMEntity *> *)values;
- (void)removeEntities:(NSSet<STMEntity *> *)values;

#warning should override
//- (void)addMessagesObject:(STMMessage *)value;
//- (void)removeMessagesObject:(STMMessage *)value;
//- (void)addMessages:(NSSet<STMMessage *> *)values;
//- (void)removeMessages:(NSSet<STMMessage *> *)values;

@end

NS_ASSUME_NONNULL_END
