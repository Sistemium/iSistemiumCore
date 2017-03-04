//
//  STMJson.h
//  iSistemiumCore
//
//  Created by Maxim Grigoriev on 25/05/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMDatum.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMJson : STMDatum

- (NSString *)validJSONString;
- (id)validJSONObject;


@end

NS_ASSUME_NONNULL_END

#import "STMJson+CoreDataProperties.h"
