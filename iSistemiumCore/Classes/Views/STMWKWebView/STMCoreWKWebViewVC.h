//
//  STMCoreWKWebViewVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STMSoundCallbackable.h"
#import "STMBarCodeScanner.h"
#import "STMCheckinDelegate.h"
#import "STMScriptMessaging.h"

@interface STMCoreWKWebViewVC : UIViewController <STMSoundCallbackable, STMCheckinDelegate, STMScriptMessagingOwner>

@property (nonatomic, strong) NSDictionary *webViewStoryboardParameters;
@property (nonatomic) BOOL haveLocalHTML;
@property (nonatomic) NSString *directLoadUrl;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

- (NSString *)webViewAppManifestURI;
- (void)reloadWebView;

- (void)appManifestLoadErrorText:(NSString *)errorText;
- (void)appManifestLoadInfoText:(NSString *)infoText;
- (void)localHTMLUpdateIsAvailable;

- (void)loadUrl:(NSURL *)fileUrl atBaseDir:(NSString *)baseDir;
- (void)loadHTML:(NSString *)html atBaseDir:(NSString *)baseDir;

@end
