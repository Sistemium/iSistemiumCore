//
//  STMCustom9TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/08/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom9TVCell : STMTableViewCell <STMTDICell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet STMLabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIView *checkboxView;


@end
