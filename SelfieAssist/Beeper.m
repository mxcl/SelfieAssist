@import AVFoundation;
#import "Beeper.h"

@interface Beeper () <AVAudioPlayerDelegate>
@end

@implementation Beeper {
    AVAudioPlayer *player;
    NSTimeInterval lastBeepTimestamp;
    NSTimer *timer;
}

- (instancetype)init {
    id url = [[NSBundle mainBundle] URLForResource:@"beep" withExtension:@"caf"];
    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    player.delegate = self;
    [player prepareToPlay];

    timer = [NSTimer timerWithTimeInterval:2 target:self selector:@selector(ontimeout) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

    return self;
}

- (void)dealloc {
    [timer invalidate];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)pp successfully:(BOOL)flag {
    [player prepareToPlay];
}

- (void)ontimeout {
    CGFloat delta = fabs(_delta);
    CGFloat amplitude = 0.1 * MAX(0.6, delta / 0.6);
    NSTimeInterval now = [NSDate new].timeIntervalSince1970;

    if (lastBeepTimestamp + amplitude >= now) {
        [player play];
        lastBeepTimestamp = now;
    }
}

@end
