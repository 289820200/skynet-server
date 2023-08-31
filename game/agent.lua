
package.path = "./game/?.lua;" .. package.path
local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local sharedata = require "skynet.sharedata"
local log = require "log"
local print_r = require "common.print_r"

require "common.algo"
require "polo.User"
require "polo.Character"
require "polo.Hero"
require "polo.Mail"
require "polo.Gem"



local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
-- 注册的
local targets = {}

local client_fd
local gate 

-- 账号模块
local account_handler = require "request_handler.account_handler"

-- 角色模块
local character_handler = require "request_handler.character_handler"

--地图模块
local map_handler = require "request_handler.map_handler"

--技能模块
local skill_handler = require "request_handler.skill_handler"

-- 副将模块
local hero_handler = require "request_handler.hero_handler"

--天赋模块
local talent_handler = require "request_handler.talent_handler"

--装备模块
local equipment_handler = require "request_handler.equipment_handler"

--邮件模块
local mail_handler = require "request_handler.mail_handler"

--签到模块
local sign_handler = require "request_handler.sign_handler"


--vip 充值 
local vip_handler = require "request_handler.vip_handler"

--商城模块
local shop_handler = require "request_handler.shop_handler"

--gm模块
local gm_handler = require "request_handler.gm_handler"

--宝石模块
local gem_handler = require "request_handler.gem_handler"

--急行战模块
local rush_handler = require "request_handler.rush_handler"

local REQUEST = {}

local user 

-- function CMD.character_logined(character)
-- 	user.character = character
-- end


function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
	log.debug("request name", name,"args :")
	print(name)
	log.info(args)
	local f = assert(REQUEST[name])	
	local r = f(args)	
	log.debug("============================= respones ========================")
	log.infot(r)
	if response then
		local char 
		if user then 
			char = user.character 
		end 
		if char then 
			-- 由自身决定是否保存数据			
			char:save()
			char.depart_time = 0
		end 
		if r then
			return response(r)
		else
			return nil
		end
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (_, _, type, ...)
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	-- skynet.fork(function()
	-- 	while true do
	-- 		send_package(send_request "heartbeat")
	-- 		skynet.sleep(500)
	-- 	end
	-- end)

	
	local seed = tostring(os.time()):reverse():sub(1, 6)..fd
	math.randomseed(seed)  
	for i=1,math.random(2,5) do
		math.random()
	end

	user = User:new { 
		fd = fd, 
		REQUEST = REQUEST,
		RESPONSE = {},
		CMD = CMD,
		send_request = send_request,
		send_package = send_package,
		broadcast_list = {},
		agent = skynet.self(),
	}
	REQUEST = user.REQUEST
	RESPONSE = user.RESPONSE

	account_handler:register (user)

	character_handler:register (user)

	map_handler:register(user)

	skill_handler:register(user)

	hero_handler:register(user)

	talent_handler:register(user)

	equipment_handler:register(user)

	mail_handler:register(user)

	sign_handler:register(user)

	vip_handler:register(user)

	shop_handler:register(user)

	gm_handler:register(user)

	gem_handler:register(user)

	rush_handler:register(user)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end


local function send_mail_notify(mail_data)
	local mail_list = user.character.mail_list
	local new_mail_num = 0
	for i,v in ipairs(mail_list) do
		if v.status == 0 then
			new_mail_num = new_mail_num + 1
		end
	end
	if new_mail_num >  0 then
		send_package(send_request("mail_notify",{mail_num=new_mail_num,mail_data=mail_data}))
	end
end

--推送邮件
function CMD.push_mail(mail_data)
	if mail_data then
		local f = assert(REQUEST["accept_mail"])
		local ok = f(mail_data)
		if ok then
			--发送新邮件提示
			--在线时收到新邮件，notify里包含邮件数据
			send_mail_notify(mail_data)
		end
	end
end

--恢复体力
local function restore_energy_notify()
	local f = assert(REQUEST["restore_energy"])	
	local update_info = f(data)
	if update_info then
		send_package(send_request("restore_energy_notify",update_info))
	end
	
    return true
end

local function set_char_timer(  )
	skynet.fork(function ( )
		while true do
			--恢复体力
			if user and user.character then
				restore_energy_notify()
				if user.character.depart_time > 30 then
					--print("time over,disconnect")
					--CMD.disconnect()
				end

				user.character.depart_time = user.character.depart_time + 1
			end

			skynet.sleep(100)
		end
	end)
end

function CMD.gm_command(req)
	local f = assert(REQUEST["gm_command"])	
	local ok,msg,char_data = f(req)

	if ok then
		local status = ok and 1 or 0
		send_package(send_request("gm_command",{status=status,char_data=char_data}))
	end

    return ok,msg
end

function CMD.fight_attr_change_notify(  )
	local char = user.character
	if char then
		send_package(send_request(
			"fight_attr_change_notify",
			{
				lv=char.lv,
				fight_attr=char.fight_attr,
			})
		)
	end
end

function CMD.char_login()
	-- 角色登录后用户处理
	user:char_login()
	--加入在线用户列表
	skynet.call("char_mgr","lua","add_online_char",user.character.id,skynet.self())
	--发送新邮件提示
	--登录的时候notify只包含未读邮件数量
	send_mail_notify()
	set_char_timer()
end

function CMD.disconnect()
	-- todo: do something before exit
	print("CMD.disconnect","Do Save")
	local char = user.character
	if char then
		char:mark_updated()
		char:save()
		skynet.call("char_mgr","lua","del_online_char",user.character.id)
	end
	skynet.exit()
end


--获取角色数据
function CMD.get_char_data( )
	return user.character
end

-- 充值回调
function CMD.recharge_notify( data )
	print("agent.recharge_notify")
	local f = assert(REQUEST["recharge_notify"])	
	local update_info = f(data)
	send_package(send_request("recharge_notify",update_info))
    return true
end

function CMD.match_succ( op_data )
	--扣减次数
	local result = {
		status = 1,
		lose_num = 0,
		char_name = op_data.char_name,
		fight = op_data.fight,
		hero_list = op_data.hero_list,
	}
	local char = user.character
	if char and char.rush_rec and char.rush_rec.lose_num then
		result.lose_num = char.rush_rec.lose_num
	end
	send_package(send_request("rush_match_result",result))
end

function CMD.rush_msg( type,msg )
	local msg_type = {
		["rush_loaded"] = 1,
		["rush_position"] = 1,
		["rush_kill_mon"] = 1,
		["rush_boss_hp"] = 1,
	}	

	if not msg_type[type] then
		return
	end

	send_package(send_request(type,msg))
end

function CMD.rush_result( msg )
	--1：胜利 2：对方胜利 3：双方超时
	local f = REQUEST["rush_result"]
	local rsp
	if f then
		rsp = f(msg)
	end

	send_package(send_request("rush_result",rsp))
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
