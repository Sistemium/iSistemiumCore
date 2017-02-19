//
//  STMFmdb+Transactions.h
//  iSisSales
//
//  Created by Alexander Levin on 19/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFmdb+Private.h"
#import "STMPersistingTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMFmdbTransaction : NSObject <STMPersistingTransaction>

+ (instancetype)persistingTransactionWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB;
- (instancetype)initWithFMDatabase:(FMDatabase*)database stmFMDB:(STMFmdb *)stmFMDB;

@end

NS_ASSUME_NONNULL_END
