# Changelog

All notable changes to CDMx will be documented in this file.

## [0.1.0] - 2026-02-08

### Initial Release

**Core Features**
- Hotkey display on Blizzard's Essential and Utility cooldown bars
- Just-In-Time (JIT) hotkey detection system
- Support for ElvUI, Bartender4, Dominos, and Blizzard action bars

**Trinket Bar**
- Dedicated tracking for equipped trinkets
- Auto-detection of trinket swaps
- Configurable visibility (Always/Combat/Out of Combat)
- Draggable positioning with lock/unlock
- Masque support

**Custom Tracking Bars**
- Create unlimited custom bars for any spells/items
- Item picker UI - scan action bars and select what to track
- Per-bar configuration:
  - Slots (1-12)
  - Icon size (20-80)
  - Padding (0-20)
  - Font size (8-24)
  - Horizontal/vertical layout
- Global style settings (square icons, borders)
- Full GUI configuration panel

**Configuration**
- Comprehensive settings panel (Interface → AddOns → CDMx)
- Separate font sizes for Essential vs Utility cooldowns
- Configurable hotkey positioning
- Proc glow effects
- Lock All Bars option for quick locking
- Slash commands for power users

**Polish**
- ElvUI-style aesthetic
- Masque skinning support
- Case-sensitive bar naming
- Universal lock/unlock toggle

**Known Issues**
- Custom bars require `/reload` after changing slot count
- Some class transformation abilities may need manual spell ID mapping
