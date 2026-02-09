# CDMx - Cooldown Manager Extended

**Enhance your cooldown tracking with hotkey displays and customizable bars.**

CDMx extends World of Warcraft's built-in Cooldown Manager by adding hotkey displays to all cooldown icons and providing custom tracking bars for trinkets, consumables, and any spells or items you want to monitor.

## Features

### Hotkey Display on Cooldown Icons
- Automatically shows hotkeys on Blizzard's Essential and Utility cooldown bars
- Just-In-Time (JIT) lookup system — finds hotkeys when cooldowns appear
- Works with all major action bar addons (ElvUI, Bartender4, Dominos, Blizzard default)
- Configurable font size, position, and outline
- Separate font sizes for Essential vs Utility cooldowns

### Trinket Bar
- Dedicated bar for equipped trinkets (slots 13 & 14)
- Auto-detects trinket swaps
- Displays cooldowns, hotkeys, and proc indicators
- Visibility options: Always / Combat Only / Out of Combat

### Custom Tracking Bars
- Create unlimited custom bars for any spells or items
- Easy item picker — scans your action bars so you can check what you want to track
- Per-bar settings: icon size, spacing, font size, horizontal/vertical layout, visibility
- Global style settings (Blizzard-style icons, borders) apply to all custom bars

### Edit Mode Integration
- Position all CDMx bars using WoW's built-in Edit Mode
- Green overlay movers appear on all bars when Edit Mode is open
- Drag to reposition, close Edit Mode to lock — just like Blizzard's own frames

### Configuration
- Full GUI settings panel (ESC → Interface → AddOns → CDMx)
- Dark collapsible sections with custom-drawn widgets
- No slash commands needed — everything is accessible from the settings panel
- Live preview for most settings (font sizes, spacing, layout)

## Installation

### Via CurseForge Client
1. Install the CurseForge app
2. Search for "CDMx"
3. Click Install

### Manual Installation
1. Download the latest release
2. Extract the `CDMx` folder
3. Place it in `World of Warcraft\_retail_\Interface\AddOns\`
4. Restart WoW or `/reload`

## Quick Start

1. **Hotkeys appear automatically** on Blizzard's cooldown bars — no setup needed
2. Open settings: **ESC → Interface → AddOns → CDMx**
3. Expand sections to configure font sizes, icon styles, etc.
4. To create a custom bar: expand **Custom Bars** → click **+ Add New Bar** → `/reload` → click **Edit Items** to pick spells/items
5. To reposition bars: open **Edit Mode** (ESC → Edit Mode) and drag the green CDMx movers

## Slash Commands

- `/cdmx config` — Open settings panel
- `/cdmx toggle` — Enable/disable addon
- `/cdmx version` — Show version info
- `/cdmx debug` — Toggle debug output

### Custom Bar Commands
- `/cdmx bar create <name>` — Create new bar
- `/cdmx bar list` — List all bars
- `/cdmx bar <name> delete` — Delete bar
- `/cdmx bar <name> layout` — Toggle horizontal/vertical
- `/cdmx bar <name> slots <1-12>` — Set number of slots
- `/cdmx bar <name> size <20-80>` — Set icon size
- `/cdmx bar <name> font <8-24>` — Set font size

## Known Limitations

- Custom bars require `/reload` after changing slot count or adding/removing items
- Hotkey detection requires abilities to be on your action bars
- Border and icon style changes require `/reload`
- No per-character profiles yet — settings are shared across characters

## Compatibility

- **Tested with**: ElvUI, Bartender4, Dominos, Blizzard default action bars
- **Optional**: Masque for custom icon skinning
- **Requires**: World of Warcraft: The War Within (11.0+) or Midnight (12.0+)
- **No dependencies required**

## FAQ

**Q: Why aren't hotkeys showing on my cooldowns?**
A: The ability must be on one of your action bars. CDMx scans bars to find keybinds — if an ability isn't on a bar, no hotkey will display.

**Q: Can I track abilities not on my bars?**
A: The item picker only shows spells and items currently on your action bars. This is by design since CDMx needs the action bar slot to detect hotkeys.

**Q: How do I move my bars?**
A: Open Edit Mode (ESC → Edit Mode). Green movers will appear over all CDMx bars. Drag them into position, then close Edit Mode.

**Q: Does this work with WeakAuras?**
A: Yes. CDMx enhances Blizzard's Cooldown Manager and runs independently of WeakAuras.

**Q: My custom bar is empty after adding items!**
A: Click "Edit Items", select your spells/items, click Save, then `/reload`.

## Support & Feedback

- **Bugs**: Open an issue on [GitHub](https://github.com/juicetheforce/CDMx/issues)
- **Feature Requests**: GitHub issues
- **General Discussion**: CurseForge comments

## Credits

**Author**: Juicetheforce
**Development**: Built with Claude AI assistance
**Inspiration**: Cooldown Manager Centered

## License

This addon is provided as-is for personal use. Feel free to modify for your own use, but please credit the original if you redistribute.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
