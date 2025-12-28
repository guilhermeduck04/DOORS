
fx_version 'adamant'
game 'gta5'

dependency 'ghost_ui'

client_script {
   '@vrp/lib/utils.lua',
   'config/*',
   'client/main.lua',
}

server_script {
   '@vrp/lib/utils.lua',
   'config/*',
   'server/main.lua',
}
                            