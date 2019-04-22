//
//  MyAUEncoder.m
//  AudUnit
//
//  Created by Sihang Huang on 4/22/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "MyAUEncoder.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MyAUEncoder() {
    
    AudioConverterRef converter;
    uint8_t *buffer;
}

@end

@implementation MyAUEncoder

- (void)foo: (UInt32)bitRate {
    //输入流的描述
    AudioStreamBasicDescription inDes;
    //输出流的描述
    AudioStreamBasicDescription outDes = {0};
    outDes.mFormatID = kAudioFormatMPEG4AAC;
    outDes.mFormatFlags = kMPEG4Object_AAC_LC;
    outDes.mBytesPerFrame = 0;
    outDes.mBytesPerPacket = 0;
    outDes.mFramesPerPacket = 1024;
    outDes.mChannelsPerFrame = 2;
    
    //编码器的描述
    AudioClassDescription codecDes;
    
    UInt32 type = kAudioFormatMPEG4AAC;
    UInt32 size;
    
    if(AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(type), &type, &size) != noErr) {
        NSLog(@"获取encoder信息失败");
        return;
    }
    
    int numOfCodecs = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[numOfCodecs];
    
    if (AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(type), &type, &size, &descriptions) != noErr) {
        NSLog(@"获取encoder失败");
        return;
    }
    
    for (int i=0; i< numOfCodecs; i++) {
        AudioClassDescription des = descriptions[i];
        if (des.mSubType == kAudioFormatMPEG4AAC &&
            // ?????????????????????? 如果换成 kAppleHardwareAudioCodecManufacturer 会怎样????????????????????
            des.mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            
            codecDes = des;
            break;
        }
    }
    
    // 获取编码器
    if (AudioConverterNewSpecific(&inDes, &outDes, 1, &codecDes, &converter) != noErr) {
        NSLog(@"s初始化au converter失败");
    }
    
    UInt32 outBufferSize;
    UInt32 propertySize = sizeof(UInt32); //size of kAudioConverterPropertyMinimumOutputBufferSize
    if (AudioConverterGetProperty(converter, kAudioConverterPropertyMinimumOutputBufferSize, &propertySize, &outBufferSize) != noErr) {
        NSLog(@"获取encoder的max buffer size失败");
    }
    
    if (AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate) != noErr) {
        NSLog(@"设置encoder的bit rate失败");
    }
    
    buffer = malloc(outBufferSize * sizeof(uint8_t));
}

@end
