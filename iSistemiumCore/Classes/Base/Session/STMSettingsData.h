//
//  STMSettingsData.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMSettingsData : NSObject

+ (NSDictionary *)settingsFromFileName:(NSString *)settingsFileName withSchemaName:(NSString *)schemaName;
+ (NSDictionary *)settingsFromData:(NSData *)settingsData withSchema:(NSData *)schemaData;

@end
