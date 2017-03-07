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


@interface STMFmdb : NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithModelMapping:(id <STMModelMapping>)modelMapping
                              filing:(id <STMFiling>)filing
                            fileName:(NSString *)fileName;

- (instancetype)initWithModelling:(id <STMModelling>)modelling
                           filing:(id <STMFiling>)filing
                         fileName:(NSString *)fileName;

- (BOOL)hasTable:(NSString *)name;

- (void)deleteFile;

NS_ASSUME_NONNULL_END


@end
