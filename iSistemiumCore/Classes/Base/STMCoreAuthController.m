//
//  STMCoreAuthController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreAuthController.h"

#import <AdSupport/AdSupport.h>

#import <JNKeychain/JNKeychain.h>

#import "STMDevDef.h"
#import "STMFunctions.h"
#import "STMCoreSessionManager.h"
#import "STMLogger.h"

#import "STMSocketController.h"


#define AUTH_URL @"https://api.sistemium.com/pha/auth"

#define ROLES_URL @"https://api.sistemium.com/pha/roles"

#define TIMEOUT 15.0

#define KC_PHONE_NUMBER @"phoneNumber"
#define KC_SERVICE_URI @"serviceUri"
#define KC_USER_ID @"userID"
#define KC_ACCESS_TOKEN @"accessToken"


@interface STMCoreAuthController() <NSURLConnectionDataDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSString *requestID;
@property (nonatomic, strong) NSString *serviceUri;
@property (nonatomic, strong) NSString *apiURL;


@end


@implementation STMCoreAuthController

@synthesize phoneNumber = _phoneNumber;
@synthesize userID = _userID;
@synthesize userName = _userName;
@synthesize accessToken = _accessToken;
@synthesize serviceUri = _serviceUri;
@synthesize stcTabs = _stcTabs;
@synthesize iSisDB = _iSisDB;


#pragma mark - singletone init

+ (STMCoreAuthController *)authController {
    
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

        NSString *keychainPhoneNumber = [JNKeychain loadValueForKey:KC_PHONE_NUMBER];
        if ([self.phoneNumber isEqualToString:keychainPhoneNumber]) [self checkAccessToken];
        
    }
    
    return self;
    
}


#pragma mark - variables setters & getters

- (NSString *)phoneNumber {
    
    if (!_phoneNumber) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:phoneNumber forKey:@"phoneNumber"];
        [defaults synchronize];

        [JNKeychain saveValue:phoneNumber forKey:KC_PHONE_NUMBER];
        
        _phoneNumber = phoneNumber;
        
    }
    
}

- (NSString *)userName {
    
    if (!_userName) {

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:userName forKey:@"userName"];
        [defaults synchronize];
        
        _userName = userName;

    }
    
}

- (void)setControllerState:(STMAuthState)controllerState {

    NSLog(@"authControllerState %d", controllerState);
    _controllerState = controllerState;

    if (controllerState == STMAuthRequestRoles) {
        
        [self requestRoles];
        
    } else if (controllerState == STMAuthSuccess) {
        
        NSLog(@"login");
        [self startSession];

    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerStateChanged" object:self];
    
}

- (NSString *)serviceUri {
    
    if (!_serviceUri) {
        _serviceUri = [JNKeychain loadValueForKey:KC_SERVICE_URI];
    }
    return _serviceUri;
    
}

- (void)setServiceUri:(NSString *)serviceUri {
    
    if (serviceUri != _serviceUri) {
        
        [JNKeychain saveValue:serviceUri forKey:KC_SERVICE_URI];
        NSLog(@"serviceUri %@", serviceUri);
        _serviceUri = serviceUri;
        
    }
    
}

- (NSString *)userID {
    
    if (!_userID) {
        _userID = [JNKeychain loadValueForKey:KC_USER_ID];
    }
    return _userID;
    
}

- (void)setUserID:(NSString *)userID {
    
    if (userID != _userID) {
        
        [JNKeychain saveValue:userID forKey:KC_USER_ID];
        NSLog(@"userID %@", userID);
        _userID = userID;
        
    }
    
}

- (NSString *)accessToken {
    
    if (!_accessToken) {
        _accessToken = [JNKeychain loadValueForKey:KC_ACCESS_TOKEN];
    }
    return _accessToken;
    
}

- (void)setAccessToken:(NSString *)accessToken {
    
    if (accessToken != _accessToken) {
        
        [JNKeychain saveValue:accessToken forKey:KC_ACCESS_TOKEN];
        NSLog(@"accessToken %@", accessToken);
        _accessToken = accessToken;

        self.lastAuth = [NSDate date];
        self.tokenHash = [STMFunctions MD5FromString:accessToken];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.lastAuth forKey:@"lastAuth"];
        [defaults setObject:self.tokenHash forKey:@"tokenHash"];
        [defaults synchronize];
        
    }
    
}

- (NSString *)tokenHash {
    
    if (!_tokenHash) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _lastAuth = [defaults objectForKey:@"lastAuth"];
        
    }
    
    return _lastAuth;
    
}

- (NSArray *)stcTabs {
    
    if (!_stcTabs) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _stcTabs = [defaults objectForKey:@"stcTabs"];
        
    }
    return _stcTabs;
    
}

- (void)setStcTabs:(NSArray *)stcTabs {
    
    if (![stcTabs isEqual:_stcTabs]) {
        
        _stcTabs = stcTabs;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:stcTabs forKey:@"stcTabs"];
        [defaults synchronize];
        
    }
    
}

- (NSString *)iSisDB {
    
    if (!_iSisDB) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:iSisDB forKey:@"iSisDB"];
        [defaults synchronize];
        
        _iSisDB = iSisDB;
        
    }
    
}


#pragma mark - instance methods

- (void)checkAccessToken {

    BOOL checkValue = YES;
    
    if (!self.userID || [self.userID isEqualToString:@""]) {
        NSLog(@"No userID");
        checkValue = NO;
    } else {
        NSLog(@"userID %@", self.userID);
    }
    if (!self.accessToken || [self.accessToken isEqualToString:@""]) {
        NSLog(@"No accessToken");
        checkValue = NO;
    } else {
        NSLog(@"accessToken %@", self.accessToken);
    }

    self.controllerState = checkValue ? STMAuthRequestRoles : STMAuthEnterPhoneNumber;

}

- (void)logout {
    
    NSLog(@"logout");

    self.controllerState = STMAuthEnterPhoneNumber;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"notAuthorized" object:[STMCoreSessionManager sharedManager].currentSession.syncer];
    [[STMCoreSessionManager sharedManager] stopSessionForUID:self.userID];

    self.userID = nil;
    self.accessToken = nil;
    self.stcTabs = nil;
    self.iSisDB = nil;
    [JNKeychain deleteValueForKey:KC_PHONE_NUMBER];

}

- (void)startSession {

    NSLog(@"serviceUri %@", self.serviceUri);
    NSLog(@"apiURL %@", self.apiURL);

    NSArray *trackers = @[@"battery", @"location"];
    
    NSDictionary *startSettings = nil;
    
    NSString *dataModelName = ([[NSBundle mainBundle].bundleIdentifier hasSuffix:@"iSistemiumCore"]) ? @"iSistemiumCore" : @"STMDataModel2";
    
#ifdef DEBUG
    
    if (GRIMAX) {
        
        startSettings = @{
                          @"restServerURI"                  : self.serviceUri,
                          @"dataModelName"                  : dataModelName,
                          //                      @"fetchLimit"               : @"50",
                          //                      @"syncInterval"             : @"600",
                          //                      @"uploadLog.type"           : @"",
                          @"requiredAccuracy"               : @"100",
                          @"desiredAccuracy"                : @"10",
                          @"timeFilter"                     : @"60",
                          @"distanceFilter"                 : @"60",
                          @"backgroundDesiredAccuracy"      : @"3000",
                          @"foregroundDesiredAccuracy"      : @"10",
                          @"offtimeDesiredAccuracy"         : @"0",
                          @"maxSpeedThreshold"              : @"60",
                          @"locationTrackerAutoStart"       : @YES,
                          @"locationTrackerStartTime"       : @"0",
                          @"locationTrackerFinishTime"      : @"24",
                          @"locationWaitingTimeInterval"    : @"10",
                          @"batteryTrackerAutoStart"        : @YES,
                          @"batteryTrackerStartTime"        : @"8.0",
                          @"batteryTrackerFinishTime"       : @"22.0",
                          @"http.timeout.foreground"        : @"60",
                          @"jpgQuality"                     : @"0.0",
                          @"blockIfNoLocationPermission"    : @YES
                          };
        
    } else {
    
        startSettings = @{
                          @"restServerURI"            : self.serviceUri,
                          @"dataModelName"            : dataModelName,
                          };

    }
    
#else

    startSettings = @{
                      @"restServerURI"            : self.serviceUri,
                      @"dataModelName"            : dataModelName,
                      };

#endif
    
    if (self.apiURL) {
        
        NSMutableDictionary *tempDictionary = [startSettings mutableCopy];
        [tempDictionary addEntriesFromDictionary:@{@"API.url":self.apiURL}];
        
        startSettings = tempDictionary;
        
    }

    [[STMCoreSessionManager sharedManager] startSessionForUID:self.userID
                                                   iSisDB:self.iSisDB
                                             authDelegate:self
                                                 trackers:trackers
                                            startSettings:startSettings
                                  defaultSettingsFileName:@"settings"
                                           documentPrefix:[[NSBundle mainBundle] bundleIdentifier]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionNotAuthorized)
                                                 name:@"notAuthorized"
                                               object:[STMCoreSessionManager sharedManager].currentSession.syncer];

}

- (void)sessionNotAuthorized {
    
    [self logout];
    
}

#pragma mark - STMRequestAuthenticatable

- (NSURLRequest *)authenticateRequest:(NSURLRequest *)request {
    
    NSMutableURLRequest *resultingRequest = nil;
    
    if (self.accessToken) {
        
        resultingRequest = [request mutableCopy];
        [resultingRequest addValue:self.accessToken forHTTPHeaderField:@"Authorization"];
        [resultingRequest setValue:[[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString] forHTTPHeaderField:@"DeviceUUID"];


    }
    
    return resultingRequest;
    
}


#pragma mark - send requests

- (BOOL)sendPhoneNumber:(NSString *)phoneNumber {
    
    if ([STMFunctions isCorrectPhoneNumber:phoneNumber]) {
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
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
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            return NO;

        }

    } else {
        return NO;
    }
    
}

- (BOOL)sendSMSCode:(NSString *)SMSCode {
    
    if ([STMFunctions isCorrectSMSCode:SMSCode]) {

        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

        NSString *urlString = [NSString stringWithFormat:@"%@?smsCode=%@&ID=%@", AUTH_URL, SMSCode, self.requestID];
        NSURLRequest *request = [self requestForURL:urlString];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        
        if (connection) {
            
            return YES;
            
        } else {
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError"
                                                                object:self
                                                              userInfo:@{@"error": NSLocalizedString(@"NO CONNECTION", nil)}];
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
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
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSURLRequest *request = [self authenticateRequest:[self requestForURL:ROLES_URL]];
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
    [request setHTTPMethod:@"GET"];
    [request setValue:[[UIDevice currentDevice].identifierForVendor UUIDString] forHTTPHeaderField:@"DeviceUUID"];
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
        
    } else {
        
        self.controllerState = STMAuthEnterPhoneNumber;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError" object:self userInfo:@{@"error": error.localizedDescription}];
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    }

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

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
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
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
            
            self.requestID = responseJSON[@"ID"];
            self.controllerState = STMAuthEnterSMSCode;
            
            break;
            
        }
            
        case STMAuthEnterSMSCode: {
            
            self.serviceUri = responseJSON[@"redirectUri"];
            self.apiURL = responseJSON[@"apiUrl"];
            self.userID = responseJSON[@"ID"];
            self.userName = responseJSON[@"name"];
            self.accessToken = responseJSON[@"accessToken"];
            
            self.controllerState = STMAuthRequestRoles;
            
            break;
            
        }
            
        case STMAuthNewSMSCode: {
            
            self.requestID = responseJSON[@"ID"];
            self.controllerState = STMAuthEnterSMSCode;
            
            break;
            
        }
            
        case STMAuthRequestRoles: {
            
            self.iSisDB = responseJSON[@"roles"][@"iSisDB"];
            
            id stcTabs = responseJSON[@"roles"][@"stcTabs"];
            
            if ([stcTabs isKindOfClass:[NSArray class]]) {
                
                self.stcTabs = stcTabs;
                
            } else if ([stcTabs isKindOfClass:[NSDictionary class]]) {
                
                self.stcTabs = @[stcTabs];
                
            } else {
                
                [[STMLogger sharedLogger] saveLogMessageWithText:@"recieved stcTabs is not an array or dictionary" type:@"error"];
                
            }
            
            self.controllerState = STMAuthSuccess;
            
            break;
            
        }
            
        case STMAuthSuccess: {
            break;
        }
            
        default: {
            break;
        }
            
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
            
        } else if (self.controllerState == STMAuthEnterSMSCode) {
            
            errorString = NSLocalizedString(@"WRONG SMS CODE", nil);
            self.controllerState = STMAuthEnterSMSCode;
            
//        } else if (self.controllerState == STMAuthRequestRoles) {
//            
//            errorString = [NSLocalizedString(@"ROLES REQUEST ERROR", nil) stringByAppendingString:errorString];
//            self.controllerState = STMAuthEnterPhoneNumber;
            
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"authControllerError" object:self userInfo:@{@"error": errorString}];

    }
    
}


@end
