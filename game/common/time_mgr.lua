--------------------------------------------------------------------------
-- Desc:    时间日期管理器
-- Author:  
-- Date:    2011.04.19
-- Last:
-- Copyright (c) 2010 QUWAN Entertainment All right reserved.
--
-- 时间日期相关的参数意义：
--  day     = 1..31
--  wday    = 1..7  周一 周二 周三 周四 周五 周六 周日
--  hour    = 0..23
--  minute  = 0..59
--  second  = 0..59
--------------------------------------------------------------------------
--local ms = require "ms"

local os = os
local print = print
local math = math
local pairs = pairs
local tonumber = tonumber

local deb = deb

--module "base.time_mgr"

--------------------------------------------------------------------------
-- 天数 to 秒数
--------------------------------------------------------------------------
function dayToSecond(day)
    return day * 24 * 3600
end
--------------------------------------------------------------------------
-- 分数 to 秒数
--------------------------------------------------------------------------
function minuteToSecond(minute)
    return minute * 60
end
--------------------------------------------------------------------------
-- 获取当前时间的所在的天数
--------------------------------------------------------------------------
function getDayByTime(tm)
    local daySeconds = dayToSecond(1)
    return math.floor((tm + 8 * 3600) / daySeconds)
end
--------------------------------------------------------------------------
-- 获取当前时间的所在的周
--------------------------------------------------------------------------
function getWeekByTime(tm)
    local daySeconds = dayToSecond(1)
    return math.floor((tm + 8 * 3600 - daySeconds * 4) / (daySeconds * 7))
--    return os.date("%W", tm)
end

--------------------------------------------------------------------------
-- 取得时间点当天（凌晨零点零分零秒）的时间
--------------------------------------------------------------------------
function dayBeginTime(tm)
    local daySeconds = dayToSecond(1)
    local tmDay = math.floor((tm + 8 * 3600) / daySeconds)
    -- 格林威治时间是从8点开始，所以这里要减去8个小时的秒数
    return tmDay * daySeconds - (8 * 3600)
end

--------------------------------------------------------------------------
-- 格林威治时间转为北京时间
--------------------------------------------------------------------------
function UTCtoBeginTime(tm)
    -- 格林威治时间是从8点开始，所以这里要减去8个小时的秒数
    return tm - (8 * 3600)
end
--------------------------------------------------------------------------
-- 取下一个时间点（时、分、秒）以及距离现在的时间
--------------------------------------------------------------------------
function nextDayTime(hour, minute, second)
    hour = hour or 0
    minute = minute or 0
    second = second or 0

    local now       = os.time()
    -- 取得当天凌晨的时间
    local nowBegin  = dayBeginTime(now)
    -- 计算指定时分秒需要经过秒数
    local passSec   = hour * 3600 + minute * 60 + second
    -- 下个时间点=凌晨时间+需要经过秒数
    local nextTime    = nowBegin + passSec
    -- 如果下个时间点小于当前时间，则取下一天的时间
    if nextTime <= now then
        nextTime = nextTime + dayToSecond(1)
    end
    return nextTime, nextTime - now
end
--------------------------------------------------------------------------
-- 取下一个时间点（周几、时、分、秒）以及距离现在的时间
--------------------------------------------------------------------------
--                                   1    2    3    4    5    6    7
-- os.date里返回结构的wday星期顺序是 周日 周一 周二 周三 周四 周五 周六
-- 而我们习惯的星期顺序是            周一 周二 周三 周四 周五 周六 周日
--------------------------------------------------------------------------
--local weekDays = { 2, 3, 4, 5, 6, 7, 1 }
-- 两个wday的间隔天数
local weekDeltaDays = {
    --      周日 周一 周二 周三 周四 周五 周六
    [1] = { 0,   1,   2,   3,   4,   5,   6 }, -- 周日
    [2] = { 6,   0,   1,   2,   3,   4,   5 }, -- 周一
    [3] = { 5,   6,   0,   1,   2,   3,   4 }, -- 周二
    [4] = { 4,   5,   6,   0,   1,   2,   3 }, -- 周三
    [5] = { 3,   4,   5,   6,   0,   1,   2 }, -- 周四
    [6] = { 2,   3,   4,   5,   6,   0,   1 }, -- 周五
    [7] = { 1,   2,   3,   4,   5,   6,   0 }, -- 周六
}
function nextWeekTime(wday, hour, minute, second)
    local now       = os.time()

    local tm        = os.date("*t", now)
    tm.hour         = hour or 0
    tm.min          = minute or 0
    tm.sec          = second or 0
    local nextTime  = os.time(tm)

    local deltaDays = weekDeltaDays[tm.wday][wday or 1]
    nextTime = nextTime + (deltaDays * dayToSecond(1))
    -- 如果下次时间小于当前时间，则设置为一周后的时间
    if nextTime <= now then
        nextTime = nextTime + dayToSecond(7)
    end
    
    return nextTime, nextTime - now
end
--  获取当前是星期几
function getWeekDay()
	local tm        = os.date("*t", now)
	local wDay = tm.wday -1 --(从1-7分别对应周日到周六)
	if wDay == 0 then
		wDay = 7
	end
	return wDay
end
--------------------------------------------------------------------------
-- 判断两个时间,是否是同一天
--------------------------------------------------------------------------
function isSameDay(destTime, srcTime)
    local destDay = os.date("*t", destTime)
    local srcDay = os.date("*t", srcTime)
    if srcDay.year ~= destDay.year
    or srcDay.month ~= destDay.month
    or srcDay.day ~= destDay.day then				
        return false
    else
        return true
    end
end
--------------------------------------------------------------------------
-- 判断两个时间,是否是同一周
--------------------------------------------------------------------------
function isSameWeek(destTime, srcTime)
    local destWeek = math.floor(destTime / (60*60*24*7))
    local srcWeek = math.floor(srcTime / (60*60*24*7))
    if destWeek ~= srcWeek then
        return false
    else
        return true
    end
end

--------------------------------------------------------------------------
-- 检测当前时间是否在两个时间段内
-- param1 & param2 必须是如下格式：p1= {year=?, month=?, day=?,hour=?}
--------------------------------------------------------------------------
function isInTime(startTm, endTm, _curTime)
	local curTime = _curTime or os.time()
    curTime = os.date("*t", curTime)
	
	local _startTm = curTime
	for k, v in pairs(_startTm) do 
		_startTm[k] = startTm[k] or v
	end
	_startTm = os.time(_startTm)
	
	local _endTm = curTime
	for k, v in pairs(_endTm) do 
		_endTm[k] = endTm[k] or v
	end
	_endTm = os.time(_endTm)
	
	curTime = os.time()
-- 	print(_startTm, curTime, _endTm)
	if curTime <= _endTm and curTime >= _startTm then
		--print("xxx")
		return true
	end
	return false
end

-------------------------------------------------------------------------
-- 检测当前日期，日期限制
--[[
	_date = {
		min = { year = 2013, month = 1, day = 4 },
		max = { year = 2013, month = 1, day = 4 },
	}
--]]
--------------------------------------------------------------------------
--[[function checkDate(_date, _chekDate)
	if not _date then
		return false
	end
	
	if not _date.min or not _date.max then
		return false
	end
	
	return ms.time_mgr.isInTime(_date.min, _date.max, _chekDate)
end
--]]
-------------------------------------------------------------------------
-- 检测指定的时间是否在限制时间内，时间限制  
--[[
    _time = {
        min = { hour = 5, min = 20, sec=0 },
        max = { hour = 5, min = 20, sec=0 },
    }
    checktime {os.date("*t")}
--]]
--------------------------------------------------------------------------
function checkTime(_time, checktime)
    if not _time then
        return
    end
    local curTime = checktime or os.time()
    curTime = os.date("*t", curTime)
    local nowTime_hour      = curTime.hour
    local nowTime_min       = curTime.min
    local nowTime_sec       = curTime.sec or 0
    local nowTime_AllMin    = nowTime_hour * 3600 + nowTime_min*60 + nowTime_sec
    
    local _timeMin = _time.min.hour * 3600 + _time.min.min*60 + _time.min.sec or 0
    local _timeMax = _time.max.hour * 3600 + _time.max.min*60 + _time.max.sec or 0
    
    if nowTime_AllMin < _timeMin or nowTime_AllMin > _timeMax then
        return false
    end 
    return true
end

-------------------------------------------------------------------------
-- 检测当前星期，星期限制
--[[
	周一..周7
	1,2,3,4,5,6,7
--]]
--------------------------------------------------------------------------
function checkWeek(_week)
	if not _week then
		return false
	end
	local nowWeek 	= tonumber(os.date("%w"))
	if nowWeek == 0 then
		nowWeek = 7
	end
	return nowWeek == _week
end
-------------------------------------------------------------------------
-- 检测当前日期，日期限制
--[[
	_date = {
		min = { year = 2013, month = 1, day = 4 },
		max = { year = 2013, month = 1, day = 4 },
	}
--]]
--------------------------------------------------------------------------
function checkServerDate(_date)
	if not _date then
		return false
	end
	
	if not _date.min or not _date.max then
		return false
	end
    -- 当前时间
    local curServerTime = os.date("*t")
    -- 起始时间
    local beginTime = curServerTime
    for k, v in pairs(beginTime) do 
        beginTime[k] = _date.min[k] or v
    end
    local beginTimeSec = os.time(beginTime)
    -- 结束时间
    local endTime = curServerTime
    for k, v in pairs(endTime) do 
        endTime[k] = _date.max[k] or v
    end
    local endTimeSec = os.time(endTime)
    -- 当前时间
    local curServerTimeSec = os.date("*t")

    if curServerTimeSec <= endTimeSec and curServerTimeSec >= beginTimeSec then
        return true
    end
    return false
end
---------------------------------------------------------------------
-- 时间数据转换成分钟
----------------------------------------------------------------------
function timeDataToSec(timeData)
	local timeSec = 0
	if timeData.hour and timeData.hour > 0 then
		timeSec = (timeData.hour*60)*60
	end
	if timeData.min and timeData.min > 0 then
		timeSec = timeSec + (timeData.min*60)
	end
	if timeData.sec and timeData.sec > 0 then
		timeSec = timeSec + timeData.sec
	end
	return timeSec
end
---------------------------------------------------------------------
-- 判断当前时间是否在此时间段内
-- 返回：是否/间隔时间
----------------------------------------------------------------------
function getLastSecInTime(starSec, endSec)
	if not starSec or not endSec then
		return
	end
	
	local nowTime_hour 		= tonumber(os.date("*t", os.time()).hour)
	local nowTime_min 		= tonumber(os.date("*t", os.time()).min)
	local nowTime_sec 		= tonumber(os.date("*t", os.time()).sec)
	local nowTime_AllSec 	= (nowTime_hour*60)*60 + (nowTime_min*60) + nowTime_sec
	
	-- 在时间内
	if nowTime_AllSec >= starSec and nowTime_AllSec <= endSec then
		local disSec = endSec - nowTime_AllSec
		return true, false, disSec
	end
	
	-- 还没参加过
	local isReady = false
	-- 不在时间内, 还没到
	if starSec - nowTime_AllSec > 0 then
		isReady = true
		return false, isReady, starSec - nowTime_AllSec
	end
	
	-- 不在时间内, 已超出
	if nowTime_AllSec - endSec > 0 then
		isReady = false
		return false, isReady, nowTime_AllSec - endSec
	end
	return false
end

---------------------------------------------------------------------
-- 将秒钟时间转换为时，分，秒
----------------------------------------------------------------------
function SecToTimeData(sec)
	local bj_time = UTCtoBeginTime(sec) --北京时间
	if bj_time < 0 then
		bj_time = bj_time +24*3600
	end
	local curTime = os.date("*t", bj_time)
	return curTime.hour,curTime.min,curTime.sec
end


---------------------------------------------------------------------
-- 返回指定时间与当前时间的间隔
--time ={ year = 2013, month = 1, day = 4, hour, min, sec }
----------------------------------------------------------------------
function getDeltaTime(time)
	local curTime = os.time()
	local theTime = os.time(time)
	return os.difftime(theTime, curTime)
end

-- 获取当天，某时刻的os.tiems
function curDataToTime(hour1,min1,sec1)
	
	local now       = os.time()
    local tm        = os.date("*t", now)
    tm.hour         = hour1
    tm.min          = min1
    tm.sec          = sec1
	
	return os.time(tm)
end

---------------------------------------------------------------------
-- -- 年月日装换为os.time时间
----------------------------------------------------------------------
function dataToTime(year,month,day)
	
	local now       = os.time()
    local tm        = os.date("*t", now)
	tm.year         = year
	tm.month        = month
	tm.day          = day
    tm.hour         = 0
    tm.min          = 0
    tm.sec          = 0
	
	return os.time(tm)
end
-- _time = 20140101
function dataToTime2(_time)
	
	local now       = os.time()
    local tm        = os.date("*t", now)
	tm.year         = _time/10000
	tm.month        = _time/100%100
	tm.hour         = _time%100
    tm.hour         = 0
    tm.min          = 0
    tm.sec          = 0
	
	return os.time(tm)
end

function strToTime( str_time )
	if not str_time then
		print("strToTime str_time nil")
		return nil
	end
	local t = {}
	for v in string.gmatch(str_time,"%d+") do
		i = tonumber(v)
		table.insert(t,i)
	end
	if #t < 3 or #t > 6 then
		print("strToTime param num error: "..#t)
		return nil
	else 
		local time = os.time{year=t[1],month=t[2],day=t[3],hour=t[4],min=t[5],sec=t[6]}
		if not time then 
			print("strToTime wrong str: "..str)
		end
		return time
	end
end