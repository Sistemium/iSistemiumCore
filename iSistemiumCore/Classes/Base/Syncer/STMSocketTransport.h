//
//  STMSocketTransport.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMSocketTransportOwner.h"
#import "STMPersistingWithHeadersAsync.h"

#import "iSistemiumCore-Swift.h"
@import SocketIO;

static NSString *kSocketFindAllMethod = @"findAll";
static NSString *kSocketFindMethod = @"find";
static NSString *kSocketUpdateMethod = @"update";
static NSString *kSocketDestroyMethod = @"destroy";


@interface STMSocketTransport : NSObject <STMPersistingWithHeadersAsync>

@property (nonatomic) BOOL isReady;

+ (instancetype)initWithUrl:(NSString *)socketUrlString
          andEntityResource:(NSString *)entityResource
                      owner:(id <STMSocketTransportOwner>)owner;

- (void)closeSocketInBackground;
- (void)checkSocket;

- (void)socketSendEvent:(STMSocketEvent)event
              withValue:(id)value;


@end
