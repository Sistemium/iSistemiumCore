//
//  STMProfileVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 04/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMProfileVC.h"

#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"

#import "STMCoreLocationTracker.h"
#import "STMSyncer.h"
#import "STMEntityController.h"
#import "STMCorePicturesController.h"
#import "STMSocketController.h"

#import "STMCoreAuthController.h"
#import "STMCoreRootTBC.h"

#import "STMCoreUI.h"
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

@property (weak, nonatomic) IBOutlet UIButton *unusedPicturesButton;

@property (weak, nonatomic) IBOutlet UIImageView *uploadImageView;
@property (weak, nonatomic) IBOutlet UIImageView *downloadImageView;
@property (weak, nonatomic) IBOutlet UIImageView *lastLocationImageView;

@property (weak, nonatomic) UIImageView *syncImageView;

@property (nonatomic) float totalEntityCount;
@property (nonatomic) int previousNumberOfObjects;

@property (nonatomic, strong) Reachability *internetReachability;

@property (nonatomic) BOOL downloadAlertWasShown;
@property (nonatomic) BOOL newsReceiving;

@property (nonatomic, strong) STMSpinnerView *syncSpinner;

@property (nonatomic, strong) UIAlertView *locationDisabledAlert;
@property (nonatomic) BOOL locationDisabledAlertIsShown;

@property (nonatomic, strong) NSString *requestLocationServiceAuthorization;

@property (nonatomic) NSUInteger fantomsCount;


@end


@implementation STMProfileVC

- (STMCoreLocationTracker *)locationTracker {
    return [(STMCoreSession *)[STMCoreSessionManager sharedManager].currentSession locationTracker];
}

- (STMSyncer *)syncer {
    return [[STMCoreSessionManager sharedManager].currentSession syncer];
}

- (STMCoreSettingsController *)settingsController {
    return [[STMCoreSessionManager sharedManager].currentSession settingsController];
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

            self.progressBar.progress = 1.0;
            [self performSelector:@selector(hideProgressBar)
                       withObject:nil
                       afterDelay:0];
            
            if (!self.downloadAlertWasShown) [self showDownloadAlert];
            
        } else {
            
            self.progressBar.hidden = NO;
            [UIApplication sharedApplication].idleTimerDisabled = YES;
            self.totalEntityCount = 1;
            
        }
        
        if (fromState == STMSyncerReceiveData) {
            
            [self performSelector:@selector(hideNumberOfObjects)
                       withObject:nil
                       afterDelay:5];
            
        }
        
    }
    
    [self stopSyncSpinner];

    [self updateSyncInfo];
    
}

- (void)hideProgressBar {
    
    self.progressBar.hidden = YES;
    [UIApplication sharedApplication].idleTimerDisabled = NO;

}

- (void)updateSyncInfo {
    
    [self updateSyncDatesLabels];
    [self updateCloudImages];
    [self updateNonloadedPicturesInfo];

}

- (void)updateUploadSyncProgressBar {
    
    STMSyncer *syncer = [self syncer];
    
    if (syncer.syncerState == STMSyncerSendData || syncer.syncerState == STMSyncerSendDataOnce) {
        
        float allUnsyncedObjectsCount = (float)[syncer numbersOfAllUnsyncedObjects];
        float currentlyUnsyncedObjectsCount = (float)[syncer numberOfCurrentlyUnsyncedObjects];
        
        if (allUnsyncedObjectsCount > 0) {
            
            self.progressBar.hidden = NO;
            self.progressBar.progress = (allUnsyncedObjectsCount - currentlyUnsyncedObjectsCount) / allUnsyncedObjectsCount;
            
        }

    }
    
}

- (void)defantomizingProgressBarStart:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setColorForSyncImageView];

        self.fantomsCount = [notification.userInfo[@"fantomsCount"] integerValue];
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        self.progressBar.hidden = NO;
        self.progressBar.progress = 0.0;
    });
    
}

- (void)defantomizingProgressBarUpdate:(NSNotification *)notification {

    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger currentFantomsCount = [notification.userInfo[@"fantomsCount"] integerValue];
        self.progressBar.hidden = NO;
        self.progressBar.progress = (self.fantomsCount - currentFantomsCount) / (float)self.fantomsCount;
    });
}

- (void)defantomizingProgressBarFinish {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(hideProgressBar)
                   withObject:nil
                   afterDelay:0];
        
        [self setColorForSyncImageView];
    });
}


#pragma mark - cloud images for sync button

- (void)updateCloudImages {
    
    [self setImageForSyncImageView];
    [self setColorForSyncImageView];
    
}

- (void)setImageForSyncImageView {
    
    STMSyncer *syncer = [self syncer];
    
    NSString *imageName = nil;
    
    if ([STMSocketController socketIsAvailable]) {
        
        switch (syncer.syncerState) {
            case STMSyncerIdle: {

                imageName = ([syncer numbersOfAllUnsyncedObjects] > 0) ? @"Upload To Cloud-100" : @"Download From Cloud-100";
                break;
                
            }
            case STMSyncerSendData:
            case STMSyncerSendDataOnce: {

                if (!self.syncSpinner) {
                    [self startSyncSpinnerInView:self.uploadImageView];
                }
                
                imageName = @"Upload To Cloud-100";
                break;
                
            }
            case STMSyncerReceiveData: {

                if (!self.syncSpinner) {
                    [self startSyncSpinnerInView:self.downloadImageView];
                }
                
                imageName = @"Download From Cloud-100";
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

- (void)startSyncSpinnerInView:(UIView *)view {
    
    self.syncSpinner = [STMSpinnerView spinnerViewWithFrame:view.bounds
                                         indicatorStyle:UIActivityIndicatorViewStyleGray
                                        backgroundColor:[UIColor whiteColor]
                                                   alfa:1];
    [view addSubview:self.syncSpinner];

}

- (void)stopSyncSpinner {
    
    [self.syncSpinner removeFromSuperview];
    self.syncSpinner = nil;

}

- (void)setColorForSyncImageView {
    
    [self removeGestureRecognizersFromCloudImages];
    
    STMSyncer *syncer = [self syncer];
    BOOL hasObjectsToUpload = ([syncer numbersOfAllUnsyncedObjects] > 0);
    UIColor *color = (hasObjectsToUpload) ? [UIColor redColor] : ACTIVE_BLUE_COLOR;
    SEL cloudTapSelector = (hasObjectsToUpload) ? @selector(uploadCloudTapped) : @selector(downloadCloudTapped);
    
    NetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable || ![STMSocketController socketIsAvailable]) {
        
        color = [color colorWithAlphaComponent:0.3];
        [self.syncImageView setTintColor:color];
        
    } else {
        
        if (syncer.syncerState == STMSyncerIdle/* && ![STMCoreObjectsController isDefantomizingProcessRunning]*/) {
            
            [self.syncImageView setTintColor:color];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                  action:cloudTapSelector];
            [self.syncImageView addGestureRecognizer:tap];
            
            if (hasObjectsToUpload) {
                
                UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                        action:@selector(uploadCloudLongPressed:)];
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
        self.progressBar.hidden = NO;
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
            
            self.progressBar.hidden = NO;
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
    
    if ([[[STMCoreSessionManager sharedManager].currentSession syncer] syncerState] != STMSyncerReceiveData) {
        
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
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"sendDate" stringByAppendingString:[STMCoreAuthController authController].userID];
    NSString *sendDateString = [defaults objectForKey:key];
    
    key = [@"receiveDate" stringByAppendingString:[STMCoreAuthController authController].userID];
    NSString *receiveDateString = [defaults objectForKey:key];
    
    self.sendDateLabel.text = (sendDateString) ? sendDateString : nil;
    self.receiveDateLabel.text = (receiveDateString) ? receiveDateString : nil;
    
}

- (void)setupNonloadedPicturesButton {
    
    [self.nonloadedPicturesButton setTitleColor:ACTIVE_BLUE_COLOR forState:UIControlStateNormal];
    [self.nonloadedPicturesButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    
}

- (void)setupUnusedPicturesButton {
    
    [self.unusedPicturesButton setTitleColor:ACTIVE_BLUE_COLOR forState:UIControlStateNormal];
    [self.unusedPicturesButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    
}

- (void)updateNonloadedPicturesInfo {

    self.nonloadedPicturesButton.enabled = ([self syncer].syncerState == STMSyncerIdle);
    
    NSUInteger unloadedPicturesCount = [[STMCorePicturesController sharedController] nonloadedPicturesCount];
    
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
        
        [STMCorePicturesController sharedController].downloadingPictures = NO;
        [UIApplication sharedApplication].idleTimerDisabled = NO;

    }
    
    [self.nonloadedPicturesButton setTitle:title forState:UIControlStateNormal];
    self.navigationController.tabBarItem.badgeValue = badgeValue;
    
    UIColor *titleColor = [STMCorePicturesController sharedController].downloadingPictures ? ACTIVE_BLUE_COLOR : [UIColor redColor];
    [self.nonloadedPicturesButton setTitleColor:titleColor forState:UIControlStateNormal];
    
}

- (void)updateUnusedPicturesInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([STMGarbageCollector.unusedImageFiles count] == 0) {
            self.unusedPicturesButton.hidden = YES;
        }else{
            NSString *pluralString = [STMFunctions pluralTypeForCount:[STMGarbageCollector.unusedImageFiles count]];
            NSString *picturesCount = [NSString stringWithFormat:@"%@UPICTURES", pluralString];
            NSString *unusedCount = [NSString stringWithFormat:@"%@UNUSED", pluralString];
            [self.unusedPicturesButton setTitle:[NSString stringWithFormat:NSLocalizedString(unusedCount, nil), (unsigned long) [STMGarbageCollector.unusedImageFiles count], NSLocalizedString(picturesCount, nil)] forState:UIControlStateNormal];
            [self.unusedPicturesButton setTitle:[NSString stringWithFormat:NSLocalizedString(unusedCount, nil), (unsigned long) [STMGarbageCollector.unusedImageFiles count], NSLocalizedString(picturesCount, nil)] forState:UIControlStateDisabled];
        }
    });
    
}

- (void)nonloadedPicturesCountDidChange {
    [self updateNonloadedPicturesInfo];
}

- (IBAction)nonloadedPicturesButtonPressed:(id)sender {

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
        actionSheet.title = NSLocalizedString(@"UNLOADED PICTURES", nil);
        actionSheet.delegate = self;

        if ([STMCorePicturesController sharedController].downloadingPictures) {
        
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
- (IBAction)unusedPicturesButtonPressed:(id)sender {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
        actionSheet.tag = 4;
        actionSheet.title = NSLocalizedString(@"UNUSED PICTURES", nil);
        actionSheet.delegate = self;
        actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"DELETE", nil)];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"CLOSE", nil)];
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
    
    [STMCorePicturesController checkPhotos];
    [STMCorePicturesController sharedController].downloadingPictures = YES;
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    [self updateNonloadedPicturesInfo];
    
}

- (void)stopPicturesDownloading {
    
    [STMCorePicturesController sharedController].downloadingPictures = NO;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self updateNonloadedPicturesInfo];

}

- (void)showDownloadAlert {
    
    NSUInteger unloadedPicturesCount = [[STMCorePicturesController sharedController] nonloadedPicturesCount];
    
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
    
    STMCoreSettingsController *settingsController = [[STMCoreSessionManager sharedManager].currentSession settingsController];

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
        case 4:
            if (buttonIndex == 0) {
                
                [STMGarbageCollector removeUnusedImages];
                self.unusedPicturesButton.enabled = NO;
                [self updateUnusedPicturesInfo];
                
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
                [[STMCoreAuthController authController] logout];
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

        case 4:
            if (buttonIndex == 0) {
                [STMGarbageCollector removeUnusedImages];
                self.unusedPicturesButton.enabled = NO;
                [self updateUnusedPicturesInfo];
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
    
    self.nameLabel.text = [STMCoreAuthController authController].userName;
    self.phoneNumberLabel.text = [STMCoreAuthController authController].phoneNumber;

    BOOL syncerIsIdle = ([[STMCoreSessionManager sharedManager].currentSession syncer].syncerState == STMSyncerIdle);
    self.progressBar.hidden = syncerIsIdle;
    [UIApplication sharedApplication].idleTimerDisabled = !syncerIsIdle;
    
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

        BOOL isDriver = [[STMCoreSettingsController stringValueForSettings:@"geotrackerControl" forGroup:@"location"] isEqualToString:GEOTRACKER_CONTROL_SHIPMENT_ROUTE];
        
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

    } else {
        [self showLocationDisabledAlert];
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
               name:NOTIFICATION_SYNCER_STATUS_CHANGED
             object:syncer];
    
    [nc addObserver:self
           selector:@selector(updateSyncInfo)
               name:@"sendFinished"
             object:syncer];

    [nc addObserver:self
           selector:@selector(updateUploadSyncProgressBar)
               name:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENDED
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
               name:NOTIFICATION_SYNCER_DID_CHANGE_CONTENT
             object:nil];
    
    [nc addObserver:self
           selector:@selector(socketAuthorizationSuccess)
               name:NOTIFICATION_SOCKET_AUTHORIZATION_SUCCESS
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
             object:[STMCorePicturesController sharedController]];
    
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
    
    [nc addObserver:self
           selector:@selector(updateUnusedPicturesInfo)
               name:@"unusedImageRemoved"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(defantomizingProgressBarStart:)
               name:NOTIFICATION_DEFANTOMIZING_START
             object:nil];
    
    [nc addObserver:self
           selector:@selector(defantomizingProgressBarUpdate:)
               name:NOTIFICATION_DEFANTOMIZING_UPDATE
             object:nil];

    [nc addObserver:self
           selector:@selector(defantomizingProgressBarFinish)
               name:NOTIFICATION_DEFANTOMIZING_FINISH
             object:nil];

}

- (void)sessionStatusChanged {
    
    
    if ([STMCoreSessionManager sharedManager].currentSession.status == STMSessionRunning) {
    
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
    [self setupUnusedPicturesButton];
    [self updateUnusedPicturesInfo];
    
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
    
    if ([STMCoreRootTBC sharedRootVC].newAppVersionAvailable) {
        [[STMCoreRootTBC sharedRootVC] newAppVersionAvailable:nil];
    }
    
    if ([STMCorePicturesController sharedController].downloadingPictures) {
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
