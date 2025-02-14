local OPCODE = 92

local trackerWindow = nil

local tasksWindow = nil

local jsonData = ""
local config = {}
local tasks = {}
local activeTasks = {}
local playerLevel = 0
local RewardType = {
  Points = 1,
  Ranking = 2,
  Experience = 3,
  Gold = 4,
  Item = 5,
  Storage = 6,
  Teleport = 7,
}

function init()
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  ProtocolGame.unregisterExtendedOpcode(OPCODE, onExtendedOpcode)

  destroy()
end

function create()
  if tasksWindow then
    return
  end
  
  trackerWindow = g_ui.loadUI("tasks_tracker", modules.game_interface.getRightPanel())
  trackerWindow.miniwindowScrollBar:mergeStyle({["$!on"] = {}})
  trackerWindow:setContentMinimumHeight(120)
  trackerWindow:setup()
  trackerWindow:hide()

  tasksWindow = g_ui.displayUI("tasks")
  tasksWindow:hide()

  tasksWindow.info.kills.bar.scroll.onValueChange = onKillsValueChange
end

function toggleTasksPanel()
  if not tasksWindow then
    return
  end
  
  if tasksWindow:isVisible() then
    tasksWindow:hide()
  else
    tasksWindow:show()
  end
end

function destroy()
  if tasksWindow then
    if trackerWindow then
      trackerWindow:destroy()
      trackerWindow = nil
    end

    tasksWindow:destroy()
    tasksWindow = nil
  end

  config = {}
  tasks = {}
  activeTasks = {}
  playerLevel = 0
  jsonData = ""
end

function onExtendedOpcode(protocol, code, buffer)
  local char = buffer:sub(1, 1)
  local endData = false
  if char == "E" then
    endData = true
  end

  local partialData = false
  if char == "S" or char == "P" or char == "E" then
    partialData = true
    buffer = buffer:sub(2)
    jsonData = jsonData .. buffer
  end

  if partialData and not endData then
    return
  end

  local json_status, json_data =
    pcall(
    function()
      return json.decode(endData and jsonData or buffer)
    end
  )

  if not json_status then
    g_logger.error("[Tasks] JSON error: " .. json_data)
    return
  end

  local action = json_data.action
  local data = json_data.data

  if action == "config" then
    onTasksConfig(data)
  elseif action == "tasks" then
    onTasksList(data)
  elseif action == "active" then
    onTasksActive(data)
  elseif action == "update" then
    onTaskUpdate(data)
  elseif action == "points" then
    onTasksPoints(data)
  elseif action == "ranking" then
    onTasksRanking(data)
  elseif action == "open" then
    show()
  elseif action == "close" then
    hide()
  end
end

function onTasksConfig(data)
  config = data

  tasksWindow.info.kills.bar.min:setText(config.kills.Min)
  tasksWindow.info.kills.bar.max:setText(config.kills.Max)
  tasksWindow.info.kills.bar.scroll:setRange(config.kills.Min, config.kills.Max)
  tasksWindow.info.kills.bar.scroll:setValue(config.kills.Min)
end

function onTasksList(data)
  tasks = data
  local localPlayer = g_game.getLocalPlayer()
  local level = localPlayer:getLevel()
  
  for taskId, task in ipairs(data) do
    if not task then
      g_logger.error("[Tasks] Task is nil for taskId: " .. tostring(taskId))
      goto continue
    end
    
    if not task.outfits then
      task.outfits = {}
      for _, mobName in ipairs(task.mobs) do
        local outfitType = getOutfitTypeByName(mobName)
        table.insert(task.outfits, {
          type = outfitType or 128,
          head = 0,
          body = 0,
          legs = 0,
          feet = 0,
          addons = 0
        })
      end
    end
    
    local widget = g_ui.createWidget("TaskMenuEntry", tasksWindow.tasksList)
    widget:setId(taskId)
    local outfit = task.outfits[1]
    widget.preview:setOutfit(outfit)
    widget.preview:setCenter(true)
    widget.info.title:setText(task.name or "Unknown Task")
    widget.info.level:setText("Level " .. (task.lvl or 0))
    if not (task.lvl >= level - config.range and task.lvl <= level + config.range) then
      widget.info.bonus:hide()
    end
    
    ::continue::
  end

  tasksWindow.tasksList.onChildFocusChange = onTaskSelected
  local firstChild = tasksWindow.tasksList:getChildByIndex(1)
  if firstChild then
    onTaskSelected(nil, firstChild)
  end
  playerLevel = g_game.getLocalPlayer():getLevel()
end

function onTasksActive(data)
  for _, active in ipairs(data) do
    local task = tasks[active.taskId]
    local widget = g_ui.createWidget("TrackerButton", trackerWindow.contentsPanel.trackerPanel)
    widget:setId(active.taskId)
    local outfit = task.outfits[1]
    widget.creature:setOutfit(outfit)
    widget.creature:setCenter(true)
    if task.name:len() > 12 then
      widget.label:setText(task.name:sub(1, 9) .. "...")
    else
      widget.label:setText(task.name)
    end
    widget.kills:setText(active.kills .. "/" .. active.required)
    local percent = active.kills * 100 / active.required
    setBarPercent(widget, percent)
    widget.onMouseRelease = onTrackerClick
    activeTasks[active.taskId] = true
  end
end

function onTaskUpdate(data)
  local widget = trackerWindow.contentsPanel.trackerPanel[tostring(data.taskId)]
  if data.status == 1 then
    local task = tasks[data.taskId]
    if not widget then
      widget = g_ui.createWidget("TrackerButton", trackerWindow.contentsPanel.trackerPanel)
      widget:setId(data.taskId)
      local outfit = task.outfits[1]
      widget.creature:setOutfit(outfit)
      widget.creature:setCenter(true)
      if task.name:len() > 12 then
        widget.label:setText(task.name:sub(1, 9) .. "...")
      else
        widget.label:setText(task.name)
      end
      widget.onMouseRelease = onTrackerClick
      activeTasks[data.taskId] = true
    end

    widget.kills:setText(data.kills .. "/" .. data.required)
    local percent = data.kills * 100 / data.required
    setBarPercent(widget, percent)
  elseif data.status == 2 then
    activeTasks[data.taskId] = nil
    if widget then
      widget:destroy()
    end
  end

  local focused = tasksWindow.tasksList:getFocusedChild()
  if focused then
    local taskId = tonumber(focused:getId())
    if taskId == data.taskId then
      if activeTasks[data.taskId] then
        tasksWindow.start:hide()
        tasksWindow.cancel:show()
      else
        tasksWindow.start:show()
        tasksWindow.cancel:hide()
      end
    end
  end
end

function onTasksPoints(points)
  tasksWindow.points:setText("Current Ancestral Tasks Points: " .. points)
end

function onTasksRanking(data)
    if not data or not data.rank then
        return
    end
    tasksWindow.ranking:setText("Current Ancestral Ranking: " .. tostring(data.rank))
end


function onTrackerClick(widget, mousePosition, mouseButton)
  local taskId = tonumber(widget:getId())
  local menu = g_ui.createWidget("PopupMenu")
  menu:setGameMenu(true)
  menu:addOption(
    "Abandon this task",
    function()
      cancel(taskId)
    end
  )
  menu:display(menuPosition)

  return true
end

function setBarPercent(widget, percent)
  if percent > 92 then
    widget.killsBar:setBackgroundColor("#00BC00")
  elseif percent > 60 then
    widget.killsBar:setBackgroundColor("#50A150")
  elseif percent > 30 then
    widget.killsBar:setBackgroundColor("#A1A100")
  elseif percent > 8 then
    widget.killsBar:setBackgroundColor("#BF0A0A")
  elseif percent > 3 then
    widget.killsBar:setBackgroundColor("#910F0F")
  else
    widget.killsBar:setBackgroundColor("#850C0C")
  end
  widget.killsBar:setPercent(percent)
end

function onTaskSelected(parent, child, reason)
  if not child then
    return
  end

  local taskId = tonumber(child:getId())
  local task = tasks[taskId]

  tasksWindow.info.rewards:destroyChildren()
  for _, reward in ipairs(task.rewards) do
    local widget = g_ui.createWidget("Label", tasksWindow.info.rewards)
    widget:setTextAlign(AlignCenter)
    if reward.type == RewardType.Points then
      widget:setText("Tasks Points: " .. reward.value)
	elseif reward.type == RewardType.Ranking then
      widget:setText("Ranking Points: " .. reward.value)
    elseif reward.type == RewardType.Experience then
      widget:setText("Experience: " .. reward.value)
    elseif reward.type == RewardType.Gold then
      widget:setText("Gold: " .. reward.value)
    elseif reward.type == RewardType.Item then
      widget:setText(reward.amount .. "x " .. reward.name)
    elseif reward.type == RewardType.Storage then
      widget:setText(reward.desc)
    elseif reward.type == RewardType.Teleport then
      widget:setText("Teleport to " .. reward.desc)
    end
  end

  tasksWindow.info.monsters:destroyChildren()
  for id, monster in ipairs(task.mobs) do
    local widget = g_ui.createWidget("UICreature", tasksWindow.info.monsters)
    local outfit = task.outfits[id]
    widget:setOutfit(outfit)
    widget:setCenter(true)
    widget:setPhantom(false)
    widget:setTooltip(monster)
  end

  if activeTasks[taskId] then
    tasksWindow.start:hide()
    tasksWindow.cancel:show()
  else
    tasksWindow.start:show()
    tasksWindow.cancel:hide()
  end
end

function onKillsValueChange(widget, value, delta)
  tasksWindow.info.kills.bar.value:setText(value)

  local focused = tasksWindow.tasksList:getFocusedChild()
  if not focused then
    return
  end

  local taskId = tonumber(focused:getId())
  local task = tasks[taskId]

  local bonus = math.floor((math.max(0, value - config.bonus) / config.bonus) + 0.5)
  if bonus == 0 then
    tasksWindow.info.kills.bonuses.none:show()
    tasksWindow.info.kills.bonuses.points:hide()
    tasksWindow.info.kills.bonuses.exp:hide()
    tasksWindow.info.kills.bonuses.gold:hide()
  else
    tasksWindow.info.kills.bonuses.none:hide()
    tasksWindow.info.kills.bonuses.points:hide()
    tasksWindow.info.kills.bonuses.exp:hide()
    tasksWindow.info.kills.bonuses.gold:hide()

    for _, reward in ipairs(task.rewards) do
      if reward.type == RewardType.Points then
        local finalBonus = bonus * config.points
        tasksWindow.info.kills.bonuses.points:show()
        tasksWindow.info.kills.bonuses.points:setText("+" .. finalBonus .. "% Tasks Points")
      elseif reward.type == RewardType.Experience then
        local finalBonus = bonus * config.exp
        tasksWindow.info.kills.bonuses.exp:show()
        tasksWindow.info.kills.bonuses.exp:setText("+" .. finalBonus .. "% Exp")
      elseif reward.type == RewardType.Gold then
        local finalBonus = bonus * config.gold
        tasksWindow.info.kills.bonuses.gold:show()
        tasksWindow.info.kills.bonuses.gold:setText("+" .. finalBonus .. "% Gold")
      end
    end
  end
end

function onSearch()
  scheduleEvent(
    function()
      local searchInput = tasksWindow.searchInput
      local text = searchInput:getText():lower()

      if text:len() >= 1 then
        local children = tasksWindow.tasksList:getChildren()
        for i, child in ipairs(children) do
          local found = false
          for _, mob in ipairs(tasks[i].mobs) do
            if mob:lower():find(text) then
              found = true
              break
            end
          end

          if found then
            child:show()
          else
            child:hide()
          end
        end
      else
        local children = tasksWindow.tasksList:getChildren()
        for _, child in ipairs(children) do
          child:show()
        end
      end
    end,
    50
  )
end

function start()
  local focused = tasksWindow.tasksList:getFocusedChild()
  if not focused then
    return
  end
  
  local taskId = tonumber(focused:getId())
  local kills = tasksWindow.info.kills.bar.scroll:getValue()

  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "start", data = {taskId = taskId, kills = kills}}))
  end
end

function cancel(taskId)
  if not taskId then
    local focused = tasksWindow.tasksList:getFocusedChild()
    if not focused then
      return
    end

    taskId = tonumber(focused:getId())
  end

  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "cancel", data = taskId}))
  end
end

function toggleTracker()
  if not trackerWindow then
    return
  end

  if trackerWindow:isVisible() then
    trackerWindow:hide()
  else
    trackerWindow:show()
    trackerWindow:raise()
  end
end

function toggle()
  if not tasksWindow then
    return
  end
  if tasksWindow:isVisible() then
    return hide()
  end
  show()
end

function show()
  if not tasksWindow then
    return
  end

  local level = g_game.getLocalPlayer():getLevel()
  if playerLevel ~= level then
    local children = tasksWindow.tasksList:getChildren()
    for taskId, child in ipairs(children) do
      local task = tasks[taskId]
      if task.lvl >= level - config.range and task.lvl <= level + config.range then
        child.info.bonus:show()
      else
        child.info.bonus:hide()
      end
    end
    playerLevel = level
  end

  local focused = tasksWindow.tasksList:getFocusedChild()
  if focused then
    local taskId = tonumber(focused:getId())
    if activeTasks[taskId] then
      tasksWindow.start:hide()
      tasksWindow.cancel:show()
    else
      tasksWindow.start:show()
      tasksWindow.cancel:hide()
    end
  end

  tasksWindow:show()
  tasksWindow:raise()
  tasksWindow:focus()
end

function hide()
  if not tasksWindow then
    return
  end
  tasksWindow:hide()
end

function hideTracker()
  if trackerWindow then
    trackerWindow:hide()
  end
end

function getOutfitTypeByName(mobName)
  local outfitMap = {
    -- Criaturas básicas
    ["Crocodile"] = 119,
    ["Tarantula"] = 219,
    ["Carniphila"] = 251,
    ["Mammoth"] = 199,
    ["Ice Golem"] = 261,
    ["Mutated Rat"] = 305,
    ["Ancient Scarab"] = 79,
    ["Bonebeast"] = 101,
    ["Crystal Spider"] = 263,
    ["Giant Spider"] = 38,
    ["Werewolf"] = 308,
    ["Nightmare"] = 245,
    ["Dragon Lord"] = 39,
    ["Hellspawn"] = 322,
    ["Hydra"] = 121,
    ["Serpent Spawn"] = 220,
    ["Medusa"] = 330,
    ["Behemoth"] = 55,
    ["Sea Serpent"] = 275,
    ["Young Sea Serpent"] = 275,
    ["Hellhound"] = 240,
    ["Ghastly Dragon"] = 351,
    ["Destroyer"] = 236,
    ["Undead Dragon"] = 231,
    ["Demon"] = 35,
    
    -- Quara
    ["Quara Hydromancer"] = 72,
    ["Quara Predator"] = 72,
    ["Quara Constrictor"] = 72,
    ["Quara Mantassin"] = 72,
    ["Quara Pincher"] = 72,
    
    -- Lizards
    ["Lizard Chosen"] = 334,
    ["Lizard Dragon Priest"] = 334,
    ["Lizard High Guard"] = 334,
    ["Lizard Legionnaire"] = 334,
    
    -- Draken
    ["Draken Spellweaver"] = 351,
    ["Draken Warmaster"] = 351,
    ["Draken Abomination"] = 351,
    ["Draken Elite"] = 351,
    
    -- Minotaurs
    ["Worm Priestess"] = 25,
    ["Minotaur Amazon"] = 25,
    ["Minotaur Hunter"] = 25,
    ["Mooh'tah Warrior"] = 25,
    
    -- Nightmare Isles
    ["Retching Horror"] = 315,
    ["Choking Fear"] = 315,
    
    -- Secret Library
    ["Burning Book"] = 1061,
    ["Cursed Book"] = 1061,
    ["Ice Book"] = 1061,
    ["Energy Book"] = 1061,
    ["Guardian of Tales"] = 1061,
    
    -- Variações de nomes
    ["Ice Golems"] = 261,
    ["Ancient Scarabs"] = 79,
    ["Bonebeasts"] = 101,
    ["Crystal Spiders"] = 263,
    ["Giant Spiders"] = 38,
    ["Werewolves"] = 308,
    ["Nightmares"] = 245,
    ["Dragon Lords"] = 39,
    ["Hellspawns"] = 322,
    ["High Class Lizards"] = 334,
    ["Hydras"] = 121,
    ["Serpent Spawns"] = 220,
    ["Medusas"] = 330,
    ["Behemoths"] = 55,
    ["Hellhounds"] = 240,
    ["Ghastly Dragons"] = 351,
    ["Destroyers"] = 236,
    ["Undead Dragons"] = 231,
    ["Demons"] = 35,
    ["Raging Demons"] = 35,
    
    -- Novas criaturas do log
    ["Nightmare Scion"] = 245,
    ["Wyrm"] = 291,
    ["Elder Wyrm"] = 291,
    ["Stampor"] = 381,
    ["Brimstone Bug"] = 352,
    ["Mutated Bat"] = 307,
    ["Silencer"] = 568,
    ["Frazzlemaw"] = 594,
    ["Guzzlemaw"] = 594,
    ["Juggernaut"] = 244,
    ["Dark Torturer"] = 244,
    
    -- Criaturas do Secret Library
    ["Burning Book"] = 1061,
    ["Biting Book"] = 1061,
    ["Flying Book"] = 1061,
    ["Icecold Book"] = 1061,
    ["Energetic Book"] = 1061,
    ["Brain Squid"] = 1061,
    ["Ink Blob"] = 1061,
    ["Rage Squid"] = 1061,
    ["Squid Warden"] = 1061,
    
    -- Bosses e Criaturas Especiais
    ["Alpha Demon"] = 35,
    ["Black Dragon"] = 39,
    ["Infernal Demon"] = 35,
    ["Master of the Elements"] = 261,
    ["The Pale Worm"] = 231,
    ["The Unwelcome"] = 231,
    ["The Fear Feaster"] = 315,
    
    -- Criaturas das Profundezas
    ["Demon of the Depths"] = 35,
    ["Rhino of the Depths"] = 381,
    ["Bony Sea Devil"] = 231,
    
    -- Aparições e Fantasmas
    ["Druid's Apparition"] = 138,
    ["Knight's apparition"] = 131,
    ["Sorcerer's Apparition"] = 133,
    ["Paladin's Apparition"] = 129,
    ["Capricious Phantom"] = 48,
    ["Distorted Phantom"] = 48,
    
    -- Criaturas de Elite
    ["Emerald Mage"] = 133,
    ["Ruby Archer"] = 129,
    ["Sapphire Warrior"] = 131,
    ["Shadow Reaper"] = 48,
    ["Skullshade"] = 48,
    ["Tombwraith"] = 48,
    
    -- Criaturas Darklight
    ["Darklight Construct"] = 231,
    ["Darklight Emitter"] = 231,
    ["Darklight Matter"] = 231,
    ["Darklight Source"] = 231,
    ["Darklight Striker"] = 231,
    
    -- Goshnar's
    ["Goshnar's Cruelty"] = 231,
    ["Goshnar's Greed"] = 231,
    ["Goshnar's Hatred"] = 231,
    ["Goshnar's Malice"] = 231,
    ["Goshnar's Spite"] = 231,
    ["Goshnar's Megalomania"] = 231,
    
    -- Outros Bosses
    ["Count Vlarkorth"] = 231,
    ["Duke Krule"] = 231,
    ["Earl Osam"] = 231,
    ["Lord Azaram"] = 231,
    ["Sir Baeloc"] = 231,
    ["Sir Nictros"] = 231,
    ["King Zelos"] = 231,
    
    -- Criaturas Especiais
    ["Bulltauren Alchemist"] = 25,
    ["Bulltauren Brute"] = 25,
    ["Bulltauren Forgepriest"] = 25,
    ["Mega Dragon"] = 39,
    ["Wardragon"] = 39,
    ["Evil Prospector"] = 131,
    ["Cursed Prospector"] = 131,
    
    -- Novas criaturas
    ["Aberration of the Depths"] = 231,
    ["Azure Guard"] = 231,
    ["Brontosaurus"] = 381,
    ["Butcher Ogre"] = 25,
    ["Colossal Ice Monkey"] = 261,
    ["Giant Hornet"] = 219,
    ["Mitmah Vanguard"] = 231,
    ["Tauren Herk"] = 25,
    ["Irgix The Flimsy"] = 48,
    ["Unaz The Mean"] = 48,
    ["Vok The Freakish"] = 48,
    ["The Dread Maiden"] = 231,
    ["Animated Feather"] = 231,
    ["Energuardian of Tales"] = 1061,
    ["Floating Savant"] = 1061,
    ["Knowledge Elemental"] = 1061,
    ["Ghulosh"] = 231,
    ["Gorzindel"] = 231,
    ["Lokathmor"] = 231,
    ["Mazzinor"] = 231,
    ["The Scourge Of Oblivion"] = 231,
    ["Brachiodemon"] = 35,
    ["Branchy Crawler"] = 231,
    ["Cloak Of Terror"] = 48,
    ["Courage Leech"] = 48,
    ["Rotten Golem"] = 261,
    ["Turbulent Elemental"] = 261,
    ["Many Faces"] = 48,
    ["Bloated Man-Maggot"] = 231,
    ["Converter"] = 231,
    ["Meandering Mushroom"] = 231,
    ["Mycobiontic Beetle"] = 231,
    ["Oozing Carcass"] = 231,
    ["Oozing Corpus"] = 231,
    ["Rotten Man-Maggot"] = 231,
    ["Sopping Carcass"] = 231,
    ["Walking Pillar"] = 231,
    ["Wandering Pillar"] = 231,
    ["Chagorz"] = 231,
    ["Ichgahal"] = 231,
    ["Murcion"] = 231,
    ["Vemiath"] = 231,
    ["Bakragore"] = 231,
    ["Aeliana"] = 231,
    ["Archon"] = 231,
    ["Baalzebul"] = 35,
    ["Lyrael"] = 231,
    ["Nyxion"] = 231,
    ["Oroniel"] = 231,
    ["Sagittarius"] = 231,
    ["Seraphiel"] = 231,
    ["Fangclaw"] = 231,
    ["Lurkskin"] = 231,
    ["Scalebreaker"] = 231,
    ["Slinkhide"] = 231,
    ["Sludgejaw"] = 231,
    ["Cinderclaw"] = 231,
    ["Scaledrake"] = 39,
    ["Bonecleaver"] = 231,
    ["Fleshcarver"] = 231,
    ["Fleshrend"] = 231,
    ["Mauler"] = 231,
    ["Grothar"] = 231,
    ["Grugnor"] = 231,
    ["Krag'lok"] = 231,
    ["Krulmash"] = 231,
    ["Mok'gosh"] = 231,
    ["Thokkar"] = 231,
    ["Blackblade"] = 231,
    ["Blightbearer"] = 231,
    ["Gorthak"] = 231,
    ["Malevolent"] = 231,
    ["Shadowreaper"] = 48,
    ["Urzog"] = 231,
    ["Bonelich"] = 231,
    ["Deathrattle"] = 231,
    ["Doombone"] = 231,
    ["Grimbone"] = 231
  }
  
  -- Procura pelo nome exato primeiro
  if outfitMap[mobName] then
    return outfitMap[mobName]
  end
  
  -- Se não encontrar, tenta remover o 's' final (plural)
  if mobName:sub(-1) == "s" then
    local singularName = mobName:sub(1, -2)
    if outfitMap[singularName] then
      return outfitMap[singularName]
    end
  end
  
  -- Procura por padrões comuns nos nomes
  local patterns = {
    ["Dragon"] = 39,
    ["Demon"] = 35,
    ["Spider"] = 38,
    ["Ghost"] = 48,
    ["Phantom"] = 48,
    ["Apparition"] = 48,
    ["Book"] = 1061,
    ["Squid"] = 1061,
    ["Torturer"] = 244,
    ["Lost Soul"] = 48,
    ["Elemental"] = 261,
    ["Golem"] = 261,
    ["Undead"] = 231,
    ["Lich"] = 231,
    ["Beast"] = 101
  }
  
  for pattern, outfitId in pairs(patterns) do
    if mobName:find(pattern) then
      return outfitId
    end
  end
  
  -- Se não encontrar nenhum, retorna um outfit padrão
  return 128 -- Outfit padrão caso não encontre
end
