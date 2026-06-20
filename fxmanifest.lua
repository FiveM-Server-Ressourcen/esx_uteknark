fx_version 'cerulean'
game 'gta5'

description 'ESX UteKnark - Extended Weed System'
version '2.0.0'
author 'DemmyDemon (extended)'

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
    'lib/wildweed.lua',
    'cl_uteknark.lua',
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
