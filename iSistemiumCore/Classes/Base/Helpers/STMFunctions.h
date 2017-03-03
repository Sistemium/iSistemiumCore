//
//  STFunctions.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "STMConstants.h"

// Don't import any STM headers
// This class is only for generic methods

@interface STMDateFormatter : NSDateFormatter

@end

#define STMIsNull(a,b) a ? a : b

@interface STMFunctions : NSObject

NS_ASSUME_NONNULL_BEGIN

+ (BOOL)isCorrectPhoneNumber:(NSString *)phoneNumberString;
+ (BOOL)isCorrectSMSCode:(NSString *)SMSCode;

+ (NSData *)dataWithHexString:(NSString *)hexString;
+ (NSData *)dataFromString:(NSString *)string;
+ (nullable NSData *)xidDataFromXidString:(nullable NSString  *)xidString;
+ (NSData *)UUIDDataFromNSUUID:(NSUUID *)nsuuid;
+ (NSString *)UUIDStringFromUUIDData:(NSData *)UUIDData;
+ (NSString *)hexStringFromData:(NSData *)data;
+ (NSString *)base64HexStringFromData:(NSData *)data;

+ (NSString *)uuidString;

+ (NSString *)pluralTypeForCount:(NSUInteger)count;

+ (UIImage *)resizeImage:(nullable UIImage *)image toSize:(CGSize)size;
+ (UIImage *)resizeImage:(nullable UIImage *)image toSize:(CGSize)size allowRetina:(BOOL)retina;
+ (UIImage *)colorImage:(UIImage *)origImage withColor:(UIColor *)color;
+ (UIImage *)drawText:(NSString *)text withFont:(UIFont *)font color:(UIColor *)color inImage:(UIImage *)image atCenter:(BOOL)atCenter;

+ (NSNumber *)daysFromTodayToDate:(NSDate *)date;

+ (NSString *)displayDateInfo:(nullable NSString *)dateInfo;

+ (NSDate *)dateFromString:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date;
+ (NSString *)stringFromNow;

+ (NSString *)addPrefixToEntityName:(NSString*)entityName;
+ (NSString *)removePrefixFromEntityName:(NSString*)entityName;

+ (NSDateFormatter *)dateNumbersFormatter;
+ (NSDateFormatter *)dateNumbersFormatterTwo;
+ (NSDateFormatter *)dateShortNoTimeFormatter;
+ (NSDateFormatter *)dateShortTimeShortFormatter;
+ (NSDateFormatter *)dateMediumNoTimeFormatter;
+ (NSDateFormatter *)dateLongNoTimeFormatter;
+ (NSDateFormatter *)dateMediumTimeMediumFormatter;
+ (NSDateFormatter *)dateMediumTimeShortFormatter;
+ (NSDateFormatter *)noDateShortTimeFormatter;
+ (NSDateFormatter *)noDateMediumTimeFormatter;
+ (NSDateFormatter *)noDateShortTimeFormatterAllowZero:(BOOL)allowZero;

+ (void)NSLogCurrentDateWithMilliseconds;

+ (NSDate *)dateFromDouble:(double)time;
+ (double)currentTimeInDouble;

+ (NSString *)trueMinus;

+ (NSNumberFormatter *)decimalFormatter;
+ (NSNumberFormatter *)decimalMaxTwoDigitFormatter;
+ (NSNumberFormatter *)decimalMinTwoDigitFormatter;
+ (NSNumberFormatter *)decimalMaxTwoMinTwoDigitFormatter;
+ (NSNumberFormatter *)currencyFormatter;
+ (NSNumberFormatter *)percentFormatter;

+ (NSString *)dayWithDayOfWeekFromDate:(NSDate *)date;

+ (NSString *)MD5FromString:(nullable NSString *)string;

+ (NSString *)devicePlatform;
+ (NSString *)currentAppVersion;

+ (NSString *)documentsDirectory;
+ (NSString *)absolutePathForPath:(nullable NSString *)path;
+ (NSString *)absoluteDocumentsPathForPath:(nullable NSString *)path;
+ (NSString *)absoluteDataCachePath;
+ (NSString *)absoluteDataCachePathForPath:(nullable NSString *)path;
+ (NSString *)absoluteTemporaryPathForPath:(nullable NSString *)path;

+ (UIColor *)colorForColorString:(NSString *)colorSting;

+ (CGRect)frameOfHighlightedTabBarButtonForTBC:(UITabBarController *)tabBarController;

// - JSON representation

+ (id)jsonObjectFromString:(NSString *)string;
+ (NSString *)jsonStringFromObject:(id)object;
+ (NSString *)jsonStringFromArray:(NSArray *)objectArray;
+ (NSString *)jsonStringFromDictionary:(NSDictionary *)objectDic;
+ (NSDictionary *)validJSONDictionaryFromDictionary:(NSDictionary *)dictionary;

+ (NSString *)volumeStringWithVolume:(NSInteger)volume andPackageRel:(NSInteger)packageRel;

+ (BOOL)shouldHandleMemoryWarningFromVC:(UIViewController *)vc;
+ (void)nilifyViewForVC:(UIViewController *)vc;
+ (void)logMemoryStat;
+ (NSString *)memoryStatistic;

+ (nullable NSString *)shortCompanyName:(nullable NSString *)companyName;

+ (NSString *)appStateString;

+ (uint64_t)freeDiskspace;

+ (NSString *)uppercaseFirst:(NSString *)inputString;
+ (NSString *)lowercaseFirst:(NSString *)inputString;

+ (nullable id)popArray:(NSMutableArray *)array;
+ (void)moveObject:(id)object toTheHeadOfArray:(NSMutableArray *)array;
+ (void)moveObject:(id)object toTheTailOfArray:(NSMutableArray *)array;

+ (NSDictionary*)mapDictionary:(NSDictionary*)dictionary withBlock:(id (^)(id value, id key))mapperBlock;
+ (NSArray *)mapArray:(NSArray*)array withBlock:(id (^)(id value))mapperBlock;
+ (NSDictionary <NSString *, NSArray <NSDictionary <NSString *, id> *> *> *)groupArray:(NSArray <NSDictionary <NSString *, id> *> *)array byKey:(NSString *)key;

+ (BOOL)error:(NSError **)error withMessage:(NSString * _Nullable)errorMessage;
+ (NSError *)errorWithMessage:(NSString *)errorMessage;

+ (NSDictionary*)setValue:(id)value forKey:(id)key inDictionary:(NSDictionary*)dictionary;

+ (nullable NSString *)currentTestTarget;

+ (BOOL)isNotNullAndTrue:(id)value;
+ (BOOL)isNotNull:(nullable id)value;
+ (BOOL)isNullBoth:(id)value1 and:(id)value2;

+ (NSString *)printableTimeInterval:(NSTimeInterval)timeInterval;

+ (NSDictionary *)callerInfo;


NS_ASSUME_NONNULL_END


@end
