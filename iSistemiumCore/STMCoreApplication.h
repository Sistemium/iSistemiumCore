//
//  STMCoreApplication.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMStating.h"

@interface STMCoreApplication : UIApplication

+(STMCoreApplication *) sharedApplication;

@property(nonatomic) id<STMStating> states;

@end
