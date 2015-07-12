@import AVFoundation;
@import AudioToolbox;
#import "Beeper.h"


@implementation Beeper {
    NSTimeInterval lastBeepTimestamp;
    NSTimeInterval idealStartedTimestamp;
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
        if (_enabled) {
            CGFloat delta = fabs(_delta);
            BOOL const ideal = delta < 0.08;
            CGFloat duration = ideal
                ? 0.2
                : 0.2 + log(1 + MIN(delta * 1.0/0.25, 1));

            NSTimeInterval now = [NSDate new].timeIntervalSince1970;

            if (ideal) {
                if (idealStartedTimestamp == 0) {
                    idealStartedTimestamp = now;
                } else if (now > idealStartedTimestamp + 1) {
                    _yoDudeItHasBeenASecond();

                    // let’s be defensive and cancel ourselves
                    _enabled = NO;
                    idealStartedTimestamp = 0;
                }
            } else {
                idealStartedTimestamp = 0;
            }

            if (lastBeepTimestamp + duration <= now) {
                AudioServicesPlaySystemSound(soundID);
                lastBeepTimestamp = now;
            }
        }
        [self loop];
    });
}

@end
