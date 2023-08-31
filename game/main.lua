package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
require "skynet.manager"
local config = require "config"
local sharedata = require "skynet.sharedata"


skynet.start(function()
    skynet.error("game server start")
	--启动基础服务
	skynet.newservice("console")
	skynet.newservice("debug_console", config.debug.telnet_port)
	--启动协议加载服务	
	skynet.uniqueservice("proto.protoloader")
	
	-- 加载游戏配置数据共享服务
	local setting = skynet.uniqueservice("setting.settings")
    skynet.name(".settings",setting)
    skynet.call(setting,"lua","new")
    
    local data = sharedata.query("settings_data")
    -- 服务器 id 
    
    local srv_id_config = data.srv_id_config or {}
    local srv_id_data = srv_id_config[1] or {}
    local srv_id = srv_id_data.srv_id

    -- 加载游戏配置数据共享服务
    local db = skynet.newservice("db.database")
    skynet.name(".database", db)

    local recharge = skynet.newservice("recharge")
    skynet.name(".recharge", recharge)

    local gm_command = skynet.newservice("gm_command")
    skynet.name(".gm_command", gm_command)

    skynet.newservice("recharge_httpd")

    --创建定时器
    local svr_timer = skynet.uniqueservice("svr_timer")
    skynet.name("svr_timer",svr_timer)

    --角色管理器
    local char_mgr = skynet.uniqueservice("char_mgr")
    skynet.name("char_mgr",char_mgr)

    --邮件中心
    local mail_center = skynet.uniqueservice("mail_center")
    skynet.name("mail_center",mail_center)

    --签到管理器
    local sign_ranking = skynet.uniqueservice("sign_ranking")
    skynet.name("sign_ranking",sign_ranking)
	
	-- 启动gate(监听)服务
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {	
		address = config.gate.address,
		port = config.gate.port,
		maxclient = config.gate.maxclient,
		nodelay = true,
		-- loginserver = loginserver,
		servername = "sample",
	})

	if not srv_id then 
        skynet.error("请先在 srv_id_config.csv 里配置服务服id")
    else
        skynet.error("当前服务器 id为：",srv_id)
    end
	
    skynet.exit()
    
end)