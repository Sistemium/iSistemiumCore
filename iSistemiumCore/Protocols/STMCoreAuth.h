//
//  STMCoreAuth.h
//  iSistemiumCore
//
//  Created by Alexander Levin on 16/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMRequestAuthenticatable.h"

typedef NS_ENUM(NSUInteger, STMAuthState) {
    STMAuthStarted,
    STMAuthEnterPhoneNumber,
    STMAuthEnterSMSCode,
    STMAuthNewSMSCode,
    STMAuthRequestRoles,
    STMAuthSuccess
};

@protocol STMCoreAuth <STMRequestAuthenticatable>

@property (readonly) NSString *userName;
@property (readonly) NSString *userID;
@property (readonly) NSDate *lastAuth;
@property (readonly) NSString *accountOrg;
@property (readonly) STMAuthState controllerState;

- (void)logout;

@end
