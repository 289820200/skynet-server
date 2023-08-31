--------------------------------------
-- @Author:      Mark
-- @DateTime:    2015-12-14 17:06
-- @Description:  角色技能
--------------------------------------
local skynet = require "skynet"
local log = require "log"
local sharedata = require "skynet.sharedata"
local print_r = require "common.print_r"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


Skill={
    type_active = 1,-- 主动
    type_passive = 2,-- 被动
    type_joint = 3,-- 合击
}

function Skill:new( o )
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

-- 是否被动技能
function Skill:is_passive()
    local t = self:get_type()
    return t == Skill.type_passive 
end

-- 获取技能类型 1主动 2被动 3合击
function Skill:get_type()
    local data = self:get_conf()
    local t = data.skill_type
    return t
end

function Skill:get_conf()
    local  conf_set = gdd.skill
    if conf_set[self.id] then
        return conf_set[self.id]
    else
        return nil
    end
end

function Skill:get_data_conf()
    local  conf_set = gdd.skill
    local conf = conf_set[self.id]
    if not conf then
        return nil
    end

    local data_conf_set = gdd.skilldata_common

    local skill_data_list = conf.skill_data_list
    local data_conf_id = skill_data_list[self.level]

    if not data_conf_id then
        return nil
    end

    return data_conf_set[data_conf_id]
end

function Skill:put_on(index)
    self.index = index
    self.is_using = true
end

function Skill:take_off()
    self.index = 0
    self.is_using = false
end

-- 是否已装备
function Skill:is_on()
    -- 数据有耦合 修改时注意同时修改
    return self.index ~= 0 and self.is_using
end

function Skill:unlock(index)
    self.level = 1
end

function Skill:check_unlock( char_lv )
    local conf = self:get_conf()
    
    if not conf then
        return false,"skill conf err"
    end
    if char_lv < conf.unlock_level then
        return false,"level too low"
    end
    -- 合击技
    if conf.type == 3 then
        return false,"skill type err"
    end
    return true
end

function Skill:check_level_up( char_lv )
    local skill_conf = self:get_conf()
    if not skill_conf then
        return false,"skill conf err"
    end

    local skill_data_conf_set = gdd.skilldata_common

    if self.level == 0 then
        return false,"havnt unlock"
    end

    if skill_conf.type == 3 then
        return false,"skill type err"
    end

    local cur_lv = self.level
    if not skill_conf.skill_data_list[cur_lv + 1] then
        return false,"no this level"
    end

    local data_id = skill_conf.skill_data_list[cur_lv + 1]
    local skill_data_conf = skill_data_conf_set[data_id]

    if not skill_data_conf then 
        return false,"skill data conf err"
    end

    if skill_data_conf.need_lv > char_lv then
       return false,"level too low"
    end
    
    return true  
end

function Skill:unlock_cost(  )
    local conf = self:get_conf()

    if not conf then
        return nil
    end

    local list = {}
    for k,v in pairs(conf.unlock_cost_list) do
        table.insert(list,v)
    end

    return list
end


function Skill:level_up_cost()
    local skill_conf = self:get_conf()
    if not skill_conf then
        return nil
    end

    local skill_data_conf = gdd.skilldata_common

    local skill_data_list = skill_conf.skill_data_list
    local cur_lv = self.level
    --当前等级或者下一等级的数据找不到，都视为出错
    if (not skill_data_list[cur_lv]) or (not skill_data_list[cur_lv + 1]) then
        return nil
    end

    local data_id = skill_data_list[cur_lv]
    if not skill_data_conf[data_id] then 
        return nil
    end

    local list = {}
    for k,v in pairs(skill_data_conf[data_id].level_up_cost_list) do
        table.insert(list,v)
    end

    return list
end

function Skill:get_fight(  )
    local data_conf = self:get_data_conf()
    if not data_conf then
        return 0
    end

    return data_conf.fight or 0
end


