--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-05-10
-- @Description:  急行战处理
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"
require "common.predefine"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd
local agent

skynet.init(function ()
    gdd = sharedata.query "settings_data"
end)


handler:init (function (u)
    user = u
    database = ".database"
    agent = u.agent
end)

local function get_match_level(  )
    local char = user.character
    local level = 1
    for i,v in ipairs(PUSH_LEVEL) do
        if char.lv > v then
            level = i
        end
    end

    return level
end

--急行战面板信息
function REQUEST.get_rush_info( req )
    local char = user.character

    local vip_conf = gdd.vip[char.vip] or gdd.vip[0]
    if not vip_conf then
        return char:get_error_ret("no vip conf")
    end
    local today_num = char.rush_record.today_num or 0 
    local remain_num = math.max(vip_conf.push_num - today_num ,0)

    local buy_cost = PUSH_BUY_COST

    local level = get_match_level()
    
    return char:get_succ_ret({remain_num=remain_num,buy_cost=buy_cost,level=level})
end

function REQUEST.rush_match_begin( req )
    local char = user.character

    --重新计算一次战斗力
    char.fight = char:cal_char_fight()
    local hero_list = {}
    for k,v in pairs(char.hero_list) do
        if v:is_on() then
            table.insert( hero_list,v.id )
        end
    end
    local level = get_match_level()
    local char_data = {
        char_id=char.id,
        char_name=char.nickname,
        --难度等级
        level = level,
        lv = char.lv,
        hero_list = hero_list,
        fight=char.fight,
        time = os.time(),
        agent = user.agent,
    }
    local ok = skynet.call("rush_mgr","lua","add_player",char_data)

    if not ok then
        return char:get_error_ret("match fail")
    end

    return char:get_succ_ret()
end

function REQUEST.rush_match_cancel( req )
    local char = user.character

    local ok = skynet.call("rush_mgr","lua","del_player",char.id)

    if not ok then
        --删除出错应该有一些处理，todo
        return char:get_error_ret("cancel fail")
    end

    return char:get_succ_ret()
end


function REQUEST.rush_loaded( req )
    local char = user.character

    skynet.call("rush_mgr","lua","forward_rush_msg",char.id,"rush_loaded",req)
    return char:get_succ_ret()
end

function REQUEST.rush_position( req )
    local char = user.character

    skynet.call("rush_mgr","lua","forward_rush_msg",char.id,"rush_position",req)
    return char:get_succ_ret()
end

function REQUEST.rush_kill_mon( req )
    local char = user.character

    skynet.call("rush_mgr","lua","forward_rush_msg",char.id,"rush_kill_mon",req)
    return char:get_succ_ret()
end

function REQUEST.rush_boss_hp( req )
    local char = user.character

    skynet.call("rush_mgr","lua","forward_rush_msg",char.id,"rush_boss_hp",req)
    return char:get_succ_ret()
end

function REQUEST.rush_pass( req )
    local char = user.character
    local status = req.status
    local time = req.time

    skynet.call("rush_mgr","lua","rush_pass",char.id,status,time)
    return char:get_succ_ret()
end

--
function REQUEST.rush_result( req )
    local char = user.character
    local rush_rec = char.rush_rec or {}
    local status = req.status
    local time = req.time

    local reward
    --1：胜利 2：失败 3：超时
    --双方超时不断连胜纪录
    local level = get_match_level()
    if status == 1 then
        rush_rec.win_num = (rush_rec.win_num or 0) + 1
        rush_rec.lose_num = 0
        --更新排行榜数据
        skynet.call(database,"lua","rush","update_rank",level,char.id,rush_rec.win_num)
        --计算奖励
        local map_conf
        local act_conf = gdd.active[RUSH_ACT_ID]
        if act_conf then
            local map_data = act_conf.map_id_list[level]
            if map_data then
                map_conf = Map.get_conf(map_data.id,map_data.diff)
            end
        end

        if map_conf then
            reward = Map.cal_map_reward(map_conf.scene_id,map_conf.level,false)
        end
        if reward then
            reward = char:give_reward(reward)
        end
    elseif status == 2 then
        print("rush fail!!!")
        rush_rec.win_num = 0
        rush_rec.lose_num = (rush_rec.lose_num or 0) + 1
        --更新排行榜数据
        skynet.call(database,"lua","rush","update_rank",level,char.id,rush_rec.win_num)
    end

    char.rush_rec = rush_rec

    return {result=status,time=time,reward=reward}
end

function REQUEST.get_rush_rank( req )
    local char = user.character
    local rush_rec = char.rush_rec or {}
    local level = req.level

    local rank_list = skynet.call(database,"lua","rush","get_rank",level)
    if rank_list then
        if rush_rec.like_list then
            for k,v in pairs(rank_list) do
                v.can_like = true
                for m,n in pairs(rush_rec.like_list) do
                    if n == v.char_id then
                        v.can_like = false
                    end
                end
            end      
        else
            for k,v in pairs(rank_list) do
                v.can_like = true
            end
        end
    end

    return char:get_succ_ret({rank_list=rank_list})
end

function REQUEST.rush_rank_like( req )
    local char = user.character
    local rush_rec = char.rush_rec or {}
    local char_id = req.char_id
    local level = req.level

    if rush_rec.like_list then
        for k,v in pairs(rush_rec.like_list) do
            if v == char_id then
                return char:get_error_ret("have liked this char")
            end
        end
    end

    local reward_conf = gdd.rush_rank_like_reward[1]

    if not reward_conf then
        return char:get_error_ret("reward conf err")
    end

    local ok,msg = skynet.call(database,"lua","rush","rank_like",char_id,level)
    if not ok then
        return char:get_error_ret(msg)
    end

    rush_rec.like_list = rush_rec.like_list or {}
    table.insert( rush_rec.like_list,char_id )

    local tmp_reward
    local ran_num = math.random(10000)
    if reward_conf.prob >= ran_num then
        tmp_reward = {}
        for k,v in pairs(reward_conf.reward_list) do
            table.insert( tmp_reward,{id=v.id,num=v.num,lv =v.lv})
        end
        tmp_reward = char:give_reward(tmp_reward)
    end

    char.rush_rec = rush_rec

    return char:get_succ_ret({reward = tmp_reward})
end


return handler