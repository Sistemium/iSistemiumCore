//
//  STMPersister.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingObserving.h"
#import "STMPersistingSync.h"
#import "STMDocument.h"

#import "STMModeller+Interceptable.h"
#import "STMFmdb.h"

#import "STMFiling.h"


NS_ASSUME_NONNULL_BEGIN

@interface STMPersister : STMModeller <STMPersistingSync>

@property (nonatomic, strong) STMFmdb *fmdb;
@property (nonatomic, strong) STMDocument *document;
@property (nonatomic,strong) dispatch_queue_t dispatchQueue;

+ (instancetype)persisterWithModelName:(NSString *)modelName
                                filing:(id <STMFiling>)filing
                     completionHandler:(void (^ _Nullable)(BOOL success))completionHandler;

@end

NS_ASSUME_NONNULL_END

