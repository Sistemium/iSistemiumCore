//
//  STMCustom6TVCell.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCustom6TVCell.h"

@implementation STMCustom6TVCell

- (CGFloat)heightLimiter {
    return [self constraintForIdentifier:@"heightLimiter"].constant;
}
- (void)setHeightLimiter:(CGFloat)newValue {
    [self constraintForIdentifier:@"heightLimiter"].constant = newValue;
}

-(NSLayoutConstraint *)constraintForIdentifier:(NSString *)identifier {
    for (UIView *view in self.contentView.subviews){
        for (NSLayoutConstraint *constraint in view.constraints) {
            if ([constraint.identifier isEqualToString:identifier]) {
                return constraint;
            }
        }
    }
    return nil;
}

@end
