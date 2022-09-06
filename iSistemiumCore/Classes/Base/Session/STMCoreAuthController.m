//
//  STMCoreAuthController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreAuthController.h"

#import <AdSupport/AdSupport.h>

#import "STMKeychain.h"

#import "STMDevDef.h"
#import "STMFunctions.h"
#import "STMCoreSessionManager.h"
#import "STMLogger.h"
#import "STMUserDefaults.h"

#import "STMClientDataController.h"
#import "iSistemiumCore-Swift.h"


//#import "STMSocketController.h"


#define AUTH_URL @"https://api.sistemium.com/pha/auth"

#define ROLES_URL @"https://api.sistemium.com/pha/roles"

#define VFS_ROLES_URL @"https://oauth.it/api/roles"

#define VFS_SOCKET_URL @"https://socket3.sistemium.com/socket.io-client"

#define TIMEOUT 15.0

#define KC_PHONE_NUMBER @"phoneNumber"
#define KC_ENTITY_RESOURCE @"entityResource"
#define KC_USER_ID @"userID"
#define KC_ACCESS_TOKEN @"accessToken"


@interface STMCoreAuthController () <NSURLConnectionDataDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSString *requestID;

@end


@implementation STMCoreAuthController

@synthesize phoneNumber = _phoneNumber;
@synthesize userID = _userID;
@synthesize userName = _userName;
@synthesize accessToken = _accessToken;
@synthesize entityResource = _entityResource;
@synthesize stcTabs = _stcTabs;
@synthesize iSisDB = _iSisDB;
@synthesize rolesResponse = _rolesResponse;
@synthesize isDemo = _isDemo;


#pragma mark - singletone init

+ (instancetype)sharedAuthController {

    static dispatch_once_t pred = 0;
    __strong static id _authController = nil;

    dispatch_once(&pred, ^{
        _authController = [[self alloc] init];
    });

    return _authController;

}

- (instancetype)init {

    self = [super init];

    if (self) {

        self.controllerState = STMAuthStarted;

    }

    return self;

}

- (STMCoreSessionManager *)sessionManager {
    return [STMCoreSessionManager sharedManager];
}


#pragma mark - variables setters & getters

- (NSString *)phoneNumber {

    if (!_phoneNumber) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        id phoneNumber = [defaults objectForKey:@"phoneNumber"];

        if ([phoneNumber isKindOfClass:[NSString class]]) {
            _phoneNumber = phoneNumber;
            NSLog(@"phoneNumber %@", phoneNumber);
        }

    }

    return _phoneNumber;

}

- (void)setPhoneNumber:(NSString *)phoneNumber {

    if (phoneNumber != _phoneNumber) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:phoneNumber forKey:@"phoneNumber"];
        [defaults synchronize];

        [STMKeychain saveValue:phoneNumber forKey:KC_PHONE_NUMBER];

        _phoneNumber = phoneNumber;

    }

}

- (BOOL)isDemo {

    if (!_isDemo) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        BOOL demo = [defaults boolForKey:@"isDemo"];
        
        _isDemo = demo;

    }

    return _isDemo;

}

- (void)setIsDemo:(BOOL)demo {

    if (_isDemo != demo) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setBool:demo forKey:@"isDemo"];
        [defaults synchronize];

        _isDemo = demo;

    }

}

- (NSString *)userName {

    if (!_userName) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        id userName = [defaults objectForKey:@"userName"];

        if ([userName isKindOfClass:[NSString class]]) {
            _userName = userName;
            NSLog(@"userName %@", userName);
        }

    }

    return _userName;

}

- (void)setUserName:(NSString *)userName {

    if (userName != _userName) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:userName forKey:@"userName"];
        [defaults synchronize];

        _userName = userName;

    }

}

- (void)setControllerState:(STMAuthState)controllerState {

    //    NSLog(@"authControllerState %d", controllerState);
    _controllerState = controllerState;

    NSString *logMessage = [NSString stringWithFormat:@"authController state %@", [self authControllerStateString]];
    [[STMLogger sharedLogger] infoMessage:logMessage];

    if (controllerState == STMAuthRequestRoles) {

        [self requestRoles];

    } else if (controllerState == STMAuthSuccess) {

        UIApplication *app = [UIApplication sharedApplication];
        STMCoreAppDelegate *appDelegate = (STMCoreAppDelegate *) app.delegate;
        [appDelegate setupWindow];

        [[STMLogger sharedLogger] importantMessage:@"login success"];

    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerStateChanged"
                                                        object:self];

}

- (NSString *)authControllerStateString {

    switch (self.controllerState) {
        case STMAuthStarted: {
            return @"STMAuthStarted";
            break;
        }
        case STMAuthEnterPhoneNumber: {
            return @"STMAuthEnterPhoneNumber";
            break;
        }
        case STMAuthEnterSMSCode: {
            return @"STMAuthEnterSMSCode";
            break;
        }
        case STMAuthNewSMSCode: {
            return @"STMAuthNewSMSCode";
            break;
        }
        case STMAuthRequestRoles: {
            return @"STMAuthRequestRoles";
            break;
        }
        case STMAuthSuccess: {
            return @"STMAuthSuccess";
            break;
        }
    }

}

- (NSString *)entityResource {

    if (!_entityResource) {
        _entityResource = [STMKeychain loadValueForKey:KC_ENTITY_RESOURCE];
    }
    return _entityResource;

}

- (void)setEntityResource:(NSString *)entityResource {

    if (entityResource != _entityResource) {

        [STMKeychain saveValue:entityResource forKey:KC_ENTITY_RESOURCE];
        NSLog(@"entityResource %@", entityResource);
        _entityResource = entityResource;

    }

}

- (NSString *)userID {

    if (!_userID) {
        _userID = [STMKeychain loadValueForKey:KC_USER_ID];
    }
    return _userID;

}

- (void)setUserID:(NSString *)userID {

    if (userID != _userID) {

        [STMKeychain saveValue:userID forKey:KC_USER_ID];
        NSLog(@"userID %@", userID);
        _userID = userID;

    }

}

- (NSString *)accessToken {

    if (!_accessToken) {
        _accessToken = [STMKeychain loadValueForKey:KC_ACCESS_TOKEN];
    }
    return _accessToken;

}

- (void)setAccessToken:(NSString *)accessToken {

    if (accessToken != _accessToken) {

        [STMKeychain saveValue:accessToken forKey:KC_ACCESS_TOKEN];
        NSLog(@"accessToken %@", accessToken);
        _accessToken = accessToken;

        self.lastAuth = [NSDate date];
        self.tokenHash = [STMFunctions MD5FromString:accessToken];

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:self.lastAuth forKey:@"lastAuth"];
        [defaults setObject:self.tokenHash forKey:@"tokenHash"];
        [defaults synchronize];

    }

}

- (NSString *)tokenHash {

    if (!_tokenHash) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        NSString *tokenHash = [defaults objectForKey:@"tokenHash"];

        if (!tokenHash) {

            tokenHash = [STMFunctions MD5FromString:self.accessToken];

            if (tokenHash) {

                [defaults setObject:tokenHash forKey:@"tokenHash"];
                [defaults synchronize];

            } else {

                tokenHash = @"tokenHash is empty, should be investigated";

            }

        }

        _tokenHash = tokenHash;

    }

    return _tokenHash;

}

- (NSDate *)lastAuth {

    if (!_lastAuth) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _lastAuth = [defaults objectForKey:@"lastAuth"];

    }

    return _lastAuth;

}

- (NSArray *)stcTabs {

    if (!_stcTabs) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _stcTabs = [defaults objectForKey:@"stcTabs"];

    }
    return _stcTabs;

}

- (void)setStcTabs:(NSArray *)stcTabs {

    if (![stcTabs isEqual:_stcTabs]) {

        _stcTabs = stcTabs;

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:stcTabs forKey:@"stcTabs"];
        [defaults synchronize];

    }

}

- (NSString *)iSisDB {

    if (!_iSisDB) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        id iSisDB = [defaults objectForKey:@"iSisDB"];

        if ([iSisDB isKindOfClass:[NSString class]]) {
            _iSisDB = iSisDB;
            NSLog(@"iSisDB %@", iSisDB);
        }

    }

    return _iSisDB;

}

- (void)setISisDB:(NSString *)iSisDB {

    if (iSisDB != _iSisDB) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:iSisDB forKey:@"iSisDB"];
        [defaults synchronize];

        _iSisDB = iSisDB;

    }

}

- (NSDictionary *)rolesResponse {

    if (!_rolesResponse) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        id rolesResponse = [defaults objectForKey:@"rolesResponse"];

        if ([rolesResponse isKindOfClass:[NSDictionary class]]) {
            _rolesResponse = rolesResponse;
        }

    }
    return _rolesResponse;

}

- (void)setRolesResponse:(NSDictionary *)rolesResponse {

    if (rolesResponse != _rolesResponse) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:rolesResponse forKey:@"rolesResponse"];
        [defaults synchronize];

        _rolesResponse = rolesResponse;

    }

}

- (NSString *)accountOrg {

    if (!_accountOrg) {
        _accountOrg = self.rolesResponse[@"roles"][@"org"];
    }
    return _accountOrg;

}


#pragma mark - instance methods

- (void)checkPhoneNumber {

    [[STMLogger sharedLogger] infoMessage:@"checkPhoneNumber"];

    NSString *keychainPhoneNumber = [STMKeychain loadValueForKey:KC_PHONE_NUMBER];

    if ([self.phoneNumber isEqualToString:keychainPhoneNumber]) {

        [self checkAccessToken];

    } else {

        NSString *logMessage = [NSString stringWithFormat:@"keychainPhoneNumber %@ != userDefaultsPhoneNumber %@", keychainPhoneNumber, self.phoneNumber];
        
        [[STMLogger sharedLogger] errorMessage:logMessage];
        
        self.controllerState = STMAuthEnterPhoneNumber;
        
    }

}


- (void)checkAccessToken {

    [[STMLogger sharedLogger] infoMessage:@"checkAccessToken"];

    BOOL checkValue = YES;

    if (!self.userID || [self.userID isEqualToString:@""]) {

        [[STMLogger sharedLogger] errorMessage:@"No userID or userID is empty string"];
        checkValue = NO;

    } else {
        NSLog(@"userID %@", self.userID);
    }
    if (!self.accessToken || [self.accessToken isEqualToString:@""]) {

        [[STMLogger sharedLogger] errorMessage:@"No accessToken or accessToken is empty string"];
        checkValue = NO;

    } else {
        NSLog(@"accessToken %@", self.accessToken);
    }
    
    if (checkValue){
        self.controllerState = STMAuthRequestRoles;
    } else {
        self.controllerState = STMAuthEnterPhoneNumber;
    }

}

- (void)logout {

    STMCoreSessionManager *sessionManager = [self sessionManager];

    [sessionManager.currentSession.syncer prepareToDestroy];

    [[STMLogger sharedLogger] saveLogMessageWithText:@"logout"
                                             numType:STMLogMessageTypeImportant];

    self.controllerState = STMAuthEnterPhoneNumber;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"notAuthorized"
                                                  object:sessionManager.currentSession.syncer];

    [sessionManager stopSessionForUID:self.userID];

    self.userID = nil;
    self.accessToken = nil;
    self.stcTabs = nil;
    self.iSisDB = nil;
    self.isDemo = false;
    [STMKeychain deleteValueForKey:KC_PHONE_NUMBER];
    [STMCoreRootTBC.sharedRootVC hideTabBar];

}

- (NSString *)dataModelName {

    NSString *dataModelName = @"";

#if defined (CONFIGURATION_DebugSales) || defined (CONFIGURATION_ReleaseSales) || defined (CONFIGURATION_DebugSalesApple) || defined (CONFIGURATION_ReleaseSalesApple)

    NSLog(@"USE SALES DATA MODEL");
    dataModelName = @"iSisSales";

#endif

#if defined (CONFIGURATION_DebugWarehouse) || defined (CONFIGURATION_ReleaseWarehouse) || defined (CONFIGURATION_DebugWarehouseApple) || defined (CONFIGURATION_ReleaseWarehouseApple)

    NSLog(@"USE WAREHOUSE DATA MODEL");
    dataModelName = @"iSisWarehouse";

#endif
    
#if defined (CONFIGURATION_DebugDriver) || defined (CONFIGURATION_ReleaseDriver) || defined (CONFIGURATION_DebugDriverApple) || defined (CONFIGURATION_ReleaseDriverApple)
    
    NSLog(@"USE DRIVER DATA MODEL");
    dataModelName = @"iSisDriver";
    
#endif
    
#if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)
    
    NSLog(@"USE VFS DATA MODEL");
    dataModelName = @"vfs";
    
#endif

    return dataModelName;

}

- (void)startSession {

#if defined CONFIGURATION_DebugWarehouse || CONFIGURATION_DebugShipping

    //    NSLog(@"CONFIGURATION_DebugWarehouse — use local socket");
    //    self.socketURL = @"http://localhost:8000/socket.io-client/";

#endif

    NSLog(@"socketURL %@", self.socketURL);
    NSLog(@"entity resource %@", self.entityResource);

    NSArray *trackers = @[@"battery", @"location"];

    NSDictionary *startSettings = nil;

    NSString *dataModelName = [self dataModelName];

    if (self.entityResource) {

#ifdef DEBUG

        if (GRIMAX) {

            startSettings = @{
                    @"entityResource": self.entityResource,
                    @"dataModelName": dataModelName,
                    //                      @"fetchLimit"               : @"50",
                    //                      @"syncInterval"             : @"600",
                    //                      @"uploadLog.type"           : @"",
                    @"requiredAccuracy": @"100",
                    @"desiredAccuracy": @"10",
                    @"timeFilter": @"60",
                    @"distanceFilter": @"60",
                    @"backgroundDesiredAccuracy": @"3000",
                    @"foregroundDesiredAccuracy": @"10",
                    @"offtimeDesiredAccuracy": @"0",
                    @"maxSpeedThreshold": @"60",
                    @"locationTrackerAutoStart": @YES,
                    @"locationTrackerStartTime": @"0",
                    @"locationTrackerFinishTime": @"24",
                    @"locationWaitingTimeInterval": @"10",
                    @"batteryTrackerAutoStart": @YES,
                    @"batteryTrackerStartTime": @"8.0",
                    @"batteryTrackerFinishTime": @"22.0",
                    @"http.timeout.foreground": @"60",
                    @"jpgQuality": @"0.0",
                    @"blockIfNoLocationPermission": @YES
            };

        } else {

            startSettings = @{@"entityResource": self.entityResource,
                    @"dataModelName": dataModelName//,
//                              @"requestLocationServiceAuthorization": @"requestAlwaysAuthorization",
//                              @"locationTrackerAutoStart": @YES
            };
        }

#else

        startSettings = @{@"entityResource": self.entityResource,
                          @"dataModelName": dataModelName};

#endif

    }

//    self.socketURL = @"http://lamac.local:8000/socket.io-client/";
    
    #if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)
        
        self.socketURL = VFS_SOCKET_URL;
        
    #endif

    if (self.socketURL) {

        self.socketURL = [self.socketURL stringByReplacingOccurrencesOfString:@"//socket."
                                                                   withString:@"//socket-v2."];

        startSettings = [STMFunctions setValue:self.socketURL
                                        forKey:@"socketUrl"
                                  inDictionary:startSettings];

    }

    STMCoreSessionManager *sessionManager = [self sessionManager];

    [sessionManager startSessionWithAuthDelegate:self
                                        trackers:trackers
                                   startSettings:startSettings
                         defaultSettingsFileName:@"settings"];

}


#pragma mark - STMRequestAuthenticatable

- (NSURLRequest *)authenticateRequest:(NSURLRequest *)request {

    NSMutableURLRequest *resultingRequest = nil;

    if (self.accessToken) {

        resultingRequest = [request mutableCopy];
        [resultingRequest addValue:self.accessToken forHTTPHeaderField:@"Authorization"];

        NSString *deviceUUIDString = [STMClientDataController deviceUUID];
        [resultingRequest setValue:deviceUUIDString forHTTPHeaderField:@"DeviceUUID"];

    }

    return resultingRequest;

}


#pragma mark - send requests

- (BOOL)sendPhoneNumber:(NSString *)phoneNumber {

    if ([STMFunctions isCorrectPhoneNumber:phoneNumber]) {

        [STMFunctions setNetworkActivityIndicatorVisible:YES];

        self.phoneNumber = phoneNumber;

        NSString *urlString = [NSString stringWithFormat:@"%@?mobileNumber=%@", AUTH_URL, phoneNumber];
        NSURLRequest *request = [self requestForURL:urlString];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

        if (connection) {

            return YES;

        } else {

            [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError"
                                                                object:self
                                                              userInfo:@{@"error": @"No connection"}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"loginError" arguments:NSLocalizedString(@"NO CONNECTION", nil)];
            });

            [STMFunctions setNetworkActivityIndicatorVisible:NO];

            return NO;

        }

    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
            [channel invokeMethod:@"loginError" arguments:NSLocalizedString(@"WRONG PHONE NUMBER", nil)];
        });
        return NO;
    }

}

- (BOOL)sendSMSCode:(NSString *)SMSCode {

    if ([STMFunctions isCorrectSMSCode:SMSCode]) {

        [STMFunctions setNetworkActivityIndicatorVisible:YES];

        NSString *urlString = [NSString stringWithFormat:@"%@?smsCode=%@&ID=%@", AUTH_URL, SMSCode, self.requestID];
        NSURLRequest *request = [self requestForURL:urlString];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

        if (connection) {

            return YES;

        } else {

            [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError"
                                                                object:self
                                                              userInfo:@{@"error": NSLocalizedString(@"NO CONNECTION", nil)}];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"loginError" arguments:NSLocalizedString(@"NO CONNECTION", nil)];
            });

            [STMFunctions setNetworkActivityIndicatorVisible:NO];

            self.controllerState = STMAuthEnterPhoneNumber;

            return NO;

        }

    } else {
        return NO;
    }

}

- (BOOL)requestNewSMSCode {

    self.controllerState = STMAuthNewSMSCode;
    return [self sendPhoneNumber:self.phoneNumber];

}

- (BOOL)requestRoles {

    [STMFunctions setNetworkActivityIndicatorVisible:YES];

    if (self.stcTabs) {

        self.controllerState = STMAuthSuccess;

        [self startSession];

    }

    NSURLRequest *request = [self authenticateRequest:[self requestForURL:ROLES_URL]];
    
    #if defined (CONFIGURATION_DebugVfs) || defined (CONFIGURATION_ReleaseVfs)
        
        request = [self authenticateRequest:[self requestForURL:VFS_ROLES_URL]];
        
    #endif
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

    if (connection) {

        return YES;

    } else {

        [self connectionErrorWhileRequestingRoles];

        return NO;

    }

    return YES;
}

- (NSURLRequest *)requestForURL:(NSString *)urlString {

    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    NSString *deviceUUIDString = [STMClientDataController deviceUUID];
    [request setValue:deviceUUIDString forHTTPHeaderField:@"DeviceUUID"];

    request.HTTPMethod = @"GET";
    request.timeoutInterval = TIMEOUT;

    return request;

}


#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {

#ifdef DEBUG
    NSString *errorMessage = [NSString stringWithFormat:@"connection did fail with error: %@", error];
    NSLog(@"%@", errorMessage);
#endif

    if (self.controllerState == STMAuthRequestRoles) {

        [self connectionErrorWhileRequestingRoles];

    } else if (self.controllerState == STMAuthSuccess) {


    } else {
                
        dispatch_async(dispatch_get_main_queue(), ^{
            FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
            [channel invokeMethod:@"loginError" arguments:NSLocalizedString(@"NO CONNECTION", nil)];
        });

        [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError"
                                                            object:self
                                                          userInfo:@{@"error": error.localizedDescription}];

        [STMFunctions setNetworkActivityIndicatorVisible:NO];

    }

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {

    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

    switch (statusCode) {
        case 401:
            [self gotUnauthorizedStatus];
            break;

        default:
            self.responseData = [NSMutableData data];
            break;
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {

    [self parseResponse:self.responseData fromConnection:connection];
    [STMFunctions setNetworkActivityIndicatorVisible:NO];
    self.responseData = nil;

}

- (void)gotUnauthorizedStatus {

    if (self.controllerState == STMAuthRequestRoles) {

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil)
                                                                message:NSLocalizedString(@"U R NOT AUTH", nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];

        }];

    }

    [self logout];

}

- (void)connectionErrorWhileRequestingRoles {

    if (self.stcTabs) {

        self.controllerState = STMAuthSuccess;

    } else {

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ERROR", nil)
                                                                message:NSLocalizedString(@"CAN NOT GET ROLES", nil)
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"NO", nil)
                                                      otherButtonTitles:NSLocalizedString(@"YES", nil), nil];
            alertView.tag = 1;
            [alertView show];

        }];

    }

}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {

    switch (alertView.tag) {

        case 1:
            switch (buttonIndex) {

                case 0:
                    [self logout];
                    break;

                case 1:
                    [self requestRoles];
                    break;

                default:
                    break;

            }
            break;

        default:
            break;
    }

}


#pragma mark - parse response

- (void)parseResponse:(NSData *)responseData fromConnection:(NSURLConnection *)connection {

    if (responseData) {

        NSError *error;
        id responseJSON = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];

//        NSLog(@"responseData %@", responseData);
//        NSLog(@"responseJSON %@", responseJSON);

        if ([responseJSON isKindOfClass:[NSDictionary class]]) {

            [self processingResponseJSON:responseJSON];

        } else {

            [self processingResponseJSONError];

        }

    }

}

- (void)processingResponseJSON:(NSDictionary *)responseJSON {

    switch (self.controllerState) {

        case STMAuthEnterPhoneNumber: {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"validPhoneNumber" arguments:nil];
            });
            
            self.requestID = responseJSON[@"ID"];
            self.controllerState = STMAuthEnterSMSCode;
            
            break;

        }

        case STMAuthEnterSMSCode: {

            self.entityResource = responseJSON[@"redirectUri"];
            self.socketURL = responseJSON[@"apiUrl"];
            self.userID = responseJSON[@"ID"];
            self.userName = responseJSON[@"name"];
            self.accessToken = responseJSON[@"accessToken"];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"validPassword" arguments:responseJSON];
            });
                
            self.controllerState = STMAuthRequestRoles;
            
            break;

        }

        case STMAuthNewSMSCode: {

            self.requestID = responseJSON[@"ID"];
            self.controllerState = STMAuthEnterSMSCode;
        
            break;

        }

        case STMAuthSuccess:
        case STMAuthRequestRoles: {

            [self processRoles:responseJSON];

            break;

        }

        default: {
            break;
        }

    }
    
}

- (void)processRoles:(NSDictionary *)responseJSON {
    BOOL wasLogged = !!self.stcTabs;

    NSDictionary *roles = ([responseJSON[@"roles"] isKindOfClass:[NSDictionary class]]) ? responseJSON[@"roles"] : nil;

    if (roles) {

        self.rolesResponse = responseJSON;
        
        #if defined (CONFIGURATION_DebugVfs)
        
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"validPassword" arguments:@{@"name": responseJSON[@"account"][@"name"]}];
            });
        
            self.accountOrg = @"vfsd";
            self.userID = responseJSON[@"account"][@"id"];
            self.userName = responseJSON[@"account"][@"name"];
            self.socketURL = VFS_SOCKET_URL;
            self.entityResource = @"vfsd/Entity";
            self.iSisDB = self.userID;
            self.phoneNumber = @"";
            self.stcTabs = @[
                @{
                    @"name": @"STMProfile",
                    @"title": @"Профиль",
                    @"imageName": @"checked_user-128.png",
                },
                @{
                    @"name": @"STMWKWebView",
                    @"title": @"VFS",
                    @"imageName": @"3colors-colorless.png",
                    @"appManifestURI": @"https://vfsm2.sistemium.com/app.manifest",
                    @"url": @"https://vfsm2.sistemium.com"
                                 
                },
                @{
                    @"name": @"STMWKWebView",
                    @"title": @"STW",
                    @"imageName": @"3colors-colorless.png",
                    @"url": @"https://stw.sistemium.com"
                                 
                }
            ];
        
        #elif defined (CONFIGURATION_ReleaseVfs)
        
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"validPassword" arguments:@{@"name": responseJSON[@"account"][@"name"]}];
            });
        
            self.accountOrg = @"vfs";
            self.userID = responseJSON[@"account"][@"id"];
            self.userName = responseJSON[@"account"][@"name"];
            self.socketURL = VFS_SOCKET_URL;
            self.entityResource = @"vfs/Entity";
            self.iSisDB = self.userID;
            self.phoneNumber = @"";
            self.stcTabs = @[
                @{
                    @"name": @"STMProfile",
                    @"title": @"Профиль",
                    @"imageName": @"checked_user-128.png",
                },
                @{
                    @"name": @"STMWKWebView",
                    @"title": @"VFS",
                    @"imageName": @"3colors-colorless.png",
                    @"appManifestURI": @"https://vfsm2.sistemium.com/app.manifest",
                    @"url": @"https://vfsm2.sistemium.com"
                                 
                },
                @{
                    @"name": @"STMWKWebView",
                    @"title": @"STW",
                    @"imageName": @"3colors-colorless.png",
                    @"url": @"https://stw.sistemium.com"
                                 
                }
            ];
                            
        #else

            self.accountOrg = roles[@"org"];
            self.iSisDB = roles[@"iSisDB"];
        
            id stcTabs = roles[@"stcTabs"];

            if ([stcTabs isKindOfClass:[NSArray class]]) {

                self.stcTabs = stcTabs;

            } else if ([stcTabs isKindOfClass:[NSDictionary class]]) {

                self.stcTabs = @[stcTabs];

            } else {

                [[STMLogger sharedLogger] saveLogMessageWithText:@"recieved stcTabs is not an array or dictionary"
                                                         numType:STMLogMessageTypeError];

            }
        
        #endif

    } else {

        [[STMLogger sharedLogger] saveLogMessageWithText:@"recieved roles is not a dictionary"
                                                 numType:STMLogMessageTypeError];

    }

    self.controllerState = STMAuthSuccess;

    if (!wasLogged) {

        [self startSession];

    }
}

- (void)processingResponseJSONError {

    if (self.controllerState == STMAuthRequestRoles) {

        [self connectionErrorWhileRequestingRoles];

    } else {

        NSString *errorString = NSLocalizedString(@"RESPONSE IS NOT A DICTIONARY", nil);

        if (self.controllerState == STMAuthEnterPhoneNumber) {

            errorString = NSLocalizedString(@"WRONG PHONE NUMBER", nil);
            self.controllerState = STMAuthEnterPhoneNumber;
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"loginError" arguments:errorString];
            });

        } else if (self.controllerState == STMAuthEnterSMSCode) {

            errorString = NSLocalizedString(@"WRONG SMS CODE", nil);
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"loginError" arguments:errorString];
            });
            self.controllerState = STMAuthEnterSMSCode;

        } else if (self.controllerState == STMAuthRequestRoles) {
            
            errorString = [NSLocalizedString(@"ROLES REQUEST ERROR", nil) stringByAppendingString:errorString];
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterMethodChannel *channel = [(STMCoreAppDelegate *)[UIApplication sharedApplication].delegate flutterChannel];
                [channel invokeMethod:@"loginError" arguments:errorString];
            });
            self.controllerState = STMAuthEnterPhoneNumber;

        }

        [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError"
                                                            object:self
                                                          userInfo:@{@"error": errorString}];

    }

}


@end
