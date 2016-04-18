//
//  STMLocation+CoreDataProperties.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 08/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "STMLocation.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMLocation (CoreDataProperties)

@property (nullable, nonatomic, retain) NSDecimalNumber *altitude;
@property (nullable, nonatomic, retain) NSString *commentText;
@property (nullable, nonatomic, retain) NSDecimalNumber *course;
@property (nullable, nonatomic, retain) NSDate *deviceCts;
@property (nullable, nonatomic, retain) NSDate *deviceTs;
@property (nullable, nonatomic, retain) NSDecimalNumber *horizontalAccuracy;
@property (nullable, nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, retain) NSNumber *isFantom;
@property (nullable, nonatomic, retain) NSDate *lastSeenAt;
@property (nullable, nonatomic, retain) NSDecimalNumber *latitude;
@property (nullable, nonatomic, retain) NSDecimalNumber *longitude;
@property (nullable, nonatomic, retain) NSDate *lts;
@property (nullable, nonatomic, retain) NSData *ownerXid;
@property (nullable, nonatomic, retain) NSString *source;
@property (nullable, nonatomic, retain) NSDecimalNumber *speed;
@property (nullable, nonatomic, retain) NSDate *sqts;
@property (nullable, nonatomic, retain) NSDate *sts;
@property (nullable, nonatomic, retain) NSDate *timestamp;
@property (nullable, nonatomic, retain) NSDecimalNumber *verticalAccuracy;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, retain) NSSet<STMPhoto *> *photos;

@end

@interface STMLocation (CoreDataGeneratedAccessors)

- (void)addPhotosObject:(STMPhoto *)value;
- (void)removePhotosObject:(STMPhoto *)value;
- (void)addPhotos:(NSSet<STMPhoto *> *)values;
- (void)removePhotos:(NSSet<STMPhoto *> *)values;

@end

NS_ASSUME_NONNULL_END
