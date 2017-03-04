//
//  STMEntity+CoreDataClass.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 12/10/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import "STMEntity.h"
#import "STMWorkflow.h"

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
