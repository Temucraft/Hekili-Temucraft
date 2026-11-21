# Hekili (Temucraft)

The Hekili priority helper for the World of Warcraft 3.3.5a client, made for the Temucraft server. It shows the
next abilities to use for your class, based on SimulationCraft-style action lists, and updates as you play.

This is a port of [Hekili](https://github.com/Hekili/hekili) by Hekili and its contributors, from the `wrath`
branch (release **v3.4.3-1.0.7**, commit `2ef2a44`), the version made for Wrath Classic. Wrath Classic has the
same classes, talents and spell ids as 3.3.5, so its class files and action lists are used as they are. All
credit for Hekili goes to its authors. The upstream readme is in `Hekili/README.md`. The upstream repository has
no license file; this port keeps the original authors, history notes and credits, and is shared as a fork for the
3.3.5 community.

The addon is in the `Hekili` folder (the folder name keeps the saved variables `HekiliDB` working). It needs
**!TemucraftCompat**.

## What changed for 3.3.5

The first commit is the upstream branch as downloaded. Changes in the Lua files have a `Temucraft:` comment.

- **TOC**: Interface 30300, title "Hekili (Temucraft)", depends on !TemucraftCompat. The packager files and the
  `.github` folder were removed.
- **Libraries**: the upstream copy gets its libraries from the packager. This copy carries versions that work on
  3.3.5: Ace3, LibSharedMedia, LibCompress, LibDeflate, LibDBIcon, LibTranslit from the Temucraft Plater port;
  LibSpellRange, LibRangeCheck and LibCustomGlow from the 3.3.5 WeakAuras; the SharedMedia widgets and LibDualSpec
  from 3.3.5 addons. Retail-only libraries (TaintLess, the SFX widgets, LibItemBuffs, LibChatAnims, SpellFlashCore)
  are not included; Hekili works without them.
- **`Temucraft.lua`** (new, loads before Hekili): every Hekili file starts with `setfenv( 1, HekiliTemucraft.env )`,
  so it reads globals through a table of its own. Only Hekili sees these versions; other addons keep the normal
  3.3.5 functions.
  - Classic return orders: `UnitAura`/`UnitBuff`/`UnitDebuff`, `UnitCastingInfo`/`UnitChannelInfo`, `GetSpellInfo`
    (cast time, ranges and the spell id), `GetBuildInfo`, `UnitClassBase` (class file first), `GetActionInfo`
    (spell id for spells), `GetMacroSpell` (spell id), `GetCursorInfo`, `GetShapeshiftFormInfo`, `GetNetStats`,
    `GetSpellBookItemName`.
  - Spell ids where 3.3.5 only takes names: `IsUsableSpell`, `IsSpellInRange`, `IsHarmfulSpell`, `IsHelpfulSpell`,
    `IsPassiveSpell`, `GetSpellTexture`.
  - Talents: `IsPlayerSpell` / `IsSpellKnown` also count talent ranks, read from the talent frame (3.3.5 doesn't
    put talent passives in the spell book).
  - Cast events: 3.3.5 sends `UNIT_SPELLCAST_*` with the spell name and rank; Hekili's handlers get the Classic
    arguments (cast id and spell id) instead.
  - 3.3.5 GUIDs ("0xF130...") are read for npc ids.
  - Weapon imbues: 3.3.5 gives no enchant id, so the imbue name is read from the weapon tooltip (shaman imbues
    are matched by name). This also fixes an upstream bug where the shaman code read the wrong value.
  - Combo points (`UnitPower` type 4) come from `GetComboPoints`; power types 3.3.5 doesn't have read as 0.
  - `Enum.PowerType` with the Classic values (the rune types), `Item:CreateFromItemID`, stand-ins for missing
    functions (charges, power cost tables, loss of control, phasing...) and global strings.
  - Missing `C_` namespaces and members do nothing (retail-only code paths).
- **Icons**: the class files gave icons as file ids, which 3.3.5 doesn't have. 528 were changed to their icon
  paths; 6 icons that the 3.3.5 client doesn't have fall back to the spell's own icon.
- **Atlases**: the few option icons that were atlases use whole 3.3.5 textures.
- **Menu**: the retail slider in the display menu became a list of values (3.3.5 dropdowns have no custom frames).
- A call to an undefined function in the target debug text was fixed.

## What doesn't work on 3.3.5

- Spell charges, loss of control data and phasing information don't exist on this client.
- Haste comes from haste rating (3.3.5 has no total haste function), so haste buffs such as Bloodlust are only
  counted where the class files add them.
- Temucraft's own class changes and new spells aren't in the action lists yet; suggestions follow the stock
  Wrath rotations.
- Glows for spell procs ("spell activation overlay") don't exist on 3.3.5.

## Status

Built and checked without the game: every Lua file compiles, and the functions it calls were compared with the
3.3.5 client's. It has not been played yet; the first in-game run may need small fixes.
