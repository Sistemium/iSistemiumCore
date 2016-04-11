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

#define ACTIVE_BLUE_COLOR [UIColor colorWithRed:0 green:0.478431 blue:1 alpha:1]
#define GREY_LINE_COLOR [UIColor colorWithRed:0.785 green:0.78 blue:0.8 alpha:1]
#define STM_LIGHT_BLUE_COLOR [UIColor colorWithRed:0.56 green:0.77 blue:1 alpha:1]
#define STM_SUPERLIGHT_BLUE_COLOR [UIColor colorWithRed:0.92 green:0.96 blue:1 alpha:1]
#define STM_YELLOW_COLOR [UIColor colorWithRed:1 green:0.98 blue:0 alpha:1]
#define STM_LIGHT_LIGHT_GREY_COLOR [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1]
#define STM_DARK_GREEN_COLOR [UIColor colorWithRed:0 green:0.7 blue:0.2 alpha:1]

#define STM_SECTION_HEADER_COLOR [UIColor colorWithRed:239.0/255 green:239.0/255 blue:244.0/255 alpha:1.0];

#define MAX_PICTURE_SIZE 3500.0

#define TICK NSDate *startTime = [NSDate date]
#define TOCK NSLog(@"ElapsedTime: %f", -[startTime timeIntervalSinceNow])

#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define NSLogMethodName NSLog(@"%@", NSStringFromSelector(_cmd))

#define BUILD_VERSION [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]
#define APP_VERSION [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
#define SYSTEM_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]

#define MAGIC_NUMBER_FOR_CELL_WIDTH 0 //16

#define TOOLBAR_HEIGHT 44
#define PICKERVIEW_ROW_HEIGHT 32

#define GEOTRACKER_CONTROL_SHIPMENT_ROUTE @"ShipmentRoute"


// Notification's names

#define NOTIFICATION_SYNCER_GET_BUNCH_OF_OBJECTS @"syncerGetBunchOfObjects"
#define NOTIFICATION_SESSION_STATUS_CHANGED @"sessionStatusChanged"

#define FREE_SPACE_PRECISION_MiB 200
#define FREE_SPACE_THRESHOLD 500

#define RINGING_LOCAL_NOTIFICATION @"ringingLocalNotification"
#define MAX_CODES_PER_BATCH 1

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

#define WK_SCRIPT_MESSAGE_NAMES @[WK_MESSAGE_POST, WK_MESSAGE_GET, WK_MESSAGE_SCANNER_ON, WK_MESSAGE_FIND_ALL, WK_MESSAGE_FIND, WK_MESSAGE_UPDATE, WK_MESSAGE_UPDATE_ALL, WK_MESSAGE_DESTROY, WK_MESSAGE_SOUND, WK_MESSAGE_TABBAR, WK_MESSAGE_SUBSCRIBE]


#endif
