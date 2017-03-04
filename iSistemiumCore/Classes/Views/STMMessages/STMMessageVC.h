//
//  STMMessageVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STMCoreDataModel.h"

@interface STMMessageVC : UIViewController

@property (nonatomic, strong) STMMessagePicture *picture;
@property (nonatomic, strong) NSString *text;

@end
