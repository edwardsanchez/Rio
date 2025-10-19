# Rio

A modern iOS chat application with advanced visual effects and unique message bubble animations.

## Overview

Rio is an experimental chat application built for iOS that showcases sophisticated UI animations and visual effects. The app features custom-designed message bubbles with multiple visual states, animated cursive handwriting for typing indicators, and Metal-powered particle effects.

## Requirements

- **iOS 26.0 or later**
- Xcode 17.0+
- Swift 5.9+

## Key Features

### Message Bubbles with Visual States
Rio implements three distinct bubble states for inbound messages:
- **Thinking**: Animated metaball effect with traveling circles around the bubble perimeter, indicating the user is composing a message
- **Talking**: Standard chat bubble appearance for delivered messages
- **Read**: Visual state indicating the message has been read

Outbound messages use a simpler appearance with theme-based colors.

### Animated Cursive Text
The typing indicator uses a sophisticated animated cursive handwriting system that simulates text being written in real-time:
- Custom cursive font rendering from SVG path data
- Sliding window animation that maintains a fixed left edge
- Path-length compensation for consistent visual speed
- Support for sequential text animations
- Dual tracking system to prevent visual jitter

### Content Type Support
Messages support various content types:
- Text and emoji
- Images (with full-screen preview)
- Colors
- Dates and date ranges
- Locations
- URLs with preview cards
- Measurements and ratings
- Code snippets
- Files

### Visual Effects
- **Bubble Animations**: Smooth transitions between thinking, talking, and read states
- **Particle Explosions**: Metal shader-based effects for state transitions
- **Metaball Effects**: Animated circles with blur effects for thinking bubbles
- **Parallax Scrolling**: Jelly-like cascading effect during message list scrolling
- **Custom Themes**: Multiple color themes for chat bubbles

## Project Structure

### Core Components

#### `/Rio/`
Main application source files:
- `RioApp.swift` - Application entry point
- `ContentView.swift` - Root view with navigation stack
- `ChatData.swift` - Observable data model managing chats and messages
- `Types.swift` - Core data structures (User, Chat, ChatTheme)

#### `/Rio/Message/`
Message-related views and components:
- `MessageBubbleView.swift` - Main bubble rendering
- `MessageContentView.swift` - Content type rendering
- `MessageTypes.swift` - Message and content type definitions
- `BubbleConfiguration.swift` - Centralized bubble animation configuration

#### `/Rio/Message/Bubble/`
Advanced bubble animation system:
- `BubbleView.swift` - Animated bubble shapes with state management
- `BubbleAnimationState.swift` - State machine for bubble transitions
- `CircleAnimationManager.swift` - Metaball circle animation logic
- `TransitionCoordinator.swift` - Coordinates complex state transitions
- `Explosion/` - Metal shaders and logic for particle effects
- `Tails/` - Custom tail views for different bubble states

#### `/Rio/Cursive Letter/`
Animated cursive text system:
- `AnimatedCursiveTextView.swift` - Main view with sophisticated animation logic
- `CursiveLetter.swift` - Individual letter shape definitions
- `PathXAnalyzer.swift` - Path analysis for coordinate transformations
- `svg/` - SVG glyph files for the cursive font

#### `/Rio/` (Views)
Chat interface views:
- `ChatListView.swift` - List of all chats
- `ChatDetailView.swift` - Individual chat conversation view
- `MessageListView.swift` - Scrollable message list with animations
- `ChatInputView.swift` - Message composition interface

### External Dependencies

#### SVGPath
Swift package for parsing and rendering SVG paths (used for cursive text).

## Architecture Notes

### State Management
- Uses SwiftUI's `@Observable` macro for reactive state management
- `ChatData` class manages all chat and message state
- `BubbleConfiguration` provides centralized configuration for animations

### Animation System
The bubble animation system uses a sophisticated state machine:
1. **Read → Thinking**: Smooth morph with expanding circles
2. **Thinking → Talking**: Transition with particle explosion effect
3. **Talking → Read**: Direct visual state change

Animation timing is coordinated through `BubbleConfiguration` to ensure text reveals sync with visual transitions.

### Cursive Text Implementation
The animated cursive text system uses several advanced techniques:
- **Dual Tracking System**: Separate tracking for visual position and offset calculations
- **Ratchet Mechanism**: Prevents backward movement to maintain fixed left edge
- **Path Analysis**: Uses `PathXAnalyzer` for precise measurements and coordinate transformations
- **Forward-Only Progression**: Ensures smooth animations without jitter
- **Variable Speed Support**: Can adjust speed based on path complexity

### Metal Shaders
Custom Metal shaders provide:
- Particle explosion effects during bubble transitions
- Metaball rendering for thinking bubbles
- Advanced blur and blending effects

## Development

### Building
```bash
xcodebuild -scheme Rio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Key Files for LLM Understanding

When working with this codebase, these files provide the most context:

1. **Data Models**: `Types.swift`, `MessageTypes.swift` - Understanding the core data structures
2. **State Management**: `ChatData.swift`, `BubbleConfiguration.swift` - How state flows through the app
3. **Bubble System**: `BubbleView.swift`, `BubbleAnimationState.swift` - Core animation logic
4. **Cursive Text**: `AnimatedCursiveTextView.swift` - Complex path-based animation system
5. **Message Rendering**: `MessageBubbleView.swift`, `MessageContentView.swift` - How content is displayed

### Bubble Metaball System

The thinking bubble uses a sophisticated circle packing algorithm:
- Circles are distributed along the rounded rectangle perimeter
- Each circle oscillates within constrained diameter bounds
- Zero-sum animation keeps total perimeter length constant
- Deterministic seeded RNG ensures stable animations

## Current Status

The project is in active development. See `TODO.md` for planned features and known issues.

### Known Limitations
- Dynamic type support limited to `.small` through `.large` sizes
- Some animation transitions need refinement
- Image full-screen viewing partially implemented

