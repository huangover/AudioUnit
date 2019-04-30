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
    NSInteger mChannels;
    uint8_t *_pcmBuffer;
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
        
        AudioBufferList list = {0};
        list.mNumberBuffers = 1;
        list.mBuffers[0].mData = buffer;
        list.mBuffers[0].mNumberChannels = mChannels;
        list.mBuffers[0].mDataByteSize = bufferSize;
        UInt32 ioOutputDataPacketSize = 1;
        if (AudioConverterFillComplexBuffer(converter, inputDataProc, (__bridge void * _Nullable)(self), &ioOutputDataPacketSize, &list, NULL) != noErr) {
            NSLog(@"AudioConverterFillComplexBuffer failed");
            
            if ([self.delegate respondsToSelector:@selector(didConvertToAACData:error:)]) {
                [self.delegate didConvertToAACData:nil error:[NSError errorWithDomain:NSOSStatusErrorDomain code:-1 userInfo:nil]];
            }
            
            break;
        }
        
        NSData *encodedData = [NSData dataWithBytes:list.mBuffers[0].mData length:list.mBuffers[0].mDataByteSize];
        NSData *adt = [self adtsDataForPacketLength:encodedData.length];
        NSMutableData *mutData = [NSMutableData dataWithData:adt];
        [mutData appendData:encodedData];
        
        if ([self.delegate respondsToSelector:@selector(didConvertToAACData:error:)]) {
            [self.delegate didConvertToAACData:mutData error:nil];
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
    return [encoder encodeData:*ioNumberDataPackets ioData:ioData];
}

- (OSStatus)encodeData:(UInt32)ioNumberDataPackets ioData:(AudioBufferList *)ioData {
    // size由AudioStreamBasicDescription inDes决定
    // inDes注明1个frame/packet, bytes/Frame = channels * sizeof(UInt16)
    
    static int count = 0;
    
    NSInteger size = ioNumberDataPackets * mChannels * sizeof(UInt16);
    
    // 因为*ioData.mBuffers[0]是NULL
    if(NULL == _pcmBuffer) {
        _pcmBuffer = malloc(size);
    }
    
    UInt32 dataRead = 0;
    if ([self.datasource respondsToSelector:@selector(fillBuffer:byteSize:)]) {
        dataRead = [self.datasource fillBuffer:_pcmBuffer byteSize:size];
    } else {
        return -1;
    }
    
    if (dataRead == 0) {
//        *ioNumberDataPackets = 0; //为什么要修改这个？？
        NSLog(@"循环了%d次",count);
        return -1;
    } else {
        count++;
//        NSLog(@"读数据，长度为%d", dataRead);
    }
    
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mDataByteSize = size;
    ioData->mBuffers[0].mNumberChannels = mChannels;
//    *ioNumberDataPackets = 1
    return noErr;
}

- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = mChannels;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}
@end
