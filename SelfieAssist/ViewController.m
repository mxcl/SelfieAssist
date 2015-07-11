#import <AssertMacros.h>
@import AssetsLibrary;
@import AVFoundation;
@import CoreImage;
@import ImageIO;
#import "ViewController.h"

// used for KVO observation of the @"capturingStillImage" property to perform flash bulb animation
static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

// utility used by newSquareOverlayedImageForFeatures for
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;

    bitmapBytesPerRow = (size.width * 4);

    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}

#pragma mark-

@interface UIImage (RotationMethods)
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;
@end

@implementation UIImage (RotationMethods)

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;

    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();

    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);

    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));

    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;

}

@end

#pragma mark-

@interface ViewController () <UIGestureRecognizerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureVideoDataOutput *videoDataOutput;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureStillImageOutput *stillImageOutput;
    UIView *flashView;
    UIImage *square;
    CIDetector *faceDetector;
    CGFloat beginGestureScale;
    CGFloat effectiveScale;
}
- (void)setupAVCapture;
- (void)teardownAVCapture;
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation;
@end

@implementation ViewController

- (void)setupAVCapture
{
    NSError *error = nil;

    AVCaptureSession *session = [AVCaptureSession new];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    else
        [session setSessionPreset:AVCaptureSessionPresetPhoto];

    // Select a video device, make an input
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) @throw @"DANG";

    if ([session canAddInput:deviceInput])
        [session addInput:deviceInput];

    // Make a still image output
    stillImageOutput = [AVCaptureStillImageOutput new];
    [stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)AVCaptureStillImageIsCapturingStillImageContext];
    if ( [session canAddOutput:stillImageOutput] )
        [session addOutput:stillImageOutput];

    // Make a video data output
    videoDataOutput = [AVCaptureVideoDataOutput new];

    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                       [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [videoDataOutput setVideoSettings:rgbOutputSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked (as we process the still image)

    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];

    if ( [session canAddOutput:videoDataOutput] )
        [session addOutput:videoDataOutput];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];

    effectiveScale = 1.0;
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    CALayer *rootLayer = [self.view layer];
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:previewLayer];
    [session startRunning];

    [self switchCameras:nil];
}

// clean up capture setup
- (void)teardownAVCapture {
    [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
    [previewLayer removeFromSuperlayer];
}

// perform a flash bulb animation using KVO to monitor the value of the capturingStillImage property of the AVCaptureStillImageOutput class
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((__bridge id)context == AVCaptureStillImageIsCapturingStillImageContext ) {
        BOOL isCapturingStillImage = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

        if ( isCapturingStillImage ) {
            // do flash bulb like animation
            flashView = [[UIView alloc] initWithFrame:self.view.frame];
            [flashView setBackgroundColor:[UIColor whiteColor]];
            [flashView setAlpha:0.f];
            [[[self view] window] addSubview:flashView];

            [UIView animateWithDuration:.4f
                             animations:^{
                                 [flashView setAlpha:1.f];
                             }
             ];
        }
        else {
            [UIView animateWithDuration:.4f
                             animations:^{
                                 [flashView setAlpha:0.f];
                             }
                             completion:^(BOOL finished){
                                 [flashView removeFromSuperview];
                                 flashView = nil;
                             }
             ];
        }
    }
}

// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation) deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

// utility routine to create a new image with the red square overlay with appropriate orientation
// and return the new composited image which can be saved to the camera roll
- (CGImageRef)newSquareOverlayedImageForFeatures:(NSArray *)features
                                       inCGImage:(CGImageRef)backgroundImage
                                 withOrientation:(UIDeviceOrientation)orientation
                                     frontFacing:(BOOL)isFrontFacing
{
    CGImageRef returnImage = NULL;
    CGRect backgroundImageRect = CGRectMake(0., 0., CGImageGetWidth(backgroundImage), CGImageGetHeight(backgroundImage));
    CGContextRef bitmapContext = CreateCGBitmapContextForSize(backgroundImageRect.size);
    CGContextClearRect(bitmapContext, backgroundImageRect);
    CGContextDrawImage(bitmapContext, backgroundImageRect, backgroundImage);
    CGFloat rotationDegrees = 0.;

    switch (orientation) {
        case UIDeviceOrientationPortrait:
            rotationDegrees = -90.;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotationDegrees = 90.;
            break;
        case UIDeviceOrientationLandscapeLeft:
            if (isFrontFacing) rotationDegrees = 180.;
            else rotationDegrees = 0.;
            break;
        case UIDeviceOrientationLandscapeRight:
            if (isFrontFacing) rotationDegrees = 0.;
            else rotationDegrees = 180.;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            break; // leave the layer in its last known orientation
    }
    UIImage *rotatedSquareImage = [square imageRotatedByDegrees:rotationDegrees];

    // features found by the face detector
    for ( CIFaceFeature *ff in features ) {
        CGRect faceRect = [ff bounds];
        CGContextDrawImage(bitmapContext, faceRect, [rotatedSquareImage CGImage]);
    }
    returnImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease (bitmapContext);

    return returnImage;
}

- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;

    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }

    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;

    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;

    return videoBox;
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    NSArray *sublayers = [NSArray arrayWithArray:[previewLayer sublayers]];
    NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
    NSInteger featuresCount = [features count], currentFeature = 0;

    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];

    // hide all the face layers
    for ( CALayer *layer in sublayers ) {
        if ( [[layer name] isEqualToString:@"FaceLayer"] )
            [layer setHidden:YES];
    }

    if ( featuresCount == 0) {
        [CATransaction commit];
        return; // early bail.
    }

    CGSize parentFrameSize = self.view.frame.size;
    NSString *gravity = [previewLayer videoGravity];
    BOOL isMirrored = [previewLayer isMirrored];
    CGRect previewBox = [ViewController videoPreviewBoxForGravity:gravity frameSize:parentFrameSize apertureSize:clap.size];

    for ( CIFaceFeature *ff in features ) {
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];

        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;

        if ( isMirrored )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
        else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);

        CALayer *featureLayer = nil;

        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }

        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [CALayer new];
            [featureLayer setContents:(id)[square CGImage]];
            [featureLayer setName:@"FaceLayer"];
            [previewLayer addSublayer:featureLayer];
        }
        [featureLayer setFrame:faceRect];

        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                break;
            case UIDeviceOrientationLandscapeLeft:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
                break;
            case UIDeviceOrientationLandscapeRight:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                break; // leave the layer in its last known orientation
        }
        currentFeature++;
    }

    [CATransaction commit];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // got an image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants. 
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.  
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.  
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.  
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.  
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.  
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.  
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.  
    };
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    NSArray *features = [faceDetector featuresInImage:ciImage options:imageOptions];

    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
    });
}

// use front/back camera
- (IBAction)switchCameras:(id)sender
{
    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;

    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            [[previewLayer session] beginConfiguration];
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
            for (AVCaptureInput *oldInput in [[previewLayer session] inputs]) {
                [[previewLayer session] removeInput:oldInput];
            }
            [[previewLayer session] addInput:input];
            [[previewLayer session] commitConfiguration];
            break;
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupAVCapture];

    square = [UIImage imageNamed:@"squarePNG"];
    faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyLow}];

    proximityDetector = [[ProximityDetector alloc] initWithIdealProportion:0.6];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        beginGestureScale = effectiveScale;
    }
    return YES;
}

// scale image depending on users pinch gesture
- (IBAction)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
    BOOL allTouchesAreOnThePreviewLayer = YES;
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for ( i = 0; i < numTouches; ++i ) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.view];
        CGPoint convertedLocation = [previewLayer convertPoint:location fromLayer:previewLayer.superlayer];
        if ( ! [previewLayer containsPoint:convertedLocation] ) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if ( allTouchesAreOnThePreviewLayer ) {
        effectiveScale = beginGestureScale * recognizer.scale;
        if (effectiveScale < 1.0)
            effectiveScale = 1.0;
        CGFloat maxScaleAndCropFactor = [[stillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        if (effectiveScale > maxScaleAndCropFactor)
            effectiveScale = maxScaleAndCropFactor;
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [previewLayer setAffineTransform:CGAffineTransformMakeScale(effectiveScale, effectiveScale)];
        [CATransaction commit];
    }
}

@end
