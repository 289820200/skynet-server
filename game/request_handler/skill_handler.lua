local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Skill"

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

function REQUEST.get_skill_list(args)
    local char = user.character
    local skill_conf = gdd.skill

    local skill_list 
    if args.type==0 then 
        skill_list = char.skill_list
    else
        for k,v in pairs(char.hero_list) do
            if v.id == args.hero_id then
                skill_list = v.skill_list
            end
        end
    end

    if not skill_list then
        return {status=0,msg="no  this hero :",args.hero_id}
    end

    local list = {}
    for k,v in pairs(skill_list) do
        local tmp = {}
        tmp.id = v.id
        tmp.level = v.level
        tmp.is_using = v.is_using
        tmp.index = v.index or 0
        table.insert(list,tmp)
    end

    return {status = 1,mag = "",skill = list}

end

function REQUEST.skill_unlock( args )
    local char = user.character
    local skill_list = char.skill_list
    local skill_id = args.id
    local skill_conf = gdd.skill

    if not skill_conf[skill_id] then
        return {status=0,msg="skill conf err"}
    end

    local target_skill
    for k,v in pairs(skill_list) do
        if v.id == skill_id then
            target_skill = v
        end
    end

    if not target_skill then
        return {status=0,msg="havnt this skill"}
    end

    if  target_skill.level > 0 then
        --级别大于0说明解锁过。先返回正确结果吧。
        return {status=1,msg="repate unlock"}
    end

    
     --检查等级要求
    local ok,msg = target_skill:check_unlock(char.lv)
    if not ok then
        return {status=0,msg=msg}
    end

    local cost = target_skill:unlock_cost()
    if not cost then
        return {status=0,msg="conf err"}
    end

    for k,v in pairs(cost) do
        local enough = char:is_stuff_enough(v.id,v.num)
        if not enough then 
            return {status=0,msg="cost not enough"}
        end
    end

    for k,v in pairs(cost) do
        char:add_stuff(v.id,-v.num,"unlock skill"..skill_id)
    end

    target_skill:unlock()

    char:mark_updated()

    return {status=1,msg= ""}
end

function REQUEST.skill_level_up( args )
    local char = user.character
    local skill_id = args.skill_id
    local skill_conf = gdd.skill
    local skill_list
    local role_level = 1

    if args.up_type==0 then 
        skill_list = char.skill_list
        role_level = char.lv
    else
        local hero_list = char.hero_list
        for k,v in pairs(hero_list) do
            --可能出现多个相同武将
            if v.uuid == args.hero_id then
                skill_list = v.skill_list
                role_level = v.lv
            end
        end
        if not skill_list then
            return {status=0,msg="hero id err"}
        end
    end

    local target_skill
    for k,v in pairs(skill_list) do
        if v.id == skill_id then
            target_skill = v
        end
    end

    if not target_skill then
        return {status=0,msg="havnt this skill"}
    end

    --检查等级要求
    local ok,msg = target_skill:check_level_up(role_level)
    if not ok then
        return {status=0,msg=msg}
    end

    local cost = target_skill:level_up_cost()
    if not cost then
        return {status=0,msg="conf err"}
    end

    for k,v in pairs(cost) do
        local enough = char:is_stuff_enough(v.id,v.num)
        if not enough then
            return {status=0,msg="skill level up cost not enough"}
        end
    end

    for k,v in pairs(cost) do
        char:add_stuff(v.id,-v.num,"skill level up"..skill_id)
    end
    target_skill.level = target_skill.level + 1

    char:mark_updated()

    return {status = 1,msg= ""}
end

function REQUEST.skill_put_on( args )
    local char = user.character
    local skill_id = args.id
    local index = args.index
    local skill_list = char.skill_list
    --2个技能槽
    if index<=0 or index >=3 then
        return {status=0,msg="index err"}
    end

    local target_skill
    for k,v in pairs(skill_list) do
        if v.id == skill_id then
            target_skill = v
            break
        end
    end

    if not target_skill then
        return {status=0,msg="havnt this skill"}
    end
    
    if target_skill.level == 0 then
        return {status=0,msg="havnt unlock"}
    end

    if target_skill.is_using == true then
        return {status=1,msg = ""}
    end

    local using_num = 0

    for k,v in pairs(skill_list) do
        if v.is_using == true then
            --对应位置有的话，就替换掉
            if v.index == index then
                v:take_off()
            end
        end
    end

    target_skill:put_on(index)

    char:mark_updated()

    return {status=1,msg=""}
end

function REQUEST.get_using_skill_list()
    local char = user.character
    local skill_list = char.skill_list
    local list = {}
    for k,v in pairs(skill_list) do
        if v.is_using == true then
            local tmp = {}
            tmp.id = v.id
            tmp.level = v.level
            tmp.index = v.index
            tmp.is_using = true
            table.insert(list,tmp)
        end   
    end
    table.sort(list,function ( lhs,rhs )
        return lhs.index < rhs.index
    end)
    
    return {status=1,mag= "",skill=list}
end

return handler
