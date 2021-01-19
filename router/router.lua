-- Router code API

local function explode(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

---------------------

component = require("component")

modem1 = component.proxy("ADDRESS1")
modem2 = component.proxy("ADDRESS2")
event = require("event")

map = io.open("map.txt","r")
connections = {}
mappings = {}
last = 1

line = map:read()
while line~=nil do
	local arr = explode(line,",")
	table.insert(mappings,{{arr[1],arr[2]},{arr[3],arr[4]},{arr[5],arr[6]},{arr[7],arr[8]},arr[9],arr[10]})
	line = map:read()
end

local function newConnection(ip,user,port)
	local arr = explode(ip,".")
	for _,mapping in pairs(mappings) do
		if arr[1] >= mapping[1][1] and arr[1] <= mapping[1][2] and arr[2] >= mapping[2][1] and arr[2] <= mapping[2][2] and
		   arr[3] >= mapping[3][1] and arr[3] <= mapping[3][2] and arr[4] >= mapping[4][1] and arr[4] <= mapping[4][2] then
		    last = last + 1
		    table.insert(connections,{last,ip,port,mapping[5],mapping[6]})
			modem.open(last)
			return {last,ip,port,mapping[5],mapping[6]}
		end
	end
	return false
end

local function connExists(port)
	for k,p in pairs(connections) do
		if p[1]==port then return k end
	end
	return false
end

modem1.open(9999)
modem2.open(9999)

while true do
	local _,recv,port,_,msg = event.pull("modem_message") -- Router responds: <port> on success, nil on fail
	local index = connExists(port)
	if port ~= 9999 and index~= false then
		if connections[index][5]==false then modem2.send(connections[index][5],9999,"DELIVER,"..port..","..msg)
		else 
			modem2.send(connections[index][5],9999,"FORWARD,".. connections[index][2]..",".. port..","..msg)
		end
	else
		local arr = explode(msg,",")
		if arr[1]=="CONNECT" then
			local result = newConnection(arr[2],recv,arr[3])
			if result ~= false then modem2.send(recv,9999,result[3]) end
		elseif arr[1]=="DELIVER" then
			modem2.broadcast(arr[2],arr[3])
		elseif arr[1]=="FORWARD" then
			local ip = explode(".",arr[2])
			for _,mapping in pairs(mappings) do
				if ip[1] >= mapping[1][1] and ip[1] <= mapping[1][2] and ip[2] >= mapping[2][1] and ip[2] <= mapping[2][2] and
				   ip[3] >= mapping[3][1] and ip[3] <= mapping[3][2] and ip[4] >= mapping[4][1] and ip[4] <= mapping[4][2] then
					    if mapping[6]==false then modem2.send(mapping[5],9999,"DELIVER,"..arr[3]..","..arr[4])
						else modem2.send(mapping[5],9999,"FORWARD,"..arr[2]..","..arr[3]..","..arr[4]) end
				end
			end
		end
	end
end