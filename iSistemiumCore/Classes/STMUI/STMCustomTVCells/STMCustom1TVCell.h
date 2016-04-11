//
//  STMCustom1TVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 18/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"
#import "STMInsetLabel.h"

@interface STMCustom1TVCell : STMTableViewCell <STMTDICell, STMTDMCell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet STMLabel *messageLabel;
@property (weak, nonatomic) IBOutlet STMInsetLabel *infoLabel;



@end
