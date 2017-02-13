//
//  STMDataDownloading.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataDownloadingOwner.h"
#import "STMDataSyncingState.h"


@protocol STMDataDownloading <NSObject>

@property (nonatomic, strong) id <STMDataSyncingState> downloadingState;
@property (nonatomic, weak) id <STMDataDownloadingOwner> dataDownloadingOwner;
@property (nonatomic, strong) NSArray *receivingEntitiesNames;
@property (nonatomic, strong) NSMutableDictionary *stcEntities;

- (void)startDownloading;
- (void)stopDownloading:(NSString *)stopMessage;

- (void)dataReceivedSuccessfully:(BOOL)success
                      entityName:(NSString *)entityName
                          result:(NSArray *)result
                          offset:(NSString *)offset
                        pageSize:(NSUInteger)pageSize
                           error:(NSError *)error;


@end
