ESX = nil
local bancache,namecache = {},{}
local open_assists,active_assists = {},{}

function split(s, delimiter)result = {};for match in (s..delimiter):gmatch("(.-)"..delimiter) do table.insert(result, match) end return result end

Citizen.CreateThread(function() -- startup
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX==nil do Wait(0) end
    
    MySQL.ready(function()
        refreshNameCache()
    end)

    sendToDiscord("Starting logger...")

    print("[^1"..GetCurrentResourceName().."^7] Performing version check...")
    PerformHttpRequest("https://api.elipse458.me/resources/checkupdates.php", function(a,b,c)
        local data = json.decode(b)
        if a~=200 then
            print("[^1"..GetCurrentResourceName().."^7] Version check failed!")
        else
            if data and data.updateNeeded then
                print("[^1"..GetCurrentResourceName().."^7] Outdated!")
                print("[^1"..GetCurrentResourceName().."^7] Current version: 1.7 | New version: "..data.newVersion.." | Versions behind: "..data.versionsBehind)
                print("[^1"..GetCurrentResourceName().."^7] Changelog:")
                for k,v in ipairs(data.update.changelog) do
                    print("- "..v)
                end
                print("[^1"..GetCurrentResourceName().."^7] Database update needed: "..(data.update.dbUpdateNeeded and "^4Yes^7" or "^1No^7"))
                print("[^1"..GetCurrentResourceName().."^7] Config update needed: "..(data.update.configUpdateNeeded and "^4Yes^7" or "^1No^7"))
                print("[^1"..GetCurrentResourceName().."^7] Update url: ^4"..data.update.releaseUrl.."^7")
                if (type(data.versionsBehind)=="string" or data.versionsBehind>1) and data.update.dbUpdateNeeded then
                    print("[^1"..GetCurrentResourceName().."^7] ^1!!^7 You are multiple versions behind, make sure you run update sql files (if any) from all new versions in order of release ^1!!^7")
                end
                sendToDiscord("Update found!\nUpdate url: "..data.update.releaseUrl.."\nCurrent version: 1.7\nNew version: "..data.newVersion.."\nVersions behind: "..data.versionsBehind)
            else
                print("[^1"..GetCurrentResourceName().."^7] No updates found!")
            end
        end
    end, "POST", "resname=el_bwh&ver=1.7")
end)

AddEventHandler("playerConnecting",function(name, setKick, def)
    local identifiers = GetPlayerIdentifiers(source)
    if #identifiers>0 and identifiers[1]~=nil then
        local banned, data = isBanned(identifiers)
        namecache[identifiers[1]]=GetPlayerName(source)
        if banned then
            print(("[^1"..GetCurrentResourceName().."^7] Banned player %s (%s) tried to join, their ban expires on %s (Ban ID: #%s)"):format(GetPlayerName(source),data.receiver[1],data.length and os.date("%Y-%m-%d %H:%M",data.length) or "PERMANENT",data.id))
            local kickmsg = Config.banformat:format(data.reason,data.length and os.date("%Y-%m-%d %H:%M",data.length) or "PERMANENT",data.sender_name,data.id)
            if Config.backup_kick_method then DropPlayer(source,kickmsg) else def.done(kickmsg) end
        else
            local data = {["@name"]=GetPlayerName(source)}
            for k,v in ipairs(identifiers) do
                data["@"..split(v,":")[1]]=v
            end
            if not data["@steam"] then
                print("[^1"..GetCurrentResourceName().."^7] Player connecting without steamid, skipping identifier storage")
            else
                MySQL.Async.execute("INSERT INTO `bwh_identifiers` (`steam`, `license`, `ip`, `name`, `xbl`, `live`, `discord`, `fivem`) VALUES (@steam, @license, @ip, @name, @xbl, @live, @discord, @fivem) ON DUPLICATE KEY UPDATE `license`=@license, `ip`=@ip, `name`=@name, `xbl`=@xbl, `live`=@live, `discord`=@discord, `fivem`=@fivem",data)
            end
        end
    else
        if Config.backup_kick_method then DropPlayer(source,"[BWH] No identifiers were found when connecting, please reconnect") else def.done("[BWH] No identifiers were found when connecting, please reconnect") end
    end
end)

AddEventHandler("playerDropped",function(reason)
    if open_assists[source] then open_assists[source]=nil end
    for k,v in ipairs(active_assists) do
        if v==source then
            active_assists[k]=nil
            TriggerClientEvent("chat:addMessage",k,{color={255,0,0},multiline=false,args={"BWH","O admin que te ajudava desconectou-se!"}})
            return
        elseif k==source then
            TriggerClientEvent("el_bwh:assistDone",v)
            TriggerClientEvent("chat:addMessage",v,{color={255,0,0},multiline=false,args={"BWH","O jjogador que ajudavas desconectou-se! TP de volta..."}})
            active_assists[k]=nil
            return
        end
    end
end)

function refreshNameCache()
    namecache={}
    for k,v in ipairs(MySQL.Sync.fetchAll("SELECT steam,name FROM bwh_identifiers")) do
        namecache[v.steam]=v.name
    end
end

function sendToDiscord(msg)
    if Config.discord_webhook~=nil then
        PerformHttpRequest(Config.discord_webhook, function(a,b,c)end, "POST", json.encode({embeds={{title="BWH Action Log",description=msg:gsub("%^%d",""),color=65280,}}}), {["Content-Type"]="application/json"})
    end
end

function logAdmin(msg)
    for k,v in ipairs(ESX.GetPlayers()) do
        if isAdmin(ESX.GetPlayerFromId(v)) then
            TriggerClientEvent("chat:addMessage",v,{color={255,0,0},multiline=false,args={"BWH",msg}})
            sendToDiscord(msg)
        end
    end
end


function isBanned(identifiers)
    for _,ban in ipairs(bancache) do
        if not ban.unbanned and (ban.length==nil or ban.length>os.time()) then
            for _,bid in ipairs(ban.receiver) do
                for _,pid in ipairs(identifiers) do
                    if bid==pid then return true, ban end
                end
            end
        end
    end
    return false, nil
end

function isAdmin(xPlayer)
    for k,v in ipairs(Config.admin_groups) do
        if xPlayer.getGroup()==v then return true end
    end
    return false
end

function execOnAdmins(func)
    local ac = 0
    for k,v in ipairs(ESX.GetPlayers()) do
        if isAdmin(ESX.GetPlayerFromId(v)) then
            ac = ac + 1
            func(v)
        end
    end
    return ac
end

--Assist--
TriggerEvent('es:addCommand', 'assist', function(source, args, user)
    local reason = table.concat(args," ")
    if reason=="" or not reason then TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Por favor, especifique uma razão."}}); return end
    if not open_assists[source] and not active_assists[source] then
        local ac = execOnAdmins(function(admin) TriggerClientEvent("el_bwh:requestedAssist",admin,source); TriggerClientEvent("chat:addMessage",admin,{color={0,255,255},multiline=Config.chatassistformat:find("\n")~=nil,args={"BWH",Config.chatassistformat:format(GetPlayerName(source),source,reason)}}) end)
        if ac>0 then
            open_assists[source]=reason
            Citizen.SetTimeout(120000,function()
                if open_assists[source] then open_assists[source]=nil end
                if GetPlayerName(source)~=nil then
                    TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Seu pedido de ajuda expirou-se!"}})
                end
            end)
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"BWH","Pedido de ajuda (expira em 120s), escreve ^1/cassist^7 para cancelar pedido"}})
        else
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não há admins no server!"}})
        end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Já estão a ajudar-te ou tens um pedido de ajuda pendente."}})
    end
end)

TriggerEvent('es:addCommand', 'cassist', function(source, args, user)
    if open_assists[source] then
        open_assists[source]=nil
        TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"BWH","O seu pedido foi cancelado com sucesso!"}})
        execOnAdmins(function(admin) TriggerClientEvent("el_bwh:hideAssistPopup",admin) end)
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não tens pedidos de ajuda pendentes!"}})
    end
end)

TriggerEvent('es:addCommand', 'finassist', function(source, args, user)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
        local found = false
        for k,v in pairs(active_assists) do
            if v==source then
                found = true
                active_assists[k]=nil
                TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"BWH","Assistência finalizada, TP de volta."}})
                TriggerClientEvent("el_bwh:assistDone",source)
            end
        end
        if not found then TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não estás a ajudar ninguém."}}) end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não tens permissões para este comando!"}})
    end
end)

TriggerEvent('es:addCommand', 'bwh', function(source, args, user)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
        if args[1]=="refresh" then
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"BWH","Refreshing name cache..."}})
            refreshNameCache()
        elseif args[1]=="assists" then
            local openassistsmsg,activeassistsmsg = "",""
            for k,v in pairs(open_assists) do
                openassistsmsg=openassistsmsg.."^5ID "..k.." ("..GetPlayerName(k)..")^7 - "..v.."\n"
            end
            for k,v in pairs(active_assists) do
                activeassistsmsg=activeassistsmsg.."^5ID "..k.." ("..GetPlayerName(k)..")^7 - "..v.." ("..GetPlayerName(v)..")\n"
            end
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=true,args={"BWH","Assistências pendentes:\n"..(openassistsmsg~="" and openassistsmsg or "^1Sem assistências pendentes")}})
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=true,args={"BWH","Assistências ativas:\n"..(activeassistsmsg~="" and activeassistsmsg or "^1Sem assistências ativas")}})
        else
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Inválido sub-comando! (^4ban^7,^4warn^7,^4banlist^7,^4warnlist^7,^4refresh^7)"}})
        end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não tens permissões para este comando!"}})
    end
end)

function acceptAssist(xPlayer,target)
    if isAdmin(xPlayer) then
        local source = xPlayer.source
        for k,v in pairs(active_assists) do
            if v==source then
                TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Já estás a ajudar alguém"}})
                return
            end
        end
        if open_assists[target] and not active_assists[target] then
            open_assists[target]=nil
            active_assists[target]=source
            TriggerClientEvent("el_bwh:acceptedAssist",source,target)
            TriggerClientEvent("el_bwh:hideAssistPopup",source)
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"BWH","Teletransportando jogador..."}})
        elseif not open_assists[target] and active_assists[target] and active_assists[target]~=source then
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Alguém já está ajudando este jogador!"}})
        else
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Jogador com este id não pediu ajuda!"}})
        end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"BWH","Não tens permissões para este comando!"}})
    end
end

TriggerEvent('es:addCommand', 'accassist', function(source, args, user)
    local xPlayer = ESX.GetPlayerFromId(source)
    local target = tonumber(args[1])
    acceptAssist(xPlayer,target)
end)

RegisterServerEvent("el_bwh:acceptAssistKey")
AddEventHandler("el_bwh:acceptAssistKey",function(target)
    if not target then return end
    local _source = source
    acceptAssist(ESX.GetPlayerFromId(_source),target)
end)
