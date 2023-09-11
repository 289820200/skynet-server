-- module proto as examples/proto.lua
package.path = "./game/?.lua;" .. package.path

local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local proto = require "proto.proto"

skynet.start(function()
	sprotoloader.save(proto.c2s, 1)
	-- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
