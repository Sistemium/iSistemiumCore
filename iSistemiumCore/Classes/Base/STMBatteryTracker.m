//
//  STMBatteryTracker.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/3/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMBatteryTracker.h"
#import "STMCoreDataModel.h"
#import "STMEntityDescription.h"
#import "STMObjectsController.h"

@implementation STMBatteryTracker

- (void)customInit {
    
    self.group = @"battery";
    [super customInit];
    
}

- (void)startTracking {
    
    [super startTracking];
    
    if (self.tracking) {
        
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:@"UIDeviceBatteryLevelDidChangeNotification" object:[UIDevice currentDevice]];
        [self getBatteryStatus];

    }
    
}

- (void)stopTracking {

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceBatteryLevelDidChangeNotification" object:[UIDevice currentDevice]];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];

    [super stopTracking];
    
}

#pragma mark - battery tracking

- (void)batteryChanged:(NSNotification *)notification {
    
    [self getBatteryStatus];
    
}

- (void)getBatteryStatus {
    
    STMBatteryStatus *batteryStatus = (STMBatteryStatus *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMBatteryStatus class]) isFantom:NO];
    batteryStatus.batteryLevel = [NSDecimalNumber decimalNumberWithDecimal:@((double)[UIDevice currentDevice].batteryLevel).decimalValue];
    NSString *batteryState;
    
    switch ([UIDevice currentDevice].batteryState) {
            
        case UIDeviceBatteryStateUnknown:
            batteryState = @"Unknown";
            break;
        case UIDeviceBatteryStateUnplugged:
            batteryState = @"Unplugged";
            break;
        case UIDeviceBatteryStateCharging:
            batteryState = @"Charging";
            break;
        case UIDeviceBatteryStateFull:
            batteryState = @"Full";
            break;
            
    }
    
    batteryStatus.batteryState = batteryState;
    
    NSLog(@"batteryLevel %@", batteryStatus.batteryLevel);
    NSLog(@"batteryState %@", batteryStatus.batteryState);
    
}


@end
