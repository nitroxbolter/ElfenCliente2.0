healthBar = nil
manaBar = nil
experienceBar = nil
soulLabel = nil
capLabel = nil
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your character mana is %d out of %d.'
powerTooltip = 'Your character power is %d out of %d.'
experienceTooltip = 'You have %d%% to advance to level %d.'
vocation = nil
localPlayer = nil

local color = {
    ["Novato"] = "#34baeb",
    ["Guerreiro"] = "#A6052C",
    ["Lutador"] = "#A6052C",
    ["Bárbaro"] = "#A6052C",
    ["Paladino"] = "#0077ff",
    ["Templario"] = "#0077ff",
    ["Patrulheiro"] = "#0f6621",
    ["Ladino"] = "#5c0000",
    ["Assassino"] = "#5c0000",
    ["Arqueiro"] = "#0f6621",
    ["Hunter"] = "#0f6621",
    ["Feiticeiro"] = "#ba34eb",
    ["Bruxo"] = "#ba34eb",
    ["Arquimago"] = "#ba34eb",
    ["Necromancer"] = "#460075",
    ["Evoker"] = "#460075",
    ["Celestial"] = "#FFF369",
    ["Profeta"] = "#00eaff",
    ["Hierofante"] = "#00eaff",
    ["Bispo"] = "#FFF369",
    ["Cardeal"] = "#FFF369",
}

function init()
    connect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onExperienceChange = onExperienceChange,
        onManaChange = onManaChange,
        onLevelChange = onLevelChange,
        onPowerChange = onPowerChange,
        onVocationChange = onPlayerVocationChange
    })

    if g_game.isOnline() then
        localPlayer = g_game.getLocalPlayer()
        vocation = localPlayer:getVocation()
        onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
        onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
        onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
        -- onPowerChange(localPlayer, localPlayer:getPower(), localPlayer:getMaxPower())
        updateColor(vocation)
    end
end

function updateColor(vocation)
    --modules.game_interface.getRootPanel():setImageColor(color[vocations[tostring(vocation)]])
end

function terminate()
    disconnect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onExperienceChange = onExperienceChange,
        onManaChange = onManaChange,
        onLevelChange = onLevelChange,
        onPowerChange = onPowerChange,
        onVocationChange = onPlayerVocationChange
    })
end

function onHealthChange(localPlayer, health, maxHealth)
    setGlobePercent('health', health, maxHealth)
end

function onManaChange(localPlayer, mana, maxMana)
    setGlobePercent('mana', mana, maxMana)
end

function onLevelChange(localPlayer, value, percent)
    setActionExperience(value, percent)
end

function onPowerChange(localPlayer, power, maxPower, oldPower, oldMaxPower)
    setActionPower(power, maxPower)
end

function onPlayerVocationChange(localPlayer, vocation, oldVocation)
    updateColor(vocation)
end

function setGlobePercent(window, now, max)
    local percent = math.min(100, math.max(0, now * 100 / max)) -- Limita entre 0 e 100%

    local globe
    local globe2
    local globe3
    local text
    local panel
    local tip

    if window == 'mana' then
        panel = modules.game_interface.getRootPanel():getChildById("manaPanel")
        globe = panel:getChildById("manaFill")
        globe2 = panel:getChildById("manaFillbacka")
        globe3 = panel:getChildById("manaFillbacka")
        text = panel:getChildById("text")
        tip = manaTooltip
    elseif window == 'health' then
        panel = modules.game_interface.getRootPanel():getChildById("healthPanel")
        globe = panel:getChildById("healthFill")
        globe2 = panel:getChildById("healthFillbacka")
        globe3 = panel:getChildById("healthFillbacka")
        text = panel:getChildById("text")
        tip = healthTooltip
    end

    -- Calcula a altura máxima do clipe
    local maxClipHeight = 292
    local clipHeight = math.min(maxClipHeight, (maxClipHeight * percent / 100))
    local clipY = maxClipHeight - clipHeight

    -- Calcula a altura máxima do painel
    local maxPanelHeight = 100
    local panelHeight = math.min(maxPanelHeight, (maxPanelHeight * percent / 100))

    -- Aplica os valores ao globo principal
    globe:setImageClip({ x = 0, y = clipY, height = clipHeight, width = 292 })
    globe:setHeight(panelHeight)
    
    -- Aplica ao globo de fundo
    globe3:setImageClip({ x = 0, y = clipY, height = clipHeight, width = 292 })
    globe3:setHeight(panelHeight)
    
    text:setText(now .. "/" .. max)
    text:setTooltip(tr(tip, now, max))
end

function setActionPower(now, max)
    localPlayer = g_game.getLocalPlayer()
    vocation = localPlayer:getVocation()

    local percent = now * 100 / max
    local powerBar = modules.game_interface.getRootPanel():getChildById("powerBar")
    local powerValue = powerBar:getChildById("powerFill")
    local powerText = powerBar:getChildById("powerText")
    local powerWidth = powerBar:getWidth() - 18

    powerValue:setImageClip({
        x = 0,
        y = 0,
        height = 14,
        width = 1920 * percent / 100
    })

    if percent < 50 then
        powerValue:setImageBorderLeft((powerWidth * percent / 100))
        powerValue:setImageBorderRight(0)
    else
        powerValue:setImageBorderLeft((powerWidth * percent / 100 / 2))
        powerValue:setImageBorderRight((powerWidth * percent / 100 / 2))
    end

    powerValue:setWidth(powerWidth * percent / 100)
    powerText:setText(percent .. "%")
    powerText:setTooltip(tr(powerTooltip, now, max))
end

function expForLevel(level)
    return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
    return expForLevel(currentLevel + 1) - currentExp
end

function setActionExperience(level, percent)
    localPlayer = g_game.getLocalPlayer()
    vocation = localPlayer:getVocation()
    updateColor(vocation)

    local experienceBar = modules.game_interface.getRootPanel():getChildById("expBar")
    local experienceValue = experienceBar:getChildById("expFill")
    local experienceText = experienceBar:getChildById("expText")
    local expWidth = experienceBar:getWidth() - 18

    experienceValue:setImageClip({
        x = 0,
        y = 0,
        height = 14,
        width = 1920 * percent / 100
    })

    if percent < 50 then
        experienceValue:setImageBorderLeft((expWidth * percent / 100))
        experienceValue:setImageBorderRight(0)
    else
        experienceValue:setImageBorderLeft((expWidth * percent / 100 / 2))
        experienceValue:setImageBorderRight((expWidth * percent / 100 / 2))
    end

    local text = tr('You have %s percent to go', 100 - percent) .. '\n' ..
        tr('%s of experience left', expToAdvance(localPlayer:getLevel(), localPlayer:getExperience()))

    experienceValue:setWidth(expWidth * percent / 100)
    experienceText:setText(percent .. "%")
    experienceText:setTooltip(text)

    -- Atualiza o texto do nível no novo widget
    local levelTextWidget = modules.game_interface.getRootPanel():getChildById("textLevel")  -- Corrigido para "textLevel"
    levelTextWidget:setText(level)  -- Define apenas o texto do nível
end

function updateActionBars()
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
        --setActionPower(localPlayer:getPower(), localPlayer:getMaxPower())
        setActionExperience(localPlayer:getLevel(), localPlayer:getLevelPercent())
    end
end
