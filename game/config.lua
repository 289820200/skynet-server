--------------------------------------------------------------------------------
-- 配置脚本
--	author: 张志锋
--------------------------------------------------------------------------------
return {
	-- 调试相关配置
	debug = {
		-- debug_console监听端口
		telnet_port = 8100,
		-- 显示客户端请求/服务器回复消息
		echo_message = true,
	},
	-- 日志等级
	log_level = 1,

	-- http服务器地址，用于和平台通讯
	http = {
		host = "0.0.0.0",
		port = 9528,
	},


	-- 账号中心数据库
	account_center_redis = {
		host = "127.0.0.1",
		port = 6380,
		auth = "test",
		db = 0, --默认使用0号数据库
		--一个数据库连接最多同时接受的请求数，超过请求数后将新建连接
		maxrequest = 10,
		--跟数据库的最大连接数，超过后将不再建立新连接
		maxconnect = 100,
		--默认的数据库连接数
		defaultconnect = 1,
	},

	-- redis数据库配置
	game_redis = {
		host = "127.0.0.1",
		port = 6379,
		--auth = "test",
		db = 0, --默认使用0号数据库
		--一个数据库连接最多同时接受的请求数，超过请求数后将新建连接
		maxrequest = 10,
		--跟数据库的最大连接数，超过后将不再建立新连接
		maxconnect = 100,
		--默认的数据库连接数
		defaultconnect = 1,
	},

	-- 监听服务配置
	gate = {
		-- ip+端口
		address = "0.0.0.0",
		port = 8888,
		-- 最大客户端连接数
		maxclient = 4096,
		servername = "game",
	},
}
