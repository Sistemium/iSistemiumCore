//
//  STMSettingsTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 4/13/13.
//  Copyright (c) 2013 Maxim Grigoriev. All rights reserved.
//

#import "STMSettingsController.h"
#import "STMSettingsTVC.h"
#import "STMSessionManager.h"
#import "STMSession.h"
#import "STMSetting.h"
#import "STMSettingsData.h"

@interface STMSettingsTVC () <UITextFieldDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSDictionary *controlsSettings;
//@property (nonatomic, strong) NSFetchedResultsController *resultsController;

@end


@interface STMSettingsTVCell ()

@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UISwitch *senderSwitch;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITextField *textField;

@end


@implementation STMSettingsTVCell

- (void) layoutSubviews {

    [super layoutSubviews];

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.textLabel.frame = CGRectMake(10, 10, 220, 24);
    self.textLabel.font = [UIFont boldSystemFontOfSize:16];
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.detailTextLabel.frame = CGRectMake(230, 10, 60, 24);
    self.detailTextLabel.font = [UIFont boldSystemFontOfSize:18];
    self.detailTextLabel.textAlignment = NSTextAlignmentRight;

}


@end


@implementation STMSettingsTVC

//@synthesize resultsController = _resultsController;

#pragma mark - STGTSettingsTableViewController

- (id <STMSession>)session {
    
    return [STMSessionManager sharedManager].currentSession;
    
}

- (NSDictionary *)controlsSettings {
    
    if (!_controlsSettings) {
        _controlsSettings = self.session.settingsControls;
    }
    
    return _controlsSettings;
    
}

- (STMSetting *)settingObjectForIndexPath:(NSIndexPath *)indexPath {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.group == %@ && SELF.name == %@", [self groupNames][indexPath.section], [self settingNameForIndexPath:indexPath]];
    return [[[self.session.settingsController currentSettings] filteredArrayUsingPredicate:predicate] lastObject];
    
}

- (NSArray *)groupNames {
    
//    return [[self controlsSettings] valueForKey:@"groupNames"];
    
    return [(STMSettingsController *)[self.session settingsController] groupNames];
    
}

- (NSArray *)settingsGroupForSection:(NSInteger)section {
    
    NSString *groupName = [self groupNames][section];
    NSArray *settingsGroup = [self.controlsSettings valueForKey:groupName];
    
    return settingsGroup;
    
}

- (NSString *)controlTypeForIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *controlGroup = [self settingsGroupForSection:indexPath.section];

    NSString *controlType = nil;
    
//    NSLog(@"controlGroup.count %d, indexPath.row-1 %d", controlGroup.count, indexPath.row-1)
    
    if (indexPath.row < controlGroup.count) {
        
        controlType = controlGroup[indexPath.row][0];

    } else {
        
        controlType = @"textField";
        
    }
    
    return controlType;
    
}


- (NSString *)minForIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *controlGroup = [self settingsGroupForSection:indexPath.section];
    return controlGroup[indexPath.row][1];
    
}

- (NSString *)maxForIndexPath:(NSIndexPath *)indexPath {
    NSArray *controlGroup = [self settingsGroupForSection:indexPath.section];
    return controlGroup[indexPath.row][2];
}

- (NSString *)stepForIndexPath:(NSIndexPath *)indexPath {
    NSArray *controlGroup = [self settingsGroupForSection:indexPath.section];
    return controlGroup[indexPath.row][3];
}

- (NSString *)settingNameForIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *settingsGroup = [self settingsGroupForSection:indexPath.section];
    NSLog(@"settingsGroup %@", settingsGroup);
    
    NSArray *setting = settingsGroup[indexPath.row];
    NSLog(@"setting %@", setting);
    
    NSString *settingName = [setting lastObject];
    NSLog(@"settingName %@", settingName);
    
    return settingName;
    
}


- (NSIndexPath *)indexPathForGroup:(NSString *)groupName setting:(NSString *)settingName {
    
    NSUInteger section = [[self groupNames] indexOfObject:groupName];
    NSUInteger row;
    
    for (NSArray *controlSetting in [self settingsGroupForSection:section]) {
        
        if ([[controlSetting lastObject] isEqualToString:settingName]) {
            
            row = [[self settingsGroupForSection:section] indexOfObject:controlSetting];
            return [NSIndexPath indexPathForRow:row inSection:section];
            
        }
        
    }
    
    return nil;
    
}

- (NSString *)valueForIndexPath:(NSIndexPath *)indexPath {
    
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    
    NSLog(@"settingName %@", settingName);
    
    NSString *value = [[self settingObjectForIndexPath:indexPath] valueForKey:@"value"];
    if ([[self controlTypeForIndexPath:indexPath] isEqualToString:@"slider"]) {
        value = [self formatValue:value forSettingName:settingName];
    }
    return value;

}

- (NSString *)formatValue:(NSString *)valueString forSettingName:(NSString *)settingName{
    
    if ([settingName hasSuffix:@"StartTime"] || [settingName hasSuffix:@"FinishTime"]) {
        double time = [valueString doubleValue];
        double hours = floor(time);
        double minutes = rint((time - floor(time)) * 60);
        NSNumberFormatter *timeFormatter = [[NSNumberFormatter alloc] init];
        timeFormatter.formatWidth = 2;
        timeFormatter.paddingCharacter = @"0";
        valueString = [NSString stringWithFormat:@"%@:%@", [timeFormatter stringFromNumber:@(hours)], [timeFormatter stringFromNumber:@(minutes)]];
    } else if ([settingName isEqualToString:@"trackScale"]) {
        valueString = [NSString stringWithFormat:@"%.1f", [valueString doubleValue]];
    } else {
        valueString = [NSString stringWithFormat:@"%.f", [valueString doubleValue]];
    }
    return valueString;

}
 
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return [[self groupNames] count];
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSArray *keys = [self groupNames];
    
    return [[[self.session settingsController] currentSettingsForGroup:keys[section]] count];
    
//    return [[self.controlsSettings valueForKey:[keys objectAtIndex:section]] count];
    
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    NSString *title = [NSString stringWithFormat:@"SETTING%@",[self groupNames][section]];
    return NSLocalizedString(title, @"");
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *controlType = [self controlTypeForIndexPath:indexPath];
    
    if ([controlType isEqualToString:@"slider"] || [controlType isEqualToString:@"textField"]) {
        
        return 70.0;
        
    } else if ([controlType isEqualToString:@"switch"] || [controlType isEqualToString:@"segmentedControl"]) {
        
        return 44.0;
        
    } else {
        
        return 0.0;
        
    }
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"settingCell";
    STMSettingsTVCell *cell = nil;
    
    NSString *controlType = [self controlTypeForIndexPath:indexPath];
    
    if ([controlType isEqualToString:@"slider"]) {
        cell = [[STMSettingsTVCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
        [self addSliderToCell:cell atIndexPath:indexPath];

    } else {
        cell = [[STMSettingsTVCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        
        if ([controlType isEqualToString:@"switch"]) {
            [self addSwitchToCell:cell atIndexPath:indexPath];

        } else if ([controlType isEqualToString:@"textField"]) {
            [self addTextFieldToCell:cell atIndexPath:indexPath];
            
        } else if ([controlType isEqualToString:@"segmentedControl"]) {
            [self addSegmentedControlToCell:cell atIndexPath:indexPath];

        }

    }
    
    cell.textLabel.text = NSLocalizedString([self settingNameForIndexPath:indexPath], @"");
    
    return cell;
    
}

- (void)addSliderToCell:(STMSettingsTVCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    cell.detailTextLabel.text = [self valueForIndexPath:indexPath];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(25, 38, 270, 24)];
    slider.maximumValue = [[self maxForIndexPath:indexPath] doubleValue];
    slider.minimumValue = [[self minForIndexPath:indexPath] doubleValue];
    [self setSlider:slider value:[[self valueForIndexPath:indexPath] doubleValue] forSettingName:[self settingNameForIndexPath:indexPath]];
    
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(sliderValueChangeFinished:) forControlEvents:UIControlEventTouchUpInside];
    
    [cell.contentView addSubview:slider];
    cell.slider = slider;

}

- (void)addSwitchToCell:(STMSettingsTVCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    UISwitch *senderSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(230, 9, 80, 27)];
    [senderSwitch setOn:[[self valueForIndexPath:indexPath] boolValue] animated:NO];
    [senderSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    [cell.contentView addSubview:senderSwitch];
    cell.senderSwitch = senderSwitch;

}

- (void)addTextFieldToCell:(STMSettingsTVCell *)cell atIndexPath:(NSIndexPath *)indexPath {

    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(25, 38, 270, 24)];

    NSLog(@"indexPath %@", indexPath);

    textField.text = [self valueForIndexPath:indexPath];
    textField.font = [UIFont systemFontOfSize:14];
    textField.keyboardType = UIKeyboardTypeURL;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.delegate = self;
    [cell.contentView addSubview:textField];
    cell.textField = textField;

}

- (void)addSegmentedControlToCell:(STMSettingsTVCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    int i = [[self minForIndexPath:indexPath] intValue];
    int ii = [[self maxForIndexPath:indexPath] intValue];
    int step = [[self stepForIndexPath:indexPath] intValue];
    
    NSMutableArray *segments = [NSMutableArray array];
    while (i <= ii) {
        NSString *segmentTitle = [NSString stringWithFormat:@"%@_%d", [self settingNameForIndexPath:indexPath], i];
        [segments addObject:NSLocalizedString(segmentTitle, @"")];
        i += step;
    }
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:segments];
    segmentedControl.frame = CGRectMake(110, 7, 200, 30);
//    segmentedControl.segmentedControlStyle = UISegmentedControlStylePlain;
//    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:12], UITextAttributeFont, nil];
//    [segmentedControl setTitleTextAttributes:textAttributes forState:UIControlStateNormal];
    [segmentedControl addTarget:self action:@selector(segmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.selectedSegmentIndex = [[self valueForIndexPath:indexPath] integerValue];
    [cell.contentView addSubview:segmentedControl];
    cell.segmentedControl = segmentedControl;

}


#pragma mark - show changes in situ

- (void)settingsChanged:(NSNotification *)notification {
//    NSLog(@"notification.userInfo %@", notification.userInfo);
    NSString *groupName = [[notification.userInfo valueForKey:@"changedObject"] valueForKey:@"group"];
    NSString *settingName = [[notification.userInfo valueForKey:@"changedObject"] valueForKey:@"name"];
    NSIndexPath *indexPath = [self indexPathForGroup:groupName setting:settingName];
    STMSettingsTVCell *cell = (STMSettingsTVCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    NSString *value = [self valueForIndexPath:indexPath];
    cell.detailTextLabel.text = value;
    [self setSlider:cell.slider value:[value doubleValue] forSettingName:settingName];
    [cell.senderSwitch setOn:[value boolValue]];
    [cell.segmentedControl setSelectedSegmentIndex:[value integerValue]];
    cell.textField.text = value;
}


#pragma mark - controls

- (STMSettingsTVCell *)cellForView:(UIView *)view {
    
    if ([view.superview isKindOfClass:[STMSettingsTVCell class]]) {
        return (STMSettingsTVCell *)view.superview;
    } else if (view.superview == nil) {
        return nil;
    } else {
        return [self cellForView:view.superview];
    }
    
}

- (void)setSlider:(UISlider *)slider value:(double)value forSettingName:(NSString *)settingName {
    
    if ([settingName isEqualToString:@"desiredAccuracy"]) {
        NSArray *accuracyArray = @[@(kCLLocationAccuracyBestForNavigation),
                                  @(kCLLocationAccuracyBest),
                                  @(kCLLocationAccuracyNearestTenMeters),
                                  @(kCLLocationAccuracyHundredMeters),
                                  @(kCLLocationAccuracyKilometer),
                                  @(kCLLocationAccuracyThreeKilometers)];
        value = [accuracyArray indexOfObject:@(value)];
        if (value == NSNotFound) {
            NSLog(@"NSNotFoundS");
            value = [accuracyArray indexOfObject:@(kCLLocationAccuracyNearestTenMeters)];
        }
    }
    slider.value = value;

}

- (void)sliderValueChanged:(UISlider *)slider {
    
    STMSettingsTVCell *cell = [self cellForView:slider];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    double step = [[self stepForIndexPath:indexPath] doubleValue];
    
    if ([settingName isEqualToString:@"distanceFilter"]) {
        [slider setValue:floor(slider.value/step)*step];
    } else {
        [slider setValue:rint(slider.value/step)*step];
    }
    
    NSString *value = [NSString stringWithFormat:@"%f", slider.value];

    if ([settingName isEqualToString:@"desiredAccuracy"]) {
        value = [self desiredAccuracyValueFrom:rint(slider.value)];
    }
    
    cell.detailTextLabel.text = [self formatValue:value forSettingName:settingName];

}

- (void)sliderValueChangeFinished:(UISlider *)slider {
    
    STMSettingsTVCell *cell = [self cellForView:slider];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    NSString *value = [NSString stringWithFormat:@"%f", slider.value];
    
    if ([settingName isEqualToString:@"desiredAccuracy"]) {
        value = [self desiredAccuracyValueFrom:rint(slider.value)];
    }
    
    NSString *groupName = [self groupNames][indexPath.section];
    [self.session.settingsController setNewSettings:@{settingName: value} forGroup:groupName];

}

- (NSString *)desiredAccuracyValueFrom:(int)index {
    NSArray *accuracyArray = @[@(kCLLocationAccuracyBestForNavigation),
                              @(kCLLocationAccuracyBest),
                              @(kCLLocationAccuracyNearestTenMeters),
                              @(kCLLocationAccuracyHundredMeters),
                              @(kCLLocationAccuracyKilometer),
                              @(kCLLocationAccuracyThreeKilometers)];
    return [NSString stringWithFormat:@"%@", accuracyArray[index]];
}

- (void)switchValueChanged:(UISwitch *)senderSwitch {
    
    STMSettingsTVCell *cell = [self cellForView:senderSwitch];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    NSString *value = [NSString stringWithFormat:@"%d", senderSwitch.on];
    NSString *groupName = [self groupNames][indexPath.section];
    [self.session.settingsController setNewSettings:@{settingName: value} forGroup:groupName];
    
}

- (void)segmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    
    STMSettingsTVCell *cell = [self cellForView:segmentedControl];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    NSString *value = [NSString stringWithFormat:@"%ld", (long)segmentedControl.selectedSegmentIndex];
    NSString *groupName = [self groupNames][indexPath.section];
    [self.session.settingsController setNewSettings:@{settingName: value} forGroup:groupName];
    
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [textField resignFirstResponder];
    return YES;
    
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    
    STMSettingsTVCell *cell = [self cellForView:textField];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSString *settingName = [self settingNameForIndexPath:indexPath];
    NSString *groupName = [self groupNames][indexPath.section];
    textField.text = [self.session.settingsController setNewSettings:@{settingName: textField.text} forGroup:groupName];

    return YES;
    
}

#pragma mark - view lifecycle

- (instancetype)initWithStyle:(UITableViewStyle)style {
    
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)customInit {

    self.title = NSLocalizedString(@"SETTINGS", @"");
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"settingsChanged" object:self.session];

    
}

//- (void)viewWillAppear:(BOOL)animated {
//    
//    [super viewWillAppear:animated];
//    
//}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}

- (void)didReceiveMemoryWarning {
    
    if ([STMFunctions shouldHandleMemoryWarningFromVC:self]) {
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"settingsChanged" object:self.session];
        [STMFunctions nilifyViewForVC:self];
        
    }

    [super didReceiveMemoryWarning];
    
}

@end
