//
//  STMSocketConnection.h
//  iSisSales
//
//  Created by Alexander Levin on 02/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSocketConnectionOwner.h"
#import "STMRemoteDataEventHandling.h"

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
    STMSocketEventRemoteRequests,
    STMSocketEventData,
    STMSocketEventJSData,
    STMSocketEventSubscribe,
    STMSocketEventUpdate,
    STMSocketEventUpdateCollection,
    STMSocketEventDestroy
};

@protocol STMSocketConnection <NSObject>

NS_ASSUME_NONNULL_BEGIN

@property (nonatomic, weak, nullable) id <STMSocketConnectionOwner> owner;
@property (nonatomic, weak, nullable) id <STMRemoteDataEventHandling> remoteDataEventHandling;
@property (nonatomic) BOOL isReady;

- (void)closeSocket;

- (void)checkSocket;

- (void)socketSendEvent:(STMSocketEvent)event
              withValue:(id _Nullable)value;

- (void)socketSendEvent:(STMSocketEvent)event
              withValue:(id _Nullable)value
      completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler;

NS_ASSUME_NONNULL_END

@end
