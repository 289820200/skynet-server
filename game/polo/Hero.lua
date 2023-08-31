--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-12-11 11:25:20
-- @Description: 武将
--------------------------------------

local database = ".database"

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local print_r = require "common.print_r"
local log = require "log"

local gdd 
skynet.init(function() 
    gdd = sharedata.query "settings_data"
end)


Hero={
    
}

function Hero:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self    
    return o
end

-- 根据hero_id获取属性
function Hero.get_data( id )
    local heros = gdd.hero 
    local hero = heros[id]
    if not hero then
        print("hero is nil id",id)
    end
    return hero
end

-- 构造副将实例
function Hero.create(id,lv,exp,on,uuid)
    -- 每个副将拥有一个同主角（玩家）之间的好感度；好感度初始值为30，上限为100；
    local hero = Hero:new({id=id,lv=(lv or 1),exp=(exp or 0),on=on,uuid=uuid})
    hero:init_data()
    return hero
end


local prop_list = {    
    "goodwill",
    "grade",
}

-- 生成成长值
local grow_list = {
    -- 静态数据 key 属性值 key
    {data_key = "atk_grow",prop_key = "atk_grow"},
    {data_key = "def_grow",prop_key = "def_grow"},
    {data_key = "hp_grow",prop_key = "hp_grow"},
}


function Hero:init_raw_data( )
    local id =self.id 
    local data = Hero.get_data(self.id)
    if not data then 
        print("副将信息不存在，id",id)
        return 
    end

    --非战斗属性
    for k,v in pairs(prop_list) do
        self[v] = data[v]
    end

    --战斗属性
    self.attr = {}
    self:build_base_attr(self.grade or 0)

    -- 成长值
    for m,n in ipairs(grow_list) do
        local data_key = n.data_key
        local grow_data = data[data_key]
        local weight = grow_data.weight
        local r = math.random(weight)
        local tmp_r = 0 
        for k,v in ipairs(grow_data) do
            local prob = v.prob 
            tmp_r = tmp_r + prob
            if r <= tmp_r then 
                local from = v.from
                local to = v.to 
                local rank = to - from 
                local value = math.random()*rank + from
                -- 保留一位小数
                local value = math.floor(value*10)/10
                -- 成长值
                local prop_key = n.prop_key
                self.attr[prop_key] = value
                break
            end 
        end
    end
end

--因为和stuff_desc里的字段重名，编码时会出错，所以加上了_f后缀
function Hero:init_prop_f()
    -- 初始化过
    if self.inited_prop then return end
    self:init_raw_data()
    self.inited_prop = true
end


function Hero:init_data()
    -- 基础属性
    self:init_prop_f()
    -- 技能
    self:init_skill()
end

--------------------------------------
---------------- 上阵
--------------------------------------
function Hero:is_on()
    return self.on
end

function Hero:get_on()
    self.on = true
end


function Hero:get_off()
    self.on = false
end


--------------------------------------
---------------- 技能
--------------------------------------

-- 当数据库里取出有数据，对象化
function Hero:init_had_skill()
    local skill_list = self.skill_list or {}
    for k,v in ipairs(skill_list) do
        local skill = Skill:new(v)
        skill_list[k] = skill 
    end
    self.skill_list = skill_list
end

-- 初始化技能
function Hero:init_skill()
    local skill_list = self.skill_list or {}
    if #skill_list > 0 then
        self:init_had_skill()
        return
    end
    --初始化一下技能
    local hero_conf = gdd.hero[self.id]
    local skill_conf = gdd.skill
    -- 前三个技能是三段普攻
    if hero_conf then 
        local index = -1 
        for k,v in pairs(hero_conf.skill_list) do
            if skill_conf[v] then
                
                --副将技能初始就是1级
                local skill = Skill:new{id=v,level=1,is_using=false,index=-1}
                
                if not skill:is_passive() then 
                    -- 除被动技能由升阶激活外，主动，合击默认开启
                    index = index + 1 -- 从0 开始
                    skill:put_on(index)
                else
                    skill.index = 7 
                end 

                table.insert(skill_list,skill)
            end
        end
    end
    self.skill_list = skill_list
end

--------------------------------------
---------------- 洗练
--------------------------------------

---------------------------------------------------------------
-- 之前的方式 start
-- -- 洗练 确定就没什么事了，恢复再请求处理
-- function Hero:refined(hero)
--     if self.id ~= hero.id then return nil,"副将类型不匹配" end 
--     local idx = math.random(1,3)
--     local aptitude = main_aptitude_idx[idx]
--     -- 记录洗练
--     local pre_defined = {[aptitude] = self[aptitude]}
--     self.pre_defined = pre_defined

--     local value = hero[aptitude]
--     self[aptitude] = value
--     -- 返回洗练后的值,洗出的属性
--     return true,aptitude,value
-- end

-- -- 恢复
-- function Hero:refined_back( )
--     local pre_defined = self.pre_defined
--     if not pre_defined then 
--         return nil ,"没有洗练过"
--     end
--     -- 恢复
--     local key
--     local value 
--     for k,v in pairs(pre_defined) do
--         key = k
--         value = v
--         self[k] = v
--     end
--     self.pre_defined = nil 
--     return true,key,value
-- end
-- 之前的方式 end
---------------------------------------------------------------


-- 洗练 
-- 副将洗练 
-- 副将洗练是消耗相同的副将来增加成长值。
-- 每次洗练副将的成长值都会增加，增加量：
-- 被消耗的副将成长-该副将最低成长）*副将阶位对应的洗练系数 
-- 例如：
-- 阶位3的张辽攻击成长为25，被消耗掉的张辽攻击成长为6.5，
-- 阶位3的张辽能增加的成长：
-- （6.5-5）*0.5=0.75
--         其中6.5为消耗掉的张辽的攻击成长
--         5为副将张辽的最低成长（数据来自表2）
--         0.5为阶位3的张辽的洗练系数（数据来自表3）
-- 最后洗练后阶位3的张辽攻击成长变为25.8（取小数点后1位）。
-- 当洗练后的攻击成长达到了对应阶位的成长上限，则成长不会再增加。

function Hero:refined(hero)
    local conf = Hero.get_data(self.id)
    if not conf then
        return false,"武将配置错误"
    end

    local grade = self.grade or 0
    -- 自身阶数对应数值
    local grade_data = conf.grade_data_list[grade]
    
    local refine_fac = grade_data.refine_fac

    -- 攻防血 
    local list = {
        "atk_grow","def_grow","hp_grow"
    }
    local grow_list = {}
    -- 被吞副将信息
    for k,v in ipairs(list) do
        local h_grow = hero[v] or 0
        -- 最小最大值
        local min
        for m,n in ipairs(conf[v]) do
            if (not min) or min > n.from then
                min = n.from
            end
        end

        local max = conf["max_"..v.."_list"][grade]
        if (not min) or (not max) then
            return false,"配置数值出错，请检查"
        end

        -- 洗练增长
        local add = (h_grow-min)*refine_fac
        if add < 0 then 
            log.error("增长数值小于0，请检查配置",self.id,hero.id)
            add = math.max(add,0)
        end
        
        -- 当洗练后的攻击成长达到了对应阶位的成长上限，则成长不会再增加。
        local grow = (self.attr[v]  or 0) + add        
        grow = math.min(grow,max)
        
        -- 保留一位小数
        grow = math.floor(grow*10)/10

        grow_list[v] = grow
    end

    for k,v in pairs(grow_list) do
        self.attr[k] = v
    end

    return true
end



--------------------------------------
---------------- 升级
--------------------------------------
function Hero:lv_up(lv_limit)
    local id = self.id 
    local all_level_info = gdd.hero_level_info
    local level_data = all_level_info[id]
    local lv = self.lv 
    local data = level_data[lv]
    if not data then 
        skynet.error("citta lv_up error",id,lv)
        return 
    end 


    -- 当前经验值
    local exp = self.exp 

    -- 当前等级升级到下一级需要经验值 
    local up_exp = data.up_exp
    print("exp,up_exp,lv,#level_data",exp,up_exp,lv,#level_data)
    if exp >= up_exp and lv < #level_data then 
        -- 副将等级不能超过主角
        if lv >= lv_limit then                         
            return 
        end 
        -- 升级 消耗
        print("hero lv up,exp,lv",exp,lv)
        exp = exp - up_exp
        self.exp  = exp 
        -- 等级加1 
        lv = lv + 1           
        self.lv = lv

        -- 递归到经验不足以升级
        self:lv_up(lv_limit)
    end
end

-- 升级后
function Hero:lv_up_process()
    -- TODO
end

-- 增加经验值
-- lv_limit 主角等级
function Hero:add_exp(mexp,lv_limit)
    local exp = self.exp or 0
    exp = exp + mexp     
    self.exp = exp
    local lv = self.lv 
    self:lv_up(lv_limit)
    local now_lv = self.lv 
    local is_lv_up = now_lv > lv 
    if is_lv_up then 
        self:lv_up_process()
    end
    return is_lv_up
end

--------------------------------------
---------------- 升阶
--------------------------------------
function Hero:build_base_attr( grade )
    local data = Hero.get_data(self.id)
    if not data then
        return false,"找不到武将配置"
    end

    local grade_data = data.grade_data_list[grade]
    if not grade_data then
        return false,"武将配置错误"
    end

    for k,v in pairs(grade_data) do
        self.attr[k] = v
    end

    return true
end

function Hero:up_grade()
    local data = Hero.get_data(self.id)
    if not data then
        return false,"找不到武将配置"
    end
    local next_grade = (self.grade or 0) + 1

    local ok,msg = self:build_base_attr(next_grade)
    if not ok then
        return false,msg
    end

    self.grade = next_grade

    return true
end


--------------------------------------
---------------- 好感度
--------------------------------------

-- 增加好感度
function Hero:add_goodwill(gw)
    local goodwill = self.goodwill or 0 
    if goodwill >= 100 then 
        return false,"好感度已满"
    end
    goodwill = goodwill + gw 
    -- 0<= goodwill<=100 
    goodwill = math.max(0,goodwill)
    goodwill = math.min(100,goodwill)
    self.goodwill = goodwill
    return true
end

-- 吃道具增加好感度 
function Hero:add_goodwill_stuff(stuff_id,num)
    -- 道具的增加的好感度
    -- 暂定游戏中有5种道具：鼎烧鹿肉10点、青梅酒5点、一合酥3点、女儿红2点、胭粉香料1点；
    local stuff = gdd.item
    local data = stuff[id] or {}
    local gw = data.goodwill or 0
    assert(gw>0)
    local n = num or 0
    return self:add_goodwill(gw*n)
end

-- 结束一声战斗影响好感度
-- is_win is_dead
function Hero:fight_affect_goodwill( is_win,is_dead )
    if is_win then 
        self:win_goodwill()
    else
        self:lost_goodwill()
    end
    -- 不论成败，死了就是死了，扣你丫的：）
    if is_dead then 
        self:dead_goodwill()
    end
end


-- 胜利一场增加好感度
function Hero:win_goodwill()
    local gw = sellf.win_gw
    assert(gw>=0)
    self:add_goodwill(gw)
end


-- 失败一场减少好感度
function Hero:lost_goodwill()
    local gw = sellf.lost_gw
    assert(gw<=0)
    self:add_goodwill(gw)
end


-- 死亡一场减少好感度
function Hero:dead_goodwill()
    local gw = sellf.dead_gw
    assert(gw<=0)
    self:add_goodwill(gw)
end

function Hero:get_attr(  )
    local data = Hero.get_data()
    if not data then
        return nil
    end

    return self.attr
end




