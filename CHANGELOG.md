# Changelog

All notable changes to CDMx will be documented in this file.

## [1.0.6] - 2026-02-17

### Hotkey Display Fix

**Fixed: Numpad hotkey display**
- Numpad keys (Numpad1, Numpad2, etc.) now correctly shorten to N1, N2, N3, etc.
- Previous versions could display the full "NUMPAD1" text depending on how WoW returned the key name
- Hotkey formatting now normalizes key names to uppercase before processing, preventing any future casing issues

## [1.0.5] - 2026-02-17

### Macro Hotkey Support

**Fixed: Hotkeys now display for macro'd abilities on Blizzard's Cooldown Manager**
- Abilities placed on action bars via macros (e.g. `/cast [@mouseover] Lay on Hands`) now correctly show their hotkeys on Essential and Utility cooldown icons
- Uses Blizzard's `C_ActionBar.FindSpellActionButtons` API for robust resolution — WoW handles all macro parsing internally, so any macro format works (conditionals, mouseover, stopcasting, etc.)
- Works with both default Blizzard action bars and ElvUI
- Previous versions only detected spells placed directly on bars, missing any ability wrapped in a macro

**Improved: Diagnostic output**
- `/cdmxdump` now shows macro slots with resolution info and `FindSpellActionButtons` results for each CDM spell
- `/cdmxslot` shows `FindSpellActionButtons` data for easier debugging

## [1.0.4] - 2026-02-14

### Named Profile System

**New: Full profile management**
- All settings are now stored in named profiles (like ElvUI, WeakAuras, Details)
- Each character can use a different profile, or multiple characters can share one
- Create, copy, rename, delete, and reset profiles via config UI or slash commands
- Profile dropdown selector in the config panel for quick switching
- Character-to-profile assignments shown in config

**New: Centered bar layout**
- Bars now grow equally in both directions from their anchor point
- Keeps bars visually centered when abilities are added/removed or when switching specs
- Per-bar toggle in config (default: on) for both trinket bar and custom bars
- Works correctly with Edit Mode drag positioning

**Improved: Live item picker updates**
- Adding/removing items from custom bars now applies immediately on save
- No longer requires /reload after editing bar contents

**Migration: Automatic for existing users**
- Existing settings are automatically wrapped into a "Default" profile on first load
- No manual action required, all settings preserved

**Slash commands:**
- `/cdmx profile` - Show current profile
- `/cdmx profile list` - List all profiles with character assignments
- `/cdmx profile use <name>` - Switch to a profile
- `/cdmx profile create <name>` - Create new profile
- `/cdmx profile copy <source> <dest>` - Copy a profile
- `/cdmx profile delete <name>` - Delete a profile
- `/cdmx profile rename <old> <new>` - Rename a profile
- `/cdmx profile reset` - Reset current profile to defaults

## [1.0.3] - 2026-02-12

### Fixed Hotkey Detection for Default Blizzard Action Bars

**Fixed: Hotkeys not detected on secondary bars for non-ElvUI users**
- Replaced hardcoded slot→binding table with dynamic frame-based discovery
- The addon now queries actual button frames at runtime to determine which keybind maps to which action slot
- Works correctly for default Blizzard bars, ElvUI, and other bar addons
- Previous hardcoded mapping was based on ElvUI's slot assignments which differ from Blizzard's default layout

**Expanded action bar scan range**
- Increased slot scan from 120 to 180 to cover MultiBar5-8 which can use higher slot numbers on default bars

## [1.0.2] - 2026-02-11

### Automatic Talent Replacement Detection

**Fixed: Talent-replaced abilities missing hotkeys**
- Hotkey lookup now automatically detects talent replacements using `C_Spell.GetOverrideSpell()`
- Fixes Blessed Hammer (replaces Crusader Strike), and similar talent swaps across all classes
- No more need to manually hardcode every talent replacement per spec

## [1.0.1] - 2026-02-10

### Hotkey Detection Overhaul

**Fixed: Incorrect hotkeys on Paladin and other classes**
- Replaced unreliable `cooldownID` frame property with `GetBaseSpellID()` method call
- Blizzard's cooldown manager uses internal frame pool identifiers (`cooldownID`) that don't correspond to the actual displayed spell — `GetBaseSpellID()` returns the real spell
- This fix should improve hotkey accuracy across all classes, especially for self-buffs, PBAoE abilities, and talent-replaced spells

**Fixed: Hotkeys not showing for abilities on bars 2-10**
- `GetHotkeyForSlot()` now correctly maps slot numbers to their proper binding names (`MULTIACTIONBAR3BUTTON`, `MULTIACTIONBAR4BUTTON`, etc.)
- Previously only main action bar (slots 1-12) returned keybinds

**Improved: Spell override detection for talent replacements**
- Added `spellIDMap` entry for Templar's Verdict → Final Verdict (Paladin)
- Existing mappings retained for Void Metamorphosis and Vengeful Retreat (DH)

**Added: Enhanced diagnostic commands**
- `/cdmxdump` now shows identification method (GetBaseSpellID vs rangeCheck) and full resolution chain
- `/cdmxframes` probes all available methods on problem frames for debugging

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
