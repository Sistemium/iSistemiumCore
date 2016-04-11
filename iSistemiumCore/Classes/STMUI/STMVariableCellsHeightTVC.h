//
//  STMVariableCellsHeightTVC.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 03/06/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMFetchedResultsControllerTVC.h"

#define SINGLE_LINE_HEADER_HEIGHT 56

@interface STMVariableCellsHeightTVC : STMFetchedResultsControllerTVC

@property (strong, nonatomic) NSMutableDictionary *cachedCellsHeights;
@property (nonatomic) CGFloat standardCellHeight;

- (void)fillCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

- (void)putCachedHeight:(CGFloat)height forIndexPath:(NSIndexPath *)indexPath;
- (NSNumber *)getCachedHeightForIndexPath:(NSIndexPath *)indexPath;

- (UITableViewCell *)cellForHeightCalculationForIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)heightForCellAtIndexPath:(NSIndexPath *)indexPath;

- (void)deviceOrientationDidChangeNotification:(NSNotification *)notification;



@end
