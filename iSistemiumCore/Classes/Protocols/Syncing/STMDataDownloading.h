//
//  STMDataDownloading.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMDataDownloadingOwner.h"


@protocol STMDataDownloading <NSObject>

@property (nonatomic, weak) id <STMDataDownloadingOwner> owner;

- (void)startDownloading;
- (void)stopDownloading;

- (void)dataReceivedSuccessfully:(BOOL)success
                      entityName:(NSString *)entityName
                          result:(NSArray *)result
                          offset:(NSString *)offset
                        pageSize:(NSUInteger)pageSize
                           error:(NSError *)error;


@end
