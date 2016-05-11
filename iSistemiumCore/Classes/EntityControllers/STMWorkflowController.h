//
//  STMWorkflowController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/09/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMController.h"
#import "STMUI.h"


@interface STMWorkflowController : STMController

+ (NSString *)workflowForEntityName:(NSString *)entityName;

+ (STMWorkflowAS *)workflowActionSheetForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow withDelegate:(id <UIActionSheetDelegate>)delegate;

+ (NSDictionary *)workflowActionSheetForProcessing:(NSString *)processing didSelectButtonWithIndex:(NSInteger)buttonIndex inWorkflow:(NSString *)workflow;

+ (NSString *)labelForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;
+ (NSString *)descriptionForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;

+ (NSString *)processingForLabel:(NSString *)label inWorkflow:(NSString *)workflow;

+ (UIColor *)colorForProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;

+ (NSString *)labelForEditableProperty:(NSString *)editableProperty;

+ (BOOL)isEditableProcessing:(NSString *)processing inWorkflow:(NSString *)workflow;


@end
