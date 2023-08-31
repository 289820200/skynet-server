local log = require "log"
local packer = require "db.packer"
local print_r = require "common.print_r"

local mail = {}
local connection_handler

function mail.init (ch)
    connection_handler = ch
end

local function get_db_connect()
    return connection_handler "game_db"
end 

local function make_mail_box_key (char_id)
    return string.format ("mail_box_%d", char_id)
end

local function make_mail_key( mail_id )
    return string.format("mail_%d",mail_id)
end


-- 邮件id 自动增长
local max_mail_id_key = "max_mail_id_key"
local function set_max_mail_id()
    local connection = get_db_connect()
    connection:incr(max_mail_id_key)
    local max_mail_id = connection:get(max_mail_id_key)
    if max_mail_id then
        return tonumber(max_mail_id)
    else
        return nil
    end
end



function mail.get_max_mail_id()
    local connection = get_db_connect()
    local max_mail_id = connection:get(max_mail_id_key)
    if max_mail_id then
        return tonumber(max_mail_id)
    else
        return 0
    end
end


function mail.list( char_id,max_char_mail )
    local connection = get_db_connect()
    local key = make_mail_box_key(char_id)

    local mail_list = {}
    --做一点简单的判断，减少数据库操作
    local max_mail_id = tonumber(connection:get(max_mail_id_key) or 0) 
    if max_char_mail == max_mail_id then
        return mail_list
    end
    
    local self_mail_list = connection:lrange(key,0,-1)
    if self_mail_list then
        for i,v in ipairs(self_mail_list) do
            local mail_id = tonumber(v)
            if mail_id > max_char_mail then
                local data_str = connection:hget("mail_data",v)
                if data_str then
                    local data = packer.unpack(data_str)
                    if data then
                        table.insert(mail_list,data)
                    end
                else
                    --没有邮件数据的话，说明邮件已经过期，从列表中把id删除
                    connection:lrem(key,0,mail_id)
                end
            end
        end
    end

    return mail_list
end

function mail.set_data( mail_data )
    if not mail_data then
       return nil
    end

    local connection = get_db_connect()
    local new_id = set_max_mail_id()

    if new_id then
        if mail_data.type == 1 then
            --公共邮件会发送给当时已经创建的所有角色
            local char_set = connection:lrange("char_list",0,-1)
            for i,v in ipairs(char_set) do
                local char_id = tonumber(v)
                local box_key = make_mail_box_key(char_id)
                connection:rpush(box_key,new_id)
            end
        else
            for i,v in ipairs(mail_data.des_char_list) do
                local box_key = make_mail_box_key(v)
                connection:rpush(box_key,new_id)
            end
        end

        mail_data.id = new_id
        local data_str = packer.pack(mail_data)
        --无论一封邮件发送给多少人，邮件数据都只保存一份
        local mail_key = make_mail_key(new_id)
        connection:set(mail_key,data_str)
        --十天后淘汰邮件
        connection:expire(mail_key,MAIL_EXPIRE_TIME)
    end

    return new_id
end

function mail.get_data( mail_id )
    if not mail_id then
        return nil
    end  

    local connection = get_db_connect()
    data_str = connection:hget ("mail_data",mail_id)

    if data_str then
        return(packer.unpack(data_str))
    end

    return nil
end

function mail.delete( mail_id,char_id)
    if (not mail_id) or (not char_id) then
        return false
    end 

    local connection = get_db_connect()
    local key = make_mail_box_key(char_id)
    --LREM( key,count,value ),返回删除元素个数
    local del_num = connection:lrem(key,0,mail_id)
    if del_num <= 0 then
        print("del from database fail")
        return false
    --出现删除了一个以上元素的情况，肯定是某处出现了bug
    elseif del_num > 1 then
        log.debug("del mail num err char,mail,num:",char_id,mail_id,num)
    end

    return true
end

return mail