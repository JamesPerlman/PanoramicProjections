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

typedef enum RSFType : NSUInteger {
    RSFTypeOctahedron,
    RSFTypeStereographic,
} RSFType;

@protocol MTLTexture, MTLBuffer, MTLComputeCommandEncoder, MTLComputePipelineState;

@interface RotatableSquareFilter : NSObject <MBETextureProvider, MBETextureConsumer>

@property (nonatomic, strong) MBEContext *context;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLComputePipelineState> pipeline;
@property (nonatomic, strong) id<MTLTexture> internalTexture;
@property (nonatomic, assign, getter=isDirty) BOOL dirty;
@property (nonatomic) float thetaOffset, phiOffset;

+ (instancetype)filterWithContext:(MBEContext*)context type:(RSFType)type;

- (instancetype)initWithFunctionName:(NSString *)functionName context:(MBEContext *)context;

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder;

@end

