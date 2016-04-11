//
//  STMBarCodeController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMBarCodeController.h"

#import "STMSoundController.h"
#import "STMObjectsController.h"


@implementation STMBarCodeController

#warning should override
/*
 + (NSArray <STMArticle *> *)articlesForBarcode:(NSString *)barcode {

    NSArray *barcodesArray = [self barcodesArrayForBarcodeClass:[STMArticleBarCode class] barcodeValue:barcode];

    if (barcodesArray.count > 0) {

        if (barcodesArray.count > 1) {
            NSLog(@"barcodesArray.count > 1");
        }

        NSMutableArray *result = @[].mutableCopy;
        
        for (STMArticleBarCode *articleBarCode in barcodesArray) {
            
            STMArticle *article = articleBarCode.article;
            
            if (article) {

                [result addObject:article];
                NSLog(@"article name %@", article.name);

            }
            
        }
        
        return result;

    } else {

//        [STMSoundController alertSay:NSLocalizedString(@"NO ARTICLES FOR THIS BARCODE", nil)];

//        [STMSoundController alertSay:NSLocalizedString(@"UNKNOWN BARCODE", nil)];
        NSLog(@"unknown barcode %@", barcode);
        
        return nil;

    }
    
}

+ (NSArray <STMStockBatch *> *)stockBatchForBarcode:(NSString *)barcode {

    NSArray *barcodesArray = [self barcodesArrayForBarcodeClass:[STMStockBatchBarCode class] barcodeValue:barcode];
    
    if (barcodesArray.count > 0) {
        
        if (barcodesArray.count > 1) {
            
            NSString *logMessage = [NSString stringWithFormat:@"More than one stockbatch barcodes for barcode: %@", barcode];
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
            
        }
        
        NSMutableArray *result = @[].mutableCopy;
        
        for (STMStockBatchBarCode *stockBatchBarCode in barcodesArray) {
            
            STMStockBatch *stockBatch = stockBatchBarCode.stockBatch;
            
            if (stockBatch) {
                
                [result addObject:stockBatch];
                NSLog(@"stockBatch name %@", stockBatch.article.name);
                
            }
            
        }
        
        return result;
        
    } else {
        
        NSLog(@"unknown barcode %@", barcode);
        return nil;
        
    }

}

+ (NSArray *)barcodesArrayForBarcodeClass:(Class)barcodeClass barcodeValue:(NSString *)barcodeValue {
    
    if ([barcodeClass isSubclassOfClass:[STMArticleBarCode class]] || [barcodeClass isSubclassOfClass:[STMStockBatchBarCode class]]) {
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:NSStringFromClass(barcodeClass)];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES selector:@selector(caseInsensitiveCompare:)]];
        if (barcodeValue) request.predicate = [NSPredicate predicateWithFormat:@"code == %@", barcodeValue];
        
        NSArray *barcodesArray = [[self document].managedObjectContext executeFetchRequest:request error:nil];
        
        return barcodesArray;

    } else {
        
        return nil;
        
    }
    
}
*/

+ (STMBarCodeScannedType)barcodeTypeFromTypes:(NSArray <STMBarCodeType *> *)types forBarcode:(NSString *)barcode {
    
    NSString *matchedType = nil;
    
    for (STMBarCodeType *barCodeType in types) {
        
        if (barCodeType.mask) {
            
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:(NSString * _Nonnull)barCodeType.mask
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:&error];
            
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:barcode
                                                                options:0
                                                                  range:NSMakeRange(0, barcode.length)];
            
            if (numberOfMatches > 0) {
                
                matchedType = barCodeType.type;
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

#warning should override
/*
+ (void)addBarcode:(NSString *)barcode toArticle:(STMArticle *)article {
    
    STMArticleBarCode *articleBarcode = (STMArticleBarCode *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMArticleBarCode class]) isFantom:NO];
    
    articleBarcode.code = barcode;
    articleBarcode.article = article;
    
    [[self document] saveDocument:^(BOOL success) {
        
    }];
    
}
*/


@end
