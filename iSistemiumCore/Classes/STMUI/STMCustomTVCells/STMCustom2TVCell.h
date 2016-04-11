//
//  STMCustom2TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 20/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom2TVCell : STMTableViewCell <STMTDCell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;


@end
