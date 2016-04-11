//
//  STMInfoTableViewCell.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/03/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMInfoTableViewCell.h"

@implementation STMInfoButtonTableViewCell

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.backgroundColor = STM_SECTION_HEADER_COLOR;

}

- (void)setFrameForInfoLabel {
    
    CGFloat paddingX = (self.infoLabel.text) ? 10 : 0;
    
    NSDictionary *attributes = @{NSFontAttributeName:self.infoLabel.font};
    
    CGSize size = [self.infoLabel.text sizeWithAttributes:attributes];
    
    CGFloat x = self.contentView.frame.size.width - size.width - 2 * paddingX;
    
    CGRect frame = CGRectMake(x, 0, size.width + 2 * paddingX, self.infoLabel.superview.frame.size.height);
    self.infoLabel.frame = frame;
    
}


@end


@implementation STMInfoTableViewCell

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    self.infoLabel.textAlignment = NSTextAlignmentRight;
    self.infoLabel.backgroundColor = [UIColor clearColor];
    
    [self setFrameForInfoLabel];

    [self setFrameToLabel:self.textLabel withInfoLabel:self.infoLabel];
    [self setFrameToLabel:self.detailTextLabel withInfoLabel:self.infoLabel];
    
}

- (void)setFrameForInfoLabel {

    CGFloat paddingX = 0;
    CGFloat paddingY = 0;
    CGFloat marginX = 0;
    
    if (self.infoLabel.text) {
        
        paddingX = 10;
        paddingY = 5;
        marginX = 10;
        
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:self.infoLabel.font};
    
    CGSize size = [self.infoLabel.text sizeWithAttributes:attributes];
    
    CGFloat x = self.contentView.frame.size.width - size.width - 2 * paddingX - marginX;
    CGFloat y = (self.contentView.frame.size.height - size.height - 2 * paddingY) / 2;
    
    CGRect frame = CGRectMake(x, y, size.width + 2 * paddingX, size.height + 2 * paddingY);
    self.infoLabel.frame = frame;

}

- (void)setFrameToLabel:(UILabel *)label withInfoLabel:(UILabel *)infoLabel {

    CGFloat x = label.frame.origin.x;
    CGFloat y = label.frame.origin.y;
    CGFloat height = label.frame.size.height;
    CGFloat width = infoLabel.frame.origin.x - x;
    CGRect frame = CGRectMake(x, y, width, height);
    label.frame = frame;

}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
//    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    
    if (self) {
        
        self.infoLabel = [[UILabel alloc] init];
        [self.contentView addSubview:self.infoLabel];
        
    }
    return self;
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}


@end
