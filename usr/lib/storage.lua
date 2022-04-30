local storage = {}

component = require("component")
serial = require("serialization")
filesys = require("filesystem")
shell = require("shell")
term = require("term")
require("common")
storage.data = component.data
storage.disks = {}

local homereq = {["disks.txt"] = true, ["nodes.txt"] = "{}", ["contacts.txt"] = "{}", ["lb.txt"] = "error"}
local indexreq = {["index.txt"] = ""}
local walletreq = {["remutxo.txt"] = "", ["utxo.txt"] = "", ["walletremutxo.txt"] = "", ["walletutxo.txt"] = ""}

function getMount(addr)
	local f = filesys.mounts()
	for p,m in f do
		if p.address == addr then return m end
	end
end

function storage.reloadDisks()
	local df = io.open("disks.txt","r")
	if not df then return end
	local line = df:read()
	if not line then df:close() return end
	local arr = explode(",",line)
	storage.indexDisk = arr[2]
	line = df:read()
	if not line then df:close() return end
	arr = explode(",",line)
	storage.utxoDisk = arr[2]
	line = df:read()
	while line ~= nil do
		arr = explode(",",line)
		storage.disks[arr[1]] = arr[2]
		line = df:read()
	end
	df:close()
end

function storage.editDisks()
	local availDisks = {}
	for p, m in filesys.mounts() do
		if string.sub(m,1,4) == "/mnt" then
			availDisks[#availDisks+1] = {
				mount = m,
				size = p.spaceTotal(),
				used = p.spaceUsed(),
				label = p.getLabel(),
				addr = p.address,
				usage = 0,
				oldusage = 0,
				name = nil,
				i = math.huge
			}
		end
	end
	
	local diskr = io.open("disks.txt", "r")
	if diskr then
		local disks = {}
		repeat
			local d = diskr:read()
			if not d then break end
			local arr = explode(",",d)
			disks[#disks+1] = arr
		until not d or not string.find(d,",")
		for i,d in ipairs(disks) do
			for j,ad in ipairs(availDisks) do
				if d[2] == ad.addr then
					ad.i = i
					ad.usage = math.min(i,3)
					ad.oldusage = ad.usage
					ad.name = d[1]
				end
			end
		end
		diskr:close()
	end
	table.sort(availDisks,function(a,b) return a.i < b.i end)
	local tgpu = term.gpu()
	local seldisk = -1
	local function drawDisks()
		term.clear()
		tgpu.setForeground(0xFFFFFF)
		print("Disk editor")
		for i,j in ipairs(availDisks) do
			local ustring = " "
			tgpu.setForeground(0xFFFFFF)
			if j.usage == 1 then
				ustring = "I"
				tgpu.setForeground(0x00FF00)
			elseif j.usage == 2 then
				ustring = "W"
				tgpu.setForeground(0x00FFFF)
			elseif j.usage == 3 then
				ustring = "B"
				tgpu.setForeground(0xFFFF00)
			end
			print((seldisk == i and "*" or " ").."["..ustring.."] Disk "..tostring(i)..", size: "..tostring(j.size).." bytes, used: "..tostring(j.used).." bytes, free: "..tostring(j.size - j.used).." bytes, address: \""..j.addr.."\"")
		end
		tgpu.setForeground(0xFFFFFF)
	end
	local running = true
	local save = false
	while running do
		local d
		repeat
			drawDisks()
			print("Select disk to execute operation on, type q to quit or type s to save and quit: ")
			local o = string.sub(string.upper(term.read()),1,-2)
			if o == "Q" or o == "S" then 
				save = (o == "S")
				running = false 
			end
			d = tonumber(o)
		until (d and availDisks[d]) or not running
		if not running then break end
		seldisk = d
		drawDisks()
		print("Press U to unassign, I to assign as index disk, W to assign as wallet disk, B to assign as block disk and any other key to cancel")
		local o = string.sub(string.upper(term.read()),1,1)
		if o == "U" then
			availDisks[seldisk].usage = 0
		elseif o == "I" then
			for i,j in ipairs(availDisks) do
				if j.usage == 1 then
					j.usage = 3
				end
			end
			availDisks[seldisk].usage = 1
		elseif o == "W" then
			for i,j in ipairs(availDisks) do
				if j.usage == 2 then
					j.usage = 3
				end
			end
			availDisks[seldisk].usage = 2
		elseif o == "B" then
			availDisks[seldisk].usage = 3
		end
		seldisk = -1
	end
	if not save then return false end
	local oidisk
	local nidisk
	local owdisk
	local nwdisk
	local hasBlockDisk
	for i,j in ipairs(availDisks) do
		if j.oldusage == 1 then
			oidisk = j
		elseif j.oldusage == 2 then
			owdisk = j
		end
		if j.usage == 1 then
			nidisk = j
		elseif j.usage == 2 then
			nwdisk = j
		end
		if not hasBlockDisk and j.usage == 3 then
			hasBlockDisk = true
		end
	end
	if not nidisk then
		print("Missing index disk!")
	end
	if not nwdisk then
		print("Missing wallet disk!")
	end
	if not hasBlockDisk then
		print("Missing a block disk!")
	end
	if not (nidisk and nwdisk and hasBlockDisk) then
		print("Press any key to continue...")
		term.pull("key_down")
		return false
	end
	print("Moving data...")
	local tmpdir = os.tmpname().."/"
	filesys.makeDirectory(tmpdir.."oindex")
	filesys.makeDirectory(tmpdir.."owallet")
	filesys.makeDirectory(tmpdir.."nioblocks")
	filesys.makeDirectory(tmpdir.."nwoblocks")
	local niwasow = false
	if oidisk ~= nidisk and oidisk then
		shell.execute("mv -v "..getMount(oidisk.addr).."/* "..tmpdir.."oindex")
		if nidisk == owdisk then
			niwasow = true
			shell.execute("mv -v "..getMount(nidisk.addr).."/* "..tmpdir.."owallet")
		else
			shell.execute("mv -v "..getMount(nidisk.addr).."/* "..tmpdir.."nioblocks")
		end
		shell.execute("cp -rv "..tmpdir.."oindex/*".." "..getMount(nidisk.addr))
		shell.execute("cp -rv "..tmpdir..(niwasow and "owallet/*" or "nioblocks/*").." "..getMount(oidisk.addr))
	end
	if owdisk ~= nwdisk and owdisk then
		local towdisk = niwasow and oidisk or owdisk
		if not niwasow then
			shell.execute("mv -v "..getMount(towdisk.addr).."/* "..tmpdir.."owallet")
		end
		shell.execute("mv -v "..getMount(nwdisk.addr).."/* "..tmpdir.."nwoblocks")
		shell.execute("cp -rv "..tmpdir.."owallet/* "..getMount(nwdisk.addr))
		shell.execute("cp -rv "..tmpdir.."nwoblocks/* "..getMount(towdisk.addr))
	end
	print("Updating disks.txt...")
	local diskw = io.open("disks.txt","w")
	diskw:write((oidisk and oidisk.name or "0")..","..nidisk.addr.."\n")
	diskw:write((owdisk and owdisk.name or "1")..","..nwdisk.addr.."\n")
	local i = 2
	for _,j in ipairs(availDisks) do
		if j.usage == 3 then
			if j.oldusage == 1 then
				diskw:write((nidisk and nidisk.name or tostring(i))..","..j.addr.."\n")
			elseif j.oldusage == 2 then
				diskw:write((nwdisk and nwdisk.name or tostring(i))..","..j.addr.."\n")
			else
				diskw:write((j.name or tostring(i))..","..j.addr.."\n")
			end
		end
	end
	diskw:close()
	print("Reloading disk configuration...")
	storage.reloadDisks()
	return true
end

function storage.setup(force)
	local hometbc = {}
	local indextbc = {}
	local wallettbc = {}
	local disktxtexists = not force
	if not force then
		print("Detecting missing configuration files...")
		for n,v in pairs(homereq) do
			if not filesys.exists(shell.getWorkingDirectory().."/"..n) then
				hometbc[n] = n ~= "disks.txt" and v or nil
				print("Missing: "..n)
				if n == "disks.txt" then
					print("disks.txt does not exist! Marking all index and wallet disk files as missing...")
					indextbc = indexreq
					wallettbc = walletreq
					disktxtexists = false
				end
			end
		end
		if #indextbc == 0 then
			print("Detecting missing index disk files...")
			storage.reloadDisks()
			if not storage.indexDisk then 
				indextbc = indexreq
				print("No index disk definition found! Marking all files as missing...")
			else
				for n,v in pairs(indexreq) do
					if not filesys.exists(getMount(storage.indexDisk).."/"..n) then
						indextbc[n] = v
						print("Missing: "..n)
					end
				end
			end
			print("Detecting missing wallet disk files...")
			if not storage.utxoDisk then
				wallettbc = walletreq
				print("No wallet disk definition found! Marking all files as missing...")
			else
				for n,v in pairs(walletreq) do
					if not filesys.exists(getMount(storage.utxoDisk).."/"..n) then
						wallettbc[n] = v
						print("Missing: "..n)
					end
				end
			end
		end
	end
	if #hometbc == 0 and #indextbc == 0 and #wallettbc == 0 and disktxtexists and not force then return end
	if not disktxtexists then
		repeat 
			print("Opening disk editor...")
		until storage.editDisks() or force
	end
	if force then return end
	print("Creating files...")
	for i,j in pairs(hometbc) do
		local h = io.open(i,"w")
		h:write(j)
		h:close()
	end
	for i,j in pairs(indextbc) do
		local h = io.open(getMount(storage.indexDisk).."/"..i,"w")
		h:write(j)
		h:close()
	end
	for i,j in pairs(wallettbc) do
		local h = io.open(getMount(storage.utxoDisk).."/"..i,"w")
		h:write(j)
		h:close()
	end
end

if (storage.data==nil) then
    print("No data card present on device!")
end
storage.setup()
storage.reloadDisks()

function storage.generateIndex()
    local file = io.open(getMount(storage.indexDisk).."/index.txt","w")
    file:write("0000000000000000,00\n")
    file:close()
end

function storage.loadIndex(uuid)
    local file,err = assert(io.open(getMount(storage.indexDisk).."/index.txt","r"))
    if file==nil then print(err) end
	if not uuid then file:close() return nil end
	local arr
	local data
	repeat
		data = file:read()
		if not data then file:close() return nil end
		arr = explode(",",data)
	until (arr[1] == uuid)
    if arr[1]=="0000000000000000" then file:close() return nil end
    if arr[1]~=uuid then -- Solve conflict
        local aux = io.open(getMount(storage.indexDisk).."/conflicts/"..arr[1]..".txt","r")
        local line = aux:read()
        local ret = nil
        while line ~= nil do
            local tmp = explode(",",line)
            if tmp[1]==uuid then
                ret = line
                break
            end
            line = aux:read()
        end
        aux:close()
        file:close()
        return ret
    end
    file:close()
    return data
end

function storage.loadRawIndex(uuid)
    local file = io.open(getMount(storage.indexDisk).."/index.txt","r")
    
    local num = hexMod(tohex(storage.data.sha256(uuid)),150000)
	local data
    repeat
		data = file:read()
		if not data then file:close() return nil end
		arr = explode(",",data)
	until (arr[1] == uuid)
    file:close()
    return data
end

function storage.saveIndex(uuid,disk)
    local i = storage.loadRawIndex(uuid) or "0000000000000000"
    local arr = explode(",",i)
    if arr[1]~="0000000000000000" and arr[1]~=uuid then -- Solve conflict
        local file = io.open(getMount(storage.indexDisk).."/conflicts/"..arr[1]..".txt","a")
        file:write(uuid..","..disk.."\n")
        file:close()
    else
        local file = io.open(getMount(storage.indexDisk).."/index.txt","a")
        file:write(uuid..","..disk.."\n")
        file:close()
    end
end

function storage.loadBlock(uuid)
    local index = storage.loadIndex(uuid)
    if index==nil then return nil, "nonexistent index" end
	
    local data = explode(",",index)
    local disk = storage.disks[data[2]]
    if disk==nil then return nil, "invalid index" end
    local file = io.open(getMount(disk).."/"..uuid..".txt","r")
    local block = (serial.unserialize(file:read("*a")))
    file:close()
    return block
end

function storage.saveBlock(block)
    if storage.loadBlock(block.uuid) ~= nil then return end
    local data = serial.serialize(block)
    for k,d in pairs(storage.disks) do
        local hdd = component.proxy(component.get(d))
        if ( hdd.spaceTotal() - hdd.spaceUsed() >= data:len() ) then
            local file = io.open(getMount(d).."/"..(block.uuid)..".txt","w")
            file:write(data)
            file:close()
            storage.saveIndex(block.uuid,k)
            return
        end
    end
    error("[!] All disks are full, i'm unable to save block id ".. block.uuid)
    return nil
end

function storage.tmpsaveutxo(uuid,buuid) storage.saveutxo(uuid,buuid,true) end
function storage.saveutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","a")
	if file==nil then file=io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","w") end
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletutxo(uuid,buuid) storage.savewalletutxo(uuid,buuid,true) end
function storage.savewalletutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt","a")
	if file==nil then file=io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt","w") end
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsaveremutxo(uuid,buuid) storage.saveremutxo(uuid,buuid,true) end
function storage.saveremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","a")
	if file==nil then file=io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","w") end
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmpsavewalletremutxo(uuid,buuid) storage.savewalletremutxo(uuid,buuid,true) end
function storage.savewalletremutxo(uuid, buuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","a")
	if file==nil then file=io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","w") end
    file:write(uuid..","..buuid.."\n")
    file:close()
end

function storage.tmputxopresent(uuid) return storage.utxopresent(uuid,true) end
function storage.utxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end

    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
	if file==nil then return false end
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then file:close() return arr[2] end
        line = file:read()
    end
    file:close() return false
end

function storage.tmpremutxopresent(uuid) return storage.remutxopresent(uuid,true) end
function storage.remutxopresent(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
	if file==nil then return false end
    local line = file:read()
    while line ~= nil do
        local arr = explode(",",line)
        if arr[1]==uuid then file:close() return arr[2] end
        line = file:read()
    end
    file:close()
    return false
end

function storage.tmpremoveutxo(uuid) storage.removeutxo(uuid,true) end
function storage.removeutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt","r")
	if file==nil then return end

    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."utxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."utxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."utxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."utxo.txt")
end

function storage.tmpremovewalletutxo(uuid) storage.removewalletutxo(uuid,true) end
function storage.removewalletutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt","r")
	if file==nil then return end
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."walletutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."walletutxo.txt")
end

function storage.tmpremoveremutxo(uuid) storage.removeremutxo(uuid,true) end
function storage.removeremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt","r")
	if file==nil then return end
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."remutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."remutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."remutxo.txt")
end

function storage.tmpremovewalletremutxo(uuid) storage.removewalletremutxo(uuid,true) end
function storage.removewalletremutxo(uuid, tmp)
    local prefix = ""
    if tmp==true then prefix="tmp" end
    
    local file = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt","r")
	if file==nil then return end
    local newfile = io.open(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt","w")
    local line = file:read()
    while line ~= nil do
        if explode(",",line)[1]~=uuid then newfile:write(line.."\n") end
        line = file:read()
    end
    file:close()
    newfile:close()
    filesys.remove(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
    filesys.rename(getMount(storage.utxoDisk).."/"..prefix.."walletremutxo2.txt",getMount(storage.utxoDisk).."/"..prefix.."walletremutxo.txt")
end

function storage.discardtmputxo()
    filesys.remove(getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpremutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.consolidatetmputxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmputxo.txt",getMount(storage.utxoDisk).."/utxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpremutxo.txt",getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpremutxo.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpwalletutxo.txt",getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt",getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.cacheutxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/utxo.txt",getMount(storage.utxoDisk).."/utxo_cached.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo.txt",getMount(storage.utxoDisk).."/remutxo_cached.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo.txt",getMount(storage.utxoDisk).."/walletutxo_cached.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo_cached.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo.txt",getMount(storage.utxoDisk).."/walletremutxo_cached.txt")
end

function storage.restoreutxo()
    filesys.remove(getMount(storage.utxoDisk).."/utxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/utxo_cached.txt",getMount(storage.utxoDisk).."/utxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/remutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo_cached.txt",getMount(storage.utxoDisk).."/remutxo.txt")
    
    filesys.remove(getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo_cached.txt",getMount(storage.utxoDisk).."/walletutxo.txt")
    filesys.remove(getMount(storage.utxoDisk).."/walletremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo_cached.txt",getMount(storage.utxoDisk).."/walletremutxo.txt")
end

function storage.setuptmpenvutxo()
    local file = io.open(getMount(storage.utxoDisk).."/tmpwalletutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmpwalletremutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmputxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/tmpremutxo.txt","w")
    file:close()
end

function storage.setuptmpenvutxo_cache()
    filesys.copy(getMount(storage.utxoDisk).."/utxo_cached.txt",getMount(storage.utxoDisk).."/tmputxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/remutxo_cached.txt",getMount(storage.utxoDisk).."/tmpremutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletutxo_cached.txt",getMount(storage.utxoDisk).."/tmpwalletutxo.txt")
    filesys.copy(getMount(storage.utxoDisk).."/walletremutxo_cached.txt",getMount(storage.utxoDisk).."/tmpwalletremutxo.txt")
end

function storage.generateutxo()
    local file = io.open(getMount(storage.utxoDisk).."/utxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/remutxo.txt","w")
    file:close()
    
    file = io.open(getMount(storage.utxoDisk).."/walletutxo.txt","w")
    file:close()
    file = io.open(getMount(storage.utxoDisk).."/walletremutxo.txt","w")
    file:close()
end


return storage