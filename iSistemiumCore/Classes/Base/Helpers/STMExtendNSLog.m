//
//  STMExtendNSLog.m
//  iSistemium
//
//

#import "STMExtendNSLog.h"

void ExtendNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...) {
    
    // Type to hold information about variable arguments.
    va_list ap;
    
    // Initialize a variable argument list.
    va_start (ap, format);
    
    // NSLog only adds a newline to the end of the NSLog format if
    // one is not already there.
    // Here we are utilizing this feature of NSLog()
    if (![format hasSuffix: @"\n"]) {
        format = [format stringByAppendingString: @"\n"];
    }
    
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    
    // End using variable argument list.
    va_end (ap);
    
    NSString *fileName = @(file).lastPathComponent;
//    fprintf(stderr, "(%s) (%s:%d) %s",
//            functionName, [fileName UTF8String],
//            lineNumber, [body UTF8String]);
    
    NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterNoStyle
                                                    timeStyle:NSDateFormatterMediumStyle];
    
    NSString *functionString = [NSString stringWithUTF8String:functionName];
    
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@" -[]"];
    NSMutableArray *array = [functionString componentsSeparatedByCharactersInSet:charSet].mutableCopy;
    [array removeObject:@""];
    array = [array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF BEGINSWITH %@)", @"_"]].mutableCopy;

    functionString = array.lastObject;
    
//    [array removeObject:functionString];
//
//    NSString *classString = array.lastObject;
//    
//    if ([fileName hasPrefix:classString]) {
//    
//        fprintf(stderr, "%s / [%s:%d %s] - %s", date.UTF8String, fileName.UTF8String, lineNumber, functionString.UTF8String, body.UTF8String);
//
//    } else {
//
//        fprintf(stderr, "%s / [%s:%d | %s %s] - %s", date.UTF8String, fileName.UTF8String, lineNumber, classString.UTF8String, functionString.UTF8String, body.UTF8String);
//
//    }

    fprintf(stderr, "%s / [%s %s]:%d - %s", date.UTF8String, fileName.UTF8String, functionString.UTF8String, lineNumber, body.UTF8String);

}

void NSLogMessage(NSDictionary *callerInfo, NSString *format, ...) {
    
    va_list ap;
    va_start (ap, format);
    
    if (![format hasSuffix: @"\n"]) {
        format = [format stringByAppendingString: @"\n"];
    }
    
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    
    va_end (ap);
    
    NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterNoStyle
                                                    timeStyle:NSDateFormatterMediumStyle];
    
    NSString *callerClass = callerInfo[@"class"];
    NSString *callerFunction = callerInfo[@"function"];
    
    fprintf(stderr, "%s / [%s %s] - %s", date.UTF8String, callerClass.UTF8String, callerFunction.UTF8String, body.UTF8String);

}
