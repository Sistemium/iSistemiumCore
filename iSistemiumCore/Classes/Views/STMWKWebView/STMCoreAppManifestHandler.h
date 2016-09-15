//
//  STMCoreAppManifestHandler.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 15/09/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMCoreWKWebViewVC.h"


@interface STMCoreAppManifestHandler : NSObject

+ (void)loadLocalHTMLWithOwner:(STMCoreWKWebViewVC *)owner;


@end
