//
//  STMIdleTimerController.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 23/09/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMIdleTimerController : NSObject

+ (void)sender:(NSString *)senderName askIdleTimerDisabled:(BOOL)disabled;

@end
