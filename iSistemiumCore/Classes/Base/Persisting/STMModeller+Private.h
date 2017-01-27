//
//  STMModeller+Private.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller.h"

@interface STMModeller (Private)

+ (id)typeConversionForValue:(id)value key:(NSString *)key entityAttributes:(NSDictionary *)entityAttributes;

@end
