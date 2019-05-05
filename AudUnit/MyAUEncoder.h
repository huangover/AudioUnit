//
//  MyAUEncoder.h
//  AudUnit
//
//  Created by Sihang Huang on 4/22/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioConverter.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^ConvertCallback)(AudioBufferList *outData);

@protocol MyAUEncoderDataSource <NSObject>

- (UInt32)fillBuffer:(uint8_t *)buffer byteSize:(UInt32)size;

@end

@protocol MyAUEncoderDelegate <NSObject>

- (void)didConvertToAACData:(NSData *)data error: (NSError *)error;

@end

@interface MyAUEncoder : NSObject

@property (nonatomic, weak) id<MyAUEncoderDataSource>datasource;
@property (nonatomic, weak) id<MyAUEncoderDelegate>delegate;

- (instancetype)initWithBitRate:(UInt32)bitRate sampleRate:(UInt32)sampleRate numChannels:(NSInteger)numChannels;
- (void)encode;

@end

NS_ASSUME_NONNULL_END
