//
//  STMLogger+Private.h
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMLogger.h"

@interface STMLogger()

@property (strong, nonatomic) STMDocument *document;
@property (strong, nonatomic) NSFetchedResultsController *resultsController;

@property (nonatomic, strong) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, strong) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, strong) NSMutableArray *deletedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *insertedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *updatedRowIndexPaths;

@property (nonatomic, strong) NSString *uploadLogType;

@property (nonatomic, weak) UITableView *tableView;

@end
