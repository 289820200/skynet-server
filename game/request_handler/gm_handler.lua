--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-02-18 
-- @Description:  GM命令处理
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"
require "common.predefine"
require "polo.StuffFactory"


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

local char_gm_cmd = {
    [1] = "gm_add_stuff",
    [2] = "gm_level_up",
    [3] = "gm_add_hero",
    [4] = "gm_set_char_attr",
    [5] = "gm_set_hero_attr",
    [6] = "gm_unlock_all_map",
}

local CMD = {}

function CMD.gm_add_stuff( args )
    local char = user.character
    local id = tonumber(args.id)
    local num = tonumber(args.num) or 1

    if not id then
        return false,"stuff id nil"
    end

    if not StuffFactory.is_stuff_id_legal(id) then
        return false,"stuff id not legal"
    end

    char:add_stuff(id,num,"gm add char,id,num:"..char.id..","..id..","..num)
    return true
end

function CMD.gm_level_up( args )
    local char = user.character
    local lv = tonumber(args.level)

    if not lv or lv <= 0 then
        return false,"lv err"
    end

    --为了能触发升级处理，只好用加经验的方法了
    local class_id = char.class_id 
    local class_level_info = gdd.class_level_info
    local level_data = class_level_info[class_id]

    local total_exp = 0
    local cur_lv = char.lv
    for i=cur_lv,cur_lv + lv - 1 do
        if not level_data[i] then
            break
        end
        total_exp = total_exp + level_data[i].exp
    end

    char:add_stuff(EXP_ID,total_exp,"gm add lv char,num:"..char.id..","..lv)

    return true
end

function CMD.gm_add_hero( args )
    local char = user.character
    local id = tonumber(args.id)
    local level = tonumber(args.level) or 1

    if not id then
        return false,"hero id nil"
    end

    local hero_conf_set = gdd.hero
    if not hero_conf_set[id] then
        return false,"hero conf err"
    end

    char:add_hero(id,level,0,false)
    char:mark_updated()
    
    return true
end

function CMD.gm_set_char_attr( args )
    local char = user.character
    local id = tonumber(args.id)
    local attr_type = args.attr_type
    if (not attr_type) then
        return false,"attr type nil"
    end

    local base_num = char.fight_attr[attr_type]
    if (not base_num) or (type(base_num) ~= "number") then
        return false,"attr type err"
    end

    local add_num = tonumber(args.add_num)
    if not add_num then
        return false,"add attr num err"
    end

    char.fight_attr[attr_type] = base_num + add_num

    char:mark_updated()
    return true
end

function CMD.gm_set_hero_attr( args )
    local char = user.character
    local index = tonumber(args.index)
    local attr_type = args.attr_type

    if (not attr_type) then
        return false,"attr type nil"
    end

    local target_hero = char.hero_list[index]

    if not target_hero then
        return false,"not this hero"
    end

    local base_num = target_hero[attr_type]
    if (not base_num) or (type(base_num) ~= "number") then
        return false,"attr type err"
    end

    local add_num = tonumber(args.add_num)
    if not add_num then
        return false,"add attr num err"
    end

    target_hero[attr_type] = base_num + add_num

    return true
end

function CMD.gm_unlock_all_map( req )
    local char = user.character
    local conf_set = gdd.scene_chapter

    for k,v in pairs(conf_set) do
        --map配置
        for m,n in pairs(v) do
            char:set_map_record(n.scene_id,n.level,3)
        end     
    end

    return true
end

function REQUEST.gm_command( req )
    local char = user.character
    local cmd_type = tonumber(req.type)

    local fun_name = char_gm_cmd[cmd_type]
    if not fun_name then
        return false,"cmd err"
    end

    local f = CMD[fun_name]
    local ok,msg = f(req)

    if ok then
        char:save()
    end

    return ok,msg,char
end


return handler