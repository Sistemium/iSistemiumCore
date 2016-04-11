//
//  STMWKWebViewVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 01/03/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STMEntitiesSubscribable.h"


@interface STMWKWebViewVC : UIViewController <STMEntitiesSubscribable>

- (void)reloadWebView;


@end
