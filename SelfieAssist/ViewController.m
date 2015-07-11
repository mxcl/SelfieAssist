@import AVFoundation;
#import "ViewController.h"

@interface ViewController ()
@end


@implementation ViewController {
    AVCaptureVideoPreviewLayer *previewLayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    AVCaptureDevice *device = ^id{
        for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if ([d position] == AVCaptureDevicePositionFront) {
                return d;
            }
        }
        return nil;
    }();

    AVCaptureSession *session = [AVCaptureSession new];
    id preset = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone
        ? AVCaptureSessionPreset640x480
        : AVCaptureSessionPresetPhoto;
    session.sessionPreset = preset;

    id error;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

    if (error)
        @throw @"DAYYYMN SON";

    // add the input to the session
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    } else
        @throw @"DAYYYMN SON";

    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.backgroundColor = [UIColor blackColor].CGColor;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:previewLayer];

    [session startRunning];
}

- (void)viewDidLayoutSubviews {
    previewLayer.frame = self.view.bounds;
}

@end
