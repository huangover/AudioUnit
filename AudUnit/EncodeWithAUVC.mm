//
//  EncodeWithAUVC.m
//  AudUnit
//
//  Created by Sihang Huang on 5/3/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "EncodeWithAUVC.h"
#import "MyDecoder.hpp"
#import "MyAUEncoder.h"
#import "CommonUtil.h"
#import "AU/ConnectNodesAndRecordManager.h"
#import "SSZAACSoftEncoder.h"
#import "SSZAudioConfig.h"

static bool AAC_DECODE_HARDWARE = 0;

#define BIT_RATE 64*1024
#define SAMPLE_RATE 44100
#define CHANNELS 2

@interface EncodeWithAUVC () <MyAUEncoderDataSource, MyAUEncoderDelegate, ConnectNodesAndRecordManagerDelegate, SSZAACSoftEncoderDelegate> {
    dispatch_queue_t encoderQueue;
}

@property (nonatomic) MyDecoder *myDecoder;
@property (nonatomic, strong) MyAUEncoder *auEncoder;//硬编码
@property (nonatomic, strong) SSZAACSoftEncoder *aacSoftEncoder;//软编码
@property (nonatomic, strong) NSFileHandle *aacFileHandle;
@property (nonatomic, strong) NSFileHandle *pcmFileHandle;
@property (weak, nonatomic) IBOutlet UILabel *encodeStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *checkEncodedFileExistsLabel;

@property (nonatomic, strong) ConnectNodesAndRecordManager *connectAUNodesManager;

@end

@implementation EncodeWithAUVC

- (NSString *)pcmFilePath {
    return [CommonUtil bundlePath:@"abc.pcm"];
}

- (NSString *)aacFilePath {
    return [CommonUtil documentsPath:@"vocal.aac"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSFileManager defaultManager] removeItemAtPath:self.aacFilePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.aacFilePath contents:nil attributes:nil];
    _aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.aacFilePath];
    
    if (YES) {
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"111" ofType:@"aac"];
        const char *myPcmFilePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
        self.myDecoder = new MyDecoder();
        self.myDecoder->init(myPcmFilePath, NULL);
        
        if (AAC_DECODE_HARDWARE) {
            // 方案一：用myDecoder解码出来的数据去喂MyAUEncoder，编码，然后保存到文件中。最后听一听文件是否可以正常播放。
            // MyAUEncoder的delegate要数据，MyDecoder提供数据给回调，然后进行编码
            self.auEncoder = [[MyAUEncoder alloc] initWithBitRate:BIT_RATE sampleRate:SAMPLE_RATE numChannels:CHANNELS];
            self.auEncoder.datasource = self;
            self.auEncoder.delegate = self;
        } else {
            SSZAudioConfig *config = [SSZAudioConfig new];
            config.bitRate = BIT_RATE;
            config.sampleRate = SAMPLE_RATE;
            config.channel = CHANNELS;
            self.aacSoftEncoder = [[SSZAACSoftEncoder alloc] initWithAudioConfig:config];
            self.aacSoftEncoder.delegate = self;
            
            short *buffer = (short *)malloc(sizeof(short) * 2048);
            int size = sizeof(short) * 2048;
            
            int dataRead = 0;
            while ((dataRead = self.myDecoder->readData_returnLen((short *)buffer, size)) > 0) { // 参数的size是以byte为单位
                [self.aacSoftEncoder encode:buffer len:dataRead];
                
                
            }
            free(buffer);
            buffer = NULL;
            NSLog(@"编码写文件完成，文件关闭");
            [_aacFileHandle closeFile];
        }
        
        _pcmFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.pcmFilePath];
    } else {
    
        // 方案二：用ConnectAUNodesManager作为输出，编码，并保存文件。问题在于，目前MyAuDecoder是callback要数据，跟ConnectAUNodesManager的机制冲突，要看看MyAuDecoder有没有别的api
        // 如果机制冲突了，那说明硬编码不行？？？只能用FFmpeg的软编码了？？？
        
        self.connectAUNodesManager = [ConnectNodesAndRecordManager new];
        [self.connectAUNodesManager constructUnits];
    }
}

#pragma mark -- Action

- (IBAction)encodeButtonTapped:(id)sender {
    encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(encoderQueue, ^{
        [self.auEncoder encode];
    });
}

- (IBAction)checkEncodedFileExists:(UIButton *)sender {
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:self.aacFilePath];
    
    self.checkEncodedFileExistsLabel.text = [NSString stringWithFormat:@"编码的文件(vocal.aac)在%@, 大小%lu", self.aacFilePath, data.length];
    NSLog(@"编码的文件在%@, 大小%lu", self.aacFilePath, data.length);
    
}

#pragma mark -- SSZAACSoftEncoderDelegate

- (void)aacSoftEncoderDidEncodeData:(void *)data1 len:(int)len {
    if (len == 0) {
        puts("编码0字节");
    } else {
        NSData *data = [NSData dataWithBytes:data1 length:len];
//        NSData *data = [NSData dataWithBytes:data length:len];
        [_aacFileHandle writeData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.encodeStatusLabel.text = [NSString stringWithFormat:@"写数据长度%lu",  (unsigned long)data.length];
        });
    }
}

#pragma mark -- MyAUEncoder delegate & dataSource

- (UInt32)fillBuffer:(uint8_t *)buffer byteSize:(NSInteger)size {
    
    // 参数的size是以byte为单位
    int dataRead = self.myDecoder->readData_returnLen((short *)buffer, size);
    
    return dataRead;
}

- (void)didConvertToAACData:(NSData *)data error:(nonnull NSError *)error {
    if (error) {
        NSLog(@"编码写文件完成，文件关闭");
        [_aacFileHandle closeFile];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.encodeStatusLabel.text = @"编码写文件完成，文件关闭";
        });
    } else {
        NSLog(@"写数据长度%d",  data.length);
        [_aacFileHandle writeData:data];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.encodeStatusLabel.text = [NSString stringWithFormat:@"写数据长度%d",  data.length];
        });
    }
}

#pragma mark -- ConnectNodesAndRecordManagerDelegate

- (void)didRenderNumberFrames:(UInt32)inNumberFrames data:(AudioBufferList *)ioData {
    
}

@end
