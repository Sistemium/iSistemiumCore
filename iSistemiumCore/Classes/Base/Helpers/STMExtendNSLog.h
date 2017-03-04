//
//  STMExtendNSLog.h
//  iSistemium
//
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define NSLog(args...) ExtendNSLog(__FILE__,__LINE__,__PRETTY_FUNCTION__,args);
#define NSLogM(callerInfo, args...) NSLogMessage(callerInfo, args);
#else
#define NSLog(x...)
#endif

void ExtendNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...);
void NSLogMessage(NSDictionary *callerInfo, NSString *format, ...);
