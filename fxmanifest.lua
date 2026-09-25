fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'domino-boricua'
author 'hellovisualab'
description 'Dominó Boricua: dominó en parejas estilo Puerto Rico para QBCore, Qbox y ESX'
version '2.0.0'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'shared/domino.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/world.lua',
    'client/admin.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/bot.lua',
    'server/main.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/*.woff2',
}
