@import UIKit;

@protocol ProximityDetectorDelegate
- (void)proximityDetectorIdealConditionsMetForOneSecond:(id)proximityDetector;
@end

@interface ProximityDetector: NSObject
- (instancetype)initWithIdealProportion:(CGFloat)proportionalFraction;
- (void)pipeFaceFrame:(CGRect)faceFrame pictureFrame:(CGRect)pictureFrame;
@property (nonatomic) BOOL enabled;
@end
