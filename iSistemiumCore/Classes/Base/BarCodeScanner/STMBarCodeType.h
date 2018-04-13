//
//  STMBarCodeType.h
//  iSistemium
//
//  Created by Alexander Levin on 13/04/18.
//  Copyright © 2018 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMBarCodeType : NSObject

@property (nullable, nonatomic, retain) NSString *commentText;
@property (nullable, nonatomic, retain) NSDate *deviceCts;
@property (nullable, nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, retain) NSString *mask;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *symbology;
@property (nullable, nonatomic, retain) NSString *type;

@end
