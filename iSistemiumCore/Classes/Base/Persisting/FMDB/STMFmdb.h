//
//  STMFmdb.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMModelling.h"
#import "STMModelMapping.h"
#import "STMFiling.h"
#import "STMAdapting.h"

@interface STMFmdb : NSObject<STMAdapting>

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithModelling:(id <STMModelling>)modelling
                           dbPath:(NSString *)dbPath;

- (BOOL)hasTable:(NSString *)name;
- (NSString *)executePatchForCondition:(NSString *)condition
                           patch:(NSString *)patch;

NS_ASSUME_NONNULL_END


@end
