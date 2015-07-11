@import AVFoundation;
@import CoreImage;
#import "ProximityDetector.h"
#import "ViewController.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@end


@implementation ViewController {
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureSession *session;
    ProximityDetector *proximityDetector;
    CIDetector *faceDetector;
    NSDictionary *imageOptions;

    UIView *surround;

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

    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                      context:[CIContext contextWithOptions:nil]
                                      options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorTracking: @NO}];

    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:6] forKey:CIDetectorImageOrientation];
    // ^-- increases camera accuracy for faster detection

    [session startRunning];

    proximityDetector = [[ProximityDetector alloc] initWithIdealProportion:0.6];

    [self captureVideo];

    surround = [UIView new];
    surround.layer.borderColor = [UIColor redColor].CGColor;
    surround.layer.borderWidth = 1;
    surround.backgroundColor = [UIColor colorWithHue:0 saturation:1 brightness:1 alpha:0.1];
    [self.view addSubview:surround];
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
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);

    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];

    [self detectFaces:[ciImage copy]];

    if (attachments) {
        CFRelease(attachments);
    }
}

- (void)detectFaces:(CIImage *)image {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{

        NSArray *faces = [faceDetector featuresInImage:image options:imageOptions];

        if ([faces count])
        {
            NSLog(@"Face rect: %@", NSStringFromCGRect([faces[0] bounds]));

            CIFaceFeature *face = faces[0];
            [proximityDetector pipeFaceFrame:face.bounds pictureFrame:image.extent];

            dispatch_async(dispatch_get_main_queue(), ^{
                CGFloat factor = MIN(self.view.bounds.size.width / image.extent.size.width, self.view.bounds.size.height/ image.extent.size.height);

                CGRect f = face.bounds;
                f.origin.x *= factor;
                f.origin.y *= factor;
                f.size.width *= factor;
                f.size.height *= factor;

                f.origin.y += (self.view.bounds.size.height - self.view.bounds.size.width) / 2;

                surround.frame = f;
            });
        }
    });

}

@end
