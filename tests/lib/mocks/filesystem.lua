local fs = {}

fs.mock = {}
fs.mock.availableFiles = {}
fs.mock.addFile = function(filename)
    fs.mock.availableFiles[filename]=true
end

fs.exists = function (filename)
    if fs.mock.availableFiles[filename] then
        return true
    else
        return false
    end
end

return fs