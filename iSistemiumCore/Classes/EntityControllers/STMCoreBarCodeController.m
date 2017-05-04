//
//  STMCoreBarCodeController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreBarCodeController.h"

#import "STMSoundController.h"
#import "STMCoreObjectsController.h"


@implementation STMCoreBarCodeController

+ (STMBarCodeScannedType)barcodeTypeFromTypesDics:(NSArray <NSDictionary *> *)types forBarcode:(NSString *)barcode {
    
    NSString *matchedType = nil;
    
    for (NSDictionary *barCodeType in types) {
        
        if (barCodeType[@"mask"]) {
            
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:(NSString * _Nonnull)barCodeType[@"mask"]
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:&error];
            
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:barcode
                                                                options:0
                                                                  range:NSMakeRange(0, barcode.length)];
            
            if (numberOfMatches > 0) {
                
                matchedType = barCodeType[@"type"];
                break;
                
            }
            
        }
        
    }
    
    return [self barCodeScannedTypeForStringType:matchedType];

}


+ (STMBarCodeScannedType)barCodeScannedTypeForStringType:(NSString *)type {
    
    if ([type isEqualToString:@"Article"]) {
        
        return STMBarCodeTypeArticle;
        
    } else if ([type isEqualToString:@"StockBatch"]) {
        
        return STMBarCodeTypeStockBatch;
        
    } else if ([type isEqualToString:@"ExciseStamp"]) {
        
        return STMBarCodeTypeExciseStamp;
        
    } else {
        
        return STMBarCodeTypeUnknown;
        
    }
    
}

+ (NSString *)barCodeTypeStringForType:(STMBarCodeScannedType)type {
    
    NSString *typeString = nil;
    
    switch (type) {
        case STMBarCodeTypeUnknown: {
            typeString = @"Unknown";
            break;
        }
        case STMBarCodeTypeArticle: {
            typeString = @"Article";
            break;
        }
        case STMBarCodeTypeExciseStamp: {
            typeString = @"ExciseStamp";
            break;
        }
        case STMBarCodeTypeStockBatch: {
            typeString = @"StockBatch";
            break;
        }
    }

    return typeString;
    
}


@end
