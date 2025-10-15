//
//  VaporParams.swift
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//


#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ---------- small noise toolkit ----------
inline float hash12(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

inline float2 hash22(float2 p) {
    float2 h = float2(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)));
    return fract(sin(h) * 43758.5453123);
}

inline float noise2d(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash12(i + float2(0,0));
    float b = hash12(i + float2(1,0));
    float c = hash12(i + float2(0,1));
    float d = hash12(i + float2(1,1));
    float2 u = f*f*(3.0 - 2.0*f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// approximate gradient of value noise
inline float2 noiseGrad(float2 p) {
    float e = 0.002;
    float n  = noise2d(p);
    float nx = noise2d(p + float2(e,0)) - n;
    float ny = noise2d(p + float2(0,e)) - n;
    return float2(nx, ny) / e;
}

// curl-like field from value-noise gradient
inline float2 curlField(float2 p) {
    float2 g = noiseGrad(p);
    float2 c = float2(-g.y, g.x);
    float l = max(length(c), 1e-4);
    return c / l; // unit curl direction
}

// ---------- uniforms ----------
struct VaporParams {
    float time;          // seconds
    float progress;      // 0..1 controls dissolve progression
    float cell;          // particle cell size in px
    float baseRadius;    // particle base radius in px
    float sizeJitter;    // 0..1 variation of radius
    float speed;         // px/sec along wind
    float life;          // 0..1 how much staggering of start
    float2 wind;         // normalized direction, magnitude modulated by speed
    float turbulence;    // 0..1 scale of curl field mixing
    float twirl;         // 0..1 extra local angular swirl
    float drag;          // 0..2 velocity damping over age
    float burst;         // px radial burst from center
    float feather;       // px soft edge on particles
    float seed;          // random seed
    float2 size;         // layer size in px
};

// Easing for a "pop and drift"
inline float easePop(float t) {
    // fast start, then smooth settle
    t = clamp(t, 0.0, 1.0);
    float a = pow(t, 0.35);
    return smoothstep(0.0, 1.0, a);
}

// Rotate a 2D vector by angle (radians)
inline float2 rotate2(float2 v, float ang) {
    float s = sin(ang), c = cos(ang);
    return float2(c*v.x - s*v.y, s*v.x + c*v.y);
}

// Main layer effect
[[ stitchable ]] half4 vaporizeLayer(float2 pos,
                                      SwiftUI::Layer layer,
                                      float time,
                                      float progress,
                                      float cell,
                                      float baseRadius,
                                      float sizeJitter,
                                      float speed,
                                      float life,
                                      float windX,
                                      float windY,
                                      float turbulence,
                                      float twirl,
                                      float drag,
                                      float burst,
                                      float feather,
                                      float seed,
                                      float sizeX,
                                      float sizeY) {
    float2 wind = float2(windX, windY);
    float2 sizePx = float2(sizeX, sizeY);         // view size in pixels
    float2 uv = pos / sizePx;                     // 0..1

    // grid cell for per-particle params
    float2 cellCoord = floor(pos / cell);
    float2 cellCenterPx = (cellCoord + 0.5) * cell;

    // jitter center in the cell so it does not look like a grid
    float2 jitter = (hash22(cellCoord + seed) - 0.5) * (cell * 0.8);
    cellCenterPx += jitter;

    // per-particle randomness
    float r1 = hash12(cellCoord + seed * 19.17);
    float r2 = hash12(cellCoord + seed * 53.91);

    // particle radius with jitter
    float radius0 = baseRadius * mix(1.0 - sizeJitter, 1.0 + sizeJitter, r1);

    // per-particle delayed start from life parameter
    // life near 1.0 means broader staggering
    float startOffset = r2 * life; // 0..life
    float t = clamp(progress - startOffset, 0.0, 1.0);

    // pop-like easing for displacement and shrink for vanish
    float pop = easePop(t);
    float shrink = 1.0 - t; // radius shrinks to zero by end

    // wind velocity in px/sec
    float2 windDir = normalize(wind + float2(1e-4, 0));
    float2 vWind = windDir * speed;

    // curl turbulence in screen space
    float curlScale = mix(0.0, 1.5, turbulence);
    float2 curl = curlField(uv * 6.0 + seed * 0.37 + time * 0.15) * (120.0 * curlScale);

    // twirl adds a small angle based on noise
    float ang = (noise2d(uv * 8.0 + seed * 2.1 + time * 0.2) - 0.5) * (3.14159 * twirl);
    float2 vField = vWind + rotate2(curl, ang);

    // radial burst from view center for "bubble pop"
    float2 toCenter = normalize(pos - sizePx * 0.5);
    float2 vBurst = toCenter * burst;

    // combine velocities, apply drag over age
    float dragK = 1.0 / (1.0 + drag * t);
    float2 totalDisp = (vField * pop + vBurst * pop) * dragK * (0.016); // scale to ~per-frame at 60 fps

    // accumulate displacement proportional to total progress
    // this makes the offset scale with the animation rather than time alone
    float2 dispPx = totalDisp * (progress * 60.0); // coarse scale for stronger travel

    // moved particle center
    float2 movedCenter = cellCenterPx + dispPx;

    // particle radius shrinks and gently feathers
    float radius = max(0.0, radius0 * shrink);
    float d = length(pos - movedCenter);
    float alphaMask = smoothstep(radius + feather, radius - feather, d);

    // sample the original layer from the inverse-warped position so the texture rides with the particle
    float2 samplePos = pos - dispPx;
    half4 src = layer.sample(samplePos);

    // fade out near the end in case any pixels remain due to numerical issues
    float endFade = smoothstep(0.9, 1.0, progress);
    half a = src.a * alphaMask * (1.0 - endFade);

    return half4(src.rgb * a, a);
}