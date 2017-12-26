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
#import "STMEntityController.h"
#import "STMCorePicturesController.h"

#import "STMCoreAuthController.h"
#import "STMCoreRootTBC.h"

#import "STMCoreUI.h"
#import "STMFunctions.h"

#import <Reachability/Reachability.h>

#import "iSistemiumCore-Swift.h"

#import "STMUserDefaults.h"


#define UPLOAD_FILE_NAME @"Upload To Cloud-100"
#define DOWNLOAD_FILE_NAME @"Download From Cloud-100"
#define NO_CONNECTION_FILE_NAME @"No connection Cloud-100"


@interface STMProfileVC ()

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
@property (nonatomic, strong) NSString *syncImageFileName;

@property (nonatomic) float totalEntityCount;
@property (nonatomic) int previousNumberOfObjects;

@property (nonatomic, strong) Reachability *internetReachability;

@property (nonatomic) BOOL downloadAlertWasShown;

@property (nonatomic, strong) STMSpinnerView *sendSpinner;
@property (nonatomic, strong) STMSpinnerView *receiveSpinner;

@property (nonatomic, strong) UIAlertController *locationDisabledAlert;
@property (nonatomic) BOOL locationDisabledAlertIsShown;

@property (nonatomic, strong) NSString *requestLocationServiceAuthorization;

@property (nonatomic) NSUInteger fantomsCount;


@end


@implementation STMProfileVC

- (STMCoreLocationTracker *)locationTracker {
    return [(STMCoreSession *)[STMCoreSessionManager sharedManager].currentSession locationTracker];
}

- (id <STMSyncer>)syncer {
    return [STMCoreSessionManager sharedManager].currentSession.syncer;
}

- (id <STMSettingsController>)settingsController {
    return [[STMCoreSessionManager sharedManager].currentSession settingsController];
}

- (id <STMCoreUserDefaults>)userDefaults {
    return [STMUserDefaults standardUserDefaults];
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

        UIAlertController *alertController = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"LOGOUT", nil)
                                        message:NSLocalizedString(@"R U SURE TO LOGOUT", nil)
                                        preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action){
                                       [[STMCoreAuthController authController] logout];
                                   }];
        
        UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"CANCEL", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {

                                   }];
        
        [alertController addAction:cancelAction];
        [alertController addAction:okAction];
        
        [self.tabBarController presentViewController:alertController animated:YES completion:nil];
        
    }];
    
}

- (void)hideProgressBar {
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        self.progressBar.hidden = YES;
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        
    }];
    
}

- (void)syncerReceiveStarted {
    
    if (!self.isViewLoaded || !self.view.window) {
        return;
    }
    
    self.totalEntityCount = (float)[STMEntityController stcEntities].allKeys.count;
    
    self.tabBarController.tabBar.userInteractionEnabled = [STMEntityController downloadableEntityReady];

    [self updateSyncInfo];
    
}

- (void)syncerReceiveFinished {
    
    if (!self.isViewLoaded || !self.view.window) {
        return;
    }
    
    [self updateSyncInfo];
    [self hideProgressBar];
    
    [STMCorePicturesController.sharedController checkPhotos];
    
    [self performSelector:@selector(hideNumberOfObjects)
               withObject:nil
               afterDelay:2];
    
}

- (void)updateSyncInfo {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self updateSyncDatesLabels];
        [self updateCloudImages];
        [self updateNonloadedPicturesInfo];
        [self checkSpinnerStates];
        
    });
    
}

- (void)updateUploadSyncProgressBar {

    // TODO: should be implemented later

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
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        [self hideProgressBar];
        [self setColorForSyncImageView];
        self.tabBarController.tabBar.userInteractionEnabled = [STMEntityController downloadableEntityReady];
        
    }];
    
    if (!self.downloadAlertWasShown) [self showDownloadAlert];
    
}


#pragma mark - cloud images for sync button

- (void)updateCloudImages {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self setImageForSyncImageView];
        [self setColorForSyncImageView];
        
    });
    
}

- (void)haveUnsyncedObjects {
    
    dispatch_async(dispatch_get_main_queue(), ^{

        NetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
        
        if (networkStatus == NotReachable || !self.syncer.transportIsReady) {
            
            self.syncImageFileName = UPLOAD_FILE_NAME;
            
            self.syncImageView.image = [[UIImage imageNamed:self.syncImageFileName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            
            UIColor *color = [UIColor redColor];
            color = [color colorWithAlphaComponent:0.3];
            
            self.syncImageView.tintColor = color;
            
            [self removeGestureRecognizersFromCloudImages];
            
        } else {
            
            self.syncImageView.tintColor = ACTIVE_BLUE_COLOR;

        }

    });
    
}

- (void)haveNoUnsyncedObjects {
    [self setImageForSyncImageView];
}

- (void)setImageForSyncImageView {
    
    if (self.syncer.transportIsReady) {

        self.syncImageFileName = DOWNLOAD_FILE_NAME;
        [self checkSpinnerStates];
        
    } else {
        
        if (![self.syncImageFileName isEqualToString:UPLOAD_FILE_NAME]) {
            self.syncImageFileName = NO_CONNECTION_FILE_NAME;
        }

    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.syncImageView.image = [[UIImage imageNamed:self.syncImageFileName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    });
    
}

- (void)checkSpinnerStates {
    
    (self.syncer.isSendingData) ? [self startSendSpinner] : [self stopSendSpinner];
    (self.syncer.isReceivingData) ? [self startReceiveSpinner] : [self stopReceiveSpinner];

}

- (void)startSendSpinner {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (!self.sendSpinner) {
            
            self.sendSpinner = [STMSpinnerView spinnerViewWithFrame:self.uploadImageView.bounds
                                                     indicatorStyle:UIActivityIndicatorViewStyleGray
                                                    backgroundColor:[UIColor whiteColor]
                                                               alfa:1];
            [self.uploadImageView addSubview:self.sendSpinner];
            
        }

    });

}

- (void)startReceiveSpinner {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (!self.receiveSpinner) {
            
            self.receiveSpinner = [STMSpinnerView spinnerViewWithFrame:self.downloadImageView.bounds
                                                        indicatorStyle:UIActivityIndicatorViewStyleGray
                                                       backgroundColor:[UIColor whiteColor]
                                                                  alfa:1];
            [self.downloadImageView addSubview:self.receiveSpinner];

        }
        
    });
    
}

- (void)stopSendSpinner {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.sendSpinner removeFromSuperview];
        self.sendSpinner = nil;
        
    });
    
}

- (void)stopReceiveSpinner {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.receiveSpinner removeFromSuperview];
        self.receiveSpinner = nil;
        
    });
    
}

- (void)setColorForSyncImageView {
    
    [self removeGestureRecognizersFromCloudImages];
    
    UIColor *color = (self.syncImageView.tintColor) ? self.syncImageView.tintColor : ACTIVE_BLUE_COLOR;
    SEL cloudTapSelector = @selector(downloadCloudTapped);
    
    NetworkStatus networkStatus = [self.internetReachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable || !self.syncer.transportIsReady) {
        
        color = [color colorWithAlphaComponent:0.3];
        [self.syncImageView setTintColor:color];
        
    } else {
        
        [self.syncImageView setTintColor:color];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:cloudTapSelector];
        [self.syncImageView addGestureRecognizer:tap];
        
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
            [self.syncer sendData];
        }
        
    }

}

- (void)uploadCloudTapped {
    [self.syncer sendData];
}

- (void)downloadCloudTapped {
    [self.syncer receiveData];
}


#pragma mark -

- (void)entitiesReceivingDidFinish {
    self.totalEntityCount = (float)[STMEntityController stcEntities].allKeys.count;
}

- (void)entityCountdownChange:(NSNotification *)notification {
    
    float countdownValue = [(notification.userInfo)[@"countdownValue"] floatValue];
    self.progressBar.hidden = NO;
    self.progressBar.progress = (self.totalEntityCount - countdownValue) / self.totalEntityCount;
    
}

- (void)getBunchOfObjects:(NSNotification *)notification {
    
    NSNumber *numberOfObjects = notification.userInfo[@"count"];
    
    numberOfObjects = @(self.previousNumberOfObjects + numberOfObjects.intValue);
    
    NSString *pluralType = [STMFunctions pluralTypeForCount:numberOfObjects.intValue];
    NSString *numberOfObjectsString = [pluralType stringByAppendingString:@"OBJECTS"];
    
    NSString *receiveString = ([pluralType isEqualToString:@"1"]) ? NSLocalizedString(@"RECEIVE1", nil) : NSLocalizedString(@"RECEIVE", nil);
    
    self.numberOfObjectLabel.text = [NSString stringWithFormat:@"%@ %@ %@", receiveString, numberOfObjects, NSLocalizedString(numberOfObjectsString, nil)];
    
    self.previousNumberOfObjects = numberOfObjects.intValue;
    
}

- (void)socketAuthorizationSuccess {
    [self updateCloudImages];
}

- (void)hideNumberOfObjects {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.previousNumberOfObjects = 0;
        self.numberOfObjectLabel.text = @"";
        
    });
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
    
    NSString *userID = [STMCoreAuthController authController].userID;
    
    if (!userID) return;
    
    NSString *key = [@"sendDate" stringByAppendingString:userID];
    NSString *sendDateString = [self.userDefaults objectForKey:key];
    
    key = [@"receiveDate" stringByAppendingString:userID];
    NSString *receiveDateString = [self.userDefaults objectForKey:key];
    
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
    self.unusedPicturesButton.hidden = YES;
    
}

- (void)updateNonloadedPicturesInfo {

    self.nonloadedPicturesButton.enabled = YES;
    
    NSUInteger unloadedPicturesCount = [STMCorePicturesController sharedController].nonloadedPicturesCount;
    
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
        if ([STMGarbageCollector.sharedInstance.unusedImageFiles count] == 0) {
            self.unusedPicturesButton.hidden = YES;
        }else{
            NSString *pluralString = [STMFunctions pluralTypeForCount:[STMGarbageCollector.sharedInstance.unusedImageFiles count]];
            NSString *picturesCount = [NSString stringWithFormat:@"%@UPICTURES", pluralString];
            NSString *unusedCount = [NSString stringWithFormat:@"%@UNUSED", pluralString];
            [self.unusedPicturesButton setTitle:[NSString stringWithFormat:NSLocalizedString(unusedCount, nil), (unsigned long) [STMGarbageCollector.sharedInstance.unusedImageFiles count], NSLocalizedString(picturesCount, nil)] forState:UIControlStateNormal];
            [self.unusedPicturesButton setTitle:[NSString stringWithFormat:NSLocalizedString(unusedCount, nil), (unsigned long) [STMGarbageCollector.sharedInstance.unusedImageFiles count], NSLocalizedString(picturesCount, nil)] forState:UIControlStateDisabled];
            self.unusedPicturesButton.hidden = NO;
        }
    });
    
}

- (void)nonloadedPicturesCountDidChange {
    [self updateNonloadedPicturesInfo];
}

- (IBAction)nonloadedPicturesButtonPressed:(id)sender {

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:nil
                                              message:NSLocalizedString(@"UNLOADED PICTURES", nil)
                                              preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *stopAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"DOWNLOAD STOP", nil)
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action){

                                       [self stopPicturesDownloading];
                                       
                                   }];
        
        UIAlertAction *closeAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"CLOSE", nil)
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action)
                                    {

                                    }];
        
        UIAlertAction *downloadNowAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"DOWNLOAD NOW", nil)
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction *action){
                                         
                                         [self checkDownloadingConditions];
                                         
                                     }];
        
        UIAlertAction *downloadLaterAction = [UIAlertAction
                                      actionWithTitle:NSLocalizedString(@"DOWNLOAD LATER", nil)
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *action)
                                      {
                                          
                                      }];
        
        if ([STMCorePicturesController sharedController].downloadingPictures) {

            [alertController addAction:stopAction];
            [alertController addAction:closeAction];
            

        } else {
            
            [alertController addAction:downloadNowAction];
            [alertController addAction:downloadLaterAction];

        }
        
        [alertController.popoverPresentationController setPermittedArrowDirections:0];
        
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = self.view.bounds;
        
        [self.tabBarController presentViewController:alertController animated:YES completion:nil];
        
    }];

}
- (IBAction)unusedPicturesButtonPressed:(id)sender {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:nil
                                              message:NSLocalizedString(@"UNUSED PICTURES", nil)
                                              preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *deleteAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"DELETE", nil)
                                     style:UIAlertActionStyleDestructive
                                     handler:^(UIAlertAction *action){
                                         
                                         [STMGarbageCollector.sharedInstance removeUnusedImages];
                                         self.unusedPicturesButton.enabled = NO;
                                         [self updateUnusedPicturesInfo];
                                         
                                     }];
        
        UIAlertAction *closeAction = [UIAlertAction
                                      actionWithTitle:NSLocalizedString(@"CLOSE", nil)
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *action)
                                      {
                                          
                                      }];
        
        [alertController addAction:deleteAction];
        [alertController addAction:closeAction];
        
        [alertController.popoverPresentationController setPermittedArrowDirections:0];
        
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = self.view.bounds;
        
        [self.tabBarController presentViewController:alertController animated:YES completion:nil];
        
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
    
    [STMCorePicturesController.sharedController checkPhotos];
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
    
    NSUInteger unloadedPicturesCount = [STMCorePicturesController sharedController].nonloadedPicturesCount;
    
    if (unloadedPicturesCount > 0) {
        
        NSString *pluralString = [STMFunctions pluralTypeForCount:unloadedPicturesCount];
        NSString *picturesCount = [NSString stringWithFormat:@"%@UPICTURES", pluralString];
        NSString *title = [NSString stringWithFormat:@"%lu %@ %@. %@", (unsigned long)unloadedPicturesCount, NSLocalizedString(picturesCount, nil), NSLocalizedString(@"WAITING FOR DOWNLOAD", nil), NSLocalizedString(@"DOWNLOAD IT NOW?", nil)];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:NSLocalizedString(@"UNLOADED PICTURES", nil)
                                                  message:title
                                                  preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *noAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"NO", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action){

                                       }];
            
            UIAlertAction *yesAction = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"YES", nil)
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action)
                                           {
                                               [self checkDownloadingConditions];
                                           }];
            
            [alertController addAction:noAction];
            [alertController addAction:yesAction];
            
            [self.tabBarController presentViewController:alertController animated:YES completion:nil];
        
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
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:nil
                                              message:NSLocalizedString(@"ENABLE WWAN MESSAGE", nil)
                                              preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *enableAlwaysAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ENABLE WWAN ALWAYS", nil)
                                       style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction *action){
                                           
                                           [self enableWWANDownloading];
                                           [self startPicturesDownloading];
                                           
                                       }];
        
        UIAlertAction *enableOnceAction = [UIAlertAction
                                      actionWithTitle:NSLocalizedString(@"ENABLE WWAN ONCE", nil)
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *action)
                                      {
                                          
                                          [self startPicturesDownloading];
                                          
                                      }];
        
        [alertController addAction:enableAlwaysAction];
        [alertController addAction:enableOnceAction];
        
        [alertController.popoverPresentationController setPermittedArrowDirections:0];
        
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = self.view.bounds;
        
        [self.tabBarController presentViewController:alertController animated:YES completion:nil];
        
    }];
    
}

- (void)enableWWANDownloading {
    
    id <STMSettingsController> settingsController = [[STMCoreSessionManager sharedManager].currentSession settingsController];

    [settingsController setNewSettings:@{@"enableDownloadViaWWAN": @(YES)} forGroup:@"appSettings"];
    
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

    BOOL syncerIsIdle = YES;
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
        
        id <STMSettingsController> settings = STMCoreSessionManager.sharedManager.currentSession.settingsController;

        BOOL isDriver = [[settings stringValueForSettings:@"geotrackerControl" forGroup:@"location"] isEqualToString:GEOTRACKER_CONTROL_SHIPMENT_ROUTE];
        
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
            
            self.locationDisabledAlert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"NO LOCATION PERMISSION BLOCK TITLE", nil)
                message:NSLocalizedString(@"NO LOCATION PERMISSION BLOCK MESSAGE", nil)
                preferredStyle:UIAlertControllerStyleAlert];
            
            [self.tabBarController presentViewController:self.locationDisabledAlert animated:YES completion:nil];
            
        }];
        
        self.locationDisabledAlertIsShown = YES;

    } else if (![self blockIfNoLocationPermission] && self.locationDisabledAlertIsShown) {
        [self hideLocationDisabledAlert];
    }
        
}

- (void)hideLocationDisabledAlert {
    
    if (self.locationDisabledAlertIsShown) {
        
        [self.locationDisabledAlert dismissViewControllerAnimated:YES completion:nil];
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
    
    [nc addObserver:self
           selector:@selector(updateSyncInfo)
               name:NOTIFICATION_SYNCER_SEND_STARTED
             object:nil];

//    [nc addObserver:self
//           selector:@selector(updateUploadSyncProgressBar)
//               name:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENT
//             object:self.syncer];
    
    [nc addObserver:self
           selector:@selector(updateSyncInfo)
               name:NOTIFICATION_SYNCER_SEND_FINISHED
             object:nil];

    [nc addObserver:self
           selector:@selector(haveUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_UNSYNCED_OBJECTS
             object:nil];

    [nc addObserver:self
           selector:@selector(haveNoUnsyncedObjects)
               name:NOTIFICATION_SYNCER_HAVE_NO_UNSYNCED_OBJECTS
             object:nil];

    [nc addObserver:self
           selector:@selector(syncerReceiveStarted)
               name:NOTIFICATION_SYNCER_RECEIVE_STARTED
             object:nil];

    [nc addObserver:self
           selector:@selector(getBunchOfObjects:)
               name:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
             object:nil];

    [nc addObserver:self
           selector:@selector(syncerReceiveFinished)
               name:NOTIFICATION_SYNCER_RECEIVE_FINISHED
             object:nil];

    [nc addObserver:self
           selector:@selector(entityCountdownChange:)
               name:NOTIFICATION_SYNCER_ENTITY_COUNTDOWN_CHANGE
             object:nil];
    
    [nc addObserver:self
           selector:@selector(entitiesReceivingDidFinish)
               name:NOTIFICATION_SYNCER_RECEIVED_ENTITIES
             object:nil];
    
    [nc addObserver:self
           selector:@selector(socketAuthorizationSuccess)
               name:NOTIFICATION_SOCKET_AUTHORIZATION_SUCCESS
             object:nil];
    
    [nc addObserver:self
           selector:@selector(newAppVersionAvailable:)
               name:NOTIFICATION_NEW_VERSION_AVAILABLE
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
               name:NOTIFICATION_PICTURE_UNUSED_CHANGE
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
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithCustomView:imageView];
    NSLayoutConstraint * widthConstraint = [NSLayoutConstraint constraintWithItem:imageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:22];
    NSLayoutConstraint * heightConstraint = [NSLayoutConstraint constraintWithItem:imageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:22];
    self.navigationItem.rightBarButtonItem = button;
    [widthConstraint setActive:YES];
    [heightConstraint setActive:YES];
    

//    self.lastLocationImageView.image = [self.lastLocationImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [self updateCloudImages];
    [self updateSyncDatesLabels];
    [self setupNonloadedPicturesButton];
    [self updateNonloadedPicturesInfo];
    [self setupUnusedPicturesButton];
    
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
    
    [STMCorePicturesController.sharedController checkPhotos];
    
    [self updateSyncInfo];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [STMFunctions nilifyViewForVC:self];
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
