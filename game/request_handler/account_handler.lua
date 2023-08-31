local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
-- local uuid = require "uuid"

local is_verify

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd

handler:init (function (u)
	user = u
	database = ".database" --skynet.uniqueservice ("database")
	gdd  = sharedata.query "settings_data"
end)

function REQUEST.account_login(args)
	local account_id = args.account_id
	local account_name = args.account_name
	local account_secret = args.account_secret
	log.debug(account_id,account_name,account_secret)
	is_verify = skynet.call(database, "lua", "account_center","verify",account_id,account_name,account_secret)
	if is_verify then
		local list = skynet.call(database, "lua", "character","list",account_id) 
		user.char_list = list
		return {status = 1,char_list = list}
	else
		return {status = 0}
	end 
end

function REQUEST.update_game_setting(args)
	if not is_verify then 
		return {status =0,msg="请先通过验证"}
	end 
	local admin = gdd.admin
	local is_admin = false
	for k,v in pairs(admin) do
		if v.account_id == args.account_id then
			is_admin = true
			break
		end
	end
	if not is_admin then
		return {status = 0,msg="非管理员无法更新配置"}
	end

	skynet.call(".settings","lua","update")
	
	return {status=1,msg = "ok"}
end


return handler

