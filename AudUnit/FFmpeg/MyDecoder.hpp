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
public:
    int init(const char *inputFile,const char *outputFile);
    void decodePacket(uint8_t **buffer, int *size);
    void decode();
    void destroy();
};

#endif /* MyDecoder_hpp */
