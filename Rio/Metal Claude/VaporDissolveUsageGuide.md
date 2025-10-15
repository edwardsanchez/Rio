# Vapor Dissolve Effect - Usage Guide

## Installation

1. Add both files to your Xcode project:
   - `VaporDissolve.metal` - The Metal shader
   - `VaporDissolveEffect.swift` - The SwiftUI implementation

2. Make sure the Metal file is included in your app target

## Basic Usage

```swift
import SwiftUI

struct ContentView: View {
    @State private var isDissolving = false
    
    var body: some View {
        YourView()
            .vaporDissolve(
                isDissolving: isDissolving,
                duration: 2.0
            )
    }
}
```

## Parameters Explained

### Core Parameters

**particleSize** (2.0 - 20.0)
- Controls the diameter of each particle circle
- Smaller values create finer, more detailed dissolution
- Larger values create a more chunky, bubble-like effect

**particleSpeed** (0.1 - 3.0)
- Overall speed multiplier for particle movement
- Lower values create slow, peaceful dispersion
- Higher values create rapid, explosive effects

**particleLifetime** (0.5 - 3.0)
- How long each particle exists before fully fading
- Longer lifetimes create more lingering, smoke-like effects

**sizeRandomness** (0.0 - 1.0)
- Variation in particle sizes
- 0 = all particles same size
- 1 = maximum size variation

### Wind & Motion

**windDirection** (CGPoint)
- X and Y components of wind vector
- (1, 0) = wind blowing right
- (0, -1) = wind blowing up
- Can combine for diagonal wind

**windStrength** (0.0 - 3.0)
- How much wind affects particle movement
- 0 = no wind effect
- Higher values = stronger wind displacement

**turbulenceIntensity** (0.0 - 2.0)
- Steam-like swirls and eddies
- Creates organic, fluid motion
- Higher values = more chaotic movement

**spiralIntensity** (0.0 - 1.0)
- Circular/spiral motion of particles
- Adds rotational movement pattern
- Good for vortex or tornado effects

**gravityInfluence** (0.0 - 1.0)
- Downward pull on particles
- 0 = particles float freely
- 1 = particles fall like droplets

### Burst Configuration

**burstIntensity** (0.0 - 1.0)
- Initial explosive force from center
- 0 = gentle release
- 1 = strong explosion outward

**burstCenter** (CGPoint)
- Normalized position of burst origin
- (0.5, 0.5) = center of view
- (0, 0) = top-left corner
- (1, 1) = bottom-right corner

**dispersalRadius** (0.5 - 5.0)
- How far particles spread before fading
- Larger values = wider dispersion area

### Visual Properties

**fadeOutSpeed** (0.5 - 3.0)
- How quickly particles become transparent
- Lower = gradual fade
- Higher = quick disappearance

**rotationSpeed** (0.0 - 3.0)
- Spin rate of particles around their path
- Adds dynamic rotation to movement

**edgeSoftness** (0.0 - 1.0)
- Softness of particle circle edges
- 0 = hard edges
- 1 = very soft, cloud-like edges

**particleDensity** (0.5 - 2.0)
- Number of particles per unit area
- Lower = fewer, larger particles
- Higher = more, smaller particles

**temperatureVariation** (0.0 - 1.0)
- Simulates heat effects
- Adds upward thermal lift
- Slight warm color tinting

### Advanced

**noiseScale** (0.001 - 0.1)
- Scale of noise patterns
- Affects randomness distribution
- Lower = smoother patterns

## Preset Examples

### Soap Bubble Pop
```swift
VaporDissolveParameters(
    particleSize: 12,
    particleSpeed: 0.5,
    particleLifetime: 2.0,
    windStrength: 0.3,
    turbulenceIntensity: 0.5,
    burstIntensity: 0.3,
    gravityInfluence: 0.1,
    temperatureVariation: 0.2
)
```

### Steam Rising
```swift
VaporDissolveParameters(
    particleSize: 8,
    windDirection: CGPoint(x: 0, y: -1),
    windStrength: 0.5,
    turbulenceIntensity: 1.2,
    gravityInfluence: 0,
    temperatureVariation: 0.8,
    edgeSoftness: 0.9
)
```

### Explosive Burst
```swift
VaporDissolveParameters(
    particleSize: 6,
    particleSpeed: 2.0,
    burstIntensity: 1.0,
    spiralIntensity: 0.5,
    fadeOutSpeed: 2.0
)
```

### Gentle Mist
```swift
VaporDissolveParameters(
    particleSize: 15,
    particleSpeed: 0.3,
    particleLifetime: 3.0,
    turbulenceIntensity: 0.3,
    edgeSoftness: 1.0,
    fadeOutSpeed: 0.8
)
```

## Complete Example

```swift
import SwiftUI

struct ThoughtBubbleView: View {
    @State private var isDissolving = false
    @State private var showBubble = true
    
    // Custom parameters for thought bubble effect
    let thoughtBubbleParams = VaporDissolveParameters(
        particleSize: 10,
        particleSpeed: 0.8,
        particleLifetime: 2.0,
        sizeRandomness: 0.4,
        windDirection: CGPoint(x: 0.3, y: -0.5),
        windStrength: 0.6,
        turbulenceIntensity: 0.8,
        dispersalRadius: 2.5,
        fadeOutSpeed: 1.2,
        rotationSpeed: 0.5,
        gravityInfluence: 0.05,
        edgeSoftness: 0.9,
        particleDensity: 1.2,
        burstIntensity: 0.4,
        burstCenter: CGPoint(x: 0.5, y: 0.5),
        spiralIntensity: 0.2,
        temperatureVariation: 0.3
    )
    
    var body: some View {
        VStack {
            if showBubble {
                // Your thought bubble content
                ZStack {
                    Ellipse()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Text("💭 Thinking...")
                                .font(.title2)
                        )
                }
                .frame(width: 250, height: 150)
                .vaporDissolve(
                    isDissolving: isDissolving,
                    duration: 2.5,
                    parameters: thoughtBubbleParams,
                    onComplete: {
                        // Reset for next animation
                        showBubble = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showBubble = true
                            isDissolving = false
                        }
                    }
                )
            }
            
            Button("Pop Thought") {
                isDissolving = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDissolving || !showBubble)
            .padding(.top, 50)
        }
    }
}
```

## Performance Tips

1. **Particle Density**: Lower values improve performance with minimal visual impact
2. **Layer Effect Bounds**: The `maxSampleOffset` in the modifier may need adjustment for large dispersion effects
3. **Turbulence**: High turbulence with many particles can be GPU intensive

## Customization Ideas

1. **Directional Effects**: Use wind direction to make particles flow toward UI elements
2. **Reveal Effects**: Reverse the progress (1 to 0) to create a materialization effect
3. **Interactive**: Tie burst center to touch location for interactive dissolves
4. **Chained Effects**: Trigger multiple views with slight delays for cascading effects

## Troubleshooting

- **Particles cut off**: Increase `maxSampleOffset` in the layer effect
- **Too slow**: Reduce particle density or turbulence intensity
- **Not visible**: Check that progress is animating from 0 to 1
- **Too fast**: Increase duration or reduce particle speed

## Integration with Animations

```swift
// Combine with other animations
YourView()
    .scaleEffect(isDissolving ? 1.1 : 1.0)
    .vaporDissolve(isDissolving: isDissolving)
    .animation(.easeOut(duration: 0.3), value: isDissolving)
```

## State Management

```swift
// Use with view appearance/disappearance
struct DisappearingView: View {
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            ContentView()
                .vaporDissolve(
                    isDissolving: !isVisible,
                    onComplete: {
                        // View is now fully dissolved
                    }
                )
                .onTapGesture {
                    isVisible = false
                }
        }
    }
}
```
