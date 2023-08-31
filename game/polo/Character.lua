--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-20 13:53:54
-- @Description: 角色相关
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local dbpacker = require "db.packer"
local print_r = require "common.print_r"
local log = require "log"
local get_intl_str = require "common.intl_str"

require "polo.StuffFactory"
require "polo.Hero"
require "polo.Map"
require "polo.Skill"
require "polo.Talent"
require "polo.Mail"


local database = ".database"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


-- 获取玩家身上的存放点
-- char={
--     package={
--         item={},
--         equipment={},
--         gem={},
--         citta={}
--     },
--     debris={
--         equipment={},
--         gem={},
--         citta={}
--     }
-- }

Character={
    
}

function Character:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

--记录角色信息被更新
function Character:mark_updated()
    self.info_updated = true
end

--存储角色信息

function Character:save()
    if self.info_updated then 
        -- 序列化存储
        log.debug("保存角色数据 id:",self.id)
        self.info_updated = false
        skynet.call(database,"lua","character","save_char",self.id,self)        
    end
end

-- 角色描述
function Character:get_desc()
    return {
        id = self.id,
        nickname = self.nickname,
        lv = self.lv,
        class_id = self.class_id
    }
end

-- 从数据库取出数据后，反序列化，对象化
function Character:loadData2Object()

    -- 背包数据对象化
    local package = self.package or {}
    for k,v in pairs(package) do
        local _v = {}
        for m,n in ipairs(v) do
            local stuff = StuffFactory.new_stuff_by_data(n)
            table.insert(_v,stuff)
        end
        package[k] = _v
    end
    self.package = package

    -- 副将
    local hero_list = self.hero_list or {}
    for k,v in pairs(hero_list) do
        local hero = Hero:new(v)
        hero:init_data()
        hero_list[k] = hero        
    end
    self.hero_list = hero_list

    --技能
    local skill_list = self.skill_list or {}
    for k,v in pairs(skill_list) do
        local skill = Skill:new(v)
        skill_list[k] = skill
    end
    self.skill_list = skill_list

    --地图
    --[[table里的key如果是离散的，经过dkjson编码解码后，
    number型的key会变成string型，所以处理一下key]]
    local map = self.map or {}
    local new_map = {}
    for k,v in pairs(map) do
        local k_num = tonumber(k)
        if k_num then    
            new_map[k_num] = v
        else
            new_map[k] = v
        end
    end
    self.map = new_map

    --天赋
    local talent_list = self.talent_list or {}
    for k,v in pairs(talent_list) do
        local talent = Talent:new(v)
        talent_list[k] = talent
    end
    self.talent_list = talent_list

    --邮件
    local mail_list = self.mail_list or {}
    for k,v in pairs(mail_list) do
        local mail = Mail:new(v)
        mail_list[k] = mail
    end
    self.mail_list = mail_list
end


-- 加载某个角色
function Character.load_char(char_id)    
    local char_data = skynet.call(database,"lua","character","load_char",char_id)
    local char = Character:new(char_data)
    char:loadData2Object()
    return char 
end


local class_need_key = {
    "money",
    "rmb",
}
local level_need_key = {
    "max_hp",
    "max_sp",
    "attack",
    "defense",
    "critical",
    "critical_defense",
    "move_speed",
    "move_back_speed",
    "move_back_duration",
    "attack_rate",
    "hp_recovery",
    "sp_recovery",
}

-- 创建新角色
function Character.create_new_char(class_id,nickname)
    local get_max_char_id = skynet.call(database,"lua","character","get_max_char_id")
    local class_config = gdd.class_config
    local class_data = class_config[class_id]
    assert(class_data,"class_data is not find,class_id:"..class_id)
    local now_time = os.time()

    local char = Character:new{} --deep_copy(class_data)

    --初始化角色属性
    for k,v in pairs(class_need_key) do
        char[v] = class_data[v]
    end

    local lv = 1

    local class_level_info = gdd.class_level_info
    local level_info = class_level_info[class_id]
    local level_data= level_info[lv]

    --初始化战斗属性
    char.fight_attr = {}
    for k,v in pairs(level_need_key) do
        char.fight_attr[v] = level_data[v]
    end
    --这个属性在class表里-。-
    char.fight_attr.max_energy = class_data.max_energy
    char.fight_attr.energy = 50 --char.fight_attr.max_energy

    char.id = get_max_char_id
    char.nickname = nickname
    char.class_id = class_id
    
    char.exp = 0 
    char.vip = 0
    char.lv = lv
    char.create_time = now_time
    char.depart_time = 0

    char.map = {}
    char.map.cur_map = {map_id = 0,diff = 0}
    char.skill_list = {}
    char.mail_list = {}
    char.sign_record = {}
    char.goods_record = {}
    char.rush_record = {}

    --测试用
    char.rmb=10000

    -- 装备初始化装备
    local init_equip_list = class_data.init_equip_list or {}
    for k,v in pairs(init_equip_list) do
        local id = v.id
        local num = v.num 
        local stuff_type = StuffFactory.get_stuff_type(id)        
        local list = char:add_equipment(id,num,true)
        -- 初始化装备都穿上
        for m,n in ipairs(list) do
            n:put_on()
        end
    end

    --增加初始化宝石
    local init_gem_list = class_data.init_gem_list
    if init_gem_list then
        for k,v in pairs(init_gem_list) do
            char:add_gem(v.id,v.num,v.lv)
        end
    end


    -- 增加初始化道具
    local init_item_list = class_data.init_item_list or {}

    for k,v in pairs(init_item_list) do
        local id = v.id
        local num = v.num 
        char:add_stuff(id,num)        
    end


    -- 初始化武将
    local hero_conf_set = gdd.hero
    local init_heros = class_data.init_heros or {}
    char.hero_list = {}
    for k,v in pairs(init_heros) do
        if hero_conf_set[v.id] then
            local id = v.id
            local lv = v.lv or 1
            local exp = 0 
            local to_fight = v.to_fight
            char:add_hero(id,lv,exp,to_fight)
        end
    end

    --初始化技能
    local init_skills = class_data.init_skills or {}
    local skill_list = {}
    skill_conf = gdd.skill
    local level = 1
    for i,v in ipairs(init_skills) do
        if skill_conf[v] then
            --初始技能第一个是已解锁状态
            --local skill = Skill:new{id=v,level=level,is_using=false,index=0}
            --测试用，初始为解锁状态
            local skill = Skill:new{id=v,level=1,is_using=false,index=0}
            if i<=2 then
                skill.index = i
                skill.is_using = true
            end
            table.insert(skill_list,skill)
            level = 0
        end
    end
    char.skill_list = skill_list

    --初始化天赋
    local talent_list = {}
    local talent_conf_set = gdd.talent
    for k,v in pairs(talent_conf_set) do
        if not talent_list[v.type] then
            local is_open = (v.need_level <= char.lv) and true or false
            talent_list[v.type] = Talent:new{type=v.type,level=0,is_open=is_open}
        end
    end

    char.talent_list = talent_list

    char.fight = char:cal_char_fight()

    char:mark_updated()
    return char
end

function Character:get_power()
    --返回人物的战力，todo
    return self.fight
end


-- 构造出应答
function Character:get_ret_short(msg)
    local ret = {
        status=1,
        msg=msg,
    }
    return ret
end

--构造出应答
function Character:get_succ_ret( prop )
     local ret = {
        status=1,
    }
    if prop then
        for k,v in pairs(prop) do
            ret[k] = v
        end
    end
    return ret
end

-- 构造出应答
function Character:get_ret(prop,msg)
    local ret = {
        status=1,
        msg=msg,
    }
    if prop then
        for k,v in pairs(prop) do
            ret[v] = self[v]
        end
    end
    return ret
end

function Character:get_error_ret(error_msg)
    local ret = {
        status=0,
        msg=error_msg,
    }
    return ret
end

function Character:get_equip_attr( uuid )
    local equip = self:get_stuff_by_uuid("equipment",uuid)
    if not equip then 
        return nil
    end

    local attr = {}
    local data = Equipment.get_data(equip.id)
    --主属性
    local attr_type = {
    [1] = "attack",
    [2] = "defense",
    [2] = "max_hp",
    }
    local attr_num = data.prop_value_list[(equip.deify_lv or 0) + 1]
    local main_prop = attr_type[data.main_prop]
    if main_prop then
        attr[main_prop] = attr_num
    end

    --附加属性
    local char_attr = self.fight_attr
    local prop_conf_set = gdd.equipment_prop
    for k,v in pairs(equip.init_prop) do
        local prop_conf = prop_conf_set[v.id]
        if prop_conf then
            local prop_type = ATTR_ENUM[v.prop_type]
            if prop_type then
                --1:百分比 2：数值
                if v.num_type == 1 then
                    if char_attr[prop_type] then
                        attr[prop_type] = attr[prop_type] + v.value * char_attr[prop_type]
                    else
                        attr[prop_type] = (attr[prop_type] or 0) + v.value
                    end
                else
                    attr[prop_type] = (attr[prop_type] or 0) + v.value
                end
            --装备强化，装备本身的基础属性提高一定百分比
            elseif v.prop_type == 19 then
                attr[main_prop] = attr[main_prop] + attr[main_prop] * v.value
            end
        end
    end

    if equip.inlay_list then
        for k,v in pairs(equip.inlay_list) do
            if v ~= -1 then
                local gem = self:get_stuff_by_uuid("gem",v)
                if gem then
                    attr.extra_fight = attr.extra_fight + (gem:get_fight() or 0)
                end
            end
        end
    end
    
    return attr
end

local function cal_fight( attr )
    --太长了，分段写好看点
    local fight = 0

    local critical = attr.critical or 0
    local skill_dam = attr.skill_dam or 0
    local daodun_dam = attr.daodun_dam or 0
    local qiangqi_dam = attr.daodun_dam or 0
    local gongnu_dam = attr.gongnu_dam or 0
    local ceshi_dam = attr.ceshi_dam or 0
    local chuiche_dam = attr.chuiche_dam or 0
    local attack_fight = (attr.attack + skill_dam * 0.32) *
    (1 + critical*0.5 + daodun_dam*0.25 + qiangqi_dam*0.25 + gongnu_dam*0.16 + ceshi_dam*0.16 + chuiche_dam*0.2)

    local critical_defense = attr.critical_defense or 0
    local daodun_blk = attr.daodun_blk or 0
    local qiangqi_blk = attr.qiangqi_blk or 0
    local gongnu_blk = attr.gongnu_blk or 0
    local ceshi_blk = attr.ceshi_blk or 0
    local chuiche_blk = attr.chuiche_blk or 0
    local defense_fight = (attr.defense + attr.max_hp * 0.625) *
    (1 + critical_defense*0.5 + daodun_blk*0.5 + qiangqi_blk*0.5 + gongnu_blk*0.5 + ceshi_blk*0.5 + chuiche_blk*0.5)

    fight = math.floor(attack_fight + defense_fight + attr.hp_recovery*20 + attr.extra_fight)

    return fight
end

function Character:bulid_attr(  )
    local base_attr = self.fight_attr
    --基础属性
    local attr = {
        max_hp = base_attr.max_hp,
        attack = base_attr.attack,
        defense = base_attr.defense,
        critical = base_attr.critical,
        critical_defense = base_attr.critical_defense,
        attack_rate = base_attr.attack_rate,
        hp_recovery = base_attr.hp_recovery,
        extra_fight = 0,
    }   
    --天赋属性
    local talent_conf_set = gdd.talent
    for k,v in pairs(self.talent_list) do
        local id = v.type * 100 + v.level
        local conf = talent_conf_set[id]
        if conf then
            --怒气不增加战斗力
            if v.type == 1 then
                attr.attack = attr.attack + conf.add_prop
            elseif v.type == 2 then
                attr.defense = attr.attack + conf.add_prop
            elseif v.type == 3 then
                attr.max_hp = attr.attack + conf.add_prop
            end
        end
    end

    --装备属性,对于特殊属性，参与公式计算的加入attr结构，不参与的直接计入extra_fight
    local equip_list = self.package.equipment
    for k,v in pairs(equip_list) do
        if v.on then
            local equip_attr = self:get_equip_attr(v.uuid)
            if equip_attr then
                for m,n in pairs(equip_attr) do
                    attr[m] = (attr[m] or 0) + n
                end
            end
        end
    end

    --计算技能和心法战力
    for k,v in pairs(self.skill_list) do
        if v.is_using then
            attr.extra_fight = attr.extra_fight + (v:get_fight() or 0)
        end
    end

    local citta_list = self.package.citta
    if citta_list then
        for k,v in pairs(self.package.citta) do
            if v.skill_id and v.skill_id ~= -1 then
                attr.extra_fight = attr.extra_fight + (v:get_fight() or 0)
            end
        end
    end

    --计算副将战力
    for k,v in pairs(self.hero_list) do
        if v.on then
            local hero_attr = v:get_attr()
            if hero_attr then
                local fight = cal_fight(hero_attr)
                attr.extra_fight = attr.extra_fight + (fight or 0)
            end
        end
    end

    return attr
end

function Character:cal_char_fight(  )
    --计算出属性的战力
    local attr = self:bulid_attr()
    --[[（攻击+技能伤害*0.32）*（1+暴击率*0.5+刀盾伤害*0.25+枪骑伤害*0.25+弓弩伤害*0.16+策士伤害*0.16+车锤伤害*0.2）
    +（防御+生命*0.625）*（1+抗暴率*0.5+刀盾格挡*0.5+枪骑格挡*0.5+弓弩格挡*0.32+策士格挡*0.32+车锤格挡*0.4）
    +生命回复*20]]--
    local fight
    if attr then
        fight = cal_fight(attr)
    end

    return fight
end

--------------------------------------------------------------------------
---------------------------------关卡-------------------------------------
--------------------------------------------------------------------------
function Character:get_section_total_star( section )
    local map = self.map
    local total_star = 0

    for k,v in pairs(map) do
        if type(k) == "number" then
            for _,diff in pairs(v.diff) do
                if diff.section == section then
                    total_star = total_star + diff.star
                end
            end
        end
    end

    return total_star
end

function Character:insert_map_list( list,conf )
    local section_id = conf.section_id
    if section_id and section_id > 0 then
        local map_id = conf.scene_id
        local diff = conf.level
        local pre_id = conf.pre_scene

        local tmp = {}
        tmp.level = diff

        local map_rec = self:get_map_record(map_id,diff)
        if not map_rec then
            tmp.star = 0
            tmp.is_first = true
            tmp.att_time = 0
        else
            tmp.star = map_rec.star
            tmp.is_first = false
            tmp.att_time = map_rec.today_time or 0
        end

        if not pre_id or pre_id == -1 then
            tmp.can_att = true
        else
            local pre_rec = self:get_map_record(pre_id,1)
            if pre_rec then
                tmp.can_att = true
            else
                tmp.can_att = false
            end
        end

        local section = list[section_id] or {section_id=section_id}
        local map_list = section.map or {}
        local find_map = false
        local map
        for k,v in pairs(map_list) do
            if v.id == map_id then
                find_map = true
                map = v
            end
        end

        if not map then
            map = {}
            map.id = map_id
            map.pre_id = pre_id
        end

        local diff_list = map.diff or {}
        diff_list[diff] = tmp

        map.diff = diff_list
        if not find_map then
            table.insert( map_list,map )
        end
        section.map = map_list
        list[section_id] = section
    end
end

function Character:get_map_list_new(  )
    local map_rec = self.map
    local map_list = {}
    local conf_set = gdd.scene_chapter
    
    --获取地图记录
    for k,v in pairs(conf_set) do
        --map配置
        for m,n in pairs(v) do
            self:insert_map_list(map_list,n)
        end     
    end

    --计算章节可攻打状态，总星数
    for sec_id,section in pairs(map_list) do
        local can_att = false
        local total_star = 0
        for _,map in pairs(section.map) do
            for _,diff in pairs(map.diff) do
                total_star = total_star + (diff.star or 0)
                if diff.can_att then
                    can_att = true
                end
            end
        end

        if map_rec.section_record then
            section.reward_status = map_rec.section_record[sec_id] or 0
        else
            section.reward_status = 0
        end

        section.can_att = can_att
        section.total_star = total_star
    end

    --排序
    for _,section in pairs(map_list) do
        table.sort(section.map,function ( lhs,rhs )
            return lhs.id < rhs.id
        end)
    end
    return map_list
end

function Character:get_map_record( map_id,diff )
    local map_set = self.map
    local map = map_set[map_id]
    if not map then
        return nil
    end
    if not map.diff then
        --不应该出现有一个maptable里没有diff字段的，假如出现，修补一下吧
        map.diff = {}
        return nil
    end
    if not map.diff[diff] then
        return nil
    end

    return map.diff[diff]
end

function Character:check_enter_map(map_id,diff)
    local map = self.map
    local ok,conf = Map.check_map_valid(map_id,diff)
    if not ok then
        return ok,"map conf err"
    end
    --检查进入次数
    local record = self:get_map_record(map_id,diff)

    if record and conf.ask_count_list then
        total_time = conf.ask_count_list[self.vip+1] or conf.ask_count_list[1]
        local today_time = record.total_time or 0
        if today_time >= total_time then
            return false,"enter time deplete"
        end
    end

    --检查等级要求，战力要求，消耗
    if conf.ask_level > self.lv then 
         return false,get_intl_str("ERROR_LEVEL_TOO_LOW")
    end
    if conf.ask_power > 0 then
        --[[local power = self:get_power()
        if power < conf.ask_power then
            return false,"role power too low"
        end]]
    end
 
    if conf.ask_energy > self.fight_attr.energy then
        return false,"energy not enough"
    end
    if conf.ask_money > self.money then
        return false,"money not enough"
    end
    if conf.ask_rmb > self.rmb then
        return false,"rmb not enough"
    end


    --是否已在其他地图内
    if not map.cur_map then
        map.cur_map = {map_id = 0,diff = 0}
    end
    if map.cur_map.map_id ~= 0 then
        return false,get_intl_str("ERROR_REPEAT_ENTER_MAP")
    end

    local pre_id = conf.pre_scene
    if diff == 1 then
        --配置中无效值统一填为-1
        if (not map[pre_id]) and (pre_id ~= -1) then
            return false,get_intl_str("ERROR_DIDN_PASS_PRE_MAP")
        end
    else
        local record = map[map_id]
        if record and record.diff and record.diff[diff - 1] then
            if record.diff[diff - 1].star < 3 then
                return false,get_intl_str("ERROR_DIDN_PASS_PRE_DIFF")
            end
        else
            return false,get_intl_str("ERROR_DIDN_PASS_PRE_DIFF")
        end
    end

    return true
end

function Character:deal_map_cost(map_id,diff)
    --扣消耗
    local ok,conf = Map.check_map_valid(map_id,diff)
    if not ok then
        return ok,"map conf err"
    end

    if conf.ask_energy > 0 then
        if self.fight_attr.energy >= conf.ask_energy then
            self.fight_attr.energy = self.fight_attr.energy - conf.ask_energy
        else
            return false,"energy not enough"
        end
    end

    if conf.ask_money > 0 then
        if self.money >= conf.ask_money then
            self.money = self.money - conf.ask_money
        else
            return false,"money not enough"
        end
    end

    if conf.ask_rmb > 0 then
        if self.rmb >= conf.ask_rmb then
            self.rmb = self.rmb - conf.ask_rmb
        else
            return false,"rmb not enough"
        end
    end

    self:mark_updated()
    return true
end

function Character:get_map_star( map_id,diff )
    local map_data = self.map[map_id]
    if not map_data then
        return -1
    end
    local diff_data = map_data.diff
    if not diff then
        return -1
    end

    if not diff_data[diff] then
        return -1
    end

    return diff_data[diff].star
end

function Character:set_map_record(map_id,diff,star)
    local map_conf = Map.get_conf(map_id,diff)
    if not  map_conf then
        return false
    end

    --1:普通 2：精英 3：地狱 4：擂台 5：天梯 6：团战
    if map_conf.type ~= 2 and map_conf.type ~= 3 then
        star = 0
    end

    local map = self.map
    local map_data = map[map_id] or {} 
    map_data.diff = map_data.diff or {}
    --记录上map所属章节
    if not map_data.diff[diff] then
        map_data.diff[diff] = Map:new{id=map_id,diff=diff,star=star,section=map_conf.section_id}
    else
        if not map_data.diff[diff].star or map_data.diff[diff].star < star then          
             map_data.diff[diff].star = star
        end
    end

    --今天攻打次数
    map_data.diff[diff].today_time = map_data.diff[diff].today_time  or 0
    map_data.diff[diff].today_time = map_data.diff[diff].today_time + 1

    map[map_id]  = map_data
    self.map = map

    if star == 3 then
        skynet.call(database,"lua","map","add_rank",map_id,diff,self.id,self.nickname)
    end

    self:mark_updated()

    return true
end

function Character:set_cur_map( map_id,diff )
    self.map.cur_map.map_id = map_id
    self.map.cur_map.diff = diff
end

function Character:reset_cur_map(  )
    self.map.cur_map.map_id = 0
    self.map.cur_map.diff = 0

    self.map.cur_map.use_medicine = 0
    self.map.cur_map.relive_num = 0
end


function Character:give_reward(reward,usage)
    if not reward then
        return nil
    end

    local ret_reward = {}

    for i,v in ipairs(reward) do
        --lv只有宝石需要
        local ret = self:add_stuff(v.id,v.num,usage,v.lv) 
        if ret then
            if ret.id then
                table.insert(ret_reward,ret)
            else
                for m,n in pairs(ret) do
                    if n.id then
                        table.insert(ret_reward,n)
                    end
                end
            end
        else
            table.insert( ret_reward,v)
        end
    end

    self:check_hero_lv_up()

    self:mark_updated()
    --添加之后再把添加列表返回给客户端
    return ret_reward
end


--------------------------------------------------------------------------
-----------------------------------背包------------------------------------
--------------------------------------------------------------------------


--检测道具是否足够的入口。只判断物品，货币，各种碎片，不处理有uuid的道具
function Character:is_stuff_enough( id,num )
    local stuff_type = StuffFactory.get_stuff_type(id)
    local ret
    if stuff_type == StuffFactory.type_item then 
        -- 道具
        ret = self:is_item_enough(id,num)
    elseif stuff_type ==  StuffFactory.type_prop then 
        -- 属性
        ret = self:is_prob_enough(id,num)
    elseif stuff_type == StuffFactory.type_equip_debris then
        ret = self:is_debris_enough("equipment",id,num)
    elseif stuff_type == StuffFactory.type_gem_debris then
        ret = self:is_debris_enough("gem",id,num)
    elseif stuff_type == StuffFactory.type_citta_debris then
        ret = self:is_debris_enough("citta",id,num)
    elseif stuff_type == StuffFactory.type_hero_debris then
        ret = self:is_debris_enough("hero",id,num)
    else
        log.notice("is_stuff_enough,type error id,num",id,num)
    end 

    return ret
end
-- 自身物品id 

function Character:get_stuff_uuid()
    local stuff_uuid = self.stuff_uuid or 0
    stuff_uuid = stuff_uuid + 1 
    self.stuff_uuid = stuff_uuid
    return stuff_uuid
end

-- 是否有某个物品
function Character:had_this_stuff(stuff_type,id)
    local package = self.package or {}
    local type_stuff = package[stuff_type] or {}

    -- 在物品类型中查找 
    local find 
    for k,v in pairs(type_stuff) do
        if v.id == id then 
            find = v
            break
        end 
    end
    return find
end

-- 道具可以堆叠
function Character:add_item(id,num,usage) 
    local package = self.package or {}
    local type_stuff = package.item or {}
    -- 在物品类型中查找 
    local find 
    local idx 
    for k,v in pairs(type_stuff) do
        if v.id == id then 
            find = v
            idx = k
            break
        end 
    end
    num = num or 0
    if find then 
        -- 有，更改数量
        local num = find.num + num 
        if num <=0 then
            table.remove(type_stuff,idx)
        else
            find.num = num
        end

    else
        -- 没有构造，插入
        find = Item:new{
            id = id,
            num = num or 1,
            -- uuid = self:get_stuff_uuid(),
        }
        table.insert(type_stuff,find)
    end

    package.item = type_stuff

    self.package = package
    self:mark_updated()
end

--------------------------------------
---------------- @模块：背包-道具
--------------------------------------


-- 是否有足够的道具 
function Character:is_item_enough( id,num )
    local package = self.package or {}
    local type_stuff = package.item or {}
    -- 在物品类型中查找 
    local find 
    local idx 
    for k,v in ipairs(type_stuff) do
        if v.id == id then 
            find = v
            idx = k
            break
        end 
    end
    if find and find.num >= num then 
        return find,idx
    else
        return nil 
    end    
end



-- 道具 出售
function Character:sell_item( id,num )
    local stuff_type = StuffFactory.get_stuff_type(id)

    if stuff_type ~= StuffFactory.type_item then
        return nil,"该道具无法出售"
    end

    local find,idx = self:is_item_enough(id,num)
    if not find then 
        return nil,"没有该道具或者数量不足"
    end

    local get_list,msg = find:sell(num)
    if not get_list then
        return nil,msg
    end
    self:add_item(id,-num)

    return get_list
end

-- 道具 使用
function Character:use_item(id,num)
    local stuff_type = StuffFactory.get_stuff_type(id)
    if stuff_type ~= StuffFactory.type_item then
        return nil,"该道具无法出售"
    end

    local find = self:is_item_enough(id,num)
    if not find then
        return nil,"没有该道具或者数量不足"
    end

    local get_list,msg = find:use(num)
    if not get_list then
        return nil,msg
    end

    self:add_item(id,-num)
    
    return get_list
end

--------------------------------------
---------------- @模块：背包-装备
--------------------------------------

-- 获取指定装备
function Character:get_stuff_by_uuid( type,uuid )
    local package = self.package
    if not package then
        return nil
    end
    local type_stuff = package[type]
    if not type_stuff then
        return nil
    end

    local find 
    for k,v in pairs(type_stuff) do
        if v.uuid == uuid then 
            find = v
            break
        end
    end

    return find
end

function Character:delete_stuff(type,uuid )
    local package = self.package
    if not package then
        return false
    end
    local type_stuff = package[type]
    if not type_stuff then
        return false
    end

    local ret = false

    for k,v in pairs(type_stuff) do
        if v.uuid == uuid then 
            ret = true
            self:mark_updated()
            table.remove(type_stuff,k)
            break
        end
    end

    return ret
end

-- 不能堆叠
function Character:add_equipment(id,num,is_default)
    local package = self.package or {}

    local type_stuff = package.equipment or {}
    local list
    if num >= 0 then
        list = {}
        for i=1,num do
            local eq = Equipment:new{
                id=id,
                on=false,
                uuid = self:get_stuff_uuid(),
            }
            eq:init(is_default)
            table.insert(type_stuff,eq)
            table.insert(list,eq)
        end
    else
        local del_num = math.abs(num)
        for k,v in pairs(type_stuff) do
            if v.id == id then
                table.remove(type_stuff,k)
                del_num = del_num - 1
            end
            if del_num <= 0 then
                break
            end
        end
    end 

    package.equipment = type_stuff
    self.package = package
    self:mark_updated()
    return list
end


-- 装备
function Character:equip(uuid)
    local stuff_type = 2
    local package = self.package or {}
    local type_stuff = package.equipment or {}

    -- 是否有该装备
    local find 
    for k,v in pairs(type_stuff) do
        if v.uuid == uuid then 
            find = v
            break
        end
    end
    if not find then 
        return false,"找不到该装备"
    end
    -- 装备是否属性些角色
    local  belong_to = find:belong_to()
    if belong_to ~= self.class_id then 
        return false,"装备与主角不匹配"
    end

    local class = find:get_class() -- 小类 
    -- 该位置是否已装备
    local other
    for k,v in pairs(type_stuff) do
        if v:get_class() == class and v.on == true then 
            other = v
            break
        end
    end
    if other then 
        -- 脱
        other:put_off()
    end
    -- 穿上
    find:put_on()

    return true
end

-- 脱下
function Character:equip_off(uuid)
    local stuff_type = 2
    local package = self.package or {}
    local type_stuff = package.equipment or {}

    -- 是否有该装备
    local find 
    for k,v in pairs(type_stuff) do
        if v.uuid == uuid then 
            find = v
            break
        end
    end

    if not find then 
        return false,"找不到该装备"
    end

    find:put_off()

    return true
end

-- 升级
function Character:lv_up_equip(uuid,level_type,num)
    local stuff_type = 2
    local package = self.package or {}
    local type_stuff = package.equipment or {}

    -- 是否有该装备
    local find 
    for k,v in pairs(type_stuff) do
        if v.uuid == uuid then 
            find = v
            break
        end
    end

    if not find then 
        return {status=0,msg='没有找到该装备'}
    end
    --

    local prop={"package"}
    return self:get_ret(prop,nil)
end


--------------------------------------
---------------- @模块：背包宝石
--------------------------------------
-- 不能堆叠
function Character:add_gem(id,num,lv)
    local package = self.package or {}
    if (not lv) or lv <= 0 then
        lv = 1
    end
    local list
    local type_stuff = package.gem or {}
    if num >= 0 then
        list = {}
        for i=1,num do
            local eq = Gem:new{
                id=id,
                uuid = self:get_stuff_uuid(),
                lv = lv,
            }
            table.insert(type_stuff,eq)
            table.insert(list,eq)
        end
    else
        --暂时不在改动物品数量的函数里添加检测，检测在调用这些函数之前应该被处理
        --以后有必要的话，再添加吧
        for k,v in pairs(type_stuff) do
            if v.id == id then
                table.remove(type_stuff,k)
            end
        end
    end
    package.gem = type_stuff
    self.package = package
    self:mark_updated()

    return list
end

--------------------------------------
---------------- @模块：技能 
--------------------------------------

-- 存在某个技能
function Character:is_had_skill( skill_id )
    local skill_list = self.skill_list or {}
    local found 
    for k,v in pairs(skill_list) do
        if v.id == skill_id then 
            return v,k
        end
    end
    return nil 
end


--------------------------------------
---------------- @模块：背包心法
--------------------------------------

-- 不能堆叠
function Character:add_citta(id,num,lv)
    local package = self.package or {}

    local type_stuff = package.citta or {}
    local list = {}

    if num >= 0 then
        for i=1,num do
            local eq = Citta:new{
                id=id,
                uuid = self:get_stuff_uuid(),
                lv = lv or 1,
                exp = 0,
            }
            table.insert(type_stuff,eq)
            table.insert( list, eq )
        end 
    else
        for k,v in pairs(type_stuff) do
            if v.id == id then
                table.remove(type_stuff,k)
            end
        end
    end

    package.citta = type_stuff
    self.package = package
    self:mark_updated()

    return list
end

-- 存在某个心法
function Character:is_had_citta( uuid )
    local package = self.package or {}
    local citta = package.citta or {}
    local found 
    for k,v in pairs(citta) do
        if v.uuid == uuid then 
            return v,k
        end
    end
    return nil 
end

-- 删除某个心法
function Character:rm_citta( uuid )
    local package = self.package or {}
    local citta = package.citta or {}
    local found 
    for k,v in pairs(citta) do
        if v.uuid == uuid then 
            table.remove(citta,k)
            break
        end
    end
end

-- 是否有且足够
function Character:is_had_citta_debris( id,num )
    local debris = self.debris or {}
    local citta_debris = debris.citta or {}    
    for k,v in ipairs(citta_debris) do
        if v.id == id then             
            return v,v.num>=num
        end
    end
    return nil
end

function Character:add_citta_debris( id,num )
    local debris = self.debris or {}
    local citta_debris = debris.citta or {}    
    local found 
    for k,v in ipairs(citta_debris) do
        if v.id == id then             
            v.num = v.num + num 
            -- 不足时删除
            if v.num <=0 then 
                table.remove(citta_debris,k)
            end
            found = true
            break
        end
    end
    -- 原来包里没有，就增加
    if not found and num >0 then 
        table.insert(citta_debris,{id=id,num=num})
    end

    debris.citta = citta_debris
    self.debris = debris
    self:mark_updated()
end

-- 合成
function Character:compound_citta( args )
    -- 配方id
    local make_id = args.make_id
    -- 配方id 找到配方数据
    local all_make = gdd.citta_make
    local data = all_make[make_id]
    if not data then 
        return nil,"配方id有误"
    end

    local debris_id = data.debris_id
    local debris_num = data.debris_num 
    -- 材料所需 是否足够
    local found,is_enough = self:is_had_citta_debris( debris_id,debris_num )
    if not found
    or not is_enough 
    then 
        return nil,"碎片不足"
    end
    -- 减了
    self:add_citta_debris( debris_id,-debris_num )    
    -- 随机产生心法
    local output = data.output
    local r = math.random(1,data.total_prop)
    local len = #output
    local all_prop = 0 
    local citta

    for i=1,len do
        local v = output[i]
        local prop = v.prop 
        all_prop = all_prop + prop 
        if r <= all_prop then 
            local id = v.id
            local lv = v.lv 
            -- 加到心法
            citta = self:add_citta(id,1,lv)
            break
        end
    end

    --add_citta返回的是一个table
    return citta[1]
end






--------------------------------------
---------------- @模块：副将
--------------------------------------

-- 是否有某个副将
function Character:is_had_hero( uuid )
    local hero_list = self.hero_list or {}
    local found 
    for k,v in ipairs(hero_list) do
        if v.uuid == uuid then 
            found = v 
            break
        end
    end
    return found
end

-- 增加副将
function Character:add_hero(id,lv,exp,to_fight) 
    local hero_list = self.hero_list or {}
    local uuid = self:get_stuff_uuid()
    if not lv or lv <= 0 then
        lv = 1
    end
    local hero = Hero.create(id,lv,exp,to_fight,uuid)
    table.insert(hero_list,hero)
    self.hero_list = hero_list

    return hero
end

-- 删除副将
function Character:remove_hero(uuid) 
    local hero_list = self.hero_list or {}
    for k,v in ipairs(hero_list) do
        if v.uuid == uuid then 
            table.remove(hero_list,k)
            break
        end
    end
end

-- 增加副将
function Character:add_hero_by_id(id,lv,exp,to_fight )
    self:add_hero(id,1,0,false)
end


-- 升级
function Character:lv_up_hero(args)
    
end

-- 增加好感度
function Character:add_hero_goodwill( args )
    local hero_uuid = args.hero_uuid
    -- 副将是否存在
    local hero = self:is_had_hero( hero_uuid )
    if not hero then 
        return self:get_error_ret("没有找到该副将")
    end
    local item_id = args.item_id
    local num = args.num 
    local found = self:is_item_enough(item_id,num)
    if not found then 
        return self:get_error_ret("道具数量不足")
    end

    local ok,error_msg = hero:add_goodwill_stuff(id,num)
    if ok then 
        self:add_item(item_id,-num)
    else
        return self:get_error_ret(error_msg)
    end

    local prop = {
        "package",
        "hero_list",
    }
    return self:get_ret(prop)
end

-- 升级处理
function Character:lv_up_process()
    -- TODO 升级处理
    --改变角色基础数据
    local lv = self.lv
    local class_id = self.class_id
    local class_level_info = gdd.class_level_info
    local level_info = class_level_info[class_id]
    local level_data= level_info[lv]

    for k,v in pairs(level_need_key) do
        if level_data[v] then
            --目前没有升级时减小的属性
            self.fight_attr[v] = math.max(level_data[v],self.fight_attr[v])
        end
    end
    
    --没法直接call到agent，只好从char_mgr中转
    skynet.call("char_mgr","lua","fight_attr_change_notify",self.id)

    --处理天赋开放
    local talent_conf_set = gdd.talent
    for k,v in pairs(talent_conf_set) do
        local target_talent = self.talent_list[v.type]
        if target_talent and (not target_talent.is_open) and lv >= v.need_level then
            target_talent.is_open = true
            target_talent.level = 1
        end
    end

    --武将升级
    for k,v in pairs(self.hero_list) do
        v:add_exp(0,self.lv)
    end

    --处理char_list
    skynet.call(database,"lua","character","set_char_list",self.account_id,self.id,{lv=self.lv})

end

function Character:lv_up()
    local class_id = self.class_id 
    local class_level_info = gdd.class_level_info
    local level_data = class_level_info[class_id]
    local lv = self.lv 
    local data = level_data[lv]
    if not data then 
        skynet.error("citta lv_up error",class_id,lv)
        return 
    end 
    -- 当前经验值
    local exp = self.exp 
    -- 当前等级升级到下一级需要经验值 
    local up_exp = data.exp
    local max_lv = #level_data

    if exp >= up_exp and lv < max_lv then 
        -- 升级 消耗
        exp = exp - up_exp
        self.exp  = exp 

        -- 等级加1 
        lv = lv + 1         
        self.lv = lv
        -- 递归到经验不足以升级
        self:lv_up()
    end
end

-- from 经验值来源
function Character:add_exp(mexp,from)
    local exp = self.exp or 0 
    exp = exp + mexp 
    self.exp = exp 
    -- 增加经验后是否升级
    local lv = self.lv 
    self:lv_up()
    local now_lv = self.lv 
    local is_lv_up = now_lv > lv
    if is_lv_up then 
        -- 升级后处理
        self:lv_up_process()
    end
    return  is_lv_up
end

function Character:add_hero_exp( num )
    for k,v in pairs(self.hero_list) do
        if v:is_on() then
            local is_lv_up = v:add_exp(num,self.lv)
            break
        end
    end 
    return is_lv_up or false   
end

--如果某次奖励先发放武将经验再发放角色经验，可能出现武将可以升级却没升级的bug
--所以使用这个方法使武将检查一下是否升级
function Character:check_hero_lv_up(  )
    self:add_hero_exp(0)
end

function Character:add_money(num)  
    local money = self.money or 0 
    money = money + num
    self.money = money 
    self:mark_updated()
end

--加体力
--tofinish
function Character:add_energy( energy )
    --todo体力上限
    self.fight_attr.energy  = self.fight_attr.energy + energy
end

--加元宝
--tofinish
function Character:add_rmb( rmb )
    self.rmb = self.rmb + rmb
end

--加血量
--tofinish
function Character:add_hp( hp )
    self.hp = self.hp + hp
    self.hp = self.hp > self.max_hp and self.max_hp or self.hp
end

--加元宝
--tofinish
function Character:add_sp( sp )
    self.sp = self.sp + sp
    self.sp = self.sp > self.max_sp and self.max_sp or self.sp
end


--货币类型是否足够
function Character:is_prob_enough( id,num )
    local stuff_prop = gdd.stuff_prop
    local prop = stuff_prop[id]
    if not prop then 
        log.notice("Character:is_prob_enough(id,num) prop is nil:",id,num)
        return 
    end
    if prop.name == "money" then 
        return self.money >= num
    elseif prop.name == "exp" then 
        return self.exp >= num
    elseif prop.name == "energy" then 
        return self.fight_attr.energy >= num
    elseif prop.name == "rmb" then 
        return self.rmb >= num
    elseif prop.name == "hp" then 
        return self.hp >= num
    elseif prop.name == "sp" then 
        return self.sp >= num
    else
        return false
    end
end

function Character:add_prop_by_type( type,num )
    -- body
end

function Character:add_prop(id,num,usage)
    local stuff_prop = gdd.stuff_prop
    local prop = stuff_prop[id]
    if not prop then 
        log.notice("Character:add_prop(id,num,usage) prop is nil:",id,num)
        return 
    end
    if prop.name == "money" then 
        self:add_money(num)
    elseif prop.name == "exp" then 
        self:add_exp(num)
    elseif prop.name == "energy" then 
        self:add_energy(num)
    elseif prop.name == "rmb" then 
        self:add_rmb(num)
    --[[elseif prop.name == "hp" then 
        self:add_hp(num)
    elseif prop.name == "sp" then 
        self:add_sp(num)]]--
    elseif prop.name == "hero_exp" then
        self:add_hero_exp(num)
    else
        log.error("Character:add_prop(id,num,usage) type false:",id,num)
    end

    self:mark_updated()
end


function Character:get_package_stuff( type )
    
end

function Character:is_debris_enough( key,id,num )
    local debris = self.debris
    if not debris then
        return false
    end
    local type_debris = debris[key]
    if not debris then
        return false
    end

    for i,v in ipairs(type_debris) do
        if v.id == id then 
            return v.num >= num
        end
    end

    return false
end

-- 增加碎片
function Character:add_debris(key,id,num)
    local debris = self.debris or {}
    local type_debris = debris[key] or {}

    local found
    local k 
    for i,v in ipairs(type_debris) do
        if v.id == id then 
            found = v
            k = i
            break
        end
    end

    if found then 
        local num = found.num + num 
        found.num = num 
        if num <=0 then 
            table.remove(type_debris,k)
        end
    else
        table.insert(type_debris,{id=id,num=num})
    end
    debris[key] = type_debris
    self.debris = debris
end

-- 装备碎片
function Character:add_equipment_debris(id,num)
    self:add_debris("equipment",id,num)
end

-- 宝石碎片
function Character:add_gem_debris(id,num)
    self:add_debris("gem",id,num)
end

-- 心法碎片
function Character:add_citta_debris(id,num)
    self:add_debris("citta",id,num)
end

--武将碎片
function Character:add_hero_debris( id,num )
    self:add_debris("hero",id,num)
end


function Character:add_stuff(id,num,usage,...) 
    local stuff_type = StuffFactory.get_stuff_type(id)
    local ret
    if stuff_type == StuffFactory.type_item then 
        -- 道具
        ret = self:add_item(id,num)
    elseif stuff_type ==  StuffFactory.type_equip then 
        -- 装备
        ret = self:add_equipment(id,num)
    elseif stuff_type ==  StuffFactory.type_gem then 
        -- 宝石
        ret = self:add_gem(id,num,...)
    elseif stuff_type ==  StuffFactory.type_citta then 
        -- 心法
        self:add_citta(id,num)
    elseif stuff_type ==  StuffFactory.type_equip_debris then 
        -- 装备碎片
        ret = self:add_equipment_debris(id,num)    
    elseif stuff_type ==  StuffFactory.type_gem_debris then 
        -- 宝石碎片
        ret = self:add_gem_debris(id,num)
    elseif stuff_type ==  StuffFactory.type_citta_debris then 
        -- 心法碎片
        ret = self:add_citta_debris(id,num)
    elseif stuff_type ==  StuffFactory.type_prop then 
        -- 属性
        ret = self:add_prop(id,num)
    elseif stuff_type == StuffFactory.type_hero then
        ret = self:add_hero(id,...)
    elseif stuff_type == StuffFactory.type_hero_debris then
        ret = self:add_hero_debris(id,num)
    else
        log.notice("add_stuff error stuff_type,id,num,usage",stuff_type,id,num,usage)
    end 
    --简单地log一下。添加的方法里不出错就不log了
    log.debug("Character:add_stuff(id,num,usage) :",id,num,usage)

    self:mark_updated()    
    return ret
end
