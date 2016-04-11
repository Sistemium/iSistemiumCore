//
//  STMSettingsData.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 09/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMSettingsData.h"
#import <CoreLocation/CoreLocation.h>
#import <KiteJSONValidator/KiteJSONValidator.h>


@implementation STMSettingsData

+ (NSDictionary *)settingsFromFileName:(NSString *)settingsFileName withSchemaName:(NSString *)schemaName {
    
    NSString *schemaPath = [[NSBundle mainBundle] pathForResource:schemaName ofType:@"json"];
    NSData *schemaData = [NSData dataWithContentsOfFile:schemaPath];
    
    NSString *settingsPath = [[NSBundle mainBundle] pathForResource:settingsFileName ofType:@"json"];
    NSData *settingsData = [NSData dataWithContentsOfFile:settingsPath];

    if (settingsData) {
        
        return [self settingsFromData:settingsData withSchema:schemaData];
        
    } else {
        
        NSLog(@"no settings.json file");
        return @{};
        
    }
    
}


+ (NSDictionary *)settingsFromData:(NSData *)settingsData withSchema:(NSData *)schemaData {
    
    KiteJSONValidator *JSONValidator = [[KiteJSONValidator alloc] init];
    
    if ([JSONValidator validateJSONData:settingsData withSchemaData:schemaData]) {
        
        NSMutableDictionary *settingsValues = [NSMutableDictionary dictionary];
        NSMutableDictionary *settingsControls = [NSMutableDictionary dictionary];
        
        NSError *error;
        NSDictionary *settingsJSON = [NSJSONSerialization JSONObjectWithData:settingsData options:NSJSONReadingMutableContainers error:&error];
        
        NSMutableArray *settingsControlGroupNames = [NSMutableArray array];
        
        for (NSDictionary *group in settingsJSON[@"defaultSettings"]) {
            
            NSString *groupName = group[@"group"];
            
            NSMutableDictionary *settingsValuesGroup = [NSMutableDictionary dictionary];
            NSMutableArray *settingsControlsGroup = [NSMutableArray array];
            
            for (NSDictionary *settingItem in group[@"data"]) {
                
                NSString *itemName = settingItem[@"name"];
                id itemValue = settingItem[@"value"];
                
                itemValue = [itemValue isKindOfClass:[NSString class]] ? itemValue : ([itemValue respondsToSelector:@selector(stringValue)]) ? [itemValue stringValue] : [NSNull null];
                
                settingsValuesGroup[itemName] = itemValue;
                
                NSString *itemControlType = settingItem[@"control"];
                
                if (itemControlType) {
                    
                    NSString *itemMinValue = [settingItem[@"min"] stringValue];
                    NSString *itemMaxValue = [settingItem[@"max"] stringValue];
                    NSString *itemStepValue = [settingItem[@"step"] stringValue];
                    
                    itemMinValue = itemMinValue ? itemMinValue : @"";
                    itemMaxValue = itemMaxValue ? itemMaxValue : @"";
                    itemStepValue = itemStepValue ? itemStepValue : @"";
                    
                    [settingsControlsGroup addObject:@[itemControlType, itemMinValue, itemMaxValue, itemStepValue, itemName]];
                    
                    //                    NSLog(@"%@", itemName);
                    
                }
                
            }
            
            if (settingsValuesGroup.count > 0) {
                settingsValues[groupName] = settingsValuesGroup;
            }
            if (settingsControlsGroup.count > 0) {
                settingsControls[groupName] = settingsControlsGroup;
                [settingsControlGroupNames addObject:groupName];
            }
            
        }
        
        settingsControls[@"groupNames"] = settingsControlGroupNames;
        
        return @{@"values": settingsValues, @"controls": settingsControls};
        
    } else {
        
        NSLog(@"settingsData not confirm schema");
        return nil;
        
    }

}

@end
