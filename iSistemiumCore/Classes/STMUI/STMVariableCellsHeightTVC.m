//
//  STMVariableCellsHeightTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/06/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMVariableCellsHeightTVC.h"

#import <Crashlytics/Crashlytics.h>


@interface STMVariableCellsHeightTVC ()


@end


@implementation STMVariableCellsHeightTVC


#pragma mark - deviceOrientationDidChangeNotification

- (void)deviceOrientationDidChangeNotification:(NSNotification *)notification {
    
    self.cachedCellsHeights = nil;
    
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    
    [self.tableView reloadData];
    
    if (selectedIndexPath) [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    
}


#pragma mark - cell's height caching

- (NSMutableDictionary *)cachedCellsHeights {
    
    if (!_cachedCellsHeights) {
        _cachedCellsHeights = [NSMutableDictionary dictionary];
    }
    return _cachedCellsHeights;
    
}

- (void)putCachedHeight:(CGFloat)height forIndexPath:(NSIndexPath *)indexPath {
    
    NSManagedObject *object = [self.resultsController objectAtIndexPath:indexPath];
    NSManagedObjectID *objectID = object.objectID;
    
    if (objectID) {
        self.cachedCellsHeights[objectID] = @(height);
    } else {
        CLS_LOG(@"objectID is nil for %@", object);
    }
    
}

- (NSNumber *)getCachedHeightForIndexPath:(NSIndexPath *)indexPath {
    
    NSManagedObjectID *objectID = [[self.resultsController objectAtIndexPath:indexPath] objectID];
    
    return self.cachedCellsHeights[objectID];
    
}


#pragma mark - table view dataSource & delegate

- (CGFloat)standardCellHeight {
    
    if (!_standardCellHeight) {
        
        static CGFloat standardCellHeight;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            standardCellHeight = [[UITableViewCell alloc] init].frame.size.height;
        });
        
        _standardCellHeight = standardCellHeight + 1.0f;  // Add 1.0f for the cell separator height
        
    }
    return _standardCellHeight;
    
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.standardCellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (SYSTEM_VERSION >= 8.0) {
        
        return [super tableView:self.tableView heightForRowAtIndexPath:indexPath];
        
    } else {

        NSNumber *cachedHeight = [self getCachedHeightForIndexPath:indexPath];
        CGFloat height = (cachedHeight) ? cachedHeight.floatValue : [self heightForCellAtIndexPath:indexPath];
        
        return height;
        
    }
    
}

- (UITableViewCell *)cellForHeightCalculationForIndexPath:(NSIndexPath *)indexPath {

    static UITableViewCell *cell = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cell = [self.tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
    });

    return cell;
    
}

- (CGFloat)heightForCellAtIndexPath:(NSIndexPath *)indexPath {
    
    if (SYSTEM_VERSION >= 8.0) {
        
        // autoHeight is always -1 if use [super tableView:self.tableView heightForRowAtIndexPath:indexPath]
        // may be remove this part of code

        CGFloat autoHeight = [super tableView:self.tableView heightForRowAtIndexPath:indexPath];

        if (autoHeight > 0) [self putCachedHeight:autoHeight forIndexPath:indexPath];

        return autoHeight;
        
    } else {
    
        UITableViewCell *cell = [self cellForHeightCalculationForIndexPath:indexPath];
        
        [self fillCell:cell atIndexPath:indexPath];
        
        cell.bounds = CGRectMake(0.0f, 0.0f, CGRectGetWidth(self.tableView.bounds) - MAGIC_NUMBER_FOR_CELL_WIDTH, CGRectGetHeight(cell.bounds));
        
        [cell setNeedsLayout];
        [cell layoutIfNeeded];
        
        CGSize size = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        CGFloat height = size.height + 1.0f; // Add 1.0f for the cell separator height
        
        height = (height < self.standardCellHeight) ? self.standardCellHeight : height;
        
        [self putCachedHeight:height forIndexPath:indexPath];
        
        return height;
    
    }
    
}

- (void)fillCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    if (SYSTEM_VERSION < 8.0) {
        
        [cell setNeedsUpdateConstraints];
        [cell updateConstraintsIfNeeded];

    }
    
}


#pragma mark - NSFetchedResultsController delegate

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    if ([anObject isKindOfClass:[NSManagedObject class]]) {
        
        NSManagedObjectID *objectID = [(NSManagedObject *)anObject objectID];
        [self.cachedCellsHeights removeObjectForKey:objectID];
        
    }
    
    [super controller:controller didChangeObject:anObject atIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(deviceOrientationDidChangeNotification:)
               name:UIDeviceOrientationDidChangeNotification
             object:nil];
    
    [super customInit];
    
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
