local log = require "log"
local packer = require "db.packer"
local print_r = require "common.print_r"
require "common.predefine"

local rush = {}
local connection_handler
local floor = math.floor

function rush.init (ch)
    connection_handler = ch
end

local function get_db_connect()
    return connection_handler "game_db"
end 

local function get_score( win_num,time )
    --zset的score使用double型，正常的胜利数肯定是不会使其溢出的
    --左右移的优先级比四则运算低
    return (win_num<<32)+time
end

local function analysis_score( score )
    local win_num = score>>32
    local time = score - (win_num<<32)
    return floor(win_num),floor(time)
end

--获取角色数据
local function get_char_data( char_id )
    --[[本来打算如果角色在线，直接获取内存里的角色数据，以免数据没有回写
    但是发现在这里没法call别的服务，就没法获取到在线角色数据了
    回头再研究]]--
    local connection = get_db_connect()
    local key = string.format ("char_%d", char_id)
    local data_str = connection:get (key) or "{}"
    data = packer.unpack(data_str)

    return data
end

function rush.update_rank( level,char_id,win_num )
    local connection = get_db_connect()
    local key = "rush_rank_"..level
    if win_num <= 0  then    
        connection:zrem(key,char_id)
    elseif win_num >= 5 then
        local score = get_score(win_num,os.time())
        connection:zadd(key,score,char_id)
    end
end

function rush.get_rank( level )
    local connection = get_db_connect()
    local key = "rush_rank_"..level
    --从0开始
    local rank_list = connection:zrevrange(key,0,9)
    if (not rank_list) or (not next(rank_list))then
        return nil
    end

    local ret_list = {}
    for k,v in pairs(rank_list) do
        local tmp = {}
        tmp.char_id = tonumber(v)
        local score = connection:zscore( key,v )
        local win_num,time = analysis_score(score)
        tmp.win_num = win_num
        tmp.time = time

        local like_num = connection:hget("rush_rank_like",v) or 0
        tmp.like_num = tonumber(like_num)

        local char_data = get_char_data(v)
        if char_data then
            tmp.char_name = char_data.nickname
            tmp.lv = char_data.lv
        end
        table.insert( ret_list, tmp)
    end

    return ret_list
end

function rush.rank_like( char_id,level )
    --在角色数据里保存点赞记录这里不校验是否点过赞
    local connection = get_db_connect()
    local key = "rush_rank_"..level

    local rank = connection:zrevrank(key,char_id)
    --rank从0开始
    if not rank or rank >= 10 then
        return false,"char not in rank"
    end

    connection:hincrby("rush_rank_like",char_id,1)

    return true
end


return rush