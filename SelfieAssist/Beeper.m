@import AVFoundation;
@import AudioToolbox;
#import "Beeper.h"


@interface MovingAverage: NSObject
@end
@implementation MovingAverage {
    NSMutableArray *values;
}

- (instancetype)init {
    values = [NSMutableArray new];
    return self;
}

- (double)add:(double)value {
    [values addObject:@(value)];
    if (values.count > 50)
        [values removeObjectAtIndex:0];

    double average = 0;
    for (id value in values)
        average += [value doubleValue];

    return average / values.count;
}

- (void)clear {
    [values removeAllObjects];
}

- (double)last:(int)n {
    n = MIN(n, (int)values.count);

    double average = 0;
    for (id value in [values subarrayWithRange:NSMakeRange(values.count - n, n)])
        average += [value doubleValue];
    return average / n;
}

@end



@implementation Beeper {
    NSTimeInterval lastBeepTimestamp;
    NSTimeInterval idealStartedTimestamp;
    MovingAverage *movingAverage;
    SystemSoundID soundID;
    BOOL started;
}

- (instancetype)init {
    movingAverage = [MovingAverage new];
    id url = [[NSBundle mainBundle] URLForResource:@"beep" withExtension:@"caf"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef) url, &soundID);
    return self;
}

- (void)setDelta:(CGFloat)delta {
    _delta = delta;
    if (!started) {
        started = true;
        [self loop];
    }
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    if (!enabled) {
        idealStartedTimestamp = 0;
        lastBeepTimestamp = 0;
        [movingAverage clear];
    }
}

- (void)loop {
    id q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), q, ^{
        if (_enabled) {
            CGFloat movingAverageDelta = fabs([movingAverage add:_delta]);

            BOOL const ideal = movingAverageDelta < 0.06;
            CGFloat duration = ideal
                ? 0.10
                : 0.26 + log(1 + MIN((fabs([movingAverage last:15]) - 0.06) * 1.0/0.2, 1));

            NSTimeInterval now = [NSDate new].timeIntervalSince1970;

            if (ideal) {
                if (idealStartedTimestamp == 0) {
                    idealStartedTimestamp = now;
                } else if (now > idealStartedTimestamp + 1 && /* make sure current frame is ideal still */ _delta < 0.06) {
                    dispatch_async(dispatch_get_main_queue(), _yoDudeItHasBeenASecond);

                    // let’s be defensive and cancel ourselves
                    self.enabled = NO;
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
