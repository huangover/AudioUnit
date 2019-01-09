//
//  ViewController.m
//  AudUnit
//
//  Created by sihang huang on 2019/1/8.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "ViewController.h"
#import "MyAudioUnitManager.h"

@interface ViewController ()
@property (nonatomic, strong) MyAudioUnitManager *audioUnitManager;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)buttonTapped:(id)sender {
    if (!self.audioUnitManager) {
        self.audioUnitManager = [MyAudioUnitManager new];
        [self.audioUnitManager constructUnits];
    }
    [self.audioUnitManager start];
    
    return;
}
- (IBAction)stopButtonTapped:(id)sender {
    [self.audioUnitManager stop];
}


@end
