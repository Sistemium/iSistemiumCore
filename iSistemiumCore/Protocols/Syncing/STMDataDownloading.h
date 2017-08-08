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

@property (readonly) id <STMDataSyncingState> downloadingState;
@property (nonatomic, weak) id <STMDataDownloadingOwner> dataDownloadingOwner;

- (id <STMDataSyncingState>)startDownloading;
- (id <STMDataSyncingState>)startDownloading:(NSArray <NSString *> *)entitiesNames;

- (void)stopDownloading;

- (void)dataReceivedSuccessfully:(BOOL)success
                      entityName:(NSString *)entityName
                    dataRecieved:(NSArray *)dataRecieved
                          offset:(NSString *)offset
                        pageSize:(NSUInteger)pageSize
                           error:(NSError *)error;


@end
