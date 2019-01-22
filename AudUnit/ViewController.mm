//
//  ViewController.m
//  AudUnit
//
//  Created by sihang huang on 2019/1/8.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "ViewController.h"
#import "ConnectAUNodesManager.h"
#import "RenderAUDataManager.h"
#import "FFmpeg/MyDecoder.hpp"

static BOOL isRenderCallback = YES;

@interface ViewController () <RenderAUDataManagerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *ipodEqualizerTableView;
@property (nonatomic, strong) ConnectAUNodesManager *connectAUNodesManager;
@property (nonatomic, strong) RenderAUDataManager *renderAUDataManager;
@property (nonatomic, strong) NSArray *effects;
@property (nonatomic) MyDecoder *ffDecoder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"131" ofType:@"aac"];
    
    if (!path) {
        NSLog(@"Failed to log 131.aac");
        return;
    }
    
    const char *myPcmFilePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    MyDecoder *ffDecoder = new MyDecoder();
    ffDecoder->init(myPcmFilePath, NULL);
    self.ffDecoder = ffDecoder;
    
    if(isRenderCallback) {
        self.renderAUDataManager = [RenderAUDataManager new];
        self.renderAUDataManager.delegate = self;
        [self.renderAUDataManager constructUnits];
    } else {
        [self.ipodEqualizerTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
        
        self.connectAUNodesManager = [ConnectAUNodesManager new];
        
        __weak typeof(self) weakSelf = self;
        self.connectAUNodesManager.didGetEffectsBlock = ^(NSArray *effects) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.effects = effects;
            [strongSelf.ipodEqualizerTableView reloadData];
            
        };
        
        [self.connectAUNodesManager constructUnits];
    }
}

// RenderAUManagerDelegate

- (void)fillBuffer:(short *)buffer withSize:(int)size {
    self.ffDecoder->readData(buffer, size);
}

- (int)numOfChannels {
    return self.ffDecoder->outDataNumChannels();
}


// Actions

- (IBAction)buttonTapped:(id)sender {
    if(isRenderCallback) {
        [self.renderAUDataManager start];
    } else {
        [self.connectAUNodesManager start];
    }
    
}
- (IBAction)stopButtonTapped:(id)sender {
    if(isRenderCallback) {
        [self.renderAUDataManager stop];
    } else {
        [self.connectAUNodesManager stop];
    }
}

// Mixer Unit

- (IBAction)mixerUnitVolumnSliderDidSlide:(UISlider *)sender {
    if(isRenderCallback) {
        
    } else {
        [self.connectAUNodesManager setMixerUnitOutputVolumn:sender.value];
    }
}

// Mic unit

- (IBAction)micUnitVolumnSliderDidSlide:(UISlider *)sender {
    if(isRenderCallback) {
        
    } else {
        [self.connectAUNodesManager setMicUnitVolumn:sender.value];
    }
}


// Player unit

- (IBAction)playerUnitVolumnSliderDidSlide:(UISlider *)sender {
    if (isRenderCallback) {
        return;
    } else {
        [self.connectAUNodesManager setPlayerUnitVolumn:sender.value];
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
        [self.connectAUNodesManager setIpodUnitEffectAtIndex:indexPath.row];
    }
}

@end
