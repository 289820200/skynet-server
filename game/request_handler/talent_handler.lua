local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Talent"

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

function REQUEST.talent_level_up( args )
    local char = user.character
    local type = args.type
    local target_talent = char.talent_list[type]
    if not target_talent then
        return {status=0,msg="talent type err"}
    end

    local ok,msg = target_talent:check_level_up(char.lv)
    if not ok then 
        return {status=0,msg=msg}
    end

    local cost = target_talent:level_up_cost()
    if not cost then
        return {status=0,msg="talent level up cost not enough"}
    end

    for k,v in pairs(cost) do
        local enough = char:is_stuff_enough(v.id,v.num)
        if not enough then
            return {status=0,msg="talent level up cost not enough"}
        end
    end

    for k,v in pairs(cost) do
        char:add_stuff(v.id,-v.num,"talent level up"..v.id)
    end

    target_talent:level_up()

    char:mark_updated()
    return {status=1,msg= ""}
end


return handler