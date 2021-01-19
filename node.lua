local component = require("component")
local serial = require("serialization")
local net = require("netcraftAPI")

local modem = component.modem
local data = component.data

function explode(d,p)
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

function tableHas(t,elem)
	for _,e in pairs(t) do
		if e == elem then return true end
	end
	return false
end

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

function createBlock()
	local r = {}
	r["id"]=-1
	r["uuid"]=""
	r["transactions"]={}
	r["sol"]=0
	r["previous"]=-1
	return r
end

function getBlock(id,trans,sol,prev)
	local r = {}
	r["id"]=id
	r["transactions"]=trans
	r["sol"]=sol
	r["previous"]=prev
	return r
end

function findBlock(uuid,chain)
	for _,b in pairs(chain) do
		if b.uuid == uuid then return b end
	end
	return nil
end

function findTransaction(t,tr)
	for _,b in pairs(t) do
		if b == tr then return b end
	end
	return nil
end

function clearPool(t)
	for p,b in pairs(chain) do
		if os.uptime() - tonumber(b[1]) > 20000 then
			table.remove(t,b[2])
		end
	end
end

function verifyBlock(data, block,chain, difficulty)
	-- Verify that height is correct & previous block exists
	local p = findBlock(block.previous,chain)
	if p==nil then return false end
	if p.id+1 ~= block.id then return false end
	
	-- Verify if proof-of-work is correct
	if tonumber((data.sha256(block.sol .. serial.serialize(p))):tohex(),16) >= difficulty then return false end
	
	-- Verify if each transaction in the block is correct
	for _,tr in pairs(block.transactions) do
		if ~verifyTransaction(data,tr,updateUnusedFromZero(block,chain)) then return false end
	end
	
	return true
end

function isUnused(tr,unused)
	for _,s in pairs(unused) do
		if s.id == tr.id then return true end
	end
	return false
end

function verifyTransaction(data,tr,unused)
	-- First, check if digital signature is correct
	if ~data.ecdsa(tr.id .. tr.from .. tr.to .. tr.qty .. serial.serialize(tr.sources),tr.from,tr.sig) then return false end
	
	-- Now, check if sources are correct & user has enough money
	sum = 0
	for _,s in pairs(tr.sources) do
		if s.to ~= tr.from && s.from ~= tr.from then return false end
		if ~isUnused(tr,unused) then return false end
		
		if s.to == tr.from then sum = sum + s.qty
		else sum = sum + s.remainder end
	end
	
	if (sum-tr.qty-tr.remainder)~= 0 then return false end
	
	return true
end

function loadBlocks(file)
	local t = serial.unserialize(file:read())
	sortChain(t)
	local num = t[#t].uuid
	file:close()
	return t,num
end

function saveBlocks(t,file)
	file:write(serial.serialize(t))
	file:close()
end

function sortChain(blockchain) -- Sorts the blockchain by id
	table.sort(blockchain,function (a,b) return a.id < b.id end)
end

function loadNodes(file)
	local t = serial.unserialize(file:read())
	file:close()
	return t
end

function saveNodes(t,file)
	file:write(serial.serialize(t))
	file:close()
end

function loadUnused(file)
	t = serial.unserialize(file:read())
	file:close()
	return t
end

function saveUnused(t,file)
	file:write(serial.serialize(t))
	file:close()
end

function updateUnused(block,unused)
	for _,tr in pairs(block.transactions) do
		for _,un in pairs(tr.sources) do
			table.remove(unused,un)
		end
		table.insert(unused,tr)
	end
end

function updateUnusedFromZero(block,chain)
	local unused = {}
	local usedIds = {}
	
	local currB = block
	while(currB.previous ~= nil) do
		for _,t in pairs(currB.transactions) do
			for _,source in pairs(t.sources) do
				table.insert(usedIds,source.uuid)
			end
			if ~tableHas(usedIds,t.uuid) then
				table.insert(unused,t)
			end
		end
		
		currB = findBlock(currB.previous,chain)
	end
	return unused
end

function broadcast(nodes,msg) -- Broadcasts message MSG to all nodes in NODES
	for _,node in pairs(node) do
		local arr = explode(",",arr)
		local sock = net.connect(modem,arr[0])
		net.send(sock,msg,6654)
		sock.close()
	end
end

local nodes = io.open("nodes.txt","r")
local blockchain = io.open("block.txt","r")
local unused = io.open("unused.txt","r")
local srv = net.server(modem,6654)



local list = {} -- List of known nodes
local blocks = {} -- List of known blocks
local transactions = {} -- List of new transactions received
local unusedTransactions = {} -- List of known unused transactions (Keep updated with the current blockchain!)
local difficulty = 0 -- Net difficulty
local last = 0
local numblocks = 0
local lastTimeStamp = 0
local conflict = false


blocks,last = loadBlocks(blockchain)
numblocks = #blocks
list = loadNodes(nodes)
unusedTransactions = loadUnused(unused)

-- Update our blockchain

flag = false
flag2 = false

newblocks = {}

for _,c in pairs(list) do
	local sock = net.connect(modem,c,6654)
	if sock ~= nil then
		net.send(sock,"GET_CHAIN_FROM_NUM,"..numblocks,6654)
		local msg = srv.listen(2000)
		if msg == "--START--" then 
			while msg ~= "--END--" and ~flag2 do
				msg = srv.listen(2000)
				if (msg==nil) then flag2 = true
				elseif (msg ~="--END--") then table.insert(newblocks,serial.unserialize(msg)) end
			end
			if flag2 then for k in pairs(newblocks) do newblocks[k]=nil end
			else
				flag = true
				for _,b in pairs(newblocks) do table.insert(blocks,b) end
				for k in pairs(newblocks) do newblocks[k]=nil end
			end
		end
	end
	if flag then break end
end

-- Get the current network difficulty

flag = false

for _,c in pairs(list) do
	local sock = net.connect(modem,c,6654)
	if sock ~= nil then
		net.send(sock,"GETDIFFICULTY",6654)
		local msg = srv.listen(2000)
		if msg ~= nil then 
			difficulty = tonumber(msg[2])
			flag = true
		end
	end
	if flag then break end
end

-- Get last block timestamp

flag = false

for _,c in pairs(list) do
	local sock = net.connect(modem,c,6654)
	if sock ~= nil then
		net.send(sock,"GETLASTTIMESTAMP",6654)
		local msg = srv.listen(2000)
		if msg ~= nil then 
			lastTimeStamp = tonumber(msg[2])
			flag = true
		end
	end
	if flag then break end
end

while true do -- Main loop
	local msg = srv.listen()
	local arr = explode(",",msg[2])
	local ip = msg[1]
	if arr[1]=="NEWBLOCK" then -- We should keep this!
		local blocknew = serial.unserialize(arr[2])
		if verifyBlock(data,blocknew,blocks,difficulty) then
			if blocknew.id == last+1 then -- New block in the chain points to my previous block, all correct
				table.insert(blocks,blocknew)
				print("Adding new block id " .. blocknew.uuid .. "!")
				if (~conflict) unused = updateUnused(blocknew,unused)
				else 
					unused = updateUnusedFromZero(blocknew,blocks)
					conflict = false
				end
				last = last + 1
				saveBlocks(blocks,io.open("block.txt","w"))
			else -- We will save this block, but its transactions will be ignored
				table.insert(blocks,blocknew)
				print("Adding orphan block id " .. blocknew.uuid .. " at height" .. blocknew.id)
				conflict = true -- Ensure that we reload unused transactions after the conflict is done
			end
		else
			print("INFO: Rejecting block id " .. serial.unserialize(arr[2]).id)
		end
	elseif arr[1]=="NEWTRANSACT" then -- We should give this to miners! Propagate the message!
		clearPool(transactions)
		local tr = serial.unserialize(arr[2])
		if findTransaction(transactions,tr)==nil then
			if verifyTransaction(data,tr,unusedTransactions) then
				table.insert(transactions,{os.uptime(),tr}
				broadcast(list,msg))
			end
		end
	elseif arr[1]=="NEWNODE" then -- We should keep this & propagate the message!
		if ~tableHas(list,arr[2]) then
			table.insert(list,arr[2])
			saveNodes(list,io.open("nodes.txt"))
			broadcast(list,msg)
		end
	elseif arr[1]=="GETCHAINSIZE" then
		local sock = net.connect(modem,arr[2],6654)
		sock.send(last,6654)
		sock.close()
	elseif arr[1]=="GETBLOCK" then -- GETBLOCK,uuid
		local p = findBlock(arr[2],blocks)
		if (p ~= nil) then
			local sock = net.connect(modem,ip,6654)
			net.send(sock,serial.serialize(p),6654)
			net.close(sock)
		end
	elseif arr[1]=="GET_CHAIN" then -- We send our entire blockchain, block by block. We mark the end by sending "--END--".
		local sock = net.connect(modem,ip,6654)
		for _,b in pairs(blocks) do
			net.send(sock,serial.serialize(b),6654)
		end
		net.send(sock,"--END--")
		net.close(sock)
	elseif arr[1]=="GET_CHAIN_FROM_NUM" then -- GET_CHAIN_FROM_NUM,start
		local sock = net.connect(modem,ip,6654)
		net.send(sock,"--START--",6654)
		for k=tonumber(arr[2]),#blocks do
			net.send(sock,serial.serialize(blocks[k]),6654)
		end
		net.send(sock,"--END--")
		net.close(sock)
	elseif arr[1]=="GETDIFFICULTY" then
		local sock = net.connect(modem,arr[2],6654)
		net.send(sock,difficulty,6654)
		net.close(sock)
	elseif arr[1]=="GETLASTTIMESTAMP" then
		local sock = net.connect(modem,arr[2],6654)
		net.send(sock,lastTimeStamp,6654)
		net.close(sock)
	end
end