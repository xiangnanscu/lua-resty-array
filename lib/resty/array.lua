local basearray_setup = require("resty.basearray").setup
local table_concat = table.concat
local table_remove = table.remove
local table_insert = table.insert
local table_sort = table.sort
local select = select
local error = error
local table_new, table_clear, clone
if ngx then
  table_clear = table.clear
  table_new = table.new
  clone = require("table.clone")
else
  local pairs = pairs
  table_new = function(narray, nhash)
    return {}
  end
  table_clear = function(self)
    for key, _ in pairs(self) do
      self[key] = nil
    end
  end
  clone = function(self)
    local copy = {}
    for key, value in pairs(self) do
      copy[key] = value
    end
    return copy
  end
end

local function resolve_index(self, index, is_end, no_max)
  if index == nil then
    return is_end and #self or 1
  elseif index == 0 then
    return 1
  elseif index < 0 then
    if #self + index >= 0 then
      return #self + index + 1
    else
      return 1
    end
    -- index >= 1
  elseif index > #self then
    if not no_max then
      return #self == 0 and 1 or #self
    else
      return index
    end
  else
    return index
  end
end

local array = setmetatable({}, {
  __call = function(self, attrs)
    return setmetatable(attrs or {}, self)
  end
})
array.__index = array
function array.new(cls, self)
  return setmetatable(self or {}, cls)
end

basearray_setup(array)


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

function array.equals(self, o)
  if type(o) ~= 'table' or #o ~= #self then
    return false
  end
  for i = 1, #self do
    local tt, ot = type(self[i]), type(o[i])
    if tt ~= ot then
      return false
    elseif tt ~= 'table' then
      if self[i] ~= o[i] then
        return false
      end
    elseif not array.equals(self[i], o[i]) then
      return false
    end
  end
  return true
end

-- {1,2} == {1,2}
array.__eq = array.equals
-- {1,2} + {2,3} = {1,2,2,3}
function array.__add(self, o)
  return array.concat(self, o)
end

-- {1,2} - {2,3} = {1}
function array.__sub(self, o)
  local res = setmetatable({}, array)
  local od = o:as_set()
  for i = 1, #self do
    if not od[self[i]] then
      res[#res + 1] = self[i]
    end
  end
  return res
end

return array
