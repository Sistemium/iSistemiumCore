//
//  UIToolbar+custom.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 21/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "UIToolbar+custom.h"
#import <objc/runtime.h>


@implementation UIToolbar (custom)

/**
 *      http://matteogobbi.github.io/blog/2014/12/15/extending-methods-in-a-category-by-method-swizzling/
 */

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self mg_extendsLayoutSubviews];
    });
    
}

+ (void)mg_extendsLayoutSubviews {
    
    Class thisClass = self;
    
    //layoutSubviews selector, method, implementation
    SEL layoutSubviewsSEL = @selector(layoutSubviews);
    Method layoutSubviewsMethod = class_getInstanceMethod(thisClass, layoutSubviewsSEL);
    IMP layoutSubviewsIMP = method_getImplementation(layoutSubviewsMethod);
    
    //mg_layoutSubviews selector, method, implementation
    SEL mg_layoutSubviewsSEL = @selector(mg_layoutSubviews);
    Method mg_layoutSubviewsMethod = class_getInstanceMethod(thisClass, mg_layoutSubviewsSEL);
    IMP mg_layoutSubviewsIMP = method_getImplementation(mg_layoutSubviewsMethod);
    
    //Try to add the method layoutSubviews with the new implementation (if already exists it'll return NO)
    BOOL wasMethodAdded = class_addMethod(thisClass, layoutSubviewsSEL, mg_layoutSubviewsIMP, method_getTypeEncoding(mg_layoutSubviewsMethod));
    
    if (wasMethodAdded) {
        //Just set the new selector points to the original layoutSubviews method
        class_replaceMethod(thisClass, mg_layoutSubviewsSEL, layoutSubviewsIMP, method_getTypeEncoding(layoutSubviewsMethod));
    } else {
        method_exchangeImplementations(layoutSubviewsMethod, mg_layoutSubviewsMethod);
    }

}


- (void)mg_layoutSubviews {
    
    [self mg_layoutSubviews];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"toolBarLayoutDone" object:self];
    
}


@end
