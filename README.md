# Questie-Octo

A lightweight quest helper for Turtle WoW / OctoWoW, focused on clear quest, objective, map, minimap, and tracker information.

## Requirements

**ClassicAPI.dll is required and is not included with Questie-Octo.**

[Download the latest ClassicAPI release here.](https://github.com/brues-code/ClassicAPI/releases/latest)

## Installation

1. Download the latest Questie-Octo release.
2. Extract the `Questie-Octo` folder into your WoW `Interface/AddOns` folder.
3. Make sure the addon path ends like this:

   `Interface/AddOns/Questie-Octo/Questie-Octo.toc`

4. Install ClassicAPI separately using its release instructions.
5. Restart the game if it was already running.

## First Steps

### Open Questie-Octo settings

By default, Questie-Octo adds a yellow **!** settings button.

- **Left Click:** Open settings
- **Drag:** Move the button around the minimap when it is not managed by a button panel

To disable it, open **Other → Interface** and uncheck **Show Minimap Button**.

If your UI provides a minimap-button panel, such as pfUI's **Addon Buttons** panel, the enabled Questie-Octo button can appear there with your other addon buttons.

On supported game menus, including Blizzard, Shagu Tweaks, pfUI and DragonflightUI-Reforged, you may also see a **Questie Options** button in the Escape menu.

You can also open the settings with either slash command:

`/qo`

`/questieocto`

### Unlock and move the quest tracker

1. Open the settings.
2. Select the **Tracker** tab.
3. Uncheck **Lock Tracker**.
4. Left-click and drag the **top/header area of the tracker** to move it.
5. Re-enable **Lock Tracker** when you are happy with its position.

The tracker is transparent by default, so the draggable header can be easy to miss.

If the tracker gets moved somewhere inconvenient, use **Tracker → Reset Tracker Position**.

### Dark Theme

Questie-Octo uses its dark options theme by default.

To change it, open **Other → Interface** and toggle **Enable Dark Theme**. The theme only changes the Questie-Octo settings window.

### Show Minimap Button

**Changing this option requires `/reload`.** When disabled, Questie-Octo does not create the minimap-button frame at all; it is not merely hidden. This avoids issues with older Vanilla minimap-button collector addons.

The other settings access methods described above remain available when the minimap button is disabled.

### Track quests manually

Questie-Octo can automatically track accepted quests.

To manually track or untrack a quest, use **Shift + Left Click** on the quest in the Quest Log.

On the World Map or minimap, hold **Shift** while hovering a quest marker to see a compact tracker-style quest summary with the quest title, objectives, required amounts/current progress when known, and rewards. The tracker itself keeps its normal hover because its objective rows are already visible.

### Quest Browser

The **Quest Browser** button is available in the bottom-left corner of the Questie-Octo settings window. You can also open it with `/qo quests`.

### Quest Automation

Quest automation is optional and disabled by default. Open **Other → Quest Automation** to configure:

- **Auto Accept Quests**
- **Auto Turn In Quests**
- **Auto Accept Gray Quests**
- **Include Repeatable Quests**

Hold **Shift** while talking to an NPC to keep that conversation manual. Questie-Octo leaves multiple reward choices, money-cost turn-ins, and quest accept confirmations to the player.

## Useful Commands

- `/qo` or `/questieocto` — open or close Questie-Octo settings
- `/qo quests` — open the quest browser
- `/qo help` — show available Questie-Octo commands

## Notes

Questie-Octo requires ClassicAPI as an external dependency. `ClassicAPI.dll` is intentionally not bundled with the addon.
