//
//  STMBarCodeScan.h
//  iSistemium
//
//  Created by Alexander Levin on 13/04/18.
//  Copyright © 2018 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMBarCodeScan : NSObject

@property (nullable, nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, retain) NSString *code;
@property (nullable, nonatomic, retain) NSDate *deviceCts;

@end
