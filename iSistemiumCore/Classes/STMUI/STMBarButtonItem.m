//
//  STMUIBarButtonItem.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 16/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMBarButtonItem.h"
#import "STMConstants.h"

@implementation STMBarButtonItemDone

@end


@implementation STMBarButtonItemCancel

@end


@implementation STMBarButtonItemEdit

@end


@implementation STMBarButtonItemDelete

@end


@implementation STMBarButtonItemLabel

@end


@implementation STMBarButtonItem

+ (STMBarButtonItem *)flexibleSpace {
    
    STMBarButtonItem *flexibleSpace = [[STMBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    return flexibleSpace;
    
}

+ (STMBarButtonItem *)fixedSpaceWithWidth:(CGFloat)width {

    STMBarButtonItem *fixedSpace = [[STMBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedSpace.width = width;
    
    return fixedSpace;

}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (void)awakeFromNib {
    
    [super awakeFromNib];
    
    [self customInit];
    
}

- (void)customInit {

    UIColor *color = ACTIVE_BLUE_COLOR;
    NSDictionary *textAttributes = @{NSForegroundColorAttributeName:color};
    [self setTitleTextAttributes:textAttributes forState:UIControlStateNormal];

    color = GREY_LINE_COLOR;
    textAttributes = @{NSForegroundColorAttributeName:color};
    [self setTitleTextAttributes:textAttributes forState:UIControlStateDisabled];

    if ([self isKindOfClass:[STMBarButtonItemDone class]]) {
        
        UIFont *font = [UIFont boldSystemFontOfSize:17];
        NSDictionary *textAttributes = @{NSFontAttributeName:font};
        [self setTitleTextAttributes:textAttributes forState:UIControlStateNormal];
        
    } else if ([self isKindOfClass:[STMBarButtonItemCancel class]]) {
        
    } else if ([self isKindOfClass:[STMBarButtonItemEdit class]]) {
        
    } else if ([self isKindOfClass:[STMBarButtonItemDelete class]]) {
        
        UIColor *color = [UIColor redColor];
        NSDictionary *textAttributes = @{NSForegroundColorAttributeName:color};
        [self setTitleTextAttributes:textAttributes forState:UIControlStateNormal];
        
    } else if ([self isKindOfClass:[STMBarButtonItemLabel class]]) {
        
        UIColor *color = [UIColor blackColor];
        NSDictionary *textAttributes = @{NSForegroundColorAttributeName:color};
        [self setTitleTextAttributes:textAttributes forState:UIControlStateDisabled];
        
        self.tintColor = color;
        
        self.enabled = NO;
        
    }

}

- (void)setTintColor:(UIColor *)tintColor {
    
    [super setTintColor:tintColor];
    
    if (tintColor) {
        
        NSDictionary *textAttributes = @{NSForegroundColorAttributeName:tintColor};
        [self setTitleTextAttributes:textAttributes forState:UIControlStateNormal];

    }
    
}


@end
