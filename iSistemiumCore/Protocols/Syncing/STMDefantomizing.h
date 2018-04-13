//
//  STMDefantomizing.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 30/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingFantoms.h"

@protocol STMDefantomizingOwner <NSObject>

- (void)defantomizeEntityName:(NSString *)entityName identifier:(NSString *)identifier;

- (void)defantomizingFinished;

@end


@protocol STMDefantomizing <NSObject>

@property (nonatomic, weak) id <STMDefantomizingOwner> defantomizingOwner;
@property (nonatomic, strong) id <STMPersistingFantoms> persistenceFantomsDelegate;

- (void)startDefantomization;

- (void)stopDefantomization;

- (void)defantomizedEntityName:(NSString *)entityName
                    identifier:(NSString *)identifier
                       success:(BOOL)success
                    attributes:(NSDictionary *)attributes
                         error:(NSError *)error;


@end
