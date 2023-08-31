--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-20
-- @Description:  商城处理
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

local function ref_item_rec(  )
    local char = user.character
    local gs_rec = char.goods_record
    gs_rec.item_record = {}
    local item_conf_set = gdd.shop_item
    local vip_conf = gdd.vip[char.vip] or gdd.vip[0]

    for k,v in pairs(item_conf_set) do
        if v.type == 2 then
            local num = vip_conf.shop_item_num or 0
            table.insert(gs_rec.item_record,{id=v.id,num=num})
        end
    end
end

local function ref_gift_rec(  )
    local char = user.character
    local gs_rec = char.goods_record
    gs_rec.gift_record = {}
    local item_conf_set = gdd.shop_item
    local vip_conf = gdd.vip[char.vip] or gdd.vip[0]

    for k,v in pairs(item_conf_set) do
        if v.type == 3 then
            local num = vip_conf.shop_gift_num or 0
            table.insert(gs_rec.gift_record,{id=v.id,num=num})
        end
    end
end

local function ref_treasure_rec(  )
    local char = user.character
    local gs_rec = char.goods_record
    gs_rec.treasure_record = {}
    local item_conf_set = gdd.shop_treasure
    local vip_conf = gdd.vip[char.vip] or gdd.vip[0]

    for i=1,MAX_TREASURE_NUM do
        local total_prob = 0
        local tmp_prob = 0
        for k,v in pairs(item_conf_set) do
            --挤圆桌总概率
            total_prob = total_prob + v.prob
        end
        local ran_num = math.random(total_prob)
        for k,v in pairs(item_conf_set) do
            tmp_prob = tmp_prob + v.prob
            if tmp_prob >= ran_num then
                local num = vip_conf.shop_treasure_num
                table.insert(gs_rec.treasure_record,{id=v.id,num=num})
                break
            end
        end
    end
end

--更新奇珍阁刷新次数和时间，更新道具和礼包刷新状态
--奇珍阁每隔一段时间增加一次刷新次数，道具和礼包每天0点刷新
local function update_ref_time(  )
    local char = user.character
    local gs_rec = char.goods_record
    local now_time = os.time()
    --刷新道具礼包状态
    local last_item_ref_time = gs_rec.last_item_ref_time or 0
    local last_item_ref_date = last_item_ref_time // ONE_DAY_SEC
    local now_date = now_time // ONE_DAY_SEC
    if now_date - last_item_ref_date >= 1 then
        --刷新道具礼包购买记录
        ref_item_rec()
        ref_gift_rec()
        --道具和礼包刷新时间一致
        gs_rec.last_item_ref_time = now_time
    end

    --刷新奇珍阁
    --3小时增加一次刷新机会
    local ref_cycle = ONE_HOUR_SEC * 3
    local time_interval =  now_time - (gs_rec.last_treasure_ref_time or 0)
    local add_time = time_interval // ref_cycle

    --vip等级增加最大刷新次数
    local vip_conf = gdd.vip[char.vip] or gdd.vip[0]
    local max_ref_num = vip_conf.shop_treasure_ref_num or 1

    gs_rec.last_treasure_ref_time = now_time
    local old_ref_num = gs_rec.treasure_ref_num or 0
    gs_rec.treasure_ref_num = math.min(old_ref_num + add_time,max_ref_num)
    gs_rec.treasure_ref_time = ref_cycle - time_interval % ref_cycle

    if not gs_rec.treasure_record then
        ref_treasure_rec()
    end
end

function REQUEST.get_goods_list( args )
    --先刷新一下商城状态
    update_ref_time()

    local char = user.character
    local gs_rec = char.goods_record

    --获取商品列表时，更新一下刷新次数和下次增加刷新次数的时间
    local type = args.type

    local record
    --type 1:奇珍阁 2：道具 3：礼包
    if type == 1 then
        record = gs_rec.treasure_record
    elseif type == 2 then
        record = gs_rec.item_record
    elseif type == 3 then
        record = gs_rec.gift_record
    else
        return {status=0,msg="goods type err"}
    end

    --刷新情况
    local t_ref_num = gs_rec.treasure_ref_num
    local t_ref_time = gs_rec.treasure_ref_time

    char:mark_updated()
    return {status=1,msg="",goods_list = record,ref_num=t_ref_num,ref_time=t_ref_time}
end

function REQUEST.buy_goods( args )
    local char = user.character
    local gs_rec = char.goods_record

    local type = args.type
    local index = args.index
    local buy_num = args.num

    local record
    local conf_set
    if type == 1 then
        record = gs_rec.treasure_record
        conf_set = gdd.shop_treasure
    elseif type == 2 then
        record = gs_rec.item_record
        conf_set = gdd.shop_item
    elseif type == 3 then
        record = gs_rec.gift_record
        conf_set = gdd.shop_item
    else
        return {status=0,"buy goods type err"}
    end

    --判定
    local target = record[index]
    if not target then
        return {status=0,msg="buy goods not exist"}
    end

    if target.num < buy_num then
        return {status=0,msg="goods num not enough"}
    end

    local conf = conf_set[target.id]
    if not conf then
        return {status=0,msg="goods conf err"}
    end

    --是否在打折期间
    local price
    if conf.is_discount then
        local now_time = os.time()
        local begin_time = conf.discount_begin_time
        local end_time = conf.discount_begin_time + conf.discount_duration_time
        if now_time >= begin_time and now_time <=  end_time then
            price = conf.discount_price
        else
            price = conf.price
        end
    else
        price = conf.price
    end 

    if not char:is_stuff_enough(RMB_ID,price * buy_num) then
        return {status=0,msg="rmb not enough"}
    end

    --操作
    target.num = target.num - buy_num
    char:add_stuff(RMB_ID,-price * buy_num)

    local goods = {[1] = {id=conf.item_id,num=conf.item_num * buy_num}}

    goods = char:give_reward(goods,"shop buy")

    char:mark_updated()
    return {status=1,msg="",goods=goods[1]}
end

--刷新奇珍阁
function REQUEST.refresh_treasure( args )
    local char = user.character
    local gs_rec = char.goods_record

    if gs_rec.treasure_ref_num > 0 then
        gs_rec.treasure_ref_num = gs_rec.treasure_ref_num - 1
        ref_treasure_rec()
    else
        if not char:is_stuff_enough(RMB_ID,REF_TREASURE_COST) then
            return {status=0,msg="rmb not enough"}
        end
        char:add_stuff(RMB_ID,-REF_TREASURE_COST)
        ref_treasure_rec()
    end
    
    char:mark_updated()
    return {status=1,msg="",goods_list=gs_rec.treasure_record}
end

return handler
