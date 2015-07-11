#import "Beeper.h"
#import "ProximityDetector.h"
@import UIKit;


@implementation ProximityDetector {
    CGFloat idealProportion;
    time_t conditionsMetTimestamp;
    Beeper *beeper;
}

- (instancetype)initWithIdealProportion:(CGFloat)proportionalFraction {
    idealProportion = proportionalFraction;
    return self;
}

- (void)pipeFaceFrame:(CGRect)faceFrame pictureFrame:(CGRect)pictureFrame {
    CGFloat faceWidth = CGRectGetWidth(faceFrame);
    CGFloat pictureWidth = CGRectGetWidth(pictureFrame);
    CGFloat proportion = faceWidth / pictureWidth;

    beeper.delta = proportion - idealProportion;
}

@end
