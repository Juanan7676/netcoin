-- NetCraft API by Juanan76
local event = require("event")

local net = {}

function net.send(modem,client,port,rport,msg)
    modem.send(client,port,rport,msg)
end

function net.listen(modem, port, timeout)
    modem.open(port)
    local client, clientPort, msg
    
    if(timeout==nil) then _,_,client,_,_,clientPort,msg = event.pull("modem_message")
    else _,_,client,_,_,clientPort,msg = event.pull(timeout,"modem_message") end
    
    return client, clientPort, msg
end

function net.listentoclient(modem, port, client, timeout)
    modem.open(port)
    local client, clientPort, msg
    
    if(timeout==nil) then _,_,client,_,_,clientPort,msg = event.pull("modem_message",nil,client)
    else _,_,client,_,_,clientPort,msg = event.pull(timeout,"modem_message",nil,client) end
    return client, clientPort, msg
end

function net.server(modem,port)
	local t = {}
	t.listen = function(timeout)
		return net.listen(modem,port,timeout)
	end
	return t
end
function net.connect(modem,addr,port)
	return node --Yes this works!
end

return net