//
//  STMFMDB_OBJC.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 16/12/2016.
//  Copyright © 2016 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMFMDB_OBJC.h"

#import "FMDB.h"

@implementation STMFMDB_OBJC

FMDatabase *database;

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths objectAtIndex:0];
        NSString *dbPath = [documentDirectory stringByAppendingPathComponent:@"database.db"];
        database = [FMDatabase databaseWithPath:dbPath];
    }
    return self;
}

-(NSArray<NSDictionary *> * _Nonnull)getDataByEntityNameWithName:(NSString * _Nonnull)name{
    
    NSMutableArray *rez = @[].mutableCopy;
    
    if ([database open]) {
        FMResultSet *s = [database executeQuery:[@"SELECT * FROM " stringByAppendingString:name]];
        while ([s next]) {
            [rez addObject:[s resultDictionary]];
        }
        [database close];
    } else {
        NSLog(@"STMFmdb error: \(database?.lastErrorMessage())")
    }
    return rez;
    
}


@end
