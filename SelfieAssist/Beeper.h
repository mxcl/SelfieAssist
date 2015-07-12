@import Foundation.NSObject;
@import CoreGraphics.CGBase;

@interface Beeper: NSObject
@property (nonatomic) CGFloat delta;
@property (nonatomic) BOOL enabled;
@property (nonatomic, strong) void (^yoDudeItHasBeenASecond)();
@end
