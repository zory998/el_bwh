Config = {}

Config.admin_groups = {"admin","superadmin"} -- groups that can use admin commands
Config.popassistformat = "Jogador %s está a pedir ajuda\nEscreve <span class='text-success'>/accassist %s</span> para aceitar ou <span class='text-danger'>/decassist</span> para recusar" -- popup assist message format
Config.chatassistformat = "Jogador %s está a pedir ajuda\nEscreve ^2/accassist %s^7 para aceita ou ^1/decassist^7 para recusar\n^4Razão^7: %s" -- chat assist message format
Config.assist_keys = {accept=208,decline=207} -- keys for accepting/declining assist messages (default = page up, page down) - https://docs.fivem.net/game-references/controls/
-- Config.assist_keys = nil -- coment the line above and uncomment this one to disable assist keys
Config.warning_screentime = 7.5 * 1000 -- warning display length (in ms)
Config.backup_kick_method = false -- set this to true if banned players don't get kicked
Config.discord_webhook = nil -- set to nil to disable, otherwise put "<your webhook url here>" <-- with the quotes!
Config.page_element_limit = 250