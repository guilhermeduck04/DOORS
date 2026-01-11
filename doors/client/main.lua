-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPserver = Tunnel.getInterface("vRP","doors")

src = {}
Tunnel.bindInterface("doors",src)
vSERVER = Tunnel.getInterface("doors")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local segundos = 0
local trancas = config.doors
local lastUpdate = 0 -- Controle para não floodar o UI

-----------------------------------------------------------------------------------------------------------------------------------------
-- SISTEMA DE INTERAÇÃO (CORRIGIDO: UI OTIMIZADO)
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local time = 1000
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local now = GetGameTimer()
        
        for k,v in pairs(trancas) do
            local distance = #(pedCoords - v.coords)
            
            if distance <= v.distance then
                -- LÓGICA DO UI: Só atualiza a cada 200ms para evitar CRASH, mesmo que o loop esteja rápido
                if (now - lastUpdate) > 200 then
                    lastUpdate = now
                    
                    local uiText = v.trancado[1] and "Destrancar" or "Trancar"
                    local uiType = v.trancado[1] and "locked" or "door"

                    exports['ghost_ui']:ShowPrompt({
                        id = 'door_' .. k,
                        coords = v.coords,
                        text = uiText,
                        key = 'E',
                        type = uiType,
                        maxDistance = v.distance,
                        offset = 0.5
                    })
                end
                
                -- LÓGICA DO CLIQUE: Roda rápido (5ms) para pegar o clique instantâneo
                if distance <= 1.5 then
                    time = 5 -- Deixa o loop rápido APENAS para checar a tecla
                    
                    if IsControlJustPressed(0,38) and segundos <= 0 then
                        segundos = 3 -- Reduzi para 3s para ser mais dinâmico
                        
                        -- Animação
                        vRP._playAnim(true,{{"veh@mower@base","start_engine"}},false)
                        Citizen.Wait(2200) -- Aguarda animação
                        
                        -- Envia pro servidor
                        local novoStatus = not v.trancado[1]
                        if vSERVER.syncLock(k, novoStatus, v.perm[1]) then
                            local msg = novoStatus and "Porta trancada." or "Porta destrancada."
                            local tipo = novoStatus and "sucesso" or "negado"
                            TriggerEvent("Notify", tipo, msg, 3000)
                        end
                    end
                end
            else
                -- Esconde o prompt se sair de perto (só executa uma vez quando necessário)
                if distance < v.distance + 2.0 then 
                   exports['ghost_ui']:HidePrompt('door_' .. k)
                end
            end
        end
    
        Citizen.Wait(time)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SYNCRONIZAR PORTAS (CORRIGIDO: SEM CRASH)
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local time = 1000
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        
        -- Otimização: Só busca objetos se tiver alguma porta configurada perto
        local closeDoor = false
        for _,v in pairs(trancas) do
            if #(pedCoords - v.coords) <= 20.0 then
                closeDoor = true
                break
            end
        end

        if closeDoor then
            time = 500 -- Atualiza a cada meio segundo se estiver perto
            local gamePool = GetGamePool('CObject') -- Pega objetos

            for k,v in pairs(trancas) do
                if #(pedCoords - v.coords) <= 20.0 then
                    
                    -- Verifica objetos no mundo
                    for _, entity in ipairs(gamePool) do
                        local entityCoords = GetEntityCoords(entity)
                        
                        -- Se o objeto estiver a 3 metros da coordenada da config (pega porta dupla)
                        if #(v.coords - entityCoords) <= 3.0 then
                            local model = GetEntityModel(entity)
                            
                            -- Confere Hash
                            local isDoor = false
                            for _, h in pairs(v.hash) do
                                if model == h then isDoor = true break end
                            end

                            if isDoor then
                                -- ESTADO ATUAL vs ESTADO DESEJADO
                                -- IsEntityPositionFrozen retorna true se está travada
                                local isLocked = IsEntityPositionFrozen(entity)
                                local shouldLock = v.trancado[1]

                                -- Só mexe se estiver errado (EVITA OVERFLOW DE REDE)
                                if isLocked ~= shouldLock then
                                    
                                    -- Garante controle antes de aplicar
                                    if not NetworkHasControlOfEntity(entity) then
                                        NetworkRequestControlOfEntity(entity)
                                    end

                                    -- Aplica
                                    SetEntityCanBeDamaged(entity, false)
                                    if shouldLock then
                                        -- Tenta fechar e trancar
                                        local _, heading = GetStateOfClosestDoorOfType(model, entityCoords.x, entityCoords.y, entityCoords.z, false, 0.0)
                                        if heading > -0.08 and heading < 0.08 then
                                            FreezeEntityPosition(entity, true)
                                        end
                                    else
                                        -- Destranca
                                        FreezeEntityPosition(entity, false)
                                    end
                                end
                                
                                -- Força visualmente a porta a ficar parada se estiver trancada
                                if shouldLock and isLocked then
                                     FreezeEntityPosition(entity, true)
                                end
                            end
                        end
                    end
                end
            end
        end

        Citizen.Wait(time)
    end
end)

function src.setLock(id, status)
    if id and trancas[id] then
        trancas[id].trancado[1] = status
    end
end

function src.syncAllLock(value)
    for k,v in pairs(value) do
        if trancas[k] then
            trancas[k].trancado[1] = v
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTILS / CALLBACKS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("closeNui",function(data,cb)
    SetNuiFocus(false)
end)

RegisterNetEvent('sound:source')
AddEventHandler('sound:source',function(sound,volume)
    SendNUIMessage({ transactionType = 'playSound', transactionFile = sound, transactionVolume = volume })
end)

-- Mantive o contador separado para não pesar
Citizen.CreateThread(function()
    while true do
        if segundos > 0 then
            segundos = segundos - 1
        end
        Citizen.Wait(1000)
    end
end)