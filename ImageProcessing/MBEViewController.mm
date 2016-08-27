//
//  MBEViewController.mm
//  ImageProcessing
//
//  Created by Warren Moore on 9/30/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import "MBEViewController.h"
#import "MBEContext.h"
#import "MBEImageFilter.h"
#import "MBESaturationAdjustmentFilter.h"
#import "MBEGaussianBlur2DFilter.h"
#import "UIImage+MBETextureUtilities.h"
#import "MBEMainBundleTextureProvider.h"
#import "EquirectToCubemapFilter.h"
#import "RotatableSquareFilter.h"

@interface MBEViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) MBEContext *context;
@property (nonatomic, strong) MBEMainBundleTextureProvider *imageProvider;
@property (nonatomic, strong) MBESaturationAdjustmentFilter *desaturateFilter;
@property (nonatomic, strong) MBEGaussianBlur2DFilter *blurFilter;
@property (nonatomic, strong) EquirectToCubemapFilter *e2cFilter;

@property (nonatomic, strong) RotatableSquareFilter *filter;

@property (nonatomic, strong) MBEImageFilter *funFilter;

@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (atomic, assign) uint64_t jobIndex;

@property (nonatomic, strong) UIImagePickerController *picker;
@property (nonatomic, weak) IBOutlet UISegmentedControl *filterTypeControl;

@property (nonatomic) RSFType filterType;

@end

@implementation MBEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.picker = [[UIImagePickerController alloc] init];
    self.picker.delegate = self;
    self.picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    self.renderingQueue = dispatch_queue_create("Rendering", DISPATCH_QUEUE_SERIAL);

    self.imageView.userInteractionEnabled = YES;
    self.view.userInteractionEnabled = YES;
    [self buildFilterGraph];
    [self updateImage];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
- (void)buildFilterGraph
{
    self.context = [MBEContext newContext];
    
    self.imageProvider = [MBEMainBundleTextureProvider textureProviderWithImageNamed:@"cubemap"
                                                                             context:self.context];
    
    self.filterType = (RSFType)self.filterTypeControl.selectedSegmentIndex;
    
    
    
    /*self.funFilter = [[MBEImageFilter alloc] initWithFunctionName:@"modulo_fun" context: self.context];
    self.funFilter.provider = self.imageProvider;*/
    
/*    self.desaturateFilter = [MBESaturationAdjustmentFilter filterWithSaturationFactor:self.saturationSlider.value
                                                                              context:self.context];
    self.desaturateFilter.provider = self.imageProvider;
    
    self.blurFilter = [MBEGaussianBlur2DFilter filterWithRadius:self.blurRadiusSlider.value
                                                        context:self.context];
    self.blurFilter.provider = self.desaturateFilter;
*/
 //    self.e2cFilter = [EquirectToCubemapFilter filterWithContext:self.context];
//    self.e2cFilter.provider = self.imageProvider;
}

- (void)setFilterType:(RSFType)filterType {
    self.filter = [RotatableSquareFilter filterWithContext:self.context type:filterType];
    self.filter.provider = self.imageProvider;
    [self updateImage];
}

- (void)updateImage
{
    ++self.jobIndex;
    uint64_t currentJobIndex = self.jobIndex;

    // Grab these values while we're still on the main thread, since we could
    // conceivably get incomplete values by reading them in the background.
    float thetaOffset = self.thetaSlider.value;
    float phiOffset = self.phiSlider.value;
    
    dispatch_async(self.renderingQueue, ^{
        if (currentJobIndex != self.jobIndex)
            return;

        self.filter.phiOffset = phiOffset;
        self.filter.thetaOffset = thetaOffset;
        
        self.filter.dirty = true;

        id<MTLTexture> texture = self.filter.texture;
        UIImage *image = [UIImage imageWithMTLTexture:texture];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
        });
    });
}

- (IBAction)phiOffsetDidChange:(id)sender
{
    [self updateImage];
}

- (IBAction)thetaOffsetDidChange:(id)sender
{
    [self updateImage];
}

- (IBAction)save:(id)sender {
    UIImageWriteToSavedPhotosAlbum(self.imageView.image, nil, nil, nil);
}

- (IBAction)select:(id)sender {
    [self presentViewController:self.picker animated:YES completion:nil];
}

- (IBAction)changeFilter:(id)sender {
    UISegmentedControl *segmentedControl = (UISegmentedControl *) sender;
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    [self setFilterType:(RSFType)selectedSegment];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:true completion:nil];
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    
    self.filter.dirty = true;
    [self.imageProvider setImage:image context:self.context];
    [self updateImage];
    
}
@end
