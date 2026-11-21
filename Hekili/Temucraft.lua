-- Temucraft.lua
-- 3.3.5a port helpers for Hekili. Loaded after the libraries and before every Hekili file.
--
-- Hekili was written for Wrath Classic (3.4). Most newer functions it calls come from !TemucraftCompat. A few
-- exist on 3.3.5 but give their values in another order (UnitAura, GetSpellInfo, the cast functions...), and
-- changing those for the whole client would break other addons. So every Hekili file starts with
--     setfenv( 1, HekiliTemucraft.env )
-- and reads its globals through that table: the versions below first, then the normal globals. Globals that
-- Hekili writes still go to _G.

local _G = _G
local type, tonumber, select, pairs, next, setmetatable, rawget = type, tonumber, select, pairs, next, setmetatable, rawget
local floor = math.floor

local TC = TemucraftCompat or {}
local Modern = TC.Modern or {}

local o = {}            -- the 3.3.5 stand-ins and the Classic return orders
local T = { overrides = o }
HekiliTemucraft = T

local noop = function() end

-- ------------------------------------------------------------------------------------------------ spells
local GetSpellInfo335, GetSpellLink = _G.GetSpellInfo, _G.GetSpellLink

local function idFromLink( link )
    return link and tonumber( link:match( "spell:(%d+)" ) )
end

-- The spell id for a spell name (optionally "Name(Rank 3)"): the highest known rank, from its link.
local idByName = {}
local function SpellIdByName( name, rank )
    if not name then return nil end
    local key = rank and rank ~= "" and ( name .. "(" .. rank .. ")" ) or name
    local id = idByName[ key ]
    if id == nil then
        id = idFromLink( GetSpellLink( key ) ) or ( key ~= name and idFromLink( GetSpellLink( name ) ) ) or false
        idByName[ key ] = id
    end
    return id or nil
end
T.SpellIdByName = SpellIdByName
T.ClearSpellIds = function() for k in pairs( idByName ) do idByName[ k ] = nil end end

-- Classic: name, rank, icon, castTime, minRange, maxRange, spellID
-- 3.3.5:   name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
o.GetSpellInfo = function( spell, book )
    if spell == nil then return nil end
    local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
    if book then
        name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo335( spell, book )
    else
        name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo335( spell )
    end
    if not name then return nil end
    local id = type( spell ) == "number" and not book and spell or SpellIdByName( name, rank )
    return name, rank, icon, castTime, minRange, maxRange, id
end

-- Spell names only: these take a name or a spell book index on 3.3.5, not a spell id.
local function byName( spell )
    if type( spell ) == "number" then return ( GetSpellInfo335( spell ) ) end
    return spell
end
for _, fn in pairs( { "IsSpellInRange", "IsHarmfulSpell", "IsHelpfulSpell", "SpellHasRange", "IsUsableSpell", "IsPassiveSpell" } ) do
    local real = _G[ fn ]
    if real then
        o[ fn ] = function( spell, ... )
            local name = byName( spell )
            if not name then return nil end
            return real( name, ... )
        end
    end
end

o.GetSpellTexture = function( spell, book )
    if type( spell ) == "number" and not book then return ( select( 3, GetSpellInfo335( spell ) ) ) end
    return _G.GetSpellTexture( spell, book )
end

-- 3.3.5 has no charges, no base cooldown data and no cost table.
o.GetSpellCharges = function() return nil end
o.GetSpellBaseCooldown = function() return 0, 1500 end
o.GetSpellPowerCost = function( spell )
    local name, _, _, cost, _, powerType = GetSpellInfo335( spell )
    if not name then return nil end
    return { { type = powerType or 0, cost = cost or 0, minCost = cost or 0, costPercent = 0, costPerSec = 0,
        requiredAuraID = 0, hasRequiredAura = false } }
end
o.SpellIsSelfBuff = function() return false end

-- Talents: a talent spell is "known" when the talent has at least that spell's rank. 3.3.5 doesn't put talent
-- passives in the spell book, so IsSpellKnown can't see them.
local talentRanks, talentsDirty = {}, true
local function TalentRanks()
    if talentsDirty then
        for k in pairs( talentRanks ) do talentRanks[ k ] = nil end
        local group = _G.GetActiveTalentGroup and _G.GetActiveTalentGroup() or 1
        for tab = 1, _G.GetNumTalentTabs() or 0 do
            for i = 1, _G.GetNumTalents( tab ) or 0 do
                local name, _, _, _, rank = _G.GetTalentInfo( tab, i, false, false, group )
                if name then talentRanks[ name ] = rank or 0 end
            end
        end
        talentsDirty = false
    end
    return talentRanks
end
T.TalentsChanged = function() talentsDirty = true end

o.IsPlayerSpell = function( id )
    if not id then return false end
    if _G.IsSpellKnown( id ) then return true end
    local name, rank = GetSpellInfo335( id )
    if not name then return false end
    local have = TalentRanks()[ name ]
    if have then
        local want = rank and tonumber( rank:match( "(%d+)" ) ) or 1
        return have >= want
    end
    return false
end
o.IsSpellKnown = function( id, pet )
    if not id then return false end
    if _G.IsSpellKnown( id, pet ) then return true end
    if pet then return false end
    return o.IsPlayerSpell( id )
end

-- Spell book: newer clients give the spell id as a third value.
local function bookType( b ) if b == "pet" or b == _G.BOOKTYPE_PET then return "pet" end return "spell" end
o.GetSpellBookItemName = function( slot, book )
    local name, rank = _G.GetSpellName( slot, bookType( book ) )
    if not name then return nil end
    return name, rank, idFromLink( GetSpellLink( slot, bookType( book ) ) )
end
o.FindSpellBookSlotBySpellID = function( id )
    local name = GetSpellInfo335( id )
    if not name then return nil end
    local byNameSlot
    for tab = 1, _G.GetNumSpellTabs() do
        local _, _, offset, count = _G.GetSpellTabInfo( tab )
        for slot = offset + 1, offset + count do
            local link = GetSpellLink( slot, "spell" )
            if idFromLink( link ) == id then return slot end
            if not byNameSlot and _G.GetSpellName( slot, "spell" ) == name then byNameSlot = slot end
        end
    end
    return byNameSlot
end


-- Action bars, macros and the cursor: newer clients give spell ids where 3.3.5 gives spell book slots or names.
-- 3.3.5 GetActionInfo: type, id (spell book slot for spells), subType, spellID
o.GetActionInfo = function( slot )
    local kind, id, sub, spellID = _G.GetActionInfo( slot )
    if kind == "spell" then return kind, spellID or id, sub end
    return kind, id, sub
end
o.GetMacroSpell = function( macro )
    local name, rank = _G.GetMacroSpell( macro )
    if not name then return nil end
    return SpellIdByName( name, rank )
end
o.GetCursorInfo = function()
    local kind, a, b, c = _G.GetCursorInfo()
    if kind == "spell" and c == nil then
        return kind, a, b, idFromLink( GetSpellLink( a, b ) )
    end
    return kind, a, b, c
end

-- ------------------------------------------------------------------------------------------------ units
o.UnitAura = Modern.UnitAura
o.UnitBuff = Modern.UnitBuff
o.UnitDebuff = Modern.UnitDebuff
o.UnitCastingInfo = Modern.UnitCastingInfo
o.UnitChannelInfo = Modern.UnitChannelInfo
o.GetBuildInfo = Modern.GetBuildInfo

-- Wrath Classic has no specializations; Hekili treats the class as the spec there. !TemucraftCompat gives
-- retail-style stand-ins for these, so Hekili gets its own Classic versions.
o.GetSpecialization = function() return _G.GetActiveTalentGroup and _G.GetActiveTalentGroup() or 1 end
o.GetSpecializationInfo = function()
    local name, baseName, id = _G.UnitClass( "player" )
    return id, baseName, name
end

-- 3.3.5 UnitClassBase gives (localized name, class file); newer clients give (class file, class id).
o.UnitClassBase = function( unit )
    local _, file, id = _G.UnitClass( unit )
    return file, id
end

o.GetNumClasses = function() return _G.MAX_CLASSES or 11 end   -- class ids 1-11 (no 10 on 3.3.5)
o.HasVehicleActionBar = _G.HasVehicleActionBar or function() return _G.UnitHasVehicleUI( "player" ) and true or false end
o.HasOverrideActionBar = _G.HasOverrideActionBar or function() return false end
o.UnitPhaseReason = function() return nil end
o.UnitWeaponAttackPower = function() return 0 end
o.GetMasteryEffect = function() return 0 end

-- Ratings past armor penetration (25) don't exist on 3.3.5.
local GetCombatRating, GetCombatRatingBonus = _G.GetCombatRating, _G.GetCombatRatingBonus
o.CR_MASTERY, o.CR_VERSATILITY_DAMAGE_DONE, o.CR_VERSATILITY_DAMAGE_TAKEN = 26, 29, 31
o.GetCombatRating = function( i ) if not i or i > 25 then return 0 end return GetCombatRating( i ) end
o.GetCombatRatingBonus = function( i ) if not i or i > 25 then return 0 end return GetCombatRatingBonus( i ) end

o.GetActiveLossOfControlData = function() return nil end
o.GetActiveLossOfControlDataCount = function() return 0 end



-- Enum.PowerType with every Wrath Classic value (the rune types are separate powers there).
o.Enum = setmetatable( {
    PowerType = setmetatable( { HealthCost = -2, None = -1, Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4,
        Runes = 5, RunicPower = 6, SoulShards = 7, LunarPower = 8, HolyPower = 9, Alternate = 10, Maelstrom = 11, Chi = 12,
        Insanity = 13, Obsolete = 14, Obsolete2 = 15, ArcaneCharges = 16, Fury = 17, Pain = 18, Essence = 19,
        RuneBlood = 20, RuneFrost = 21, RuneUnholy = 22, NumPowerTypes = 23 }, { __index = _G.Enum and _G.Enum.PowerType } ),
}, { __index = function( _, k ) return _G.Enum and _G.Enum[ k ] end } )


-- Combo points aren't a unit power on 3.3.5: read them with GetComboPoints, 5 at most.
local UnitPower, UnitPowerMax = _G.UnitPower, _G.UnitPowerMax
o.UnitPower = function( unit, kind, ... )
    if kind == 4 then
        if unit == "player" or unit == "vehicle" then return _G.GetComboPoints( unit, "target" ) or 0 end
        return 0
    end
    if kind and ( kind < 0 or kind > 6 ) then return 0 end   -- power types past runic power don't exist here
    return UnitPower( unit, kind, ... )
end
o.UnitPowerMax = function( unit, kind, ... )
    if kind == 4 then return 5 end
    if kind and ( kind < 0 or kind > 6 ) then return 0 end
    return UnitPowerMax( unit, kind, ... )
end

-- ------------------------------------------------------------------------------------------------ misc stats
o.GetNetStats = function()   -- newer clients split latency into home and world
    local down, up, latency = _G.GetNetStats()
    return down, up, latency, latency
end

-- Classic layout with the form's spell id: icon, name, active, castable, spellID
o.GetShapeshiftFormInfo = function( i )
    local icon, name, active, castable = _G.GetShapeshiftFormInfo( i )
    if not icon then return nil end
    return icon, name, active, castable, SpellIdByName( name )
end

-- Weapon imbues: newer clients give the enchant id; 3.3.5 only says there is one. The fourth and eighth values
-- here are the imbue's name from the weapon tooltip ("Windfury 3"), or nil.
local scanTip
local function TempEnchantName( slot )
    if not scanTip then
        scanTip = CreateFrame( "GameTooltip", "HekiliTemucraftScanTip", nil, "GameTooltipTemplate" )
        scanTip:SetOwner( _G.WorldFrame, "ANCHOR_NONE" )
    end
    scanTip:ClearLines()
    scanTip:SetInventoryItem( "player", slot )
    for i = 2, scanTip:NumLines() do
        local line = _G[ "HekiliTemucraftScanTipTextLeft" .. i ]
        local text = line and line:GetText()
        local name = text and text:match( "^(.-) %(%d+ ?%a+%)$" )
        if name then
            local r, g, b = line:GetTextColor()
            if g > 0.9 and r < 0.2 then return name end
        end
    end
end
T.TempEnchantName = TempEnchantName
o.GetWeaponEnchantInfo = function()
    local mh, mhExpires, mhCharges, oh, ohExpires, ohCharges = _G.GetWeaponEnchantInfo()
    return mh, mhExpires, mhCharges, mh and TempEnchantName( 16 ) or nil, oh, ohExpires, ohCharges,
        oh and TempEnchantName( 17 ) or nil
end

-- ------------------------------------------------------------------------------------------------ UI
o.UIDropDownMenu_AddSeparator = _G.UIDropDownMenu_AddSeparator or function( level )
    local info = _G.UIDropDownMenu_CreateInfo()
    info.text, info.disabled, info.notCheckable, info.notClickable = "", true, true, true
    _G.UIDropDownMenu_AddButton( info, level )
end

-- An object whose every method does nothing (ItemLocation and other retail-only objects).
local inert
inert = setmetatable( {}, { __index = function() return function() return nil end end } )
o.ItemLocation = _G.ItemLocation or setmetatable( { CreateEmpty = function() return inert end,
    CreateFromEquipmentSlot = function() return inert end, CreateFromBagAndSlot = function() return inert end },
    { __index = function() return noop end } )


-- Item:CreateFromItemID (item mixin): enough for Hekili's potion and item lists. 3.3.5 sends
-- GET_ITEM_INFO_RECEIVED with no item id, so waiting items are checked again on each one (and every second).
do
    local waiting = {}
    local waiter = CreateFrame( "Frame" )
    local elapsed = 0
    local function check()
        for item, callbacks in pairs( waiting ) do
            if _G.GetItemInfo( item.itemID ) then
                waiting[ item ] = nil
                for i = 1, #callbacks do callbacks[ i ]( true ) end
            end
        end
        if next( waiting ) == nil then waiter:Hide() end
    end
    waiter:Hide()
    waiter:RegisterEvent( "GET_ITEM_INFO_RECEIVED" )
    waiter:SetScript( "OnEvent", check )
    waiter:SetScript( "OnUpdate", function( self, e )
        elapsed = elapsed + e
        if elapsed > 1 then elapsed = 0 check() end
    end )

    local ItemObject = {}
    ItemObject.__index = ItemObject
    function ItemObject:GetItemID() return self.itemID end
    function ItemObject:IsItemEmpty() return not self.itemID end
    function ItemObject:IsItemDataCached() return _G.GetItemInfo( self.itemID ) ~= nil end
    function ItemObject:GetItemName() return ( _G.GetItemInfo( self.itemID ) ) end
    function ItemObject:GetItemLink() return ( select( 2, _G.GetItemInfo( self.itemID ) ) ) end
    function ItemObject:GetItemQuality() return ( select( 3, _G.GetItemInfo( self.itemID ) ) ) end
    function ItemObject:GetItemIcon() return ( select( 10, _G.GetItemInfo( self.itemID ) ) ) end
    function ItemObject:ContinueOnItemLoad( fn )
        if not self.itemID then return end
        if _G.GetItemInfo( self.itemID ) then fn( true ) return end
        waiting[ self ] = waiting[ self ] or {}
        table.insert( waiting[ self ], fn )
        waiter:Show()
    end
    ItemObject.ContinueWithCancelOnItemLoad = function( self, fn ) self:ContinueOnItemLoad( fn ) return noop end

    o.Item = _G.Item or {
        CreateFromItemID = function( _, id ) return setmetatable( { itemID = tonumber( id ) }, ItemObject ) end,
        CreateFromItemLink = function( _, link )
            return setmetatable( { itemID = link and tonumber( link:match( "item:(%d+)" ) ) }, ItemObject )
        end,
    }
end

-- Newer global strings (enUS) used in option names and checks.
o.BEST = _G.BEST or "Best"
o.SPELL_MAX_CHARGES = _G.SPELL_MAX_CHARGES or "Max %d Charges"
o.CAPACITANCE_SHIPMENT_COOLDOWN = _G.CAPACITANCE_SHIPMENT_COOLDOWN or "%s Cooldown"
o.BATTLE_PET_NAME_4 = _G.BATTLE_PET_NAME_4 or "Undead"

-- ------------------------------------------------------------------------------------------------ namespaces
-- C_ namespaces: missing ones and missing members do nothing (retail-only code paths), with a few answers that
-- matter for Hekili's flow.
local nsExtra = {
    C_Spell = { IsSpellDataCached = function() return true end, RequestLoadSpellData = noop },
    C_PvP = { IsWarModeDesired = function() return false end },
    C_PlayerInfo = { IsPlayerInChromieTime = function() return false end },
    C_PetBattles = { IsInBattle = function() return false end },
    C_LossOfControl = { GetActiveLossOfControlData = function() return nil end,
        GetActiveLossOfControlDataCount = function() return 0 end },
    C_ClassColor = { GetClassColor = function( file ) return _G.RAID_CLASS_COLORS[ file ] end },
    C_Texture = {},
}

-- Atlases Hekili's options use, drawn with whole 3.3.5 textures.
local ATLAS = {
    [ "auctionhouse-icon-favorite" ] = [[Interface\Icons\Ability_Warrior_Cleave]],
    [ "nameplates-InterruptShield" ] = [[Interface\Icons\Ability_Kick]],
    [ "voicechat-icon-speaker-mute" ] = [[Interface\Icons\Ability_Warrior_ShieldWall]],
    [ "VignetteEventElite" ] = [[Interface\Icons\Spell_Nature_Bloodlust]],
    [ "communities-icon-addgroupplus" ] = [[Interface\PaperDollInfoFrame\Character-Plus]],
    [ "communities-icon-redx" ] = [[Interface\Buttons\UI-GroupLoot-Pass-Up]],
    [ "hud-MainMenuBar-arrowdown-up" ] = [[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]],
    [ "hud-MainMenuBar-arrowup-up" ] = [[Interface\ChatFrame\UI-ChatIcon-ScrollUp-Up]],
    [ "transmog-icon-revert" ] = [[Interface\Buttons\UI-RefreshButton]],
    [ "poi-door-right" ] = [[Interface\Icons\Spell_Arcane_TeleportDalaran]],
}
nsExtra.C_Texture.GetAtlasInfo = function( atlas )
    local real = _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo( atlas )
    if real then return real end
    local file = ATLAS[ atlas ]
    if not file then return nil end
    return { file = file, width = 64, height = 64, leftTexCoord = 0.08, rightTexCoord = 0.92, topTexCoord = 0.08,
        bottomTexCoord = 0.92 }
end
local nsCache = {}
local function Namespace( name )
    local proxy = nsCache[ name ]
    if proxy then return proxy end
    local extra = nsExtra[ name ] or {}
    proxy = setmetatable( {}, { __index = function( t, k )
        local real = _G[ name ]
        local v = extra[ k ]
        if v == nil and type( real ) == "table" then v = real[ k ] end
        if v == nil then v = noop end
        return v
    end } )
    nsCache[ name ] = proxy
    return proxy
end


-- ------------------------------------------------------------------------------------------------ GUIDs
-- 3.3.5 GUIDs are "0xF130EEEEEECCCCCC" (type, 24-bit npc entry, counter), not "Creature-0-...-npcid-spawn".
-- NpcID gives the entry of a creature, vehicle or pet GUID, or nil.
local NPC_TYPES = { [ 3 ] = true, [ 4 ] = true, [ 5 ] = true }   -- 0xF13 creature, 0xF14 pet, 0xF15 vehicle
function T.NpcID( guid )
    if type( guid ) ~= "string" then return nil end
    if guid:sub( 1, 2 ) ~= "0x" then
        local id = guid:match( "(%d+)-%x-$" )   -- newer layout, in case one comes in
        return id and tonumber( id )
    end
    local kind = tonumber( guid:sub( 5, 5 ), 16 )
    if guid:sub( 3, 4 ) ~= "F1" or not NPC_TYPES[ kind ] then return nil end
    return tonumber( guid:sub( 7, 12 ), 16 )
end

-- ------------------------------------------------------------------------------------------------ cast events
-- 3.3.5: UNIT_SPELLCAST_x (unit, spellName, rank, castID, spellID); SENT (unit, spellName, rank, target, castID).
-- Classic: UNIT_SPELLCAST_x (unit, castGUID, spellID); SENT (unit, target, castGUID, spellID).
local CAST = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_FAILED_QUIET = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true }

-- Returns true and the Classic arguments for a cast event, or false for any other event.
function T.CastArgs( event, unit, name, rank, a4, a5 )
    if event == "UNIT_SPELLCAST_SENT" then
        return true, unit, a4, a5, SpellIdByName( name, rank )
    elseif CAST[ event ] then
        local id = tonumber( a5 ) or SpellIdByName( name, rank )
        return true, unit, a4, id
    end
    return false
end

local events = CreateFrame( "Frame" )
events:RegisterEvent( "SPELLS_CHANGED" )
events:RegisterEvent( "LEARNED_SPELL_IN_TAB" )
events:RegisterEvent( "CHARACTER_POINTS_CHANGED" )
events:RegisterEvent( "PLAYER_TALENT_UPDATE" )
events:RegisterEvent( "ACTIVE_TALENT_GROUP_CHANGED" )
events:SetScript( "OnEvent", function( _, event )
    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then T.ClearSpellIds() end
    talentsDirty = true
end )

-- ------------------------------------------------------------------------------------------------ environment
-- The stand-ins and namespace proxies are kept in the lookup table after the first read; everything else is
-- read from _G each time (Hekili and other addons set and hook globals later).
local lookup = setmetatable( {}, { __index = function( t, k )
    local v = o[ k ]
    if v == nil and type( k ) == "string" and k:sub( 1, 2 ) == "C_" then v = Namespace( k ) end
    if v ~= nil then
        t[ k ] = v
        return v
    end
    return _G[ k ]
end } )

T.env = setmetatable( {}, { __index = lookup, __newindex = _G } )
T.noop = noop
