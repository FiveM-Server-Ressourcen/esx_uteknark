--[[ GROWTH STAGES
     Stages are now derived from a continuous growth percentage (0-100).
     Models and visual metadata live here; timing is driven by the decay system.
--]]

-- ── Stage derivation ──────────────────────────────────────────────────────

function GetStageFromGrowth(pct)
    if     pct >= 100 then return 6
    elseif pct >= 80  then return 5
    elseif pct >= 60  then return 4
    elseif pct >= 40  then return 3
    elseif pct >= 20  then return 2
    else                   return 1 end
end

-- ── UI helpers ────────────────────────────────────────────────────────────

-- Returns a Unicode block progress bar string
function MakeBar(pct, width)
    width   = width or 10
    pct     = math.max(0, math.min(100, pct))
    local n = math.floor(pct / 100 * width + 0.5)
    return string.rep('█', n) .. string.rep('░', width - n)
end

-- ── Model resolution ──────────────────────────────────────────────────────

function GetPlantModel(strain, stage)
    local s = Config.Strains[strain]
    if not s then return `prop_mp_cone_01` end
    local key = (stage <= 4) and 'prop_young' or 'prop_mature'
    return s[key] or `prop_mp_cone_01`
end

-- ── Visual stage table ────────────────────────────────────────────────────

local Colors = {
    Seedling = {  80, 200, 120, 170 },
    Growing  = {  40, 180, 255, 170 },
    Mature   = { 120, 220,  60, 170 },
    Ready    = { 255, 180,  30, 180 },
}

Growth = {
    [1] = { -- 0-20 % – Seedling
        model_key = 'prop_young',
        offset    = vector3(0, 0, -1.0),
        marker    = { offset = vector3(0, 0, 0.05), color = Colors.Seedling },
    },
    [2] = { -- 20-40 % – Young
        model_key = 'prop_young',
        offset    = vector3(0, 0, -0.8),
        marker    = { offset = vector3(0, 0, 0.30), color = Colors.Growing },
    },
    [3] = { -- 40-60 % – Growing
        model_key = 'prop_young',
        offset    = vector3(0, 0, -0.6),
        marker    = { offset = vector3(0, 0, 0.55), color = Colors.Growing },
    },
    [4] = { -- 60-80 % – Maturing
        model_key = 'prop_mature',
        offset    = vector3(0, 0, -0.4),
        marker    = { offset = vector3(0, 0, 0.80), color = Colors.Mature },
    },
    [5] = { -- 80-100 % – Almost ready
        model_key = 'prop_mature',
        offset    = vector3(0, 0, -0.2),
        marker    = { offset = vector3(0, 0, 1.05), color = Colors.Mature },
    },
    [6] = { -- 100 % – Harvestable
        model_key = 'prop_mature',
        offset    = vector3(0, 0,  0.0),
        marker    = { offset = vector3(0, 0, 1.80), color = Colors.Ready },
    },
}
