modalDialog = nil
lastDialogChoices = 0
lastDialogChoice = 0
lastDialogAnswer = 0

function init()
  g_ui.importStyle('modaldialog')

  connect(g_game, { onModalDialog = onModalDialog,
                    onGameEnd = destroyDialog })

  local dialog = rootWidget:recursiveGetChildById('modalDialog')
  if dialog then
    modalDialog = dialog
  end
end

function terminate()
  disconnect(g_game, { onModalDialog = onModalDialog,
                       onGameEnd = destroyDialog })
end

function destroyDialog()
  if modalDialog then
    modalDialog:destroy()
    modalDialog = nil
  end
end

function onModalDialog(id, title, message, buttons, enterButton, escapeButton, choices, priority)
  -- priority parameter is unused, not sure what its use is.
  if modalDialog then
    return
  end

  modalDialog = g_ui.createWidget('ModalDialog', rootWidget)

  local messageLabel = modalDialog:getChildById('messageLabel')
  local choiceList = modalDialog:getChildById('choiceList')
  local choiceScrollbar = modalDialog:getChildById('choiceScrollBar')
  local buttonsPanel = modalDialog:getChildById('buttonsPanel')

  modalDialog:setText(title)
  messageLabel:setText(message)

  local labelHeight
  for i = 1, #choices do
    local choiceId = choices[i][1]
    local choiceName = choices[i][2]

    local label = g_ui.createWidget('ChoiceListLabel', choiceList)
    label.choiceId = choiceId
    label:setText(choiceName)
    label:setPhantom(false)
    if not labelHeight then
      labelHeight = label:getHeight()
    end
  end
  if #choices > 0 then
    if g_clock.millis() < lastDialogAnswer + 1000 and lastDialogChoices == #choices then
      choiceList:focusChild(choiceList:getChildByIndex(lastDialogChoice))    
    else
      choiceList:focusChild(choiceList:getFirstChild())
    end
  end

  local buttonsWidth = 0
  for i = 1, #buttons do
    local buttonId = buttons[i][1]
    local buttonText = buttons[i][2]

    local button = g_ui.createWidget('ModalButton', buttonsPanel)
    button:setText(buttonText)
    button.onClick = function(self)
                       local focusedChoice = choiceList:getFocusedChild()
                       local choice = 0xFF
                       if focusedChoice then
                         choice = focusedChoice.choiceId
                         lastDialogChoice = choiceList:getChildIndex(focusedChoice)
                         lastDialogAnswer = g_clock.millis()
                       end
                       g_game.answerModalDialog(id, buttonId, choice)
                       destroyDialog()
                     end
    buttonsWidth = buttonsWidth + button:getWidth() + button:getMarginLeft() + button:getMarginRight()
  end

  local additionalHeight = 0
  if #choices > 0 then
    choiceList:setVisible(true)
    choiceScrollbar:setVisible(true)

    additionalHeight = math.min(modalDialog.maximumChoices, math.max(modalDialog.minimumChoices, #choices)) * labelHeight
    additionalHeight = additionalHeight + choiceList:getPaddingTop() + choiceList:getPaddingBottom()
  end

  local horizontalPadding = modalDialog:getPaddingLeft() + modalDialog:getPaddingRight()
  buttonsWidth = buttonsWidth + horizontalPadding
  
  local labelWidth = math.min(600, math.floor(message:len() * 2.1))
  modalDialog:setWidth(math.min(modalDialog.maximumWidth, math.max(buttonsWidth, labelWidth, modalDialog.minimumWidth)))
  messageLabel:setTextWrap(true)
  
  modalDialog:setHeight(220 + additionalHeight + messageLabel:getHeight())

  local enterFunc = function()
    local focusedChoice = choiceList:getFocusedChild()
    local choice = 0xFF
    if focusedChoice then
      choice = focusedChoice.choiceId
      lastDialogChoice = choiceList:getChildIndex(focusedChoice)
      lastDialogAnswer = g_clock.millis()
    end
    g_game.answerModalDialog(id, enterButton, choice)
    destroyDialog()
  end

  local escapeFunc = function()
    local focusedChoice = choiceList:getFocusedChild()
    local choice = 0xFF
    if focusedChoice then
      choice = focusedChoice.choiceId
      lastDialogChoice = choiceList:getChildIndex(focusedChoice)
      lastDialogAnswer = g_clock.millis()
    end
    g_game.answerModalDialog(id, escapeButton, choice)
    destroyDialog()
  end

  choiceList.onDoubleClick = enterFunc

  modalDialog.onEnter = enterFunc
  modalDialog.onEscape = escapeFunc
  
  lastDialogChoices = #choices
end