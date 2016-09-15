//
//  STMCoreWKWebViewVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STMEntitiesSubscribable.h"
#import "STMSoundCallbackable.h"
#import "STMBarCodeScanner.h"
#import "STMCheckinDelegate.h"


@interface STMCoreWKWebViewVC : UIViewController <STMEntitiesSubscribable, STMSoundCallbackable, STMCheckinDelegate>

@property (nonatomic, strong) NSDictionary *webViewStoryboardParameters;

- (NSString *)webViewAppManifestURI;
- (void)reloadWebView;

- (void)appManifestLoadFailWithErrorText:(NSString *)errorText;


@end
