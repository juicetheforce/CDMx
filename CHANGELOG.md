# Changelog

All notable changes to CDMx will be documented in this file.

## [1.0.0] - 2026-02-08

### First Public Release

**Edit Mode Integration**
- CDMx bars now integrate with WoW's Edit Mode for positioning
- Green overlay movers appear on all bars when Edit Mode is open
- Drag to reposition, close Edit Mode to lock
- Removed old lock/unlock system in favor of Edit Mode

**Config Panel Overhaul**
- Completely rebuilt settings panel with custom-drawn widgets
- Dark/gold aesthetic matching modern addon style
- Collapsible sections (all collapsed by default)
- Custom sliders with click-to-set and mouse wheel support
- Stepper controls for cycling through options
- No Blizzard UI templates — fully custom widgets

**Shared UI Module**
- Centralized icon creation, styling, and layout across all bar types
- Consistent look and feel for trinket bar and custom bars
- Reduced code duplication by ~50%

**Improvements**
- Stack/charge count font reduced to prevent overlap with hotkeys
- Clearer setting labels ("Blizzard-style icons" instead of "Square icons")
- Deep merge for saved variables — new defaults apply without resetting user config
- Removed bar background and title labels (Edit Mode movers replace them)

**Bug Fixes**
- Fixed icon layout alignment for Edit Mode mover overlays
- Fixed duplicate file entry in TOC
- Fixed various saved variable inheritance issues

## [0.1.0] - 2026-02-07

### Internal Development Release

**Core Features**
- Hotkey display on Blizzard's Essential and Utility cooldown bars
- Just-In-Time (JIT) hotkey detection system
- Support for ElvUI, Bartender4, Dominos, and Blizzard action bars

**Trinket Bar**
- Dedicated tracking for equipped trinkets
- Auto-detection of trinket swaps
- Configurable visibility (Always/Combat/Out of Combat)
- Masque support

**Custom Tracking Bars**
- Unlimited custom bars for any spells/items
- Item picker UI — scan action bars and select what to track
- Per-bar configuration (slots, icon size, padding, font size, layout)
- Global style settings (square icons, borders)

**Configuration**
- GUI settings panel (Interface → AddOns → CDMx)
- Separate font sizes for Essential vs Utility cooldowns
- Configurable hotkey positioning
- Proc glow effects
- Slash commands for power users
