local packer = require "db.packer"
local print_r = require "common.print_r"

local sign = {}
local connection_handler

function sign.init (ch)
    connection_handler = ch
end

local function get_db_connect()
    return connection_handler "game_db"
end 

local function make_name_key (name)
    return "char-name", name
end

local function sort_rank( lhs,rhs )
    if lhs.num == rhs.num then
        if lhs.last_sign_time == rhs.last_sign_time then
            return lhs.char_id < rhs.char_id
        else
            return lhs.last_sign_time < rhs.last_sign_time
        end
    else
        return lhs.num > rhs.num
    end
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

function sign.sign_up( sign_data )
    local connection = get_db_connect()
    connection:hmset("sign_data",sign_data.char_id ,packer.pack(sign_data))
end


function sign.ref_today_rank(  )
    --生成当日的排行榜
    local connection = get_db_connect()
    local tmp_list = connection:hvals("sign_data") 

    for k,v in pairs(tmp_list) do
        tmp_list[k] = packer.unpack(v)       
    end

    table.sort( tmp_list, sort_rank )
    local rank = {}
    local index = 1
    --清空排行榜
    connection:zremrangebyrank("sign_rank",0,-1) 
    for k,v in pairs(tmp_list) do
        --连续签到不小于7天才能进榜
        if v.num >= 7 then
            local char_data = get_char_data(v.char_id)
            --等级不小于30级才能进榜
            if char_data and char_data.lv >= 30 then
                connection:zadd("sign_rank",index,v.char_id)
            end
        end
        index = index + 1
    end
end

function sign.get_today_rank( )
    local connection = get_db_connect()
    local rank = connection:zrange("sign_rank",0,-1)

    local ret_rank = {}
    local index = 1
    for k,v in pairs(rank) do
        local char_id = tonumber(v)
        local tmp = {}
        --redis会把数据存储为string
        tmp.char_id = char_id
        --前10名要获取他们的名字和签到次数
        if index <= 10 then
            local char_data = get_char_data(char_id)
            if char_data then
                tmp.name = char_data.nickname
                tmp.num = char_data.sign_record.continual_day
            end
        end
        index = index + 1
        table.insert( ret_rank, tmp)
    end

    return ret_rank
end


return sign
