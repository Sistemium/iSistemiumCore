//
//  STMSoundController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 23/11/15.
//  Copyright © 2015 Sistemium UAB. All rights reserved.
//

#import "STMSoundController.h"

#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>

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
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"AudioSessionMediaServicesWereReset notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"AudioSessionMediaServicesWereReset notification");
    
    [self initAudioSession];
    [self sharedController].speechSynthesizer = nil;
    
}

+ (void)initAudioSession {
    
    [self sharedController];
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"initAudioSession";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
    if ([self initAudioSessionSharedInstance]) {
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            [self startBackgroundPlay];
        }
        
    }
    
}

+ (BOOL)initAudioSessionSharedInstance {
    
    STMLogger *logger = [STMLogger sharedLogger];
//    CLS_LOG(@"initAudioSessionSharedInstance");
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    BOOL result = YES;
    NSError *error = nil;
    
    result = [audioSession setCategory:AVAudioSessionCategoryPlayback
                           withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                 error:&error];
    
    if (result) {
        
        result = [audioSession setActive:YES
                                   error:&error];
        
    }
    
    if (!result) {
        
        [logger saveLogMessageWithText:error.localizedDescription];
        //        CLS_LOG(@"%@", error.localizedDescription);
        
    }
    
    return result;
    
}


#pragma mark - playing sounds

+ (void)playAlert {
    
    //     List of Predefined sounds and it's IDs
    //     http://iphonedevwiki.net/index.php/AudioServices
    
    //    AudioServicesPlayAlertSound(1033);
    //    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    
    NSString *path  = [[NSBundle mainBundle] pathForResource:@"error" ofType:@"mp3"];
    
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
    
    NSString *path  = [[NSBundle mainBundle] pathForResource:@"ok" ofType:@"mp3"];
    
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
        
        NSLog(@"i %ld", (long)i);
        
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
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"startBackgroundPlay";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"startBackgroundPlay");
    
    [self addAudioSessionObservers];
    
    [self playSilentAudio];
    
}

- (void)stopBackgroundPlay {
    
    STMLogger *logger = [STMLogger sharedLogger];

    if (self.player.playing) {
        
        NSString *logMessage = @"stopBackgroundPlay";
        [logger saveLogMessageWithText:logMessage];
//        CLS_LOG(@"stopBackgroundPlay");
        
        [self removeAudioSessionObservers];
        [self.player stop];
        
    } else {
        
        NSString *logMessage = @"player is not playing";
        [logger saveLogMessageWithText:logMessage];
        
    }
    
}

- (void)playSilentAudio {
    
    if (self.player.playing) [self.player stop];
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    if (![STMSoundController initAudioSessionSharedInstance]) {
        
        [logger saveLogMessageWithText:@"initAudioSessionSharedInstance failed"];
        return;
        
    }
    
    NSString *logMessage = @"playSilentAudio";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
    NSString *silentWavPath = [[NSBundle mainBundle] pathForResource:@"silent" ofType:@"wav"];
    
    if (silentWavPath) {
        
        NSURL *silentWavURL = [NSURL fileURLWithPath:silentWavPath];
        
        NSError *error = nil;
        
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:silentWavURL
                                                             error:&error];
        
        if (self.player) {
            
            self.player.delegate = self;
            
            self.player.numberOfLoops = -1;
            self.player.volume = 0;
            
            //        CLS_LOG(@"self.player %@", self.player);
            //        CLS_LOG(@"self.player.delegate %@", self.player.delegate);
            //        CLS_LOG(@"[AVAudioSession sharedInstance] %@", [AVAudioSession sharedInstance]);
            //        CLS_LOG(@"[AVAudioSession sharedInstance].delegate %@", [AVAudioSession sharedInstance].delegate);
            
            [self.player play];
            
        } else {
            [logger saveLogMessageWithText:error.localizedDescription];
        }
        
    } else {
        [logger saveLogMessageWithText:@"have no path for file silent.wav"
                               numType:STMLogMessageTypeError];
    }
    
}


#pragma mark - AVAudoiSession notifications

- (void)addAudioSessionObservers {
    
    [self removeAudioSessionObservers];
    
//    CLS_LOG(@"addAudioSessionObservers");
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(audioSessionInterruption:)
               name:AVAudioSessionInterruptionNotification
             object:audioSession];
    
    [nc addObserver:self
           selector:@selector(audioSessionRouteChange:)
               name:AVAudioSessionRouteChangeNotification
             object:audioSession];
    
    [nc addObserver:self
           selector:@selector(audioSessionMediaServicesWereLost:)
               name:AVAudioSessionMediaServicesWereLostNotification
             object:audioSession];
    
    //    [nc addObserver:self
    //           selector:@selector(audioSessionMediaServicesWereReset:)
    //               name:AVAudioSessionMediaServicesWereResetNotification
    //             object:audioSession];
    
    [nc addObserver:self
           selector:@selector(audioSessionSilenceSecondaryAudioHint:)
               name:AVAudioSessionSilenceSecondaryAudioHintNotification
             object:audioSession];
    
}

- (void)removeAudioSessionObservers {
    
//    CLS_LOG(@"removeAudioSessionObservers");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)audioSessionInterruption:(NSNotification *)notification {
    
    if (![notification.name isEqualToString:AVAudioSessionInterruptionNotification]) return;
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"audioSessionInterruption notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
    if (!notification.userInfo) return;
    
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *interruptionType = userInfo[AVAudioSessionInterruptionTypeKey];
    
    switch (interruptionType.unsignedIntegerValue) {
            
        case AVAudioSessionInterruptionTypeEnded: {
            
            logMessage = @"audioSessionInterruption ended";
            [logger saveLogMessageWithText:logMessage];
//            CLS_LOG(@"%@", logMessage);
            
            NSNumber *interruptionOption = userInfo[AVAudioSessionInterruptionOptionKey];
            
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                
                logMessage = @"audioSessionInterruption should resume";
                [logger saveLogMessageWithText:logMessage];
//                CLS_LOG(@"%@", logMessage);
                
                [self playSilentAudio];
                
            } else {
                
                logMessage = @"audioSessionInterruption something else";
                [logger saveLogMessageWithText:logMessage];
//                CLS_LOG(@"%@", logMessage);
                
            }
            
        }
            break;
            
        case AVAudioSessionInterruptionTypeBegan: {
            
            logMessage = @"audioSessionInterruption began";
            [logger saveLogMessageWithText:logMessage];
//            CLS_LOG(@"%@", logMessage);
            
            self.player.delegate = nil;
            self.player = nil;
            
        }
            break;
            
        default:
            break;
            
    }
    
}

- (void)audioSessionRouteChange:(NSNotification *)notification {
    
    if (![notification.name isEqualToString:AVAudioSessionRouteChangeNotification]) return;
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"audioSessionRouteChange notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
    if (!notification.userInfo) return;
    
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *changeReason = userInfo[AVAudioSessionRouteChangeReasonKey];
    
    if (changeReason) {
        
        logMessage = @"RouteChangeReason undefined";
        
        switch (changeReason.unsignedIntegerValue) {
            case AVAudioSessionRouteChangeReasonUnknown:
                logMessage = @"AVAudioSessionRouteChangeReasonUnknown";
                break;
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
                logMessage = @"AVAudioSessionRouteChangeReasonNewDeviceAvailable";
                break;
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
                logMessage = @"AVAudioSessionRouteChangeReasonOldDeviceUnavailable";
                break;
            case AVAudioSessionRouteChangeReasonCategoryChange:
                logMessage = @"AVAudioSessionRouteChangeReasonCategoryChange";
                break;
            case AVAudioSessionRouteChangeReasonOverride:
                logMessage = @"AVAudioSessionRouteChangeReasonOverride";
                break;
            case AVAudioSessionRouteChangeReasonWakeFromSleep:
                logMessage = @"AVAudioSessionRouteChangeReasonWakeFromSleep";
                break;
            case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
                logMessage = @"AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory";
                break;
            case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
                logMessage = @"AVAudioSessionRouteChangeReasonRouteConfigurationChange";
                break;
                
            default:
                break;
        }
        
        [logger saveLogMessageWithText:logMessage];
//        CLS_LOG(@"%@", logMessage);
        
    }
    
    NSNumber *hintType = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey];
    
    if (hintType) {
        
        logMessage = @"AudioHintType undefined";
        
        switch (hintType.unsignedIntegerValue) {
            case AVAudioSessionSilenceSecondaryAudioHintTypeEnd:
                logMessage = @"AVAudioSessionSilenceSecondaryAudioHintTypeEnd";
                break;
            case AVAudioSessionSilenceSecondaryAudioHintTypeBegin:
                logMessage = @"AVAudioSessionSilenceSecondaryAudioHintTypeBegin";
                break;
                
            default:
                break;
        }
        
        [logger saveLogMessageWithText:logMessage];
//        CLS_LOG(@"%@", logMessage);
        
    }
    
}

- (void)audioSessionMediaServicesWereLost:(NSNotification *)notification {
    
    if (![notification.name isEqualToString:AVAudioSessionMediaServicesWereLostNotification]) return;
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"audioSessionMediaServicesWereLost notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
}

- (void)audioSessionMediaServicesWereReset:(NSNotification *)notification {
    
    if (![notification.name isEqualToString:AVAudioSessionMediaServicesWereResetNotification]) return;
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"audioSessionMediaServicesWereReset notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
}

- (void)audioSessionSilenceSecondaryAudioHint:(NSNotification *)notification {
    
    if (![notification.name isEqualToString:AVAudioSessionSilenceSecondaryAudioHintNotification]) return;
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = @"audioSessionSilenceSecondaryAudioHint notification";
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *hintType = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey];
    
    if (hintType) {
        
        logMessage = @"AudioHintType undefined";
        
        switch (hintType.unsignedIntegerValue) {
            case AVAudioSessionSilenceSecondaryAudioHintTypeEnd:
                logMessage = @"AVAudioSessionSilenceSecondaryAudioHintTypeEnd";
                break;
            case AVAudioSessionSilenceSecondaryAudioHintTypeBegin:
                logMessage = @"AVAudioSessionSilenceSecondaryAudioHintTypeBegin";
                break;
                
            default:
                break;
        }
        
        [logger saveLogMessageWithText:logMessage];
//        CLS_LOG(@"%@", logMessage);
        
    }
    
}


#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    
    STMLogger *logger = [STMLogger sharedLogger];
    [logger saveLogMessageWithText:error.localizedDescription];
//    CLS_LOG(@"%@", error.localizedDescription);
    
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    STMLogger *logger = [STMLogger sharedLogger];
    NSString *logMessage = [NSString stringWithFormat:@"audioPlayerDidFinishPlaying successfully:%@", @(flag)];
    [logger saveLogMessageWithText:logMessage];
//    CLS_LOG(@"%@", logMessage);
    
}


@end
