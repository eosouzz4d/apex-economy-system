# AIFrame Engine

Advanced procedural AI engine for NPC behavior in Roblox.

---

## Overview

AIFrame is a high-level AI framework designed to simulate intelligent, adaptive NPCs through modular systems and layered decision-making.

This is not a simple pathfinding script — it is a full behavioral engine.

---

## Core Systems

### State Machine
- 15+ dynamic states
- Context-aware transitions
- Override via goals and behavior trees

### Perception System
- Vision (raycast-based)
- Hearing system
- Damage awareness
- Alert levels

### Threat System
- Dynamic threat accumulation
- Distance-based decay
- Target prioritization
- Threat sharing between NPCs

### Memory System
- Enemy tracking
- Danger zones
- Interest points
- Custom facts API

### Pathfinding
- Cached navigation
- Anti-stuck recovery
- Dynamic obstacle handling

---

## Tactical AI

NPCs adapt using tactical modes:

- Rush
- Flank
- Circle
- Kite
- Cover
- Hit & Run
- Retreat

---

## Combat System

- Attack cycles with cooldowns
- Reactive blocking
- Smart dodging
- Critical hits
- External combat engine support

---

## Abilities

- Cooldown-based system
- Priority-driven usage
- Conditional activation
- Custom callbacks

---

## Status Effects

Supports advanced interactions:

- Burning / Wet / Frozen synergy
- Poison & Bleed stacking
- Crowd control effects
- Buffs and debuffs

---

## Emotion System

Dynamic behavior influenced by:

- Fear
- Rage
- Stress
- Morale

---

## Squad System

- Dynamic formations
- Command hierarchy
- Tactical orders
- Auto leader reassignment

---

## Behavior Trees

Supports:

- Selector / Sequence
- Conditions
- Cooldowns
- Random weighted logic

---

## Performance

- LOD system (Full / Medium / Low / Sleep)
- Bucket scheduler
- Raycast budgeting

---

## Serialization

- Full state export/import
- Replay system
- Persistent AI state

---

## Architecture

Built using modular OOP (metatables), with isolated subsystems:

- perception
- combat
- movement
- memory
- tactical
- emotion
- prediction

---

## Usage

```lua
local AIFrame = require(path.to.module)

AIFrame:RegisterNPC(npcModel, config)
AIFrame:SetState(npcModel, "Chase")
