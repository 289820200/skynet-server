--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-26 
-- @Description:  签到管理器
--------------------------------------

package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local print_r = require "common.print_r"
require "common.predefine"

local sign_rank
local last_ref_time
local CMD = {}
local gdd 
local database

local function ref_sign_rank(  )
    skynet.call(database,"lua","sign","ref_today_rank")
end

local function get_sign_rank( )
    last_ref_time = last_ref_time or 0
    local last_date = last_ref_time // ONE_DAY_SEC
    local now_date = os.time() // ONE_DAY_SEC
    --排行榜过期的话要更新
    if now_date - last_date >= 1 then
        ref_sign_rank()
    end
    sign_rank = skynet.call(database,"lua","sign","get_today_rank")
end

--获取签到榜
function CMD.get_rank( char_id )
    --获取榜单前10名的角色名和签到数，自身签到数和排行
    if not sign_rank then
        get_sign_rank()
    end
    local rank_info = {}
    rank_info.list = {}
    for i,v in ipairs(sign_rank) do
        if i <= 10 then
            local likes = 0
            local is_liked = false
            v.likes_list = v.likes_list or {}
            for m,n in pairs(v.likes_list) do
                likes = likes + 1
                if n == char_id then
                    is_liked = true
                end
            end
            table.insert(rank_info.list,{char_id=v.char_id,name=v.name,num=v.num,likes=likes,is_liked=is_liked})
        end
        if v.char_id == char_id then
            if i <= 500 then
                rank_info.self_rank = i
            elseif i <= 1000 then
                --大于500的显示500开外
                rank_info.self_rank = 501
            else
                --大于1000的显示1000开外
                rank_info.self_rank = 1001
            end
        end
    end
    -- -1表示未上榜
    rank_info.self_rank = rank_info.self_rank or -1
    return rank_info
end

--签到
function CMD.sign( char_id,num )
    if char_id and num then
        skynet.call(database,"lua","sign","sign_up",{char_id=char_id,num=num})
        return true
    else
        return false
    end
end

--给签到榜上的人点赞
function CMD.likes( src_char_id ,des_char_id)
    local target

    for i,v in ipairs(sign_rank) do
        if i > 10 then
            break
        end
        if v.char_id == des_char_id then
            target = sign_rank[i]
            break
        end
    end

    if not target then
        return false,"not this char"
    end

    --不能重复给同一个人点赞
    target.likes_list = target.likes_list or {}

    for k,v in pairs(target.likes_list) do
        if v == src_char_id then
            return false,"had like this char"
        end
    end

    table.insert(target.likes_list,src_char_id)

    return true
end

--发放签到榜奖励
function CMD.give_rank_reward(  )
    local reward_conf = gdd.sign_like_reward[2]
    local base_reward = {}

    if not reward_conf then
        return
    end
    local base_reward = reward_conf.reward_list
   
    --每个点赞数都有一定几率给被赞的人奖励，至少会获得一份奖励
    for i,v in pairs(sign_rank) do
        --前10名才有奖励
        if i > 10 then
            break
        end

        local reward = {}
        if v.likes_list then
            for m,n in pairs(v.likes_list) do
                local ran_num = math.random(10000)
                if reward_conf.prob > ran_num then
                    RewardTool.merge_reward_table(reward_conf.reward_list,reward)
                end
            end
        end

        local mail_data = {
            --用-1表示系统邮件，暂时
            src_char=-1,
            type=2,
            title="签到榜奖励",
            content=string.format("您好,您昨天在签到榜获得了%d个赞,以下是您得到的随机奖励,赞的数量越多,随机奖励就越多哦!",v.num),
            des_char_list= {[1] = v.char_id},
            attachment = reward,
        }

        skynet.call("mail_center","lua","send_mail",mail_data)
    end

    --发完奖励刷新排行榜
    get_sign_rank()
end


skynet.start(function ()
    skynet.dispatch("lua", function(session,source, cmd, ...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
    gdd = sharedata.query "settings_data"
    database = ".database"
end)
