//
//  EquirectToCubemapFilter.h
//  ImageProcessing
//
//  Created by James Perlman on 6/19/16.
//  Copyright © 2016 Metal By Example. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBETextureProvider.h"
#import "MBETextureConsumer.h"
#import "MBEContext.h"

@protocol MTLTexture, MTLBuffer, MTLComputeCommandEncoder, MTLComputePipelineState;

@interface EquirectToCubemapFilter : NSObject <MBETextureProvider, MBETextureConsumer>

@property (nonatomic, strong) MBEContext *context;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLComputePipelineState> pipeline;
@property (nonatomic, strong) id<MTLTexture> internalTexture;
@property (nonatomic, assign, getter=isDirty) BOOL dirty;

+ (instancetype)filterWithContext:(MBEContext*)context;

- (instancetype)initWithFunctionName:(NSString *)functionName context:(MBEContext *)context;

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder;

@end

