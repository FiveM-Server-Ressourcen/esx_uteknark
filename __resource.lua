resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'
description 'ESX UteKnark – Dynamic Weed Growing System v3'

dependencies { 'es_extended', 'mysql-async', 'ox_lib' }

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'lib/octree.lua',
    'lib/growth.lua',
    'lib/cropstate.lua',
}

client_scripts {
    'lib/debug.lua',
    'cl_uteknark.lua',
    'cl_wildweed.lua',
    'cl_drying.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'sv_uteknark.lua',
}
