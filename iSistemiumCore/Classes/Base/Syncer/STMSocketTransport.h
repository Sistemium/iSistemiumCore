//
//  STMSocketTransport.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreObject.h"
#import "STMSocketConnection.h"

#import "iSistemiumCore-Swift.h"
@import SocketIO;

@interface STMSocketTransport : STMCoreObject <STMSocketConnection>

+ (instancetype)transportWithUrl:(NSString *)socketUrlString
               andEntityResource:(NSString *)entityResource
                           owner:(id <STMSocketConnectionOwner>)owner;

@end
