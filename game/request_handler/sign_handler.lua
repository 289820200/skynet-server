--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-18
-- @Description:  签到处理
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

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

local function if_yestoday_signed( )
    local char = user.character
    local sign_rec = char.sign_record
    local day_sec = 3600 * 24
    if sign_rec.last_sign_time then
        local today = os.time() // day_sec
        local last_sign_day = sign_rec.last_sign_time // day_sec
        return last_sign_day == today - 1
    else
        return false
    end
end

local function deal_daily_reward( )
    local char = user.character
    local daily_conf_set = gdd.sign_reward

    local day_sec = 3600 * 24
    local create_day = char.create_time // day_sec
    local today =  os.time() // day_sec
    --奖励周期，奖励按30天为一个轮回月。
    local phase = (today - create_day ) % 30 + 1
    --现在先按每天都是固定奖励配置，留个可以变动奖励的坑
    local daily_conf = daily_conf_set[phase] or daily_conf_set[1]
    local daily_reward
    if daily_conf then
        daily_reward = {}
        for i,v in ipairs(daily_conf.reward_list) do
            table.insert(daily_reward,{id=v.id,num=v.num})
        end
        daily_reward = char:give_reward(daily_reward)
    end

    return daily_reward
end

local function deal_continual_reward(  )
    local char = user.character
    local sign_rec = char.sign_record

    local conti_reward
    if sign_rec.continual_day >= 7 and sign_rec.continual_day % 7 == 0 then
        --给奖励
        local conti_conf_set = gdd.sign_continual_reward

        local c_reward_num = sign_rec.continual_day // 7
        --现在先按每次都是固定奖励配置，留个可以变动奖励的坑
        local conti_conf = conti_conf_set[c_reward_num] or conti_conf_set[1]

        if conti_conf then
            conti_reward = {}
            for i,v in ipairs(conti_conf.reward_list) do
                table.insert(conti_reward,{id=v.id,num=v.num})
            end
            conti_reward = char:give_reward(conti_reward) 
        end
    end

    return conti_reward
end

function REQUEST.sign_up( args )
    local char = user.character
    local sign_rec = char.sign_record
    local sign_list = sign_rec.sign_list or {}

    local cur_date = os.date("*t",os.time())
    local year = cur_date.year
    local month = cur_date.month
    local day = cur_date.day
    
    local target_month
    for i,v in ipairs(sign_list) do
        if v.year == year and v.month == month then
            target_month = sign_list[i]
        end
    end

    --添加记录
    local today_flag = 1 << (day - 1)
    if target_month then 
        if (target_month.sign & today_flag) ~= 0 then
            return {status=0,msg="have signed up"}
        end
        target_month.sign = target_month.sign | today_flag
    else
        local tmp = {year=year,month=month,sign=today_flag}
        table.insert(sign_list,tmp)
        target_month = sign_list[#sign_list]
    end
    sign_rec.sign_list = sign_list

    --检查连续天数
    local if_continue = if_yestoday_signed()
    if if_continue then
        sign_rec.continual_day = sign_rec.continual_day + 1
    else
        sign_rec.continual_day = 1
    end
    --更新签到时间
    sign_rec.last_sign_time = os.time()

    --签到奖励
    local daily_reward = deal_daily_reward()

    --连续签到奖励
    local continual_reward = deal_continual_reward()

    --添加到排行榜
    skynet.call("sign_ranking","lua","sign",char.id,sign_rec.continual_day)

    return {status=1,msg="",daily_reward=daily_reward,continual_reward=continual_reward}
end

function REQUEST.get_sign_ranking( args )
    local char = user.character
    local rank_info = skynet.call("sign_ranking","lua","get_rank",char.id)
    if not rank_info then
        return {status=0,msg="get rank err"}
    end
    rank_info.self_num = char.sign_record.continual_day
    return {status=1,msg="",rank_info=rank_info}
end

function REQUEST.sign_ranking_likes( args )
    local char = user.character
    local src_char_id = char.id
    local des_char_id = args.char_id
    if src_char_id == des_char_id then
        return {status=0,msg="cant like self"}
    end
    local ok,msg = skynet.call("sign_ranking","lua","likes",src_char_id,des_char_id)
    if not ok then
        return {status=0,msg=msg}
    end
    --点赞成功给奖励
    --[1]是点赞奖励配置，[2]是被点赞奖励配置
    local reward_conf = gdd.sign_like_reward[1]
    if not reward_conf then
        return {status=0,msg="reward conf err"}
    end
    local tmp_reward
    local ran_num = math.random(10000)
    if reward_conf.prob >= ran_num then
        tmp_reward = {}
        for k,v in pairs(reward_conf.reward_list) do
            table.insert( tmp_reward,{id=v.id,num=v.num,lv=v.lv})
        end
        tmp_reward = char:give_reward(tmp_reward)
    end

    return {status=1,msg="",reward=tmp_reward}
end 



return handler

