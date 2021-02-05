local nodenet = require("nodenet")
require("protocol")
local thread = require("thread")
local napi = require("netcraftAPI")
local component = require("component")

cache.loadNodes()

thread.create(function()
    local sv = napi.server(component.modem,2000)
    while true do
        nodenet.dispatchNetwork(sv)
    end
end)

io.read()