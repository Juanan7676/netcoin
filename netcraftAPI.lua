-- NetCraft API by Juanan76

local net = {}

function explode(p,d)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+#d -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function net.server(modem,port)
  modem.open(port)
  return {listen = function(timeout)
      if (timeout==nil) then _,_,_,_,_,msg = require("event").pull("modem_message")
      else _,_,_,_,_,msg = require("event").pull(timeout,"modem_message") end
	  if msg == nil then return nil end
      return explode(msg,"!") -- { ip,msg,responsePort }
    end
  }
end

function net.connect(modem,ip,port)
  modem.broadcast(9999,"CONNECT~~"..ip.."~~"..port)
  -- As we don't know the address of the router, we broadcast a msg on the port 9999, which is by convention
  -- the port on which routers communicate with clients on handshake.
  modem.open(9999)
  local ret,_,_,_,_,msg = require("event").pull(2,"modem_message",nil,nil,9999) -- Router responds: <port> on success, nil on fail
  if ret == nil then return false end
  if msg == "nil" then return false
  else return {ip,msg,modem} end
end

function net.send(socket,msg,responsePort)
  socket[3].broadcast(socket[2],msg .. "!" .. responsePort)
end

function net.close(socket)
  socket[3].broadcast(9999,"CLOSE~~"..socket[2])
end

return net