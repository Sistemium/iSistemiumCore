//
//  STMCoreVolumePicker.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/12/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreVolumePicker.h"

#import "STMCoreSessionManager.h"
#import "STMConstants.h"


@interface STMCoreVolumePicker() <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic) NSInteger selectedBoxCount;
@property (nonatomic) NSArray *packageRels;


@end


@implementation STMCoreVolumePicker

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self customInit];
    }
    return self;
    
}

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    
    if (self) {
        [self customInit];
    }
    return self;

}

- (void)customInit {
    
    self.delegate = self;
    self.dataSource = self;

}

- (NSArray *)packageRels {
    
    if (!_packageRels) {
        _packageRels = [self currentPackageRels];
    }
    return _packageRels;
    
}

- (NSArray *)currentPackageRels {
    return @[];
}

- (void)setPackageRel:(NSInteger)packageRel {
    
    if ([self.packageRels containsObject:@(packageRel)]) {
        
        _packageRel = packageRel;

        [self reloadComponent:0];
        [self reloadComponent:2];

        if (self.showPackageRel) [self selectRow:[self.packageRels indexOfObject:@(packageRel)] inComponent:4 animated:NO];
        
    }
    
}

- (void)setSelectedVolume:(NSInteger)selectedVolume {
    
    if (selectedVolume > self.maxVolume) {
        selectedVolume = self.maxVolume;
    }
    
    _selectedVolume = selectedVolume;
    
    self.selectedBoxCount = (self.packageRel > 0) ? self.selectedVolume / self.packageRel : 0;
    
    [self selectRow:self.selectedBoxCount inComponent:0 animated:YES];
    [self selectRow:self.selectedVolume inComponent:2 animated:YES];
    
}


#pragma mark - UIPickerViewDataSource, UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return (self.showPackageRel) ? 6 : 4;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    
    switch (component) {
        case 0:
            return (self.packageRel > 0) ? (self.maxVolume / self.packageRel) + 1 : 1;
            break;
            
        case 2:
            return self.maxVolume + 1;
            break;
            
        case 4:
            return (self.packageRelIsLocked) ? 1 : self.packageRels.count;
            break;

        default:
            return 1;
            break;
    }
    
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return PICKERVIEW_ROW_HEIGHT;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    
    CGFloat numberOfComponents = [self numberOfComponentsInPickerView:pickerView];
    CGFloat width = CGRectGetWidth(self.bounds) / numberOfComponents;
    
    return width;
    
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    switch (component) {
        case 0:
            return @(row).stringValue;
            break;
            
        case 2:
            return (self.packageRel > 0) ? @(row % self.packageRel).stringValue : @(row).stringValue;
            break;
            
        case 4:
            return (self.packageRelIsLocked) ? @(self.packageRel).stringValue : [self.packageRels[row] stringValue];
            break;

        default:
            return nil;
            break;
    }
    
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    NSString *unit1 = NSLocalizedString(@"VOLUME UNIT1", nil);
    NSString *unit2 = [self bottlesUnit];
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor]};

    
    switch (component) {
        case 1:
            return [[NSAttributedString alloc] initWithString:unit1
                                                   attributes:attributes];
            break;

        case 3:
            return [[NSAttributedString alloc] initWithString:unit2
                                                   attributes:attributes];
            break;
            
        case 4: {
            
            attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:20],
                           NSForegroundColorAttributeName: [UIColor grayColor]};
            
            NSString *title = [self pickerView:pickerView titleForRow:row forComponent:component];
            return [[NSAttributedString alloc] initWithString:title attributes:attributes];
            
        }
            break;
            
        case 5:
            return [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@/%@", unit2, unit1]
                                                   attributes:attributes];
            break;

        default:
            return nil;
            break;
    }
    
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    
    CGFloat height = [self pickerView:pickerView rowHeightForComponent:component];
    CGFloat width = [self pickerView:pickerView widthForComponent:component];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    
    label.font = [UIFont systemFontOfSize:28];
    
    switch (component) {
        case 0:
        case 2:
            label.textAlignment = NSTextAlignmentRight;
            label.text = [self pickerView:pickerView titleForRow:row forComponent:component];
            break;

        case 4:
            label.textAlignment = NSTextAlignmentRight;
            label.attributedText = [self pickerView:pickerView attributedTitleForRow:row forComponent:component];
            if (self.packageRelIsLocked) [self component:component enableRotation:NO];
            break;

        case 1:
        case 3:
        case 5:
            label.textAlignment = NSTextAlignmentLeft;
            label.attributedText = [self pickerView:pickerView attributedTitleForRow:row forComponent:component];
            [self component:component enableRotation:NO];
            break;
            
        default:
            break;
    }
    
    return label;

    
}

- (NSString *)bottlesUnit {
    
    NSDictionary *appSettings = [[STMCoreSessionManager sharedManager].currentSession.settingsController currentSettingsForGroup:@"appSettings"];
    BOOL enableShowBottles = [appSettings[@"enableShowBottles"] boolValue];
    
    return (enableShowBottles) ? NSLocalizedString(@"VOLUME UNIT2", nil) : NSLocalizedString(@"VOLUME UNIT3", nil);

}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    switch (component) {
        case 0:
            self.selectedVolume = self.selectedVolume + (row - self.selectedBoxCount) * self.packageRel;
            [self.owner volumeSelected];
        break;
            
        case 2:
            self.selectedVolume = row;
            [self.owner volumeSelected];
            break;
            
        case 4: {
            
            NSInteger selectedPackageRel = (self.packageRelIsLocked) ? self.packageRel : [self.packageRels[row] integerValue];
            NSInteger volumeAfterUpdate = self.selectedVolume - (self.selectedBoxCount * (self.packageRel - selectedPackageRel));
            
            self.packageRel = selectedPackageRel;
            
            self.selectedVolume = volumeAfterUpdate;
            
            [self.owner packageRelSelected];
            
        }
            break;
            
        default:
            break;
    }
    
}


#pragma mark - enable/disable rotating

- (void)component:(NSInteger)component enableRotation:(BOOL)enableRotation {

    if (self.subviews.count > 0) {
        
        UIView *mainView = nil;
        
        for (UIView *subview in self.subviews) {
            
            if (CGRectGetHeight(subview.frame) == CGRectGetHeight(self.frame)) {
                
                mainView = subview;
                break;
                
            }
            
        }
        
        if (mainView) {
            
            UIView *componentView = mainView.subviews[component];
            
            for (UIGestureRecognizer *gesture in componentView.gestureRecognizers) {
                gesture.enabled = enableRotation;
            }
            
        }
        
    }
    
}


@end
