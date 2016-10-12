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


static NSString *kSocketFindAllMethod = @"findAll";
static NSString *kSocketFindMethod = @"find";
static NSString *kSocketUpdateMethod = @"update";
static NSString *kSocketDestroyMethod = @"destroy";


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


@interface STMSocketController : NSObject

+ (STMSocketController *)sharedInstance;

+ (void)startSocketWithUrl:(NSString *)socketUrlString
         andEntityResource:(NSString *)entityResource;

+ (void)checkSocket;
+ (void)startSocket;
+ (void)closeSocket;
+ (void)reconnectSocket;

+ (SocketIOClientStatus)currentSocketStatus;
+ (BOOL)socketIsAvailable;
+ (BOOL)isSendingData;

+ (void)reloadResultsControllers;

+ (NSArray <STMDatum *> *)unsyncedObjects;
+ (NSUInteger)numbersOfUnsyncedObjects;

+ (void)sendEvent:(STMSocketEvent)event withValue:(id)value;
+ (void)sendUnsyncedObjects:(id)sender withTimeout:(NSTimeInterval)timeout;

+ (NSDate *)deviceTsForSyncedObjectXid:(NSData *)xid;

+ (void)successfullySyncObjectWithXid:(NSData *)xid;
+ (void)unsuccessfullySyncObjectWithXid:(NSData *)xid
                            errorString:(NSString *)errorString
                              abortSync:(BOOL)abortSync;

+ (void)startReceiveDataFromResource:(NSString *)resourceString
                            withETag:(NSString *)eTag
                          fetchLimit:(NSInteger)fetchLimit
                          andTimeout:(NSTimeInterval)timeout;

+ (void)checkNewsWithFetchLimit:(NSInteger)fetchLimit
                     andTimeout:(NSTimeInterval)timeout;

+ (NSString *)newsResourceString;

+ (void)receiveFinishedWithError:(NSString *)errorString;

+ (void)sendFantomFindEventToResource:(NSString *)resource
                              withXid:(NSString *)xidString
                           andTimeout:(NSTimeInterval)timeout;

- (void)closeSocketInBackground;


@end
