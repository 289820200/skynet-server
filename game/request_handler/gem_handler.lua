local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Gem"
require "polo.StuffFactory"
require "common.predefine"

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


function REQUEST.gem_synthesis( req )
    local char = user.character
    local recipe_id = req.recipe_id

    local conf = gdd.recipe[recipe_id]
    if not conf then
        return char:get_error_ret("recipe conf err")
    end

    if not conf.type ==  2 then
        return char:get_error_ret("recipe type err")
    end

    local gem_id = conf.product_list[char.class_id] or conf.product_list[1]
    if not gem_id then
        return char:get_error_ret("equip id err")
    end

    local gem_conf = gdd.gem[gem_id]
    if not gem_conf then
        return char:get_error_ret("gem conf err")
    end

    for k,v in pairs(conf.material_list) do
        if not char:is_stuff_enough(v.id,v.num) then
            return char:get_error_ret("material num not enough")
        end
    end

    for k,v in pairs(conf.material_list) do
        char:add_stuff(v.id,-v.num,"gem synthesis")
    end

    --随机等级
    local random_lv = Gem.get_random_lv(gem_id)
    if random_lv <= 0 then
        return char:get_error_ret("gem init err")
    end

    --添加装备
    local new_gem = char:add_gem(gem_id,1,random_lv)
    
    --发送广播
    if random_lv >=5 then
        local msg = string.format("恭喜%s，成功合成%d级的%s宝石！",char.nickname,random_lv,gem_conf.name)
        user:publish_world_broadcast(msg)
    end

    char:mark_updated()
    --add_gem返回的是table
    return char:get_succ_ret({new_gem = new_gem[1]})
end

function REQUEST.gem_level_up( req )
    local char = user.character
    local src_list = req.src_list
    local des_uuid = req.des_uuid

    local des_gem = char:get_stuff_by_uuid("gem",des_uuid)
    if not des_gem then
        return char:get_error_ret("cant find des gem")
    end

    local gem_conf = gdd.gem[des_gem.id]
    if not gem_conf then
        return char:get_error_ret("gem conf err")
    end

    local des_exp_conf = gdd.gem[des_gem.id]
    if not des_exp_conf then
        return char:get_error_ret("cant find des gem exp conf")
    end

    local total_exp = 0
    for k,v in pairs(src_list) do
        local src_gem = char:get_stuff_by_uuid("gem",v)
        if not src_gem then
            return char:get_error_ret("cant find src gem,uuid:"..v)
        end
        local src_gem_conf = gdd.gem[src_gem.id]
        if not src_gem_conf then
            return char:get_error_ret("cant find src gem conf,uuid"..v)
        end
        total_exp = total_exp + (src_gem_conf.give_exp_list[src_gem.lv or 1] or 0)
    end


    if total_exp <= 0 then
        return char:get_error_ret("gem exp conf err:exp<=0")
    end

    for k,v in pairs(src_list) do
        if not char:delete_stuff("gem",v) then
            return char:get_error_ret("delete src gem err,uuid:"..v)
        end
    end

    local old_lv = des_gem.lv

    des_gem:add_exp(total_exp)

    if des_gem.lv > old_lv and des_gem.lv >= 5 then
        local msg = string.format("恭喜%s，成功将%s宝石升级到%d级！",char.nickname,gem_conf.name,des_gem.lv)
        user:publish_world_broadcast(msg)
    end

    char:mark_updated()

    return char:get_succ_ret({new_gem=des_gem})
end










return handler