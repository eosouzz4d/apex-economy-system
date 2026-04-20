# AIFrame Architecture

## System Overview

AIFrame is structured as a modular AI engine composed of independent subsystems.

Each NPC is internally represented as a record containing isolated components.

## Core Components

### Perception
Handles:
- Vision detection
- Hearing system
- Alert updates

### Threat
- Tracks enemies
- Applies decay over time
- Determines current target

### Memory
Stores:
- Known enemies
- Last seen positions
- Danger zones
- Custom data

### Movement
- Pathfinding
- Navigation state
- Anti-stuck logic

### Combat
- Attack cycles
- Defensive actions
- Damage handling

### Tactical
- Decision layer
- Combat strategies

### Emotion
- Fear
- Rage
- Stress
- Morale

### Prediction
- Target movement estimation
- Accuracy tracking

## Execution Model

- NPCs are distributed into scheduler buckets
- Only part of them update per frame
- Reduces performance cost

## LOD System

- FULL: all systems active
- MEDIUM: reduced logic
- LOW: minimal updates
- SLEEP: inactive

## Design Principles

- Server authoritative
- Fully modular
- Scalable to large NPC counts
- Performance oriented
