--------------------------------------------------------------------------
-- Desc:csv加载类
-- Author: 
-- Data: 2014-10-11 10:02:28
-- Last: 
-- Copyright (c) 2010 QUWAN Entertainment All right reserved.
--------------------------------------------------------------------------

local ms = require "ms"

local core = core
local deb = deb
local table = table
local tonumber = tonumber
local pairs = pairs

module "settings.load_csv"


--------------------------------------------------------------------------
-- 加载食谱信息
--------------------------------------------------------------------------
function loadCookbook(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		local info = {}
		info.typeId = csv:getInt(row, "TypeID") 
		info.name = csv:getData(row, "Name")
		info.price = csv:getInt(row, "Price")
		info.star = csv:getInt(row, "Star")
		info.foodIds = {}
		info.foodNums = {}

		local foods = csv:getData(row, "FoodsID")
		local list = core.string.split(foods, ";")

		for i = 1, #list do
			local arry = core.string.split(list[i], "-")
			local foodId = tonumber(arry[1])
			local num = tonumber(arry[2] or "1")
			table.insert(info.foodIds, foodId)
			table.insert(info.foodNums, num)
		end

		if result[info.typeId] then
			ms.log.error("重复的食谱配置")
			return
		end
		result[info.typeId] = info
	end
	return result
end


--------------------------------------------------------------------------
-- 加载食材信息
--------------------------------------------------------------------------
function loadMaterial(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		local info = {}
		info.typeId = csv:getInt(row, "TypeID") 
		info.name = csv:getData(row, "Name")
		info.price = csv:getInt(row, "Price")
		if result[info.typeId] then
			ms.log.error("重复的食材配置")
			return
		end
		result[info.typeId] = info
	end
	return result
end


--------------------------------------------------------------------------
-- 加载场景表
--------------------------------------------------------------------------
function loadScene(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		local info = {}
		info.id = csv:getInt(row, "ID") 
		info.name = csv:getData(row, "Name")
		info.number = csv:getInt(row, "Number")
		info.tasks = {}

		local tasks = csv:getData(row, "TaskList")
		local l = core.string.split(tasks, ";")

		for i = 1, #l do
			local taskId = tonumber(l[i])
			table.insert(info.tasks, taskId)
		end
		
		if result[info.id] then
			ms.log.error("重复的场景ID配置")
			return
		end
		result[info.id] = info
	end
	return result
end

--------------------------------------------------------------------------
-- 加载任务表
--------------------------------------------------------------------------
function loadTask(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		local info = {}
		info.id = csv:getInt(row, "ID") 

		info.mode = 0

		local str = csv:getData(row, "Mode")
		if str == "Main" then
			info.mode = 1
		elseif str == "Activity" then
			info.mode = 2
		end

		info.type = 0

		str = csv:getData(row, "Type")
		if str == "Cooking" then
			info.type = 1
		elseif str == "Consume" then
			info.type = 2
		end

		info.executeId = csv:getInt(row, "ExecuteID")

		info.scoreRate = csv:getInt(row, "ScoreRate")

		info.S = csv:getData(row, "S")
		info.A = csv:getData(row, "A")
		info.B = csv:getData(row, "B")
		info.C = csv:getData(row, "C")
		info.D = csv:getData(row, "D")

		info.name = csv:getData(row, "Name")
		info.desc = csv:getData(row, "Desc")
		info.forceId = csv:getInt(row, "ForceID")

		if result[info.id] then
			ms.log.error("重复的任务编号:%d", info.id)
			return
		end
		result[info.id] = info
	end
	return result
end


--------------------------------------------------------------------------
-- 加载商城配置 
--------------------------------------------------------------------------
function loadMall(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		local info = {}

		info.id = csv:getInt(row, "ID")
		if result[info.id] then
			ms.log.warn("配置了重复的道具，id:%d", info.id or -1)
		end

		info.name = csv:getData(row, "Name")
		info.desc = csv:getData(row, "Desc")
		info.type = csv:getInt(row, "Type")

		if info.type ~= 2 and info.type ~= 3 and info.type ~= 5 and info.type ~= 6 and info.type ~= 7 then
			ms.log.warn("配置了错误的类型，请检查。错误道具Id：%d", info.id or -1)
		end

		info.priceMoney = csv:getInt(row, "PriceMoney")
		info.priceDiamond = csv:getInt(row, "PriceDiamond")

		local putaway = csv:getData(row, "Putaway")

		if putaway == "TRUE" then
			info.isPutaway = true
		else
			info.isPutaway = false
		end

		info.getId = csv:getInt(row, "GetID")

		result[info.id] = info
	end
	return result
end

--------------------------------------------------------------------------
-- 加载成就
--------------------------------------------------------------------------
function loadAchieve(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		
		local info = {}

		info.id = csv:getInt(row, "Id")
		if result[info.id] then
			ms.log.warn("配置了重复的成就Id，id:%d", info.id or -1)
		end

		info.name = csv:getData(row, "Name")

		local ctype = csv:getData(row, "ConditionType")
		info.conditionType = ms.egame.AchieveConditionType[ctype]
		if not info.conditionType then
			ms.log.warn("成就[%d]配置了错误的条件类型%s", info.id, ctype)
		end

		info.params = {}
		for k = 1, 5 do 
			local str = csv:getData(row, "Param"..k)
			local values = ms.str.subString(str, ";")
			local params = {}
			
			for k, v in pairs(values or {}) do 
				local value = tonumber(v)
				if value ~= -1 then
					table.insert(params, value)
				end
			end
			if #params > 0 then
				table.insert(info.params, params)
			end
		end


		info.packageId = csv:getInt(row, "PackageId")
		info.conditionDesc = csv:getData(row, "ConditionDesc")
		result[info.id] = info
	end
	return result
end

--------------------------------------------------------------------------
-- 加载日常任务表
--------------------------------------------------------------------------
function loadEverydayTask(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		
		local info = {}

		info.id = csv:getInt(row, "Id")
		if result[info.id] then
			ms.log.warn("配置了重复的日常任务Id，id:%d", info.id or -1)
		end

		info.name = csv:getData(row, "Name")

		local ctype = csv:getData(row, "ConditionType")
		info.conditionType = ms.egame.EverydayTaskConditionType[ctype]
		if not info.conditionType then
			ms.log.warn("日常任务[%d]配置了错误的条件类型%s", info.id, ctype)
		end

		info.params = {}
		for k = 1, 5 do 
			local str = csv:getData(row, "Param"..k)
			local values = ms.str.subString(str, ";")
			local params = {}
			
			for k, v in pairs(values or {}) do 
				local value = tonumber(v)
				if value ~= -1 then
					table.insert(params, value)
				end
			end
			if #params > 0 then
				table.insert(info.params, params)
			end
		end


		info.packageId = csv:getInt(row, "PackageId")
		info.conditionDesc = csv:getData(row, "ConditionDesc")
		result[info.id] = info
	end
	return result
end

--------------------------------------------------------------------------
-- 加载充值表
--------------------------------------------------------------------------
function loadRecharge(csv, res)
	local result = res or {}
	for row = 0, csv:getRowNum() -1 do
		
		local info = {}

		info.id = csv:getInt(row, "ID")
		if result[info.id] then
			ms.log.warn("配置了重复的充值ID，ID:%d", info.id or -1)
		end

		info.rechargeType = csv:getInt(row, "RechargeType")
		if info.rechargeType ~= 1 and info.rechargeType ~= 2  then
			ms.log.warn("充值[%d]配置了错误的充值货币类型%s", info.id, info.rechargeType)
		end

		info.payType = csv:getInt(row, "PayType")
		if info.payType ~= 1 and info.payType ~= 2  then
			ms.log.warn("充值[%d]配置了错误的付款货币类型%s", info.id, info.payType)
		end

		info.rechargeAmount = csv:getInt(row, "RechargeAmount")
		info.desc = csv:getData(row, "Desc")
		info.payAmount = csv:getInt(row, "PayAmount")

		result[info.id] = info
	end
	return result
end