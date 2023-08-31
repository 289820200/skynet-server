package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local httpc = require "http.httpc"
local sharedata = require "skynet.sharedata"

local settings
local srv_list
skynet.init(function() 
    settings = sharedata.query("settings_data")
    srv_list = settings.server_list
end)


local CMD = {}

local cmd_list = {
    --根据角色名获取id
    [1001] = function ( req )
        local id = skynet.call(".database","lua","character","get_name_to_id",req.char_name)
        if id then
            return true,"char_id:"..id
        else
            return false,"dont have this char"
        end
    end
}

function CMD.command( req )
    local cmd_type = tonumber(req.type)
    if not cmd_type then
        return false,"cmd type nil"
    end
    local ok,msg
    if cmd_type < 1000 then
        --小于1000的表示操作角色数据,转交角色管理器
        ok,msg = skynet.call("char_mgr","lua","gm_command",req)
    else
        if cmd_list[cmd_type] then
            local f = cmd_list[cmd_type]
            ok,msg = f(req)
        else
            return false,"cmd type err"
        end
    end

    return ok,msg
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)