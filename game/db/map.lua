
local packer = require "db.packer"
local print_r = require "common.print_r"

require "common.predefine"

local map = {}
local connection_handler

function map.init (ch)
    connection_handler = ch
end

local function get_db_connect()
    return connection_handler "game_db"
end 

local function get_map_rank_key( map_id,diff )
    return "map_rank_"..map_id.."_"..diff
end

function map.add_rank( map_id,diff,char_id,char_name )
    local connection = get_db_connect()
    local key = get_map_rank_key(map_id,diff)
    local num = connection:zcard(key)

    if num < 10 then
        local data_str = packer.pack({char_id=char_id,char_name=char_name})
        --有相同的就不添加，在新版redis中，可以使用"nx"参数（zadd [nx]）
        if not connection:zrank(key,data_str) then
            --注意：set操作会取消expire,但zadd不会
            connection:zadd(key,num,data_str)
        end

        --排行已满10个，倒计时30天淘汰
        if connection:zcard(key) >=10 then
            connection:expire(key,MAP_RANK_EXPIRE_TIME)
        end
    end
end

function map.get_rank( map_id,diff )
    local connection = get_db_connect()
    local key = get_map_rank_key(map_id,diff)
    local rank_list = {}

    local tmp_list = connection:zrange(key,0,-1) or {}
    for k,v in pairs(tmp_list) do
        local tmp_data = packer.unpack(v)
        if tmp_data then
            table.insert( rank_list,tmp_data)
        end
    end

    local ttl = connection:ttl(key)

    return rank_list,ttl
end


return map