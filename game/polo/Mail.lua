--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-05 
-- @Description:  邮件对象
--------------------------------------
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


Mail={
    
}

function Mail:new( o )
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

--读邮件时的处理
function Mail:read( )
    if self.status == 0 then
        if self.attachment then
            --0 未读 1 有附件未领 2 有附件已领/无附件已读
            self.status = 1
        else
            self.status = 2
        end
    else
        return false
    end

    return true,self.status
end

--领取附件
function Mail:get_attachment( )
    if not self.attachment then
        return nil,"no attachment"
    end
    if self.status >= 2 then
        return nil,"has got attachment"
    end
    self.status = 2
    return self.attachment
end

--蛋疼，还要传入char id，逻辑上很奇怪，但是数据结构所限需要这样做
function Mail:delete(char_id)
    if self.status < 2 then
        return false,"get attachment or read first"
    end

    local ok = skynet.call(".database","lua","mail","delete",self.id,char_id)
    if not ok then
        return false,"delete mail fail"
    end

    return true
end

