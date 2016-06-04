//
//  STMSocketController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/10/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "iSistemiumCore-Swift.h"


typedef NS_ENUM(NSInteger, STMSocketEvent) {
    STMSocketEventConnect,
    STMSocketEventDisconnect,
    STMSocketEventReconnect,
    STMSocketEventStatusChange,
    STMSocketEventInfo,
    STMSocketEventAuthorization,
    STMSocketEventRemoteCommands,
    STMSocketEventData,
    STMSocketEventJSData
};


@interface STMSocketController : NSObject

+ (void)startSocketWithUrl:(NSString *)socketUrlString
         andEntityResource:(NSString *)entityResource;

+ (void)startSocket;
+ (void)closeSocket;
+ (void)reconnectSocket;

+ (void)reloadResultsControllers;

+ (NSArray *)unsyncedObjects;
+ (NSUInteger)numbersOfUnsyncedObjects;

+ (void)sendEvent:(STMSocketEvent)event withValue:(id)value;
+ (void)sendUnsyncedObjects:(id)sender;

+ (SocketIOClientStatus)currentSocketStatus;
+ (BOOL)socketIsAvailable;
+ (BOOL)isSendingData;

+ (NSDate *)deviceTsForSyncedObjectXid:(NSData *)xid;
+ (void)successfullySyncObjectWithXid:(NSData *)xid;

+ (void)startReceiveDataFromResource:(NSString *)resourceString
                            withETag:(NSString *)eTag
                          fetchLimit:(NSInteger)fetchLimit
                          andTimeout:(NSTimeInterval)timeout;

+ (void)checkNewsWithFetchLimit:(NSInteger)fetchLimit
                     andTimeout:(NSTimeInterval)timeout;

+ (NSString *)newsResourceString;


@end
