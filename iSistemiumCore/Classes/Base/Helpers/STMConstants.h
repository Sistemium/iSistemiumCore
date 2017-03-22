//
//  STMConstants.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 04/08/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#ifndef iSistemium_STMConstants_h
#define iSistemium_STMConstants_h

#define ISISTEMIUM_PREFIX @"STM"

#define MAIN_MAGIC_NUMBER 17

#define ACTIVE_BLUE_COLOR [UIColor colorWithRed:0 green:0.478431 blue:1 alpha:1]
#define GREY_LINE_COLOR [UIColor colorWithRed:0.785 green:0.78 blue:0.8 alpha:1]
#define STM_LIGHT_BLUE_COLOR [UIColor colorWithRed:0.56 green:0.77 blue:1 alpha:1]
#define STM_SUPERLIGHT_BLUE_COLOR [UIColor colorWithRed:0.92 green:0.96 blue:1 alpha:1]
#define STM_YELLOW_COLOR [UIColor colorWithRed:1 green:0.98 blue:0 alpha:1]
#define STM_LIGHT_LIGHT_GREY_COLOR [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1]
#define STM_DARK_GREEN_COLOR [UIColor colorWithRed:0 green:0.7 blue:0.2 alpha:1]

#define STM_SECTION_HEADER_COLOR [UIColor colorWithRed:239.0/255 green:239.0/255 blue:244.0/255 alpha:1.0];

#define TICK NSDate *startTime = [NSDate date]
#define TOCK NSLog(@"ElapsedTime: %f", -[startTime timeIntervalSinceNow])

#define CURRENT_TIMESTAMP NSLog(@"%@", @([[NSDate date] timeIntervalSinceReferenceDate]))

#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define CurrentMethodName [NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)]
#define NSLogMethodName NSLog(@"%@", NSStringFromSelector(_cmd))

#define BUNDLE_DISPLAY_NAME [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
#define BUILD_VERSION [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]
#define APP_VERSION [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
#define SYSTEM_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]

#define MAGIC_NUMBER_FOR_CELL_WIDTH 0 //16

#define TOOLBAR_HEIGHT 44
#define PICKERVIEW_ROW_HEIGHT 32

#define GEOTRACKER_CONTROL_SHIPMENT_ROUTE @"ShipmentRoute"

#define DATE_FORMAT_WITH_MILLISECONDS @"yyyy-MM-dd HH:mm:ss.SSS"
#define DATE_FORMAT_WITHOUT_TIME @"yyyy-MM-dd"

//#define DATA_CACHE_PATH @"dataCache"
//#define IMAGES_CACHE_PATH @"images"

#define RELATIONSHIP_SUFFIX @"Id"

// Notification's names

#define NOTIFICATION_SYNCER_INIT_SUCCESSFULLY @"Syncer init successfully"

#define NOTIFICATION_SYNCER_RECEIVE_STARTED @"receiveStarted"
#define NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED @"bunchOfObjectsReceived"
#define NOTIFICATION_SYNCER_RECEIVE_FINISHED @"receiveFinished"
#define NOTIFICATION_SYNCER_RECEIVED_ENTITIES @"entitiesReceivingDidFinish"

#define NOTIFICATION_SYNCER_SEND_STARTED @"sendStarted"
//#define NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENT @"bunchOfObjectsSent"
#define NOTIFICATION_SYNCER_SEND_FINISHED @"sendFinished"

#define NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE @"entityCountdownChange"

#define NOTIFICATION_SOCKET_AUTHORIZATION_SUCCESS @"socketAuthorizationSuccess"

#define NOTIFICATION_SESSION_STATUS_CHANGED @"sessionStatusChanged"
#define NOTIFICATION_SESSION_REMOVED @"sessionRemoved"

#define NOTIFICATION_PICTURE_WAS_DOWNLOADED @"pictureWasDownloaded"
#define NOTIFICATION_PICTURE_DOWNLOAD_ERROR @"pictureDownloadError"
#define NOTIFICATION_PICTURE_UNUSED_CHANGE @"unusedImagesDidChange"

#define NOTIFICATION_DEFANTOMIZING_START @"defantomizingStart"
#define NOTIFICATION_DEFANTOMIZING_UPDATE @"defantomizingUpdate"
#define NOTIFICATION_DEFANTOMIZING_FINISH @"defantomizingFinish"

#define NOTIFICATION_DOCUMENT_READY @"documentReady"
#define NOTIFICATION_DOCUMENT_NOT_READY @"documentNotReady"
#define NOTIFICATION_DOCUMENT_SAVE_SUCCESSFULLY @"documentSavedSuccessfully"

#define NOTIFICATION_NEW_VERSION_AVAILABLE @"newAppVersionAvailable"

#define RINGING_LOCAL_NOTIFICATION @"ringingLocalNotification"


//

#define MAX_CODES_PER_BATCH 1

#define FREE_SPACE_PRECISION_MiB 200
#define FREE_SPACE_THRESHOLD 500

// Script message's names

#define WK_MESSAGE_ERROR_CATCHER @"errorCatcher"
#define WK_MESSAGE_POST @"post"
#define WK_MESSAGE_GET @"get"
#define WK_MESSAGE_SCANNER_ON @"barCodeScannerOn"
#define WK_MESSAGE_FIND_ALL @"findAll"
#define WK_MESSAGE_FIND @"find"
#define WK_MESSAGE_UPDATE @"update"
#define WK_MESSAGE_UPDATE_ALL @"updateAll"
#define WK_MESSAGE_DESTROY @"destroy"
#define WK_MESSAGE_SOUND @"sound"
#define WK_MESSAGE_TABBAR @"tabbar"
#define WK_MESSAGE_SUBSCRIBE @"subscribe"
#define WK_MESSAGE_REMOTE_CONTROL @"remoteControl"
#define WK_MESSAGE_ROLES @"roles"
#define WK_MESSAGE_CHECKIN @"checkin"
#define WK_MESSAGE_GET_PICTURE @"getPicture"
#define WK_MESSAGE_TAKE_PHOTO @"takePhoto"

#define WK_SCRIPT_MESSAGE_NAMES @[WK_MESSAGE_ERROR_CATCHER, WK_MESSAGE_POST, WK_MESSAGE_GET, WK_MESSAGE_SCANNER_ON, WK_MESSAGE_FIND_ALL, WK_MESSAGE_FIND, WK_MESSAGE_UPDATE, WK_MESSAGE_UPDATE_ALL, WK_MESSAGE_DESTROY, WK_MESSAGE_SOUND, WK_MESSAGE_TABBAR, WK_MESSAGE_SUBSCRIBE, WK_MESSAGE_REMOTE_CONTROL, WK_MESSAGE_ROLES, WK_MESSAGE_CHECKIN, WK_MESSAGE_GET_PICTURE, WK_MESSAGE_TAKE_PHOTO]


#endif
