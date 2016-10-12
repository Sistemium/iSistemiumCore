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
#import "STMLogger.h"


@interface STMSoundController() <AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate>

@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, strong) AVAudioPlayer *player;


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
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        id observer = (id)[self class];
        
        [nc addObserver:observer
               selector:@selector(applicationDidBecomeActive)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];

        [nc addObserver:observer
               selector:@selector(mediaServicesWereReset)
                   name:AVAudioSessionMediaServicesWereResetNotification
                 object:[AVAudioSession sharedInstance]];

    }
    
}

+ (void)applicationDidBecomeActive {
    if ([self isRinging]) [self stopRinging];
}

+ (void)mediaServicesWereReset {
    
    [self initAudioSession];
    [self sharedController].speechSynthesizer = nil;
    
}

+ (void)initAudioSession {
    
    [self sharedController];
    
    STMLogger *logger = [STMLogger sharedLogger];
    [logger saveLogMessageWithText:@"initAudioSession"];
    
    if ([self initAudioSessionSharedInstance]) {
    
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            [self startBackgroundPlay];
        }

    }
    
}

+ (BOOL)initAudioSessionSharedInstance {
    
    STMLogger *logger = [STMLogger sharedLogger];

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *error = nil;
    
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&error];
    
    if (error) {
        
        [logger saveLogMessageWithText:error.localizedDescription];
        return NO;
        
    }
    
    [audioSession setActive:YES
                      error:&error];
    
    if (error) {
        
        [logger saveLogMessageWithText:error.localizedDescription];
        return NO;
        
    }

    return YES;
    
}


#pragma mark - playing sounds

+ (void)playAlert {
    
//     List of Predefined sounds and it's IDs
//     http://iphonedevwiki.net/index.php/AudioServices
    
//    AudioServicesPlayAlertSound(1033);
//    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);

    NSString *path = [[NSBundle mainBundle] pathForResource:@"error" ofType:@"mp3"];
    
    if (path) {
        
        NSURL *pathURL = [NSURL fileURLWithPath:path];
        [self playSoundAtURL:pathURL];

    } else {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:@"have no path for file error.mp3"
                                                 numType:STMLogMessageTypeError];
        
    }
    
}

+ (void)playOk {
    
//    AudioServicesPlaySystemSound(1003);
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ok" ofType:@"mp3"];
    
    if (path) {

        NSURL *pathURL = [NSURL fileURLWithPath:path];
        [self playSoundAtURL:pathURL];

    } else {

        [[STMLogger sharedLogger] saveLogMessageWithText:@"have no path for file ok.mp3"
                                                 numType:STMLogMessageTypeError];

    }
    
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


#pragma mark - playing silent sound

+ (void)startBackgroundPlay {
    [[self sharedController] startBackgroundPlay];
}

+ (void)stopBackgroundPlay {
    [[self sharedController] stopBackgroundPlay];
}

- (void)startBackgroundPlay {
    
    [[STMLogger sharedLogger] saveLogMessageWithText:@"startBackgroundPlay"];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc removeObserver:self];
    
    [nc addObserver:self
           selector:@selector(interruptedAudio:)
               name:AVAudioSessionInterruptionNotification
             object:[AVAudioSession sharedInstance]];

    [self playSilentAudio];
    
}

- (void)stopBackgroundPlay {
    
    if (self.player.playing) {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:@"stopBackgroundPlay"];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        [self.player stop];

    } else {

        [[STMLogger sharedLogger] saveLogMessageWithText:@"player is not playing"];

    }
    
}

- (void)interruptedAudio:(NSNotification *)notification {
    
    STMLogger *logger = [STMLogger sharedLogger];

    [logger saveLogMessageWithText:@"interuptedAudio notification"];
    
    if (![notification.name isEqualToString:AVAudioSessionInterruptionNotification]) return;
    if (!notification.userInfo) return;
    
    [logger saveLogMessageWithText:@"AVAudioSessionInterruptionNotification"];
    
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *interruptionType = userInfo[AVAudioSessionInterruptionTypeKey];
    
    switch (interruptionType.unsignedIntegerValue) {
            
        case AVAudioSessionInterruptionTypeEnded: {
            
            [logger saveLogMessageWithText:@"interruption ended"];
            
            NSNumber *interruptionOption = userInfo[AVAudioSessionInterruptionOptionKey];
            
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                
                [logger saveLogMessageWithText:@"audio session should resume"];
                
                [self playSilentAudio];
                
            } else {
                
                [logger saveLogMessageWithText:@"something else"];
                
            }
            
        }
            break;
            
        case AVAudioSessionInterruptionTypeBegan: {
            
            [logger saveLogMessageWithText:@"interruption began"];
            
        }
            break;
            
        default:
            break;
            
    }
    
}

- (void)playSilentAudio {
    
    if (self.player.playing) [self.player stop];

    STMLogger *logger = [STMLogger sharedLogger];

    if (![STMSoundController initAudioSessionSharedInstance]) {
        
        [logger saveLogMessageWithText:@"initAudioSessionSharedInstance failed"];
        return;
        
    }
    
    [logger saveLogMessageWithText:@"playSilentAudio"];
    
    NSString *silentWavPath = [[NSBundle mainBundle] pathForResource:@"silent" ofType:@"wav"];
    
    if (silentWavPath) {
        
        NSURL *silentWavURL = [NSURL fileURLWithPath:silentWavPath];
        
        NSError *error = nil;
        
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:silentWavURL
                                                             error:&error];
        self.player.delegate = self;
        
        if (error) {
            
            [logger saveLogMessageWithText:error.localizedDescription];
            
            return;
            
        }
        
        self.player.numberOfLoops = -1;
        self.player.volume = 0;
        
        [self.player play];

    } else {
        [logger saveLogMessageWithText:@"have no path for file silent.wav"
                               numType:STMLogMessageTypeError];
    }
    
}


#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    [[STMLogger sharedLogger] saveLogMessageWithText:error.localizedDescription];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    NSString *logMessage = [NSString stringWithFormat:@"audioPlayerDidFinishPlaying successfully:%@", @(flag)];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage];
    
}


@end
