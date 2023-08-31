--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-05 
-- @Description:  角色管理器
--------------------------------------
package.path = "./game/?.lua;" .. package.path
local skynet = require "skynet"

require "polo.Character"

local online_list = {}

local CMD = {}


local function get_db_char( char_id )
    local char_data = skynet.call(".database","lua","character","load_char",char_id)
    if not char_data or (next(char_data) == nil) then
        return nil
    end

    return char_data
end

local function deal_offline_gm_cmd( char_id,req )
    --应该对角色数据加锁，todo
    --先初始化角色
    local char_data = get_db_char(char_id)
    if not char_data then
        return false,"no this char"
    end

    local char = Character:new(char_data)
    char:loadData2Object()

    --为了直接调用gm_handler里面的函数，构建一些结构。
    local user = {
        character = char,
        REQUEST = {},
    }
    local gm_handler = require "request_handler.gm_handler"
    gm_handler:register(user)

    local f = user.REQUEST.gm_command
    local ok,msg = f(req)

    return ok,msg
end

local function deal_gm_cmd( char_id,req )
    local online_data = online_list[char_id]
    local ok,msg
    if online_data then
        ok,msg = skynet.call(online_data.agent,"lua","gm_command",req)
    else
        ok,msg =  deal_offline_gm_cmd(char_id,req)
    end

    return ok,msg
end

function CMD.add_online_char( char_id,agent)
    local pre_data = online_list[char_id]
    if pre_data then
        local agent = pre_data.agent
        if agent then 
            -- TODO
        end
    end
    online_list[char_id] = {char_id = char_id,agent = agent}
end

function CMD.del_online_char( char_id )
    if online_list[char_id] then
        online_list[char_id] = nil
    end

    skynet.call("rush_mgr","lua","char_offline",char_id)
end

function CMD.is_char_online( char_id )
    if online_list[char_id] then
        return true
    end
    return false
end

--获取在线角色数据
function CMD.get_char_data( char_id )
    local target = online_list[char_id]
    if not target then
        return nil 
    end
    local char_data = skynet.call(target.agent,"lua","get_char_data")
    return char_data
end


--或许需要
function CMD.online_list_clear( char_id )
    online_list = {}
end

--新邮件通知
--type 1:通知所有在线角色 2：通知char_list里所有在线角色
--为了方便使用，加了has_attachment这个字段
function CMD.mail_notify(mail_data)
    local type = mail_data.type
    local char_list = mail_data.des_char_list
    if type == 1 then
        for k,v in pairs(online_list) do
            skynet.call(v.agent, "lua", "push_mail", mail_data)
        end
    else
        if char_list then
            for k,v in pairs(char_list) do
                if online_list[v] then
                    skynet.call(online_list[v].agent, "lua", "push_mail", mail_data)
                end
            end
        end
    end
end

function CMD.recharge_notify(data)
    print("char_mgr.recharge_notify")
    local char_id = tonumber(data.char_id or 1)
    if not char_id then 
        skynet.error("recharge_notify char_id is nil")
        return false
    end
    local agent_data = online_list[char_id]
    if not agent_data then 
        print("agent_data is nil ",char_id,type(char_id))
        return false
    end
    local agent = agent_data.agent
    if agent then 
        -- 在线
        skynet.call(agent,"lua","recharge_notify",data)
    else
        print("不在线的情况处理 ")
        -- 不在线的情况处理   
        -- 从数据库里获取角色数据
        -- 增加元宝
        -- 保存
    end
    return true
end

function CMD.gm_command( req )
    local char_id = tonumber(req.char_id)
    if not char_id then
        return false,"no char_id"
    end
    local ok,msg = deal_gm_cmd(char_id,req)
    return ok,msg
end


function CMD.fight_attr_change_notify( char_id )
    local online_data = online_list[char_id]
    if online_data then
        local ok,msg = skynet.call(online_data.agent,"lua","fight_attr_change_notify")
        return ok,msg
    end
end



skynet.start(function ()
    skynet.dispatch("lua", function(session,source, cmd, ...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
end)

