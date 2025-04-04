minimapWidget = nil
minimapButton = nil
minimapWindow = nil
otmm = true
preloaded = false
fullmapView = false
oldZoom = nil
oldPos = nil
fullMapWindow = nil
fullMapWidget = nil


local enabled = true


local MAP_COMPOSITIONS, COMPOSITIONS = {}, {}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Viridian", position = {x = 3296, y = 560, z = 7}}
MAP_COMPOSITIONS[#MAP_COMPOSITIONS + 1] = {text = "Pallet", position = {x = 3292, y = 799, z = 7}}


MAPMARK_TICK = 0
MAPMARK_QUESTION = 1
MAPMARK_EXCLAMATION = 2
MAPMARK_STAR = 3
MAPMARK_CROSS = 4
MAPMARK_TEMPLE = 5
MAPMARK_KISS = 6
MAPMARK_SHOVEL = 7
MAPMARK_SWORD = 8
MAPMARK_FLAG = 9
MAPMARK_LOCK = 10
MAPMARK_BAG = 11
MAPMARK_SKULL = 12
MAPMARK_DOLLAR = 13
MAPMARK_REDNORTH = 14
MAPMARK_REDSOUTH = 15
MAPMARK_REDEAST = 16
MAPMARK_REDWEST = 17
MAPMARK_GREENNORTH = 18
MAPMARK_GREENSOUTH = 19

local GUIDES = {}
GUIDES["Tangelo"] = { -- Guide Cary
    {position = {x = 2745, y = 2829, z = 6}, type = MAPMARK_DOLLAR, description = "Poke Mart"},
    {position = {x = 2756, y = 2819, z = 5}, type = MAPMARK_TEMPLE, description = "Pokemon Center"},
    {position = {x = 2764, y = 2831, z = 6}, type = MAPMARK_BAG, description = "Food Shop"},
    {position = {x = 2724, y = 2857, z = 6}, type = MAPMARK_FLAG, description = "Travel Ship"},
}


local guideEnabled = true
local guideMarks = {}

local function removeGuides()
    for k, v in pairs(guideMarks) do
        v:destroy()
    end
    guideMarks = {}
end

local function addGuides()
    for k, city in pairs(GUIDES) do
        for _, mark in pairs(city) do
            guideMarks[#guideMarks + 1] = minimapWidget:addFlag(mark.position, mark.type, tr(mark.description))
            guideMarks[#guideMarks + 1] = fullMapWidget:addFlag(mark.position, mark.type, tr(mark.description))
        end
    end
end

function setGuidesDisplay(v)
    guideEnabled = v
    if (not guideEnabled) then
        removeGuides()
    end
end

function getMinimapWidget()
  return minimapWidget
end

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRootPanel())
  minimapButton = minimapWindow:recursiveGetChildById('minimapButton')
  
  minimapButton:hide()
  
  minimapPanel  = minimapWindow:recursiveGetChildById('minimapPanel')
  minimapPanel:recursiveGetChildById('posLabel').onMouseRelease = onPositionMouseRelease
  
  minimapWidget = minimapPanel:recursiveGetChildById('minimap')
  
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() fullMapWidget:move(1,0) minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() fullMapWidget:move(-1,0) minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() fullMapWidget:move(0,1) minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() fullMapWidget:move(0,-1) minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggleMinimap)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap)
  g_keyboard.bindKeyDown('Escape', toggleFullMapVisible)

  fullMapWindow = g_ui.createWidget('FullMapWindow', rootWidget)
  fullMapWidget = fullMapWindow:getChildById('minimap')
  fullMapWindow:hide()
  
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  minimapWindow:destroy()
  fullMapWindow:destroy()
  minimapButton:destroy()
  
end

function toggleMinimap()
  if minimapButton:isVisible() then
    minimapPanel:setVisible(true)
    minimapButton:setVisible(false)
  else
    minimapPanel:setVisible(false)
    minimapButton:setVisible(true)
  end
end

function preload()
  loadMap(false)
  preloaded = true
end

function online()
  loadMap(not preloaded)
  updateCameraPosition()
end

function offline()
  saveMap()
end

local function loadCompositions()
    g_minimap.loadImage('/images/map', {x = 0, y = 0, z = 7}, 0.5)

    for _, composition in pairs(MAP_COMPOSITIONS) do
        local flag = g_ui.createWidget('MinimapFlag')
        minimapWidget:insertChild(1, flag)
        fullMapWidget:insertChild(1, flag)
		
        flag.pos = composition.position
        flag:setText(composition.text)
        flag:setFont("sans-bold-16px")
        flag:setTextAutoResize(true)
        flag:setVisible(false)
        minimapWidget:centerInPosition(flag, flag.pos)
        fullMapWidget:centerInPosition(flag, flag.pos)
        COMPOSITIONS[#COMPOSITIONS + 1] = flag
    end
end

local function toggleCompositions()
    for _, composition in pairs(COMPOSITIONS) do
        composition:setVisible(fullmapView)
    end
end

function loadMap(clean, ignoreConfig)
  local protocolVersion = g_game.getProtocolVersion()

  if clean then
    g_minimap.clean()
  end

  if (not ignoreConfig) then
      if otmm then
        local minimapFile = '/minimap.otmm'
        if g_resources.fileExists(minimapFile) then
          g_minimap.loadOtmm(minimapFile)
        end
      else
        local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
        if g_resources.fileExists(minimapFile) then
          g_map.loadOtcm(minimapFile)
        end
      end
  end
  loadCompositions()
  removeGuides()
  if (guideEnabled) then
    addGuides()
  end
  minimapWidget:load()
  fullMapWidget:load()
end

function saveMap()
  local protocolVersion = g_game.getProtocolVersion()
  if otmm then
    local minimapFile = '/minimap.otmm'
    g_minimap.saveOtmm(minimapFile)
  else
    local minimapFile = '/minimap_' .. protocolVersion .. '.otcm'
    g_map.saveOtcm(minimapFile)
  end
  minimapWidget:save()
  fullMapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
	  minimapPanel:getChildById('posLabel'):setText('X:'..pos.x..' Y:'..pos.y..' Z:'..pos.z)
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
  if not fullMapWidget:isDragging() then
    if not fullmapView then
      fullMapWidget:setCameraPosition(player:getPosition())
    end
    fullMapWidget:setCrossPosition(player:getPosition())
  end
end

function toggleFullMap()
  if fullMapWindow:isVisible() then
    fullmapView = false
    fullMapWindow:hide()
  else
    fullmapView = true
    fullMapWindow:show()
  end
  toggleCompositions()
end

function toggleFullMapVisible()
    if (fullmapView) then
        toggleFullMap()
    end
end

function updatePos(pos)
  text = 'Posição: ' .. pos
  posLabel:setText(text)
end

function setDisplay(v)
    enabled = v
    window:setVisible(enabled)
end


function setLocation(text)
    window:recursiveGetChildById('location'):setText(text)
end

function reset()
    local messageBox
    local defaultCallback = function() messageBox:ok() end
    messageBox = UIMessageBox.display(tr("Map reset"), tr("You really want to reset the map?"),
        {
            {text=tr('Yes'), callback=function()
                minimapWidget:removeFlags()
                fullMapWidget:removeFlags()
                saveMap()
                loadMap(true, true)
                displayInfoBox(tr('Map reset'), tr('The map has been reseted!'))
                defaultCallback()
            end},
            {text=tr('No'), callback=defaultCallback}
        }, defaultCallback, defaultCallback)
end