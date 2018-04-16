//
//  STMCoreBarCodeController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMBarCodeType.h"
#import "STMBarCodeScanning.h"

@interface STMCoreBarCodeController : STMCoreController

+ (STMBarCodeScannedType)barcodeTypeFromTypesDics:(NSArray <NSDictionary *> *)types
                                       forBarcode:(NSString *)barcode;

+ (NSString *)barCodeTypeStringForType:(STMBarCodeScannedType)type;

+ (NSArray <NSDictionary *> *)stockBatchForBarcode:(NSString *)barcode;


@end
