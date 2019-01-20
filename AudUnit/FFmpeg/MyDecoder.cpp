//
//  MyDecoder.cpp
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/15.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#include "MyDecoder.hpp"

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
    
    // 这里sample有检查是否需要resample, 如果我们需要的样本格式跟input file的样本格式不一样的话
    if (audioCodecContext->sample_fmt != AV_SAMPLE_FMT_S16) {
       
        swrContext = swr_alloc_set_opts(NULL, av_get_default_channel_layout(2), AV_SAMPLE_FMT_S16, audioCodecContext->sample_rate,
                                        av_get_default_channel_layout(audioCodecContext->channels), audioCodecContext->sample_fmt, audioCodecContext->sample_rate, 0, NULL);
        if (!swrContext || swr_init(swrContext)) {
            if (swrContext)
                swr_free(&swrContext);
            avcodec_close(audioCodecContext);
            return -1;
        }
    }
    
    return 1;
}

void MyDecoder::decodePacket(uint8_t **buffer, int *size) {
    av_init_packet(&packet); // 需要先init
    frame = avcodec_alloc_frame();
    
    // 开始读frame
    while (av_read_frame(formatContext, &packet) == 0) {
        //解码
        int gotFrame = 0;
        
        if (avcodec_decode_audio4(audioCodecContext, frame, &gotFrame, &packet) < 0) {
            continue;
        }
        
        if (gotFrame == 0) {
            continue;
        }
        
        void *audioData = frame->data[0];
        int numSamples = frame->nb_samples;
        int numChannels = 2;
        int dataSize = numSamples * numChannels;
        
        *buffer = new uint8_t[dataSize];
        memcpy(*buffer, audioData, dataSize);
        break;
    }
    
    av_free_packet(&packet);
}

void MyDecoder::decode() {
    uint8_t *buffer = new uint8_t[1];
    int size = -1;
    frame = avcodec_alloc_frame();
    static int count = 0;
    while(size != 0 && buffer != NULL) {
        size = 0;
        buffer = NULL;
        
        av_init_packet(&packet); // 需要先init
    
        // 开始读frame
        while (av_read_frame(formatContext, &packet) >= 0) { //改动1 >= 0
            printf("actual read");
            //解码
            int gotFrame = 0;
            
            if (avcodec_decode_audio4(audioCodecContext, frame, &gotFrame, &packet) < 0) {
                continue;
            }
            
            if (gotFrame == 0) {
                continue;
            }
            
            void *audioData;// = frame->data[0];
            int numSamples = 0;// = frame->nb_samples;
            int numChannels = 2;
            
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
            }
            
            size = numSamples * numChannels;
            buffer = new uint8_t[size];
            memcpy(buffer, audioData, size);
            
            break;
        }
        
        av_free_packet(&packet);
        
        fwrite(buffer, sizeof(uint8_t), size, outputFileObject);
        count++;
        printf("read frame count %d", count);
    }
    
    printf("output file ended");
}

void MyDecoder::destroy() {
    
}
