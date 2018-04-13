//
//  STMLogger+TableView.m
//  iSisSales
//
//  Created by Alexander Levin on 10/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMLogger+Private.h"

#import "STMFunctions.h"
#import "STMCoreDataModel.h"

@implementation STMLogger (TableView)


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return [[self.resultsController sections] count];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    id <NSFetchedResultsSectionInfo> sectionInfo = [self.resultsController sections][section];
    return [sectionInfo numberOfObjects];

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    id <NSFetchedResultsSectionInfo> sectionInfo = [self.resultsController sections][section];

    NSDateFormatter *dateFormatter = [STMFunctions dateNumbersFormatter];

    NSDate *date = [dateFormatter dateFromString:[sectionInfo name]];

    dateFormatter = [STMFunctions dateLongNoTimeFormatter];

    return [dateFormatter stringFromDate:date];

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *cellIdentifier = @"logCell";
    //    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];

    NSDateFormatter *startDateFormatter = [STMFunctions dateMediumTimeMediumFormatter];

    STMLogMessage *logMessage = [self.resultsController objectAtIndexPath:indexPath];

    cell.textLabel.text = logMessage.text;

    if ([logMessage.type isEqualToString:@"error"]) {
        cell.textLabel.textColor = [UIColor redColor];
    } else if ([logMessage.type isEqualToString:@"blue"]) {
        cell.textLabel.textColor = [UIColor blueColor];
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
    }

    cell.detailTextLabel.text = (logMessage.deviceCts) ? [startDateFormatter stringFromDate:(NSDate *_Nonnull) logMessage.deviceCts] : @"";

    return cell;

}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {

    return UITableViewCellEditingStyleNone;

}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    return indexPath;

}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {

    return nil;

}


#pragma mark - NSFetchedResultsController delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {

}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {

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

        default:; // Shouldn't have a default
            break;

    }

}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {

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

@end
