//
//  ConnectNodesAndRecordVC.m
//  AudUnit
//
//  Created by Sihang Huang on 5/3/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "ConnectNodesAndRecordVC.h"
#import "ConnectNodesAndRecordManager.h"
#import "CommonUtil.h"

@interface ConnectNodesAndRecordVC ()
@property (weak, nonatomic) IBOutlet UITableView *ipodEqualizerTableView;
@property (nonatomic, strong) ConnectNodesAndRecordManager *connectAUNodesManager;
@property (nonatomic, strong) NSArray *effects;
@end

@implementation ConnectNodesAndRecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *outURLString = [CommonUtil documentsPath:@"output.wav"];
    NSURL *outURL = [NSURL URLWithString:outURLString];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outURLString]) {
        NSLog(@"output.wav exists!");
    } else {
        NSLog(@"output.wav does NOT exist!");
    }
    
    [self.ipodEqualizerTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    
    self.connectAUNodesManager = [ConnectNodesAndRecordManager new];
    
    __weak typeof(self) weakSelf = self;
    self.connectAUNodesManager.didGetEffectsBlock = ^(NSArray *effects) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.effects = effects;
        [strongSelf.ipodEqualizerTableView reloadData];
        
    };
    
    [self.connectAUNodesManager constructUnits];
}

# pragma mark - Actions

- (IBAction)buttonTapped:(id)sender {
//    if(isRenderCallbackWithDecoder) {
//        [self.renderAUFFmpegDataManager start];
//    } else {
        [self.connectAUNodesManager start];
//    }
    
}
- (IBAction)stopButtonTapped:(id)sender {
//    if(isRenderCallbackWithDecoder) {
//        [self.renderAUFFmpegDataManager stop];
//    } else {
        [self.connectAUNodesManager stop];
//    }
}

// Mixer Unit

- (IBAction)mixerUnitVolumnSliderDidSlide:(UISlider *)sender {
    [self.connectAUNodesManager setMixerUnitOutputVolumn:sender.value];
}

// Mic unit

- (IBAction)micUnitVolumnSliderDidSlide:(UISlider *)sender {
    [self.connectAUNodesManager setMicUnitVolumn:sender.value];
}


// Player unit

- (IBAction)playerUnitVolumnSliderDidSlide:(UISlider *)sender {
    [self.connectAUNodesManager setPlayerUnitVolumn:sender.value];
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
    [self.connectAUNodesManager setIpodUnitEffectAtIndex:indexPath.row];
}

@end
