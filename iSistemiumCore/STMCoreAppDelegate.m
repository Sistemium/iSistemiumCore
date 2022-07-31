//
//  STMCoreAppDelegate.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMCoreAppDelegate.h"
#import "STMCoreAuthController.h"

#import "STMCoreAuthController.h"
#import "STMRemoteController.h"

#import "STMMessageController.h"

#import "STMCoreSessionManager.h"
#import "STMLogger.h"

#import "STMCoreRootTBC.h"

#import "STMAuthNC.h"

#import "STMSoundController.h"

#import <AVFoundation/AVFoundation.h>
#import "iSistemiumCore-Swift.h"

#import "STMUserDefaults.h"

#import "UITestSetup.h"

#import <WebKit/WebKit.h>
#import <FlutterPluginRegistrant/GeneratedPluginRegistrant.h>

@import Firebase;
@import FirebaseCrashlytics;

@interface STMCoreAppDelegate ()

@property (nonatomic, strong) NSMutableArray *fetchCompletionHandlers;

@end

@implementation STMCoreAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.flutterEngine = [[FlutterEngine alloc] initWithName:@"my flutter engine"];
    [self.flutterEngine run];
    [GeneratedPluginRegistrant registerWithRegistry:self.flutterEngine];
    self.flutterViewController =
        [[FlutterViewController alloc] initWithEngine:self.flutterEngine nibName:nil bundle:nil];
    
    self.flutterChannel = [FlutterMethodChannel
                                              methodChannelWithName:@"com.sistemium.flutterchanel"
                                              binaryMessenger:self.flutterViewController.binaryMessenger];
    
    [self.flutterChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
        if ([call.method isEqual: @"demoAuth"]){
            [CoreAuthController demoAuth];
        }
        if ([call.method isEqual: @"sendPhone"]){
            [CoreAuthController sendPhoneNumberWithPhoneNumber:call.arguments];
        }
        if ([call.method isEqual: @"sendPassword"]){
            [CoreAuthController sendSMSCodeWithSMSCode:call.arguments];
        }
    }];
    
    [STMFunctions stringFromNow];

    [self sessionManager];

    [self startAuthController];

    [self setupWindow];
    
    if ([STMCoreAuthController sharedAuthController].isDemo){
        [STMCoreAuthController.sharedAuthController logout];
    }

    [STMCoreAuthController.sharedAuthController checkPhoneNumber];

    [FIRApp configure];
    
    NSLog(@"deviceUUID %@", [STMClientDataController deviceUUID]);

//    STMLogger *logger = [STMLogger sharedLogger];
//    
//    NSString *logMessage = [NSString stringWithFormat:@"application didFinishLaunchingWithOptions: %@", launchOptions.description];
//    [logger saveLogMessageWithText:logMessage
//                           numType:STMLogMessageTypeImportant];

    if (launchOptions != nil) {

        NSDictionary *remoteNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];

        if (remoteNotification) {
            [self receiveRemoteNotification:remoteNotification];
        }

    }

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(statusChanged)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:[self sessionManager].currentSession];

    [STMSoundController initAudioSession];

    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"UI-TESTING"]) {

        [self setupUITests];

    }
    
    _orientation = UIInterfaceOrientationMaskAllButUpsideDown;

    return YES;

}
    
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window{
    return _orientation;
}

- (void)startAuthController {
    [STMCoreAuthController sharedAuthController];
}

- (STMCoreSessionManager *)sessionManager {
    return [STMCoreSessionManager sharedManager];
}

- (void)statusChanged {

    if ([self sessionManager].currentSession.status == STMSessionRunning) {
        
//        [self registerForNotification];

    }

}

- (void)receiveRemoteNotification:(NSDictionary *)remoteNotification {

    NSString *msg = [NSString stringWithFormat:@"%@", remoteNotification[@"aps"][@"alert"]];
    NSString *logMessage = [NSString stringWithFormat:@"didReceiveRemoteNotification: %@", msg];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage];

    id <STMSession> session = [self sessionManager].currentSession;

    if (session.status == STMSessionRunning) {
        [[session syncer] sendData];
    }

}

- (void)registerForNotification {

    if (SYSTEM_VERSION >= 8.0) {

        UIUserNotificationType types = UIUserNotificationTypeSound | UIUserNotificationTypeBadge | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];

    }

}


- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {

    NSLog(@"didReceiveLocalNotification: %@", notification);

//    if ([notification.userInfo.allKeys containsObject:RINGING_LOCAL_NOTIFICATION]) {
//        
//        NSString *soundName = notification.userInfo[RINGING_LOCAL_NOTIFICATION];
//        [STMSoundController ringingLocalNotificationWithMessage:nil andSoundName:soundName];
//        
//    }

}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
//    NSLog(@"didRegisterUserNotificationSettings: %@", notificationSettings);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {

    NSLog(@"deviceToken: %@", deviceToken);
    self.deviceTokenError = @"";
    [self recieveDeviceToken:deviceToken];

}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {

    NSLog(@"Failed to register with error: %@", error);
    self.deviceTokenError = error.localizedDescription;
    [self recieveDeviceToken:nil];

}

- (void)recieveDeviceToken:(NSData *)deviceToken {

    self.deviceToken = deviceToken;

}


#pragma mark - app state changes

- (void)applicationWillResignActive:(UIApplication *)application {

    NSString *logMessage = [NSString stringWithFormat:@"applicationWillResignActive"];
//    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
//                                             numType:STMLogMessageTypeImportant];

    [[self syncer] sendEventViaSocket:STMSocketEventStatusChange
                            withValue:logMessage];

    if (STMCoreAuthController.sharedAuthController.lastAuth) {
        [STMSoundController startBackgroundPlay];
    }

}

- (void)applicationDidEnterBackground:(UIApplication *)application {

    STMLogger *logger = [STMLogger sharedLogger];

    NSString *logMessage = @"applicationDidEnterBackground";
    [logger infoMessage:logMessage];

    NSLog(@"%@", [STMFunctions memoryStatistic]);
    
    [self clearWebViewCache];

    __block UIBackgroundTaskIdentifier bgTask;

    bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [self backgroundTask:bgTask endedInApplication:application];
    }];

    [self backgroundTask:bgTask startedInApplication:application];

    [[self syncer] sendEventViaSocket:STMSocketEventStatusChange
                            withValue:logMessage];

    [STMGarbageCollector.sharedInstance removeOutOfDateImages];
//    [self showTestLocalNotification];

}

- (void)applicationWillEnterForeground:(UIApplication *)application {

    NSString *logMessage = @"applicationWillEnterForeground";
    [[STMLogger sharedLogger] infoMessage:logMessage];

    [[self syncer] sendEventViaSocket:STMSocketEventStatusChange withValue:logMessage];

    [[STMLogger sharedLogger] infoMessage:@"cancel scheduled socket close if have one"];

    [STMSyncer cancelPreviousPerformRequestsWithTarget:[self syncer]
                                              selector:@selector(closeSocketInBackground)
                                                object:nil];
    [[self syncer] checkSocket];

}

- (void)applicationDidBecomeActive:(UIApplication *)application {

    NSString *logMessage = [NSString stringWithFormat:@"applicationDidBecomeActive"];
    [[STMLogger sharedLogger] infoMessage:logMessage];

    [self setupWindow];

    id <STMSession> session = [self sessionManager].currentSession;

    if (session.status == STMSessionRunning) {
        [STMMessageController showMessageVCsIfNeeded];
    }

    [[self syncer] sendEventViaSocket:STMSocketEventStatusChange
                            withValue:logMessage];
    if (STMCoreAuthController.sharedAuthController.lastAuth) {
        [STMSoundController stopBackgroundPlay];
    }

}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {


    NSString *log = [@"applicationDidReceiveMemoryWarning: " stringByAppendingString:[STMFunctions memoryStatistic]];

    [[STMLogger sharedLogger] importantMessage:log];

    [self clearWebViewCache];

}


- (void)clearWebViewCache {

    NSSet *websiteDataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeMemoryCache]];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];

    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
        NSLog(@"Done cleaning webView: %@", [STMFunctions memoryStatistic]);
    }];

}

- (void)applicationWillTerminate:(UIApplication *)application {

    [[STMUserDefaults standardUserDefaults] synchronize];

    [[STMLogger sharedLogger] saveLogMessageWithText:@"applicationWillTerminate"
                                             numType:STMLogMessageTypeError];

    [self sendAppTerminateLocalNotification];

}


#pragma mark - app fetching

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    [self.fetchCompletionHandlers addObject:completionHandler];

    STMLogger *logger = [STMLogger sharedLogger];

    NSString *logMessage = @"applicationPerformFetchWithCompletionHandler";
    [logger saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];

    __block UIBackgroundTaskIdentifier bgTask;

    bgTask = [application beginBackgroundTaskWithExpirationHandler:^{

        [self backgroundTask:bgTask endedInApplication:application];

        NSString *methodName = [NSString stringWithFormat:@"%@ in beginBackgroundTaskWithExpirationHandler:", NSStringFromSelector(_cmd)];

        [self completeFetchCompletionHandlersWithResult:UIBackgroundFetchResultFailed
                                             methodName:methodName];

    }];

    [self backgroundTask:bgTask startedInApplication:application];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"applicationPerformFetchWithCompletionHandler"
                                                        object:application];

    STMSyncer *syncer = [self syncer];

    if (syncer.transportIsReady) {
        [syncer receiveData];
    } else {
        [syncer checkSocket];
    }

}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler {

    [self.fetchCompletionHandlers addObject:handler];

    STMLogger *logger = [STMLogger sharedLogger];

    NSString *logMessage = [NSString stringWithFormat:@"application didReceiveRemoteNotification userInfo: %@", userInfo];
    [logger saveLogMessageWithText:logMessage numType:STMLogMessageTypeImportant];

    __block UIBackgroundTaskIdentifier bgTask;

    __block BOOL handlerCompleted = NO;

    bgTask = [application beginBackgroundTaskWithExpirationHandler:^{

        [self backgroundTask:bgTask endedInApplication:application];

        if (!handlerCompleted) {

            NSString *methodName = [NSString stringWithFormat:@"%@ in beginBackgroundTaskWithExpirationHandler:", NSStringFromSelector(_cmd)];

            [self completeFetchCompletionHandlersWithResult:UIBackgroundFetchResultFailed
                                                 methodName:methodName];

        }

    }];

    [self backgroundTask:bgTask startedInApplication:application];

    [self routeNotificationUserInfo:userInfo];

//    [self showTestLocalNotification];

}


#pragma mark - backgrounds

- (void)backgroundTask:(UIBackgroundTaskIdentifier)bgTask startedInApplication:(UIApplication *)application {

    STMLogger *logger = [STMLogger sharedLogger];

    NSString *logMessage = [NSString stringWithFormat:@"startBackgroundTaskWithExpirationHandler %d", (unsigned int) bgTask];
    [logger saveLogMessageWithText:logMessage];

    NSTimeInterval timeRemaining = application.backgroundTimeRemaining;

    logMessage = [NSString stringWithFormat:@"BackgroundTimeRemaining %@", @(timeRemaining)];
    [logger saveLogMessageWithText:logMessage];

    if (timeRemaining != DBL_MAX) {

        timeRemaining -= 5; // should be enough to close socket

        NSTimeInterval delayInterval = timeRemaining >= 0 ? timeRemaining : 0;

        logMessage = [NSString stringWithFormat:@"socket will be closed in %@ sec (%@) due to background condition", @(delayInterval), [NSDate dateWithTimeIntervalSinceNow:delayInterval]];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];

        [[self syncer] performSelector:@selector(closeSocketInBackground)
                            withObject:nil
                            afterDelay:delayInterval];

    }

}

- (void)backgroundTask:(UIBackgroundTaskIdentifier)bgTask endedInApplication:(UIApplication *)application {

    STMLogger *logger = [STMLogger sharedLogger];

    NSString *logMessage = [NSString stringWithFormat:@"endBackgroundTaskWithExpirationHandler %d", (unsigned int) bgTask];
    [logger saveLogMessageWithText:logMessage];

    [application endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;

}


#pragma mark -

- (void)routeNotificationUserInfo:(NSDictionary *)userInfo {

    BOOL meaningfulUserInfo = NO;

    if (userInfo[@"remoteCommands"]) {

        [STMRemoteController receiveRemoteCommands:userInfo[@"remoteCommands"]];
        meaningfulUserInfo = YES;

    }

    if (!meaningfulUserInfo) {

        [[NSNotificationCenter defaultCenter] postNotificationName:@"applicationDidReceiveRemoteNotification"
                                                            object:[UIApplication sharedApplication]
                                                          userInfo:userInfo];
        STMSyncer *syncer = [self syncer];
        
        if (syncer.transportIsReady) {
            [syncer receiveData];
        } else {
            [syncer checkSocket];
        }

    }

}

- (void)tryCatchFetchResultHandler:(void (^)(UIBackgroundFetchResult result))handler withResult:(UIBackgroundFetchResult)result methodName:(NSString *)methodName {

    NSLogMethodName;

    @try {

        NSLog(@"result %@", @(result));
        handler(result);

    } @catch (NSException *exception) {

        NSString *logMessage = [NSString stringWithFormat:@"tryCatchFetchResultHandler\n%@\nException: %@\nStack trace: %@", methodName, exception.description, exception.callStackSymbols];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];

    }

}

- (void)completeFetchCompletionHandlersWithResult:(UIBackgroundFetchResult)result methodName:(NSString *)methodName {

    NSArray *handlers = self.fetchCompletionHandlers.copy;
    [self.fetchCompletionHandlers removeObjectsInArray:handlers];

    if (!methodName) methodName = [NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)];

    for (

            void (^fetchCompletionHandler)(UIBackgroundFetchResult result)

            in handlers) {

        [self tryCatchFetchResultHandler:fetchCompletionHandler
                              withResult:result
                              methodName:methodName];

    }

}

- (void)completeFetchCompletionHandlersWithResult:(UIBackgroundFetchResult)result {
    [self completeFetchCompletionHandlersWithResult:result methodName:nil];
}

- (void)setupWindow {

    if (!self.window) {
        
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        
    }
    
    if (STMCoreAuthController.sharedAuthController.initialLoadingCompleted == NO){
        self.window.rootViewController = self.flutterViewController;
    } else {
        self.window.rootViewController = [STMCoreRootTBC sharedRootVC];
        [STMCoreRootTBC.sharedRootVC initAllTabs];
    }
        
    [self.window makeKeyAndVisible];

}

- (void)setupUITests {

    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"WorkflowTest"]) {

        [UITestSetup workflowSetup];

    }

}

- (void)showTestLocalNotification {

    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.alertBody = NSLocalizedString(@"APP TERMINATE", nil);;
    localNotification.soundName = UILocalNotificationDefaultSoundName;

    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];

}

- (void)sendAppTerminateLocalNotification {

    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.alertBody = NSLocalizedString(@"APP TERMINATE", nil);
    localNotification.soundName = UILocalNotificationDefaultSoundName;

    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];

}

- (NSString *)currentNotificationTypes {

    NSMutableArray *typesArray = [NSMutableArray array];

    if (SYSTEM_VERSION >= 8.0) {

        UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        UIUserNotificationType types = settings.types;

        if (types & UIUserNotificationTypeAlert) {
            [typesArray addObject:@"alert"];
        }
        if (types & UIUserNotificationTypeBadge) {
            [typesArray addObject:@"badge"];
        }
        if (types & UIUserNotificationTypeSound) {
            [typesArray addObject:@"sound"];
        }
        if (types == UIUserNotificationTypeNone) {
            [typesArray addObject:@"none"];
        }

    }

    return [typesArray componentsJoinedByString:@", "];

}


#pragma mark - variables setters&getters

@synthesize deviceToken = _deviceToken;
@synthesize deviceTokenError = _deviceTokenError;

- (NSData *)deviceToken {

    if (!_deviceToken) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _deviceToken = [defaults objectForKey:@"deviceToken"];

    }

    return _deviceToken;

}

- (void)setDeviceToken:(NSData *)deviceToken {

    if (_deviceToken != deviceToken) {

        _deviceToken = deviceToken;

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:deviceToken forKey:@"deviceToken"];
        [defaults synchronize];

        [[FIRCrashlytics crashlytics] setCustomValue:deviceToken forKey:@"deviceToken"];

    }

}

- (NSString *)deviceTokenError {

    if (!_deviceTokenError) {

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        _deviceTokenError = [defaults objectForKey:@"deviceTokenError"];

    }

    return _deviceTokenError;

}

- (void)setDeviceTokenError:(NSString *)deviceTokenError {

    if (_deviceTokenError != deviceTokenError) {

        _deviceTokenError = deviceTokenError;

        STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
        [defaults setObject:deviceTokenError forKey:@"deviceTokenError"];
        [defaults synchronize];

    }

}

- (STMSyncer *)syncer {
    return (STMSyncer *) [self sessionManager].currentSession.syncer;
}

- (NSMutableArray *)fetchCompletionHandlers {

    if (!_fetchCompletionHandlers) {
        _fetchCompletionHandlers = @[].mutableCopy;
    }
    return _fetchCompletionHandlers;

}

- (BOOL)haveFetchCompletionHandlers {
    return self.fetchCompletionHandlers.count;
}

- (void)testCrash {
    @[][1];
}

@end
