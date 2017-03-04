//
//  STMCustom1TVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 18/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCustom1TVCell.h"
#import "STMConstants.h"

@implementation STMCustom1TVCell

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.backgroundColor = STM_SECTION_HEADER_COLOR;
    
}


#pragma mark - view lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}


@end
