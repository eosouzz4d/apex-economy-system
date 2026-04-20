# AIFrame Engine

Advanced procedural AI engine for NPC behavior in Roblox.

## Overview

AIFrame is a high-level AI framework designed to simulate intelligent, adaptive NPCs using modular systems and layered decision-making.

This is not a simple AI script. It is a full behavioral engine.

## Core Systems

### State Machine
- 15+ dynamic states
- Context-aware transitions
- Goal overrides

### Perception System
- Vision (raycast-based)
- Hearing detection
- Damage awareness
- Alert levels

### Threat System
- Dynamic threat accumulation
- Distance-based decay
- Target prioritization
- Threat sharing

### Memory System
- Enemy tracking
- Danger zones
- Interest points
- Custom facts

### Pathfinding
- Cached navigation
- Anti-stuck recovery
- Dynamic obstacle handling

## Tactical AI

NPCs adapt using multiple strategies:
- Rush
- Flank
- Circle
- Kite
- Cover
- Hit and Run
- Retreat

## Combat System

- Attack cycles
- Reactive blocking
- Smart dodging
- Critical hits
- External engine support

## Abilities

- Cooldown-based system
- Priority-driven usage
- Conditional activation
- Custom callbacks

## Status Effects

- Burning, Frozen, Poisoned and others
- Stackable effects
- Cross interactions

## Emotion System

- Fear
- Rage
- Stress
- Morale

## Squad System

- Dynamic formations
- Tactical commands
- Leader reassignment

## Behavior Trees

Supports:
- Selector and Sequence
- Conditions
- Cooldowns
- Weighted randomness

## Performance

- LOD system
- Bucket scheduler
- Raycast budget control

## Serialization

- Full state save and load
- Replay system

## Architecture

Modular system using metatables with isolated components:
- perception
- combat
- movement
- memory
- tactical
- emotion
- prediction

## Example

    local AIFrame = require(path.to.module)

    AIFrame:RegisterNPC(npcModel, config)
    AIFrame:SetState(npcModel, "Chase")

## Philosophy

- Server authoritative
- Scalable by design
- Modular and maintainable

## Author

Matheus Souza
Roblox Systems Developer
