//
//  MyDecoder.hpp
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/15.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#ifndef MyDecoder_hpp
#define MyDecoder_hpp

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/samplefmt.h"
#include "libavutil/common.h"
#include "libavutil/channel_layout.h"
#include "libavutil/opt.h"
#include "libavutil/imgutils.h"
#include "libavutil/mathematics.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
};

class MyDecoder {
private:
    const char *inputFile;
    const char *outputFile;
    AVFormatContext *formatContext;
    AVPacket packet;
    AVFrame *frame;
    AVCodecContext *audioCodecContext;
    FILE *outputFileObject;
    int audioDataSize;
    int audioDataCursor;
    SwrContext *swrContext;
    void *swrBuffer;
    int swrBufferSize;
    int inDataNumChannels;
    
    short *decodedDataBuf;
    int sizeTotalDecoded;
    int sizeCopied;
    int sizeUncopied;
    int index;
    short *decodeData(int *size); // 返回解码的数据，size是数据的长度
    
    short *buffers[20];
public:
    int init(const char *inputFile,const char *outputFile);
    int outDataNumChannels();
    void readData(short *buffer, int size);
    int readData_returnLen(short *buffer, int size);
    void destroy();
    int getSampleRate();
    
    void preDecode10Buffers();
};

#endif /* MyDecoder_hpp */
