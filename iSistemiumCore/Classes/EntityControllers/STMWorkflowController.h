//
//  STMWorkflowController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/09/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMCoreUI.h"


@interface STMWorkflowController : STMCoreController

+ (NSString *)workflowForEntityName:(NSString *)entityName;

+ (STMWorkflowAC *)workflowActionSheetForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow withHandler:(void(^)(UIAlertAction *action))handler;

+ (NSDictionary *)workflowActionSheetForProcessing:(NSString *)processing didSelectButtonWithIndex:(NSInteger)buttonIndex inWorkflow:(NSString *)workflow;

+ (NSString *)labelForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;
+ (NSString *)descriptionForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;

+ (NSString *)processingForLabel:(NSString *)label inWorkflow:(NSString *)workflow;

+ (UIColor *)colorForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;

+ (NSString *)labelForEditableProperty:(NSString *)editableProperty;

+ (BOOL)isEditableProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;


@end
