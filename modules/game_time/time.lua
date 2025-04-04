jsonTest = {}

function jsonTest.init()
    ProtocolGame.registerExtendedOpcode(150, jsonTest.onExtendedOpcode)

    -- Adiciona a imagem no TopMenu
    jsonTest.timeImage = modules.client_topmenu.addRightGameButton(
<<<<<<< HEAD
        'timeImage', '', '/images/time/day.png', nil, false, true
=======
        'timeImage', '', '/images/day.png', nil, false, true
>>>>>>> 7eb1d4353ce2faf81d81284d6efe3e659190ee2e
    )

    -- Centraliza a imagem no TopMenu
    jsonTest.timeImage:setMarginLeft(150)
    jsonTest.timeImage:setMarginRight(650)

    -- Define tooltip inicial
    if jsonTest.timeImage then
        jsonTest.timeImage:setTooltip("Carregando...") 
    end

    -- Envia um pedido inicial ao servidor
    scheduleEvent(jsonTest.sendTimeRequest, 1000) -- Aguarda 1 segundo antes de enviar
end

function jsonTest.terminate()
    ProtocolGame.unregisterExtendedOpcode(150)

    if jsonTest.timeImage then
        jsonTest.timeImage:destroy()
        jsonTest.timeImage = nil
    end
end

-- Função para solicitar o horário ao servidor
function jsonTest.sendTimeRequest()
    if g_game.getProtocolGame() then
        local requestData = { request = "time" }
        g_game.getProtocolGame():sendExtendedOpcode(150, json.encode(requestData))
        print("Solicitação de horário enviada ao servidor.")
    else
        print("Erro: Conexão inválida!")
    end
end

function jsonTest.onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= 150 then return end
    
    local status, json_data = pcall(function() return json.decode(buffer) end)

    if not status or not json_data or not json_data.message then
        print("Erro ao receber horário do servidor!")
        return
    end

    local serverTime = json_data.message -- Obtém o horário enviado pelo servidor

    -- Atualiza a tooltip da imagem com o horário real
    if jsonTest.timeImage then
        jsonTest.timeImage:setTooltip(serverTime)
    end

    -- Obtém a hora atual do servidor
    local hour = tonumber(serverTime:sub(1, 2)) -- Pega os dois primeiros caracteres (hh)

    -- Define a imagem com base no horário
    if jsonTest.timeImage then
        if hour >= 6 and hour < 12 then
<<<<<<< HEAD
            jsonTest.timeImage:setIcon('/images/time/tarde.png') -- Entardecendo
        elseif hour >= 12 and hour < 18 then
            jsonTest.timeImage:setIcon('/images/time/day.png') -- Dia
        elseif hour >= 18 and hour < 20 then
            jsonTest.timeImage:setIcon('/images/time/evening.png') -- Anoitecendo
        else
            jsonTest.timeImage:setIcon('/images/time/night.png') -- Noite
=======
            jsonTest.timeImage:setIcon('/images/tarde.png') -- Entardecendo
        elseif hour >= 12 and hour < 18 then
            jsonTest.timeImage:setIcon('/images/day.png') -- Dia
        elseif hour >= 18 and hour < 20 then
            jsonTest.timeImage:setIcon('/images/evening.png') -- Anoitecendo
        else
            jsonTest.timeImage:setIcon('/images/night.png') -- Noite
>>>>>>> 7eb1d4353ce2faf81d81284d6efe3e659190ee2e
        end
    end

end

jsonTest.init()
