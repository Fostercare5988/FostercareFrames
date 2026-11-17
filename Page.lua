-- The FostercareFrames page in ClassicAPI's Settings window (AddOn Options, or /ffr).
local _, F = ...
local db = FostercareFramesDB
local category

SettingsRegistrar:AddRegistrant(function()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("FostercareFrames")
    for _, row in ipairs(F.PAGE) do
        if type(row) == "string" then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(row))
        else
            local key, name, tip = row[1], row[2], row[3]
            local setting = Settings.RegisterAddOnSetting(category, "FostercareFrames_" .. key, key, db,
                Settings.VarType.Boolean, name, true)
            setting:SetValueChangedCallback(F.apply[key])
            Settings.CreateCheckbox(category, setting, tip)
        end
    end
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Watched"))
    layout:AddInitializer(CreateSettingsButtonInitializer("Watched auras", "Watched auras...", F.WatchList,
        "Your buffs and your target's debuffs, each with its own icon and the time left.", false))
    Settings.RegisterAddOnCategory(category)
end)

SLASH_FOSTERCAREFRAMES1 = "/ffr"
SlashCmdList.FOSTERCAREFRAMES = function()
    if category then Settings.OpenToCategory(category:GetID()) end
end

F.Rebuild() -- the watched icons, then the rows and the top right they leave
