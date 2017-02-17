//
//  STMModeller+Private.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller.h"

@interface STMModeller()

@property (nonatomic,strong) NSMutableDictionary *allEntitiesCache;
@property (nonatomic,strong) NSMapTable <NSString *, id> *beforeMergeInterceptors;

@end

@interface STMModeller (Private)

+ (id)typeConversionForValue:(id)value
                         key:(NSString *)key
            entityAttributes:(NSDictionary *)entityAttributes;

- (NSDictionary *)dictionaryForJSWithObject:(STMDatum *)object
                                  withNulls:(BOOL)withNulls
                             withBinaryData:(BOOL)withBinaryData;

@end
