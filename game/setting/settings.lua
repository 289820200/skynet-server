--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-10-12 16:14:30
-- @Description: settings 文件 解析 
--------------------------------------
package.path = "game/?.lua;" .. package.path

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local CMD = {}
local time_mgr = require "common.time_mgr"
local SplitStr = require "common.SplitStr"

require "common.predefine"
local function SplitStr(source, pattern, init)
    local lens = string.len(source)
    local lenp = string.len(pattern)

    local result = init or {}
    local c = 0

    local i = 1
    local start = 1
    while i <= lens - lenp + 1 do
        local found = true
        for j = 1, lenp do
            if string.byte(source, i + j - 1) ~= string.byte(pattern, j) then
                found = false
                break
            end
        end
        if found then
            if i >= start then
                c = c + 1
                result[c] = string.sub(source, start, i - 1)
            end
            start = i + lenp
            i = start
        else
            i = i + 1
        end
    end
    if start <= lens then
        local same = false
        if lens - start + 1 == lenp then
            same = true
            for j = 1, lenp do
                if string.byte(source, start + j - 1) ~= string.byte(pattern, j) then
                    same = false
                    break
                end
            end
        end
        if not same then
            c = c + 1
            result[c] = string.sub(source, start, lens)
        end
    end
    result.c = c
    for i = c + 1, #result do
        result[i] = nil
    end
    return result
end

--------------------------------------
-- 解析一个文件成 table 
-- 第一行是每个字元素的key
-- 第二行是每个字元素的注释
-- 第三行为每个字元素的类型
-- 第四行以后为数据
--------------------------------------
local function get_file_process(filename,index)
    local f = assert(io.open(filename), "file is not find.file filename:"..filename)
    local t = {}
    local keys = nil 
    local key_value_type = nil 
    local line_count = 0 

    -- 数据索引
    local idx = nil 
    if index and index ~= '' then         
        idx = string.lower(index)
    end
    for line in f:lines() do
        line = string.gsub(line,"\r","")
        line_count = line_count + 1
        -- 字段名
        if line_count == 1 then 
            line = string.lower(line)
            keys = SplitStr(line,",")
        end
        -- 注释
        if line_count == 2 then 
            -- comment
            -- print(line)
        end
        -- 字段类型
        if line_count == 3 then 
            line = string.lower(line)
            key_value_type = SplitStr(line,",")
        end
        local valid = true 
        if line =='' or string.sub(line,1,1) == '#' then
            valid = false
            --print("#comment ",filename,line)
        end
        if line_count > 3 and valid then 
            local tmp = {}
            local values = SplitStr(line,",")
                local count = 0 
                for i,v in ipairs(values) do
                    count = i 
                    local key = keys[i]
                    local v_type = key_value_type[i]
                    if key and v_type then 
                        if v_type == 'number' then 
                            local num = tonumber(v)
                            if not num then 
                                print("number value err",filename,line_count,i)
                            end 
                            --无效值设定为-1
                            tmp[key] = num or -1
                        elseif v_type == 'string' then 
                            tmp[key] = v
                        elseif v_type == 'bool' then 
                            tmp[key] = (v == "TRUE")
                        end
                    end
                end
                -- assert(count > 1,"filename:"..filename.."Eror "..line)
                if not (count > 1) then
                    print("filename",filename," Eror ",line)
                end
                for i=count + 1,#keys do
                    local key = keys[i]
                    local v_type = key_value_type[i]
                    if key and v_type then 
                        if v_type == 'number' then 
                            tmp[key] = 0
                        elseif v_type == 'string' then 
                            tmp[key] = ''
                        elseif v_type == 'bool' then 
                            tmp[key] = false
                        end
                    end
                end
                -- 数据是有下标索引
                if idx and tmp[idx] then
                    t[tmp[idx]] = tmp
                else
                    table.insert(t,tmp)
                end
            -- else
            --     print(#values,#keys)
            --     print("conf value err",filename,line)
            -- end
        end
        
    end
    f:close() 
    return t
end

local function check_valid( data )
    if type(data) == "nil" then
        return false
    end

    if type(data) == "number" then
        return number ~= -1
    elseif type(data) == "string" then
        return number ~="-1"
    else
        return true
    end
end


local function class_level_info_process( data )
    local tmp_data = {}
    for k,v in ipairs(data) do
        local id = v.id 
        local tmp = tmp_data[id] or {}
        table.insert(tmp,v)
        tmp_data[id] = tmp
    end 
    return tmp_data
end

--设置一下开服时间
local function server_list_process( data )
    for k,v in ipairs(data) do
        if check_valid(v.open_time) then
            --strToTime在time.mgr中定义
            v.open_time = strToTime(v.open_time)
            assert(v.open_time)
        else
            v.open_time = 0
        end
    end
    return data
end

--设置一下公告时间
local function broad_process( data )
    for k,v in ipairs(data) do
        if check_valid(v.begin_time) then
            --strToTime在time.mgr中定义
            if v.begin_time == "0" then
                v.begin_time = 0
            else
            v.begin_time = strToTime(v.begin_time)
            assert(v.begin_time)
            end
        else
            v.begin_time = 0
        end
        if check_valid(v.end_time) then
            --strToTime在time.mgr中定义
            if v.end_time == "0" then
                v.end_time = 0
            else
            v.end_time = strToTime(v.end_time)
            assert(v.end_time)
            end
        else
            v.end_time = 0
        end
    end
    return data
end


local function item_process( data )
    for k,v in pairs(data) do
        local reward = v.reward
        local reward_list = {}
        local cost_list = {}
        local _reward = SplitStr(reward,"|")
        for m,n in ipairs(_reward) do
            if n ~= '' then 
                local _t = SplitStr(n,"_")
                local id = tonumber(_t[1])
                local num = tonumber(_t[2])
                local lv = tonumber(_t[3]) or -1
                table.insert(reward_list,{id=id,num=num,lv=lv}) 
            end
        end
        v.reward_list = reward_list


        local cost = v.cost
        local cost_list = {}
        local _cost = SplitStr(cost,"|")
        for m,n in ipairs(_cost) do
            if n ~= '' then 
                local _t = SplitStr(n,"_")
                local id = _t[1]
                local num = _t[2]
                local t = {
                    id = tonumber(id),
                    num = tonumber(num)
                }
                table.insert(cost_list,t) 
            end
        end
        v.cost_list = cost_list
    end
    return data
end

function scene_chapter_process( data )
    --转换成以场景id为key的table
    local new_conf_set = {}
    for k,v in pairs(data) do
        --处理进入次数
        if v.ask_count and v.ask_count ~= "-1" then
            local str = v.ask_count
            local list = {}
            local tmp = SplitStr(str,";")
            for m,n in ipairs(tmp) do
                local num = tonumber(n)
                table.insert( list,num)
            end
            v.ask_count_list = list
        end

        --任务列表
        local quest_list = {}
        if check_valid(v.quest_id) then
            local tmp = SplitStr(v.quest_id,";")
            for k,v in ipairs(tmp) do
                table.insert(quest_list,tonumber(v))
            end
        end
        v.quest_list = quest_list

        if not new_conf_set[v.scene_id] then 
            new_conf_set[v.scene_id] = {}
        end

        if not new_conf_set[v.scene_id][v.level] then
            new_conf_set[v.scene_id][v.level] = {}
        end
        new_conf_set[v.scene_id][v.level] = v
    end

    return new_conf_set     
end

--处理一下奖励表
function scene_reward_process( data )
    for k,v in pairs(data) do
        v.reward = {}
        if v.player_exp and v.player_exp > 0 then
            local tmp = {}
            tmp.id = 50000001
            tmp.num = v.player_exp
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end
        if v.energy and v.energy > 0 then
            local tmp = {}
            tmp.id = 50000002
            tmp.num = v.energy
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end  
        if v.hp and v.hp > 0 then
            local tmp = {}
            tmp.id = 50000003
            tmp.num = v.hp
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end

        if v.sp and v.sp > 0 then
            local tmp = {}
            tmp.id = 50000004
            tmp.num = v.sp
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end

        if v.money and v.money > 0 then
            local tmp = {}
            tmp.id = 50000005
            tmp.num = v.money
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end

        if v.rmb and v.rmb > 0 then
            local tmp = {}
            tmp.id = 50000006
            tmp.num = v.rmb
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end

        if v.hero_exp and v.hero_exp > 0 then
            local tmp = {}
            tmp.id = 50000007
            tmp.num = v.hero_exp
            tmp.rate = 10000
            table.insert(v.reward,tmp)
        end

        for i=1,10 do
            local tmp = {}
            tmp.id = v["item"..i]
            tmp.num = v["count"..i]
            tmp.rate = v["rate"..i]
            table.insert(v.reward,tmp)
        end
    end
    return data
end

--关卡怪物表处理
function scene_monster_process( data )
    for k,v in pairs(data) do
        v.spawn_mons = {}
        local mons = SplitStr(v.spawn_monster_ids,";")  
        for m,n in pairs(mons) do
            table.insert(v.spawn_mons,tonumber(n))
        end
    end
    return data
end

--关卡事件处理
function scene_events_process( data )
    for k,v in pairs(data) do
        local eparam_list = {}
        local eparams = v.eparams
        if eparams then 
            local list_str = SplitStr(eparams,";")
            for m,n in ipairs(list_str) do
                if n ~= '' then
                    local param = {}
                    for i,j in string.gmatch(n, "%d+") do
                        table.insert(param,j)
                    end
                    if #param > 0 then
                        table.insert(eparam_list,param)
                    end
                end
            end
        end
        v.eparam_list = eparam_list
    end

    return data
end

--关卡初始化表
function scene_init_process( data )
    for k,v in pairs(data) do
        --复活费用
        local relive_money_list = {}
        if check_valid(v.relive_money) then
            local tmp = SplitStr(v.relive_money,";")
            for m,n in ipairs(tmp) do
                table.insert( relive_money_list,tonumber(n) )
            end
        end
        v.relive_money_list = relive_money_list
    end
    --print_r(data)
    return data
end


--刷怪表处理
function spawn_monster_proccess( data )
    for k,v in pairs(data) do
        v.monster_list = {}
        for i=1,4 do
            local id = tonumber(v["monster_id"..i])
            local num = tonumber(v["number"..i])
            table.insert(v.monster_list,{id=id,num=num})
        end
    end

    return data
end



--------------------------------------
---------------- 主角初始信息处理
--------------------------------------

function class_config_process( data )
    for k,v in pairs(data) do
        -- 初始化装备
        local init_equip = v.init_equip
        local init_equip_list = {}
        if init_equip then 
            local list_str = SplitStr(init_equip,"|")
            for m,n in ipairs(list_str) do
                if n ~= '' then 
                    local _t = SplitStr(n,"_")
                    local id = tonumber(_t[1])
                    local num = tonumber(_t[2])
                    local lv = tonumber(_t[3]) or -1                

                    table.insert(init_equip_list,{id=id,num=num,lv=lv}) 
                end
            end
        end
        v.init_equip_list = init_equip_list

        -- 初始化道具
        local init_item = v.init_item
        local init_item_list = {}
        if init_item then 
            local list_str = SplitStr(init_item,"|")
            for m,n in ipairs(list_str) do
                if n ~= '' then 
                    local _t = SplitStr(n,"_")
                    local id = tonumber(_t[1])
                    local num = tonumber(_t[2])                

                    table.insert(init_item_list,{id=id,num=num}) 
                end
            end
        end
        v.init_item_list = init_item_list

        --初始化宝石
        local init_gem = v.init_gem
        local init_gem_list = {}
        if init_gem then 
            local list_str = SplitStr(init_gem,"|")
            for m,n in ipairs(list_str) do
                if n ~= '' then 
                    local _t = SplitStr(n,"_")
                    local id = tonumber(_t[1])
                    local num = tonumber(_t[2])
                    local lv = tonumber(_t[3]) or -1                

                    table.insert(init_gem_list,{id=id,num=num,lv=lv}) 
                end
            end
        end
        v.init_gem_list = init_gem_list


        -- 初始化武将
        local hero_id = v.hero_id 
        local init_heros = {}
        if hero_id and hero_id ~="" then 
            local ids = SplitStr(hero_id,"|")
            for k,v in ipairs(ids) do
                local tmp = {}
                local data = SplitStr(v,"_")
                -- id,是否上阵
                tmp.id = tonumber(data[1])
                tmp.lv = tonumber(data[2]) or 1
                tmp.on = tonumber(data[3])==1
                table.insert(init_heros,tmp)
            end                   
        end 
        v.init_heros = init_heros 

        --初始化技能
        local init_skills = {}
        --下标从0到11,前4个是普攻
        for i=4,11 do
            local tmp = {}
            local id = tonumber(v["skill"..i])
            if id and id ~= -1 then
                table.insert(init_skills,id)
            end
        end
        v.init_skills = init_skills
    end
    return data
end
--------------------------------------
---------------- @模块：心法模块
--------------------------------------

local function citta_level_info_process( data )
    local tmp_data = {}
    for k,v in ipairs(data) do
        local id = v.id 
        local tmp = tmp_data[id] or {}
        table.insert(tmp,v)
        tmp_data[id] = tmp
    end 
    return tmp_data
end

--------------------------------------
---------------- @模块：技能模块
--------------------------------------
local function skill_process( data)
    for k,v in pairs(data) do
        --初始化各等级数据id
        local skill_data = v.skill_datas
        local skill_data_list = {}
        if skill_data then
            local list_str = SplitStr(skill_data,";")
             for m,n in ipairs(list_str) do
                if n then 
                    table.insert(skill_data_list,tonumber(n)) 
                end
            end
        end
        v.skill_data_list = skill_data_list

        -- 初始化解锁消耗
        local unlock_cost = v.unlock_cost
        local unlock_cost_list = {}
        if unlock_cost then 
            local list_str = SplitStr(unlock_cost,"|")
            for m,n in ipairs(list_str) do
                if n ~= '' then 
                    local _t = SplitStr(n,"_")
                    local id = _t[1]
                    local num = _t[2]                   
                    local t = {
                        id = tonumber(id),
                        num = tonumber(num)
                    }
                    table.insert(unlock_cost_list,t) 
                end
            end
        end  
        v.unlock_cost_list = unlock_cost_list
    end

    return data
end

function skilldata_common_process( data )
    for k,v in pairs(data) do
         --初始化升级消耗
        local level_up_cost = v.level_up_cost
        local level_up_cost_list = {}
        if level_up_cost then 
            local list_str = SplitStr(level_up_cost,"|")
            for m,n in ipairs(list_str) do
                if n ~= '' then 
                    local _t = SplitStr(n,"_")
                    local id = _t[1]
                    local num = _t[2]                   
                    local t = {
                        id = tonumber(id),
                        num = tonumber(num)
                    }
                    table.insert(level_up_cost_list,t) 
                end
            end
        end  
        v.level_up_cost_list = level_up_cost_list
    end
    return data
end

--------------------------------------
---------------- @模块：心法配方
--------------------------------------

local function citta_make_process( data )
    for k,v in pairs(data) do
        local total_prop = 0
        local output_str = v.output
        local output = {}
        local tmp = SplitStr(output_str,"|")
        for m,n in ipairs(tmp) do
            local tmp2 = SplitStr(n,"_")
            -- id 等级 概率
            local id = tonumber(tmp2[1])
            local lv = tonumber(tmp2[2])
            local prop = tonumber(tmp2[3])
            total_prop = total_prop + prop
            table.insert(output,{id=id,lv=lv,prop=prop})
        end
        v.total_prop = total_prop
        v.output = output
    end  
    return data   
end

--------------------------------------
---------------- @模块：副将
--------------------------------------
local function hero_process( data )
    local aptitude = {"caption", "force","intlg",}

    local prop_list = {"atk_grow","def_grow","hp_grow"}
    local max_grow_list = {"max_atk_grow","max_def_grow","max_hp_grow"}
    for k,v in pairs(data) do
        local skill_list = {}
        --hero表skill下标从0到11，前4个是普攻的4段攻击
        for i=4,11 do
            local id = tonumber(v["skill"..i])
            if id and id ~= -1 then
                table.insert(skill_list,id)
            end
        end
        v.skill_list = skill_list


        --升阶等级
        local up_grade_lv_list = {}
        if check_valid(v.up_grade_lv) then
            local tmp = SplitStr(v.up_grade_lv,"_")
            for m,n in ipairs(tmp) do
                local lv = tonumber(n)
                table.insert( up_grade_lv_list,lv )
            end
        end
        v.up_grade_lv_list = up_grade_lv_list

        --升阶消耗
        local up_grade_cost_list = {}
        if check_valid(v.up_grade_cost) then
            local tmp = SplitStr(v.up_grade_cost,";")
            for m,n in ipairs(tmp) do
                local tmp2 = SplitStr(n,"|")
                local list = {}
                for i,j in ipairs(tmp2) do
                    local tmp3 = SplitStr(j,"_")
                    local id = tonumber(tmp3[1])
                    local num = tonumber(tmp3[2])
                    table.insert( list,{id=id,num=num} )
                end
                table.insert( up_grade_cost_list,list )
            end
        end
        v.up_grade_cost_list = up_grade_cost_list
     
        -- 分解所得
        local bu = v.break_up
        local break_up = {}
        tmp = SplitStr(bu,"|")
        for k,v in ipairs(tmp) do
            for id,num in string.gmatch(v,"(%d+)_(%d+)") do
                -- id 数量
                local id_int = tonumber(id)
                local num_int = tonumber(num)
                table.insert(break_up,{stuff_id=id_int,num = num_int })
            end
        end
        v.break_up = break_up

        --初始成长
        for _,prop in ipairs(prop_list) do
            local t = {}
            local weight = 0 
            local list = SplitStr(v[prop],"|")
            for k,v in ipairs(list )do
                local _t = SplitStr(v,"_")
                -- 成长 起 终 概率 
                local from = tonumber(_t[1])
                local to = tonumber(_t[2])
                local prob = tonumber(_t[3])
                weight = weight + prob
                table.insert(t,{from=from,to=to,prob=prob})
            end
            t.weight = weight
            v[prop] = t
        end

        --最大成长
        for _,max_grow in ipairs(max_grow_list) do
            local tmp = SplitStr(v[max_grow],"_")
            local list = {}
            local index = 0
            for m,n in ipairs(tmp) do
                list[index] = tonumber(n)
                index  = index + 1
            end
            v[max_grow.."_list"] = list
        end
        

        -- 阶级数据
        local grade_data_list = {}
        local index = 0
        while v["grade_data"..index] do
            local grade_data = v["grade_data"..index]
            --洗练系数_攻击_防御_生命_暴击_暴击抵抗_刀盾伤害_枪骑伤害_锤车伤害_弓弩伤害_策士伤害_
            --刀盾格挡_枪骑格挡_锤车格挡_箭弩格挡_策士格挡
            local tmp = SplitStr(grade_data,"_")
            local list = {
                refine_fac = tonumber(tmp[1]),
                attack = tonumber(tmp[2]),
                defense = tonumber(tmp[3]),
                max_hp = tonumber(tmp[4]),
                critical = tonumber(tmp[5]),
                critical_defense = tonumber(tmp[6]),

                daodun_dam = tonumber(tmp[7]),
                qiangqi_dam = tonumber(tmp[8]),
                chuiche_dam = tonumber(tmp[9]),
                gongnu_dam = tonumber(tmp[10]),
                ceshi_dam = tonumber(tmp[11]),

                daodun_blk = tonumber(tmp[12]),
                qiangqi_blk = tonumber(tmp[13]),
                chuiche_blk = tonumber(tmp[14]),
                gongnu_blk = tonumber(tmp[15]),
                ceshi_blk = tonumber(tmp[16]),
            }
            --注意，用0当key,就没法遍历到它了，这个字段应该不用遍历
            grade_data_list[index] = list
            index = index + 1
        end
        v.grade_data_list = grade_data_list
    end

    --print_r(data)
    return data
end


local function hero_level_info_process( data )
    local tmp_data = {}
    for k,v in pairs(data) do
        local id = v.id 
        local tmp = tmp_data[id] or {}
        table.insert(tmp,v)
        tmp_data[id] = tmp
    end 
    return tmp_data
end

--天赋表
local  function talent_process( data )
    for k,v in pairs(data) do
        local level_up_cost = v.level_up_cost
        local level_up_cost_list = {}
        if check_valid(level_up_cost) then
            local tmp = SplitStr(level_up_cost,";")
            for m,n in ipairs(tmp) do
                local tmp2 = SplitStr(n,"_")
                local id = tonumber(tmp2[1])
                local num = tonumber(tmp2[2])
                table.insert(level_up_cost_list,{id=id,num=num})
            end
        end
        v.level_up_cost_list = level_up_cost_list   
    end

    return data
end

-- 关卡 章节奖励
local function section_reward_process( data )
    for k,v in pairs(data) do
        --需要星数
        local need_star_list = {}
        if check_valid(v.need_star) then
            local tmp = SplitStr(v.need_star,"_")
            for k,v in ipairs(tmp) do
                table.insert( need_star_list,tonumber(v) )
            end
        end
        v.need_star_list = need_star_list

        --奖励
        local reward_list = {}
        if check_valid(v.reward) then
            local tmp = SplitStr(v.reward,";")
            for _,reward in ipairs(tmp) do
                local tmp2 = SplitStr(reward,"|")
                local  list = {}
                for _,stuff in ipairs(tmp2) do
                    local tmp3 = SplitStr(stuff,"_")
                    local id = tonumber(tmp3[1])
                    local num = tonumber(tmp3[2])
                    local lv = tonumber(tmp3[3]) or -1
                    table.insert(list,{id=id,num=num,lv=lv})
                end   
                table.insert( reward_list,list )        
            end
        end
        v.reward_list = reward_list   
    end
    --print_r(data)
    return data
end

local function sign_reward_process( data )
    for k,v in pairs(data) do
        local reward_str = v.reward
        local reward_list = {}
        local tmp = SplitStr(reward_str,"|")
        for m,n in ipairs(tmp) do
            local tmp2 = SplitStr(n,"_")
            local id = tonumber(tmp2[1])
            local num = tonumber(tmp2[2])
            local lv = tonumber(tmp2[3]) or -1
            table.insert(reward_list,{id=id,num=num,lv=lv})
        end
        v.reward_list = reward_list   
    end
    return data
end

local function sign_continual_reward_process( data )
    for k,v in pairs(data) do
        local reward_str = v.reward
        local reward_list = {}
        local tmp = SplitStr(reward_str,"|")
        for m,n in ipairs(tmp) do
            local tmp2 = SplitStr(n,"_")
            local id = tonumber(tmp2[1])
            local num = tonumber(tmp2[2])
            local lv = tonumber(tmp2[3]) or -1
            table.insert(reward_list,{id=id,num=num,lv=lv})
        end
        v.reward_list = reward_list   
    end
    return data
end

local function sign_like_reward_process( data )
    for k,v in pairs(data) do
        local reward_str = v.reward
        local reward_list = {}
        local tmp = SplitStr(reward_str,"|")
        for m,n in ipairs(tmp) do
            local tmp2 = SplitStr(n,"_")
            local id = tonumber(tmp2[1])
            local num = tonumber(tmp2[2])
            local lv = tonumber(tmp2[3]) or -1
            table.insert(reward_list,{id=id,num=num,lv=lv})
        end
        v.reward_list = reward_list   
    end
    return data
end

local function shop_item_process( data )
    for k,v in pairs(data) do
        --处理折扣时间
        if v.is_discount then
            v.discount_begin_time = strToTime(v.discount_begin_time)
            assert(v.discount_begin_time)
            --配置时以小时为单位
            v.discount_duration_time = 3600 * v.discount_duration_time
        end
    end
    return data
end

local function shop_treasure_porcess( data )
    for k,v in pairs(data) do
        --处理折扣时间
        if v.is_discount then
            v.discount_begin_time = strToTime(v.discount_begin_time)
            assert(v.discount_begin_time)
            --配置时以小时为单位
            v.discount_duration_time = 3600 * v.discount_duration_time
        end 
    end
    return data
end

local function equipment_process( data )
    for k,v in pairs(data) do
        --基础属性
        local prop_value_list = {}
        for i=0,3 do
            prop_value_list[i+1] = v["prop_value"..i] or 0
        end
        v.prop_value_list = prop_value_list

        --默认附加属性
        local default_prop_list = {}
        if v.default_prop then
            local tmp = SplitStr(v.default_prop,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local id = tonumber(t[1])
                local value = tonumber(t[2])
                local num_type = tonumber(t[3])
                table.insert(default_prop_list,{id=id,value=value,num_type=num_type})
            end
        end
        v.default_prop_list = default_prop_list

        --神化需要等级
        local deify_lv_list = {}
        for i=1,3 do
            table.insert(deify_lv_list,v["deify_lv"..i])
        end
        v.deify_lv_list = deify_lv_list

        --神化需要金币
        local deify_cost_list = {}
        for i=1,3 do
            table.insert(deify_cost_list,v["deify_lv"..i])
        end
        v.deify_cost_list = deify_cost_list

        --洗练恢复价格
        local recover_cost_list = {}
        if v.recover_cost then
            local tmp = SplitStr(v.recover_cost,"_")
            for m,n in pairs(tmp) do
                table.insert( recover_cost_list,tonumber(n))
            end
        end
        v.recover_cost_list = recover_cost_list

        --分解产物
        local product_list = {}
        local tmp = SplitStr(v.product,";")
        for m,n in ipairs(tmp) do
            local t = SplitStr(n,"_")
            local id = tonumber(t[1])
            local num = tonumber(t[2])
            table.insert(product_list,{id=id,num=num})
        end
        v.product_list = product_list
    end
    
    return data
end

local function equipment_prop_porcess( data )
    local keys = {"quality_1","quality_2","quality_3"}
    local tmp = {}
    for k,v in ipairs(data) do
        local eq_type = v.eq_type
        local t = tmp[eq_type] or {}        
        for m,n in ipairs(keys) do
            local quality_str = v[n]
            local qua = SplitStr(quality_str,"_")
            --随机范围
            local from = tonumber(qua[1])
            local to = tonumber(qua[2])
            v[n] = {from=from,to=to}   
            --print(v[n],type(v[n]))       
        end
        table.insert( t,v )
        tmp[eq_type] = t
    end
    return tmp
end

local function equip_level_up_process( data )
    local ret = {}
    for k,v in pairs(data) do
        local equip_id = v.equip_id
        local t = ret[equip_id] or {}

        local level = v.level
        t[level] = {cost = v.cost,add_value = v.add_value}

        ret[equip_id] = t
    end

    return ret
end

local function recipe_process( data )
    for k,v in pairs(data) do
        local material_list = {}
        local tmp = SplitStr(v.material,";")
        for m,n in ipairs(tmp) do
            local t = SplitStr(n,"_")
            local id = tonumber(t[1])
            local num = tonumber(t[2])
            table.insert(material_list,{id=id,num=num})
        end
        --为方便客户端使用，把消耗银币单独作为cost字段
        if check_valid(v.cost) then
            table.insert( material_list, {id=MONEY_ID,num=v.cost} )
        end
        v.material_list = material_list  

        local product_list = {}
        tmp = SplitStr(v.product,"_")
        for m,n in ipairs(tmp) do
            local id = tonumber(n)
            table.insert(product_list,id)
        end
        v.product_list = product_list
    end

    return data
end


local function gem_process( data )
    for k,v in pairs(data) do
        --需求经验
        local need_exp_list = {}
        if v.need_exp then
            local tmp = SplitStr(v.need_exp,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local level = tonumber(t[1])
                local exp = tonumber(t[2])
                need_exp_list[level] = exp > 0 and exp or 0
            end
            --确保这个table不离散
            for i=1,10 do
                if not need_exp_list[i] then
                    need_exp_list[i] = 0
                end
            end
        end
        v.need_exp_list = need_exp_list
        

        --提供经验
        local give_exp_list = {}
        if v.give_exp then
            local tmp = SplitStr(v.give_exp,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local level = tonumber(t[1])
                local exp = tonumber(t[2])
                give_exp_list[level] = exp > 0 and exp or 0
            end
            --确保这个table不离散
            for i=1,10 do
                if not give_exp_list[i] then
                    give_exp_list[i] = 0
                end
            end
        end
        v.give_exp_list = give_exp_list

        --生成概率
        local prob_list = {}
        if v.prob then
            local tmp = SplitStr(v.prob,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local level = tonumber(t[1])
                local prob = tonumber(t[2])
                prob_list[level] = prob > 0 and prob or 0
            end
            --确保这个table不离散
            for i=1,10 do
                if not prob_list[i] then
                    prob_list[i] = 0
                end
            end
        end
        v.prob_list = prob_list
    end

    return data
end


----------------急行战----------------
local function rush_bot_process( data )
    for k,v in pairs(data) do
       --武将列表
        local hero_list = {}
        if check_valid(v.hero) then
            local tmp = SplitStr(v.hero,"_")
            for m,n in ipairs(tmp) do
                table.insert( hero_list,tonumber(n))
            end
        end
        v.hero_list = hero_list

        --怪物列表
        local mon_list = {}
        if check_valid(v.mon) then
            local tmp = SplitStr(v.mon,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local time = tonumber(t[1])
                local id = tonumber(t[2])
                mon_list[time] = id
            end
        end
        v.mon_list = mon_list

         --位置列表
        local position_list = {}
        if check_valid(v.position) then
            local tmp = SplitStr(v.position,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local time = tonumber(t[1])
                local position = tonumber(t[2])
                position_list[time] = position
            end
        end
        v.position_list = position_list

         --boss血量列表
        local boss_hp_list = {}
        if check_valid(v.boss_hp) then
            local tmp = SplitStr(v.boss_hp,";")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local time = tonumber(t[1])
                local boss_hp = tonumber(t[2])
                boss_hp_list[time] = boss_hp
            end
        end
        v.boss_hp_list = boss_hp_list
    end
    
    return data
end

local function rush_rank_like_reward_process( data )
    for k,v in pairs(data) do
        local reward_str = v.reward
        local reward_list = {}
        local tmp = SplitStr(reward_str,"|")
        for m,n in ipairs(tmp) do
            local tmp2 = SplitStr(n,"_")
            local id = tonumber(tmp2[1])
            local num = tonumber(tmp2[2])
            local lv = tonumber(tmp2[3]) or -1
            table.insert(reward_list,{id=id,num=num,lv=lv})
        end
        v.reward_list = reward_list   
    end
    return data
end


local function active_process( data )
    for k,v in pairs(data) do
        local map_id_list = {}
        if check_valid(v.chapter) then
            local tmp = SplitStr(v.chapter,"|")
            for m,n in ipairs(tmp) do
                local t = SplitStr(n,"_")
                local id = tonumber(t[1])
                local diff = tonumber(t[2])
                table.insert(map_id_list,{id=id,diff=diff})
            end
        end
        v.map_id_list = map_id_list
    end

    return data
end

--------------------------------------
---------------- @模块：main
--------------------------------------

local settings_data = {}

-- settings 路径 
local settings_file_path = "game/setting/"
-- settings 文件
local settings_file_name = "settings.csv"

local process_list = {
    class_config = class_config_process,
    class_level_info = class_level_info_process,
    server_list = server_list_process,
    broad = broad_process,
    item = item_process,
    scene_chapter = scene_chapter_process,
    scene_reward = scene_reward_process,
    scene_monster = scene_monster_process,
    scene_events = scene_events_process,
    spawn_monster = spawn_monster_proccess,
    scene_init = scene_init_process,
    citta_level_info = citta_level_info_process,
    citta_make = citta_make_process,
    skill = skill_process,
    skilldata_common = skilldata_common_process,
    hero = hero_process,
    hero_level_info = hero_level_info_process,
    talent = talent_process,
    section_reward = section_reward_process,
    sign_reward = sign_reward_process,
    sign_continual_reward = sign_continual_reward_process,
    sign_like_reward = sign_like_reward_process,
    shop_item = shop_item_process,
    shop_treasure = shop_treasure_porcess,
    equipment = equipment_process,
    equipment_prop = equipment_prop_porcess,
    equip_level_up = equip_level_up_process,
    recipe = recipe_process,
    gem = gem_process,
    rush_bot = rush_bot_process,
    rush_rank_like_reward = rush_rank_like_reward_process,
    active = active_process,
}

local function set_data(key_name,data)
    local process = process_list[key_name]
    if process then 
        print("  处理",key_name.." data")
        data = process(data)
    end
    print("已加载数据",key_name)
    settings_data[key_name] = data
end


local function process_settins_file()
    -- 先读取settings.csv 里的配置
    -- 再根据其内容确定每个文件对应数据的内容
    local f = get_file_process(settings_file_path..settings_file_name)
    -- key_name -- 全局索引键值 
    -- idx_name -- 数据表中的主键 可空且为数组
    -- csv_name -- csv 文件名
    for k,v in ipairs(f) do
        local csv_name = v.csv_name
        local idx_name = v.idx_name
        local key_name = v.key_name        
        local file_name = settings_file_path..csv_name
        local data = get_file_process(file_name,idx_name) 
        set_data(key_name,data)
        -- settings_data[key_name] = data
    end
end


function CMD.new()
    process_settins_file()
    sharedata.new ("settings_data", settings_data)
end

function CMD.update()
    process_settins_file()
    sharedata.update("settings_data", settings_data)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)  
end)


