//
//  STMSpinnerView.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMSpinnerView.h"

@implementation STMSpinnerView

+ (STMSpinnerView *)spinnerViewWithFrame:(CGRect)frame {
    
    return [self spinnerViewWithFrame:frame
                       indicatorStyle:UIActivityIndicatorViewStyleWhiteLarge
                      backgroundColor:[UIColor grayColor]
                                 alfa:0.75];
    
}

+ (STMSpinnerView *)spinnerViewWithFrame:(CGRect)frame indicatorStyle:(UIActivityIndicatorViewStyle)style backgroundColor:(UIColor *)color alfa:(CGFloat)alfa {
    
    STMSpinnerView *view = [[STMSpinnerView alloc] initWithFrame:frame];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = color;
    view.alpha = alfa;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    spinner.center = view.center;
    spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [spinner startAnimating];
    [view addSubview:spinner];
    
    return view;
    
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
