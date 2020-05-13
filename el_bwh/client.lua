ESX = nil
local pos_before_assist,assisting,assist_target,last_assist = nil, false, nil, nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	SetNuiFocus(false, false)
end)

function GetIndexedPlayerList()
	local players = {}
	for k,v in ipairs(GetActivePlayers()) do
		players[tostring(GetPlayerServerId(v))]=GetPlayerName(v)..(v==PlayerId() and " (self)" or "")
	end
	return json.encode(players)
end

RegisterNUICallback("getListData", function(data,cb)
	if not data.list or not data.page then cb(nil); return end
	ESX.TriggerServerCallback("el_bwh:getListData",function(data)
		cb(data)
	end, data.list, data.page)
end)

RegisterNUICallback("hidecursor", function(data,cb)
	SetNuiFocus(false, false)
end)

--Request Assist--

RegisterNetEvent("el_bwh:requestedAssist")
AddEventHandler("el_bwh:requestedAssist",function(t)
	SendNUIMessage({show=true,window="assistreq",data=Config.popassistformat:format(GetPlayerName(GetPlayerFromServerId(t)),t)})
	last_assist=t
end)

RegisterNetEvent("el_bwh:acceptedAssist")
AddEventHandler("el_bwh:acceptedAssist",function(t)
	if assisting then return end
	local target = GetPlayerFromServerId(t)
	if target then
		local ped = GetPlayerPed(-1)
		pos_before_assist = GetEntityCoords(ped)
		assisting = true
		assist_target = t
		ESX.Game.Teleport(ped,GetEntityCoords(GetPlayerPed(target))+vector3(0,0.5,0))
	end
end)

RegisterNetEvent("el_bwh:assistDone")
AddEventHandler("el_bwh:assistDone",function()
	if assisting then
		assisting = false
		if pos_before_assist~=nil then ESX.Game.Teleport(GetPlayerPed(-1),pos_before_assist+vector3(0,0.5,0)); pos_before_assist = nil end
		assist_target = nil
	end
end)

RegisterNetEvent("el_bwh:hideAssistPopup")
AddEventHandler("el_bwh:hideAssistPopup",function(t)
	SendNUIMessage({hide=true})
	last_assist=nil
end)--END--

--Assit--
RegisterCommand("decassist",function(a,b,c)
	TriggerEvent("el_bwh:hideAssistPopup")
end, false)

if Config.assist_keys then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)
			if IsControlJustPressed(0, Config.assist_keys.accept) then
				if not last_assist then
					ESX.ShowNotification("~r~Ainda ninguém pediu ajuda!")
				elseif not NetworkIsPlayerActive(GetPlayerFromServerId(last_assist)) then
					ESX.ShowNotification("~r~Jogador que pediu ajuda já não se encontra online!")
					last_assist=nil
				else
					TriggerServerEvent("el_bwh:acceptAssistKey",last_assist)
				end
			end
			if IsControlJustPressed(0, Config.assist_keys.decline) then
				TriggerEvent("el_bwh:hideAssistPopup")
			end
		end
	end)
end

TriggerEvent('chat:addSuggestion', '/decassist', 'Esconder pedido de ajuda.',{})
TriggerEvent('chat:addSuggestion', '/assist', 'Pedir ajuda dos admins ',{{name="Razão", help="Porque precisas de ajuda?"}})
TriggerEvent('chat:addSuggestion', '/cassist', 'Cancelar pedido de ajuda.',{})
TriggerEvent('chat:addSuggestion', '/finassist', 'Assistência finalizada. TP de volta!',{})
TriggerEvent('chat:addSuggestion', '/accassist', 'Aceitar pedido de ajuda', {{name="Player ID", help="ID of the player you want to help"}})