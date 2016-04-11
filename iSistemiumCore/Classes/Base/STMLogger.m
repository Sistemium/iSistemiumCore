//
//  STMLogger.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMLogger.h"
#import "STMDocument.h"
#import "STMEntityDescription.h"
#import "STMFunctions.h"

#import "STMObjectsController.h"

@interface STMLogger() <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) STMDocument *document;
@property (strong, nonatomic) NSFetchedResultsController *resultsController;

@property (nonatomic, strong) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, strong) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, strong) NSMutableArray *deletedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *insertedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *updatedRowIndexPaths;

@end


@implementation STMLogger


#pragma mark - class methods

+ (STMLogger *)sharedLogger {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedLogger = nil;
    
    dispatch_once(&pred, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
    
}

+ (void)requestInfo:(NSString *)xidString {
    [[self sharedLogger] requestInfo:xidString];
}

+ (void)requestObjects:(NSDictionary *)parameters {
    [[self sharedLogger] requestObjects:parameters];
}

+ (void)requestDefaults {
    [[self sharedLogger] requestDefaults];
}


#pragma mark - instance methods

- (instancetype)init {
    
    self = [super init];
    if (self) {

    }
    return self;
    
}

- (void)requestInfo:(NSString *)xidString {
    
    if (![xidString isEqual:[NSNull null]]) {
        
        NSData *xidData = [STMFunctions xidDataFromXidString:xidString];
        
        NSManagedObject *object = [STMObjectsController objectForXid:xidData];
        
        if (object) {
            
            NSDictionary *objectDic = [STMObjectsController dictionaryForObject:object];
            NSString *JSONString = [STMFunctions jsonStringFromDictionary:objectDic];
            [self saveLogMessageWithText:JSONString type:@"important"];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"no object with xid %@", xidString];
            [self saveLogMessageWithText:logMessage type:@"error"];
            
        }

    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"xidSting is NSNull"];
        [self saveLogMessageWithText:logMessage type:@"error"];
        
    }
    
    [self.document saveDocument:^(BOOL success) {
//        if (success) [[self.session syncer] setSyncerState:STMSyncerSendDataOnce];
    }];
    
}

- (void)requestObjects:(NSDictionary *)parameters {
    
    NSError *error;
    
    NSArray *jsonArray = [STMObjectsController jsonForObjectsWithParameters:parameters error:&error];

    if (!error) {

        NSDictionary *jsonDic = @{@"objects": jsonArray,
                                  @"requestParameters": parameters};

        NSString *JSONString = [STMFunctions jsonStringFromDictionary:jsonDic];
        [self saveLogMessageWithText:JSONString type:@"important"];
        
    } else {

        [self saveLogMessageWithText:error.localizedDescription type:@"error"];

    }

    [self.document saveDocument:^(BOOL success) {
//        if (success) [[self.session syncer] setSyncerState:STMSyncerSendDataOnce];
    }];

}

- (void)requestDefaults {
    
    NSDictionary *defaultsDic = @{@"userDefault": [NSUserDefaults standardUserDefaults].dictionaryRepresentation};

    if (defaultsDic) {
        
        NSString *JSONString = [STMFunctions jsonStringFromDictionary:defaultsDic];
        
        [self saveLogMessageWithText:JSONString type:@"important"];

        [self.document saveDocument:^(BOOL success) {
//            if (success) [[self.session syncer] setSyncerState:STMSyncerSendDataOnce];
        }];

    }
}

- (void)setSession:(id <STMSession>)session {
    
    if (_session != session) {
        
        _session = session;
        self.document = (STMDocument *)session.document;
        
    }
    
}

- (void)setDocument:(STMDocument *)document {
    
    if (_document != document) {
        
        _document = document;
        self.resultsController = nil;

    }
    
}

- (NSArray *)availableTypes {
    return @[@"error", @"warning", @"info", @"debug", @"important"];
}

- (NSArray *)syncingTypesForSettingType:(NSString *)settingType {
    
    NSMutableArray *types = [[self availableTypes] mutableCopy];
    
    if ([settingType isEqualToString:@"debug"]) {
        return types;
    } else {
        [types removeObject:@"debug"];
        
        if ([settingType isEqualToString:@"info"]) {
            return types;
        } else {
            [types removeObject:@"info"];
            
            if ([settingType isEqualToString:@"warning"]) {
                return types;
            } else {
                [types removeObject:@"warning"];
                
                if ([settingType isEqualToString:@"error"]) {
                    return types;
                } else {
                    [types removeObject:@"error"];
                    return types;
                    
                }
                
            }
            
        }
        
    }
    
// type @"important" sync always
    
}

- (void)saveLogMessageWithText:(NSString *)text {
    [self saveLogMessageWithText:text type:@"info"];
}

- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type {
    [self saveLogMessageWithText:text type:type owner:nil];
}

- (void)saveLogMessageWithText:(NSString *)text type:(NSString *)type owner:(STMDatum *)owner {
    
    if (![[self availableTypes] containsObject:type]) type = @"info";
    
    NSLog(@"Log %@: %@", type, text);
    
    BOOL sessionIsRunning = [[self.session status] isEqualToString:@"running"];
    
    if (sessionIsRunning && self.document) {
        
        STMLogMessage *logMessage = (STMLogMessage *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMLogMessage class]) isFantom:NO];
        logMessage.text = text;
        logMessage.type = type;
//        logMessage.owner = owner;
        
        [self.document saveDocument:^(BOOL success) {
        }];
        
    } else {
        [self saveLogMessageDictionary:@{@"text": [NSString stringWithFormat:@"%@", text], @"type": [NSString stringWithFormat:@"%@", type]}];
    }

}

- (void)saveLogMessageDictionary:(NSDictionary *)logMessageDic {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *loggerDefaults = [defaults dictionaryForKey:[self loggerKey]];
    NSMutableDictionary *loggerDefaultsMutable = [NSMutableDictionary dictionaryWithDictionary:loggerDefaults];
    NSString *insertKey = [@(loggerDefaultsMutable.allValues.count) stringValue];

    NSMutableDictionary *logMessageDicMutable = [NSMutableDictionary dictionaryWithDictionary:logMessageDic];
    logMessageDicMutable[@"deviceCts"] = [NSDate date];
    
    loggerDefaultsMutable[insertKey] = logMessageDicMutable;
    
    [defaults setObject:loggerDefaultsMutable forKey:[self loggerKey]];
    [defaults synchronize];
    
}

- (void)saveLogMessageDictionaryToDocument {
    
    NSLog(@"saveLogMessageDictionaryToDocument");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *loggerDefaults = [defaults dictionaryForKey:[self loggerKey]];

    for (NSDictionary *logMessageDic in [loggerDefaults allValues]) {
        
        STMLogMessage *logMessage = (STMLogMessage *)[STMObjectsController newObjectForEntityName:NSStringFromClass([STMLogMessage class]) isFantom:NO];
        
        for (NSString *key in [logMessageDic allKeys]) {
            [logMessage setValue:logMessageDic[key] forKey:key];
        }
        
//        if ([logMessage.type isEqualToString:@"error"]) NSLog(@"logMessage %@", logMessage);
        
    }
    
    [defaults removeObjectForKey:[self loggerKey]];
    [defaults synchronize];
    
    [self.document saveDocument:^(BOOL success) {
    }];
    
}

- (NSString *)loggerKey {
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *loggerKey = [bundleIdentifier stringByAppendingString:@".logger"];

    return loggerKey;
    
}

- (NSFetchedResultsController *)resultsController {
    
    if (!_resultsController) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([STMLogMessage class])];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"deviceCts"
                                                                  ascending:NO
                                                                   selector:@selector(compare:)]];
        
        _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                 managedObjectContext:self.document.managedObjectContext
                                                                   sectionNameKeyPath:@"dayAsString"
                                                                            cacheName:nil];
        _resultsController.delegate = self;
        
        NSError *error;
        if (![_resultsController performFetch:&error]) NSLog(@"performFetch error %@", error);
        
    }
    
    return _resultsController;
    
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
    
    cell.detailTextLabel.text = (logMessage.deviceCts) ? [startDateFormatter stringFromDate:(NSDate * _Nonnull)logMessage.deviceCts] : @"";
    
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

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    
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
            
        default:
            ; // Shouldn't have a default
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
