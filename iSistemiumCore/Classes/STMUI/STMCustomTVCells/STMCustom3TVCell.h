//
//  STMCustom3TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 04/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom3TVCell : STMTableViewCell <STMTDPCell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet UIImageView *pictureView;


@end
