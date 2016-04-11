//
//  STMVolumeTVCell.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 28/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"

typedef NS_ENUM(NSUInteger, STMVolumeType) {
    STMVolumeTypeDone = 0,
    STMVolumeTypeBad = 1,
    STMVolumeTypeExcess = 2,
    STMVolumeTypeShortage = 3,
    STMVolumeTypeRegrade = 4,
    STMVolumeTypeBroken = 5
};


@interface STMVolumeTVCell : STMTableViewCell

@property (weak, nonatomic) IBOutlet STMLabel *titleLabel;

@property (weak, nonatomic) IBOutlet STMLabel *boxCountLabel;
@property (weak, nonatomic) IBOutlet STMLabel *boxUnitLabel;

@property (weak, nonatomic) IBOutlet STMLabel *bottleCountLabel;
@property (weak, nonatomic) IBOutlet STMLabel *bottleUnitLabel;

@property (nonatomic) NSInteger packageRel;
@property (nonatomic) NSInteger volume;

@property (nonatomic, weak) id parentVC;

@property (nonatomic) STMVolumeType volumeType;


@end
