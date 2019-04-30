//
//  ViewController.m
//  AudUnit
//
//  Created by sihang huang on 2019/1/8.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "ViewController.h"
#import "ConnectNodesAndRecordManager.h"
#import "RenderAUWithFFmpegDataManager.h"
#import "MyDecoder.hpp"
#import "accompany_decoder_controller.h"
#import "RenderAUWithStreamDataManager.h"
#import "CommonUtil.h"
#import "MyAUEncoder.h"

typedef NS_ENUM(NSUInteger, DecoderType) {
    DecoderTypeMy,
    DecoderTypeSample
};

BOOL isRenderCallbackWithDecoder = NO;

@interface ViewController () <RenderAUWithFFmpegDataManagerDelegate, MyAUEncoderDataSource, MyAUEncoderDelegate>
    
@property (weak, nonatomic) IBOutlet UITableView *ipodEqualizerTableView;
@property (nonatomic, strong) ConnectNodesAndRecordManager *connectAUNodesManager;
@property (nonatomic, strong) RenderAUWithFFmpegDataManager *renderAUFFmpegDataManager;
@property (nonatomic, strong) RenderAUWithStreamDataManager *renderAUDataManager;
@property (nonatomic, strong) NSArray *effects;
@property (nonatomic) MyDecoder *myDecoder;
@property (nonatomic) AccompanyDecoderController *decoderController;
@property (nonatomic, assign) DecoderType decoderType;
@property (nonatomic, strong) MyAUEncoder *auEncoder;
@property (nonatomic, strong) NSFileHandle *aacFileHandle;
@property (nonatomic, strong) NSFileHandle *pcmFileHandle;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path1 = [CommonUtil documentsPath:@"vocal.aac"];
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path1];
    NSLog(@"编码的文件在%@, 大小%lu", path1, data.length);
//    [self testEncoder];
    return;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"111" ofType:@"aac"];
    
    if (!path) {
        NSLog(@"Failed to log aac");
        return;
    }
    
    self.decoderType = DecoderTypeMy;
    const char *myPcmFilePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    if (isRenderCallbackWithDecoder) {
        
        if (self.decoderType == DecoderTypeSample) {
            // sample code的解码
            //初始化解码模块，并且从解码模块中取出原始数据
            _decoderController = new AccompanyDecoderController();
            _decoderController->init(myPcmFilePath, 0.2f);
        } else {
            // 自己写的解码
            self.myDecoder = new MyDecoder();
            self.myDecoder->init(myPcmFilePath, NULL);
            self.myDecoder->preDecode10Buffers();
        }
        
        self.renderAUFFmpegDataManager = [RenderAUWithFFmpegDataManager new];
        self.renderAUFFmpegDataManager.delegate = self;
        [self.renderAUFFmpegDataManager constructUnits];
    }
//    else if (isRenderMyDecoder) {
//        MyDecoder *ffDecoder = new MyDecoder();
//        ffDecoder->init(myPcmFilePath, NULL);
//        int sampleRate= ffDecoder->getSampleRate();
//
//        self.ffDecoder = ffDecoder;
//        self.renderAUDataManager = [RenderAUDataManager new];
////        self.renderAUDataManager.mySampleRate = sampleRate;
////        self.renderAUDataManager.delegate = self;
//        [self.renderAUDataManager constructUnits];
//    }
    else {
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
}

# pragma mark -- MyAUEncoder

- (void)testEncoder {
    // 用myDecoder解码出来的数据去喂MyAUEncoder，编码，然后保存到文件中。最后听一听文件是否可以正常播放
    
    self.auEncoder = [[MyAUEncoder alloc] initWithBitRate:128 * 1024 sampleRate:44100 numChannels:2];
    self.auEncoder.datasource = self;
    self.auEncoder.delegate = self;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"111" ofType:@"aac"];
    const char *myPcmFilePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    self.myDecoder = new MyDecoder();
    self.myDecoder->init(myPcmFilePath, NULL);
    
    
    NSString *_pcmFilePath = [CommonUtil bundlePath:@"abc.pcm"];
    _pcmFileHandle = [NSFileHandle fileHandleForReadingAtPath:_pcmFilePath];
    
    NSString *_aacFilePath = [CommonUtil documentsPath:@"vocal.aac"];
    [[NSFileManager defaultManager] removeItemAtPath:_aacFilePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:_aacFilePath contents:nil attributes:nil];
    _aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:_aacFilePath];
    
    dispatch_queue_t encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(encoderQueue, ^{
        [self.auEncoder encode];
    });
}

- (UInt32)fillBuffer:(uint8_t *)buffer byteSize:(NSInteger)size {
    
    
//    UInt32 ret = 0;
//    NSData* data = [_pcmFileHandle readDataOfLength:size];
//    if(data && data.length > 0) {
//        memcpy(buffer, data.bytes, data.length);
//        ret = (UInt32)data.length;
//    }
//    return ret;
    
    // 参数的size是以byte为单位
    int dataRead = self.myDecoder->readData_returnLen((short *)buffer, size);

    return dataRead;
}

- (void)didConvertToAACData:(NSData *)data error:(nonnull NSError *)error {
    if (error) {
        NSLog(@"编码写文件完成，文件关闭");
        [_aacFileHandle closeFile];
    } else {
        NSLog(@"写数据长度%d",  data.length);
        [_aacFileHandle writeData:data];
    }
}


# pragma mark -- RenderAUWithFFmpegDataManagerDelegate

// sample code的decoder用
- (NSInteger)renderAUWithFFmpegDataManager:(RenderAUWithFFmpegDataManager *)manager fillAudioData:(SInt16 *)sampleBuffer numFrames:(NSInteger)frameNum numChannels:(NSInteger)channels {

    //默认填充空数据
    memset(sampleBuffer, 0, frameNum * channels * sizeof(SInt16));
    if(_decoderController) {
        //从decoderController中取出数据，然后填充进去
        _decoderController->readSamples(sampleBuffer, (int)(frameNum * channels));
    }
    return 1;
}

- (void)renderAUWithFFmpegDataManager:(RenderAUWithFFmpegDataManager *)manager fillBuffer:(short *)buffer withSize:(int)size {
    
    if (!isRenderCallbackWithDecoder) { return; }
    
    if (self.decoderType == DecoderTypeSample) {
        [self renderAUWithFFmpegDataManager:manager fillAudioData:buffer numFrames:1 numChannels:size]; // 调用另一个delegate方法
    } else {
        self.myDecoder->readData(buffer, size);
    }
    
}

- (int)numOfChannelsForManager:(RenderAUWithFFmpegDataManager *)manager {
    
    if (!isRenderCallbackWithDecoder) { return 0; }
    
    if (self.decoderType == DecoderTypeSample) {
        return _decoderController->getChannels();
    } else {
        return self.myDecoder->outDataNumChannels();
    }
}

- (double)sampleRateForManager:(RenderAUWithFFmpegDataManager *)manager {
    
    if (!isRenderCallbackWithDecoder) { return 0; }
    
    if (self.decoderType == DecoderTypeSample) {
        return _decoderController->getAudioSampleRate();
    } else {
        return self.myDecoder->getSampleRate();
    }
}

# pragma mark - Actions

- (IBAction)buttonTapped:(id)sender {
    if(isRenderCallbackWithDecoder) {
        [self.renderAUFFmpegDataManager start];
    } else {
        [self.connectAUNodesManager start];
    }
    
}
- (IBAction)stopButtonTapped:(id)sender {
    if(isRenderCallbackWithDecoder) {
        [self.renderAUFFmpegDataManager stop];
    } else {
        [self.connectAUNodesManager stop];
    }
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
