--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-24 13:53:19
-- @Description: 道具
--------------------------------------
local skynet = require "skynet"
local log = require "log"
local sharedata = require "skynet.sharedata"
local print_r = require "common.print_r"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


Item={
    
}

function Item.get_item_data( id )
    local all_item_data = gdd.item
    return all_item_data[id]
end

function Item:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

-- 加载
function Item:load()
    -- body
end

-- 出售
function Item:sell(num)
    if not num or num <= 0 then
        return nil,"出售数量错误"
    end
    if self.num <= 0 then 
        log.log("item sell num <=0 id",self.id)
        return nil,"物品数量异常"
    end 
    if num > self.num then
        return nil,"物品数量不够"
    end

    local data = Item.get_item_data(self.id)
    if not data then
        return nil,"物品配置错误"
    end

    if not data.can_sell then
        return nil,"该物品无法出售"
    end

    if not data.cost_list then
        return nil,"出售产物配置错误"
    end

    local get_list  = {}
    for i=1,num do
        RewardTool.merge_reward_table(data.cost_list,get_list)
    end

    return get_list
end

-- 使用
function Item:use( num )
    if not num or num <= 0 then
        return nil,"使用数量错误"
    end
    if self.num <= 0 then 
        log.log("item use num <=0 id",self.id)
        return nil,"物品数量异常"
    end
    if num > self.num then
        return nil,"物品数量不够"
    end

    local data = Item.get_item_data(self.id)
    if not data then
        return nil,"物品配置错误"
    end

    if not data.can_use then
        return nil,"该物品无法使用"
    end

    if not data.cost_list then
        return nil,"使用产物配置错误"
    end

    local get_list = {}
    for i=1,num do
        RewardTool.merge_reward_table(data.reward_list,get_list)
    end
    return get_list
end

