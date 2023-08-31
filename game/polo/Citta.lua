--------------------------------------
-- @Author:      Aloha
-- @DateTime:    2015-11-24 13:53:19
-- @Description: 心法
--------------------------------------
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local gdd 
local citta_data 
local all_level_info 
skynet.init(function ()
    gdd = sharedata.query "settings_data"
    citta_data  = gdd.citta
    all_level_info = gdd.citta_level_info
end)

Citta={
    
}


function Citta:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    return o
end

function Citta.get_name( id )
    return citta_data[id].name
end

function Citta:lv_up(  )
    local id = self.id 
    local level_data = all_level_info[id]
    if not level_data then
        skynet.error("level_data is nil self.id:",self.id)
        return 
    end
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

-- 增加经验值
function Citta:add_exp(mexp)
    local exp = self.exp or 0
    exp = exp + mexp 
    print("exp,mexp",exp,mexp)
    self.exp = exp
    self:lv_up()
end

-- 列表
function Citta:add_citta_exp( list )
    local exp = 0 
    for k,v in ipairs(list )do
        local id = v.id
        local lv = v.lv 
        -- 通过 id lv 找到作为材料的贡献经验值 
        local level_data = all_level_info[id] or {}        
        local data = level_data[lv] or {}
        local contr_exp = data.contr_exp or 0 
        print("contr_exp",id,lv,contr_exp)
        exp = exp + contr_exp
    end
    self:add_exp(exp)
end

function Citta:get_level_data(  )
    local level_data = all_level_info[self.id]
    if not level_data then
        return nil
    end

    local data = level_data[self.lv]
    if not data then 
        return nil
    end 

    return data
end

function Citta:get_fight(  )
    local level_data = self:get_level_data()
    if not data then
        return 0
    end

    return data.fight or 0
end

