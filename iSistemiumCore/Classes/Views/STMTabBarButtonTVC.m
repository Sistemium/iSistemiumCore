//
//  STMTabBarButtonTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 19/05/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMTabBarButtonTVC.h"
#import "STMConstants.h"


@interface STMTabBarButtonTVC ()

@property (nonatomic) BOOL hasSiblings;
@property (nonatomic) BOOL hasActions;


@end


@implementation STMTabBarButtonTVC


- (BOOL)hasSiblings {
    
    if (!_hasSiblings) {
        _hasSiblings = (self.siblings) ? YES : NO;
    }
    return _hasSiblings;
    
}

- (BOOL)hasActions {
    
    if (!_hasActions) {
        _hasActions = (self.actions) ? YES : NO;
    }
    return _hasActions;
    
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    NSInteger numberOfSections = (IPHONE) ? 1 : 0;
    
    if (self.hasSiblings && self.hasActions) {
        numberOfSections += 2;
    } else if (self.hasSiblings || self.hasActions) {
        numberOfSections += 1;
    }

    return numberOfSections;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (self.hasSiblings && self.hasActions) {
        
        switch (section) {
            case 0:
                return self.siblings.count;
                break;
            case 1:
                return self.actions.count;
                break;
            case 2:
                return 1;
                break;
                
            default:
                return 0;
                break;
        }
        
    } else if (self.hasSiblings || self.hasActions) {

        switch (section) {
            case 0:
                return MAX(self.siblings.count, self.actions.count);
                break;
            case 1:
                return 1;
                break;
                
            default:
                return 0;
                break;
        }
    
    } else {
        
        return 1;
        
    }

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (self.hasSiblings && self.hasActions) {
        
        switch (section) {
            case 0:
                return NSLocalizedString(@"SHOW SIBLINGS", nil);
                break;
            case 1:
                return NSLocalizedString(@"SHOW ACTIONS", nil);
                break;
                
            default:
                return nil;
                break;
        }
        
    } else if (self.hasSiblings) {
        
        return NSLocalizedString(@"SHOW SIBLINGS", nil);
        
    } else if (self.hasActions) {
        
        return NSLocalizedString(@"SHOW ACTIONS", nil);
        
    } else {
        
        return nil;
        
    }

}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *reuseIdentifier = @"tabBarTVCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    
    cell.textLabel.textColor = ACTIVE_BLUE_COLOR;
    
    if (self.hasSiblings && self.hasActions) {
        
        switch (indexPath.section) {
            case 0:
                [self fillSiblingCell:cell forIndex:indexPath.row];
                break;
            case 1:
                [self fillActionCell:cell forIndex:indexPath.row];
                break;
            case 2:
                [self fillCloseCell:cell];
                break;
                
            default:
                break;
        }
        
    } else if (self.hasSiblings) {
        
        switch (indexPath.section) {
            case 0:
                [self fillSiblingCell:cell forIndex:indexPath.row];
                break;
            case 1:
                [self fillCloseCell:cell];
                break;
                
            default:
                break;
        }
        
    } else if (self.hasActions) {

        switch (indexPath.section) {
            case 0:
                [self fillActionCell:cell forIndex:indexPath.row];
                break;
            case 1:
                [self fillCloseCell:cell];
                break;
                
            default:
                break;
        }
        
    } else {

    }

    
    return cell;
    
}

- (void)fillSiblingCell:(UITableViewCell *)cell forIndex:(NSUInteger)index {
    
    UIViewController *vc = self.siblings[index];
    
    cell.textLabel.text = vc.title;
    cell.imageView.image = vc.tabBarItem.image;
    
    if (vc == self.parentVC) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
}

- (void)fillActionCell:(UITableViewCell *)cell forIndex:(NSUInteger)index {
    
    cell.textLabel.text = self.actions[index];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    
}

- (void)fillCloseCell:(UITableViewCell *)cell {
    
    cell.textLabel.text = NSLocalizedString(@"CLOSE", nil);
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = [UIColor redColor];
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.hasSiblings && self.hasActions) {

        if (indexPath.section == 0) {

            [self.parentVC selectSiblingAtIndex:indexPath.row];
            
        } else if (indexPath.section == 1) {
            
            [self.parentVC selectActionAtIndex:indexPath.row];
            
        } else if (indexPath.section == 2) {
            
            [self dismissViewControllerAnimated:YES completion:^{
                
            }];

        }
        
    } else if (self.hasSiblings) {

        if (indexPath.section == 0) {
            
            [self.parentVC selectSiblingAtIndex:indexPath.row];
            
        } else if (indexPath.section == 1) {
            
            [self dismissViewControllerAnimated:YES completion:^{
                
            }];
            
        }
        
    } else if (self.hasActions) {

        if (indexPath.section == 0) {
            
            [self.parentVC selectActionAtIndex:indexPath.row];
            
        } else if (indexPath.section == 1) {
            
            [self dismissViewControllerAnimated:YES completion:^{
                
            }];
            
        }

    } else {
        
    }

}


#pragma mark - view lifecycle

- (void)customInit {
    
    [self.tableView setNeedsLayout];
    [self.tableView layoutIfNeeded];
    
    self.tableView.frame = CGRectMake(0, 0, 320, self.tableView.contentSize.height);
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self customInit];
    
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
