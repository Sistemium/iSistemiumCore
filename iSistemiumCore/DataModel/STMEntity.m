//
//  STMEntity.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 30/10/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreDataModel.h"

#import "STMCoreAuthController.h"


@implementation STMEntity

- (NSString *)resource {
    return (self.url) ? (NSString *)self.url : [NSString stringWithFormat:@"%@/%@", [STMCoreAuthController authController].accountOrg, self.name];
}

- (void)willSave {
    
    NSArray *changedKeys = [[self changedValues] allKeys];
    
    if ([changedKeys containsObject:@"workflow"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"workflowDidChange" object:self];
    }
    
    [super willSave];
    
}


@end
