//
//  STMCoreLocation+CoreDataProperties.h
//  iSistemiumCore
//
//  Created by Maxim Grigoriev on 13/06/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "STMCoreLocation.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMCoreLocation (CoreDataProperties)

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
@property (nullable, nonatomic, retain) NSString *target;
@property (nullable, nonatomic, retain) NSDate *timestamp;
@property (nullable, nonatomic, retain) NSDecimalNumber *verticalAccuracy;
@property (nullable, nonatomic, retain) NSData *xid;
@property (nullable, nonatomic, retain) NSSet<STMCorePhoto *> *photos;

@end

@interface STMCoreLocation (CoreDataGeneratedAccessors)

- (void)addPhotosObject:(STMCorePhoto *)value;
- (void)removePhotosObject:(STMCorePhoto *)value;
- (void)addPhotos:(NSSet<STMCorePhoto *> *)values;
- (void)removePhotos:(NSSet<STMCorePhoto *> *)values;

@end

NS_ASSUME_NONNULL_END
