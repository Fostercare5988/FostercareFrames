-- F11: watched auras. FostercareFramesDB.watched lists your buffs (unit "player")
-- and your target's debuffs (unit "target") by name, and by spell ID where known:
-- { name, spellID, unit, icon, topRight, inRow, mine, cooldown }. Each shows as its
-- own icon with the time left (icon), and only when asked also at the top right
-- (topRight) and in the row under its frame (inRow). Only mine shows the one you
-- cast. A buff of yours that ends shows its spell's own cooldown, greyed (cooldown).
local _, F = ...
local db = FostercareFramesDB

local SIZE, GAP = 36, 6
local FILTER = { player = "HELPFUL", target = "HARMFUL" }
local icons = {}               -- frame name -> icon, kept when an entry goes
local iconOf = {}              -- entry -> its icon
local slots, found = {}, {}
local hidden = { top = {}, player = {}, target = {} }
local watching = {}            -- unit -> a watched entry is on it
local byName = { player = {}, target = {} } -- unit -> aura name -> entry
local byID = { player = {}, target = {} }   -- unit -> spell ID -> entry
local spells = {}              -- name -> { slot, book } of your spell with a cooldown, or false

-- For the rows and the top right: whether an aura is shown elsewhere instead.
-- place "top" is the top right, else the unit's row; source is the caster's token.
function F.Hidden(name, unit, place, source)
    local rule = name and (place == "top" and hidden.top or hidden[unit])[name]
    if rule == "mine" then return source ~= nil and UnitIsUnit(source, "player") and true or false end
    return rule or false
end

-- The spell's icon (a name-only entry: your own spell of that name).
local function SpellIcon(entry)
    local _, _, texture = GetSpellInfo(entry.spellID or entry.name)
    return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Your spell of that name: its book slot, for its cooldown; false for a spell
-- with none of its own (Slice and Dice), so a cast reads nothing for it.
local function Spell(name)
    local known = spells[name]
    if known == nil then
        local id = select(10, GetSpellInfo(name))
        local base = id and GetSpellBaseCooldown(id)
        local slot, book
        if base and base > 0 then slot, book = FindSpellBookSlotByID(id) end
        known = slot and { slot, book } or false
        spells[name] = known
    end
    return known
end

local function Icon(entry, index)
    local name = "FostercareFramesWatch_" .. entry.unit .. "_" .. string.gsub(entry.name, "[^%w]", "")
    local icon = icons[name]
    if not icon then
        icon = CreateFrame("Frame", name, UIParent)
        icon:SetFrameLevel(10)
        F.Icon(icon, SIZE, 14)
        icon.cd:SetScript("OnCooldownDone", function() if icon.cooling then F.WatchMissing("player") end end)
        icon.handle = F.Movable(icon, entry.name, function() F.Watch(icon.entry.unit) end)
        icon:Hide()
        icons[name] = icon
    end
    -- Until the player moves it, above the screen's centre, eight to a row.
    if not icon:IsUserPlaced() then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", UIParent, "CENTER", ((index - 1) % 8 - 3.5) * (SIZE + GAP),
            150 + math.floor((index - 1) / 8) * (SIZE + GAP))
    end
    icon.entry, icon.handle.off = entry, nil
    return icon
end

local function Show(icon, texture, count, duration, expires)
    if icon.cooling then
        icon.cooling = nil
        icon.icon:SetDesaturated(false)
        icon.cd:SetReverse(true)
    end
    icon.up = true
    F.Texture(icon.icon, texture)
    F.Stacks(icon, count)
    F.Timing(icon, duration, expires)
    icon:Show()
end

-- One of your buffs has ended: its spell's own cooldown, greyed with a filling
-- sweep, until it is ready. A cooldown of 1.5 s or less is the global one (a
-- rogue's 1 s too); C_Spell.GetSpellCooldown's isOnGCD would say so, but in a new
-- table at every read.
local function ShowCooldown(icon, entry)
    if entry.unit ~= "player" or not entry.cooldown then return false end
    local spell = Spell(entry.name)
    if not spell then return false end
    local start, duration = GetSpellCooldown(spell[1], spell[2])
    if not start or duration <= 1.5 or start + duration <= GetTime() then return false end
    if not icon.cooling then
        icon.cooling = true
        icon.icon:SetDesaturated(true)
        icon.cd:SetReverse(false)
        F.Texture(icon.icon, SpellIcon(entry))
        F.Stacks(icon, nil)
    end
    F.Timing(icon, duration, start + duration)
    icon:Show()
    return true
end

-- The entries of `unit` whose aura is not up: a cooldown, or hidden.
function F.WatchMissing(unit)
    for entry, icon in pairs(iconOf) do
        if entry.unit == unit and not icon.up and not ShowCooldown(icon, entry) and not icon.handle.revealed then
            if icon.cooling then icon.cooling = nil; icon.icon:SetDesaturated(false); icon.cd:SetReverse(true) end
            icon:Hide()
        end
    end
end

-- The first aura that matches an entry (Only mine: one you cast) shows on its icon.
local function Found(entry, texture, count, duration, expires, source)
    if not entry or found[entry] or entry.mine and not (source and UnitIsUnit(source, "player")) then return end
    found[entry] = true
    if iconOf[entry] then Show(iconOf[entry], texture, count, duration, expires) end
end

-- Reads the unit's auras of its kind once; each finds its entry by name and by
-- spell ID (the name keeps a higher rank matching).
function F.Watch(unit)
    if not watching[unit] then return end
    for _, icon in pairs(iconOf) do if icon.entry.unit == unit then icon.up = nil end end
    table.wipe(found)
    if UnitExists(unit) then
        local names, ids = byName[unit], byID[unit]
        local _, n = C_UnitAuras.GetAuraSlots(unit, FILTER[unit], nil, nil, slots)
        for i = 1, n do
            local name, texture, count, _, duration, expires, source, _, _, spellID =
                C_UnitAuras.UnitAuraBySlot(unit, slots[i])
            Found(name and names[name], texture, count, duration, expires, source)
            Found(spellID and ids[spellID], texture, count, duration, expires, source)
        end
    end
    F.WatchMissing(unit)
end

-- After a change to the list: icons for the entries that want one, the rows and
-- the top right told what now shows elsewhere.
function F.Rebuild()
    for _, set in pairs(hidden) do table.wipe(set) end
    for _, set in pairs(byName) do table.wipe(set) end
    for _, set in pairs(byID) do table.wipe(set) end
    table.wipe(iconOf)
    watching.player, watching.target = nil, nil
    for _, icon in pairs(icons) do icon.handle.off = true; icon.up = nil; icon:Hide() end
    local index = 0
    for _, entry in ipairs(db.watched) do
        if entry.icon then
            index = index + 1
            iconOf[entry] = Icon(entry, index)
        end
        watching[entry.unit] = true
        byName[entry.unit][entry.name] = entry
        if entry.spellID then byID[entry.unit][entry.spellID] = entry end
        if entry.unit == "player" and not entry.topRight then hidden.top[entry.name] = true end
        if not entry.inRow then hidden[entry.unit][entry.name] = entry.mine and "mine" or true end
    end
    F.Watch("player")
    F.Watch("target")
    if F.Rows then F.Rows() end
    if F.TopRight then F.TopRight() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, e)
    if e == "SPELLS_CHANGED" then table.wipe(spells) else F.WatchMissing("player") end
end)
