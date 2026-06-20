-- =========================================================
-- SERVER — ESX UteKnark Extended
-- =========================================================

local ESX         = nil
local VERBOSE     = false
local lastPlant   = {}  -- Anti-Spam: source -> timestamp
local tickTimes   = {}
local tickPlantCount = 0
local VERSION     = '2.0.0'

-- =========================================================
-- Logging
-- =========================================================

function log(...)
    local elements = { ... }
    local line = ''
    for _, v in ipairs(elements) do
        line = line .. ' ' .. tostring(v)
    end
    Citizen.Trace('[' .. os.date('%H:%M:%S') .. '] <' .. GetCurrentResourceName() .. '>' .. line .. '\n')
end

function verbose(...)
    if VERBOSE then log(...) end
end

-- =========================================================
-- Spieler-Inventar-Helfer
-- =========================================================

function HasItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xPlayer = ESX.GetPlayerFromId(who)
    if not xPlayer then return false end
    local item = xPlayer.getInventoryItem(what)
    return item ~= nil and item.count >= count
end

-- Prüfe ob Spieler eines der WaterItems besitzt; gibt Item-Name zurück oder nil
function HasWaterItem(who)
    if not ESX then return nil end
    local xPlayer = ESX.GetPlayerFromId(who)
    if not xPlayer then return nil end
    for _, itemName in ipairs(Config.WaterItems) do
        local item = xPlayer.getInventoryItem(itemName)
        if item and item.count >= 1 then
            return itemName
        end
    end
    return nil
end

function TakeItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xPlayer = ESX.GetPlayerFromId(who)
    if not xPlayer then return false end
    local item = xPlayer.getInventoryItem(what)
    if item and item.count >= count then
        xPlayer.removeInventoryItem(what, count)
        return true
    end
    return false
end

function GiveItem(who, what, count)
    count = count or 1
    if not ESX then return false end
    local xPlayer = ESX.GetPlayerFromId(who)
    if not xPlayer then return false end
    local item = xPlayer.getInventoryItem(what)
    if item then
        if not item.limit or item.limit == -1 or item.count + count <= item.limit then
            xPlayer.addInventoryItem(what, count)
            return true
        end
    else
        log('GiveItem: Item', what, 'existiert nicht in ESX!')
    end
    return false
end

-- ox_lib Notification an Spieler
function notify(target, description, notifyType, title)
    notifyType = notifyType or 'inform'
    TriggerClientEvent('ox_lib:notify', target, {
        title       = title or 'Weed',
        description = description,
        type        = notifyType,
        duration    = 4000,
    })
end

-- =========================================================
-- Pflanzqualität berechnen
-- =========================================================

function calcQuality(waterCount, fertCount)
    waterCount = waterCount or 0
    fertCount  = fertCount  or 0

    local waterStars = 1
    for stars = 5, 2, -1 do
        if waterCount >= Config.Quality.Water[stars] then
            waterStars = stars
            break
        end
    end

    local fertStars = 1
    for stars = 5, 2, -1 do
        if fertCount >= Config.Quality.Fertilizer[stars] then
            fertStars = stars
            break
        end
    end

    return math.min(5, math.max(1, math.floor((waterStars + fertStars) / 2)))
end

function qualityLabel(stars)
    local labels = {
        [1] = '★☆☆☆☆  Schlecht',
        [2] = '★★☆☆☆  Mäßig',
        [3] = '★★★☆☆  Normal',
        [4] = '★★★★☆  Gut',
        [5] = '★★★★★  Perfekt',
    }
    return labels[stars] or '★☆☆☆☆'
end

-- =========================================================
-- Pflanzfunktion
-- =========================================================

function plantSeed(location, strain)
    local hits = cropstate.octree:searchSphere(location, Config.Distance.Space)
    if #hits > 0 then return false end
    cropstate:plant(location, strain)
    return true
end

-- =========================================================
-- Pflanzen (Server-Event vom Client)
-- =========================================================

RegisterNetEvent('esx_uteknark:success_plant')
AddEventHandler('esx_uteknark:success_plant', function(location, strainKey)
    local src        = source
    local strainData = Config.Strains[strainKey]

    if not strainData then
        notify(src, 'Unbekannte Weed-Sorte.', 'error')
        return
    end

    -- Anti-Spam
    local now  = os.time()
    local last = lastPlant[src] or 0
    if now < last + 5 then
        notify(src, 'Bitte warte einen Moment.', 'error')
        return
    end
    lastPlant[src] = now

    -- Distanz-Sicherheitscheck
    local ped  = GetPlayerPed(src)
    local dist = #(GetEntityCoords(ped) - location)
    if dist > Config.Distance.Interact + 3.0 then
        log(GetPlayerName(src), 'pflanzte aus', string.format('%.1fm', dist), '— möglicherweise Cheat')
        return
    end

    -- Samen prüfen
    if not HasItem(src, strainData.seed) then
        notify(src, 'Du hast keine ' .. strainData.name .. ' Samen.', 'error')
        return
    end

    -- Blumentopf prüfen
    if not HasItem(src, Config.FlowerPot) then
        notify(src, 'Du benötigst einen Blumentopf zum Pflanzen.', 'error')
        return
    end

    -- Nochmal Platz prüfen (Server-Seite)
    local hits = cropstate.octree:searchSphere(location, Config.Distance.Space)
    if #hits > 0 then
        notify(src, 'Zu nah an einer anderen Pflanze!', 'error')
        return
    end

    -- Items abziehen und pflanzen
    TakeItem(src, strainData.seed, 1)
    TakeItem(src, Config.FlowerPot, 1)

    if plantSeed(location, strainKey) then
        notify(src, strainData.name .. ' erfolgreich gepflanzt!', 'success')
        log(GetPlayerName(src), 'pflanzte', strainData.name, 'an', tostring(location))
    else
        -- Rückgabe falls etwas schiefging
        GiveItem(src, strainData.seed, 1)
        GiveItem(src, Config.FlowerPot, 1)
        notify(src, 'Fehler beim Pflanzen.', 'error')
    end
end)

-- =========================================================
-- Gießen
-- =========================================================

RegisterNetEvent('esx_uteknark:waterPlant')
AddEventHandler('esx_uteknark:waterPlant', function(plantID, nearLocation)
    local src   = source
    local plant = cropstate.index[plantID]
    if not plant then
        notify(src, 'Pflanze nicht gefunden.', 'error')
        return
    end

    local dist = #(nearLocation - plant.bounds.location)
    if dist > Config.Distance.Interact + 1.0 then
        log(GetPlayerName(src), 'ist zu weit von Pflanze', plantID, 'entfernt')
        return
    end

    local waterItem = HasWaterItem(src)
    if not waterItem then
        notify(src, 'Du hast kein Wasser dabei! (' .. table.concat(Config.WaterItems, ', ') .. ')', 'error')
        return
    end

    TakeItem(src, waterItem, 1)
    cropstate:water(plantID)

    local plant2 = cropstate.index[plantID]
    if plant2 then
        notify(src, 'Pflanze gegossen. (Gesamt: ' .. (plant2.data.water_count or 1) .. '×)', 'success')
    else
        notify(src, 'Pflanze gegossen.', 'success')
    end
end)

-- =========================================================
-- Düngen
-- =========================================================

RegisterNetEvent('esx_uteknark:fertilizePlant')
AddEventHandler('esx_uteknark:fertilizePlant', function(plantID, nearLocation)
    local src   = source
    local plant = cropstate.index[plantID]
    if not plant then
        notify(src, 'Pflanze nicht gefunden.', 'error')
        return
    end

    local dist = #(nearLocation - plant.bounds.location)
    if dist > Config.Distance.Interact + 1.0 then
        log(GetPlayerName(src), 'ist zu weit von Pflanze', plantID, 'entfernt')
        return
    end

    if not HasItem(src, Config.FertilizerItem) then
        notify(src, 'Du hast keinen Dünger dabei!', 'error')
        return
    end

    TakeItem(src, Config.FertilizerItem, 1)
    cropstate:fertilize(plantID)

    local plant2 = cropstate.index[plantID]
    if plant2 then
        notify(src, 'Pflanze gedüngt. (Gesamt: ' .. (plant2.data.fertilizer_count or 1) .. '×)', 'success')
    else
        notify(src, 'Pflanze gedüngt.', 'success')
    end
end)

-- =========================================================
-- Ernten
-- =========================================================

RegisterNetEvent('esx_uteknark:harvestPlant')
AddEventHandler('esx_uteknark:harvestPlant', function(plantID, nearLocation)
    local src   = source
    local plant = cropstate.index[plantID]
    if not plant then
        notify(src, 'Pflanze nicht gefunden.', 'error')
        return
    end

    local dist = #(nearLocation - plant.bounds.location)
    if dist > Config.Distance.Interact + 1.0 then
        log(GetPlayerName(src), 'ist zu weit von Pflanze', plantID, 'entfernt')
        return
    end

    local strainKey  = plant.data.strain
    local strainData = Config.Strains[strainKey]
    if not strainData then
        notify(src, 'Unbekannte Sorte.', 'error')
        return
    end

    if not IsHarvestStage(strainKey, plant.data.stage) then
        notify(src, 'Die Pflanze ist noch nicht erntereif!', 'error')
        return
    end

    -- Qualität berechnen
    local quality  = calcQuality(plant.data.water_count, plant.data.fertilizer_count)
    local stars    = qualityLabel(quality)

    -- Ertrag (Qualität beeinflusst keine Menge, aber das Produkt-Item trägt Qualitätsnamen)
    local yield    = math.random(strainData.yield[1], strainData.yield[2])
    local seedRet  = math.random(strainData.seedReturn[1], strainData.seedReturn[2])

    -- Produkt geben
    if not GiveItem(src, strainData.product, yield) then
        notify(src, 'Dein Inventar ist voll!', 'error')
        return
    end

    -- Samen zurückgeben
    local seedsGiven = 0
    if seedRet > 0 and GiveItem(src, strainData.seed, seedRet) then
        seedsGiven = seedRet
    end

    cropstate:remove(plantID)
    TriggerClientEvent('esx_uteknark:pyromaniac', -1, plant.bounds.location)

    local msg = string.format(
        '%s geerntet!\nErnte: %d× Weed | Samen: %d× zurück\nQualität: %s',
        strainData.name, yield, seedsGiven, stars
    )
    notify(src, msg, 'success', 'Ernte')
    log(GetPlayerName(src), 'erntete', strainData.name, '| Ertrag:', yield, '| Samen:', seedsGiven, '| Qualität:', quality)
end)

-- =========================================================
-- Wild Weed Samen einsammeln
-- =========================================================

RegisterNetEvent('esx_uteknark:collectWildSeed')
AddEventHandler('esx_uteknark:collectWildSeed', function(strainKey)
    local src        = source
    local strainData = Config.Strains[strainKey]
    if not strainData then
        notify(src, 'Unbekannte Sorte.', 'error')
        return
    end

    if GiveItem(src, strainData.seed, 1) then
        notify(src, strainData.name .. ' Samen eingesammelt!', 'success', 'Wild Weed')
        log(GetPlayerName(src), 'sammelte wilden', strainData.name, 'Samen')
    else
        notify(src, 'Dein Inventar ist voll!', 'error')
    end
end)

-- =========================================================
-- Server-Tick: Wachstum
-- =========================================================

AddEventHandler('playerDropped', function()
    lastPlant[source] = nil
end)

Citizen.CreateThread(function()
    -- ESX laden
    local ESXTries = 60
    while ESXTries > 0 do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
        end)
        if ESX and next(ESX.Items) ~= nil then break end
        Citizen.Wait(1000)
        ESXTries = ESXTries - 1
    end
    if not ESX then
        log('KRITISCH: ESX-Objekt konnte nicht geladen werden!')
        return
    end
    log('ESX geladen.')

    -- Alle Samen-Items registrieren
    for strainKey, strainData in pairs(Config.Strains) do
        local seedItem = strainData.seed
        if ESX.Items[seedItem] then
            ESX.RegisterUsableItem(seedItem, function(src)
                local now  = os.time()
                local last = lastPlant[src] or 0
                if now < last + 3 then
                    notify(src, 'Bitte warte einen Moment.', 'error')
                    return
                end
                if HasItem(src, seedItem) then
                    TriggerClientEvent('esx_uteknark:attempt_plant', src, strainKey)
                    lastPlant[src] = now
                else
                    notify(src, 'Du hast keine ' .. strainData.name .. ' Samen.', 'error')
                end
            end)
            log('Usable Item registriert:', seedItem, '(', strainData.name, ')')
        else
            log('WARNUNG: Item', seedItem, 'existiert nicht in ESX! Bitte in der Datenbank anlegen.')
        end
    end
end)

Citizen.CreateThread(function()
    -- Warten bis MySQL bereit
    while GetResourceState('mysql-async') ~= 'started' do
        Citizen.Wait(500)
    end
    Citizen.Wait(500)
    cropstate:load(function(count)
        log('Geladen:', count, 'Pflanzen')
    end)

    -- Wachstums-Tick
    while true do
        Citizen.Wait(0)
        local now   = os.time()
        local begin = GetGameTimer()
        local count = 0

        for id, plant in pairs(cropstate.index) do
            if type(id) == 'number' then
                local strainKey  = plant.data.strain
                local strainData = Config.Strains[strainKey]
                if strainData then
                    local stageData = strainData.stages[plant.data.stage]
                    if stageData and not stageData.harvest then
                        local growthSecs = stageData.time * 60 * Config.TimeMultiplier
                        local relevantTime = plant.data.time + growthSecs
                        if now >= relevantTime then
                            local nextStage = plant.data.stage + 1
                            if nextStage <= #strainData.stages then
                                verbose('Pflanze', id, '(', strainKey, ') wächst auf Stage', nextStage)
                                cropstate:update(id, nextStage)
                            else
                                verbose('Pflanze', id, 'hat keine weiteren Stages')
                                cropstate:remove(id)
                            end
                        end
                    end
                end
                count = count + 1
                if count % 10 == 0 then Citizen.Wait(0) end
            end
        end

        tickPlantCount = count
        local tickTime = GetGameTimer() - begin
        table.insert(tickTimes, tickTime)
        while #tickTimes > 20 do table.remove(tickTimes, 1) end

        Citizen.Wait(10000) -- Alle 10 Sekunden prüfen
    end
end)

-- =========================================================
-- Admin-Befehle
-- =========================================================

local function inChat(target, message)
    if target == 0 then
        log(message)
    else
        TriggerClientEvent('chat:addMessage', target, { args = { 'UteKnark', message } })
    end
end

local commands = {
    debug = function(src)
        if src == 0 then log('Debug nur für Clients.') return end
        TriggerClientEvent('esx_uteknark:toggle_debug', src)
        inChat(src, 'Debug toggled.')
    end,

    stats = function(src)
        if #tickTimes == 0 then inChat(src, 'Noch keine Tick-Daten.') return end
        local total = 0
        for _, t in ipairs(tickTimes) do total = total + t end
        inChat(src, string.format('Tick avg: %.1fms | Pflanzen: %d', total / #tickTimes, tickPlantCount))
    end,

    strains = function(src)
        inChat(src, 'Verfügbare Sorten:')
        for key, data in pairs(Config.Strains) do
            inChat(src, string.format('  %s → Samen: %s | Produkt: %s', data.name, data.seed, data.product))
        end
    end,

    verbose = function(src)
        VERBOSE = not VERBOSE
        inChat(src, 'Verbose: ' .. tostring(VERBOSE))
    end,
}

RegisterCommand('uteknark', function(src, args)
    if #args == 0 then
        inChat(src, 'UteKnark v' .. VERSION .. ' | Befehle: debug, stats, strains, verbose')
        return
    end
    local directive = string.lower(args[1])
    if commands[directive] then
        commands[directive](src)
    else
        inChat(src, 'Unbekannter Befehl: ' .. directive)
    end
end, true)
