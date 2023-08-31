--------------------------------------
-- @Author:      Mark
-- @DateTime:    2015-12-28 
-- @Description:  角色天赋
--------------------------------------
local skynet = require "skynet"
local log = require "log"
local sharedata = require "skynet.sharedata"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


Talent={
    
}

function Talent:new( o )
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

function Talent:get_conf(  )
    local  conf_set = gdd.talent
    local conf_id = self.type * 100 + self.level
    if conf_set[conf_id] then
        return conf_set[conf_id]
    else
        return nil
    end
end

function Talent:check_level_up( role_lv )
    if not self.is_open then
        return false,"talent havnt open"
    end
    
    local next_conf_id = self.type * 100 + self.level + 1
    local conf_set = gdd.talent
    local next_conf = conf_set[next_conf_id]
    if not next_conf then
        return false,"not next talent level,cur level:"..self.level
    end

    if next_conf.need_level > role_lv then
        return false,"level too low"
    end

    return true,""
end

function Talent:level_up_cost( )
    local conf = self:get_conf()
    if not conf then
        return false,"talent conf err"
    end

    local list = {}
    for k,v in pairs(conf.level_up_cost_list) do
        table.insert(list,v)
    end

    return list
end

function Talent:level_up( )
    self.level = self.level + 1
end

