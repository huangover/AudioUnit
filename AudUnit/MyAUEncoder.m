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
    UInt32 bufferSize;
    int mChannels;
}

@end

@implementation MyAUEncoder

- (instancetype)initWithBitRate:(UInt32)bitRate sampleRate:(UInt32)sampleRate numChannels:(NSInteger)numChannels {
    self = [super init];
    
    if (self) {
        mChannels = numChannels;
        [self initWithBitRate:bitRate];
    }
    
    return self;
}

- (void)encode:(AudioBufferList *)inData completion:(ConvertCallback)completion {
    
}


- (void)initWithBitRate:(UInt32)bitRate {
    //输入流的描述
    
    UInt32 bytesPerSample = sizeof(UInt16);
    AudioStreamBasicDescription inDes;
    inDes.mChannelsPerFrame = mChannels;
    inDes.mFramesPerPacket = 1;
    inDes.mBytesPerPacket = bytesPerSample * inDes.mChannelsPerFrame;
    inDes.mBytesPerFrame = bytesPerSample * inDes.mChannelsPerFrame;
    inDes.mBitsPerChannel = 8 * inDes.mChannelsPerFrame;
    inDes.mFormatID = kAudioFormatLinearPCM;
    inDes.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    inDes.mSampleRate = 44100;
    
    //输出流的描述
    AudioStreamBasicDescription outDes = {0};
    outDes.mSampleRate = inDes.mSampleRate;
    outDes.mFormatID = kAudioFormatMPEG4AAC;
    outDes.mFormatFlags = kMPEG4Object_AAC_LC;
    outDes.mBytesPerFrame = 0;
    outDes.mBytesPerPacket = 0;
    outDes.mFramesPerPacket = 1024;
    outDes.mChannelsPerFrame = mChannels;
    
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
        return;
    }
    
    if (AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate) != noErr) {
        NSLog(@"设置encoder的bit rate失败");
        return;
    }
    
    UInt32 propertySize = sizeof(UInt32); //size of kAudioConverterPropertyMinimumOutputBufferSize
    if (AudioConverterGetProperty(converter, kAudioConverterPropertyMaximumOutputPacketSize, &propertySize, &bufferSize) != noErr) {
        NSLog(@"获取encoder的max buffer size失败");
        return;
    }
    
    buffer = malloc(bufferSize * sizeof(uint8_t));
}

- (void)encode {
    while (true) {
        
        AudioBufferList *list = {0};
        list->mNumberBuffers = 1;
        list->mBuffers[0].mData = buffer;
        list->mBuffers[0].mNumberChannels = 2;
        list->mBuffers[0].mDataByteSize = bufferSize;
        UInt32 ioOutputDataPacketSize = 1;
        if (AudioConverterFillComplexBuffer(converter, inputDataProc, (__bridge void * _Nullable)(self), &ioOutputDataPacketSize, list, NULL) != noErr) {
            NSLog(@"AudioConverterFillComplexBuffer failed");
            break;
        }
        
        
    }
}

OSStatus inputDataProc(AudioConverterRef               inAudioConverter,
                       UInt32 *                        ioNumberDataPackets,
                       AudioBufferList *               ioData,
                       AudioStreamPacketDescription ** outDataPacketDescription,
                       void *                          inUserData)
{
    
    MyAUEncoder *encoder = (__bridge MyAUEncoder *)inUserData;
    if ([encoder.datasource respondsToSelector:@selector(fillBuffer:size:)]) {
        [encoder.datasource fillBuffer:ioData->mBuffers[0].mData size:<#(NSInteger)#>]
    }
    return noErr;
}


@end
