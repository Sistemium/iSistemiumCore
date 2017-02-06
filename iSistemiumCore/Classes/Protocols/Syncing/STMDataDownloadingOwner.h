//
//  STMDataDownloadingOwner.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 05/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol STMDataDownloadingOwner <NSObject>

- (void)receiveData:(NSString *)entityName
             offset:(NSString *)offset
           pageSize:(NSUInteger)pageSize;

- (BOOL)downloadingTransportIsReady;

- (void)entitiesWasUpdated;
- (void)dataDownloadingFinished;


@end
