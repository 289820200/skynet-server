package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local redis = require "skynet.db.redis"
local config = require "config"
require "common.predefine"

local event_handler
local CMD = {}

function CMD.add_event(func_name,time_out,args)
	assert(type(func_name) == "string","function name is error : " .. func_name)
	skynet.fork(function ()
		while true do
			skynet.call("event_handler","lua",func_name,args)
			--timeout以秒为单位，sleep以0.01秒为单位
			skynet.sleep(time_out * 100)
		end
	end)
end 

local function init_redis_watch( channel )
	local conf = config.game_redis
	redis_watch = redis.watch(conf)
	redis_watch:psubscribe "channel"

	return redis_watch
end

local function set_svr_events(  )
	--把一些预设的服务器定时操作放在这里
	--1秒定时器
	skynet.fork(function ( )
		while true do
			--日常刷新
			--计算时区的影响，北京时间0点刷新
			local now_time = os.time() + TIME_ZONE_SEC	
			local sleep_time = ONE_DAY_SEC - now_time % ONE_DAY_SEC
			skynet.sleep(100 * sleep_time)
			skynet.call("event_handler","lua","daily_refresh")
			--防止多次刷新
			skynet.sleep(100)
		end
	end)

	local redis_watch = init_redis_watch("__key*__:*")

	skynet.fork(function (  )
		while true do
			print("Watch redis:",redis_watch:message())
			skynet.sleep(100)
		end
	end)
end


skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd,...)
		local f = assert(CMD[cmd])
		skynet.ret(skynet.pack(f(...)))
	end)

	set_svr_events()
end)


