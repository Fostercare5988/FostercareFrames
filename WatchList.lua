-- The watched-aura list: the one window of the addon's own, since the Settings
-- window cannot draw a list editor (Settings pattern rule 6). Opened from the page.
local _, F = ...
local db = FostercareFramesDB

local LINES, LINE = 14, 24
-- The columns: the entry's key, its header, its tip, and the unit it is for (nil: both).
local COLUMNS = {
    { "icon", "Icon", "Its own icon with the time left; Ctrl+Shift moves it." },
    { "topRight", "Top", "Also in the game's buffs at the top right.", "player" },
    { "inRow", "Row", "Also in the row under its frame." },
    { "mine", "Mine", "Only the one you cast; another player's stays in the row." },
    { "cooldown", "CD", "When it ends, its spell's cooldown, greyed.", "player" },
}

local win = CreateFrame("Frame", "FostercareFramesWatchList", UIParent)
win:SetWidth(440); win:SetHeight(96 + LINES * LINE)
win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
win:SetFrameStrata("DIALOG")
win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 } })
win:EnableMouse(true)
win:SetMovable(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", function() win:StartMoving() end)
win:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
win:Hide()
table.insert(UISpecialFrames, "FostercareFramesWatchList") -- Escape closes it
local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", win, "TOP", 0, -16)
title:SetText("Watched auras")
CreateFrame("Button", nil, win, "UIPanelCloseButton"):SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -6)

local box = CreateFrame("EditBox", "FostercareFramesWatchName", win, "InputBoxTemplate")
box:SetWidth(150); box:SetHeight(20)
box:SetPoint("TOPLEFT", win, "TOPLEFT", 24, -40)
box:SetAutoFocus(false)
box:SetScript("OnEscapePressed", function() box:ClearFocus() end)

local offset, Draw = 0, nil
-- A spell's name or ID; a new entry gets its own icon and, for a buff, its cooldown.
local function Add(unit)
    local text = string.match(box:GetText() or "", "^%s*(.-)%s*$")
    local id = tonumber(text)
    local name = id and GetSpellInfo(id) or text
    box:SetText(""); box:ClearFocus()
    if not name or name == "" then return end
    for _, entry in ipairs(db.watched) do if entry.unit == unit and entry.name == name then return end end
    table.insert(db.watched, { name = name, spellID = id, unit = unit, icon = true, topRight = false,
        inRow = false, mine = unit == "target", cooldown = unit == "player" })
    F.Rebuild(); Draw()
end
local function Button(text, width, x, onClick)
    local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(22)
    b:SetPoint("LEFT", box, "RIGHT", x, 0)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
end
Button("Add your buff", 110, 8, function() Add("player") end)
Button("Add target debuff", 120, 122, function() Add("target") end)
box:SetScript("OnEnterPressed", function() Add("player") end)

local function Tip(frame, text)
    frame.tip = text
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT"); GameTooltip:SetText(frame.tip, 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
for c, column in ipairs(COLUMNS) do
    local head = CreateFrame("Frame", nil, win)
    head:SetWidth(34); head:SetHeight(16)
    head:SetPoint("TOPLEFT", win, "TOPLEFT", 196 + (c - 1) * 38, -68)
    head:EnableMouse(true)
    local label = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(head)
    label:SetText(column[2])
    Tip(head, column[3])
end

-- One line per entry: icon, name ("on you" or "on target"), the switches, remove.
local lines = {}
F.lines = lines
for i = 1, LINES do
    local line = CreateFrame("Frame", nil, win)
    line:SetWidth(400); line:SetHeight(LINE)
    line:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -84 - (i - 1) * LINE)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetWidth(18); line.icon:SetHeight(18)
    line.icon:SetPoint("LEFT", line, "LEFT", 0, 0)
    line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    line.name = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.name:SetPoint("LEFT", line, "LEFT", 24, 0)
    line.name:SetWidth(150); line.name:SetJustifyH("LEFT")
    line.checks = {}
    for c, column in ipairs(COLUMNS) do
        local check = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
        check:SetWidth(22); check:SetHeight(22)
        check:SetPoint("LEFT", line, "LEFT", 182 + (c - 1) * 38, 0)
        check:SetScript("OnClick", function()
            line.entry[column[1]] = check:GetChecked() and true or false
            F.Rebuild()
        end)
        Tip(check, column[3])
        line.checks[c] = check
    end
    local remove = CreateFrame("Button", nil, line, "UIPanelCloseButton")
    remove:SetWidth(24); remove:SetHeight(24)
    remove:SetPoint("RIGHT", line, "RIGHT", 6, 0)
    remove:SetScript("OnClick", function()
        for n, entry in ipairs(db.watched) do
            if entry == line.entry then table.remove(db.watched, n); break end
        end
        F.Rebuild(); Draw()
    end)
    Tip(remove, "Stop watching it.")
    line.remove, lines[i] = remove, line
end

Draw = function()
    local list = db.watched
    offset = math.max(0, math.min(offset, #list - LINES))
    for i, line in ipairs(lines) do
        local entry = list[offset + i]
        line.entry = entry
        line:SetShown(entry ~= nil)
        if entry then
            local _, _, texture = GetSpellInfo(entry.spellID or entry.name)
            line.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            line.name:SetText(entry.name .. (entry.unit == "player" and "  |cff888888on you|r" or "  |cff888888on target|r"))
            for c, column in ipairs(COLUMNS) do
                local check = line.checks[c]
                check:SetShown(column[4] == nil or column[4] == entry.unit)
                check:SetChecked(entry[column[1]])
                -- A spell with no cooldown of its own (Slice and Dice): CD has nothing to show.
                local dead = column[1] == "cooldown" and not F.HasCooldown(entry.name)
                check:SetEnabled(not dead)
                check:SetAlpha(dead and 0.35 or 1)
                check.tip = dead and entry.name .. " has no cooldown of its own." or column[3]
            end
        end
    end
end
-- The wheel scrolls a list longer than the window.
win:EnableMouseWheel(true)
win:SetScript("OnMouseWheel", function(_, delta) offset = offset - (delta or arg1); Draw() end)

function F.WatchList()
    if win:IsShown() then win:Hide() else Draw(); win:Show() end
end
