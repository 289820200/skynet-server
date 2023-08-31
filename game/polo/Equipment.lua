--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-24 13:53:19
-- @Description: 装备
--------------------------------------



local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local print_r = require "common.print_r"
require "common.algo"

local gdd 
local equipment_data
local equipment_prop

skynet.init(function ()
    gdd = sharedata.query "settings_data"
    equipment_data  = gdd.equipment
    -- 属性原始数据
    equipment_prop  = gdd.equipment_prop
end)


Equipment={
}

function Equipment:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

-- 装备数据
function Equipment.get_data( id )
    local data = equipment_data[id]
    assert(data,"Equipment.get_data data is nil"..id)
    return data
end

-- 装备属性数据
function Equipment.get_prop_data( eq_type )
    local data = equipment_prop[eq_type]
    assert(data,"Equipment.get_prop_data data is nil"..eq_type)
    return data
end

--获取一定金钱可以升到的等级
function Equipment.get_max_level_by_cost( id,cur_lv,cost )
    local conf_set = gdd.equip_level_up
    local conf = conf_set[id]
    if not conf then
        return -1
    end

    local lv = cur_lv
    local total_cost = 0
    while(true) do
        local level_data = conf[lv + 1]
        if not level_data then
            break
        end

        total_cost = total_cost + level_data.cost
        if total_cost > cost then
            break
        end

        lv = lv + 1
    end

    return lv
end

--获取升级费用
function Equipment.get_level_up_cost( id,from,to)
    local conf_set = gdd.equip_level_up
    local conf = conf_set[id]
    if not conf then
        return -1,"level up conf nil"
    end

    if (type(from) ~="number") or (type(to)~="number") then
        return -1,"parm err"
    end

    local total_cost = 0
    for i=from+1,to do
        local level_data = conf[i]
        if not level_data then
            return -1,"level up conf err"
        end
        total_cost = total_cost + level_data.cost
    end

    return total_cost
end

-- 装备生成附加属性规则：
-- 1、  根据装备品质确定初始附加属性条数。
-- 2、  在对应属性库中安装出现概率随机对应的是哪几条属性。
-- 3、  根据该品质装备每一条属性的区间随机选择效果值。

function Equipment:init(is_default)
    local data = Equipment.get_data(self.id )
    local from = data.init_from
    local to = data.init_to
    local count = math.random(from,to)

    local init_prop = {}
    if is_default then
        for k,v in pairs(data.default_prop_list) do
            local tmp_prop = {
                id = v.id,
                value=v.value,
                num_type = v.num_type
            } 
            table.insert( init_prop,tmp_prop )
        end
    else
        -- 装备类型
        local eq_type = data.eq_type
        -- 取出属性列表
        local prop_data = Equipment.get_prop_data( eq_type )
    
        -- 获取随机到的属性
        local list = random_count(prop_data,count,"prob")

         -- 品质
        local quality = self.quality or data.quality
        --装备品质区间为3、4、5,而表里填的是1、2、3
        local key = string.format("quality_%d",quality - 2)

        for k,v in pairs(list) do
            -- 属性的取值由品质决定大小
            -- 注意属性值分 数值和百分比 equipment_prop.csv 表中 num_type 表达 1百分比，2数值
            if v[key] then
                local from = v[key].from
                local to = v[key].to
                local num_type = v.num_type
                local value
                if num_type == 1 then 
                    local rank = to - from 
                    value = math.random()*rank + from 
                    -- 保留一位小数
                    value = math.floor(value*10)/10
                else
                    -- 确认过不会出现小数
                    value = math.random(from,to)
                end 
                print("init equip prop:num_type,form,to,value",num_type,from,to,value)

                local tmp_prop = {
                    id = v.id,
                    value=value,
                    num_type = num_type
                } 
                table.insert( init_prop,tmp_prop )
            end
        end
    end

    self.init_prop = init_prop

    self.lv = 0
end

-- 装备位置
function Equipment:get_class()
    local data = Equipment.get_data(self.id)
    if data then 
        return data.class_id
    end
    skynet.error("Equipment:get_class error id:",self.id)
    return 1
end

-- 所属主角
function Equipment:belong_to()
    -- body
    local data = Equipment.get_data(self.id)
    if data then 
        return data.belong_to
    end
    skynet.error("Equipment:belong_to error id:",self.id)
    return 1
end

-- 装备
function Equipment:put_on()
    self.on = true
end


-- 卸下
function Equipment:put_off()
    self.on = false
end

function Equipment:get_self_data(  )
    local data = equipment_data[self.id]
    assert(data,"Equipment.get_self_data data is nil"..self.id)
    return data
end


function Equipment:inlay( slot_index,gem )
    local inlay_list = self.inlay_list or {}
    local slot = inlay_list[slot_index]
    if not slot then
        return false,"dont have this slot"
    end

    local equip_data = self:get_self_data()
    if not equip_data then
        return false,"equip data err"
    end
    local gem_data = gem:get_data()
    if not gem_data then
        return false,"gem data err"
    end
    if equip_data.eq_type ~= gem_data.eq_type then
        return false,"equip type err"
    end

    if slot ~= -1 then
        return false,"slot not empty"
    end

    inlay_list[slot_index] = gem.uuid
    self.inlay_list = inlay_list

    return true
end

function Equipment:inlay_remove( slot_index )
    local inlay_list = self.inlay_list or {}
    local slot = inlay_list[slot_index]
    if not slot then
        return false,"dont have this slot"
    end

    if slot == -1 then
        return false,"slot empty"
    end

    inlay_list[slot_index] = -1
    self.inlay_list = inlay_list
    return true
end

function Equipment:decompose(  )
    local conf = self:get_self_data()
    if not conf then
        return nil,"装备配置错误"
    end

    if not conf.can_decompose then
        return nil,"装备不能分解"
    end

    local ret = {}
    for k,v in pairs(conf.product_list) do
        table.insert( ret,{id=v.id,num=v.num} )
    end

    return ret
end

