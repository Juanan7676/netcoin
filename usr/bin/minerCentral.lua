component = require("component")
thread = require("thread")
serial = require("serialization")
event = require("event")
modem = component.proxy(component.get(""))
modem2 = component.proxy(component.get(""))
modem.open(7000)
modem2.open(7000)

hashrates = {}
block = nil
jreq = nil
function explode(d,p)
  local t, ll, l
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

function listen(timeout)
    local client, msg
    
    if(timeout==nil) then _,_,client,_,_,msg = event.pull("modem_message")
    else _,_,client,_,_,msg = event.pull(timeout,"modem_message") end
    
    return client, msg
end

function listentonode(c,timeout)
    local client, msg
    
    if(timeout==nil) then _,_,client,_,_,_,msg = event.pull("modem_message",nil,c)
    else _,_,client,_,_,_,msg = event.pull(timeout,"modem_message",nil,c) end
    
    return client, msg
end

thread.create( function()
    while true do
        local client,msg=listen()
        if msg~=nil then
            local parsed = explode("####",msg)
            if parsed[1]=="NJ" then
                block = serial.unserialize(parsed[2])
                jreq = client
                print("New job: #"..block.uuid.." at height "..block.height.." difficulty "..(2^240/block.target))
                modem2.broadcast(7000,block.height .. block.timestamp .. block.previous .. block.transactions, block.target)
            elseif parsed[1]=="HR" then
                hashrates[client] = tonumber(parsed[2])
            elseif parsed[1]=="NF" then
                print("BLOCK MINED! Nonce="..parsed[2])
                block.nonce = parsed[2]
                modem.send(jreq,2000,7000,"NEWBLOCK####"..serial.serialize(block))
                local _,tmp = listentonode(jreq,2)
                if tmp==nil then print("Warning: no response from node")
                elseif tmp=="BLOCK_ACCEPTED" then print("Block accepted")
                else print("Block rejected by node: got " .. tmp) end
            end
        end
    end
end )

while true do
    if block ~= nil then modem2.broadcast(7000,block.height .. block.timestamp .. block.previous .. block.transactions, block.target) end
    local sum = 0
    for k,v in pairs(hashrates) do
        sum = sum + v
        hashrates[k] = nil
    end
    print("Total hashrate: "..sum.." H/s")
    os.sleep(10)
end