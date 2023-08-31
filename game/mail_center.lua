--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-28
-- @Description:  邮件中心
--------------------------------------

local skynet = require "skynet"

local CMD = {}

function CMD.send_mail( mail_data )
    if not mail_data then
        return false
    end

    mail_data.c_time = os.time()
    local mail_id = skynet.call(".database","lua","mail","set_data",mail_data)
    if not mail_id then
        return {status=0,msg="send mail fail"}
    end
    mail_data.id = mail_id

    skynet.call("char_mgr","lua","mail_notify",mail_data)
    return true
end


skynet.start(function ()
    skynet.dispatch("lua", function(session,source, cmd, ...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
end)