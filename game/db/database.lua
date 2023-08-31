package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local redis = require "skynet.db.redis"

local config = require "config"
local account = require "db.account"
local character = require "db.character"
local mail = require "db.mail"
local sign = require "db.sign"
local map = require "db.map"
local rush = require "db.rush"

-- local center
-- local group = {}
-- local ngroup
local account_center_db
local game_db

local function hash_str (str)
	local hash = 0
	string.gsub (str, "(%w)", function (c)
		hash = hash + string.byte (c)
	end)
	return hash
end

local function hash_num (num)
	local hash = num << 8
	return hash
end

local function connection_handler (key)
	-- local hash
	-- local t = type (key)
	-- if t == "string" then
	-- 	hash = hash_str (key)
	-- else
	-- 	hash = hash_num (assert (tonumber (key)))
	-- end

	-- return group[hash % ngroup + 1]
	if key == "account_center" then
		return account_center_db
	else
		return game_db
	end 

end


local MODULE = {}
local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (connection_handler)
end

local traceback = debug.traceback

skynet.start (function ()
	module_init ("account_center", account)
	module_init ("character", character)
	module_init ("mail",mail)
	module_init ("sign",sign)
	module_init ("map",map)
	module_init ("rush",rush)
	-- center = redis.connect (config.center)
	-- ngroup = #config.group
	-- for _, c in ipairs (config.group) do
	-- 	table.insert (group, redis.connect (c))
	-- end

	--account_center_db = redis.connect (config.account_center_redis)
	game_db = redis.connect (config.game_redis)

	skynet.dispatch ("lua", function (_, _, mod, cmd, ...)		
		local m = MODULE[mod]
		if not m then
			print("database m is nil mod:",mod)
			return skynet.ret ()
		end
		local f = m[cmd]
		if not f then
			print("database f is nil cmd:",cmd)
			return skynet.ret ()
		end
		
		local function ret (ok, ...)
			if not ok then
				skynet.ret ()
			else
				skynet.retpack (...)
			end

		end
		ret (xpcall (f, traceback, ...))
	end)
end)
