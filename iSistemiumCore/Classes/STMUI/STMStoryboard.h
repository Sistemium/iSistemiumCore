//
//  STMStoryboard.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface STMStoryboard : UIStoryboard

@property (nonatomic, strong) NSDictionary *parameters;

+ (STMStoryboard *)storyboardWithName:(NSString *)name bundle:(NSBundle *)storyboardBundleOrNil;

@end
