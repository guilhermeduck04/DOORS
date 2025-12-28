local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP")

src = {}
Tunnel.bindInterface("doors",src)
Proxy.addInterface("doors",src)

vCLIENT = Tunnel.getInterface("doors")
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local trancas = {}

function src.syncLock(area, status, permissao)
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        if vRP.hasPermission(user_id, permissao) then
            vCLIENT.setLock(-1, area, status)
            trancas[area] = status
            return true
        else
            TriggerClientEvent("Notify",source,"negado","Você não possui a chave dessa fechadura", 5)
        end
    end
end

AddEventHandler("vRP:playerSpawn",function(user_id,source,first_spawn)
	if first_spawn then
        if user_id then
            for k,v in pairs(trancas) do
                vCLIENT.setLock(source, k, v)
            end
        end
	end
end)

