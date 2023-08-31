local log = require "log"
local packer = require "db.packer"

local character = {}
local connection_handler

function character.init (ch)
	connection_handler = ch
end

local function get_db_connect()
	return connection_handler "game_db"
end 

-- 角色id 自动增长 锁？
local max_char_id_key = "max_char_id_key"
function character.get_max_char_id()
	local connection = get_db_connect()
	connection:incr(max_char_id_key)
	local max_char_id = tonumber(connection:get(max_char_id_key))
	--把新角色的id添加到所有角色id的列表里
	connection:rpush("char_list",max_char_id)
	return max_char_id
end

-- 角色重名检查用一个列表存储
local function make_name_key (name)
	return get_db_connect(), "char-name", name
end


-- 存储角色名->id
function character.set_name_to_id (name,id)
	local connection, key, field = make_name_key (name)
	if connection:hsetnx (key, field, id) ~= 0 then 
		return true
	else
		return false
	end
end


-- 角色名->id
function character.get_name_to_id (name)
	local connection, key, field = make_name_key (name)
	print(name)
	local id = connection:hget (key, field)	
	return id
end



-- 具体某个角色数据
local function make_character_key (char_id)
	return get_db_connect(), string.format ("char_%d", char_id)
end

function character.save_char (char_id, data)
	local connection, key = make_character_key (char_id)
	local data_str = packer.pack(data)
	connection:set (key, data_str)
end

function character.load_char (char_id)
	local connection, key = make_character_key (char_id)
	local data_str = connection:get (key) or "{}"
	local data = packer.unpack(data_str)
	return data
end

-- 角色列表
local function make_list_key (account_id)
	return get_db_connect(), string.format ("char_list_%d", account_id)
end

function character.list (account_id)
	local connection, key = make_list_key (account_id)
	local v = connection:get (key) or "{}"
	local list = packer.unpack(v) or {}
	return list 
end

function character.save_char_list (account_id, data)
	local connection, key = make_list_key (account_id)
	local data_str = packer.pack(data)
	connection:set (key, data_str)
end

--角色数据变动的时候，同步改动char_list里的内容
function character.set_char_list( account_id,char_id,data )
	local connection, key = make_list_key (account_id)
	local list_str = connection:get (key)

	local list
	if list_str then
		list = packer.unpack(list_str)
	end

	if list then
		for k,v in pairs(list) do
			if v.id == char_id then
				for m,n in pairs(data) do
					v[m] = n
				end
			end
		end
	end

	list_str = packer.pack(list)
	connection:set (key, list_str)
end



return character

