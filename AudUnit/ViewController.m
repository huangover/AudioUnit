//
//  ViewController.m
//  AudUnit
//
//  Created by sihang huang on 2019/1/8.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "ViewController.h"
#import "MyAudioUnitManager.h"
#import "MyAudioUnitManagerCallback.h"

static BOOL isRenderCallback = YES;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITableView *ipodEqualizerTableView;
@property (nonatomic, strong) MyAudioUnitManager *audioUnitManager;
@property (nonatomic, strong) MyAudioUnitManagerCallback *audioUnitManagerCallback;
@property (nonatomic, strong) NSArray *effects;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(isRenderCallback) {
        self.audioUnitManagerCallback = [MyAudioUnitManagerCallback new];
        [self.audioUnitManagerCallback constructUnits];
    } else {
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
}

- (IBAction)buttonTapped:(id)sender {
    if(isRenderCallback) {
        [self.audioUnitManagerCallback start];
    } else {
        [self.audioUnitManager start];
    }
    
}
- (IBAction)stopButtonTapped:(id)sender {
    if(isRenderCallback) {
        [self.audioUnitManagerCallback stop];
    } else {
        [self.audioUnitManager stop];
    }
}

// Mixer Unit

- (IBAction)mixerUnitVolumnSliderDidSlide:(UISlider *)sender {
    if(isRenderCallback) {
        
    } else {
        [self.audioUnitManager setMixerUnitOutputVolumn:sender.value];
    }
}

// Mic unit

- (IBAction)micUnitVolumnSliderDidSlide:(UISlider *)sender {
    if(isRenderCallback) {
        
    } else {
        [self.audioUnitManager setMicUnitVolumn:sender.value];
    }
}


// Player unit

- (IBAction)playerUnitVolumnSliderDidSlide:(UISlider *)sender {
    if (isRenderCallback) {
        return;
    } else {
        [self.audioUnitManager setPlayerUnitVolumn:sender.value];
    }
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
    if (isRenderCallback) {
        return;
    } else {
        [self.audioUnitManager setIpodUnitEffectAtIndex:indexPath.row];
    }
}

@end
