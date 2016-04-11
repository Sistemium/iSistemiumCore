//
//  STMInsetLabel.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 18/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMInsetLabel.h"

@implementation STMInsetLabel

- (void)drawTextInRect:(CGRect)rect {
    
//    UIEdgeInsets insets = {5, 5, 5, 5};
    UIEdgeInsets insets = {LABEL_TOP_INSET, LABEL_LEFT_INSET, LABEL_BOTTOM_INSET, LABEL_RIGHT_INSET};
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
    
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
