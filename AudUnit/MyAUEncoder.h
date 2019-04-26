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

- (void)fillBuffer:(uint8_t *)buffer byteSize:(NSInteger)size;

@end

@protocol MyAUEncoderDelegate <NSObject>

- (void)didConvertToAACData:(NSData *)data;

@end



@interface MyAUEncoder : NSObject

@property (nonatomic, weak) id<MyAUEncoderDataSource>datasource;
@property (nonatomic, weak) id<MyAUEncoderDelegate>delegate;

- (instancetype)initWithBitRate:(UInt32)bitRate sampleRate:(UInt32)sampleRate numChannels:(NSInteger)numChannels;
- (void)encode:(AudioBufferList *)inData completion:(ConvertCallback)completion;
- (void)encode;

@end

NS_ASSUME_NONNULL_END
