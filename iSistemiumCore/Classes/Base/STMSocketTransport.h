//
//  STMSocketTransport.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMSyncer.h"

#import "iSistemiumCore-Swift.h"
@import SocketIO;


@interface STMSocketTransport : NSObject

+ (instancetype)initWithUrl:(NSString *)socketUrlString
          andEntityResource:(NSString *)entityResource
                  forSyncer:(STMSyncer *)syncer;


@end
