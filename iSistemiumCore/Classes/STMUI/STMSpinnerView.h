//
//  STMSpinnerView.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/02/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface STMSpinnerView : UIView

+ (STMSpinnerView *)spinnerViewWithFrame:(CGRect)frame;
+ (STMSpinnerView *)spinnerViewWithFrame:(CGRect)frame indicatorStyle:(UIActivityIndicatorViewStyle)style backgroundColor:(UIColor *)color alfa:(CGFloat)alfa;


@end
