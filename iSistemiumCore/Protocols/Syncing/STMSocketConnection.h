//
//  STMSocketConnection.h
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSocketConnectionOwner.h"

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

@protocol STMSocketConnection <NSObject>

@property (nonatomic, weak) id <STMSocketConnectionOwner> owner;
@property (nonatomic) BOOL isReady;

- (void)closeSocketInBackground;
- (void)checkSocket;

- (void)socketSendEvent:(STMSocketEvent)event
              withValue:(id)value;

- (void)socketSendEvent:(STMSocketEvent)event
              withValue:(id)value
      completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler;

@end
