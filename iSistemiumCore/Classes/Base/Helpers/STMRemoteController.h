//
//  STMRemoteController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMRemoteController : NSObject

+ (void)receiveRemoteCommands:(NSDictionary *)remoteCommands;

+ (BOOL)receiveRemoteCommands:(NSDictionary *)remoteCommands
                        error:(NSError **)error;

+ (NSDictionary *)receiveRemoteRequests:(NSDictionary *)remoteRequests;

@end
