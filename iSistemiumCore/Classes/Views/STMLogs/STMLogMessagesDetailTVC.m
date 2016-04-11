//
//  STMLogMessagesDetailTVC.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 12/12/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMLogMessagesDetailTVC.h"
#import <CoreData/CoreData.h>
#import "STMLogMessage.h"
#import "STMFunctions.h"

@interface STMLogMessagesDetailTVC ()

@end


@implementation STMLogMessagesDetailTVC

@synthesize resultsController = _resultsController;
@synthesize selectedDate = _selectedDate;

- (NSDate *)selectedDate {
    
    if (!_selectedDate) {
        
        NSDateFormatter *dateFormatter = [STMFunctions dateShortNoTimeFormatter];
        NSString *stringDate = [dateFormatter stringFromDate:[NSDate date]];
        
        _selectedDate = [dateFormatter dateFromString:stringDate];
        
    }
    
    return _selectedDate;
    
}

- (void)setSelectedDate:(NSDate *)selectedDate {
    
    if (_selectedDate != selectedDate) {
        
        _selectedDate = selectedDate;
        
        [self performFetch];
        
    }
    
}

- (NSFetchedResultsController *)resultsController {
    
    if (!_resultsController) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMLogMessage class])];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"deviceCts" ascending:NO selector:@selector(compare:)]];
        
        NSDate *startDate = self.selectedDate;
        NSDate *endDate = [NSDate dateWithTimeInterval:24*3600 sinceDate:startDate];
        
        request.predicate = [NSPredicate predicateWithFormat:@"(deviceCts >= %@) AND (deviceCts < %@)", startDate, endDate];
        
        _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:self.document.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        _resultsController.delegate = self;
        
    }
    
    return _resultsController;
    
}

- (void)performFetch {
    
    self.resultsController = nil;
    
    NSError *error;
    if (![self.resultsController performFetch:&error]) {
        
        NSLog(@"performFetch error %@", error);
        
    } else {
        
        [self.tableView reloadData];
        
    }
    
}


#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"detailLogCell" forIndexPath:indexPath];
    
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
    
    if (logMessage.deviceCts) cell.detailTextLabel.text = [startDateFormatter stringFromDate:(NSDate * _Nonnull)logMessage.deviceCts];
    
    return cell;
    
    
}


#pragma mark - view lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
