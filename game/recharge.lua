package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local httpc = require "http.httpc"
local packer = require "db.packer"


local settings
local srv_id 
skynet.init(function() 
	settings = sharedata.query("settings_data")
	srv_id = skynet.getenv "srv_id" --settings.srv_id_config[1].srv_id
end)


local recharge = {}



-- 游戏服请求下单
local CMD = {}

function CMD.recharge_order(req)
	-- 订单号
	-- srv_id_char_id_当前时间_rand(10000)
	local char_id = tonumber(req.char_id or 1)
	local t = os.time()
	local r = math.random(1,10000)
	-- TODO 
	local ch_id = req.ch_id or 1
	local os_id = req.os_id or 1
	local device_id = req.device_id or "iPhone6"
	
	local pay_point = req.pay_point or "1"
	-- 请求账号中心 
	-- 入库
	-- 请求账号中心下单
	local host = "127.0.0.1:9527"
	local url_mat = "/order?pay_point=%s&srv_id=%d&char_id=%d&os_id=%d&ch_id=%d&device_id=%s"
	local url = string.format(url_mat,pay_point,srv_id,char_id,os_id,ch_id,device_id)
	print("recharege_order,host,url:",host,url)
	local status,ret_str = httpc.get(host,url)
	if status == 200 then 
		print("ret_str",ret_str)	
		local ret = packer.unpack(ret_str)
		local order = ret.order
		return {order=order}
	else
		return {order=nil}
	end
end

-- 通知游戏服
function CMD.payback(req)
	print("通知游戏服","recharge.payback")
	-- 角色 id 
	local char_id = req.char_id 
	-- 充值 id 
	local pay_point = req.pay_point
	local data = {
		char_id = char_id,
		pay_point = pay_point,
	}
	local ret = skynet.call("char_mgr","lua","recharge_notify",data)
	return ret 
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
