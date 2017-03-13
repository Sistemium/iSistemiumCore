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

#define FMDB_PATH @"fmdb"


@interface STMFmdb : NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithModelling:(id <STMModelling>)modelling
                           filing:(id <STMFiling>)filing
                        modelName:(NSString *)modelName;

- (BOOL)hasTable:(NSString *)name;

- (void)deleteFile;

NS_ASSUME_NONNULL_END


@end
