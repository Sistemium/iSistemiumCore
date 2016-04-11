//
//  STMTableViewCell.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/11/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMTableViewCell.h"
#import "STMConstants.h"


@implementation STMTableViewCell


// remove circles in cells then table view in editing mode
// workaround for ios >= 8.0

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    
    [super setEditing:editing animated:animated];
    
    if (editing && self.editingStyle != UITableViewCellEditingStyleDelete && SYSTEM_VERSION >= 8.0) {
        
        for (UIView *subview in self.subviews) {
            
            if ([NSStringFromClass(subview.class) isEqualToString:@"UITableViewCellEditControl"]) {
                subview.hidden = YES;
            }
            
        }
        
    }
    
}


#pragma mark - view lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)prepareForReuse {
    
    [super prepareForReuse];
    
    self.textLabel.text = @"";
    self.textLabel.textColor = [UIColor blackColor];
    self.detailTextLabel.text = @"";
    self.accessoryView = nil;
    self.imageView.image = nil;

}

@end


@implementation STMTableViewSubtitleStyleCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
    
}

- (void)layoutSubviews {
    
    [super layoutSubviews];
//    self.imageView.bounds = CGRectMake(0,0,20,20);
    
}


@end

