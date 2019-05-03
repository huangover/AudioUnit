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

@interface EncodeWithAUVC () <MyAUEncoderDataSource, MyAUEncoderDelegate>

@property (nonatomic) MyDecoder *myDecoder;
@property (nonatomic, strong) MyAUEncoder *auEncoder;
@property (nonatomic, strong) NSFileHandle *aacFileHandle;
@property (nonatomic, strong) NSFileHandle *pcmFileHandle;
@property (weak, nonatomic) IBOutlet UILabel *encodeStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *checkEncodedFileExistsLabel;

@end

@implementation EncodeWithAUVC

- (NSString *)pcmFilePath {
    return [CommonUtil bundlePath:@"abc.pcm"];
}

- (NSString *)aacFilePath {
    return [CommonUtil documentsPath:@"vocal.aac"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
   
    // 用myDecoder解码出来的数据去喂MyAUEncoder，编码，然后保存到文件中。最后听一听文件是否可以正常播放
    
    self.auEncoder = [[MyAUEncoder alloc] initWithBitRate:128 * 1024 sampleRate:44100 numChannels:2];
    self.auEncoder.datasource = self;
    self.auEncoder.delegate = self;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"111" ofType:@"aac"];
    const char *myPcmFilePath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    self.myDecoder = new MyDecoder();
    self.myDecoder->init(myPcmFilePath, NULL);
    
    
    _pcmFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.pcmFilePath];
    
    [[NSFileManager defaultManager] removeItemAtPath:self.aacFilePath error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.aacFilePath contents:nil attributes:nil];
    _aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.aacFilePath];
    
}

- (IBAction)encodeButtonTapped:(id)sender {
    dispatch_queue_t encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(encoderQueue, ^{
        [self.auEncoder encode];
    });
}


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
- (IBAction)checkEncodedFileExists:(UIButton *)sender {
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:self.aacFilePath];
    
    self.checkEncodedFileExistsLabel.text = [NSString stringWithFormat:@"编码的文件(vocal.aac)在%@, 大小%lu", self.aacFilePath, data.length];
    NSLog(@"编码的文件在%@, 大小%lu", self.aacFilePath, data.length);
    
}

@end
