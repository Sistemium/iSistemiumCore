//
//  STMLogger.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMSessionManagement.h"

#define MESSAGE_DELAY_TO_CHECK_PATTERN 1


@interface STMLogger : NSObject

+ (STMLogger *)sharedLogger;

@property (nonatomic, weak) id <STMSession> session;

@property (nonatomic) NSUInteger patternDepth;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *lastLogMessagesArray;
@property (nonatomic, strong) NSMutableArray <NSDictionary *> *possiblePatternArray;
@property (nonatomic) BOOL patternDetected;
@property (nonatomic) NSUInteger currentPatternIndex;
@property (nonatomic) NSUInteger patternRepeatCounter;
@property (nonatomic, strong) NSDate *lastLogMessageDate;


@end

#import "STMLogger+Logger.h"
#import "STMLogger+TableView.h"
