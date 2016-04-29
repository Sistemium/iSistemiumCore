//
//  STMSoundController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMSoundController.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "STMConstants.h"


@interface STMSoundController() <AVSpeechSynthesizerDelegate>

@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer;


@end


@implementation STMSoundController


+ (STMSoundController *)sharedController {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedController = nil;
    
    dispatch_once(&pred, ^{
        _sharedController = [[self alloc] init];
    });
    
    return _sharedController;
    
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {

    }
    return self;
    
}

- (AVSpeechSynthesizer *)speechSynthesizer {
    
    if (!_speechSynthesizer) {
        
        _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
        _speechSynthesizer.delegate = self;
        
    }
    return _speechSynthesizer;
    
}


#pragma mark - class methods

+ (void)load {
    
    @autoreleasepool {
        
        [[NSNotificationCenter defaultCenter] addObserver:(id)[self class]
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
    }
    
}

+ (void)applicationDidBecomeActive {
    
    if ([self isRinging]) [self stopRinging];
    
}


#pragma mark - playing sounds

+ (void)playAlert {
    
//     List of Predefined sounds and it's IDs
//     http://iphonedevwiki.net/index.php/AudioServices
    
//    AudioServicesPlayAlertSound(1033);
//    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);

    NSString *path  = [[NSBundle mainBundle] pathForResource:@"error" ofType:@"mp3"];
    NSURL *pathURL = [NSURL fileURLWithPath:path];
    [self playSoundAtURL:pathURL];
    
}

+ (void)playOk {
    
//    AudioServicesPlaySystemSound(1003);
    
    NSString *path  = [[NSBundle mainBundle] pathForResource:@"ok" ofType:@"mp3"];
    NSURL *pathURL = [NSURL fileURLWithPath:path];
    [self playSoundAtURL:pathURL];
    
}

+ (void)playSoundAtURL:(NSURL *)pathURL {
    
    SystemSoundID sysSound;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef) pathURL, &sysSound);
    AudioServicesAddSystemSoundCompletion(sysSound, NULL, NULL, completionCallback, NULL);
    AudioServicesPlaySystemSound(sysSound);

}

static void completionCallback (SystemSoundID sysSound, void *data) {
    
    AudioServicesRemoveSystemSoundCompletion(sysSound);
    AudioServicesDisposeSystemSoundID(sysSound);

}


#pragma mark - saying

+ (void)say:(NSString *)string {
    
    [self sayText:string
         withRate:AVSpeechUtteranceDefaultSpeechRate
            pitch:1];
    
}

+ (void)sayText:(NSString *)string withRate:(float)rate pitch:(float)pitch {

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:string];
    utterance.rate = rate;
    utterance.pitchMultiplier = pitch;
    
    [[self sharedController].speechSynthesizer speakUtterance:utterance];
    
    NSLog(@"Say: %@", string);

}

+ (void)alertSay:(NSString *)string {
    
    [self alertSay:string
          withRate:AVSpeechUtteranceDefaultSpeechRate
             pitch:1];
    
}

+ (void)alertSay:(NSString *)string withRate:(float)rate pitch:(float)pitch {
    
    [self playAlert];
    [self sayText:string
         withRate:rate
            pitch:pitch];

}

+ (void)okSay:(NSString *)string {
    
    [self okSay:string
       withRate:AVSpeechUtteranceDefaultSpeechRate
          pitch:1];
    
}

+ (void)okSay:(NSString *)string withRate:(float)rate pitch:(float)pitch {

    [self playOk];
    [self sayText:string
         withRate:rate
            pitch:pitch];

}


#pragma mark - AVSpeechSynthesizerDelegate

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    [self.sender didFinishSpeaking];
}


#pragma mark - ringing

+ (BOOL)isRinging {

    NSArray *notifications = [UIApplication sharedApplication].scheduledLocalNotifications.copy;
    
    for (UILocalNotification *ln in notifications) {
        if ([ln.userInfo.allKeys containsObject:RINGING_LOCAL_NOTIFICATION]) return YES;
    }
    
    return NO;

}

+ (void)ringWithProperties:(NSDictionary *)ringProperties {
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        
        NSLog(@"ringing canceled: application is not in background");
        return;
        
    }
    if ([self isRinging]) {
        
        NSLog(@"ringing canceled: application is already ringing");
        return;
        
    }
    
    if ([ringProperties isKindOfClass:[NSDictionary class]]) {
        
        NSInteger numberOfRepeats = [ringProperties[@"numberOfRepeats"] integerValue];
        NSTimeInterval delay = [ringProperties[@"delay"] doubleValue];
        
        if (delay < 1) delay = 1;
        
        NSString *soundName = ringProperties[@"soundName"];
        NSString *ringMessage = ringProperties[@"ringMessage"];

        if (!soundName) soundName = UILocalNotificationDefaultSoundName;
        if (!ringMessage) ringMessage = @"iSistemuim";
        
        [self ringingLocalNotificationWithMessage:ringMessage
                                        soundName:soundName
                                  numberOfRepeats:numberOfRepeats
                                         andDelay:delay];
        
    }
    
}

+ (void)ringingLocalNotificationWithMessage:(NSString *)message soundName:(NSString *)soundName numberOfRepeats:(NSInteger)numberOfRepeats andDelay:(NSTimeInterval)delay {
    
    for (NSInteger i = 0; i < numberOfRepeats; ++i) {
        
        NSLog(@"i %d", i);
        
        UILocalNotification *ln = [[UILocalNotification alloc] init];
        ln.soundName = soundName;
        ln.alertBody = (i == 0) ? message : nil;
        ln.userInfo = @{RINGING_LOCAL_NOTIFICATION:soundName};
        
        NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:(delay * i)];
        ln.fireDate = fireDate;
        
        NSLog(@"fireDate %@", fireDate);
        
        [[UIApplication sharedApplication] scheduleLocalNotification:ln];

    }
    
}

+ (void)stopRinging {
    
    NSArray *notifications = [UIApplication sharedApplication].scheduledLocalNotifications.copy;
    
    for (UILocalNotification *ln in notifications) {
        
        if ([ln.userInfo.allKeys containsObject:RINGING_LOCAL_NOTIFICATION]) {
            
            [[UIApplication sharedApplication] cancelLocalNotification:ln];
            
        };
        
    }
    
}


@end
