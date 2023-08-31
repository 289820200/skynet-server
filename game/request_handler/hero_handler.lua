local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Hero"

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


-- 上阵
function REQUEST.hero_on_off(req)
    local on = req.on 
    local uuid_list = req.uuid_list or {}
    local char = user.character
    if #uuid_list>3 then 
        return char:get_error_ret("副将参数非法")
    end

    for k,v in pairs(uuid_list) do
        local uuid = v
        local hero = char:is_had_hero(uuid)
        if not hero then 
            return char:get_error_ret("找不到副将")
        end
    end

    if on then 
        -- TODO 可能要改开放
        --  全线下阵
        for k,v in pairs(char.hero_list) do 

            local find  -- 是否在出战列表中
            local hero_id = v.uuid
            for m,n in pairs(uuid_list) do
                if n == hero_id then 
                    find = true 
                    break
                end
            end

            local is_on = v:is_on()
            if is_on then 
                -- 当前出战状态
                if not find then 
                    -- 如果不在上阵列表则下阵
                    v:get_off()
                end
            else
                -- 当前没有出战
                if find then 
                    -- 在上阵列表则出战
                    v:get_on()
                end
            end            
        end
        char:mark_updated()
        return {status=1}
    else
        -- 下阵
        for k,v in pairs(uuid_list) do
            local hero = char:is_had_hero(v)
            hero:get_off()
        end

        char:mark_updated()
        return {status=1}
    end
end

-- 吃道具增加经验
function REQUEST.hero_add_exp( req )
    local uuid = req.uuid
    local stuff_list = req.stuff_list
    local char = user.character
    local hero = char:is_had_hero(uuid)
    if not hero then 
        return char:get_error_ret("找不到该副将")
    end 
    if #stuff_list == 0 then 
        return char:get_error_ret("道具列表为空")
    end

    for m,n in ipairs(stuff_list) do
        -- 道具是否足够
        local stuff_id = n.id
        local stuff_num = n.num
        if stuff_num > 0 then
            local item,idx = char:is_stuff_enough(stuff_id,stuff_num)
            if not item then 
                return char:get_error_ret("道具不足")
            end  
        end     
    end

    local ret_stuff_list = {}

    local stuff_prop = gdd.stuff_prop
    local lv_limit = char.lv
    local total_exp = 0
    for m,n in ipairs(stuff_list) do
        -- 每个道具增加多少点经验值 
        local stuff_id = n.id
        local stuff_num = n.num
        if stuff_num > 0 then
            local item,idx = char:is_stuff_enough(stuff_id,stuff_num)
            local reward_list,msg = item:use(stuff_num) or {}
            local per_exp = 0
            for k,v in ipairs(reward_list) do
                local id = v.id
                local prop = stuff_prop[id].name
                if prop~='hero_exp' then
                    per_exp = 0
                    break
                end
                per_exp = per_exp + v.num
            end

            if per_exp > 0 then
                -- 消耗
                char:add_item(stuff_id,-stuff_num,"add_exp uuid:"..hero.uuid.." id:"..hero.id)
                total_exp = total_exp + per_exp  
                table.insert( ret_stuff_list,n )
            end
        end     
    end

    hero:add_exp(total_exp,lv_limit)

    char:mark_updated()

    return char:get_succ_ret({uuid=uuid,add_exp=total_exp,stuff_list=ret_stuff_list})
end

-- 洗练
function REQUEST.hero_refined(req)
    local uuid = req.uuid
    local from_uuid = req.from_uuid 

    -- 是否有
    local char = user.character
    local hero = char:is_had_hero(uuid)
    local from_hero = char:is_had_hero(from_uuid)

    if not hero then 
        return char:get_error_ret("没有找到该副将。")
    end
    if not from_hero then 
        return char:get_error_ret("没有找到该副将。")
    end
    if hero.id ~= from_hero.id then 
        return char:get_error_ret("副将类型不匹配。")
    end 

    local ok,msg = hero:refined(from_hero)
    if not ok then
        return char:get_error_ret(msg)
    end

    char:remove_hero(from_uuid)

    char:mark_updated()
    return char:get_succ_ret({
            uuid = uuid,
            from_uuid = from_uuid,
            atk_grow = hero.attr.atk_grow,
            def_grow = hero.attr.def_grow,
            hp_grow = hero.attr.hp_grow,
        }) 
end

-- 洗练恢复
function REQUEST.hero_refined_back(req)
    -- local uuid = req.uuid     
    -- -- 是否有
    local char = user.character
    -- local hero = char:is_had_hero(uuid)
    -- if not hero then 
    --     return char:get_error_ret("没有找到该副将")
    -- end
    -- local suc,aptitude,apt_value = hero:refined_back()
    -- if not suc then 
    --     return char:get_error_ret(aptitude)
    -- end
    -- local ret ={
    --     status = 1,
    --     success = suc,        
    --     aptitude = aptitude,
    --     apt_value = apt_value,
    -- }
    -- char:mark_updated()
    -- return ret 
    return char:get_error_ret("副将类型不匹配。")
end


-- 进阶
function REQUEST.hero_up_grade(req)
    local uuid = req.uuid     
    local char = user.character

    local hero = char:is_had_hero(uuid)
    if not hero then 
        return char:get_error_ret("没有找到该副将")
    end

    local data = Hero.get_data(hero.id)
    if not data then
        return char:get_error_ret("副将配置错误")
    end  

    local cur_grade = hero.grade or 0
    local next_grade = cur_grade + 1

    local need_level = data.up_grade_lv_list[next_grade]
    if not need_level then
        return char:get_error_ret("副将无法升阶")
    end

    if hero.lv < need_level then
        --return char:get_error_ret("副将等级不足")
    end

    local conf_cost_list = data.up_grade_cost_list[next_grade]
    if not conf_cost_list then
        return char:get_error_ret("副将无法升阶")
    end
    local cost_list = {}
    for k,v in pairs(conf_cost_list) do
        table.insert( cost_list,{id=v.id,num=v.num})
    end

    --检查消耗
    for k,v in ipairs(cost_list) do
        local id = v.id
        local num = v.num         
        local enough = char:is_stuff_enough(id,num)
        if not enough then
            return char:get_error_ret("材料不足")
        end
    end
    print("hero up_grade 1")
    --扣掉消耗
    for k,v in ipairs(cost_list) do
        local id = v.id
        local num = v.num 
        char:add_stuff(id,-num)        
    end

    --升阶
    --除非配置出错，这里是不会失败的
    local ok,msg = hero:up_grade()
    if not ok then
        return char:get_error_ret(msg)
    end
    print("hero up_grade 2")
    -- 跑马灯
    -- 升阶成功时给予全服跑马灯提示：XX真是碉堡了，成功将“张辽”升到N阶！
    local nickname = char.nickname

    local public = string.format("%s真是碉堡了，成功将“%s”升到“%s”阶！",nickname,data.name,hero.grade)
    user:publish_world_broadcast(public)

    char:mark_updated()

    return char:get_succ_ret({uuid=uuid,new_attr=hero.attr,cost_list=cost_list}) 
end

-- 副将分解

function REQUEST.hero_break_up( req )
    local uuid = req.uuid     
    -- 是否有
    local char = user.character
    local hero = char:is_had_hero(uuid)
    if not hero then 
        return char:get_error_ret("没有找到该副将")
    end
    -- 删除副将
    char:remove_hero(uuid)
    local data = Hero.get_data(hero.id)  
    local break_up = data.break_up
    for k,v in ipairs(break_up) do
        char:add_stuff(v.stuff_id,v.num,"break_up")
    end
    char:mark_updated()
    return char:get_ret_short()
end

--武将召唤
function REQUEST.hero_summon( req )
    local char = user.character
    local hero_id = req.hero_id

    local conf = gdd.hero[hero_id]
    if not conf then
        return char:get_error_ret("hero conf err")
    end

    if not conf.debris_id then
        return char:get_error_ret("武将魂魄id错误")
    end

    if not char:is_stuff_enough(conf.debris_id,conf.debris_num) then
        return char:get_error_ret("武将魂魄不足")
    end

    char:add_stuff(conf.debris_id,-conf.debris_num,"hero summon")
    
    --Character:add_hero(id,lv,exp,to_fight) 
    local new_hero = char:add_hero(hero_id,1,0,false)

    if not new_hero then
        return char:get_error_ret("add hero error")
    end

    return char:get_succ_ret({new_hero = new_hero})
end


return handler