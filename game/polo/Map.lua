local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local get_intl_str = require "common.intl_str"
local print_r = require "common.print_r"
local log = require "log"
require "polo.RewardTool"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)

Map = {
    
}


function Map:new( o )
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

function Map.check_map_valid( map_id,diff )
    local map_conf = gdd.scene_chapter
    if not map_conf[map_id] then
        return false
    end
    if not map_conf[map_id][diff] then
        return false
    end
    return true,map_conf[map_id][diff]
end

function Map.get_conf(id,diff)
    local map_conf = gdd.scene_chapter
    if not map_conf[id] then
        return nil
    end
    if not map_conf[id][diff] then
        return nil
    end
    return map_conf[id][diff]
end

function Map.cal_map_reward( id,diff,is_first )
    local reward

    local conf = Map.get_conf(id,diff)
    if not conf then
        return nil
    end

    if is_first then      
        reward_id = conf.reward_first_id
    else
        reward_id = conf.reward_id
    end

    reward =RewardTool.get_reward_data(reward_id)
    if not reward then
        return nil
    end

    return reward
end

function Map.check_mon_valid( id,diff,mon_list )
    local map_mon_list = Map.get_mon_list(id,diff)

    local valid = true
    for k,v in pairs(mon_list) do
        --检查怪物是否合法
        local find = false
        for m,n in pairs(map_mon_list) do
            if v.id == n.id then
                n.count = n.count or 0
                n.count = n.count + 1
                --怪物数量是否超过地图里这种怪物的总数
                if n.count > n.num then
                    log.notice("cal_mon_reward mon num err,mon_id,mon_num:",n.id,n.num)
                    valid = false
                end
                find = true
                break
            end
        end
        if not find then
            valid = false
            log.notice("cal_mon_reward mon type err,mon_id:",v.id)
            break
        end
        if not valid then        
            break
        end

        --检查这个怪物的掉落是否合法
        if v.drop then
            valid = RewardTool.check_mon_reward(v.id,v.drop)
        end
        if not valid then
            log.notice("cal_mon_reward,mon reward err,mon_id:",v.id)
            break
        end
    end

    return valid
end

function Map.cal_mon_reward( id,diff,mon_list )
    local reward_id = {}
    local reward = {}
    if not mon_list then
        return nil
    end

    local valid = Map.check_mon_valid(id,diff,mon_list)
    if not valid then
        --todo
        --return nil
    end

    --把这些怪物的奖励合起来
    local reward = {}
    for k,v in pairs(mon_list) do
        if v.drop then
            for m,n in pairs(v.drop) do
                RewardTool.merge_reward(n,reward)
            end
        end
    end
   
    return reward
end

--获取本地图所有怪物的id与等级
function Map.get_mon_list( id,diff )
    local conf = Map.get_conf(id,diff)
    if not conf then
        return nil
    end

    local mon_conf_set = gdd.monster_level_info

    local monster_list = {}
    local spawn_monster_list = {}
    --把场景各个区域的刷怪列表加入到刷怪总列表里
    for k,v in pairs(gdd.scene_monster) do
        if v.scene_id == id then
            for m,n in pairs(v.spawn_mons) do
                table.insert(spawn_monster_list,n)
            end
        end
    end

    --遍历刷怪总列表，把刷出来的怪加入怪物列表
    local spawn_conf = gdd.spawn_monster
    for k,v in pairs(spawn_monster_list) do
        if spawn_conf[v] then
            for m,n in pairs(spawn_conf[v].monster_list) do
                if mon_conf_set[n.id] then
                    if monster_list[n.id]  then
                        monster_list[n.id].num  = monster_list[n.id].num + n.num
                    else
                        monster_list[n.id] = {}
                        monster_list[n.id].id = n.id
                        monster_list[n.id].num = n.num
                    end
                end
            end
        end
    end

    --计算事件刷怪
    local event_conf = gdd.scene_events
    for k,v in pairs(event_conf) do
        --事件type为1表示刷怪事件
        if v.scene_id == id and v.type == 1 then
            for m,n in pairs(v.eparam_list) do
                local event_mon_id = n[1]
                local event_mon_num = n[2]
                if mon_conf_set[n.id] then
                    if monster_list[event_mon_id] then
                        monster_list[event_mon_id].num  = monster_list[event_mon_id].num + event_mon_num
                    else
                        monster_list[event_mon_id] = {}
                        monster_list[event_mon_id].id = event_mon_id
                        monster_list[event_mon_id].num = event_mon_num
                    end
                end
            end
        end
    end

    return monster_list
end

return Map


