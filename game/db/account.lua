--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-10-30 09:59:31
-- @Description: 连接账号中心数据库
--------------------------------------

-- local constant = require "constant"
-- local srp = require "srp"
local log = require "log"
local packer = require "db.packer"

local account = {}
local connection_handler

function account.init (ch)
	connection_handler = ch
end

local function get_db_connect()
	return connection_handler "account_center"
end


local function make_key (id)
	return get_db_connect(), string.format("account_id_%d",id)
end

-- function account.load (name)
-- 	assert (name)

-- 	local acc = { name = name }

-- 	local connection, key = make_key (name)
-- 	if connection:exists (key) then
-- 		acc.id = connection:hget (key, "account")
-- 		acc.salt = connection:hget (key, "salt")
-- 		acc.verifier = connection:hget (key, "verifier")
-- 	else
-- 		acc.salt, acc.verifier = srp.create_verifier (name, constant.default_password)
-- 	end

-- 	return acc
-- end

-- function account.create (id, name, password)
-- 	assert (id and name and #name < 24 and password and #password < 24, "invalid argument")
	
-- 	local connection, key = make_key (name)
-- 	assert (connection:hsetnx (key, "account", id) ~= 0, "create account failed")

-- 	local salt, verifier = srp.create_verifier (name, password)
-- 	assert (connection:hmset (key, "salt", salt, "verifier", verifier) ~= 0, "save account verifier failed")

-- 	return id
-- end


local max_account_id_key = "max_account_id_key"
function account.get_max_char_id()
	local connection = get_db_connect()
	connection:incr(max_account_id_key)
	local max_char_id = connection:get(max_account_id_key)
	return tonumber(max_char_id)
end


local function make_name_key (name)
	return get_db_connect(), "account_name", name
end

-- 存储角色名->id
function account.set_name_to_id (name,id)
	local connection, key, field = make_name_key (name)
	if connection:hsetnx (key, field, id) ~= 0 then 
		return true
	else
		return false
	end
end


-- 角色名->id
function account.get_name_to_id (name)
	local connection, key, field = make_name_key (name)
	local id = connection:hget (key, field)	
	return id
end

function account.save (account_id, data)
	local connection, key = make_key (account_id)
	local data_str = packer.pack(data)
	connection:set (key, data_str)
end

local function get_account(id, name)
	print(id,name)
	local connection,key = make_key(id)
	local account_str = connection:get(key)
	log.debug("account_str",account_str)
	local account = packer.unpack(account_str)
	log.logt(account)
	return account
end

-- 账号中心设置secret 给游戏服验证使用
function account.up_secret(id,name,secret)
	local account = get_account(id,name)
	account.secret = secret
	local connection,key = make_key(id)
	local account_str = packer.pack(account)
	connection:set(key,account_str)
end


-- 在游戏服cwyg
function account.verify (id, name, secret)
	local account = get_account(id, name)
	if account.secret == secret then 
		return true
	end
	return false
end

return account
