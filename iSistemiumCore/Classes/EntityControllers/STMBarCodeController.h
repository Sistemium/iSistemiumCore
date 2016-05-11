//
//  STMBarCodeController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"

typedef NS_ENUM(NSUInteger, STMBarCodeScannedType) {
    STMBarCodeTypeUnknown,
    STMBarCodeTypeArticle,
    STMBarCodeTypeExciseStamp,
    STMBarCodeTypeStockBatch
};


@interface STMBarCodeController : STMCoreController

+ (STMBarCodeScannedType)barcodeTypeFromTypes:(NSArray <STMBarCodeType *> *)types
                                   forBarcode:(NSString *)barcode;

+ (NSString *)barCodeTypeStringForType:(STMBarCodeScannedType)type;


@end
