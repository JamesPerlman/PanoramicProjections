//
//  EquirectToCubemapFilter.m
//  ImageProcessing
//
//  Created by James Perlman on 6/19/16.
//  Copyright © 2016 Metal By Example. All rights reserved.
//

#import "RotatableSquareFilter.h"
#import "MBEContext.h"
#import <Metal/Metal.h>
#import <GLKit/GLKit.h>

@interface RotatableSquareFilter ()
@property (nonatomic, strong) id<MTLFunction> kernelFunction;
@property (nonatomic, strong) id<MTLTexture> texture;
@end

@implementation RotatableSquareFilter

@synthesize dirty=_dirty;
@synthesize provider=_provider;

struct AxisRotations {
    GLKMatrix4 x;
    GLKMatrix4 y;
    GLKMatrix4 z;
};

+ (instancetype)filterWithContext:(MBEContext*)context type:(RSFType)type
{
    NSString *filterName = @"";
    if (type == RSFTypeOctahedron) {
       filterName = @"equirect_to_octahedron";
    } else if (type == RSFTypeStereographic) {
        filterName = @"equirect_to_stereograph";
    }
    
    return [[self alloc] initWithFunctionName:filterName context:context];
}

- (instancetype)initWithFunctionName:(NSString *)functionName context:(MBEContext *)context;
{
    if ((self = [super init]))
    {
        NSError *error = nil;
        _context = context;
        _kernelFunction = [_context.library newFunctionWithName:functionName];
        _pipeline = [_context.device newComputePipelineStateWithFunction:_kernelFunction error:&error];
        if (!_pipeline)
        {
            NSLog(@"Error occurred when building compute pipeline for function %@", functionName);
            return nil;
        }
        _dirty = YES;
    }
    
    return self;
}

- (void)configureArgumentTableWithCommandEncoder:(id<MTLComputeCommandEncoder>)commandEncoder
{
    struct AxisRotations uniforms;
    uniforms.x = GLKMatrix4MakeXRotation(self.phiOffset);
    uniforms.y = GLKMatrix4Identity;
    uniforms.z = GLKMatrix4MakeZRotation(self.thetaOffset);
    
    if (!self.uniformBuffer)
    {
        self.uniformBuffer = [self.context.device newBufferWithLength:sizeof(uniforms)
                                                              options:MTLResourceOptionCPUCacheModeDefault];
    }
    
    memcpy([self.uniformBuffer contents], &uniforms, sizeof(uniforms));
    
    [commandEncoder setBuffer:self.uniformBuffer offset:0 atIndex:0];
 
}

- (void)applyFilter
{
    id<MTLTexture> inputTexture = self.provider.texture;
    
    if (!self.internalTexture/* ||
                              [self.internalTexture width] != [inputTexture width] ||
                              [self.internalTexture height] != [inputTexture height]*/)
    {
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:[inputTexture pixelFormat]
                                                                                                     width:1024
                                                                                                    height:1024
                                                                                                 mipmapped:NO];
        self.internalTexture = [self.context.device newTextureWithDescriptor:textureDescriptor];
    }
    
    MTLSize threadgroupCounts = MTLSizeMake(8, 8, 1);
    MTLSize threadgroups = MTLSizeMake([self.internalTexture width] / threadgroupCounts.width,
                                       [self.internalTexture height] / threadgroupCounts.height,
                                       1);
    
    id<MTLCommandBuffer> commandBuffer = [self.context.commandQueue commandBuffer];
    
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:self.pipeline];
    [commandEncoder setTexture:inputTexture atIndex:0];
    [commandEncoder setTexture:self.internalTexture atIndex:1];
    [self configureArgumentTableWithCommandEncoder:commandEncoder];
    [commandEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadgroupCounts];
    [commandEncoder endEncoding];
    
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (id<MTLTexture>)texture
{
    if (self.isDirty)
    {
        [self applyFilter];
    }
    
    return self.internalTexture;
}

@end
