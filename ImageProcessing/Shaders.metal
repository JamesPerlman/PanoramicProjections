//
//  Shaders.metal
//  ImageProcessing
//
//  Created by Warren Moore on 10/4/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#include <metal_stdlib>

#define M_PI_4  0.785398163397448
#define M_PI_2  1.570796326794896
#define M_3PI_4 2.356194490192345
#define M_PI    3.141592653589793
#define M_5PI_4 3.926990816987241
#define M_3PI_2 4.712388980384689
#define M_7PI_4 5.497787143782138
#define M_2PI   6.283185307179586

using namespace metal;
constexpr sampler s(filter::linear, address::repeat);
constant float2 sphereSpan = float2(2.0 * M_PI, M_PI);

struct AdjustSaturationUniforms
{
    float saturationFactor;
};

struct AxisOrientation
{
    int axis;
};

struct AxisRotations
{
    float4x4 x;
    float4x4 y;
    float4x4 z;
};

kernel void modulo_fun(texture2d<float, access::sample> inTexture [[texture(0)]],
                       texture2d<float, access::write> outTexture [[texture(1)]],
                       uint2 gid [[thread_position_in_grid]])

{
    float2 wh = static_cast<float2>(int2(outTexture.get_width(), outTexture.get_height()));
    float4 color = inTexture.sample(s, static_cast<float2>(gid) / wh);
    int3 c1 = static_cast<int3>(color.rgb * 255.0);
    int3 c2 = int3(255-c1.r, c1.g % 128, c1.b % 196);
    float4 c = float4(static_cast<float3>(c2.rgb) / 255.0, color.a);
    outTexture.write(c, gid);
}

kernel void equirect_to_cubeface(texture2d<float, access::sample> inTexture [[texture(0)]],
                                 texture2d<float, access::write> outTexture [[texture(1)]],
                                 constant AxisOrientation &uniforms [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]])
{
    float2 wh = float2(outTexture.get_width(), outTexture.get_height());
    float2 uv = static_cast<float2>(gid) / wh - 0.5; // normalized uv of outTexture (from -1 to 1)
    float2 xy; // sample location from big panorama (inTexture)
    switch(uniforms.axis) {
        case 0: { // x+
            xy = float2(atan(2 * uv.x),
                        M_PI_2 + uv.y / sqrt(pow(uv.x, 2) + 1));
        }
            break;
        case 1: { // y+
            xy = float2(M_PI_2 + atan(2 * uv.x),
                        M_PI_2 + uv.y / sqrt(pow(uv.x, 2) + 1));
        }
            break;
        case 2: { // x-
            xy = float2(M_PI_2 + atan(2 * uv.x),
                        M_PI   + uv.y / sqrt(pow(uv.x, 2) + 1));
        }
            break;
        case 3: { // y-
            xy = float2(M_3PI_2 + atan(2 * uv.x),
                        M_PI_2  + uv.y / sqrt(pow(uv.x, 2) + 1));
        }
        case 4: { // z+
            xy = float2(atan2(uv.y, uv.x),
                        atan(2 * length(uv)));
        }
            break;
        case 5: { // z-
            xy = float2(atan2(uv.y, uv.x),
                        M_PI - atan(2 * length(uv)));
        }
            break;
        default: break;
    };
    float4 color = inTexture.sample(s, xy / sphereSpan);
    outTexture.write(color, gid);
}

kernel void equirect_to_stereograph(texture2d<float, access::sample> inTexture [[texture(0)]],
                                    texture2d<float, access::write> outTexture [[texture(1)]],
                                    constant AxisRotations &uniforms [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]])
{
    float2 whf, gidf, uv, xy, j, p, S, coss, sins;
    float3 r;
    float4 color, r4, rotation;
    
    uint2 wh = static_cast<uint2>(int2(outTexture.get_width(), outTexture.get_height()));
    
    whf = static_cast<float2>(wh);
    gidf = static_cast<float2>(gid);
    
    xy = gidf / whf; // (spherical) uv location from outTexture (theta, phi)
    j = xy * 2 - 1;
    
    //color = float4(j, 1.0, 1.0);
    // polar coordinates of current point
    p = float2(length(j), atan2(j.y, j.x));
    
    if (p.x > 1) {
        
        color =  float4(0.0, 0.0, 0.0, 0.0);
    } else {
        
        /* polar -> spherical
         * r = phi
         * theta = theta
         */
        
        S = float2(p.y, p.x * M_PI);
        
        
        
        // r is the normalized cartesian vector pointing toward S
        coss = cos(S);
        sins = sin(S);
        r = float3(coss.x * sins.y, sins.x * sins.y, coss.y);
        
        // rotate p
        r4 = float4(r, 1.0);
        rotation = uniforms.z * uniforms.y * uniforms.x * r4;
        r = rotation.xyz;
        
        // back to spherical coordinates
        S = float2(atan2(r.y, r.x), acos(r.z/length(r)));
        
        
        
        // to uv (inTexture)
        uv = S / sphereSpan;
        color =  inTexture.sample(s, uv);
    }
    outTexture.write(color, gid);
    
}

kernel void equirect_to_octahedron(texture2d<float, access::sample> inTexture [[texture(0)]],
                                   texture2d<float, access::write> outTexture [[texture(1)]],
                                   constant AxisRotations &uniforms [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]])
{
    
    float2 whf, gidf, xy, j, n, r, cosn, sinn, uv;
    float3 p, l;
    float4 color, l4, rotation;
    
    bool reflected = false;
    
    uint2 wh = static_cast<uint2>(int2(outTexture.get_width(), outTexture.get_height()));
    
    whf = static_cast<float2>(wh);
    gidf = static_cast<float2>(gid);
    xy = gidf / whf; // uv location from outTexture
    
    // split into 8 quadrants
    if (gid.x < wh.x / 2) { // left half of image
        if (gid.y < wh.y / 2) { // bottom left corner
            n.x = M_5PI_4;
            if (gid.y < wh.y / 2 - gid.x) { // outer half
                n.y = M_3PI_4;
                reflected = true;
                //c = float4(0, 0, 1, 1);
            } else { // inner half
                n.y = M_PI_4;
                //c = float4(0, 1, 0, 1);
            }
        } else { // top left corner
            n.x = M_3PI_4;
            if (gid.y > wh.y / 2 + gid.x) { // outer half
                n.y = M_3PI_4;
                reflected = true;
                //c = float4(1, 0, 0, 1);
            } else { // inner half
                n.y = M_PI_4;
                //c = float4(0, 1, 1, 1);
            }
        }
    } else { // right half of image
        if (gid.y < wh.y / 2) { // bottom right corner
            n.x = M_7PI_4;
            if (gid.y < gid.x - wh.y / 2) { // outer half
                n.y = M_3PI_4;
                reflected = true;
                //c = float4(1, 0, 1, 1);
            } else { // inner half
                n.y = M_PI_4;
                //c = float4(1, 1, 0, 1);
            }
        } else { // top right corner
            n.x = M_PI_4;
            if (gid.y > 3 * wh.y / 2  - gid.x) { // outer half
                n.y = M_3PI_4;
                reflected = true;
                //c = float4(1, 1, 1, 1);
            } else { // inner half
                n.y = M_PI_4;
                //c = float4(0, 0, 0, 1);
            }
        }
    }
    
    j = xy * 2 - 1;
    
    // x = theta, y = phi
    // n is the normal vector (in spherical radians) of projection plane
    cosn = cos(n);
    sinn = sin(n);
    
    // p is normal to the projection plane in 3D cartesian coordinates
    p = float3(cosn.x * sinn.y, sinn.x * sinn.y, cosn.y);
    
    // reflect j if necessary
    float b = (fabs(p.x) + fabs(p.y)) / 2.0;
    
    if (reflected) {
        float a, c, d;
        a = -p.x / p.y; // slope of line to reflect about
        c = b / p.y; // y-intercept of line
        
        d = (j.x + (j.y - c) * a) / (1 + pow(a,2));
        
        // reflect
        j.x = 2.0*d - j.x;
        j.y = 2.0*d*a - j.y + 2.0*c;
    }
    
    // add z-component to project onto the plane
    l = normalize(float3(j, (b-(j.x * p.x + j.y * p.y))/p.z));
    
    // rotate l
    l4 = float4(l, 1.0);
    
    rotation = uniforms.z * uniforms.y * uniforms.x * l4;
    
    l = rotation.xyz;
    
    // line in spherical radians (x = theta, y = phi)
    r = float2(atan2(l.y, l.x), acos(l.z/*/length(l)*/));
    
    uv = float2(1 - r.x / sphereSpan.x, r.y / sphereSpan.y);
    
    color =  inTexture.sample(s, uv);
    outTexture.write(color, gid);
    
}



kernel void equirect_to_cubemap(texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                uint2 gid [[thread_position_in_grid]])
{
    
    uint2 wh = static_cast<uint2>(int2(outTexture.get_width(), outTexture.get_height()));
    float2 whf = static_cast<float2>(wh);
    float2 gidf = static_cast<float2>(gid);
    float2 uv; // to be: normalized uv of outTexture subsquare (from -1 to 1)
    float2 xy; // sample location from big panorama (inTexture)
    if (gid.y < wh.y / 2) {
        uv.y = 4.0 * (0.25 - gidf.y / whf.y);
        if (gid.x < wh.x * 0.25) { // x+
            
            uv.x = 2 * (gidf.x / (whf.x * 0.25)) - 1;
            
            xy = float2(atan(uv.x),
                        atan2(sqrt(pow(uv.x, 2) + 1), uv.y));
            
        } else if (gid.x < wh.x * 0.5) { // y+
            
            uv.x = 2 * (gidf.x / (whf.x * 0.25) - 1) - 1;
            
            xy = float2(M_PI_2 + atan(uv.x),
                        atan2(sqrt(pow(uv.x, 2) + 1), uv.y));
            
        } else if (gid.x < wh.x * 0.75) { // x-
            
            uv.x = 2 * (gidf.x / (whf.x * 0.25) - 2) - 1;
            
            xy = float2(M_PI   + atan(uv.x),
                        atan2(sqrt(pow(uv.x, 2) + 1), uv.y));
            
        } else { // y-
            uv.x = 2 * (gidf.x / (whf.x * 0.25) - 3) - 1;
            xy = float2(M_3PI_2 + atan(uv.x),
                        atan2(sqrt(pow(uv.x, 2) + 1), uv.y));
        }
    } else {
        uv.y = -(4.0 * (gidf.y / whf.y - 0.75));
        if (gid.x < wh.x / 4) { // z+
            uv.x = 1 - 2 * (gidf.x / (whf.x * 0.25));
            xy = float2(atan2(-uv.y, uv.x),
                        atan(length(uv)));
        } else if (gid.x < wh.x / 2) { // z-
            uv.x = 1 - 2 * (gidf.x / (whf.x * 0.25) - 1);
            xy = float2(atan2(uv.y, uv.x),
                        M_PI - atan(length(uv)));
        }
    }
    float4 color =  inTexture.sample(s, xy / sphereSpan);
    outTexture.write(color, gid);
}

/*
 kernel void octahedron_to_equirect(texture2d<float, access::sample> inTexture [[texture(0)]],
 texture2d<float, access::write> outTexture [[texture(1)]],
 uint2 gid [[thread_position_in_grid]])
 {
 
 float2 whf, gidf, xy, n, r, cosn, sinn, cosl, sinl, uv, j;
 float3 p, l, o;
 bool reflected = false;
 
 uint2 wh = static_cast<uint2>(int2(outTexture.get_width(), outTexture.get_height()));
 
 whf = static_cast<float2>(wh);
 gidf = static_cast<float2>(gid);
 xy = gidf / whf; // uv location from outTexture
 
 r = xy * float2(M_2PI, M_PI); // sample location of inTexture in radians
 
 if (r.x >= 0 && r.x < M_PI_2) { // Q1: x+, y+
 n.x = M_PI_4;
 } else if (r.x >= M_PI_2 && r.x < M_PI) { // Q2: x+, y-
 n.x = M_3PI_4;
 } else if (r.x >= M_PI && r.x < M_3PI_2) { // Q3: x-, y-
 n.x = M_5PI_4;
 } else if (r.x >= M_3PI_2) { // Q4: x-, y+
 n.x = M_7PI_4;
 }
 
 if (r.y >= 0 && r.y < M_PI_2) { // "top" half of octahedron (z+)
 n.y = M_PI_4;
 } else { // bottom half of octahedron (z-)
 n.y = M_3PI_4;
 reflected = true;
 }
 
 // x = theta, y = phi
 // n is the normal vector (in spherical radians) of projection plane
 
 cosn = cos(n);
 sinn = sin(n);
 
 // p is normal to the projection plane in 3D cartesian coordinates
 p = float3(cosn.x * cosn.y, sinn.x * sinn.y, cosn.y);
 
 cosl = cos(xy);
 sinl = sin(xy);
 
 // l is tangent to the current line of projection
 l = float3(cosl.x * sinl.y, sinl.x * sinl.y, cosl.y);
 
 // projected point on plane in 3D space
 o = l/(dot(p,l));
 
 // collapse this point onto the xy plane by removing the z-coord
 j = o.xy;
 
 // reflect if necessary
 if (reflected) {
 float m = -p.x / p.y; // slope of line to reflect about
 float b = 1.0 / p.y;
 
 float d = (j.x + (j.y - b)*m)/(1 + pow(m,2));
 
 j.x = 2.0*d - j.x;
 j.y = 2.0*d*m - j.y + 2.0*b;
 }
 
 // normalize the point from [-1, 1] to [0, 1]
 uv = 0.5 * j + 0.5;
 
 //...??
 float4 color =  inTexture.sample(s, uv);
 outTexture.write(c, gid);
 
 }*/