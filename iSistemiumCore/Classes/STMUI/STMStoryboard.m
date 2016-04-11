//
//  STMStoryboard.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMStoryboard.h"

@implementation STMStoryboard

+ (STMStoryboard *)storyboardWithName:(NSString *)name bundle:(NSBundle *)storyboardBundleOrNil {
    
    return (STMStoryboard *)[super storyboardWithName:name bundle:storyboardBundleOrNil];
    
}


@end
