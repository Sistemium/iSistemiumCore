//
//  STMCoreAuthController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreObject.h"
#import "STMCoreAuth.h"

@interface STMCoreAuthController : STMCoreObject <STMCoreAuth>

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *tokenHash;
@property (nonatomic, strong) NSArray *stcTabs;
@property (nonatomic, strong) NSString *iSisDB;
@property (nonatomic, strong) NSDictionary *rolesResponse;

@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSDate *lastAuth;
@property (nonatomic, strong) NSString *accountOrg;

@property (nonatomic, readwrite) STMAuthState controllerState;

+ (instancetype)sharedAuthController;

- (NSString *)dataModelName;

- (BOOL)sendPhoneNumber:(NSString *)phoneNumber;

- (BOOL)sendSMSCode:(NSString *)SMSCode;

- (BOOL)requestNewSMSCode;

- (BOOL)requestRoles;

- (void)checkPhoneNumber;

@end
