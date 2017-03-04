//
//  STMLogger.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/05/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMLogger+Private.h"
#import "STMLogMessage.h"
#import "STMCoreSettingsController.h"


#define PATTERN_DEPTH 5


@implementation STMLogger

#pragma mark - initializers



+ (STMLogger *)sharedLogger {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedLogger = nil;
    
    dispatch_once(&pred, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
    
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}


#pragma mark - Private properties

- (NSUInteger)patternDepth {
    
    if (!_patternDepth) {
        _patternDepth = PATTERN_DEPTH;
    }
    return _patternDepth;
    
}

- (NSString *)uploadLogType {
    
    if (!_uploadLogType) {
        
        _uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                  forGroup:@"syncer"];
        
    }
    return _uploadLogType;
    
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


#pragma mark - Private helpers


- (void)syncerSettingsChanged:(NSNotification *)notification {
    self.uploadLogType = nil;
}


- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(syncerSettingsChanged:)
               name:@"syncerSettingsChanged"
             object:nil];
    
}

@end

