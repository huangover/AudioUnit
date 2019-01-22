//
//  MyDecoder.cpp
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/15.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#include "MyDecoder.hpp"

#define OUT_DATA_CHANNELS 2

int MyDecoder::init(const char *inputFile, const char *outputFile) {
    this->inputFile = inputFile;
    this->outputFile = outputFile;
    
    outputFileObject = fopen(outputFile, "wb+");
    avcodec_register_all();
    av_register_all();
    formatContext = avformat_alloc_context();
    
    int result = avformat_open_input(&formatContext, inputFile, NULL, NULL);
    
    if (result != 0) {
        char *errorMsg = new char[200];
        av_strerror(result, errorMsg, 200);
        return -1;
    }
    
    result = avformat_find_stream_info(formatContext, NULL);
    
    if (result < 0) {
        return -1;
    }
    
    int streamIndex = av_find_best_stream(formatContext,
                                          AVMEDIA_TYPE_AUDIO,
                                          -1,// sample传-1而不是formatContext->nb_streams
                                          -1,
                                          &formatContext->audio_codec,//没必要传，因为formatContext->audio_codec赋值之后没用过
                                          0);
    
    if (streamIndex < 0 || formatContext->audio_codec == NULL) {
        return -1;
    }// sample只检查 result == -1 -> no audio stream, av_find_best_stream返回的是audio stream的index
    
    // 找到要的流
    AVStream *stream = formatContext->streams[streamIndex];
    audioCodecContext = stream->codec;
    
    // 找到流的解码器
    AVCodec *codec = avcodec_find_decoder(stream->codec->codec_id);
    
    
    if (codec == NULL) {
        return -1;
    }
    // 打开解码器
    result = avcodec_open2(stream->codec, codec, NULL);
    
    if (result != 0) {
        return -1;
    }
    
    // 检查是否需要resample, 有可能我们需要的数据格式跟input file的数据格式不一样。如果需要重新采样，初始化一个重采样context
    if (audioCodecContext->sample_fmt != AV_SAMPLE_FMT_S16) {
       
        swrContext = swr_alloc_set_opts(NULL,
                                        av_get_default_channel_layout(2),
                                        AV_SAMPLE_FMT_S16, audioCodecContext->sample_rate,
                                        av_get_default_channel_layout(audioCodecContext->channels),
                                        audioCodecContext->sample_fmt,
                                        audioCodecContext->sample_rate,
                                        0,
                                        NULL);
        if (!swrContext || swr_init(swrContext)) {
            if (swrContext)
                swr_free(&swrContext);
            avcodec_close(audioCodecContext);
            return -1;
        }
    }
    
    frame = avcodec_alloc_frame();
    
    return 1;
}

int MyDecoder::outDataNumChannels() {
    if (swrContext) {
        return OUT_DATA_CHANNELS;
    } else {
        return audioCodecContext->channels;
    }
}

void MyDecoder::readData(short *buffer, int size) {
    
    if (size <= (sizeTotalDecoded - index)) {
        memcpy(buffer, decodedDataBuf + index, size);
        index += size;
        
//        if (index >= sizeTotalDecoded) {
//            decodedDataBuf = decodeData(&sizeTotalDecoded);
//            index = 0;
//        }
    } else {
        memcpy(buffer, decodedDataBuf + index, sizeTotalDecoded - index);
        decodedDataBuf = decodeData(&sizeTotalDecoded);
        index = 0;
        
    }
//    memcpy(buffer, decodedDataBuf, )
    
    if (size > sizeUncopied) {

        memcpy(buffer, decodedDataBuf + (sizeTotalDecoded - sizeUncopied), sizeUncopied);
        
        decodedDataBuf = decodeData(&sizeTotalDecoded);
        
        if (sizeTotalDecoded != 0) {
            
            if (size-sizeUncopied > sizeTotalDecoded) {
                memcpy(buffer + sizeUncopied, decodedDataBuf, sizeTotalDecoded);
                sizeUncopied = 0;
            } else {
                memcpy(buffer + sizeUncopied, decodedDataBuf, size-sizeUncopied);
                sizeUncopied = sizeTotalDecoded - (size-sizeUncopied);
            }
        }
    } else {
        memcpy(buffer, decodedDataBuf, size);
        sizeUncopied -= size;
    }
}

short * MyDecoder::decodeData(int *size) {
    av_init_packet(&packet);
    void *audioData = NULL;
    *size = 0;

    // 读取PCM数据或者ADPCM数据->1个packet有多个frame; 其他数据，1个packet只有1个frame(视频或者其他类型音频数据)
    while(av_read_frame(formatContext, &packet) == 0) {
        int gotFrame = 0;
        int numBytesDecoded = avcodec_decode_audio4(audioCodecContext, frame, &gotFrame, &packet);
        
        if (numBytesDecoded < 0) {
            printf("error occurred: avcodec_decode_audio4");
            break;
        }
        
        if (gotFrame == 0) {
            continue;
        }
        
        int numSamples = 0;
        int numChannels = OUT_DATA_CHANNELS;
        
        if (swrContext) {
            const int ratio = 2;
            const int bufSize = av_samples_get_buffer_size(NULL,
                                                           numChannels,
                                                           frame->nb_samples * ratio,
                                                           AV_SAMPLE_FMT_S16,
                                                           1);
            if (!swrBuffer || swrBufferSize < bufSize) {
                swrBufferSize = bufSize;
                swrBuffer = realloc(swrBuffer, swrBufferSize);
            }
            
            uint8_t *outbuf[2] = { (uint8_t*) swrBuffer, NULL };
            numSamples = swr_convert(swrContext,
                                     outbuf,
                                     frame->nb_samples * ratio,
                                     (const uint8_t **) frame->data,
                                     frame->nb_samples);
            if (numSamples < 0) {
                break;
            }
            audioData = swrBuffer;
        } else {
            if (audioCodecContext->sample_fmt != AV_SAMPLE_FMT_S16) {
                break;
            }
            audioData = frame->data[0];
            numSamples = frame->nb_samples;
        }
        
        *size = numSamples * numChannels;
    }
    
    av_free_packet(&packet);
    
    return (short *)audioData;
}

void MyDecoder::destroy() {
    
}
