//
//  STMEntity.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 30/10/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMDatum.h"

@class STMWorkflow;

NS_ASSUME_NONNULL_BEGIN

@interface STMEntity : STMDatum

- (NSString *)resource;


@end

NS_ASSUME_NONNULL_END

#import "STMEntity+CoreDataProperties.h"
