//
//  STFunctions.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 02/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMFunctions.h"

// Don't import any STM headers
// This class is only for generic methods

#import "STMCoreSessionManager.h"
#import "STMLogger.h"

// FIXME: move STM-dependent methods somewhere

#import <CommonCrypto/CommonDigest.h>
#import <sys/sysctl.h>
#import "mach/mach.h"


@implementation STMDateFormatter


@end

STMDateFormatter *sharedDateFormatterWithMilliseconds;
STMDateFormatter *sharedDateFormatterWithoutTime;

@implementation STMFunctions

+ (NSString *)displayDateInfo:(nullable NSString *)dateInfo {
    
    NSString *separator = @"-";
    NSArray *infoParts = [dateInfo componentsSeparatedByString:separator];
    infoParts = [[infoParts reverseObjectEnumerator] allObjects];
    separator = @"/";
    return [infoParts componentsJoinedByString:separator];

}


#pragma mark - date formatters

+ (STMDateFormatter *)dateFormatterWithMilliseconds {
    
//    @synchronized (sharedDateFormatterWithMilliseconds) {
    
        if (sharedDateFormatterWithMilliseconds) return sharedDateFormatterWithMilliseconds;
    
        STMDateFormatter *dateFormatterWithMilliseconds = [[STMDateFormatter alloc] init];
        dateFormatterWithMilliseconds.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatterWithMilliseconds.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatterWithMilliseconds.dateFormat = DATE_FORMAT_WITH_MILLISECONDS;
        
        sharedDateFormatterWithMilliseconds = dateFormatterWithMilliseconds;
        
        return sharedDateFormatterWithMilliseconds;

//    }
    
}

+ (STMDateFormatter *)dateFormatterWithoutTime {
    
//    @synchronized (sharedDateFormatterWithoutTime) {
    
        if (sharedDateFormatterWithoutTime) return sharedDateFormatterWithoutTime;

        STMDateFormatter *dateFormatterWithoutTime = [[STMDateFormatter alloc] init];
        dateFormatterWithoutTime.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatterWithoutTime.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatterWithoutTime.dateFormat = DATE_FORMAT_WITHOUT_TIME;
    
        sharedDateFormatterWithoutTime = dateFormatterWithoutTime;

        return sharedDateFormatterWithoutTime;
        
//    }
    
}

+ (NSDate *)dateFromString:(NSString *)string {
    
    BOOL isStringWithoutTime = (string && ![string isKindOfClass:[NSNull class]] && [string isKindOfClass:[NSString class]] && string.length == 10);
    
    STMDateFormatter *dateFormatter = (isStringWithoutTime) ? [self dateFormatterWithoutTime] : [self dateFormatterWithMilliseconds];
    
    return [dateFormatter dateFromString:string];
    
}

+ (NSString *)stringFromDate:(NSDate *)date {
    return [[self dateFormatterWithMilliseconds] stringFromDate:date];
}

+ (NSString *)stringFromNow {
    return [[self dateFormatterWithMilliseconds] stringFromDate:[NSDate date]];
}

+(NSString *)addPrefixToEntityName:(NSString*)entityName{
    if (![entityName hasPrefix:ISISTEMIUM_PREFIX]) {
        entityName = [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
    }
    return entityName;
}

+ (NSString *)removePrefixFromEntityName:(NSString *)entity{
    if ([entity hasPrefix:ISISTEMIUM_PREFIX]){
        return [entity substringFromIndex:ISISTEMIUM_PREFIX.length];
    }
    return entity ;
}

+ (NSDateFormatter *)dateNumbersFormatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy/MM/dd";

    return dateFormatter;
    
}

+ (NSDateFormatter *)dateNumbersFormatterTwo {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd/MM/yyyy";
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)dateNoTimeFormatter {

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.timeStyle = NSDateFormatterNoStyle;
    
    return dateFormatter;

}

+ (NSDateFormatter *)dateShortNoTimeFormatter {
    
    NSDateFormatter *dateFormatter = [self dateNoTimeFormatter];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)dateShortTimeShortFormatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)dateMediumNoTimeFormatter {
    
    NSDateFormatter *dateFormatter = [self dateNoTimeFormatter];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;

    return dateFormatter;
    
}

+ (NSDateFormatter *)dateLongNoTimeFormatter {
    
    NSDateFormatter *dateFormatter = [self dateNoTimeFormatter];
    dateFormatter.dateStyle = NSDateFormatterLongStyle;
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)dateMediumTimeMediumFormatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;

    return dateFormatter;

}

+ (NSDateFormatter *)dateMediumTimeShortFormatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)noDateShortTimeFormatter {

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    return dateFormatter;

}

+ (NSDateFormatter *)noDateMediumTimeFormatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    
    return dateFormatter;
    
}

+ (NSDateFormatter *)noDateShortTimeFormatterAllowZero:(BOOL)allowZero {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (allowZero) {
        dateFormatter.dateFormat = @"HH:mm";
    } else {
        dateFormatter.dateFormat = @"kk:mm";
    }
    return dateFormatter;
    
}

+ (void)NSLogCurrentDateWithMilliseconds {
    NSLog(@"%@", [self stringFromDate:[NSDate date]]);
}


#pragma mark - date as double

+ (NSDate *)dateFromDouble:(double)time {
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    double seconds = time * 3600;
    currentDate = [dateFormatter dateFromString:[dateFormatter stringFromDate:currentDate]];
    return [NSDate dateWithTimeInterval:seconds sinceDate:currentDate];
    
}

+ (double)currentTimeInDouble {
    
    NSDate *localDate = [NSDate date];
    
    NSDateFormatter *hourFormatter = [[NSDateFormatter alloc] init];
    hourFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    hourFormatter.dateFormat = @"HH";
    double hour = [[hourFormatter stringFromDate:localDate] doubleValue];
    
    NSDateFormatter *minuteFormatter = [[NSDateFormatter alloc] init];
    minuteFormatter.dateFormat = @"mm";
    double minute = [[minuteFormatter stringFromDate:localDate] doubleValue];

    NSDateFormatter *secondsFormatter = [[NSDateFormatter alloc] init];
    secondsFormatter.dateFormat = @"ss";
    double seconds = [[secondsFormatter stringFromDate:localDate] doubleValue];
    
    double currentTime = hour + minute/60 + seconds/3600;
    
    return currentTime;
    
}


#pragma mark - number formatters

+ (NSString *)trueMinus {
    return @"\u2212"; // U+2212 TRUE MINUS SIGN
}

+ (NSNumberFormatter *)trueMinusFormatter {

    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.minusSign = [self trueMinus];
    
    return numberFormatter;

}

+ (NSNumberFormatter *)decimalFormatter {

    NSNumberFormatter *numberFormatter = [self trueMinusFormatter];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    return numberFormatter;

}

+ (NSNumberFormatter *)decimalMaxTwoDigitFormatter {
    
    NSNumberFormatter *numberFormatter = [self decimalFormatter];
    numberFormatter.maximumFractionDigits = 2;

    return numberFormatter;
    
}

+ (NSNumberFormatter *)decimalMinTwoDigitFormatter {

    NSNumberFormatter *numberFormatter = [self decimalFormatter];
    numberFormatter.minimumFractionDigits = 2;
    
    return numberFormatter;

}

+ (NSNumberFormatter *)decimalMaxTwoMinTwoDigitFormatter {
    
    NSNumberFormatter *numberFormatter = [self decimalMaxTwoDigitFormatter];
    numberFormatter.minimumFractionDigits = 2;

    return numberFormatter;
    
}

+ (NSNumberFormatter *)currencyFormatter {
    
    NSNumberFormatter *numberFormatter = [self trueMinusFormatter];
    numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    
    return numberFormatter;
    
}

+ (NSNumberFormatter *)percentFormatter {
    
    NSNumberFormatter *numberFormatter = [self trueMinusFormatter];
    numberFormatter.numberStyle = NSNumberFormatterPercentStyle;
    numberFormatter.positivePrefix = @"+";

    return numberFormatter;
    
}


#pragma mark - days calc

+ (NSNumber *)daysFromTodayToDate:(NSDate *)date {
    
    NSDate *today = [NSDate date];
    
    NSDateFormatter *dateFormatter = [self dateShortNoTimeFormatter];
    
    today = [dateFormatter dateFromString:[dateFormatter stringFromDate:today]];
    date = [dateFormatter dateFromString:[dateFormatter stringFromDate:date]];
    
    NSTimeInterval interval = [date timeIntervalSinceDate:today];
    
    int numberOfDays = floor(interval / (60 * 60 * 24));
    
    return @(numberOfDays);
    
}

+ (NSString *)dayWithDayOfWeekFromDate:(NSDate *)date {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd MMMM yyyy, EEE";
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    NSNumber *numberOfDays = [STMFunctions daysFromTodayToDate:date];

    NSString *dayString = nil;
    
    if ([numberOfDays intValue] == 0) {
        
        dayString = NSLocalizedString(@"TODAY", nil);
        
    } else if ([numberOfDays intValue] == -1) {
        
        dayString = NSLocalizedString(@"YESTERDAY", nil);
        
    } else if ([numberOfDays intValue] == 1) {
        
        dayString = NSLocalizedString(@"TOMORROW", nil);
        
    }
    
    if (dayString) dateString = [NSString stringWithFormat:@"%@, %@", dateString, [dayString lowercaseString]];
    
    return dateString;
    
}


#pragma mark - phone number & sms-code checking

+ (BOOL)isCorrectPhoneNumber:(NSString *)phoneNumberString {
    
    if ([phoneNumberString hasPrefix:@"8"]) {
        
        if (phoneNumberString.length == 11) {
            
            NSScanner *scan = [NSScanner scannerWithString:phoneNumberString];
            int val;
            return [scan scanInt:&val] && [scan isAtEnd];
            
        }
        
    }
    
    return NO;
    
}

+ (BOOL)isCorrectSMSCode:(NSString *)SMSCode {
    
    if (SMSCode.length > 3 && SMSCode.length < 7) {

        NSScanner *scan = [NSScanner scannerWithString:SMSCode];
        int val;
        return [scan scanInt:&val] && [scan isAtEnd];

    }
    
    return NO;
    
}


#pragma mark - NSString <-> NSData manipulation

+ (NSString *)uuidString {
    return [NSUUID UUID].UUIDString.lowercaseString;
}

+ (NSData *)dataWithHexString:(NSString *)hexString {
    
// https://opensource.apple.com/source/Security/Security-55471.14.18/libsecurity_transform/NSData+HexString.m.auto.html
    
    char buf[3];
    buf[2] = '\0';
    
    NSAssert(0 == hexString.length % 2, @"Hex strings should have an even number of digits (%@)", hexString);
    
    unsigned char *bytes = malloc(hexString.length/2);
    unsigned char *bp = bytes;
    
    for (CFIndex i = 0; i < hexString.length; i += 2) {
        
        buf[0] = [hexString characterAtIndex:i];
        buf[1] = [hexString characterAtIndex:i+1];
        char *b2 = NULL;
        *bp++ = strtol(buf, &b2, 16);
        
        NSAssert(b2 == buf + 2, @"String should be all hex digits: %@ (bad digit around %@)", hexString, @(i));
        
    }
    
    return [NSData dataWithBytesNoCopy:bytes
                                length:hexString.length/2
                          freeWhenDone:YES];
    
}

+ (NSData *)dataFromString:(NSString *)string {

    return [self dataWithHexString:string];
    
/* old slow version, use apple code instead of it (dataWithHexString:) — 10 times faster
    
    NSMutableData *data = [NSMutableData data];
    int i;
    
    for (i = 0; i+2 <= string.length; i+=2) {
        
        NSRange range = NSMakeRange(i, 2);
        NSString *hexString = [string substringWithRange:range];
        NSScanner *scanner = [NSScanner scannerWithString:hexString];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
        
    }
    
    return data;
*/
    
}

+ (NSData *)xidDataFromXidString:(NSString *)xidString {
    
    NSData *xidData = (xidString) ? [self dataFromString:[xidString stringByReplacingOccurrencesOfString:@"-" withString:@""]] : nil;
    
    return xidData;
    
}

+ (NSData *)UUIDDataFromNSUUID:(NSUUID *)nsuuid {
    
    uuid_t uuid;
    [nsuuid getUUIDBytes:uuid];
    return [NSData dataWithBytes:uuid length:16];
    
}

+ (NSString *)UUIDStringFromUUIDData:(NSData *)UUIDData {
    
    CFUUIDBytes UUIDBytes;
    [UUIDData getBytes:&UUIDBytes length:UUIDData.length];
    
    CFUUIDRef CFUUID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, UUIDBytes);
    CFStringRef CFUUIDString = CFUUIDCreateString(kCFAllocatorDefault, CFUUID);
    CFRelease(CFUUID);
    
    NSString *UUIDString = [(NSString *)CFBridgingRelease(CFUUIDString) lowercaseString];
    
    return UUIDString;
    
}

+ (NSString *)hexStringFromData:(NSData *)data {
 
    if (!data) return nil;
    
    NSUInteger dataLength = [data length];
    NSMutableString *string = [NSMutableString string];
    const unsigned char *dataBytes = [data bytes];
    
    for (NSInteger i = 0; i < dataLength; ++i) {
        [string appendFormat:@"%02X", dataBytes[i]];
    }
    
    return string;
    
}

+ (NSString *)base64HexStringFromData:(NSData *)data {
    return [data base64EncodedStringWithOptions:0];
}

#pragma mark - images

+ (UIImage *)resizeImage:(nullable UIImage *)image toSize:(CGSize)size {
    return [self resizeImage:image toSize:size allowRetina:YES];
}

+ (UIImage *)resizeImage:(nullable UIImage *)image toSize:(CGSize)size allowRetina:(BOOL)retina {
    
    if (image.size.height > 0 && image.size.width > 0) {
        
        CGFloat width = size.width;
        CGFloat height = size.height;
        
        if (image.size.width >= image.size.height) {
            
            height = width * image.size.height / image.size.width;
            
        } else {
            
            width = height * image.size.width / image.size.height;
            
        }
        
        // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1.0 to force exact pixel size.
        
        CGFloat scale = (retina) ? 0.0 : 1.0;
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(width ,height), NO, scale);
        [image drawInRect:CGRectMake(0, 0, width, height)];
        UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return resultImage;
        
    } else {
        
        return [[UIImage alloc] init];
        
    }
    
}

+ (UIImage *)colorImage:(UIImage *)origImage withColor:(UIColor *)color {
    
    UIGraphicsBeginImageContextWithOptions(origImage.size, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, (CGRect){ {0,0}, origImage.size} );
    
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, origImage.size.height);
    CGContextConcatCTM(context, flipVertical);
    CGContextDrawImage(context, (CGRect){{0,0}, origImage.size }, [origImage CGImage]);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
    
}

+ (UIImage *)drawText:(NSString *)text withFont:(UIFont *)font color:(UIColor *)color inImage:(UIImage *)image atCenter:(BOOL)atCenter {
    
    if (!font) font = [UIFont systemFontOfSize:14];
    if (!color) color = [UIColor blackColor];
    
    if (!image) {
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

    }
    
    NSDictionary *attributes = @{NSFontAttributeName:font,
                                 NSForegroundColorAttributeName:color};
    
    CGSize textSize = [text sizeWithAttributes:attributes];
    CGSize imageSize = image.size;
    
    CGPoint point = CGPointMake(0, 0);
    
    if (atCenter) {
        
        CGFloat x = (imageSize.width - textSize.width) / 2;
        CGFloat y = (imageSize.height - textSize.height) / 2;
        
        point = CGPointMake(x, y);
        
    }
    
    UIGraphicsBeginImageContext(imageSize);
    
    [image drawInRect:CGRectMake(0,0,imageSize.width,imageSize.height)];
    CGRect rect = CGRectMake(point.x, point.y, imageSize.width, imageSize.height);
    [[UIColor whiteColor] set];
    [text drawInRect:CGRectIntegral(rect) withAttributes:attributes];
//    [text drawInRect:CGRectIntegral(rect) withFont:font];
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resultImage;
    
}


#pragma mark - some other usefull methods

+ (NSDictionary *)mapDictionary:(NSDictionary *)dictionary withBlock:(id (^)(id value, id key))mapperBlock{
    
    NSMutableDictionary *result = NSMutableDictionary.alloc.init;
    
    for(id key in dictionary) {
        id mapped = mapperBlock(dictionary[key], key);
        if (!mapped) continue;
        result[key] = mapped;
    }
    
    return result.copy;
}

+ (NSArray *)mapArray:(NSArray *)array withBlock:(id (^)(id value))mapperBlock {
    NSMutableArray *result = [NSMutableArray array];
    
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id mapped = mapperBlock(obj);
        if (!mapped) return;
        [result addObject:mapped];
    }];
    
    return result.copy;
}

+ (NSDictionary <NSString *, NSArray <NSDictionary <NSString *, id> *> *> *)groupArray:(NSArray <NSDictionary <NSString *, id> *> *)array byKey:(NSString *)key {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    [array enumerateObjectsUsingBlock:^(NSDictionary <NSString *, id> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *keyValue = obj[key];
        NSArray *resulted = result[keyValue];
        result[keyValue] = resulted ? [resulted arrayByAddingObject:obj] : @[obj];
    }];
    
    return result.copy;
}

+ (nullable id)popArray:(NSMutableArray *)array {
    @synchronized (array) {
        id result = array.lastObject;
        if (result) [array removeLastObject];
        return result;
    }
}

+ (void)moveObject:(id)object toTheHeadOfArray:(NSMutableArray *)array {
    
    NSUInteger indexOfObject = [array indexOfObject:object];
    
    if (indexOfObject != 0) {
        
        if (indexOfObject != NSNotFound) {
            [array removeObject:object];
        }
        
        [array insertObject:object atIndex:0];
        
    }

}

+ (void)moveObject:(id)object toTheTailOfArray:(NSMutableArray *)array {
    
    NSUInteger indexOfObject = [array indexOfObject:object];

    if (indexOfObject != array.count) {
        
        if (indexOfObject != NSNotFound) {
            [array removeObject:object];
        }

        [array insertObject:object atIndex:array.count];
        
    }

}

+ (NSString *)pluralTypeForCount:(NSUInteger)count {
    
    NSString *result;
    
    if (count == 0) {
        
        result = @"0";
        
    } else {

        int testNumber = count % 100;
        
        if (testNumber >= 11 && testNumber <= 19) {
            
            result = @"5";
            
        } else {
            
            int switchNumber = testNumber % 10;
            
            switch (switchNumber) {
                    
                case 1:
                    result = @"1";
                    break;
                    
                case 2:
                case 3:
                case 4:
                    result = @"2";
                    break;
                    
                default:
                    result = @"5";
                    break;
                    
            }
            
        }

    }
    
    return result;
    
}

+ (NSString *)MD5FromString:(nullable NSString *)string {

    if (string) {
        
        // Create pointer to the string as UTF8
        const char *ptr = [string UTF8String];
        
        // Create byte array of unsigned chars
        unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
        
        // Create 16 byte MD5 hash value, store in buffer
        // (CC_LONG) — is for removing warning
        CC_MD5(ptr, (CC_LONG)strlen(ptr), md5Buffer);
        
        // Convert MD5 value in the buffer to NSString of hex values
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
        
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [output appendFormat:@"%02x", md5Buffer[i]];
        }
        
        return output;

    } else {
        
        return @"";
        
    }
    
}

+ (NSString *)devicePlatform {
    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = @(machine);
    free(machine);
    
    return platform;
    
}

+ (NSString *)currentAppVersion {
    
    NSString *displayName = BUNDLE_DISPLAY_NAME;
    NSString *appVersionString = APP_VERSION;
    NSString *buildVersion = BUILD_VERSION;
    
    NSString *result = [NSString stringWithFormat:@"%@ %@ (%@)", displayName, appVersionString, buildVersion];
    
//    NSLog(@"infoDictionary %@", infoDictionary);
    
    return result;
    
}


#pragma mark - some methods with paths/dirs/files handling

+ (BOOL)enumerateDirAtPath:(NSString *)dirPath withBlock:(BOOL (^)(NSString *path, NSError **error))enumDirBlock {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:dirPath];
    
    BOOL result = YES;
    NSError *error = nil;
    
    for (NSString *thePath in dirEnum) {
        
        NSString *fullPath = [dirPath stringByAppendingPathComponent:thePath];
        
        result = enumDirBlock(fullPath, &error);
        
        if (!result) break;
        
    }
    
    return result;
    
}

+ (NSURL *)documentsDirectoryURL {
    return [NSURL fileURLWithPath:[self documentsDirectory]];
}

+ (NSString *)documentsDirectory {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = (paths.count > 0) ? paths[0] : @"";
    
    if (paths.count > 1 || [documentDirectory isEqualToString:@""]) {
        
        NSString *logMessage = [NSString stringWithFormat:@"documentDirectoryPaths %@", paths];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];

        NSArray <NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentDirectoryUrl = urls.lastObject;
        documentDirectory = documentDirectoryUrl.path;

    }

    return documentDirectory;
    
}

+ (NSString *)absolutePathForPath:(nullable NSString *)path {
    return [self absoluteDocumentsPathForPath:path];
}

+ (NSString *)absoluteDocumentsPathForPath:(nullable NSString *)path {
    return (path) ? [[self documentsDirectory] stringByAppendingPathComponent:(NSString *)path] : [self documentsDirectory];
}

+ (NSString *)absoluteDataCachePath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *dataCachePath = [[self documentsDirectory] stringByAppendingPathComponent:DATA_CACHE_PATH];
    
    if ([fm fileExistsAtPath:dataCachePath]) {
        
        return dataCachePath;
        
    } else {
        
        NSError *error = nil;
        BOOL result = [fm createDirectoryAtPath:dataCachePath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error];

        if (result) {
            
            return dataCachePath;
            
        } else {
            
            NSLog(@"can not create dataCachePath: %@", error.localizedDescription);
            return nil;
            
        }
        
    }
    
}

+ (NSString *)absoluteDataCachePathForPath:(nullable NSString *)path {
    return (path) ? [[self absoluteDataCachePath] stringByAppendingPathComponent:(NSString *)path] : [self absoluteDataCachePath];
}

+ (NSString *)absoluteTemporaryPathForPath:(nullable NSString *)path {
    return (path) ? [NSTemporaryDirectory() stringByAppendingPathComponent:(NSString *)path] : NSTemporaryDirectory();
}


#pragma mark -

+ (UIColor *)colorForColorString:(NSString *)colorSting {
    
    NSString *selectorString = [colorSting stringByAppendingString:@"Color"];
    
    SEL selector = NSSelectorFromString(selectorString);
    
    if ([UIColor respondsToSelector:selector]) {
        
// next 3 lines — implementation of id value = [self performSelector:selector] w/o warning
        IMP imp = [UIColor methodForSelector:selector];
        id (*func)(id, SEL) = (void *)imp;
        id value = func([UIColor class], selector);
        
        return value;
        
    } else {
        
        return [UIColor blackColor];
        
    }
    
}

+ (CGRect)frameOfHighlightedTabBarButtonForTBC:(UITabBarController *)tabBarController {
    
    CGFloat tabBarYPosition = tabBarController.tabBar.frame.origin.y;
    CGRect rect = CGRectZero;
    
    NSMutableArray *tabBarSubviews = [tabBarController.tabBar.subviews mutableCopy];
    
    for (UIView *view in tabBarSubviews) {
        
        if ([view isKindOfClass:[UIControl class]]) {
            
            UIControl *controlView = (UIControl *)view;
            if (controlView.highlighted) rect = controlView.frame;
            
        }
        
    }
    
    rect = CGRectMake(rect.origin.x, rect.origin.y + tabBarYPosition, rect.size.width, rect.size.height);

    return rect;
    
}

+ (nullable NSString *)shortCompanyName:(nullable NSString *)companyName {
    
//    NSString *searchString = @"Общество с ограниченной ответственностью";
//    
//    NSRange range = [companyName.lowercaseString rangeOfString:searchString.lowercaseString];
//
//    if (range.location != NSNotFound) {
//        
//        companyName = [companyName stringByReplacingCharactersInRange:range withString:@"ООО"];
//        
//    }
    
    return companyName;
    
}

+ (NSString *)appStateString {
    
    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    
    NSString *appStateString = nil;
    
    switch (appState) {
        case UIApplicationStateActive: {
            appStateString = @"UIApplicationStateActive";
            break;
        }
        case UIApplicationStateInactive: {
            appStateString = @"UIApplicationStateInactive";
            break;
        }
        case UIApplicationStateBackground: {
            appStateString = @"UIApplicationStateBackground";
            break;
        }
        default: {
            break;
        }

    }
    return appStateString;
    
}


#pragma mark - JSON representation

+ (id)jsonObjectFromString:(NSString *)string {
    
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                    options:NSJSONReadingMutableContainers
                                                      error:&error];
    
    if (!jsonObject) {
        NSLog(@"jsonObjectFromString error: %@", error.localizedDescription);
    }
    
    return jsonObject;

}

+ (NSString *)jsonStringFromObject:(id)object {
    
    if (![NSJSONSerialization isValidJSONObject:object]) {
        
        if ([object isKindOfClass:[NSDictionary class]]) {

            object = [self validJSONDictionaryFromDictionary:object];

        } else if ([object isKindOfClass:[NSArray class]]) {

            object = [self validJSONArrayFromArray:object];

        }

    }
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    
    return JSONString;

}

+ (NSString *)jsonStringFromArray:(NSArray *)objectArray {
    return [self jsonStringFromObject:objectArray];
}

+ (NSString *)jsonStringFromDictionary:(NSDictionary *)objectDic {
    return [self jsonStringFromObject:objectDic];
}

+ (NSDictionary *)validJSONDictionaryFromDictionary:(NSDictionary *)dictionary {
    
    NSMutableDictionary *validDictionary = [NSMutableDictionary dictionary];
    
    for (id key in dictionary.allKeys) {
        
        NSString *keyString = ([key isKindOfClass:[NSString class]]) ? key : [key description];
        
        if ([dictionary[key] isKindOfClass:[NSDictionary class]]) {
            
            validDictionary[keyString] = [self validJSONDictionaryFromDictionary:(NSDictionary *)dictionary[key]];
            
        } else if ([dictionary[key] isKindOfClass:[NSArray class]]) {
            
            validDictionary[keyString] = [self validJSONArrayFromArray:dictionary[key]];
            
        } else if (![dictionary[key] isKindOfClass:[NSString class]]) {
            
            validDictionary[keyString] = [dictionary[key] description];
            
        } else {
            
            validDictionary[keyString] = dictionary[key];
            
        }
        
    }
    
    return validDictionary.copy;
    
}

+ (NSArray *)validJSONArrayFromArray:(NSArray *)array {
    
    NSMutableArray *validArray = [NSMutableArray array];
    
    for (id arrayItem in array) {
        
        if ([arrayItem isKindOfClass:[NSDictionary class]]) {
            
            [validArray addObject:[self validJSONDictionaryFromDictionary:arrayItem]];
            
        } else if ([arrayItem isKindOfClass:[NSArray class]]) {
            
            [validArray addObject:[self validJSONArrayFromArray:arrayItem]];
            
        } else if (![arrayItem isKindOfClass:[NSString class]]) {
            
            [validArray addObject:[arrayItem description]];
            
        } else {
            
            [validArray addObject:arrayItem];
            
        }
        
    }
    
    return validArray;
    
}


+ (NSString *)volumeStringWithVolume:(NSInteger)volume andPackageRel:(NSInteger)packageRel {
    
    NSString *volumeUnitString = nil;
    NSString *infoText = nil;
    
    NSDictionary *appSettings = [[STMCoreSessionManager sharedManager].currentSession.settingsController currentSettingsForGroup:@"appSettings"];
    BOOL enableShowBottles = [appSettings[@"enableShowBottles"] boolValue];

    if (packageRel != 0 && volume >= packageRel) {
        
        NSInteger package = floor(volume / packageRel);
        
        volumeUnitString = NSLocalizedString(@"VOLUME UNIT1", nil);
        NSString *packageString = [NSString stringWithFormat:@"%ld %@", (long)package, volumeUnitString];
        
        NSInteger bottle = volume % packageRel;
        
        if (bottle > 0) {
            
            volumeUnitString = (enableShowBottles) ? NSLocalizedString(@"VOLUME UNIT2", nil) : NSLocalizedString(@"VOLUME UNIT3", nil);
            NSString *bottleString = [NSString stringWithFormat:@" %ld %@", (long)bottle, volumeUnitString];
            
            packageString = [packageString stringByAppendingString:bottleString];
            
        }
        
        infoText = packageString;
        
    } else {
        
        volumeUnitString = (enableShowBottles) ? NSLocalizedString(@"VOLUME UNIT2", nil) : NSLocalizedString(@"VOLUME UNIT3", nil);
        infoText = [NSString stringWithFormat:@"%ld %@", (long)volume, volumeUnitString];
        
    }

    return infoText;
    
}


#pragma mark - memory warning handle

+ (BOOL)shouldHandleMemoryWarningFromVC:(UIViewController *)vc {
    
    if (vc.isViewLoaded && vc.view.window == nil) {
        
        NSString *logMessage = [NSString stringWithFormat:@"%@ receive memory warning.", NSStringFromClass([vc class])];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeImportant];
        
        return YES;
        
    } else {
        
        return NO;
        
    }
    
}

+ (void)nilifyViewForVC:(UIViewController *)vc {
    
    vc.view = nil;

    NSString *logMessage = [NSString stringWithFormat:@"%@ set it's view to nil. %@", NSStringFromClass([vc class]), [self memoryStatistic]];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                             numType:STMLogMessageTypeImportant];

}

+ (void)logMemoryStat {
    [[STMLogger sharedLogger] saveLogMessageWithText:[self memoryStatistic] numType:STMLogMessageTypeImportant];
}

+ (NSString *)memoryStatistic {
    
    NSString *usedMemoryString = [NSString stringWithFormat:@"Used memory: %f Kb", usedMemory()/1024.0f];
    NSString *freeMemoryString = [NSString stringWithFormat:@"Free memory: %f Kb", freeMemory()/1024.0f];
    
    return [NSString stringWithFormat:@"%@ / %@", usedMemoryString, freeMemoryString];
    
}

vm_size_t usedMemory(void) {
    
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
    
}

vm_size_t freeMemory(void) {
    
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    
    return vm_stat.free_count * pagesize;
    
}

+ (uint64_t)freeDiskspace {
    
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    if (paths.lastObject) {
        
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:(NSString * _Nonnull)paths.lastObject error: &error];
        
        if (dictionary) {
            
            NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
            NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
            totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
            totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
            
            NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
            
        } else {
            NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
        }

    }
    
    return totalFreeSpace;
    
}

+ (NSString *)uppercaseFirst:(NSString *)inputString{
    
    NSString *firstChar = [inputString substringToIndex:1];
    
    NSString *result = [[firstChar uppercaseString] stringByAppendingString:[inputString substringFromIndex:1]];
    
    return result;
}

+ (NSString *)lowercaseFirst:(NSString *)inputString{
    
    NSString *firstChar = [inputString substringToIndex:1];
    
    NSString *result = [[firstChar lowercaseString] stringByAppendingString:[inputString substringFromIndex:1]];
    
    return result;
}

+ (BOOL)error:(NSError **)error withMessage:(NSString * _Nullable)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    NSDictionary *userInfo = (errorMessage) ? @{NSLocalizedDescriptionKey: errorMessage} : nil;
    
    if (bundleId && error) *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                        code:1
                                                    userInfo:userInfo];
    
    return (error == nil);
    
}

+ (NSError *)errorWithMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    NSDictionary *userInfo = (errorMessage) ? @{NSLocalizedDescriptionKey: errorMessage} : nil;
    
    return [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                               code:1
                           userInfo:userInfo];
    
}

+ (NSDictionary*)setValue:(id)value forKey:(id)key inDictionary:(NSDictionary*)dictionary {
    NSMutableDictionary *result = dictionary.mutableCopy;
    result[key] = value;
    return result.copy;
}

+ (nullable NSString *)currentTestTarget {
    
    NSString *pattern = @"(?<=\\/tmp\\/)[^-]*";
    NSString *path = [[[NSProcessInfo processInfo] environment] valueForKey:@"XCTestConfigurationFilePath"];
    
    if (!path) {
        return nil;
    }
    
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult *match = [re firstMatchInString:path
                                                 options:0
                                                   range:NSMakeRange(0, path.length)];
    NSString *substr = [path substringWithRange:match.range];
    return substr;
    
}

+ (BOOL)isNotNullAndTrue:(id)value {
    return ![value isEqual:[NSNull null]] && [value boolValue];
}

+ (BOOL)isNotNull:(nullable id)value {
    return value && ![value isEqual:[NSNull null]];
}

+ (BOOL)isNullBoth:(id)value1 and:(id)value2 {
    
    BOOL isNullFirst = ![self isNotNull:value1];
    BOOL isNullSecond = ![self isNotNull:value2];
    
    return isNullFirst && isNullSecond;
    
}

+ (NSString *)printableTimeInterval:(NSTimeInterval)timeInterval {
    
    if (timeInterval > 10) {
        return [NSString stringWithFormat:@"%lus", (long)@(timeInterval).integerValue];
    } else if (timeInterval > 2) {
        return [NSString stringWithFormat:@"%.01fs", timeInterval];
    } else {
        return [NSString stringWithFormat:@"%lums", (long)@(timeInterval*1000).integerValue ];
    }
    
}

+ (NSDictionary *)callerInfo {
    
#warning - have to check this method's result if app build for release

    // http://stackoverflow.com/a/9603733
    
    NSMutableDictionary *result = @{}.mutableCopy;

    NSUInteger sourceIndex = 2;
    
    NSArray *callStackSymbols = [NSThread callStackSymbols];
    
    if (callStackSymbols.count <= sourceIndex) {
        return result;
    }
    
    NSString *sourceString = callStackSymbols[sourceIndex];
    
    NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@" -[]+?.,"];
    NSMutableArray *array = [sourceString componentsSeparatedByCharactersInSet:separatorSet].mutableCopy;
    [array removeObject:@""];
    
    NSUInteger classIndex = 3;
    
    if (array.count <= classIndex) {
        return result;
    }

    result[@"class"] = array[classIndex];

    NSUInteger functionIndex = 4;

    if (array.count <= functionIndex) {
        return result;
    }

    result[@"function"] = array[functionIndex];
    
    return result;
    
}


@end
