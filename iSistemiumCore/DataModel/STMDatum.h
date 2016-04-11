//
//  STMDatum.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/01/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


NS_ASSUME_NONNULL_BEGIN

@interface STMDatum : NSManagedObject

- (NSString *)currentChecksum;
- (NSDictionary *)propertiesForKeys:(NSArray *)keys;
- (NSDictionary *)relationshipXidsForKeys:(NSArray *)keys;


@end

NS_ASSUME_NONNULL_END

#import "STMDatum+CoreDataProperties.h"
