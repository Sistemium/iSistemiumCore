//
//  STMFetchedResultsControllerTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 11/08/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMFetchedResultsControllerTVC.h"

@interface STMFetchedResultsControllerTVC ()

@property (nonatomic, strong) NSMutableArray *selectedObjects;

@end


@implementation STMFetchedResultsControllerTVC

- (STMDocument *)document {
    
    if (!_document) {
        
        _document = (STMDocument *)[STMSessionManager sharedManager].currentSession.document;
        
    }
    
    return _document;
    
}

- (NSString *)cellIdentifier {
    
    if (!_cellIdentifier) {
        
        NSString *selfClassName = NSStringFromClass([self class]);
        NSString *cellIdentifier = [selfClassName stringByAppendingString:@"_cellIdentifier"];
        
        _cellIdentifier = cellIdentifier;
        
    }
    return _cellIdentifier;
    
}

- (NSMutableIndexSet *)deletedSectionIndexes {
    
    if (!_deletedSectionIndexes) {
        _deletedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    
    return _deletedSectionIndexes;
    
}

- (NSMutableIndexSet *)insertedSectionIndexes {
    
    if (!_insertedSectionIndexes) {
        _insertedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    
    return _insertedSectionIndexes;
    
}

- (NSMutableArray *)deletedRowIndexPaths {
    
    if (!_deletedRowIndexPaths) {
        _deletedRowIndexPaths = [NSMutableArray array];
    }
    
    return _deletedRowIndexPaths;
    
}

- (NSMutableArray *)insertedRowIndexPaths {
    
    if (!_insertedRowIndexPaths) {
        _insertedRowIndexPaths = [NSMutableArray array];
    }
    
    return _insertedRowIndexPaths;
    
}

- (NSMutableArray *)updatedRowIndexPaths {
    
    if (!_updatedRowIndexPaths) {
        _updatedRowIndexPaths = [NSMutableArray array];
    }
    
    return _updatedRowIndexPaths;
    
}

- (void)authControllerStateChanged {
    
    if ([STMAuthController authController].controllerState != STMAuthSuccess) {
        self.resultsController = nil;
    }
    
}

- (void)performFetch {
    
    [self performFetchWithCompletionHandler:^(BOOL success) {
        
        if (success) {
            [self successfulFetchCallback];
        }
        
    }];

}

- (void)successfulFetchCallback {
    [self.tableView reloadData];
}

- (void)performFetchWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    self.resultsController = nil;
    
    NSError *error;
    
    if (![self.resultsController performFetch:&error]) {
        
        NSLog(@"%@ performFetch error %@", NSStringFromClass([self class]), error);
        completionHandler(NO);
        
    } else {
        
        completionHandler(YES);
        
    }
    
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return self.resultsController.sections.count;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (self.resultsController.sections.count > 0) {
        
        id <NSFetchedResultsSectionInfo> sectionInfo = self.resultsController.sections[section];
        return [sectionInfo numberOfObjects];
        
    } else {
        
        return 0;
        
    }
    
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (self.resultsController.sections.count > 0) {
        
        id <NSFetchedResultsSectionInfo> sectionInfo = self.resultsController.sections[section];
        return [sectionInfo name];
        
    } else {
        
        return nil;
        
    }
    
}

- (NSIndexPath *)tableView:(UITableView *)tableView nearestIndexPathFor:(NSIndexPath *)indexPath {
    
    NSIndexPath *nearestIndexPath;
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    NSInteger numberOfSections = [tableView numberOfSections];
    NSInteger numberOfRows = [tableView numberOfRowsInSection:section];
    
    switch (numberOfSections) {
        case 0:
            nearestIndexPath = nil;
            break;

        case 1:
            switch (numberOfRows) {
                case (0 || 1):
                    nearestIndexPath = nil;
                    break;

                default:
                    switch (row) {
                        case 0:
                            nearestIndexPath = [NSIndexPath indexPathForRow:row+1 inSection:section];
                            break;
                            
                        default:
                            nearestIndexPath = [NSIndexPath indexPathForRow:row-1 inSection:section];
                            break;
                    }
                    break;
            }
            break;

        default:
            switch (section) {
                case 0:
                    switch (numberOfRows) {
                        case (0 || 1):
                            nearestIndexPath = [NSIndexPath indexPathForRow:0 inSection:section+1];
                            break;
                            
                        default:
                            switch (row) {
                                case 0:
                                    nearestIndexPath = [NSIndexPath indexPathForRow:row+1 inSection:section];
                                    break;
                                    
                                default:
                                    nearestIndexPath = [NSIndexPath indexPathForRow:row-1 inSection:section];
                                    break;
                            }
                            break;
                    }
                    break;
                    
                default:
                    switch (numberOfRows) {
                        case (0 || 1):
                            nearestIndexPath = [NSIndexPath indexPathForRow:[tableView numberOfRowsInSection:section-1]-1 inSection:section-1];
                            break;
                            
                        default:
                            switch (row) {
                                case 0:
                                    nearestIndexPath = [NSIndexPath indexPathForRow:row+1 inSection:section];
                                    break;
                                    
                                default:
                                    nearestIndexPath = [NSIndexPath indexPathForRow:row-1 inSection:section];
                                    break;
                            }
                            break;
                    }
                    break;
            }
            
            break;
    }
    
    return nearestIndexPath;
    
}


#pragma mark - NSFetchedResultsController delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    
//    NSLog(@"self class1 %@", NSStringFromClass([self class]));
    
    self.selectedObjects = [NSMutableArray array];
    
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        
        @try {
            NSManagedObject *object = [self.resultsController objectAtIndexPath:indexPath];
            [self.selectedObjects addObject:object];
        }
        @catch (NSException *exception) {
            [self.tableView deselectRowAtIndexPath:indexPath animated: true];
        }
        
//        NSLog(@"indexPath1 %@", indexPath);
        
    }
    
//    NSLog(@"self.selectedObjects.count1 %d", self.selectedObjects.count);
 
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
//    NSLog(@"self class2 %@", NSStringFromClass([self class]));

    [self.tableView beginUpdates];
    
    [self.tableView deleteSections:self.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView insertSections:self.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationFade];
    
    [self.tableView deleteRowsAtIndexPaths:self.deletedRowIndexPaths withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView insertRowsAtIndexPaths:self.insertedRowIndexPaths withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView reloadRowsAtIndexPaths:self.updatedRowIndexPaths withRowAnimation:UITableViewRowAnimationFade];
    
    [self.tableView endUpdates];
    
    self.insertedSectionIndexes = nil;
    self.deletedSectionIndexes = nil;
    self.deletedRowIndexPaths = nil;
    self.insertedRowIndexPaths = nil;
    self.updatedRowIndexPaths = nil;
  
    for (NSManagedObject *object in self.selectedObjects) {
        
        NSIndexPath *indexPath = [self.resultsController indexPathForObject:object];
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
//        NSLog(@"indexPath2 %@", indexPath);
        
    }
    
//    NSLog(@"self.selectedObjects.count2 %d", self.selectedObjects.count);
 
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch (type) {
            
        case NSFetchedResultsChangeInsert:
            [self.insertedSectionIndexes addIndex:sectionIndex];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.deletedSectionIndexes addIndex:sectionIndex];
            break;
            
        default:
            ; // Shouldn't have a default
            break;
            
    }
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    

//    if ([NSStringFromClass([self class]) isEqualToString:@"STMUncashingDetailsTVC"]) {
//        
//        NSLog(@"type %d", type);
//        NSLog(@"anObject %@", anObject);
//        
//    }
    
//    if ([NSStringFromClass([anObject class]) isEqualToString:@"STMDebt"]) {
//        
//        NSLog(@"self %@", self);
//        NSLog(@"anObject %@", anObject);
//        
//    }
    
    if (type == NSFetchedResultsChangeInsert) {
        
        if ([self.insertedSectionIndexes containsIndex:newIndexPath.section]) {
            return;
        }
        
        [self.insertedRowIndexPaths addObject:newIndexPath];
        
    } else if (type == NSFetchedResultsChangeDelete) {
        
        if ([self.deletedSectionIndexes containsIndex:indexPath.section]) {
            return;
        }
        
        [self.deletedRowIndexPaths addObject:indexPath];
        
    } else if (type == NSFetchedResultsChangeMove) {
        
        if (![self.insertedSectionIndexes containsIndex:newIndexPath.section]) {
            [self.insertedRowIndexPaths addObject:newIndexPath];
        }
        
        if (![self.deletedSectionIndexes containsIndex:indexPath.section]) {
            [self.deletedRowIndexPaths addObject:indexPath];
        }
        
    } else if (type == NSFetchedResultsChangeUpdate) {
        
        [self.updatedRowIndexPaths addObject:indexPath];
        
    }
    
}


#pragma mark - view lifecycle

- (void)customInit {
    
    self.clearsSelectionOnViewWillAppear = NO;
    
}

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authControllerStateChanged) name:@"authControllerStateChanged" object:[STMAuthController authController]];
    
    [self customInit];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
