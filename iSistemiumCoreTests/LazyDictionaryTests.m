//
//  LazyDictionaryTests.m
//  iSisSales
//
//  Created by Alexander Levin on 08/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STMLazyDictionary.h"

@interface LazyDictionaryTests : XCTestCase

@end

@implementation LazyDictionaryTests

- (void)setUp {
    [super setUp];
}

- (void)testLazyDictionaryUsage {
    
    Class itemsClass = NSMutableArray.class;

    STMLazyDictionary *dictionary = [STMLazyDictionary lazyDictionaryWithItemsClass:itemsClass];
    
    // dictionary value will be auto-instantiated with ItemsClass on first access
    
    NSString *KEY = @"key";
    
    XCTAssertNotNil(dictionary[KEY]);
    XCTAssertTrue([[dictionary[KEY] class] isSubclassOfClass:itemsClass]);

    // assigning with square brackets is supported
    
    NSString *KEY2 = @"key2";
    NSString *value = @"value for key 2";
    
    [dictionary[KEY2] addObject:value];
    
    XCTAssertEqualObjects([dictionary[KEY2] firstObject], value);
    
    // can assign any class object when assigning
    
    dictionary[KEY2] = value;
    
    XCTAssertEqualObjects(dictionary[KEY2], value);
    
    // assign nil to remove key
    
    dictionary[KEY2] = nil;
    
    // use hasKey: to test if there's a key
    
    XCTAssertFalse([dictionary hasKey:KEY2]);
    
    // also there are named equivalent methods for reading, writing and removing
    
    [dictionary setObject:value forKey:KEY2];
    XCTAssertEqualObjects([dictionary valueForKey:KEY2], value);
    XCTAssertEqualObjects([dictionary objectForKey:KEY2], value);
    
    [dictionary removeObjectForKey:KEY2];
    XCTAssertFalse([dictionary hasKey:KEY2]);
    
    // at this point there should remains only the KEY
    
    XCTAssertEqual(dictionary.allKeys.count, 1);
    XCTAssertEqualObjects(dictionary.allKeys.firstObject, KEY);
    
}

@end
