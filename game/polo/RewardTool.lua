--------------------------------------
-- @Author:      Mark
-- @DateTime:    2015-12-23 
-- @Description: 处理奖励的一些方法
--------------------------------------
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local dbpacker = require "db.packer"
local print_r = require "common.print_r"
local log = require "log"

require "polo.StuffFactory"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


RewardTool = {}

function RewardTool.merge_reward(stuff,reward)
    local reward = reward or {}
    if (not stuff) or (not stuff.id) or (not stuff.num) then
        return false
    end

    local find = false
    for k,v in pairs(reward) do
        if v.id == stuff.id then
            --对于宝石
            if v.lv and stuff.lv and v.lv ~= stuff.lv then
            else
                v.num  = v.num + stuff.num
                find = true
            end
        end
    end

    --不要把stuff直接insert进去，insert插入的实际上是指针
    if (not find) and stuff.num > 0 then
        table.insert(reward,{id=stuff.id,num=stuff.num,lv=stuff.lv})
    end

    return true
end

function RewardTool.merge_reward_table( src_list,des_list )
    for k,v in pairs(src_list) do
        RewardTool.merge_reward(v,des_list)
    end
end


function RewardTool.get_reward_data( reward_id,des_reward)
    local reward_conf_set = gdd.scene_reward
    local reward_conf = reward_conf_set[reward_id]
    if not reward_conf then
        skynet.error("reward id  err",reward_id)
        return nil,"conf err"
    end

    local reward = des_reward or {}

    --每个物品独立随机。通关奖励/必出物品出现概率配为10000
    for k,v in pairs(reward_conf.reward) do
        local ran_num = math.random(10000)
        if ran_num < v.rate then
            RewardTool.merge_reward({id=v.id,num=v.num},reward)
        end
    end
     
    return reward
end

--检测怪物奖励是否合法
function RewardTool.check_mon_reward( mon_id,reward )
    if not mon_id then
        return false
    end

    if not reward then
        return true
    end

    local mon_conf_set = gdd.monster_level_info
    local mon_conf = mon_conf_set[mon_id]
    if not mon_conf then
        return false,"mon conf err"
    end

    local reward_conf_set = gdd.scene_reward
    local reward_conf = reward_conf_set[mon_conf.scene_reward]
    if not reward_conf then
        return false,"reward conf err"
    end

    for k,v in pairs(reward) do
        if v.num > 0 then
            local find = false
            for m,n in pairs(reward_conf.reward) do
                if v.id == n.id then
                    find = true
                    break
                end
            end
            if not find then
                print("invalid reward,mon_id:",mon_id,",stuff_id:",v.id)
                return false,"invalid reward,mon_id:"..mon_id..",stuff_id:"..v.id
            end
        end
    end

    return true
end



