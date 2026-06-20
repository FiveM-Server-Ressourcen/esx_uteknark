fx_version 'cerulean'
game      'gta5'

description 'ESX UteKnark – Dynamic Weed Growing System'
version     '3.0.0'
author      'DemmyDemon (extended)'

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

dependencies {
    'es_extended',
    'mysql-async',
    'ox_lib',
}
