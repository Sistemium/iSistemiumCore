//
//  STMCoreBarCodeController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreBarCodeController.h"
#import "STMLogger.h"


@implementation STMCoreBarCodeController

+ (STMBarCodeScannedType)barcodeTypeFromTypesDics:(NSArray <NSDictionary *> *)types forBarcode:(NSString *)barcode {

    NSString *matchedType = nil;

    for (NSDictionary *barCodeType in types) {

        NSString *mask = barCodeType[@"mask"];

        if (!mask) {
            continue;
        }

        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:mask
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

    return [self barCodeScannedTypeForStringType:matchedType];

}

+ (NSArray <NSDictionary *> *)stockBatchForBarcode:(NSString *)barcode {

    NSArray *barcodesArray = [self barcodesArrayForBarcodeClass:@"STMStockBatchBarCode" barcodeValue:barcode];

    if (!barcodesArray.count) {
        NSLog(@"unknown barcode %@", barcode);
        return nil;
    }

    if (barcodesArray.count > 1) {

        NSString *logMessage = [NSString stringWithFormat:@"More than one stockbatch barcodes for barcode: %@", barcode];
        [[STMLogger sharedLogger] errorMessage:logMessage];

    }

    NSMutableArray *result = @[].mutableCopy;

    for (NSDictionary *stockBatchBarCode in barcodesArray) {

        NSString *stockBatchId = stockBatchBarCode[@"stockBatchId"];

        if (!stockBatchId) {

            continue;

        }

        NSDictionary *stockBatch = [[self persistenceDelegate] findSync:@"STMStockBatch"
                                                             identifier:stockBatchId
                                                                options:nil
                                                                  error:nil];

        [result addObject:stockBatch];

        NSLog(@"stockBatch articleId %@", stockBatch[@"articleId"]);

    }

    return result.copy;


}

+ (NSArray *)barcodesArrayForBarcodeClass:(NSString *)barcodeClass barcodeValue:(NSString *)barcodeValue {

    if (![barcodeClass isEqualToString:@"STMArticleBarCode"] && ![barcodeClass isEqualToString:@"STMStockBatchBarCode"]) {

        return nil;

    }

    NSPredicate *predicate = barcodeValue ? [NSPredicate predicateWithFormat:@"code == %@", barcodeValue] : nil;
    NSArray *barcodesArray = [[self persistenceDelegate] findAllSync:barcodeClass predicate:predicate options:nil error:nil];

    return barcodesArray;

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
