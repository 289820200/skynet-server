--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-24 14:33:34
-- @Description: 宝石
--------------------------------------
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local gdd 
local gem_data

skynet.init(function ()
    gdd = sharedata.query "settings_data"
    gem_data  = gdd.gem
end)

Gem={
    
}

function Gem:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

function Gem:get_data(  )
    local data = gem_data[self.id]
    assert(data,"Gem.get_data data is nil"..self.id)
    return data
end

function Gem:lv_up( )
    self.lv = self.lv or 1
    local conf = self:get_data()
    if conf then
        while true do
            if self.exp < conf.need_exp_list[self.lv] then
                break
            end
            self.exp = self.exp - conf.need_exp_list[self.lv]
            self.lv  = self.lv + 1
        end
    end
end

function Gem:add_exp( exp )
    if (not exp) or (not type(exp) == "number") then
        return false
    end

    self.exp = (self.exp or 0) + exp
    self:lv_up()
end

function Gem.get_random_lv( id )
    local conf = gdd.gem[id]
    if not conf then
        return -1
    end

    local total_prob = 0
    for k,v in pairs(conf.prob_list) do
        total_prob = total_prob + v
    end

    local random_num = math.random(total_prob)

    local lv = -1
    local tmp_num = 0

    for i,v in ipairs(conf.prob_list) do
        tmp_num = tmp_num + v
        if tmp_num >= random_num then
            lv = i
            break
        end
    end

    return lv
end

function Gem:get_fight(  )
    --todo
    return 0
end

