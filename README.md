# CDMx - Cooldown Manager Extended

**Enhance your cooldown tracking with hotkey displays and customizable bars!**

CDMx extends World of Warcraft's built-in Cooldown Manager by adding hotkey displays to all cooldown icons and providing powerful custom tracking bars for trinkets, consumables, and any spells/items you want to monitor.

## Features

### Hotkey Display on Cooldown Icons
- Automatically shows hotkeys on Blizzard's Essential and Utility cooldown bars
- Just-In-Time (JIT) lookup system - finds hotkeys when cooldowns appear
- Works with all major action bar addons (ElvUI, Bartender4, Dominos, Blizzard default)
- Configurable font size and position
- Separate font sizes for Essential vs Utility cooldowns

### Trinket Bar
- Dedicated bar for equipped trinkets (slots 13 & 14)
- Auto-detects trinket swaps
- Displays cooldowns, hotkeys, and proc indicators
- Draggable positioning
- Visibility options: Always / Combat Only / Out of Combat
- Masque support for custom styling

### Custom Tracking Bars
- Create unlimited custom bars for any spells/items
- Easy item picker - scan your action bars and check what you want
- Per-bar configuration:
  - Number of slots (1-12)
  - Icon size (20-80)
  - Padding between icons
  - Hotkey font size
  - Horizontal or vertical layout
  - Lock/unlock positioning
- Global style settings (square icons, borders) apply to all custom bars

### Polish & Compatibility
- ElvUI-style aesthetic with clean square icons and borders
- Masque support for skinning
- Proc glow when abilities come off cooldown
- All settings accessible via GUI (ESC → Interface → AddOns → CDMx)
- Extensive slash commands for power users

## Installation

### Via CurseForge Client
1. Install CurseForge app
2. Search for "CDMx"
3. Click Install

### Manual Installation
1. Download the latest release
2. Extract the `CDMx` folder
3. Place it in `World of Warcraft\_retail_\Interface\AddOns\`
4. Restart WoW or `/reload`

## Quick Start

1. Open settings: **ESC → Interface → AddOns → CDMx**
2. Configure hotkey display (font size, position)
3. Enable trinket bar if desired
4. Create custom bars:
   - Click "+ Add New Bar"
   - Name it (e.g., "Defensives", "Cooldowns")
   - Click "Edit Items" to pick spells/items
   - Adjust size, layout, etc.
   - Unlock to drag it into position
   - Lock when ready

## Slash Commands

### Main Commands
- `/cdmx config` - Open settings panel
- `/cdmx toggle` - Enable/disable addon
- `/cdmx debug` - Toggle debug mode

### Custom Bar Commands
- `/cdmx bar create <n>` - Create new bar
- `/cdmx bar list` - List all bars
- `/cdmx bar <n> delete` - Delete bar
- `/cdmx bar <n> lock/unlock` - Lock position
- `/cdmx bar <n> layout` - Toggle horizontal/vertical
- `/cdmx bar <n> slots <1-12>` - Set number of slots
- `/cdmx bar <n> size <20-80>` - Set icon size
- `/cdmx bar <n> font <8-24>` - Set font size

## Known Issues & Limitations

- **Cooldown Manager visibility**: Blizzard's Cooldown Manager must be enabled (it is by default)
- **Hotkey detection**: Only detects hotkeys for abilities on action bars
- **Custom bar items**: Requires `/reload` after changing the number of slots
- **Stance/form abilities**: Some class transformation abilities (Druid forms, Warrior stances) may need manual spell ID mapping

## Compatibility

### Tested With
- ✅ ElvUI
- ✅ Bartender4
- ✅ Dominos
- ✅ Blizzard default action bars
- ✅ Masque (for skinning)

### Requirements
- World of Warcraft: The War Within (11.0+) or Midnight (12.0+)
- No dependencies required
- Optional: Masque for custom skinning

## FAQ

**Q: Why aren't hotkeys showing on cooldowns?**
A: Make sure the abilities are actually on your action bars. The addon scans bars to find hotkeys - if an ability isn't bound or on a bar, no hotkey will show.

**Q: Can I track abilities not on my bars?**
A: Not currently. The hotkey system requires abilities to be on action bars to detect their keybinds.

**Q: Does this work with WeakAuras?**
A: CDMx is designed to enhance Blizzard's Cooldown Manager, not replace WeakAuras. They can run side-by-side.

**Q: My custom bar is empty!**
A: Click "Edit Items" on the bar, select spells/items from the picker, save, then `/reload`.

**Q: How do I make icons square like ElvUI?**
A: In Custom Bars settings, check "Square Icons" under Default Style.

## Support & Feedback

- **Issues/Bugs**: Open an issue on [GitHub](https://github.com/juicetheforce/CDMx/issues)
- **Feature Requests**: Also use GitHub issues
- **General Discussion**: CurseForge comments

## Credits

**Author**: Juicetheforce  
**Development**: Built with Claude AI assistance  
**Inspiration**: Cooldown Manager Centered, BetterCooldownManager

## License

This addon is provided as-is for personal use. Feel free to modify for your own use, but please don't redistribute modified versions without credit.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
