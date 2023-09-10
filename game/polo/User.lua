--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-20 13:53:38
-- @Description: 用户
--------------------------------------

local database = ".database"

User={
    
}

function User:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

-- 清理广播
function User:clear_broadcast()
    local list = self.broadcast_list or {}
    for k,v in pairs(list) do
        v:unsubscribe()
    end
    self.broadcast_list = {}   
end

--监听世界广播
function User:subscribe_world_broadcast()
    local send_request = self.send_request
    local send_package = self.send_package
    local broadcast_list = self.broadcast_list or {}
    local rc = annc.subscribe("WORLD",function (channel, source, ...)
        send_package (send_request("announcement",{message = ...}))
    end)
    broadcast_list["WORLD"] = rc
    self.broadcast_list = broadcast_list
end


--世界广播
function User:publish_world_broadcast(msg)
    local broadcast_list = self.broadcast_list or {}
    local rc = broadcast_list["WORLD"] 
    if rc then 
        rc:publish(msg)
    end
end


-- 角色登录后用户处理
function User:char_login( )
    self:clear_broadcast()
    self:subscribe_world_broadcast()
end
