//
//  ViewController.h
//  ImageProcessing
//
//  Created by Warren Moore on 9/30/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MBEViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UISlider *thetaSlider;
@property (weak, nonatomic) IBOutlet UISlider *phiSlider;

- (IBAction)thetaOffsetDidChange:(id)sender;
- (IBAction)phiOffsetDidChange:(id)sender;

@end
