//
//  STMVolumeControlsTVCell.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 29/07/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMVolumeControlsTVCell.h"

@interface STMVolumeControlsTVCell()

@property (nonatomic) NSInteger bottleCountPreviousValue;
@property (nonatomic) NSInteger boxCountPreviousValue;

@property (nonatomic) BOOL initialVolumeSetWasDone;


@end


@implementation STMVolumeControlsTVCell

- (IBAction)allCountButtonPressed:(id)sender {
    self.volume = self.volumeLimit;
}

- (IBAction)boxCountTouchedDown:(id)sender {
    self.boxCountPreviousValue = self.boxCountStepper.value;
}

- (IBAction)boxCountChanged:(id)sender {
    
    NSInteger countChange = self.boxCountStepper.value - self.boxCountPreviousValue;
    self.boxCountPreviousValue = self.boxCountStepper.value;
    
    self.volume += countChange * self.packageRel;
    
}

- (IBAction)bottleCountTouchedDown:(id)sender {
    self.bottleCountPreviousValue = self.bottleCountStepper.value;
}

- (IBAction)bottleCountChanged:(id)sender {
    
    NSInteger countChange = self.bottleCountStepper.value - self.bottleCountPreviousValue;
    self.bottleCountPreviousValue = self.bottleCountStepper.value;

    self.volume += countChange;
    
}

- (void)setVolume:(NSInteger)volume {
    
    if (volume > self.volumeLimit) volume = self.volumeLimit;
    
    _volume = volume;
    
    if (!self.initialVolumeSetWasDone) {
        
        self.boxCountStepper.value = 0;
        self.boxCountStepper.minimumValue = 0;
        self.boxCountStepper.maximumValue = (self.packageRel && self.packageRel != 0) ? floor(self.volumeLimit / self.packageRel) : 0;
        
        self.bottleCountStepper.value = volume;
        self.bottleCountStepper.minimumValue = 0;
        self.bottleCountStepper.maximumValue = self.volumeLimit;
        
        self.initialVolumeSetWasDone = YES;
        
    }
    
    if (self.volumeCell.volume != volume) self.volumeCell.volume = volume;
    
    self.boxCountStepper.value = (self.packageRel && self.packageRel != 0) ? floor(volume / self.packageRel) : 0;
    self.bottleCountStepper.value = volume;
    
    self.allCountButton.enabled = (self.volume < self.volumeLimit);
    
}


- (void)awakeFromNib {
    
    [self.allCountButton setTitle:NSLocalizedString(@"ALL VOLUME BUTTON", nil) forState:UIControlStateNormal];
    [self.allCountButton setTitle:@"" forState:UIControlStateDisabled];
    
    [super awakeFromNib];
    
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
