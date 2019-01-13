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
@property (weak, nonatomic) IBOutlet UITableView *ipodEqualizerTableView;
@property (nonatomic, strong) MyAudioUnitManager *audioUnitManager;
@property (nonatomic, strong) NSArray *effects;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.ipodEqualizerTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    
    self.audioUnitManager = [MyAudioUnitManager new];
    
    __weak typeof(self) weakSelf = self;
    self.audioUnitManager.didGetEffectsBlock = ^(NSArray *effects) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.effects = effects;
        [strongSelf.ipodEqualizerTableView reloadData];
        
    };
    
    [self.audioUnitManager constructUnits];
}

- (IBAction)buttonTapped:(id)sender {
    [self.audioUnitManager start];
    
    return;
}
- (IBAction)stopButtonTapped:(id)sender {
    [self.audioUnitManager stop];
}

// Mixer Unit

- (IBAction)mixerUnitVolumnSliderDidSlide:(UISlider *)sender {
    
    [self.audioUnitManager setMixerUnitOutputVolumn:sender.value];
}

// Mic unit

- (IBAction)micUnitVolumnSliderDidSlide:(UISlider *)sender {
    [self.audioUnitManager setMicUnitVolumn:sender.value];
}


// Player unit

- (IBAction)playerUnitVolumnSliderDidSlide:(UISlider *)sender {
    [self.audioUnitManager setPlayerUnitVolumn:sender.value];
}

// effect unit

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.effects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = self.effects[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.audioUnitManager setIpodUnitEffectAtIndex:indexPath.row];
}

@end
