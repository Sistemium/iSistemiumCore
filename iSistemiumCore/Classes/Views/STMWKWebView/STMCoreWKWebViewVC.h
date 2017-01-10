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

@property (nonatomic, strong) NSString *subscribeDataCallbackJSFunction;

@property (nonatomic, strong) NSDictionary *webViewStoryboardParameters;
@property (nonatomic) BOOL haveLocalHTML;

- (NSString *)webViewAppManifestURI;
- (void)reloadWebView;

- (void)appManifestLoadErrorText:(NSString *)errorText;
- (void)appManifestLoadInfoText:(NSString *)infoText;
- (void)localHTMLUpdateIsAvailable;

- (void)loadUrl:(NSURL *)fileUrl atBaseDir:(NSString *)baseDir;
- (void)loadHTML:(NSString *)html atBaseDir:(NSString *)baseDir;

- (void)callbackWithData:(NSArray *)data
              parameters:(NSDictionary *)parameters;

- (void)callbackWithData:(id)data
              parameters:(NSDictionary *)parameters
      jsCallbackFunction:(NSString *)jsCallbackFunction;

- (void)callbackWithError:(NSString *)errorDescription
               parameters:(NSDictionary *)parameters;


@end
