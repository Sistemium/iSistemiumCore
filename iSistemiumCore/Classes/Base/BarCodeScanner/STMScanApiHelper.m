//
//  STMScanApiHelper.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 26/02/16.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMScanApiHelper.h"


@implementation STMScanApiHelper

- (SKTRESULT)handleEvent:(ISktScanObject *)scanObj {
    
    SKTRESULT result = [super handleEvent:scanObj];
    
    switch ([[[scanObj Msg] Event] ID]) {

        case kSktScanEventButtons: {
            
            SEL selector = @selector(onButtonsEvent:);
         
            if ((_delegate != nil) && ([_delegate respondsToSelector:selector])) {
                
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [_delegate performSelector:selector withObject:scanObj];
                
            }

        }
            break;
            
        default:
            break;
            
    }
    
    return result;
    
}




@end
