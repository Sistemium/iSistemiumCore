//
//  STMSocketTransportOwner.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 23/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, STMSocketEvent) {
    STMSocketEventConnect,
    STMSocketEventDisconnect,
    STMSocketEventError,
    STMSocketEventReconnect,
    STMSocketEventReconnectAttempt,
    STMSocketEventStatusChange,
    STMSocketEventInfo,
    STMSocketEventAuthorization,
    STMSocketEventRemoteCommands,
    STMSocketEventData,
    STMSocketEventJSData
};


@protocol STMSocketTransportOwner <NSObject>

- (NSTimeInterval)timeout;
- (void)socketReceiveAuthorization;
- (void)socketLostConnection;


@end
