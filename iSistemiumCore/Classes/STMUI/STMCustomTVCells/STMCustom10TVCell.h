//
//  STMCustom10TVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/10/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

@interface STMCustom10TVCell : STMTableViewCell <STMTDCell, STMTDPCell>

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;
@property (weak, nonatomic) IBOutlet STMLabel *detailLabel;
@property (weak, nonatomic) IBOutlet UIImageView *pictureView;


@end
