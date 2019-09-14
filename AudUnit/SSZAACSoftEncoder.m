//
//  SSZAACSoftEncoder.m
//  SSZAVSDK
//
//  Created by SihangHuang on 2019/9/12.
//  Copyright © 2019 XianhuanLin. All rights reserved.
//

#import "SSZAACSoftEncoder.h"
#import "aacenc_lib.h"
#import "math.h"
#import "SSZAudioConfig.h"

#define INPUT_BUFFER_SIZE 8*2048
#define OUTPUT_BUFFER_SIZE 8192

static const char *fdkaac_error(AACENC_ERROR erraac)
{
    switch (erraac)
    {
        case AACENC_OK: return "No error";
        case AACENC_INVALID_HANDLE: return "Invalid handle";
        case AACENC_MEMORY_ERROR: return "Memory allocation error";
        case AACENC_UNSUPPORTED_PARAMETER: return "Unsupported parameter";
        case AACENC_INVALID_CONFIG: return "Invalid config";
        case AACENC_INIT_ERROR: return "Initialization error";
        case AACENC_INIT_AAC_ERROR: return "AAC library initialization error";
        case AACENC_INIT_SBR_ERROR: return "SBR library initialization error";
        case AACENC_INIT_TP_ERROR: return "Transport library initialization error";
        case AACENC_INIT_META_ERROR: return "Metadata library initialization error";
        case AACENC_ENCODE_ERROR: return "Encoding error";
        case AACENC_ENCODE_EOF: return "End of file";
        default: return "Unknown error";
    }
}


@interface SSZAACSoftEncoder () {
    HANDLE_AACENCODER encoder;
    AACENC_BufDesc inBufDescription;
    AACENC_BufDesc outBufDescription;
    
    // TO-DO: 研究初始化的数字
//    INT_PCM inputBuffer[INPUT_BUFFER_SIZE];
//    INT_PCM *inputBuffer;
//    UCHAR ancillaryBuffer[50];
//    AACENC_MetaData metaData;
//    UCHAR outBuffer[OUTPUT_BUFFER_SIZE];
    UCHAR *outbuffer;
    AACENC_InArgs inArg;
    AACENC_OutArgs outArg;
    
    AACENC_ERROR status;
}

@property (nonatomic, strong) SSZAudioConfig *config;

@end

@implementation SSZAACSoftEncoder

- (void)encode:(short *)ioData len:(int)len {
    if (len == 0) return;

    // 配置输入buffer描述
    {
        int inBufSize = len;
        INT inBuffIds = IN_AUDIO_DATA;
        INT inBufElSizes = sizeof(INT_PCM);
        inBufDescription.numBufs = 1;
        inBufDescription.bufs = (void **)&ioData;
        inBufDescription.bufferIdentifiers = &inBuffIds;
        inBufDescription.bufElSizes = &inBufElSizes;
        inBufDescription.bufSizes = &inBufSize;
    }
    // 配置输出buffer描述
    {
        int outBufSize = sizeof(UCHAR) * len;
        if (outbuffer == NULL) outbuffer = malloc(outBufSize);
        INT outBuffId = OUT_BITSTREAM_DATA;
        INT outBufElSize = sizeof(UCHAR);
        outBufDescription.numBufs = 1;
        outBufDescription.bufs = (void **)&outbuffer;
        outBufDescription.bufferIdentifiers = &outBuffId;
        outBufDescription.bufSizes = &outBufSize;
        outBufDescription.bufElSizes = &outBufElSize;
    }
    
    //所有通道的加起来的采样点数，每个采样点是2个字节所以/2 ??????
    inArg.numInSamples = (INT)len / 2; // TO-DO: 为什么除以2. numInSamples到底是什么
    if ((status = aacEncEncode(encoder,
                               &inBufDescription,
                               &outBufDescription,
                               &inArg,
                               &outArg)) != AACENC_OK) {
        printf("SSZAACSoftEncoder编码失败, ret = 0x%x, error is %s\n", status, fdkaac_error(status));
    } else {
        printf("编码了%d字节\n",outArg.numOutBytes);
        [self.delegate aacSoftEncoderDidEncodeData:outbuffer len:outArg.numOutBytes];
    }
}

//- (void)encode:(SSZAVFrame*)frameData isKeyFrame:(BOOL)isKey {
//    static size_t inBufByteSize = sizeof(INT_PCM) * INPUT_BUFFER_SIZE;
//    NSUInteger sizeByteTotal = frameData.avData.length;
//    NSUInteger step = FDKmin(sizeByteTotal, inBufByteSize);
//    
//    UCHAR *bytes = [frameData.avData bytes];
//    
//    while (sizeByteTotal > 0) {
//        FDKmemcpy(inputBuffer, bytes, (UINT)step);
//        sizeByteTotal -= step;
//        step = FDKmin(sizeByteTotal, inBufByteSize);
////        所有通道的加起来的采样点数，每个采样点是2个字节所以/2
//        inArg.numInSamples = (INT)step / 2; // TO-DO: 为什么除以2. numInSamples到底是什么
//        if (aacEncEncode(encoder, &inBufDescription, &outBufDescription, &inArg, &outArg) != AACENC_OK) {
//            puts("编码失败");
//        }
//    }
//}

- (void)start {
    [self setUpEncoder:self.config];
}

- (void)stop {
    free(outbuffer);
    aacEncClose(&encoder);
    encoder = NULL;
}

#pragma mark - Init

- (instancetype)initWithAudioConfig:(SSZAudioConfig *)config {
    self = [super init];
    
    if (self) {
        self.config = config;
        [self start];
    }
    
    return self;
}

#pragma mark - Private

- (void)setUpEncoder:(SSZAudioConfig *)config {
    
    // 初始化所有模块，2个声道
    if (aacEncOpen(&encoder, 0x0, (UINT)config.channel) != AACENC_OK) {
        puts("Failed to allocate aac soft encoder instance");
        return;
    }
    
    // 配置参数
    CHANNEL_MODE channelMode = [self getChannelMode:config.channel];
    if (channelMode == MODE_INVALID || channelMode == MODE_UNKNOWN) {
        puts("非法的channel mode");
        return;
    }
    if (aacEncoder_SetParam(encoder, AACENC_AOT, AOT_AAC_LC) != AACENC_OK) {
        puts("设置AACENC_AOT参数失败");
        return;
    }
    if (aacEncoder_SetParam(encoder, AACENC_BITRATE, (UINT)config.bitRate) != AACENC_OK) {
        puts("设置AACENC_BITRATE参数失败");
        return;
    }
    //TO-DO: CRB还是VBR？如果用VBR，设置的bitrate会被ignore
    if (aacEncoder_SetParam(encoder, AACENC_SAMPLERATE, config.sampleRate) != AACENC_OK) {
        puts("设置AACENC_SAMPLERATE参数失败");
        return;
    }
    if (aacEncoder_SetParam(encoder, AACENC_CHANNELMODE, channelMode) != AACENC_OK) {
        puts("设置AACENC_CHANNELMODE参数失败");
        return;
    }
//    if (aacEncoder_SetParam(encoder, AACENC_METADATA_MODE, 3) != AACENC_OK) {
//        puts("设置AACENC_METADATA_MODE参数失败");
//        // TO-DO: 如果失败，那么inputBuffer里面就不能有metadata了??
//    }
    // 设置编码出来的数据带aac adts头
    if (aacEncoder_SetParam(encoder, AACENC_TRANSMUX, TT_MP4_ADTS) != AACENC_OK) // 0-raw 2-adts
    {
        puts("设置AACENC_TRANSMUX为ADTS失败");
        return;
//        printf("设置AACENC_TRANSMUX为ADTS失败, ret = 0x%x, error is %s\n", ret, fdkaac_error(ret));
    }
    // TO-DO: 研究别的参数
    
    // initialize encoder with param
    if (aacEncEncode(encoder, NULL, NULL, NULL, NULL) != AACENC_OK) {
        puts("配置aac软编码器参数错误");
        return;
    }
}

- (CHANNEL_MODE)getChannelMode:(NSInteger)numChannels {
    CHANNEL_MODE channelMode = MODE_INVALID;
    
    switch (numChannels) {
        case 1:
            channelMode = MODE_1;
            break;
        case 2:
            channelMode = MODE_2;
            break;
        case 3:
            channelMode = MODE_1_2;
            break;
        case 4:
            channelMode = MODE_1_2_1;
            break;
        case 5:
            channelMode = MODE_1_2_2;
            break;
        case 6:
            channelMode = MODE_1_2_2_1;
            break;
        case 7:
            channelMode = MODE_6_1;
            break;
        case 8:
            channelMode = MODE_7_1_BACK;
            break;
        default:
            channelMode = MODE_INVALID;
            break;
    }
    
    return channelMode;
}

@end
