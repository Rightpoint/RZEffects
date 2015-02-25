//
//  ViewController.m
//  RZEffectsDemo
//
//  Created by Rob Visentin on 1/15/15.
//  Copyright (c) 2015 Raizlabs. All rights reserved.
//

#import "ViewController.h"

#import "RZEffectView.h"
#import "RZClothEffect.h"
#import "RZBlurEffect.h"
#import "RZCompositeEffect.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UISwitch *clothSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *blurSwitch;

@property (weak, nonatomic) IBOutlet UISlider *effectSlider;
@property (weak, nonatomic) IBOutlet UISlider *lightSlider;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@property (strong, nonatomic) RZEffectView *effectView;

@property (strong, nonatomic) RZClothEffect *clothEffect;
@property (strong, nonatomic) RZBlurEffect *blurEffect;
@property (strong, nonatomic) RZCompositeEffect *compositeEffect;

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class])];

    [self setupEffects];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if ( self.effectView == nil ) {
        self.effectView = [[RZEffectView alloc] initWithSourceView:self.contentView effect:nil dynamicContent:YES];
        self.effectView.backgroundColor = [UIColor blackColor];
        self.effectView.framesPerSecond = 30;
        
        [self.view insertSubview:self.effectView aboveSubview:self.contentView];

        [self toggleEffect];
    }
}

- (void)setupEffects
{
    self.clothEffect = [RZClothEffect effect];
    self.blurEffect = [RZBlurEffect effectWithSigma:8.0f];
    self.compositeEffect = [RZCompositeEffect compositeEffectWithFirstEffect:self.blurEffect secondEffect:self.clothEffect];
}

- (IBAction)toggleEffect
{
    self.effectView.hidden = NO;

    if ( self.clothSwitch.isOn && self.blurSwitch.isOn ) {
        self.effectView.effect = self.compositeEffect;
    }
    else if ( self.clothSwitch.isOn ) {
        self.effectView.effect = self.clothEffect;
    }
    else if ( self.blurSwitch.isOn ) {
        self.effectView.effect = self.blurEffect;
    }
    else {
        self.effectView.hidden = YES;
    }

    if ( self.clothSwitch.isOn ) {
        self.effectView.effectTransform.rotation = GLKQuaternionMake(-0.133518726, 0.259643972, 0.0340433009, 0.955821096);
    }
    else {
        self.effectView.effectTransform.rotation = GLKQuaternionIdentity;
    }

//    self.imageView.hidden = !self.blurSwitch.isOn;

    self.effectSlider.value = 0.0f;
    self.lightSlider.value = 0.0f;

    [self effectSliderChanged:self.effectSlider];
    [self lightSliderChanged:self.lightSlider];
}

- (IBAction)effectSliderChanged:(UISlider *)sender
{
    self.clothEffect.waveAmplitude = 0.05f + 0.15f * self.effectSlider.value;
    self.blurEffect.sigma = 8.0f + 100.0f * self.effectSlider.value;
}

- (IBAction)lightSliderChanged:(UISlider *)sender
{
    self.clothEffect.lightOffset = GLKVector3Make(0.0f, 1.1f, 4.0f - 6.0f * self.lightSlider.value);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 100;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class]) forIndexPath:indexPath];

    cell.textLabel.text = [NSString stringWithFormat:@"Live Table View Cell %i", (int)indexPath.row];

    CGFloat r, g, b;
    r = arc4random_uniform(256) / 255.0f;
    g = arc4random_uniform(256) / 255.0f;
    b = arc4random_uniform(256) / 255.0f;

    cell.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0f];

    return cell;
}

#pragma mark - UITableViewDelegate

@end
