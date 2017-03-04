//
//  STMEntity+CoreDataClass.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
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
