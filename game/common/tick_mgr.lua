--------------------------------------------------------------------------
-- Desc:    tick管理器
-- Author:  
-- Date:    2010.7.07
-- Last:
-- Copyright (c) 2010 QUWAN Entertainment All right reserved.
--------------------------------------------------------------------------
local ms = require "ms"

local os = os
local type = type
local debug = debug
local pairs = pairs
local pcall = pcall
local print = print
local table = table
local assert = assert
local unpack = unpack
local next = next
local deb = deb

module "base.tick_mgr"

--------------------------------------------------------------------------
-- 所有tick列表
local tickList = {}
-- 所有的闹钟
local clockList = {}
--------------------------------------------------------------------------
-- 处理函数，由MmainFrame调用
--------------------------------------------------------------------------
function process(passtime, tickTime)
    -- 待移除tick列表
    local tick = tickTime*1000
    local removeLst = {}
    for holder, ticks in pairs(tickList) do
        for routine, info in pairs(ticks) do
            if tick >= info.next_time then
                -- routine返回false则表示此tick不需要再执行
                if not info.calling then
                    info.calling = true

                    local tickLast = os.clock()
                    local callRet, result = false
                    if holder == "_G" then
                        callRet, result = pcall(routine, unpack(info.arg))
                    else
                        callRet, result = pcall(routine, holder, unpack(info.arg))
                    end

                    local tickNow = os.clock()

                    if tickNow - tickLast > 1 then
                        local debug_info = debug.getinfo(routine)
                        ms.log.must("tick调用时间过长：%fs，routine=%s:%d\n", tickNow - tickLast,
                            debug_info.source,
                            debug_info.linedefined
                        )
                    end

                    if callRet then
                        if result then
                            --info.next_time = tickTime - (tickTime % info.wait_time) + info.wait_time
                            info.next_time = info.next_time + info.wait_time
                        else
                            table.insert(removeLst, { holder, routine })                    
                        end
                    else
                        -- 调用tick函数出错（lua报错）时，不删除这个tick
                        --  同时打印报错信息
                        local debug_info = debug.getinfo(routine)
                        ms.log.error("调用tick失败：wait_time=%d，routine=%s:%d\n%s",
                            info.wait_time,
                            debug_info.source,
                            debug_info.linedefined,
                            result
                        )
                        -- 下次继续调用
                        info.next_time = info.next_time + info.wait_time
                    end
                    info.calling = false
                else
                    local debug_info = debug.getinfo(routine)
                    ms.log.error("重复调用tick，忽略本次调用：wait_time=%d，routine=%s:%d",
                        info.wait_time,
                        debug_info.source,
                        debug_info.linedefined
                    )
                end
            end
        end
    end

    -- 删除不再需要执行的tick
    for _, info in pairs(removeLst) do
        local holder  = info[1]
        local routine = info[2]
        -- 如果removeLst里的tick信息里的下次触发时间在当前时间之前，则删除这个tick
        -- 否则不能删除（在routine里新注册的tick）
        if tickList[holder] and
            tickList[holder][routine] and
            tickList[holder][routine].next_time <= tickTime then

            tickList[holder][routine] = nil
        end
    end
	
	--//-----------闹钟--------------------------------
	 for hour, ticks in pairs(clockList) do
        for min, info in pairs(ticks) do
			if tick >= info.next_time then
				if not info.calling then
                    info.calling = true
					clockCallBack(hour,min,info.callBack)
                    -- 更新下次时间
                    info.next_time = info.next_time + info.wait_time
                    info.calling = false
                end
			end
		end
		
		-- 清除空的记录
		if next(ticks) == nil then
			clockList[hour] = nil
		end
		
	end
	
    return true
end
--------------------------------------------------------------------------
-- 注册tick 时间以毫秒为单位
--  start_time          等待多少毫秒后第一次调用routine（传nil则等待wait_time秒）
--  wait_time           每次调用routine的等待时间
--  holder_or_routine   routine的属主类或单个的函数（非class成员函数）
--  routine             调用的函数
--  ...                 传给routine的参数
--  示例：
--
--  类方法的注册：
--      function class:registerTick()
--          ms.tick_mgr.register(nil, 3000, self, self.tick, 1, 2, 3)
--      end
--      function class:tick(p1, p2, p3)
--          -- p1 = 1, p2 = 2, p3 = 3 ...
--      end
--
--  独立函数的注册：
--      function tick(p1, p2, p3)
--          -- p1 = 1, p2 = 2, p3 = 3 ...
--      end
--      ms.tick_mgr.register(nil, 3000, tick, 1, 2, 3)
--------------------------------------------------------------------------
function register(start_time, wait_time, holder_or_routine, routine, ...)
    local holder, args
    if type(holder_or_routine) == "function" then
        holder = "_G"
        args = { routine, ... }
        routine = holder_or_routine
    else
        holder = holder_or_routine
        args = { ... }
    end

    tickList[holder] = tickList[holder] or {}
    local tickInfo = {
        calling = false,
        wait_time = wait_time,
        next_time = ms.mainFrame.nowTick + (start_time and start_time or wait_time),
        arg = args,
    }
    tickList[holder][routine] = tickInfo

    --ms.stat_mgr.add("系统 - 注册一个tick")
end
--------------------------------------------------------------------------
-- 注销tick
--------------------------------------------------------------------------
function unregister(holder_or_routine, routine)
    local holder
    if type(holder_or_routine) == "function" then
        holder = "_G"
        routine = holder_or_routine
    else
        holder = holder_or_routine
    end

    local routines = tickList[holder or "_G"]
    if not routines then
        return false
    end

    if holder == "_G" and not routine then
        ms.log.error("unregister error")
        return false
    end

    -- 没有传入routine（没指定删那个tick），则把holder注册的所有tick删掉
    if not routine then
        tickList[holder] = nil
        return true
    end

    routines[routine] = nil

   -- ms.stat_mgr.add("系统 - 注销一个tick")

    return true
end

--------------------------------------------------------------------------
-- 清空所有tick
--------------------------------------------------------------------------
function unregisterAll()
    tickList = {}
end

--------------------------------------------------------------------------
-- 注册指定每天固定时间执行的tick
--------------------------------------------------------------------------
function registerDay(hour, minute, second, holder_or_routine, routine, ...)
    local nextDayTime, deltaTime = ms.time_mgr.nextDayTime(hour, minute, second)

    ms.tick_mgr.register(deltaTime * 1000,  -- 调用一次tick等待时间
        ms.time_mgr.dayToSecond(1) * 1000,  -- 间隔时间（一天）
        holder_or_routine,
        routine,
        ...
    )
end
--------------------------------------------------------------------------
-- 注册指定每周固定时间执行的tick
--------------------------------------------------------------------------
function registerWeek(wday, hour, minute, second, holder_or_routine, routine, ...)
    local nextWeekTime, deltaTime = ms.time_mgr.nextWeekTime(wday, hour, minute, second)

    ms.tick_mgr.register(deltaTime * 1000,  -- 调用一次tick等待时间
        ms.time_mgr.dayToSecond(7) * 1000,  -- 间隔时间（一周）
        holder_or_routine,
        routine,
        ...
    )
end

--------------------------------------------------------------------------
-- 注册指定时间执行的tick
--------------------------------------------------------------------------
function registerDate(year, month, wday, hour, minute, second, holder_or_routine, routine, ...)
	local time = {}
	time.year = year
	time.month = month
	time.day = wday
	time.min = minute
	time.hour = hour
	time.sec = second
    local deltaTime = ms.time_mgr.getDeltaTime(time)

    ms.tick_mgr.register(deltaTime * 1000,  -- 调用一次tick等待时间
    	0,
        holder_or_routine,
        routine,
        ...
    )
end

------------------------------------------------------
--	闹钟（可一次注册多个,有效精度为分钟）
------------------------------------------------------
-- 统一的回调--
function clockCallBack(hour,min,callBack)
	--print("现在时间:",hour,min)
	for i = #callBack,1, -1 do
		local holder  = callBack[i].obj
		local routine = callBack[i].callBackFun
		
		local tickLast = os.clock()
		local callRet, result = false
		if holder == "_G" then
			callRet, result = pcall(routine,hour,min)
		else
			callRet, result = pcall(routine, holder, hour,min)
		end

		local tickNow = os.clock()

		if tickNow - tickLast > 1 then
			local debug_info = debug.getinfo(routine)
			ms.log.must("tick调用时间过长：%fs，routine=%s:%d\n", tickNow - tickLast,
				debug_info.source,
				debug_info.linedefined
			)
		end

		if callRet then
			if not result then
                -- 删除不需要再继续的闹钟事件
				table.remove(callBack, i)
			end
		else
			-- 调用tick函数出错（lua报错）时，不删除这个tick
			--  同时打印报错信息
			local debug_info = debug.getinfo(routine)
			ms.log.error("调用tick失败：routine=%s:%d\n%s",
				debug_info.source,
				debug_info.linedefined,
				result
			)
		end
	end
	-- 检测闹钟事件
	if #callBack == 0 then
		clockList[hour][min] = nil
	end

	return true
end
-- 注册闹钟--
--  times 闹钟时间数据， 格式：times = { [1]= {hour = -1,min = -1,}}
--  闹钟事件回调的返回值为false，表明不需要再继续
function registerClockList(times,holder_or_routine, routine)
	for index, v in pairs(times or {}) do
		if not v.hour or not v.min then
			ms.log.error("times == nil")
			return
		end
		
		local hour = v.hour
		local min  = v.min
		
		--timeList[hour] = timeList[hour] or {[min] = {},}
		clockList[hour] = clockList[hour] or {}
		if not clockList[hour][min] then
			-- 应为实际时间与心跳会有一定误差，5秒为补偿值
			local nextDayTime, deltaTime = ms.time_mgr.nextDayTime(hour, min, 5)
			local _clock = {
			calling = false,
			next_time = deltaTime*1000,
			wait_time = ms.time_mgr.dayToSecond(1) * 1000,
			callBack = {},
			}
			clockList[hour][min] = _clock
		end
		
		local data  = {obj = nil,callBackFun = nil}
		if type(holder_or_routine) == "function" then
			data.obj = "_G"
			data.callBackFun = holder_or_routine
		else
			data.obj = holder_or_routine
			data.callBackFun = routine
		end
		
		-- 检查重复
		local result = false
		for i,v in pairs(clockList[hour][min].callBack) do
			if v.obj == data.obj then
				if v.callBackFun == data.callBackFun then
					-- 已经添加过
					result = true
					break
				end
			end
		end
		
		print("闹钟时间：",hour,min)
		
		if not result then
			table.insert(clockList[hour][min].callBack,data)
		end
	end

end
-- 删除闹钟事件
function delClockList(hour,min,holder_or_routine, routine)
	if not clockList[hour] then
		return
	end
	
	if not clockList[hour][min] then
		return
	end
	
	local data  = {obj = nil,callBackFun = nil}
	if type(holder_or_routine) == "function" then
		data.obj = "_G"
		data.callBackFun = holder_or_routine
	else
		data.obj = holder_or_routine
		data.callBackFun = routine
	end
	local callBack = clockList[hour][min].callBack or {}
	for i,v in pairs(callBack) do
		if v.obj == data.obj then
			if v.callBackFun == data.callBackFun then
				-- 删除该心跳
				table.remove(callBack,i)
				break
			end
		end
	end
	
	if #callBack == 0 then
		clockList[hour][min] = nil
	end
	
end
