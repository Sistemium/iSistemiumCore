//
//  STMCustom4TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 11/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom4TVCell : STMTableViewCell <STMTDICell, STMTDPCell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet STMLabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIImageView *pictureView;


@end
