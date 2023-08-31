local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local deep_copy = require "common.DeepCopy"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"
require "common.predefine"

require "polo.Citta"


-- local uuid = require "uuid"


local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd
local agent

skynet.init(function ()
	gdd = sharedata.query "settings_data"
end)


handler:init (function (u)
	user = u
	database = ".database" --skynet.uniqueservice ("database")
	-- gdd = sharedata.query "settings_data"
	agent = u.agent
end)

local function load_list (account)
	local list = skynet.call (database, "lua", "character", "list", account)
	if list then
		list = dbpacker.unpack (list)
	else
		list = {}
	end
	return list
end

local function check_char_list()
	local char_list = user.char_list
	if not char_list then 
		char_list = load_list(user.account_id)
		user.char_list = char_list
	end 
end

-- 构建创建新角色
local function get_new_char(class_id,nickname)
	-- 创建新的角色
	local char = Character.create_new_char(class_id,nickname)

	-- 给角色列表
	local char_desc = char:get_desc()
	return char_desc,char
end

-- 更新正在使用的角色
local function using_char(data)
	user.character = data
	--暂时处理，登录时清空当前地图记录，以免出现在地图里退出客户端，下次无法进地图的bug
	--做完断线重连机制再来改掉
	user.character:reset_cur_map()
	skynet.call(agent,"lua","char_login")
end

local function send_welcome_mail( char_id )
	local mail_data = {
		-- -1表示系统邮件
		src_char = -1,
		type = 2,
		title = "欢迎来到狂斩三国",
		content = "请收下礼品",
		des_char_list = {[1] = char_id},
		attachment={[1] = {id=50000001,num=100},[2] = {id=50000006,num=100}},
	}
	skynet.call("mail_center","lua","send_mail",mail_data)
end


function REQUEST.char_create(args)
	local account_id = args.account_id
	assert(account_id,"缺少 account_id 参数")
	
	local class_id = args.class_id
	assert(class_id,"缺少 class_id 参数")
	check_char_list()
	local char_list = user.char_list
	local find
	for k,v in ipairs(char_list) do
		if v.class_id == class_id then 
			find = v
			break
		end 
	end
	if find then 
		return {status = 0,msg="该种族已有角色"..(find.nickname or "X")}
	else
		local nickname = args.nickname
		assert(nickname,"缺少 nickname 参数")
		local exist_id = skynet.call(database,"lua","character","get_name_to_id",nickname)
		if 	exist_id then 
			return {status = 0,msg="该名字已被使用"}
		end 	
		-- nickname 昵称唯一性检查

		local char_desc,char = get_new_char(class_id,nickname)
		local char_id = char.id
		
		--有时用得着
		char.account_id = account_id

		-- 存入数据库
		-- skynet.call(database,"lua","character","save_char",char_id,char)
		char:save()
		-- 存入昵称对应 id 
		skynet.call(database,"lua","character","set_name_to_id",nickname,char_id)

		-- 更新角色列表
		table.insert(char_list,char_desc)
		user.char_list = char_list
		skynet.call(database,"lua","character","save_char_list",account_id,char_list)
		using_char(char)
		--给新角色发欢迎邮件
		send_welcome_mail(char.id)
		return {status = 1,char_list=char_list,char_info=char}
	end  
end

function REQUEST.char_login(args)
	local account_id = args.account_id
	local char_id = args.char_id
	check_char_list()
	local char_list = user.char_list
	assert(account_id,"缺少account_id参数")	
	local find
	for k,v in ipairs(char_list) do
		if v.id == char_id then 
			find = v
			break
		end 
	end
	if not find then 
		log.debug("该角色不存在","account_id",account_id,"class_id",class_id)
		return {status = 0 ,msg="该角色不存在"}
	end  
	-- 从数据库加载角色信息
	local char = Character.load_char(char_id)

	using_char(char)
	--发送登录广播
	user.broadcast_list["WORLD"]:publish("欢迎"..user.character.nickname.." papapa!")
	return {status = 1,char_info=char}
end

-- function REQUEST.character_list ()
-- 	local list = load_list (user.account)
-- 	local character = {}
-- 	for _, id in pairs (list) do
-- 		local c = skynet.call (database, "lua", "character", "load", id)
-- 		if c then
-- 			character[id] = dbpacker.unpack (c)
-- 		end
-- 	end
-- 	return { character = character }
-- end

--------------------------------------
---------------- @模块：背包
--------------------------------------

-- 出售道具
function REQUEST.sell_item(args)
	local char = user.character
	local id = args.id
	local num = args.num

	local get_list,msg = char:sell_item(id,num)
	if not get_list then
		return char:get_error_ret(msg)
	end

	get_list = char:give_reward(get_list)

	return char:get_succ_ret({get_stuff_list=get_list})
end

-- 使用道具
function REQUEST.use_item(args)
	local char = user.character
	local id = args.id
	local num = args.num

	local get_list,msg =  char:use_item(id,num)
	if not get_list then
		return char:get_error_ret(msg)
	end

	get_list = char:give_reward(get_list)

	return char:get_succ_ret({get_stuff_list=get_list})
end

--使用药品
function REQUEST.use_medicine( req )
	local char = user.character
	local cur_map = char.map.cur_map

	if (not cur_map.map_id) or cur_map.map_id == 0 then
		return char:get_error_ret("不在战斗中，无法使用药品")
	end

	local map_conf = Map.get_conf(cur_map.map_id,cur_map.diff)
	if not map_conf then
		return char:get_error_ret("找不到地图配置")
	end

	local init_conf = gdd.scene_init[map_conf.init_id]
	if not init_conf then
		return char:get_error_ret("该地图无法使用药品")
	end

	local m_id = init_conf.drug_id
	local m_count = init_conf.drug_count

	if (not m_id) or (not m_count) or m_count <= 0 then
		return char:get_error_ret("该地图无法使用药品")
	end

	local used_num = cur_map.use_medicine or 0
	if used_num >= m_count then
		return char:get_error_ret("使用药品次数已满")
	end

	local find = char:is_item_enough(m_id,1)
	if not find then
		return char:get_error_ret("该药品不足")
	end

	used_num = used_num + 1
	cur_map.use_medicine = used_num

	char:add_stuff(m_id,-1,"use medicine")

	return char:get_succ_ret({id=m_id})
end

--战斗中复活
function REQUEST.relive( req )
	local char = user.character
	local cur_map = char.map.cur_map

	if (not cur_map.map_id) or cur_map.map_id == 0 then
		return char:get_error_ret("不在战斗中，无法复活")
	end

	local map_conf = Map.get_conf(cur_map.map_id,cur_map.diff)
	if not map_conf then
		return char:get_error_ret("找不到地图配置")
	end

	local init_conf = gdd.scene_init[map_conf.init_id]
	if not init_conf then
		return char:get_error_ret("找不到地图初始化配置")
	end
	
	local quest_conf
	for k,v in pairs(gdd.quest) do
		if v.quest == map_conf.quest_list[1] then
			quest_conf = v
		end
	end
	if not quest_conf then
		return char:get_error_ret("找不到任务配置")
	end

	if not init_conf.can_relive then
		return char:get_error_ret("该地图无法复活")
	end

	local max_count = quest_conf.relive or 0
	local cur_count = cur_map.relive_num or 0

	if cur_count >= max_count then
		return char:get_error_ret("复活次数不足")
	end

	local cost_list = init_conf.relive_money_list
	if not cost_list then
		return char:get_error_ret("消耗元宝配置错误")
	end
	--如果复活次数超过数组长度，取最后一个
	local cost = cost_list[cur_count + 1] or cost_list[#cost_list]
	if not cost then
		return char:get_error_ret("消耗元宝配置错误")
	end

	if not char:is_prob_enough(RMB_ID,cost) then
		return char:get_error_ret("复活所需元宝不足")
	end

	char:add_stuff(RMB_ID,-cost)

	cur_map.relive_num = cur_count + 1

	return char:get_succ_ret({cost=cost})
end

--------------------------------------
---------------- @模块：心法模块
--------------------------------------

--装备
function REQUEST.equip_citta( req )
	local char = user.character
	local skill_id = req.skill_id 
	local citta_uuid = req.citta_uuid 
	local citta = char:is_had_citta(citta_uuid)
    if not citta then 
        return {status=0,msg='没有找到该心法'}
    end
    if citta.skill_id or  citta.skill_id == skill_id then 
    	return {status=0,msg='该心法已装备'}
    end

    local skill = char:is_had_skill( skill_id )
    if not skill then 
        return {status=0,msg='没有找到该技能'}
    end
    -- 当前角色 25
 	local lv = char.lv 
 	if lv < 25 then 
 		return {status=0,msg='该功能需要角色等级达到25级'}
 	end

 	-- 当前技能等级
 	lv = skill.level or 1
 	if lv < 10 then 
 		return {status=0,msg='该功能需要技能等级达到10级'}
 	end

 	local tmp_uuid = skill.citta_uuid
 	if tmp_uuid then 
 		-- 现有的心法拆下来
 		local tmp = char:is_had_citta(tmp_uuid)
 		if tmp then 
 			tmp.skill_id = nil
 		end
 	end 

 	citta.skill_id = skill_id
 	skill.citta_uuid = citta_uuid
 	char:mark_updated()
 	return {status=1,msg='成功'}
end

--升级
function REQUEST.lv_up_citta( args )
	local char = user.character
	local uuid = args.uuid
	local citta = char:get_stuff_by_uuid("citta",uuid)
	if not citta then 
		-- 没有成功
		return char:get_error_ret("找不到目标心法")
	end
	local old_lv = citta.lv

	-- 升级材料
    local citta_list =  args.citta_list or {}

    local list = {}
    for k,v in ipairs(citta_list) do
        local _uuid = v 
        if _uuid == uuid then 
            return {status=0,msg='不能使用自身作为材料'}
        end
        local f = char:is_had_citta(_uuid)        
        if not f then 
            local msg='心法材料不满足'
            log.debug(msg,"id,升级心法uuid,材料_uuid",char.id,uuid,_uuid)
            return char:get_error_ret(msg)
        end
        table.insert(list,f)
    end

    --清理数据
    for k,v in ipairs(citta_list) do       
        char:rm_citta(v)
    end
    citta:add_citta_exp(list)

	if citta.lv > old_lv and citta.lv >= 5 then        
        -- 当用户将心法升级到5级及其以上时，系统自动在全服广播：恭喜XXX，成功将XX心法升级到了X级！
        local citta_name = Citta.get_name(citta.id)        
        local msg = string.format("恭喜%s，成功将%s心法升级到了%d级！",char.nickname,citta_name,citta.lv)
        user:publish_world_broadcast(msg)
    end

    char:mark_updated()

	return char:get_succ_ret({citta = citta}) 
end

-- 
function REQUEST.compound_citta(args)
	local char = user.character
	local citta,msg = char:compound_citta(args)
	-- 当用户合成心法的等级为5级及其以上时，系统自动在全服广播：恭喜XXX，成功合成X级的XX心法！
	if not citta then
		-- 没有成功	 
		return char:get_error_ret(msg)
	end
	local lv = citta.lv
	if lv >= 5 then        
        local citta_name = Citta.get_name(citta.id)        
        local msg = string.format("恭喜%s，成功合成%d级的%s心法！",char.nickname,lv,citta_name)
        user:publish_world_broadcast(msg)
    end
	return char:get_succ_ret({citta=citta}) 
end


function REQUEST.add_stuff(args)
	local char = user.character
	for k,v in ipairs(args.stuff_list) do
		local id = v.id
		local num = v.num 		
		char:add_stuff(id,num,"测试增加")
	end
	local prop = {"package"}
	local ret = char:get_ret(prop)
	return ret
end

function REQUEST.heart_beat( req )
	--空函数就行
end

--专门测试用
function REQUEST.test_code( req )
	local char = user.character
	local parm = req.parm
	--测试sharedata
	local conf = gdd.hero[60000001]

	return char:get_succ_ret({parm_str=conf.intro})
end


function handler.init (character)
	local temp_attribute = {
		[1] = {},
		[2] = {},
	}
	local attribute_count = #temp_attribute

	character.runtime = {
		temp_attribute = temp_attribute,
		attribute = temp_attribute[attribute_count],
	}

	local class = character.general.class
	local race = character.general.race
	local level = character.attribute.level

	local gda = gdd.attribute

	local base = temp_attribute[1]
	base.health_max = gda.health_max[class][level]
	base.strength = gda.strength[race][level]
	base.stamina = gda.stamina[race][level]
	base.attack_power = 0
	
	local last = temp_attribute[attribute_count - 1]
	local final = temp_attribute[attribute_count]

	if last.stamina >= 20 then
		final.health_max = last.health_max + 20 + (last.stamina - 20) * 10
	else
		final.health_max = last.health_max + last.stamina
	end
	final.strength = last.strength
	final.stamina = last.stamina
	final.attack_power = last.attack_power + final.strength

	local attribute = setmetatable (character.attribute, { __index = character.runtime.attribute })

	local health = attribute.health
	if not health or health > attribute.health_max then
		attribute.health = attribute.health_max
	end
end

function handler.save (character)
	if not character then return end

	local runtime = character.runtime
	character.runtime = nil
	local data = dbpacker.pack (character)
	character.runtime = runtime
	skynet.call (database, "lua", "character", "save", character.id, data)
end

return handler

