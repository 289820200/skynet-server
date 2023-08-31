---------------------------时间相关-----------------------------------
ONE_MIN_SEC = 60

ONE_HOUR_SEC = ONE_MIN_SEC * 60

ONE_DAY_SEC = ONE_HOUR_SEC * 24

TIME_ZONE = 8

TIME_ZONE_SEC = TIME_ZONE * ONE_HOUR_SEC


---------------------------地图相关------------------------------------
--通关排行榜刷新时间
MAP_RANK_EXPIRE_TIME = ONE_DAY_SEC * 30

---------------------------属性相关------------------------------------
--每次回的体力值
ADD_ENERGY = 1

--体力回复间隔
ADD_ENERGY_CYCLE =  5 * ONE_MIN_SEC

--角色属性枚举
ATTR_ENUM = {
    [1] = "attack",
    [2] = "defense",
    [3] = "max_hp",
    [4] = "critical",
    [5] = "critical_defense",
    [6] = "hp_recovery",
    [7] = "sp_recovery",
    [8] = "daodun_dam",
    [9] = "qiangqi_dam",
    [10] = "gongnu_dam",
    [11] = "ceshi_dam",
    [12] = "chechui_dam",
    [13] = "daodun_blk",
    [14] = "qiangqi_blk",
    [15] = "gongnu_dam",
    [16] = "ceshi_dam",
    [17] = "chechui_blk",
    [18] = "skill_dam",
}

---------------------------固定ID-------------------------------------
EXP_ID = 50000001
ENERGY_ID = 50000002
HP_ID = 50000003
SP_ID = 50000004
MONEY_ID = 50000005
RMB_ID = 50000006
HERO_EXP_ID = 50000007


RUSH_ACT_ID = 102


---------------------------商城相关------------------------------------
--奇珍阁物品数量
MAX_TREASURE_NUM = 6

--刷新奇珍阁消耗元宝
REF_TREASURE_COST = 20


---------------------------装备相关------------------------------------
--取消洗练保留装备费用
PROTECT_EQUIP_COST = {
    [1] = 10,
    [2] = 20,
    [3] = 50,
    [4] = 100,
    [5] = 200,
}

--取下宝石消耗金币
INLAY_REMOVE_COST = 50

---------------------------邮件相关------------------------------------
--邮件淘汰时间
MAIL_EXPIRE_TIME = ONE_DAY_SEC * 10

---------------------------pvep相关------------------------------------
--急行战购买次数耗费
PUSH_BUY_COST = 50
--急行战等级段

PUSH_LEVEL = {
    [1] = 20,
    [2] = 30,
    [3] = 40,
    [4] = 50,
}










