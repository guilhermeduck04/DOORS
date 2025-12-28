-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VRP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPserver = Tunnel.getInterface("vRP","doors")

src = {}
Tunnel.bindInterface("doors",src)
vSERVER = Tunnel.getInterface("doors")


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VARIAVEIS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local segundos = 0
local trancas = config.doors

-----------------------------------------------------------------------------------------------------------------------------------------
-- SISTEMA DE TRANCAS
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local time = 1000
        local pedCoords = GetEntityCoords(PlayerPedId())
        
        for k,v in pairs(trancas) do
            local distance = #(pedCoords - v.coords)
            
            -- ZONA VISUAL (Para ver o texto)
            if distance <= v.distance then
                time = 200 -- Atualiza o UI de forma mais tranquila
                
                -- Define o Texto e o Estilo
                local uiText = ""
                local uiType = ""

                if trancas[k].trancado[1] then
                    uiText = "Destrancar"
                    uiType = "locked" 
                else
                    uiText = "Trancar"
                    uiType = "door"
                end

                -- Mostra o Prompt
                exports['ghost_ui']:ShowPrompt({
                    id = 'door_' .. k,
                    coords = v.coords,
                    text = uiText,
                    key = 'E',
                    type = uiType,
                    maxDistance = v.distance,
                    offset = 0.5
                })

                -- ZONA DE INTERAÇÃO (Para apertar o botão)
                if distance <= 1.5 then
                    time = 5 -- CORREÇÃO AQUI: Deixa o loop rápido para captar o clique na hora
                    
                    if IsControlJustPressed(0,38) and segundos <= 0 then
                        segundos = 5
                        if trancas[k].trancado[1] then
                            vRP._playAnim(true,{{"veh@mower@base","start_engine"}},false)
                            Citizen.Wait(2200)
                            if vSERVER.syncLock(k, false, trancas[k].perm[1]) then
                                TriggerEvent("Notify","negado","Porta destrancada.", 300)
                            end
                        else
                            vRP._playAnim(true,{{"veh@mower@base","start_engine"}},false)
                            Citizen.Wait(2200)
                            if vSERVER.syncLock(k, true, trancas[k].perm[1]) then
                                TriggerEvent("Notify","sucesso","Porta trancada.", 300)
                            end
                        end
                    end
                end

            else
                exports['ghost_ui']:HidePrompt('door_' .. k)
            end
        end
    
        Citizen.Wait(time)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SYNCRONIZAR PORTAS
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
	while true do
		local time = 500
		local pedCoords = GetEntityCoords(PlayerPedId())
		for k,v in pairs(trancas) do
			local distance = #(pedCoords - v.coords)
			if distance <= 20.0 then
				local door = GetClosestObjectOfType(v.coords[1],v.coords[2],v.coords[3],5.0,trancas[k].hash[1],false,false,false)
				SetEntityCanBeDamaged(door,false)
				if v.trancado[1] == false then
					NetworkRequestControlOfEntity(door)
					FreezeEntityPosition(door,false)
				else
					local lock,heading = GetStateOfClosestDoorOfType(v.hash[1],v.coords[1],v.coords[2],v.coords[3],lock,heading)
					if heading > -0.02 and heading < 0.02 then
						NetworkRequestControlOfEntity(door)
						FreezeEntityPosition(door,true)
					end
				end
			end
		end

		Citizen.Wait(time)
	end
end)


function src.setLock(id, status)
	if id then
		trancas[id].trancado[1] = status
	end
end

function src.syncAllLock(value)
	for k in pairs(value) do
		trancas[k].trancado[1] = value[k]
	end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CALL BACKS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("closeNui",function(data,cb)
	SetNuiFocus(false)
	SendNUIMessage({ hidemenu = true })
end)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SOUNDS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('sound:source')
AddEventHandler('sound:source',function(sound,volume)
	SendNUIMessage({ transactionType = 'playSound', transactionFile = sound, transactionVolume = volume })
end)

RegisterNetEvent('sound:distance')
AddEventHandler('sound:distance', function(playerNetId, maxDistance, soundFile, soundVolume)
    local lCoords = GetEntityCoords(GetPlayerPed(-1))
    local eCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(playerNetId)))
    local distIs = Vdist(lCoords.x, lCoords.y, lCoords.z, eCoords.x, eCoords.y, eCoords.z)
    if (distIs <= maxDistance) then
        SendNUIMessage({ transactionType = 'playSound', transactionFile = soundFile, transactionVolume = soundVolume })
    end
end)  

RegisterNetEvent('sound:fixed')
AddEventHandler('sound:fixed',function(playerid,x2,y2,z2,maxdistance,sound,volume)
	local ped = PlayerPedId()
	local x,y,z = table.unpack(GetEntityCoords(ped))
	local distance = GetDistanceBetweenCoords(x2,y2,z2,x,y,z,true)
	if distance <= maxdistance then
		SendNUIMessage({ transactionType = 'playSound', transactionFile = sound, transactionVolume = volume })
	end
end)

function DrawText3Ds(x,y,z,text)
	local onScreen,_x,_y = World3dToScreen2d(x,y,z)
	SetTextFont(4)
	SetTextScale(0.35,0.35)
	SetTextColour(255,255,255,150)
	SetTextEntry("STRING")
	SetTextCentre(1)
	AddTextComponentString(text)
	DrawText(_x,_y)
	local factor = (string.len(text))/370
	DrawRect(_x,_y+0.0125,0.01+factor,0.03,0,0,0,80)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CONTADOR
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
	while true do
		local time = 1000
		if segundos > 0 then
			segundos = segundos - 1
			
			if segundos <= 0 then
				segundos = 0
			end

		end
		Citizen.Wait(time)
	end
end)