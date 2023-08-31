--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2016-01-07 14:33:21
-- @Description: VIP
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local gdd 
local vip_data 

skynet.init(function ()
    gdd = sharedata.query "settings_data"
    vip_data  = gdd.vip
end)

VIP={
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
    priv_buy_strength = "buy_strength",
}


function VIP:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

-- 是否有某种特权
function VIP:is_had_privilege(p)
    
end

function VIP:privilege()
    
end


function VIP:level_up()
    local vip_count = #vip_data
    for i=vip_count,1,-1 do
        local data = vip_data[i]
        if data then
            local acc_rmb = data.acc_rmb 
            if self.rmb >= acc_rmb then 
                self.lv = data.lv 
                break
            end
        end
    end    
end

function VIP:add_rmb(m_rmb)
    local rmb = self.rmb or 0
    rmb = rmb + m_rmb
    self.rmb = rmb
    self:level_up()
end

