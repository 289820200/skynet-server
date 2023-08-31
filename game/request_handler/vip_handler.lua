local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"
require "common.predefine"

require "polo.VIP"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd

handler:init (function (u)    
    user = u
    database = ".database" 
    gdd  = sharedata.query "settings_data"
    vip_data  = gdd.vip
    recharge_data = gdd.recharge
end)




-- 下单
function REQUEST.recharge_order(req)
    local ret = skynet.call(".recharge","lua","recharge_order",req)
    return ret 
end

-- 充值回调
function REQUEST.recharge_notify( data )
    print("充值回调","recharge_notify")
    -- 充值 id 
    local char = user.character
    -- 计费点
    local pay_point = data.pay_point

    -- 是否首充
    local is_first = false 
    --经过decode之后的pay_point不是整数，而是类似10.0这样的
    local num = math.floor(pay_point * 10)
    
    if is_first then 
        
    end

    if char then 
        char:add_stuff(RMB_ID,num,"recharge")
    end
    -- 通知到账 
    -- 更新的数据，不只元宝
    local update_info = {
        rmb = char.rmb,
        money=char.money,
        package=char.package,
        hero_list=char.hero_list,
    }
    
    return update_info
end

return handler