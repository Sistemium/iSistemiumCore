//
//  STMScanApiHelperDelegate.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 26/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ScanAPI/ScanApiHelper.h>

@protocol STMScanApiHelperDelegate <ScanApiHelperDelegate>

- (void)onButtonsEvent:(ISktScanObject *)scanObj;


@end
