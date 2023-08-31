local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"
require "polo.RewardTool"
require "common.predefine"

require "polo.Map"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd

handler:init (function (u)
    user = u
    database = ".database" 
    gdd  = sharedata.query "settings_data"
end)

function REQUEST.get_map_status(args)
    local char = user.character
    local list = char:get_map_list_new()
    return {status = 1, msg="" ,sections = list}
end

function REQUEST.enter_map(args)
    local char = user.character
    local map_id = args.map_id
    local diff = args.diff
    if (not map_id) or (not diff) then
        return {status = 0,msg = "map_id or diff nil"}
    end
    local rsp = {map_id = map_id,diff = diff}

    --判断能否进入tofinish
    local ok,msg  = char:check_enter_map(map_id,diff)
    if not ok then
        rsp.status = 0
        rsp.msg = msg
        return rsp
    end

    --扣除消耗
    ok,msg=char:deal_map_cost(map_id,diff)
    if not ok then
        rsp.status = 0
        rsp.msg = msg
        return rsp
    end

    --设置角色当前地图
    char:set_cur_map(map_id,diff)
    
    --返回结果
    rsp.status = 1
    rsp.msg = ""
    return rsp
end

function REQUEST.exit_map( args )
    local char = user.character
    local map_id = args.map_id
    local diff = args.diff
    local star = args.star
    local pass_status = args.pass_status
    local mon_list = args.monsters
    local map = char.map
    local map_conf_set = gdd.scene_chapter

    local rsp = {map_id = map_id,diff = diff,star = star}
    local conf = Map.get_conf(map_id,diff)
    if not conf then
        rsp.status = 0
        rsp.msg = "map conf err"
        return rsp
    end

    --校验tofinish
    --判断是否在该地图，初步校验一下
    if char.map.cur_map.map_id ~= map_id or char.map.cur_map.diff ~= diff then
        rsp.status = 0
        rsp.msg = "您不在该地图中！"
        return rsp
    end

    --None = -1,
    --Doing = 0,
    --Failed = 1,
    --Succeed = 2,
    if pass_status == -1 or pass_status == 0 or pass_status == 1 then
        rsp.status = 1
        if char.map[map_id] and char.map[map_id].diff[diff] then        
            rsp.star = char.map[map_id].diff[diff].star
        else
            rsp.star = 0
        end

        char:reset_cur_map()

        if pass_status == -1 then 
            rsp.msg = "退出关卡错误"
        elseif pass_status == 0 then
            rsp.msg = "中途退出关卡"
        else
            rsp.msg = "攻打关卡失败"
        end
        return rsp
    end

    --设置当前地图，添加通关记录
    char:reset_cur_map()
    local old_star = char:get_map_star(map_id,diff)
    local ok = char:set_map_record(map_id,diff,star)
    if not ok then
        rsp.status = 0
        rsp.msg = "add map record err"
        return rsp
    end

    --计算关卡奖励
    local map_reward
    local mon_reward
    local is_first = true
    if old_star >= 0 then
        is_first = false
    end
    map_reward= Map.cal_map_reward(map_id,diff,is_first)
    --give_reward会返回添加了uuid的reward列表
    if map_reward then
        map_reward = char:give_reward(map_reward,"map reward")
        --地图奖励出错的话，也不给怪物奖励
        mon_reward = Map.cal_mon_reward(map_id,diff,mon_list)
        if mon_reward then
            mon_reward = char:give_reward(mon_reward,"map reward")
        end 
    end  

    --返回结果
    rsp.status = 1
    rsp.msg = ""
    rsp.map_reward = map_reward or {}
    rsp.mon_reward = mon_reward or {}
    return rsp
end

function REQUEST.get_section_reward( args )
    local char = user.character
    local section = args.section
    local level = args.level
    local map = char.map

    if (not section) or (not level) then
        return char:get_error_ret("传参数为空")
    end

    --领取记录检查
    local section_record = map.section_record or {}
    local one_record = section_record[section]
    if one_record and (one_record & 1<<(level-1)) then
        return char:get_error_ret("该奖励已经领取过")
    end

    local conf_set = gdd.section_reward
    local conf = conf_set[section]
    if not conf then
        return char:get_error_ret("找不到奖励配置")
    end

    --星数检查
    local need_star = conf.need_star_list[level]
    if not need_star then
        return char:get_error_ret("奖励配置错误")
    end
    local total_star = char:get_section_total_star(section)
    if total_star < need_star then
        return char:get_error_ret("星数不够")
    end

    --设置领取记录
    one_record = one_record or 0
    one_record = one_record | (1 << (level-1))
    section_record[section] = one_record
    map.section_record = section_record

    local reward = conf.reward_list[level]
    if not reward then
        return char:get_error_ret("奖励配置错误")
    end

    local reward_data = {}
    for k,v in pairs(reward) do
        table.insert( reward_data,{id=v.id,num=v.num,lv=v.lv} )
    end

    reward_data = char:give_reward(reward_data,"section reward")

    return {status=1,msg="",reward=reward_data}
end

function REQUEST.restore_energy(  )
    local char = user.character
     --如果原来体力就不小于上限，就不增加了
    if char.fight_attr.energy >= char.fight_attr.max_energy then
        return nil
    end

    char.last_add_energy_time = char.last_add_energy_time or os.time()
    local last_time = char.last_add_energy_time
    local now_time = os.time()
    if now_time - last_time < ADD_ENERGY_CYCLE then
        return nil
    end

    print("restore_energy")
    local add_muiltiple = (now_time - last_time) // ADD_ENERGY_CYCLE
    last_time = last_time + add_muiltiple * ADD_ENERGY_CYCLE

    local last_energy = char.fight_attr.energy
    char.fight_attr.energy = math.min(char.fight_attr.energy + ADD_ENERGY * add_muiltiple,char.fight_attr.max_energy)
    char.last_add_energy_time = last_time

    local add_energy =  char.fight_attr.energy - last_energy

    char:mark_updated()
    return {add_energy=add_energy}
end

function REQUEST.get_map_rank( req )
    local char = user.character
    local map_id = req.map_id
    local diff = req.diff

    local ok,conf = Map.check_map_valid(map_id,diff)
    if not ok then
        return char:get_error_ret("cant find map conf")
    end

    --1:普通 2：精英 3：地狱 4：擂台 5：天梯 6：团战
    if conf.type ~= 2 and conf.type ~=3 then
        return char:get_error_ret("this type map dont have rank")
    end

    local rank,countdown = skynet.call(database,"lua","map","get_rank",map_id,diff)
    if countdown <=0 then
        countdown = -1
    end

    return char:get_succ_ret({rank=rank,ref_countdown=countdown})
end

return handler