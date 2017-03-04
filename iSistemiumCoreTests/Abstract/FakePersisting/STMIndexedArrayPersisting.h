//
//  STMIndexedArrayPersisting.h
//  iSisSales
//
//  Created by Alexander Levin on 06/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMIndexedArray.h"
#import "STMPersisting.h"

@interface STMIndexedArrayPersisting : STMIndexedArray

- (NSDictionary *)addObject:(NSDictionary *)anObject
                    options:(STMPersistingOptions)options;

- (NSArray <NSDictionary*> *)addObjectsFromArray:(NSArray <NSDictionary*> *)array
                                         options:(STMPersistingOptions)options;

@end
