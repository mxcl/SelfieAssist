@import UIKit;

@protocol ProximityDetectorDelegate
- (void)proximityDetectorInSweetSpot:(BOOL)inSweetSpot;
- (void)proximityDetectorIdealConditionsMetForOneSecond:(id)proximityDetector;
@end

@interface ProximityDetector: NSObject
- (instancetype)initWithIdealProportion:(CGFloat)proportionalFraction;
- (void)pipeFaceFrame:(CGRect)faceFrame pictureFrame:(CGRect)pictureFrame;
@property (nonatomic) BOOL enabled;
@property (nonatomic) id<ProximityDetectorDelegate> delegate;
@end
