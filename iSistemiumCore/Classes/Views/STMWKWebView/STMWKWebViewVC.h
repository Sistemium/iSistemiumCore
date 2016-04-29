//
//  STMWKWebViewVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STMEntitiesSubscribable.h"
#import "STMSoundCallbackable.h"


@interface STMWKWebViewVC : UIViewController <STMEntitiesSubscribable, STMSoundCallbackable>

- (void)reloadWebView;


@end
