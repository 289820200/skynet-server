package.path = "./game/?.lua;"..package.path
local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local sharedata = require "skynet.sharedata"
local httpc = require "http.httpc"
local table = table
local string = string

local config = require "config"
local packer = require "db.packer"

local mode = ...

if mode == "agent" then

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end
 
local settings
local srv_id 
skynet.init(function() 
	settings = sharedata.query("settings_data")
	srv_id = skynet.getenv "srv_id"  --settings.srv_id_config[1].srv_id
end)

skynet.start(function()
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)
		-- limit request body size to 8192 (you can pass nil to unlimit)
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		if code then
			if code ~= 200 then
				response(id, code)
			else
				local ret = {}
				local path, query = urllib.parse(url)

				if query then
					-- get 参数
					local q = urllib.parse_query(query) -- k v 
					if path == '/order' then 
						print("order")
						local tmp = skynet.call(".recharge","lua","order",q)
						ret.status = tmp and 1 or 0
						ret.order = tmp.order						
					elseif path == '/payback' then
						print("payback",query)
						local req_host = header.host
						-- TODO verify host

						local ok = skynet.call(".recharge","lua","payback",q)
						ret.status = ok and 1 or 0
					elseif path == '/gm_command' then
						local req_host = header.host
						-- TODO verify host
						local ok,msg = skynet.call(".gm_command","lua","command",q)
						ret.status = ok and 1 or 0
						ret.msg = msg
					end
				end

				local str = packer.pack(ret)
				print(str)
				response(id, code, str)
			end
		else
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)

else



skynet.start(function()
	local agent = {}
	for i= 1, 8 do
		agent[i] = skynet.newservice(SERVICE_NAME, "agent")
	end
	local balance = 1
	local id = socket.listen(config.http.host, config.http.port)
	skynet.error("Listen web port "..config.http.port)
	socket.start(id , function(id, addr)
		-- skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)

end