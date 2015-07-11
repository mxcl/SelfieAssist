@import AVFoundation;
@import AudioToolbox;
#import "Beeper.h"


@implementation Beeper {
    NSTimeInterval lastBeepTimestamp;
    SystemSoundID soundID;
    BOOL started;
}

- (instancetype)init {
    id url = [[NSBundle mainBundle] URLForResource:@"beep" withExtension:@"caf"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef) url, &soundID);

    return self;
}

- (void)setDelta:(CGFloat)delta {
    _delta = delta;
    if (!started) {
        [self loop];
    }
}

- (void)loop {
    id q = dispatch_get_main_queue();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), q, ^{
        CGFloat delta = fabs(_delta);
        CGFloat duration = delta < 0.08
        ? 0.2
        : 0.2 + log(1 + MIN(delta * 1.0/0.25, 1));

        NSLog(@"%f %f", _delta, duration);

        NSTimeInterval now = [NSDate new].timeIntervalSince1970;

        if (lastBeepTimestamp + duration <= now) {
            AudioServicesPlaySystemSound(soundID);
            lastBeepTimestamp = now;
        }
        [self loop];
    });
}

@end
