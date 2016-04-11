//
//  STMCustom5TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 11/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom5TVCell : STMTableViewCell <STMTDICell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet STMLabel *infoLabel;
@property (nonatomic) CGFloat heightLimiter;

@end
