@import AVFoundation;
#import "ViewController.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@end


@implementation ViewController {
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureSession *session;
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

    session = [AVCaptureSession new];
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
    [self captureVideo];
}

- (void)viewDidLayoutSubviews {
    previewLayer.frame = self.view.bounds;
}

-(void)captureVideo
{
    // Make a video data output
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                       [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
    // create a serial dispatch queue used for the sample buffer delegate
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information

   dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    if ( [session canAddOutput:videoDataOutput] ){

        [session addOutput:videoDataOutput];
    }
    // get the output for doing face detection.
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];

    NSLog(@" this works = %@",videoDataOutput);
}

@end
