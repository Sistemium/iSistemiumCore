//
//  STMUIBarButtonItem.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 16/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface STMBarButtonItem : UIBarButtonItem

+ (STMBarButtonItem *)flexibleSpace;
+ (STMBarButtonItem *)fixedSpaceWithWidth:(CGFloat)width;


@end

@interface STMBarButtonItemEdit : STMBarButtonItem

@end

@interface STMBarButtonItemDelete : STMBarButtonItem

@end

@interface STMBarButtonItemDone : STMBarButtonItem

@end

@interface STMBarButtonItemCancel : STMBarButtonItem

@end

@interface STMBarButtonItemLabel : STMBarButtonItem

@end
