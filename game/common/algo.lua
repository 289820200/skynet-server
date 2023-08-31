--------------------------------------------------------------------------
-- Desc:    一些算法函数
-- Author:  
-- Date:    2010.9.20
-- Last:
-- Copyright (c) 2010 QUWAN Entertainment All right reserved.
--------------------------------------------------------------------------

local math = math
local type = type
local pairs = pairs
local print = print
local table = table
local rawget = rawget
local rawset = rawset
local string = string
local dprint = dprint
local getmetatable = getmetatable
local setmetatable = setmetatable
local skynet = require "skynet"

local bit = bit
local deb = deb
local bits = bits
local core = core
local cpack = pack
local marshal = marshal
local cjson = cjson


--------------------------------------------------------------------------
-- 限制值在有效范围内
--------------------------------------------------------------------------
function limit(value, min, max)
    if value < (min or value) then
        return min
    elseif value > (max or value) then
        return max
    end
    return value
end
--------------------------------------------------------------------------
-- 快速计算两个坐标间的距离
--  返回值是未开方的距离（sqrt后的值才是最终距离值）
--------------------------------------------------------------------------
function distanceSq(sx, sy, dx, dy)
    local distX = dx - sx
    local distY = dy - sy
    return distX * distX + distY * distY
end
--------------------------------------------------------------------------
-- 计算两个坐标间的距离
--  返回最终距离值
--------------------------------------------------------------------------
function distance(sx, sy, dx, dy)
    return math.sqrt((sx - dx) * (sx - dx) + (sy - dy) * (sy - dy))
end
--------------------------------------------------------------------------
-- 计算朝向角度（和图形引擎一致，客户端用，还需要加上curAngle参数用于返回值时取最优角度）
--
--  角度值，5是原点，curAngle为0的情况：
--
--  1 2 3
--  4 5 6
--  7 8 9
--
--  1   =   2.3561944961547852
--  2   =   3.1415901184082031
--  3   =   -2.3561944961547852
--  4   =   1.5707963705062866
--  5   =   1.5707963705062866
--  6   =   -1.5707963705062866
--  7   =   0.78539818525314331
--  8   =   0
--  9   =   -0.78539818525314331
--------------------------------------------------------------------------
function angle(sx, sy, dx, dy, curAngle)
    return core.algo.angle(sx, sy, dx, dy, curAngle or 0)
end
--------------------------------------------------------------------------
-- 计算相对角度
--  角度值，5是原点，curAngle为0的情况：
--
--  1 2 3
--  4 5 6
--  7 8 9
--
--  1   =   135.00000000000014
--  2   =   90.000000000000099
--  3   =   45.00000000000005
--  4   =   180.0000000000002
--  5   =   0
--  6   =   0
--  7   =   -135.00000000000014
--  8   =   -90.000000000000099
--  9   =   -45.00000000000005
--------------------------------------------------------------------------
function calcAngle(sx, sy, dx, dy)
    return core.algo.calcAngle(sx, sy, dx, dy)
end
--------------------------------------------------------------------------
-- 计算两个角度间的差值(0-360)
--------------------------------------------------------------------------
function calcDiffAngle(curAngle, destAngle)
    local navValue = destAngle > 0.0 and destAngle - 6.2832 or destAngle + 6.2832
    local diff = math.min(math.abs(curAngle - destAngle), math.abs(curAngle - navValue))
    return diff * 360 / 3.1415926
end
--------------------------------------------------------------------------
-- 清除表里所有字段
--------------------------------------------------------------------------
function cleanupTable(tab)
    local fields = {}
    for fld in pairs(tab) do
        table.insert(fields, fld)
    end

    for _, fld in pairs(fields) do
        tab[fld] = nil
    end
end
--------------------------------------------------------------------------
-- 覆盖表，将src里的字段遍历覆盖到dest表，dest里没有的字段则会创建
--------------------------------------------------------------------------
function overwriteTable(dest, src)
    setmetatable(dest, getmetatable(src))

    -- 表替换，防止嵌套死循环
    local replaceTables = {}

    local traversalTable
    traversalTable = function(dest, src)
        -- 将目标表中存在，源表中不存在的字段先删除
        local removeKeys = {}
        for key, dstValue in pairs(dest) do
            if not rawget(src, key) then
                table.insert(removeKeys, key)
            end
        end
        for _, key in pairs(removeKeys) do
            dest[key] = nil
        end

        -- 拷贝目标表字段到源表
        for key, srcValue in pairs(src) do
            if type(srcValue) == "table" then
                if not replaceTables[srcValue] then
                    local dstTable = rawget(dest, key) or {}
                    replaceTables[srcValue] = dstTable

                    traversalTable(dstTable, srcValue)
                    setmetatable(dstTable, getmetatable(srcValue))
                    rawset(dest, key, dstTable)
                else
                    rawset(dest, key, replaceTables[srcValue])
                end
            else
                rawset(dest, key, srcValue)
            end
        end
    end
    traversalTable(dest, src)
end
--------------------------------------------------------------------------
-- 拷贝表
--------------------------------------------------------------------------
function copyTable(src)
    local dst = {}
    overwriteTable(dst, src)
    return dst
end
--------------------------------------------------------------------------
-- 比较两个table是否相同
--------------------------------------------------------------------------
function isSameTable(t1, t2)
	if nil == t1 or t2 == nil then return false end
    if type(t1) ~= "table" then return false end
    if type(t2) ~= "table" then return false end
	
	local count1 , count2 = 0, 0
	for _,_ in pairs(t1) do
		count1 = count1 + 1
	end
	for _,_ in pairs(t2) do
		count2 = count2 + 1
	end
	
	if count1 == count2 then
		for k, v in pairs(t1) do 
			if nil ~= t2[k] and type(t1[k]) == type(t2[k]) then
				if type(t1[k]) == "table" then
					if not isSameTable(t1[k], t2[k]) then
						return false
					end
				else
					if t1[k] ~= t2[k] then
						return false
					end
				end
			else 
				return false
			end
		end
	else 
		return false
	end
	return true
end
--------------------------------------------------------------------------
-- 返回无顺序表单count
--------------------------------------------------------------------------
function getTableCount(t1)
	if nil == t1 then return 0 end
    if type(t1) ~= "table" then return 0 end
	local count = 0
	for _, _ in pairs(t1) do
		count = count + 1
	end
	return count
end
--------------------------------------------------------------------------
-- 返回表单有无此value  递归子table
--------------------------------------------------------------------------
function testTableValue(t1, value)
    if nil == t1 then return false end
    if nil == value then return false end
    if type(t1) ~= "table" then return false end
    for k, v in pairs(t1) do
        if v == value then
            return true, k, v
        elseif type(v) == "table" then
            if testTableValue(v, value) then
                return testTableValue(v, value)
            end
        end
    end
    return false
end
--------------------------------------------------------------------------
-- 返回表单有无此key  递归子table
--------------------------------------------------------------------------
function testTableKey(t1, key)
    if nil == t1 then return false end
    if nil == key then return false end
    if type(t1) ~= "table" then return false end
    for k, v in pairs(t1) do
        if k == key then
            return true, k, v
        elseif type(k) == "table" then
            if testTableKey(k, key) then
                return testTableKey(k, key)
            end
        end
    end
    return false
end
--------------------------------------------------------------------------
-- 生成以s为起点，t -> s 为方向，distance为距离的点
--------------------------------------------------------------------------
function calcDistancePos(sx, sy, tx, ty, distance)
    local dir = {}
    dir.x = sx - tx
    dir.y = sy - ty
    local unit = math.sqrt((dir.x * dir.x) + (dir.y * dir.y))
    dir.x = dir.x / unit
    dir.y = dir.y / unit
    local x = sx + dir.x * distance
    local y = sy + dir.y * distance
    return x, y
end
--------------------------------------------------------------------------
-- 判断点是否在区域内
--------------------------------------------------------------------------
function ptInRect(x, y, left, top, right, bottom)
    return (x >= left and x <= right) and (y >= top and y <= bottom)
end
--------------------------------------------------------------------------
-- 版本字符串转数字
--------------------------------------------------------------------------
function string2Version(strVersion)
    local _, _, major, minor, rev = string.find(strVersion, "(%d+).(%d+).(%d+)")
    return major * 0x1000000 + minor * 0x10000 + rev
end
--------------------------------------------------------------------------
-- 数字转版本字符串
--------------------------------------------------------------------------
function version2String(version)
    local major = version / 0x1000000
    local minor = bit.band(version / 0x10000, 0xFF)
    local rev   = bit.band(version, 0xFFFF)

    return string.format("%d.%d.%d", major, minor, rev)
end
--------------------------------------------------------------------------
-- 打包table成一个string
--------------------------------------------------------------------------
function pack(tab, raw)
    if raw then
        --print("pack marshal raw")
        return marshal.encode(tab)
    else
        --print("pack marshal encode")
        return bits.encode(marshal.encode(tab))
    end
end
--------------------------------------------------------------------------
-- 从string解包成table
--------------------------------------------------------------------------
function unpack(buf, raw)
    if not raw then
        buf = bits.decode(buf)
    end
    if marshal.check(buf) then
        --print("unpack marshal " .. (raw and "raw" or "decode"))
        return marshal.decode(buf)
    else
        --print("unpack original " .. (raw and "raw" or "decode"))
        return cpack.unpack("t", buf)
    end
end

--------------------------------------------------------------------------
-- 判断一个数是否为整数
--------------------------------------------------------------------------
function isIntNumber( value )
    return math.floor(value) - value == 0
end

--------------------------------------------------------------------------
-- 在一个范围内生成指定个数的不重复的随机数
-- 范围参数（_start,_end）中有一个为小数，则随机数为小数。
--------------------------------------------------------------------------
function genRandoms(_start, _end, count)
    local rl = {}

    if math.abs(_end - _start)+1 < count and isIntNumber(_start) and isIntNumber(_end) then
        skynet.error("调用genRandoms出错，随机个数小于可选范围")
        return 
    end

    done = false
    local runTime = 0
    while not done do
        runTime = runTime + 1
        local r = math.random(_start, _end)
        local selected = false
        for _, val in pairs(rl) do
            if val == r then
                selected = true
            end
        end
        if not selected then
            table.insert(rl, r)
            if table.getn(rl) == count then
                done = true
            end
        end
    end
    --print("runTime", runTime)
    return rl
end
--------------------------------------------------------------------------
-- 消息组包、解?
--  组包，将消息组包成每个不大于4KB的字符串列表返回
--  解包，集合完成消息后解包
--------------------------------------------------------------------------
-- local BLOCK_SIZE = 2048
-- function packMessage(msg, sender)
--     local s = marshal.encode(msg)
--     if #s <= BLOCK_SIZE then
--         return sender(s)
--     else
--         -- print('split msg:', msg.id, #s)
--         -- dprint(msg)
--         -- 按照2KB进行拆包
--         for idx = 1, #s, BLOCK_SIZE do
--             -- 拆分的字符串
--             local split = string.sub(s, idx, idx + BLOCK_SIZE - 1)
--             -- 拆分的消?
--             local split_msg = {
--                 finish = (idx + BLOCK_SIZE) > #s,
--                 split  = split,
--             }
--             -- print(idx, split_msg.finish)
--             -- 发送拆分后的消?
--             sender(marshal.encode(split_msg))
--         end
--     end
-- end

-- local payloads = {}
-- setmetatable(payloads, { __mode = "kv" })

-- function unpackMessage(holder, msg, receiver)
--     local t = marshal.decode(msg)
--     if t.split ~= nil then
--         local result = false
--         local payload = payloads[holder] or ""
--         payload = payload .. t.split
--         if t.finish then
--             -- print('组装消息，大小：', #payload)
--             result = receiver(marshal.decode(payload))
--             payload = ""
--         end
--         payloads[holder] = payload
--         return result
--     else
--         return receiver(t)
--     end
-- end
function packMessage(msg, sender)
    msg.msg = cjson.encode(msg.msg)
    local s = cjson.encode(msg)
    return sender(s)
end
function unpackMessage( holder, msg, receiver )
    local t = cjson.decode(msg)
    return receiver(t)
end

--------------------------------------------------------------------------
-- 打印table信息
--------------------------------------------------------------------------
function printTable(t) --, name, indent)   
    local tableList = {}   
    function table_r (t, name, indent, full)   
        local id = not full and name or type(name)~="number" and tostring(name) or '['..name..']'   
        local tag = indent .. id .. ' = '   
        local out = {}  -- result   
        if type(t) == "table" then   
            if tableList[t] ~= nil then  table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')   
            else  
                tableList[t]= full and (full .. '.' .. id) or id  
                if next(t) then -- Table not empty   
                    table.insert(out, tag .. '{')   
                    for key,value in pairs(t) do   
                        table.insert(out,table_r(value,key,indent .. '    ',tableList[t]))   
                    end   
                    table.insert(out,indent .. '}')   
                else table.insert(out,tag .. '{}') end   
            end   
        else  
            local val = type(t)~="number" and type(t)~="boolean" and '"'..tostring(t)..'"' or tostring(t)   
            table.insert(out, tag .. val)   
        end   
        return table.concat(out, '\n')   
    end   
    return (table_r(t,'Value',''))
end

function random_count(raw_table,count,weight_key)
    local list = {}
    if count > 0 then 
        -- 放到临时表中
        local tmp = {}
        for k,v in pairs(raw_table) do
            tmp[k] = v
        end
        while count > 0 do
            local total_prob = 0 
            for k,v in pairs(tmp) do
                total_prob = (v[weight_key] or 0) + total_prob
            end
            
            if total_prob <= 0 then 
                print("!!!!! There is error random_count !!!!! total_prob <= 0")
                break
            end
            local r = math.random(1,total_prob)
            local tmp_r = 0 
            for k,v in pairs(tmp) do
                tmp_r = tmp_r + v[weight_key]
                if r <= tmp_r then 
                    table.insert(list,v)
                    tmp[k] = nil -- 去掉 使用在剩下里去随机
                    break
                end
            end
            count = count - 1
        end        
    end
    return list
end

function get_random_char_name( class_id )
    if not class_id then
        class_id = math.random(1,3)
    end
    local append = {
        "赵云",
        "周瑜",
        "貂蝉",
    }
    local mid ={
        "的","の","之","★","☆","○","●","◎","◇","◆","□","℃","€","■","※","→","¤"
    }

    local pre_serial = math.random(0,10000)

    return pre_serial..mid[math.random(#mid)]..append[class_id]
end
