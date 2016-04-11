//
//  STMBarCodeController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"

typedef NS_ENUM(NSUInteger, STMBarCodeScannedType) {
    STMBarCodeTypeUnknown,
    STMBarCodeTypeArticle,
    STMBarCodeTypeExciseStamp,
    STMBarCodeTypeStockBatch
};


@interface STMBarCodeController : STMController

#warning should override
//+ (NSArray <STMArticle *> *)articlesForBarcode:(NSString *)barcode;
//+ (NSArray <STMStockBatch *> *)stockBatchForBarcode:(NSString *)barcode;

+ (STMBarCodeScannedType)barcodeTypeFromTypes:(NSArray <STMBarCodeType *> *)types
                                   forBarcode:(NSString *)barcode;

#warning should override
//+ (void)addBarcode:(NSString *)barcode toArticle:(STMArticle *)article;

+ (NSString *)barCodeTypeStringForType:(STMBarCodeScannedType)type;


@end
