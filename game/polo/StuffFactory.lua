--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-24 14:33:34
-- @Description: 心法
--------------------------------------
require "polo.Item"
require "polo.Equipment"
require "polo.Gem"
require "polo.Citta"

-- 10  道具
-- 20  装备
-- 21  装备碎片
-- 22  装备配方
-- 30  宝石
-- 31  宝石碎片
-- 32  宝石配方
-- 40  心法
-- 41  心法碎片
-- 42  心法配方
-- 50  货币
-- 60  武将


-- 道具
local type_item         = 10
-- 装备
local type_equip        = 20
local type_equip_debris  = 21
local type_equip_make   = 22
-- 宝石
local type_gem          = 30
local type_gem_debris    = 31
local type_gem_make     = 32
-- 心法
local type_citta        = 40
local type_citta_debris  = 41
local type_citta_make   = 42
-- 属性
local type_prop         = 50

--武将
local type_hero         = 60
--武将碎片
local type_hero_debris  = 61

-- local type_prop         = 51
-- local type_prop         = 52
-- local type_prop         = 53

StuffFactory = {
    type_item           =   type_item       ,
    type_equip          =   type_equip      ,
    type_equip_debris    =   type_equip_debris,
    type_equip_make     =   type_equip_make ,
    type_gem            =   type_gem        ,
    type_gem_debris      =   type_gem_debris  ,
    type_gem_make       =   type_gem_make   ,
    type_citta          =   type_citta      ,
    type_citta_debris    =   type_citta_debris,
    type_citta_make     =   type_citta_make ,
    type_prop           =   type_prop,
    type_hero           =   type_hero,
    type_hero_debris    =   type_hero_debris,
}   

local id_f = 1000000
-- 获取玩家身上的存放点
-- char={
--     package={
--         item={},
--         equipment={},
--         gem={},
--         citta={}
--     },
--     debris={
--         equipment={},
--         gem={},
--         citta={}
--     }
-- }


function StuffFactory.get_stuff_type(id)
    if not id then
        return -1
    end
    return math.floor(id/id_f)
end

function StuffFactory.is_stuff_id_legal( id )
    local stuff_type = StuffFactory.get_stuff_type(id)
    for k,v in pairs(StuffFactory) do
        if type(v) == "number" and v == stuff_type then
            return true
        end
    end

    return false
end



function StuffFactory.new_stuff(id,data)
    local stuff_type = StuffFactory.get_stuff_type(id)
    if stuff_type == StuffFactory.type_item then 
        return Item:new(data)
    elseif stuff_type == StuffFactory.type_equip then 
        return Equipment:new(data)
    elseif stuff_type == StuffFactory.type_gem then 
        return Gem:new(data)
    elseif stuff_type == StuffFactory.type_citta then 
        return Citta:new(data)
    end
    print("StuffFactory.new_stuff error")

    return nil
end

function StuffFactory.new_stuff_by_data(data)
    local id = data.id
    return StuffFactory.new_stuff(id,data)
end


return StuffFactory




