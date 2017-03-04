//
//  STMJson.m
//  iSistemiumCore
//
//  Created by Maxim Grigoriev on 25/05/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMJson.h"

#import "STMFunctions.h"


@implementation STMJson

- (NSString *)validJSONString {
    return [STMFunctions jsonStringFromObject:[self validJSONObject]];
}

- (id)validJSONObject {
    return [STMFunctions jsonObjectFromString:(NSString *)self.data];
}


@end
