//
//  STMModeller+Private.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 27/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMModeller+Private.h"
#import "STMFunctions.h"

@implementation STMModeller (Private)


+ (id)typeConversionForValue:(id)value key:(NSString *)key entityAttributes:(NSDictionary *)entityAttributes {
    
    if (!value) return nil;
    
    NSString *valueClassName = [entityAttributes[key] attributeValueClassName];
    
    if ([valueClassName isEqualToString:NSStringFromClass([NSDecimalNumber class])]) {
        
        if (![value isKindOfClass:[NSNumber class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = [NSDecimalNumber decimalNumberWithString:value];
                
            } else {
                
                NSLog(@"value %@ is not a number or string, can't convert to decimal number", value);
                value = nil;
                
            }
            
        } else {
            
            value = [NSDecimalNumber decimalNumberWithDecimal:[(NSNumber *)value decimalValue]];
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSDate class])]) {
        
        if (![value isKindOfClass:[NSDate class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = [STMFunctions dateFromString:value];
                
            } else {
                
                NSLog(@"value %@ is not a string, can't convert to date", value);
                value = nil;
                
            }
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSNumber class])]) {
        
        if (![value isKindOfClass:[NSNumber class]]) {
            
            if ([value isKindOfClass:[NSString class]]) {
                
                value = @([value intValue]);
                
            } else {
                
                NSLog(@"value %@ is not a number or string, can't convert to number", value);
                value = nil;
                
            }
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSData class])]) {
        
        if ([value isKindOfClass:[NSString class]]) {
            
            value = [STMFunctions dataFromString:[value stringByReplacingOccurrencesOfString:@"-" withString:@""]];
            
        } else {
            
            NSLog(@"value %@ is not a string, can't convert to data", value);
            value = nil;
            
        }
        
    } else if ([valueClassName isEqualToString:NSStringFromClass([NSString class])]) {
        
        if (![value isKindOfClass:[NSString class]]) {
            
            if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                
                value = [STMFunctions jsonStringFromObject:value];
                value = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
                
            } else if ([value isKindOfClass:[NSObject class]]) {
                
                value = [value description];
                
            } else {
                
                NSLog(@"value %@ is not convertable to string", value);
                value = nil;
                
            }
            
        }
        
    }
    
    return value;
    
}

@end
