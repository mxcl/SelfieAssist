//
//  InstructionsViewController.m
//  SelfieAssist
//
//  Created by Joe on 7/12/15.
//  Copyright (c) 2015 Max Howell. All rights reserved.
//

#import "InstructionsViewController.h"

@interface InstructionsViewController ()
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UILabel *label;
@end

@implementation InstructionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.button.layer.cornerRadius = 20;
    self.button.layer.borderWidth = 5;
    self.button.layer.borderColor = [[UIColor blackColor]CGColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
