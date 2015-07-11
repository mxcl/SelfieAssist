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

    return self;
}

- (void)dealloc {
    [timer invalidate];
}

- (void)setDelta:(CGFloat)delta {
    _delta = delta;
    if (!timer) {
        timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(ontimeout) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)pp successfully:(BOOL)flag {
    [player prepareToPlay];
}

- (void)ontimeout {
    CGFloat delta = fabs(_delta);
    CGFloat duration = 0.1 + delta;

//    NSLog(@"%f %f", delta, duration);

    NSTimeInterval now = [NSDate new].timeIntervalSince1970;

    if (lastBeepTimestamp + duration <= now) {
        [player play];
        lastBeepTimestamp = now;
    }
}

@end
