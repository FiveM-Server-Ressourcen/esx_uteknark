Config = {
    Locale = 'en-US',

    Distance = {
        Draw     = 150.0, -- Render distance for planted props (m)
        Interact = 2.0,   -- Interaction range (m)
        Space    = 1.5,   -- Minimum distance between planted plants (m)
    },

    SetLOD = false,

    -- ─────────────────────────────────────────────
    --  ITEMS
    -- ─────────────────────────────────────────────
    FlowerPot      = 'flower_pot',
    WaterItems     = { 'water_bottle', 'watering_can' },
    FertilizerItem = 'fertilizer',

    -- How much each action adds (0-100 scale)
    WaterPerAction = 30.0,   -- +30% water when player waters
    FertPerAction  = 35.0,   -- +35% fertilizer when player fertilizes

    -- ─────────────────────────────────────────────
    --  DECAY & GROWTH SYSTEM
    --  All rates are per real-world minute.
    -- ─────────────────────────────────────────────
    Decay = {
        TickInterval        = 60,   -- Server processes plants every N seconds
        WaterPerMinute      = 1.5,  -- % water lost per minute
        FertPerMinute       = 0.8,  -- % fertilizer lost per minute

        -- Health mechanics
        HealthThreshold     = 25,   -- avg care below this → health decays
        HealthGoodThreshold = 55,   -- avg care above this → health regens
        HealthDecayRate     = 2.0,  -- % health lost per minute when neglected
        HealthRegenRate     = 0.8,  -- % health gained per minute when well-cared
        MinHealthForGrowth  = 15,   -- plant must have > this health to grow

        -- Growth
        -- GrowthRateBase / timeMultiplier = actual rate at perfect care
        -- Default: 0.15 %/min → ~11 h at perfect care, longer with neglect
        GrowthRateBase      = 0.15,
    },

    -- ─────────────────────────────────────────────
    --  QUALITY SYSTEM  (internal, never shown to player)
    --  Accumulated as exponential moving average.
    -- ─────────────────────────────────────────────
    Quality = {
        WaterWeight  = 0.40,
        FertWeight   = 0.40,
        HealthWeight = 0.20,
        EmaAlpha     = 0.08,  -- smoothing factor (lower = slower to change)

        -- Quality affects wet-weed yield at harvest:
        -- actualYield = floor( baseYield * (MinYieldMult + quality * YieldRange) )
        MinYieldMult = 0.50,  -- worst quality gives 50% of max yield
        YieldRange   = 0.50,  -- best quality gives 100% of max yield
    },

    -- ─────────────────────────────────────────────
    --  DRYING SYSTEM
    -- ─────────────────────────────────────────────
    DryingTime = 300,  -- seconds for one drying session

    DryingStations = {
        { pos = vector3( 1135.2,  -470.2,  67.0), name = 'Warehouse District' },
        { pos = vector3(-1819.7,  801.0,  138.0), name = 'Paleto Bay Barn'    },
        { pos = vector3( 2565.6, 3806.2,  44.0 ), name = 'Sandy Shores'       },
    },

    -- ─────────────────────────────────────────────
    --  WEED STRAINS
    --  Add new strains here – nothing else to change.
    -- ─────────────────────────────────────────────
    Strains = {
        og_kush = {
            name           = 'OG Kush',
            seed           = 'og_kush_seed',
            wet_product    = 'wet_og_kush',   -- Item given on harvest
            dry_product    = 'weed_og_kush',  -- Item given after drying
            prop_young     = `prop_weed_02`,
            prop_mature    = `prop_weed_01`,
            timeMultiplier = 1.00,            -- 1.0 = standard speed
            yield          = { 3, 6 },        -- base wet-weed yield range
            seedReturn     = { 1, 3 },
        },
        purple_haze = {
            name           = 'Purple Haze',
            seed           = 'purple_haze_seed',
            wet_product    = 'wet_purple_haze',
            dry_product    = 'weed_purple_haze',
            prop_young     = `prop_weed_02`,
            prop_mature    = `prop_weed_01`,
            timeMultiplier = 0.80,            -- 20 % faster
            yield          = { 3, 5 },
            seedReturn     = { 1, 3 },
        },
        amnesia = {
            name           = 'Amnesia',
            seed           = 'amnesia_seed',
            wet_product    = 'wet_amnesia',
            dry_product    = 'weed_amnesia',
            prop_young     = `prop_weed_02`,
            prop_mature    = `prop_weed_01`,
            timeMultiplier = 1.25,            -- 25 % slower, better potential
            yield          = { 4, 7 },
            seedReturn     = { 1, 3 },
        },
        white_widow = {
            name           = 'White Widow',
            seed           = 'white_widow_seed',
            wet_product    = 'wet_white_widow',
            dry_product    = 'weed_white_widow',
            prop_young     = `prop_weed_02`,
            prop_mature    = `prop_weed_01`,
            timeMultiplier = 1.10,
            yield          = { 3, 6 },
            seedReturn     = { 1, 3 },
        },
    },

    -- ─────────────────────────────────────────────
    --  WILD WEED SYSTEM
    -- ─────────────────────────────────────────────
    WildWeed = {
        SpawnChance  = 0.65,
        RespawnTime  = 3600,  -- seconds before a spot can respawn
        CollectTime  = 6000,  -- ms for collection progress bar
        SeedReward   = { 1, 3 },

        StrainWeights = {
            { strain = 'og_kush',     weight = 40 },
            { strain = 'purple_haze', weight = 30 },
            { strain = 'amnesia',     weight = 20 },
            { strain = 'white_widow', weight = 10 },
        },

        StrainProps = {
            og_kush     = `prop_weed_01`,
            purple_haze = `prop_weed_01`,
            amnesia     = `prop_weed_01`,
            white_widow = `prop_weed_01`,
        },

        -- Add as many positions as you like: vector4(x, y, z, heading)
        Positions = {
            vector4(-1155.94, 4939.26, 221.65,   0.0),
            vector4(-1200.00, 4980.00, 225.00,  45.0),
            vector4(-1100.00, 4900.00, 220.00,  90.0),
            vector4( 2700.00, 3280.00,  55.00, 180.0),
            vector4( 2750.00, 3310.00,  57.00, 270.0),
            vector4( 1280.00, 6420.00,  35.00,   0.0),
            vector4( 1310.00, 6400.00,  34.00,  30.0),
            vector4(  400.00, 6510.00,  31.00,  60.0),
            vector4(  430.00, 6530.00,  31.50, 120.0),
            vector4( -350.00, 6210.00,  31.00, 200.0),
            vector4(  -70.00, 6220.00,  31.00, 330.0),
            vector4(  100.00, 6350.00,  31.00,  15.0),
            vector4( 2900.00, 3450.00,  58.00,  95.0),
            vector4( 2850.00, 3390.00,  56.00, 175.0),
            vector4(-1350.00, 4860.00, 225.00, 240.0),
        },
    },

    -- ─────────────────────────────────────────────
    --  ADMIN OVERVIEW  (/weedplants)
    -- ─────────────────────────────────────────────
    AdminBlips = {
        PlantSprite = 469,
        PlantColor  = 2,   -- GTA blip color: 2 = green
        PlantScale  = 0.8,
        WildSprite  = 469,
        WildColor   = 1,   -- GTA blip color: 1 = red
        WildScale   = 0.6,
    },

    -- ─────────────────────────────────────────────
    --  BURN EFFECT (when a plant is destroyed)
    -- ─────────────────────────────────────────────
    Burn = {
        Enabled    = true,
        Collection = 'scr_mp_house',
        Effect     = 'scr_mp_int_fireplace_sml',
        Scale      = 1.5,
        Rotation   = vector3(0, 0, 0),
        Offset     = vector3(0, 0, 0.2),
        Duration   = 20000,
    },
}
