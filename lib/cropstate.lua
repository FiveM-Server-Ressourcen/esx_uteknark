-- =========================================================
-- CROPSTATE — Datenhaltung für Weed-Pflanzen
-- Läuft auf Client und Server (shared script).
-- =========================================================

local onServer = IsDuplicityVersion()

local cropstateMethods = {

    -- Neue Pflanze in DB einfügen (nur Server)
    plant = function(instance, location, strain, stage)
        if not onServer then
            Citizen.Trace("cropstate:plant darf nur auf dem Server aufgerufen werden.\n")
            return
        end
        stage = stage or 1
        MySQL.Async.insert(
            "INSERT INTO `uteknark` (`x`,`y`,`z`,`strain`,`stage`,`water_count`,`fertilizer_count`) VALUES (@x,@y,@z,@strain,@stage,0,0);",
            {
                ['@x']      = location.x,
                ['@y']      = location.y,
                ['@z']      = location.z,
                ['@strain'] = strain,
                ['@stage']  = stage,
            },
            function(id)
                instance:import(id, location, strain, stage, os.time(), 0, 0)
                TriggerClientEvent('esx_uteknark:planted', -1, id, location, strain, stage)
                verbose('Pflanze', id, 'wurde gepflanzt (', strain, ')')
            end
        )
    end,

    -- Alle Pflanzen aus DB laden (nur Server)
    load = function(instance, callback)
        if not onServer then
            Citizen.Trace("cropstate:load darf nur auf dem Server aufgerufen werden.\n")
            return
        end
        verbose('Lade Pflanzen aus Datenbank...')
        MySQL.Async.fetchAll(
            "SELECT `id`, `strain`, `stage`, UNIX_TIMESTAMP(`time`) AS `time`, `x`, `y`, `z`, `water_count`, `fertilizer_count` FROM `uteknark`;",
            {},
            function(rows)
                Citizen.CreateThread(function()
                    for rownum, row in ipairs(rows) do
                        instance:import(
                            row.id,
                            vector3(row.x, row.y, row.z),
                            row.strain or 'og_kush',
                            row.stage,
                            row.time,
                            row.water_count or 0,
                            row.fertilizer_count or 0
                        )
                        if rownum % 50 == 0 then
                            Citizen.Wait(0)
                        end
                    end
                    if callback then callback(#rows) end
                    instance.loaded = true
                    verbose('Laden abgeschlossen')
                end)
            end
        )
    end,

    -- Pflanze in Octree + Index eintragen (Client & Server)
    import = function(instance, id, location, strain, stage, time, waterCount, fertCount)
        local success, object = instance.octree:insert(location, 0.01, {
            id                 = id,
            strain             = strain or 'og_kush',
            stage              = stage,
            time               = time,
            water_count        = waterCount or 0,
            fertilizer_count   = fertCount  or 0,
        })
        if not success then
            Citizen.Trace(string.format("UteKnark: Pflanze %i konnte nicht in Octree eingefügt werden\n", id))
        end
        instance.index[id] = object
    end,

    -- Stage einer Pflanze aktualisieren
    update = function(instance, id, stage)
        local plant = instance.index[id]
        if not plant then return end
        plant.data.stage = stage
        if onServer then
            plant.data.time = os.time()
            MySQL.Async.execute(
                "UPDATE `uteknark` SET `stage`=@stage, `time`=NOW() WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id, ['@stage'] = stage },
                function()
                    TriggerClientEvent('esx_uteknark:update', -1, id, stage)
                    verbose('Pflanze', id, 'auf Stage', stage, 'gesetzt')
                end
            )
        else
            -- Client: altes Objekt löschen damit es neu gespawnt wird
            if plant.data.object and DoesEntityExist(plant.data.object) then
                DeleteObject(plant.data.object)
            end
            plant.data.object = nil
        end
    end,

    -- Bewässerungszähler erhöhen
    water = function(instance, id)
        local plant = instance.index[id]
        if not plant then return end
        plant.data.water_count = (plant.data.water_count or 0) + 1
        if onServer then
            MySQL.Async.execute(
                "UPDATE `uteknark` SET `water_count`=@wc WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id, ['@wc'] = plant.data.water_count },
                function()
                    TriggerClientEvent('esx_uteknark:updateCare', -1, id, plant.data.water_count, plant.data.fertilizer_count)
                end
            )
        end
    end,

    -- Düngungszähler erhöhen
    fertilize = function(instance, id)
        local plant = instance.index[id]
        if not plant then return end
        plant.data.fertilizer_count = (plant.data.fertilizer_count or 0) + 1
        if onServer then
            MySQL.Async.execute(
                "UPDATE `uteknark` SET `fertilizer_count`=@fc WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id, ['@fc'] = plant.data.fertilizer_count },
                function()
                    TriggerClientEvent('esx_uteknark:updateCare', -1, id, plant.data.water_count, plant.data.fertilizer_count)
                end
            )
        end
    end,

    -- Pflanze entfernen
    remove = function(instance, id, withPyro)
        local object = instance.index[id]
        if not object then return end
        local location = object.bounds.location
        object.data.deleted = true
        if object.node then
            object.node:remove(object.oindex)
        end
        instance.index[id] = nil
        if onServer then
            MySQL.Async.execute(
                "DELETE FROM `uteknark` WHERE `id`=@id LIMIT 1;",
                { ['@id'] = id },
                function()
                    TriggerClientEvent('esx_uteknark:removePlant', -1, id)
                    if withPyro then
                        TriggerClientEvent('esx_uteknark:pyromaniac', -1, location)
                    end
                    verbose('Pflanze', id, 'entfernt')
                end
            )
        else
            if object.data.object and DoesEntityExist(object.data.object) then
                DeleteObject(object.data.object)
            end
            object.data.object = nil
        end
    end,

    -- Alle Pflanzendaten an Client(s) senden
    bulkData = function(instance, target)
        if onServer then
            verbose('Sende Pflanzendaten an Spieler', target)
            target = target or -1
            while not instance.loaded do
                Citizen.Wait(1000)
            end
            local forest = {}
            for id, plant in pairs(instance.index) do
                if type(id) == 'number' then
                    table.insert(forest, {
                        id               = id,
                        location         = plant.bounds.location,
                        strain           = plant.data.strain,
                        stage            = plant.data.stage,
                        water_count      = plant.data.water_count,
                        fertilizer_count = plant.data.fertilizer_count,
                    })
                end
            end
            TriggerClientEvent('esx_uteknark:bulk_data', target, forest)
        else
            TriggerServerEvent('esx_uteknark:request_data')
        end
    end,
}

local cropstateMeta = {
    __newindex = function(instance, key, value) end,
    __index    = function(instance, key)
        return instance._methods[key]
    end,
}

cropstate = {
    index    = { hashtable = true },
    octree   = pOctree(vector3(0, 1500, 0), vector3(12000, 13000, 2000)),
    loaded   = false,
    _methods = cropstateMethods,
}

setmetatable(cropstate, cropstateMeta)

-- =========================================================
-- Netzwerk-Events
-- =========================================================
if onServer then

    RegisterNetEvent('esx_uteknark:request_data')
    AddEventHandler('esx_uteknark:request_data', function()
        cropstate:bulkData(source)
    end)

    RegisterNetEvent('esx_uteknark:remove')
    AddEventHandler('esx_uteknark:remove', function(plantID, nearLocation)
        local src   = source
        local plant = cropstate.index[plantID]
        if plant then
            local dist = #(nearLocation - plant.bounds.location)
            if dist <= Config.Distance.Interact + 1.0 then
                cropstate:remove(plantID, true)
                TriggerClientEvent('ox_lib:notify', src, {
                    description = 'Pflanze vernichtet.',
                    type        = 'success',
                })
            else
                Citizen.Trace(GetPlayerName(src) .. ' ist zu weit von Pflanze ' .. plantID .. ' entfernt (' .. dist .. 'm)\n')
            end
        else
            TriggerClientEvent('esx_uteknark:removePlant', src, plantID)
        end
    end)

else
    -- Client-side Events

    RegisterNetEvent('esx_uteknark:bulk_data')
    AddEventHandler('esx_uteknark:bulk_data', function(forest)
        for _, plant in ipairs(forest) do
            cropstate:import(plant.id, plant.location, plant.strain, plant.stage, nil, plant.water_count, plant.fertilizer_count)
        end
        cropstate.loaded = true
    end)

    RegisterNetEvent('esx_uteknark:planted')
    AddEventHandler('esx_uteknark:planted', function(id, location, strain, stage)
        cropstate:import(id, location, strain, stage, nil, 0, 0)
    end)

    RegisterNetEvent('esx_uteknark:update')
    AddEventHandler('esx_uteknark:update', function(plantID, stage)
        cropstate:update(plantID, stage)
    end)

    RegisterNetEvent('esx_uteknark:updateCare')
    AddEventHandler('esx_uteknark:updateCare', function(plantID, waterCount, fertCount)
        local plant = cropstate.index[plantID]
        if plant then
            plant.data.water_count      = waterCount
            plant.data.fertilizer_count = fertCount
        end
    end)

    RegisterNetEvent('esx_uteknark:removePlant')
    AddEventHandler('esx_uteknark:removePlant', function(plantID)
        cropstate:remove(plantID)
    end)
end
