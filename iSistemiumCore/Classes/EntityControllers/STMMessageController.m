//
//  STMMessageController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 05/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMMessageController.h"
#import "STMCoreObjectsController.h"
#import "STMRecordStatusController.h"

#import "STMMessageVC.h"
#import "STMCoreRootTBC.h"

@interface STMMessageController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *messagesResultsController;
@property (nonatomic, strong) NSFetchedResultsController *readMessagesResultsController;

@property (nonatomic, strong) NSMutableDictionary *shownPictures;
@property (nonatomic, strong) NSMutableArray *fullscreenPictures;


@end


@implementation STMMessageController

+ (STMMessageController *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self addObservers];
    }
    return self;
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(authStateChanged)
               name:@"authControllerStateChanged"
             object:[STMCoreAuthController authController]];
    
}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)authStateChanged {
    
    if ([STMCoreAuthController authController].controllerState != STMAuthSuccess) {
        [self flushSelf];
    }
    
}

- (void)flushSelf {
    
    self.fullscreenPictures = nil;
    self.shownPictures = nil;
    self.messagesResultsController = nil;
    self.readMessagesResultsController = nil;
    
}

- (NSMutableArray *)fullscreenPictures {
    
    if (!_fullscreenPictures) {
        _fullscreenPictures = @[].mutableCopy;
    }
    return _fullscreenPictures;
    
}

- (NSMutableDictionary *)shownPictures {
    
    if (!_shownPictures) {
        _shownPictures = @{}.mutableCopy;
    }
    return _shownPictures;
    
}

- (NSFetchedResultsController *)messagesResultsController {
    
    if (!_messagesResultsController) {
        
        NSString *entityName = NSStringFromClass([STMMessage class]);
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        
        NSFetchedResultsController *resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                            managedObjectContext:[STMMessageController document].managedObjectContext
                                                                                              sectionNameKeyPath:nil
                                                                                                       cacheName:nil];
        resultsController.delegate = self;
        [resultsController performFetch:nil];

        _messagesResultsController = resultsController;
        
    }
    return _messagesResultsController;
    
}

- (NSFetchedResultsController *)readMessagesResultsController {
    
    if (!_readMessagesResultsController) {
        
        NSManagedObjectContext *context = [STMMessageController document].managedObjectContext;
        
        if (context) {
            
            NSString *entityName = NSStringFromClass([STMRecordStatus class]);
            
            STMFetchRequest *request = [[STMFetchRequest alloc] initWithEntityName:entityName];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
            request.predicate = [NSPredicate predicateWithFormat:@"(objectXid IN %@) && (isRead == YES)", [self.messagesResultsController.fetchedObjects valueForKeyPath:@"xid"]];
            
            NSFetchedResultsController *resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                                managedObjectContext:context
                                                                                                  sectionNameKeyPath:nil
                                                                                                           cacheName:nil];
            resultsController.delegate = self;
            [resultsController performFetch:nil];
            
            _readMessagesResultsController = resultsController;

        }
        
    }
    return _readMessagesResultsController;
    
}

- (void)pictureDidShown:(STMMessagePicture *)picture {
    
    [self.fullscreenPictures removeObject:picture];
    
    if (picture.xid) {
        
        STMMessage *message = picture.message;
        
        if (message.xid && ![STMMessageController messageIsRead:message]) {
            
            NSMutableArray *shownPicturesArray = self.shownPictures[(NSData * _Nonnull)message.xid];
            if (!shownPicturesArray) shownPicturesArray = @[].mutableCopy;
            if (picture.xid) [shownPicturesArray addObject:(NSData * _Nonnull)picture.xid];
            self.shownPictures[(NSData * _Nonnull)message.xid] = shownPicturesArray;
            
            NSSet *picturesXids = [message valueForKeyPath:@"pictures.xid"];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (self IN %@)", shownPicturesArray];
            NSUInteger unshownPicturesCount = [picturesXids.allObjects filteredArrayUsingPredicate:predicate].count;
            
            if (unshownPicturesCount == 0) {
                
                [STMMessageController markMessageAsRead:message];
                [self.shownPictures removeObjectForKey:(NSData * _Nonnull)message.xid];
                
            }
            
        }

    }
    
}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
        case NSFetchedResultsChangeDelete: {
            
            if ([controller isEqual:self.messagesResultsController]) {
                self.readMessagesResultsController = nil;
            } else if ([controller isEqual:self.readMessagesResultsController]) {
//                [[NSNotificationCenter defaultCenter] postNotificationName:@"readMessageCountIsChanged" object:self];
            }

            [[NSNotificationCenter defaultCenter] postNotificationName:@"readMessageCountIsChanged" object:self];

            break;
        }
        case NSFetchedResultsChangeMove:
        case NSFetchedResultsChangeUpdate:
        default: {
            break;
        }
    }


}


#pragma mark - class methods

+ (NSArray *)sortedPicturesArrayForMessage:(STMMessage *)message {
    
    NSSortDescriptor *ordSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"ord" ascending:YES selector:@selector(compare:)];
    NSSortDescriptor *idSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)];
    NSArray *picturesArray = [message.pictures sortedArrayUsingDescriptors:@[ordSortDescriptor, idSortDescriptor]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"imageThumbnail != %@", nil];
    picturesArray = [picturesArray filteredArrayUsingPredicate:predicate];

    return picturesArray;
    
}

+ (void)showMessageVCsIfNeeded {
    
    NSArray *messages = [self messagesWithShowOnEnterForeground];
    
    NSArray *messagesXids = [messages valueForKeyPath:@"xid"];
    
    NSArray *recordStatuses = [STMRecordStatusController recordStatusesForXids:messagesXids];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isRead == YES"];
    recordStatuses = [recordStatuses filteredArrayUsingPredicate:predicate];
    
    NSArray *xids = [recordStatuses valueForKeyPath:@"objectXid"];
    
    predicate = [NSPredicate predicateWithFormat:@"NOT (xid IN %@)", xids];
    messages = [messages filteredArrayUsingPredicate:predicate];
    
    [self showMessageVCsForMessages:messages];
    
}

+ (NSArray *)messagesWithShowOnEnterForeground {
    
    STMFetchRequest *request = [[STMFetchRequest alloc] initWithEntityName:NSStringFromClass([STMMessage class])];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"cts" ascending:YES selector:@selector(compare:)];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"showOnEnterForeground == YES"];
    
    request.sortDescriptors = @[sortDescriptor];
    request.predicate = predicate;
    
    NSArray *messages = [[self document].managedObjectContext executeFetchRequest:request error:nil];

    return messages;
    
}

+ (void)showMessageVCsForMessages:(NSArray *)messages {
    
    for (STMMessage *message in messages) {
        [self showMessageVCsForMessage:message];
    }
    
}

+ (void)showMessageVCsForMessage:(STMMessage *)message {

    NSArray *picturesArray = [self sortedPicturesArrayForMessage:message];
    
    for (STMMessagePicture *picture in picturesArray) {
        
        if (![[self sharedInstance].fullscreenPictures containsObject:picture]) {
            
            [[self sharedInstance].fullscreenPictures addObject:picture];
            
            UIViewController *presenter = [[STMCoreRootTBC sharedRootVC] topmostVC];
            
            STMMessageVC *messageVC = [self messageVCWithPicture:picture andText:message.body];
            [presenter presentViewController:messageVC animated:NO completion:nil];

        }
        
    }
    
}

+ (STMMessageVC *)messageVCWithPicture:(STMMessagePicture *)picture andText:(NSString *)text {
    
    UIStoryboard *messageVCStoryboard = [UIStoryboard storyboardWithName:@"STMMessageVC" bundle:nil];
    STMMessageVC *messageVC = [messageVCStoryboard instantiateInitialViewController];
    
    messageVC.picture = picture;
    messageVC.text = text;
    
    return messageVC;

}

+ (void)pictureDidShown:(STMMessagePicture *)picture {
    [[self sharedInstance] pictureDidShown:picture];
}

+ (void)markMessageAsRead:(STMMessage *)message andSync:(BOOL)shouldSync {
    
    STMRecordStatus *recordStatus = [STMRecordStatusController recordStatusForObject:message];
    
    if (recordStatus.isRead.boolValue != YES) {
        
        recordStatus.isRead = @YES;
        
        if (shouldSync) {
            
            [self.document saveDocument:^(BOOL success) {
                
//                if (success) {
//                    
//                    //            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageIsRead" object:nil];
//                    self.syncer.syncerState = STMSyncerSendDataOnce;
//                    
//                }
                
            }];

        }
        
    }

}

+ (void)markMessageAsRead:(STMMessage *)message {
    [self markMessageAsRead:message andSync:YES];
}

+ (void)markAllMessageAsRead {
    
    NSMutableArray *messageArray = [self sharedInstance].messagesResultsController.fetchedObjects.mutableCopy;
    NSArray *readMessageArray = [self sharedInstance].readMessagesResultsController.fetchedObjects.copy;

    [messageArray removeObjectsInArray:readMessageArray];
    
    if (messageArray.count > 0) {
        
        for (STMMessage *message in messageArray) {
            [self markMessageAsRead:message andSync:NO];
        }
        
        [self.document saveDocument:^(BOOL success) {
//            if (success) self.syncer.syncerState = STMSyncerSendDataOnce;
        }];

    }
    
}

+ (BOOL)messageIsRead:(STMMessage *)message {

    STMRecordStatus *recordStatus = [STMRecordStatusController existingRecordStatusForXid:message.xid];

    return [recordStatus.isRead boolValue];
    
}

+ (NSUInteger)unreadMessagesCount {
    
    return [self unreadMessagesCountInContext:nil];
    
}

+ (NSUInteger)unreadMessagesCountInContext:(NSManagedObjectContext *)context {
    
    NSArray *messageArray = [self sharedInstance].messagesResultsController.fetchedObjects;
    NSArray *readMessageArray = [[self sharedInstance].readMessagesResultsController.fetchedObjects valueForKeyPath:@"@distinctUnionOfObjects.objectXid"];
    
    NSInteger unreadMessageCount = messageArray.count - readMessageArray.count;
    unreadMessageCount = (unreadMessageCount < 0) ? 0 : unreadMessageCount;
    
    return unreadMessageCount;

}


@end
