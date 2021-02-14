component = require("component")
thread = require("thread")
serial = require("serialization")
modem = component.modem

hashrates = {}
block = nil
jreq = nil
function explode(d,p)
  local t, lledit 
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
    modem.open(7000)
    local client, clientPort, msg
    
    if(timeout==nil) then _,_,client,_,_,clientPort,msg = event.pull("modem_message")
    else _,_,client,_,_,clientPort,msg = event.pull(timeout,"modem_message") end
    
    return client, clientPort, msg
end

thread.create( function()
    while true do
        local client,_,msg=listen()
        local parsed = explode("####",msg)
        
        if parsed[1]=="NJ" then
            block = serial.unserialize(parsed[2])
            jreq = client
            print("New job: #"..block.uuid.." at height "..block.height)
            modem.broadcast(9999,block.height .. block.timestamp .. block.previous .. block.transactions)
        elseif parsed[1]=="HR" then
            hashrates[client] = tonumber(parsed[2])
        elseif parsed[2]=="NF" then
            print("BLOCK MINED! Nonce="..parsed[2])
            block.nonce = parsed[2]
            modem.send(jreq,2000,"NEWBLOCK####"..serial.serialize(block))
        end
    end
end )

while true do
    local sum = 0
    for _,v in pairs(hashrates) do
        sum = sum + v
    end
    print("Total hashrate: "..sum.." H/s")
    os.sleep(5)
end