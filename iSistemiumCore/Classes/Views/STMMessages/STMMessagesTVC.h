//
//  STMMessagesTVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 30/08/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMVariableCellsHeightTVC.h"
#import "STMWorkflowable.h"


@interface STMMessagesTVC : STMVariableCellsHeightTVC <STMWorkflowable>

- (void)markAllMessagesAsRead;


@end
