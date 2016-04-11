//
//  STMVolumeControlsTVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"
#import "STMVolumeTVCell.h"


@interface STMVolumeControlsTVCell : STMTableViewCell

@property (weak, nonatomic) IBOutlet UIButton *allCountButton;

@property (weak, nonatomic) IBOutlet UIStepper *boxCountStepper;
@property (weak, nonatomic) IBOutlet UIStepper *bottleCountStepper;

@property (nonatomic, weak) STMVolumeTVCell *volumeCell;

@property (nonatomic) NSInteger packageRel;
@property (nonatomic) NSInteger volume;
@property (nonatomic) NSInteger volumeLimit;


@end
