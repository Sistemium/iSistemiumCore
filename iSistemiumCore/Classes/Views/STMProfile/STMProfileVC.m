//
//  STMProfileVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 04/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMProfileVC.h"

#import "STMSessionManager.h"
#import "STMSession.h"

#import "STMLocationTracker.h"
#import "STMSyncer.h"
#import "STMEntityController.h"
#import "STMPicturesController.h"
#import "STMSocketController.h"

#import "STMAuthController.h"
#import "STMRootTBC.h"

#import "STMUI.h"
#import "STMFunctions.h"

#import <Reachability/Reachability.h>


@interface STMProfileVC () <UIAlertViewDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *phoneNumberLabel;

@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;

@property (weak, nonatomic) IBOutlet UILabel *sendDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *receiveDateLabel;

@property (weak, nonatomic) IBOutlet UILabel *numberOfObjectLabel;

@property (weak, nonatomic) IBOutlet UILabel *lastLocationLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationTrackingStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *monitoringStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationWarningLabel;

@property (weak, nonatomic) IBOutlet UIButton *nonloadedPicturesButton;

@property (weak, nonatomic) IBOutlet UIImageView *uploadImageView;
@property (weak, nonatomic) IBOutlet UIImageView *downloadImageView;
@property (weak, nonatomic) IBOutlet UIImageView *lastLocationImageView;

@property (weak, nonatomic) UIImageView *syncImageView;

@property (nonatomic) float totalEntityCount;
@property (nonatomic) int previousNumberOfObjects;

@property (nonatomic, strong) Reachability *internetReachability;

@property (nonatomic) BOOL downloadAlertWasShown;
@property (nonatomic) BOOL newsReceiving;

@property (nonatomic, strong) STMSpinnerView *spinner;

@property (nonatomic, strong) UIAlertView *locationDisabledAlert;
@property (nonatomic) BOOL locationDisabledAlertIsShown;

@property (nonatomic, strong) NSString *requestLocationServiceAuthorization;


@end


@implementation STMProfileVC

- (STMLocationTracker *)locationTracker {
    return [(STMSession *)[STMSessionManager sharedManager].currentSession locationTracker];
}

- (STMSyncer *)syncer {
    return [[STMSessionManager sharedManager].currentSession syncer];
}

- (STMSettingsController *)settingsController {
    return [[STMSessionManager sharedManager].currentSession settingsController];
}

- (NSString *)requestLocationServiceAuthorization {
    
    if (!_requestLocationServiceAuthorization) {
        
        NSDictionary *appSettings = [self.settingsController currentSettingsForGroup:@"appSettings"];
        NSString *requestLocationServiceAuthorization = [appSettings valueForKey:@"requestLocationServiceAuthorization"];
        
        _requestLocationServiceAuthorization = requestLocationServiceAuthorization;
        
    }
    return _requestLocationServiceAuthorization;
    
}

- (void)backButtonPressed {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LOGOUT", nil)
                                                            message:NSLocalizedString(@"R U SURE TO LOGOUT", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"CANCEL", nil)
                                                  otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        alertView.tag = 1;
        [alertView show];
        
    }];
    
}

- (void)syncerStatusChanged:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMSyncer class]]) {
        
        STMSyncer *syncer = notification.object;
        
        STMSyncerState fromState = [notification.userInfo[@"from"] intValue];
        
        if (syncer.syncerState == STMSyncerIdle) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                
                sleep(1);
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    self.progressBar.hidden = YES;
                    
                });
                
            });
            
            if (!self.downloadAlertWasShown) [self showDownloadAlert];
            
        } else {
            
            self.progressBar.hidden = NO;
            self.totalEntityCount = 1;
            
        }
        
        if (fromState == STMSyncerReceiveData) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                
                sleep(5);
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self hideNumberOfObjects];
                    
                });
                
            });
            
        }
        
    }

    [self updateSyncInfo];
    
}

- (void)updateSyncInfo {
    
    [self updateSyncDatesLabels];
    [self updateCloudImages];
    [self updateNonloadedPicturesInfo];

}


#pragma mark - cloud images for sync button

- (void)updateCloudImages {
    
    [self setImageForSyncImageView];
    [self setColorForSyncImageView];
    
}

- (void)setImageForSyncImageView {
    
    STMSyncer *syncer = [self syncer];
    BOOL hasObjectsToUpload = ([syncer numbersOfUnsyncedObjects] > 0);

    [self.spinner removeFromSuperview];
    
    NSString *imageName = nil;
    
    if ([STMSocketController socketIsAvailable]) {
        
        switch (syncer.syncerState) {
            case STMSyncerIdle: {
                imageName = (hasObjectsToUpload) ? @"Upload To Cloud-100" : @"Download From Cloud-100";
                break;
            }
            case STMSyncerSendData:
            case STMSyncerSendDataOnce: {
                imageName = @"Upload To Cloud-100";
                self.spinner = [STMSpinnerView spinnerViewWithFrame:self.uploadImageView.bounds indicatorStyle:UIActivityIndicatorViewStyleGray backgroundColor:[UIColor whiteColor] alfa:1];
                [self.uploadImageView addSubview:self.spinner];
                break;
            }
            case STMSyncerReceiveData: {
                imageName = @"Download From Cloud-100";
                self.spinner = [STMSpinnerView spinnerViewWithFrame:self.downloadImageView.bounds indicatorStyle:UIActivityIndicatorViewStyleGray backgroundColor:[UIColor whiteColor] alfa:1];
                [self.downloadImageView addSubview:self.spinner];
                break;
            }
            default: {
                imageName = @"Download From Cloud-100";
                break;
            }
        }

    } else {
        
        imageName = @"No connection Cloud-100";
        
    }
    
    self.syncImageView.image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
}

- (void)setColorForSyncImageView {
    
    [self removeGestureRecognizersFromCloudImages];
    
    STMSyncer *syncer = [self syncer];
    BOOL hasObjectsToUpload = ([syncer numbersOfUnsyncedObjects] > 0);
    UIColor *color = (hasObjectsToUpload) ? [UIColor redColor] : ACTIVE_BLUE_COLOR;
    SEL cloudTapSelector = (hasObjectsToUpload) ? @selector(uploadCloudTapped) : @selector(downloadCloudTapped);
    
    NetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable || ![STMSocketController socketIsAvailable]) {
        
        color = [color colorWithAlphaComponent:0.3];
        [self.syncImageView setTintColor:color];
        
    } else {
        
        if (syncer.syncerState == STMSyncerIdle) {
            
            [self.syncImageView setTintColor:color];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:cloudTapSelector];
            [self.syncImageView addGestureRecognizer:tap];
            
            if (hasObjectsToUpload) {
                
                UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(uploadCloudLongPressed:)];
                [self.syncImageView addGestureRecognizer:longPress];
                
            }
            
        } else {
            
            [self.syncImageView setTintColor:[UIColor lightGrayColor]];
            
        }
        
    }
    
}

- (void)removeGestureRecognizersFromCloudImages {
    [self removeGestureRecognizersFrom:self.syncImageView];
}

- (void)removeGestureRecognizersFrom:(UIView *)view {
    
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        [view removeGestureRecognizer:gesture];
    }
    
}

- (void)uploadCloudLongPressed:(id)sender {
    
    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]]) {
        
        UILongPressGestureRecognizer *longPressGesture = (UILongPressGestureRecognizer *)sender;
        
        if (longPressGesture.state == UIGestureRecognizerStateBegan) {
            
            [self syncer].syncerState = STMSyncerSendData;
            
        }
        
    }

}

- (void)uploadCloudTapped {
    [self syncer].syncerState = STMSyncerSendDataOnce;
}

- (void)downloadCloudTapped {
    
//    [[self syncer] afterSendFurcation];
    [self syncer].syncerState = STMSyncerReceiveData;
    
}


#pragma mark -

- (void)syncerNewsHaveObjects:(NSNotification *)notification {
    
    self.newsReceiving = YES;
    self.totalEntityCount = [(notification.userInfo)[@"totalNumberOfObjects"] floatValue];
    
}

- (void)entitiesReceivingDidFinish {

    self.newsReceiving = NO;
    self.totalEntityCount = (float)[STMEntityController stcEntities].allKeys.count;
    
}

- (void)entityCountdownChange:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMSyncer class]] && !self.newsReceiving) {
        
        float countdownValue = [(notification.userInfo)[@"countdownValue"] floatValue];
        self.progressBar.progress = (self.totalEntityCount - countdownValue) / self.totalEntityCount;
        
    }
    
}

- (void)getBunchOfObjects:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMSyncer class]]) {
        
        NSNumber *numberOfObjects = notification.userInfo[@"count"];
        
        numberOfObjects = @(self.previousNumberOfObjects + numberOfObjects.intValue);
        
        NSString *pluralType = [STMFunctions pluralTypeForCount:numberOfObjects.intValue];
        NSString *numberOfObjectsString = [pluralType stringByAppendingString:@"OBJECTS"];
        
        NSString *receiveString = ([pluralType isEqualToString:@"1"]) ? NSLocalizedString(@"RECEIVE1", nil) : NSLocalizedString(@"RECEIVE", nil);
        
        self.numberOfObjectLabel.text = [NSString stringWithFormat:@"%@ %@ %@", receiveString, numberOfObjects, NSLocalizedString(numberOfObjectsString, nil)];
        
        self.previousNumberOfObjects = numberOfObjects.intValue;
        
        if (self.newsReceiving) {
            
            self.progressBar.progress = numberOfObjects.floatValue / self.totalEntityCount;
            
        }
        
    }
    
}

- (void)syncerDidChangeContent:(NSNotification *)notification {
    [self updateCloudImages];
}

- (void)socketAuthorizationSuccess {
    [self updateCloudImages];
}

- (void)hideNumberOfObjects {
    
    if ([[[STMSessionManager sharedManager].currentSession syncer] syncerState] != STMSyncerReceiveData) {
        
        self.previousNumberOfObjects = 0;
        self.numberOfObjectLabel.text = @"";
        
    }
    
}

- (void)showUpdateButton {
    
    UIBarButtonItem *updateButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"UPDATE", nil) style:UIBarButtonItemStylePlain target:self action:@selector(updateButtonPressed)];
    
    [updateButton setTintColor:[UIColor redColor]];
    
    self.navigationItem.rightBarButtonItem = updateButton;
    
}

- (void)updateButtonPressed {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateButtonPressed" object:nil];
    
}

- (void)newAppVersionAvailable:(NSNotification *)notification {
    
    //    [self showUpdateButton];
    
}

- (void)updateSyncDatesLabels {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *key = [@"sendDate" stringByAppendingString:[STMAuthController authController].userID];
    NSString *sendDateString = [defaults objectForKey:key];
    
    key = [@"receiveDate" stringByAppendingString:[STMAuthController authController].userID];
    NSString *receiveDateString = [defaults objectForKey:key];
    
    self.sendDateLabel.text = (sendDateString) ? sendDateString : nil;
    self.receiveDateLabel.text = (receiveDateString) ? receiveDateString : nil;

//    if (sendDateString) {
//        self.sendDateLabel.text = [NSLocalizedString(@"SEND DATE", nil) stringByAppendingString:sendDateString];
//    } else {
//        self.sendDateLabel.text = nil;
//    }
//    
//    if (receiveDateString) {
//        self.receiveDateLabel.text = [NSLocalizedString(@"RECEIVE DATE", nil) stringByAppendingString:receiveDateString];
//    } else {
//        self.receiveDateLabel.text = nil;
//    }
    
}

- (void)setupNonloadedPicturesButton {
    
    [self.nonloadedPicturesButton setTitleColor:ACTIVE_BLUE_COLOR forState:UIControlStateNormal];
    [self.nonloadedPicturesButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    
}

- (void)updateNonloadedPicturesInfo {

    self.nonloadedPicturesButton.enabled = ([self syncer].syncerState == STMSyncerIdle);
    
    NSUInteger unloadedPicturesCount = [[STMPicturesController sharedController] nonloadedPicturesCount];
    
    NSString *title = @"";
    NSString *badgeValue = nil;
    
    if (unloadedPicturesCount > 0) {
        
        NSString *pluralString = [STMFunctions pluralTypeForCount:unloadedPicturesCount];
        NSString *picturesCount = [NSString stringWithFormat:@"%@UPICTURES", pluralString];
        title = [NSString stringWithFormat:@"%lu %@ %@", (unsigned long)unloadedPicturesCount, NSLocalizedString(picturesCount, nil), NSLocalizedString(@"WAITING FOR DOWNLOAD", nil)];
        
        badgeValue = [NSString stringWithFormat:@"%lu", (unsigned long)unloadedPicturesCount];
        
    } else {
        
        self.downloadAlertWasShown = NO;
        self.nonloadedPicturesButton.enabled = NO;
        
        [STMPicturesController sharedController].downloadingPictures = NO;
        [UIApplication sharedApplication].idleTimerDisabled = NO;

    }
    
    [self.nonloadedPicturesButton setTitle:title forState:UIControlStateNormal];
    self.navigationController.tabBarItem.badgeValue = badgeValue;
    
    UIColor *titleColor = [STMPicturesController sharedController].downloadingPictures ? ACTIVE_BLUE_COLOR : [UIColor redColor];
    [self.nonloadedPicturesButton setTitleColor:titleColor forState:UIControlStateNormal];
    
}

- (void)nonloadedPicturesCountDidChange {
    [self updateNonloadedPicturesInfo];
}

- (IBAction)nonloadedPicturesButtonPressed:(id)sender {

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
        actionSheet.title = NSLocalizedString(@"UNLOADED PICTURES", nil);
        actionSheet.delegate = self;

        if ([STMPicturesController sharedController].downloadingPictures) {
        
            actionSheet.tag = 2;
            [actionSheet addButtonWithTitle:NSLocalizedString(@"DOWNLOAD STOP", nil)];
            [actionSheet addButtonWithTitle:NSLocalizedString(@"CLOSE", nil)];

        } else {

            actionSheet.tag = 1;
            [actionSheet addButtonWithTitle:NSLocalizedString(@"DOWNLOAD NOW", nil)];
            [actionSheet addButtonWithTitle:NSLocalizedString(@"DOWNLOAD LATER", nil)];

        }

        [actionSheet showInView:self.view];
        
    }];

}

- (void)checkDownloadingConditions {
    
    [self startPicturesDownloading];
    
/*
    
    STMSettingsController *settingsController = [[STMSessionManager sharedManager].currentSession settingsController];
    BOOL enableDownloadViaWWAN = [[settingsController currentSettingsForGroup:@"appSettings"][@"enableDownloadViaWWAN"] boolValue];
    
    NetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
    
#warning - don't forget to comment next line
    networkStatus = ReachableViaWWAN; // just for testing
    
    if (networkStatus == ReachableViaWWAN && !enableDownloadViaWWAN) {
        
        [self showWWANAlert];
        
    } else {
        [self startPicturesDownloading];
    }
 
*/

}

- (void)startPicturesDownloading {
    
    [STMPicturesController checkPhotos];
    [STMPicturesController sharedController].downloadingPictures = YES;
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    [self updateNonloadedPicturesInfo];
    
}

- (void)stopPicturesDownloading {
    
    [STMPicturesController sharedController].downloadingPictures = NO;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self updateNonloadedPicturesInfo];

}

- (void)showDownloadAlert {
    
    NSUInteger unloadedPicturesCount = [[STMPicturesController sharedController] nonloadedPicturesCount];
    
    if (unloadedPicturesCount > 0) {
        
        NSString *pluralString = [STMFunctions pluralTypeForCount:unloadedPicturesCount];
        NSString *picturesCount = [NSString stringWithFormat:@"%@UPICTURES", pluralString];
        NSString *title = [NSString stringWithFormat:@"%lu %@ %@. %@", (unsigned long)unloadedPicturesCount, NSLocalizedString(picturesCount, nil), NSLocalizedString(@"WAITING FOR DOWNLOAD", nil), NSLocalizedString(@"DOWNLOAD IT NOW?", nil)];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UNLOADED PICTURES", nil)
                                                            message:title
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"NO", nil)
                                                  otherButtonTitles:NSLocalizedString(@"YES", nil), nil];
            alert.tag = 2;
            [alert show];
        
            self.downloadAlertWasShown = YES;

        }];
        
    }
    
}

- (void)showWWANAlert {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"UNLOADED PICTURES", nil)
                                                        message:NSLocalizedString(@"NO WIFI MESSAGE", nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"NO", nil)
                                              otherButtonTitles:NSLocalizedString(@"YES", nil), nil];
        alert.tag = 3;
        [alert show];
        
    }];
    
}

- (void)showEnableWWANActionSheet {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
        actionSheet.delegate = self;
        actionSheet.tag = 3;
        actionSheet.title = NSLocalizedString(@"ENABLE WWAN MESSAGE", nil);
        
        [actionSheet addButtonWithTitle:NSLocalizedString(@"ENABLE WWAN ALWAYS", nil)];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"ENABLE WWAN ONCE", nil)];
        [actionSheet showInView:self.view];
        
    }];
    
}

- (void)enableWWANDownloading {
    
    STMSettingsController *settingsController = [[STMSessionManager sharedManager].currentSession settingsController];

    [settingsController setNewSettings:@{@"enableDownloadViaWWAN": @(YES)} forGroup:@"appSettings"];
    
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (actionSheet.tag) {

        case 1:
            if (buttonIndex == 0) {
                [self checkDownloadingConditions];
            }
            break;
            
        case 2:
            if (buttonIndex == 0) {
                [self stopPicturesDownloading];
            }
            break;

        case 3:
            if (buttonIndex == 0) {
                
                [self enableWWANDownloading];
                [self startPicturesDownloading];
                
            } else if (buttonIndex == 1) {

                [self startPicturesDownloading];

            }
            break;

        default:
            break;
    }
    
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (alertView.tag) {
            
        case 1:
            if (buttonIndex == 1) {
                [[STMAuthController authController] logout];
            }
            break;

        case 2:
            if (buttonIndex == 1) {
                [self checkDownloadingConditions];
            }
            break;

        case 3:
            if (buttonIndex == 1) {
                [self showEnableWWANActionSheet];
            }
            break;

        default:
            break;
            
    }
    
}


#pragma mark - labels setup

- (void)settingsChanged:(NSNotification *)notification {
    
    id firstKey = notification.userInfo.allKeys.firstObject;
    NSArray *observedSettings = @[@"locationTrackerAutoStart", @"blockIfNoLocationPermission", @"requestLocationServiceAuthorization"];
    
    if (firstKey && [observedSettings containsObject:firstKey]) {
        
        self.requestLocationServiceAuthorization = nil;
        
        [self setupLabels];
        [self checkLocationDisabled];
        
    }
    
}

- (void)setupLabels {
    
    self.nameLabel.text = [STMAuthController authController].userName;
    self.phoneNumberLabel.text = [STMAuthController authController].phoneNumber;
    self.progressBar.hidden = ([[STMSessionManager sharedManager].currentSession syncer].syncerState == STMSyncerIdle);
    
    self.locationWarningLabel.text = @"";
    
//    BOOL autoStart = self.locationTracker.trackerAutoStart;
//    
//    (autoStart) ? [self setupLocationLabels] : [self hideLocationLabels];

    [self setupLocationLabels];
    
}

- (void)hideLocationLabels {
    
    self.lastLocationLabel.text = @"";
    self.monitoringStatusLabel.text = @"";
    self.locationTrackingStatusLabel.text = @"";
    self.locationWarningLabel.text = @"";
    self.lastLocationImageView.hidden = YES;
    
}

- (void)setupLocationLabels {

    if (![self.requestLocationServiceAuthorization isEqualToString:@"noRequest"]) {

        BOOL isDriver = [[STMSettingsController stringValueForSettings:@"geotrackerControl" forGroup:@"location"] isEqualToString:GEOTRACKER_CONTROL_SHIPMENT_ROUTE];
        
        self.lastLocationImageView.hidden = NO;
        [self setupLastLocationLabel];
        [self setupLocationTrackingStatusLabel];
        
        if (isDriver) {
            self.monitoringStatusLabel.text = @"";
        } else {
            [self setupMonitoringStatusLabel];
        }

    } else {
        
        [self hideLocationLabels];
        
    }
    
}

- (void)setupLastLocationLabel {
    
    NSString *lastLocationTime;
    NSString *lastLocationLabelText;
    
    
    if (self.locationTracker.lastLocation) {
        
        lastLocationTime = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:self.locationTracker.lastLocation.timestamp];
//        lastLocationLabelText = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"LAST LOCATION", nil), lastLocationTime];
        lastLocationLabelText = lastLocationTime;
        
    } else {
        
        lastLocationLabelText = NSLocalizedString(@"NO LAST LOCATION", nil);
        
    }
    
    self.lastLocationLabel.textColor = [UIColor blackColor];
    self.lastLocationLabel.text = lastLocationLabelText;
    
}

- (void)setupLocationTrackingStatusLabel {
    
    UIColor *color;
    NSString *text;
    
    if ([CLLocationManager locationServicesEnabled]) {
        
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusAuthorizedAlways:
                color = ([self locationTracker].tracking) ? [UIColor greenColor] : [UIColor lightGrayColor];
                text = ([self locationTracker].tracking) ? NSLocalizedString(@"LOCATION IS TRACKING", nil) : NSLocalizedString(@"LOCATION IS NOT TRACKING", nil);
                break;
                
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                color = [UIColor brownColor];
                text = NSLocalizedString(@"LOCATIONS BACKGROUND OFF", nil);
                break;
                
            default:
                color = [UIColor redColor];
                text = NSLocalizedString(@"LOCATIONS OFF", nil);
                break;
        }
        
    } else {
        
        color = [UIColor redColor];
        text = NSLocalizedString(@"LOCATIONS OFF", nil);
        
    }

    self.locationTrackingStatusLabel.textColor = color;
    self.locationTrackingStatusLabel.text = text;

    [self checkLocationDisabled];
    
}

- (void)checkLocationDisabled {
    
    if (![self.requestLocationServiceAuthorization isEqualToString:@"noRequest"]) {
        
        if ([CLLocationManager locationServicesEnabled]) {
            
            switch ([CLLocationManager authorizationStatus]) {
                case kCLAuthorizationStatusAuthorizedAlways:
                    [self hideLocationDisabledAlert];
                    break;
                    
                default:
                    [self showLocationDisabledAlert];
                    break;
            }
            
        } else {
            [self showLocationDisabledAlert];
        }

    }

}

- (void)showLocationDisabledAlert {
    
    if ([self blockIfNoLocationPermission] && !self.locationDisabledAlertIsShown) {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            self.locationDisabledAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"NO LOCATION PERMISSION BLOCK TITLE", nil)
                                                                    message:NSLocalizedString(@"NO LOCATION PERMISSION BLOCK MESSAGE", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:nil
                                                          otherButtonTitles:nil];
            [self.locationDisabledAlert show];
            
        }];
        
        self.locationDisabledAlertIsShown = YES;

    } else if (![self blockIfNoLocationPermission] && self.locationDisabledAlertIsShown) {
        [self hideLocationDisabledAlert];
    }
        
}

- (void)hideLocationDisabledAlert {
    
    if (self.locationDisabledAlertIsShown) {
        
        [self.locationDisabledAlert dismissWithClickedButtonIndex:0 animated:NO];
        self.locationDisabledAlertIsShown = NO;
        
    }
    
}

- (BOOL)blockIfNoLocationPermission {
    
    NSDictionary *settings = [[self settingsController] currentSettingsForGroup:@"appSettings"];
    BOOL blockIfNoLocationPermission = [settings[@"blockIfNoLocationPermission"] boolValue];
    BOOL locationTrackerAutoStart = [self locationTracker].trackerAutoStart;
    
    return (blockIfNoLocationPermission && locationTrackerAutoStart);
    
}

- (void)setupMonitoringStatusLabel {
    
    UIColor *textColor = [UIColor blackColor];
    NSString *text = nil;
    
    if ([[self locationTracker] currentTimeIsInsideOfScheduleLimits]) {
        
        double finishTime = [self locationTracker].trackerFinishTime;
        NSString *finishTimeString = [[STMFunctions noDateShortTimeFormatterAllowZero:NO] stringFromDate:[STMFunctions dateFromDouble:finishTime]];

        text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"MONITORING IS TRACKING UNTIL", nil), finishTimeString];
                        
    } else {

        double startTime = [self locationTracker].trackerStartTime;
        NSString *startTimeString = [[STMFunctions noDateShortTimeFormatter] stringFromDate:[STMFunctions dateFromDouble:startTime]];

        text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"MONITORING WILL TRACKING AT", nil), startTimeString];
        
        textColor = [UIColor lightGrayColor];

    }
    
    self.monitoringStatusLabel.text = [NSString stringWithFormat:@"%@", text];
    
    self.monitoringStatusLabel.textColor = textColor;
    
}

- (void)currentAccuracyUpdated:(NSNotification *)notification {
    
    if (![self.requestLocationServiceAuthorization isEqualToString:@"noRequest"]) {
        
        BOOL isAccuracySufficient = [notification.userInfo[@"isAccuracySufficient"] boolValue];
        
        if (isAccuracySufficient) {
            
            self.locationWarningLabel.text = @"";
            
        } else {
            
            self.locationWarningLabel.textColor = [UIColor brownColor];
            self.locationWarningLabel.text = NSLocalizedString(@"ACCURACY IS NOT SUFFICIENT", nil);
            
        }

    }

}

- (void)locationTrackerStatusChanged {
    
    [self performSelector:@selector(setupLocationTrackingStatusLabel) withObject:nil afterDelay:5];
    [self performSelector:@selector(setupMonitoringStatusLabel) withObject:nil afterDelay:5];
    
}


#pragma mark - Reachability

- (void)startReachability {
    
    //    Reachability *reach = [Reachability reachabilityWithHostname:@"www.google.com"];
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
}

- (void)reachabilityChanged:(NSNotification *)notification {
    [self updateCloudImages];
}


#pragma mark - view lifecycle

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    STMSyncer *syncer = [self syncer];
    
    [nc addObserver:self
           selector:@selector(syncerStatusChanged:)
               name:@"syncStatusChanged"
             object:syncer];
    
    [nc addObserver:self
           selector:@selector(updateSyncInfo)
               name:@"sendFinished"
             object:syncer];

    [nc addObserver:self
           selector:@selector(updateSyncInfo)
               name:@"bunchOfObjectsSended"
             object:syncer];

    [nc addObserver:self
           selector:@selector(entityCountdownChange:)
               name:@"entityCountdownChange"
             object:syncer];

    [nc addObserver:self
           selector:@selector(syncerNewsHaveObjects:)
               name:@"syncerNewsHaveObjects"
             object:syncer];
    
    [nc addObserver:self
           selector:@selector(entitiesReceivingDidFinish)
               name:@"entitiesReceivingDidFinish"
             object:syncer];
    
    [nc addObserver:self
           selector:@selector(getBunchOfObjects:)
               name:NOTIFICATION_SYNCER_GET_BUNCH_OF_OBJECTS
             object:syncer];
    
    [nc addObserver:self
           selector:@selector(syncerDidChangeContent:)
               name:@"syncerDidChangeContent"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(socketAuthorizationSuccess)
               name:@"socketAuthorizationSuccess"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(newAppVersionAvailable:)
               name:@"newAppVersionAvailable"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(setupLabels)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(setupLastLocationLabel)
               name:@"lastLocationUpdated"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(currentAccuracyUpdated:)
               name:@"currentAccuracyUpdated"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(setupLocationLabels)
               name:[NSString stringWithFormat:@"locationTimersInit"]
             object:nil];
    
    [nc addObserver:self
           selector:@selector(hideLocationLabels)
               name:[NSString stringWithFormat:@"locationTimersRelease"]
             object:nil];
    
    [nc addObserver:self
           selector:@selector(locationTrackerStatusChanged)
               name:[NSString stringWithFormat:@"locationTrackerStatusChanged"]
             object:nil];
    
    [nc addObserver:self
           selector:@selector(reachabilityChanged:)
               name:kReachabilityChangedNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(nonloadedPicturesCountDidChange)
               name:@"nonloadedPicturesCountDidChange"
             object:[STMPicturesController sharedController]];
    
    [nc addObserver:self
           selector:@selector(settingsChanged:)
               name:@"appSettingsSettingsChanged"
             object:nil];

    [nc addObserver:self
           selector:@selector(settingsChanged:)
               name:@"locationSettingsChanged"
             object:nil];

    [nc addObserver:self
           selector:@selector(sessionStatusChanged)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:nil];
    
}

- (void)sessionStatusChanged {
    
    
    if ([[[STMSessionManager sharedManager].currentSession status] isEqualToString:@"running"]) {
    
        [self updateCloudImages];
        [self updateSyncDatesLabels];
        [self setupNonloadedPicturesButton];
        [self updateNonloadedPicturesInfo];

//        self.downloadAlertWasShown = NO;
    }

}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)customInit {
    
    self.navigationItem.title = [STMFunctions currentAppVersion];
    
    self.numberOfObjectLabel.text = @"";
    
    UIImage *image = [STMFunctions resizeImage:[UIImage imageNamed:@"exit-128.png"] toSize:CGSizeMake(22, 22)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(backButtonPressed)];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
    self.syncImageView = imageView;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:imageView];

//    self.lastLocationImageView.image = [self.lastLocationImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [self updateCloudImages];
    [self updateSyncDatesLabels];
    [self setupNonloadedPicturesButton];
    [self updateNonloadedPicturesInfo];
    
    [self addObservers];
    [self startReachability];
        
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self.navigationItem setHidesBackButton:YES animated:NO];
    [self customInit];

}

- (void)viewWillAppear:(BOOL)animated {
    
    [self setupLabels];
    
    [super viewWillAppear:animated];
    
    if ([STMRootTBC sharedRootVC].newAppVersionAvailable) {
        [[STMRootTBC sharedRootVC] newAppVersionAvailable:nil];
    }
    
    if ([STMPicturesController sharedController].downloadingPictures) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
