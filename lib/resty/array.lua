local basearray_setup = require("resty.basearray").setup
local object = require("resty.object")
local select = select
local table_new, clone
if ngx then
  table_new = table.new
  clone = require("table.clone")
else
  local pairs = pairs
  table_new = function(narray, nhash)
    return {}
  end
  clone = function(self)
    local copy = {}
    for key, value in pairs(self) do
      copy[key] = value
    end
    return copy
  end
end

local array = setmetatable({}, { __call = object.__call, __tostring = getmetatable(object).__call })
basearray_setup(array)
array.__call = object.__call
array.__tostring = object.__tostring
array.__name__ = 'array'
array.__index = array
array.__bases__ = { object }
array.__mro__ = { array, object }

function array.equals(self, o)
  if type(o) ~= 'table' or #o ~= #self then
    return false
  end
  for i = 1, #self do
    if self[i] ~= o[i] then
      local tt, ot = type(self[i]), type(o[i])
      if tt ~= ot then
        return false
      elseif tt ~= 'table' then
        return false
      elseif not array.equals(self[i], o[i]) then
        return false
      end
    end
  end
  return true
end

-- {1,2} == {1,2}, {1,{2}} == {1,{2}}
array.__eq = array.equals

function array.new(cls)
  return setmetatable({}, cls)
end

function array.init(self, ...)
  for i = 1, select("#", ...) do
    local a = select(i, ...)
    for j = 1, #a do
      self[#self + 1] = a[j]
    end
  end
  return self
end

function array.entries(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = { i, self[i] }
  end
  return res
end

function array.keys(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = i
  end
  return res
end

function array.values(self)
  return setmetatable(clone(self), array)
end

return array
