//
//  STMSyncer+RemoteData.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 10/07/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSyncer+RemoteData.h"

@implementation STMSyncer (RemoteData)

- (void)remoteHasNewData:(NSString *)entityName{
    
    [self receiveEntities:@[entityName]];
    
}

- (void)remoteUpdated:(NSString *)entityName attributes:(NSDictionary *)attributes{
    
    NSError *error = nil;
    
    NSDictionary *options = @{STMPersistingOptionLtsNow};
    
    [self.persistenceDelegate mergeSync:entityName attributes:attributes options:options error:&error];
    
    if (error){
        
        NSString *errorMessage = [NSString stringWithFormat:@"Error update event handle with data: %@", error.localizedDescription];
        
        [self.logger errorMessage:errorMessage];
        
    }
    
}
- (void)remoteDestroyed:(NSString *)entityName identifier:(NSString *)identifier{
    
    NSError *error = nil;
    
    NSDictionary *options = @{STMPersistingOptionRecordstatuses:@NO};
    
    [self.persistenceDelegate destroySync:entityName identifier:identifier options:options error:&error];
    
    if (error){
        
        NSString *errorMessage = [NSString stringWithFormat:@"Error destroy event handle with data: %@", error.localizedDescription];
        
        [self.logger errorMessage:errorMessage];
        
    }
    
}

@end
