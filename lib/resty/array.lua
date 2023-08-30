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

function array.concat(...)
  local n = 0
  local m = select("#", ...)
  for i = 1, m do
    n = n + #select(i, ...)
  end
  local res = setmetatable(table_new(n, 0), array)
  n = 0
  for i = 1, m do
    local e = select(i, ...)
    for j = 1, #e do
      res[n + j] = e[j]
    end
    n = n + #e
  end
  return res
end

function array.entries(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = { i, self[i] }
  end
  return res
end

function array.every(self, callback)
  for i = 1, #self do
    if not callback(self[i], i, self) then
      return false
    end
  end
  return true
end

function array.fill(self, v, s, e)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true, true)
  for i = s, e do
    self[i] = v
  end
  return self
end

function array.filter(self, callback)
  local res = setmetatable({}, array)
  for i = 1, #self do
    if callback(self[i], i, self) then
      res[#res + 1] = self[i]
    end
  end
  return res
end

function array.find(self, callback)
  if type(callback) == 'function' then
    for i = 1, #self do
      if callback(self[i], i, self) then
        return self[i]
      end
    end
  else
    for i = 1, #self do
      if self[i] == callback then
        return self[i]
      end
    end
  end
end

function array.find_index(self, callback)
  if type(callback) == 'function' then
    for i = 1, #self do
      if callback(self[i], i, self) then
        return i
      end
    end
  else
    for i = 1, #self do
      if self[i] == callback  then
        return i
      end
    end
  end
  return -1
end

array.findIndex = array.find_index

function array.flat(self, depth)
  -- [0, 1, 2, [3, 4]] => [0, 1, 2, 3, 4]
  if depth == nil then
    depth = 1
  end
  if depth > 0 then
    local n = #self
    local res = setmetatable(table_new(n, 0), array)
    for i = 1, #self do
      local v = self[i]
      if type(v) == "table" then
        local vt = array.flat(v, depth - 1)
        for j = 1, #vt do
          res[#res + 1] = vt[j]
        end
      else
        res[#res + 1] = v
      end
    end
    return res
  else
    return setmetatable(clone(self), array)
  end
end

function array.flat_map(self, callback)
  -- equivalent to self:map(callback):flat(1), more efficient
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    local v = callback(self[i], i, self)
    if type(v) == "table" then
      for j = 1, #v do
        res[#res + 1] = v[j]
      end
    else
      res[#res + 1] = v
    end
  end
  return res
end

array.flatMap = array.flat_map

function array.for_each(self, callback)
  for i = 1, #self do
    callback(self[i], i, self)
  end
end

array.forEach = array.for_each

function array.group_by(self, callback)
  local res = {}
  for i = 1, #self do
    local key = callback(self[i], i, self)
    if not res[key] then
      res[key] = setmetatable({}, array)
    end
    res[key][#res[key] + 1] = self[i]
  end
  return res
end

function array.includes(self, value, s)
  -- array{'a', 'b', 'c'}:includes('c', 3)    // true
  -- array{'a', 'b', 'c'}:includes('c', 100)  // false
  s = resolve_index(self, s, false, true)
  for i = s, #self do
    if self[i] == value then
      return true
    end
  end
  return false
end

function array.index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, #self do
    if self[i] == value then
      return i
    end
  end
  return -1
end

array.indexOf = array.index_of

function array.join(self, sep)
  return table_concat(self, sep)
end

function array.keys(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = i
  end
  return res
end

function array.last_index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, 1, -1 do
    if self[i] == value then
      return i
    end
  end
  return -1
end

array.lastIndexOf = array.last_index_of

function array.map(self, callback)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = callback(self[i], i, self)
  end
  return res
end

function array.pop(self)
  return table_remove(self)
end

function array.push(self, ...)
  local n = #self
  for i = 1, select("#", ...) do
    self[n + i] = select(i, ...)
  end
  return #self
end

function array.reduce(self, callback, init)
  local i = 1
  if init == nil then
    init = self[1]
    i = 2
  end
  if init == nil and #self == 0 then
    error("Reduce of empty array with no initial value")
  end
  for j = i, #self do
    init = callback(init, self[j], j, self)
  end
  return init
end

function array.reduce_right(self, callback, init)
  local i = #self
  if init == nil then
    init = self[i]
    i = i - 1
  end
  if init == nil and #self == 0 then
    error("Reduce of empty array with no initial value")
  end
  for j = i, 1, -1 do
    init = callback(init, self[j], j, self)
  end
  return init
end

array.reduceRright = array.reduce_right

function array.reverse(self)
  local n = #self
  local e = n % 2 == 0 and n / 2 or (n - 1) / 2
  for i = 1, e do
    self[i], self[n + 1 - i] = self[n + 1 - i], self[i]
  end
  return self
end

function array.shift(self)
  return table_remove(self, 1)
end

function array.slice(self, s, e)
  local res = setmetatable({}, array)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true)
  for i = s, e do
    res[#res + 1] = self[i]
  end
  return res
end

function array.some(self, callback)
  for i = 1, #self do
    if callback(self[i], i, self) then
      return true
    end
  end
  return false
end

function array.sort(self, callback)
  table_sort(self, callback)
  return self
end

function array.splice(self, s, del_cnt, ...)
  local n = #self
  s = resolve_index(self, s)
  if del_cnt == nil or del_cnt >= n - s + 1 then
    del_cnt = n - s + 1
  elseif del_cnt <= 0 then
    del_cnt = 0
  end
  local removed = setmetatable({}, array)
  for i = s, del_cnt + s - 1 do
    table_insert(removed, table_remove(self, s))
  end
  for i = select("#", ...), 1, -1 do
    local e = select(i, ...)
    table_insert(self, s, e)
  end
  return removed
end

function array.unshift(self, ...)
  local n = select("#", ...)
  for i = n, 1, -1 do
    local e = select(i, ...)
    table_insert(self, 1, e)
  end
  return #self
end

function array.values(self)
  return setmetatable(clone(self), array)
end

-- other methods

function array.group_by_key(self, key)
  local res = {}
  for i = 1, #self do
    local k = self[i][key]
    if not res[k] then
      res[k] = setmetatable({}, array)
    end
    res[k][#res[k] + 1] = self[i]
  end
  return res
end

function array.map_key(self, key)
  local n = #self
  local res = setmetatable(table_new(n, 0), array)
  for i = 1, n do
    res[i] = self[i][key]
  end
  return res
end

array.sub = array.slice

function array.clear(self)
  return table_clear(self)
end

function array.dup(self)
  local already = {}
  for i = 1, #self do
    local e = self[i]
    if already[e] then
      return e
    else
      already[e] = true
    end
  end
end

array.duplicate = array.dup

local FIRST_DUP_ADDED = {}
function array.dups(self)
  local already = {}
  local res = setmetatable({}, array)
  for i = 1, #self do
    local e = self[i]
    local a = already[e]
    if a ~= nil then
      if a ~= FIRST_DUP_ADDED then
        res[#res + 1] = a
        already[e] = FIRST_DUP_ADDED
      end
      res[#res + 1] = e
    else
      already[e] = e
    end
  end
  return res
end

function array.dup_map(self, callback)
  local already = {}
  for i = 1, #self do
    local e = self[i]
    local k = callback(e, i, self)
    if already[k] then
      return e
    else
      already[k] = true
    end
  end
end

function array.dups_map(self, callback)
  local already = {}
  local res = setmetatable({}, array)
  for i = 1, #self do
    local e = self[i]
    local k = callback(e, i, self)
    local a = already[k]
    if a ~= nil then
      if a ~= FIRST_DUP_ADDED then
        res[#res + 1] = a
        already[k] = FIRST_DUP_ADDED
      end
      res[#res + 1] = e
    else
      already[k] = e
    end
  end
  return res
end

function array.uniq(self)
  local already = {}
  local res = setmetatable({}, array)
  for i = 1, #self do
    local key = self[i]
    if not already[key] then
      res[#res + 1] = key
      already[key] = true
    end
  end
  return res
end

function array.uniq_map(self, callback)
  local already = {}
  local res = setmetatable({}, array)
  for i = 1, #self do
    local key = callback(self[i], i, self)
    if not already[key] then
      res[#res + 1] = self[i]
      already[key] = true
    end
  end
  return res
end

function array.as_set(self)
  local res = table_new(0, #self)
  for i = 1, #self do
    res[self[i]] = true
  end
  return res
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

function array.exclude(self, callback)
  local res = setmetatable({}, array)
  for i = 1, #self do
    if not callback(self[i], i, self) then
      res[#res + 1] = self[i]
    end
  end
  return res
end

function array.count(self, callback)
  local res = 0
  for i = 1, #self do
    if callback(self[i], i, self) then
      res = res + 1
    end
  end
  return res
end

function array.count_exclude(self, callback)
  local res = 0
  for i = 1, #self do
    if not callback(self[i], i, self) then
      res = res + 1
    end
  end
  return res
end

function array.combine(self, n)
  if #self == n then
    return array { self }
  elseif n == 1 then
    return array.map(self, function(e)
      return array { e }
    end)
  elseif #self > n then
    local head = self[1]
    local rest = array.slice(self, 2)
    return array.concat(array.combine(rest, n), array.combine(rest, n - 1):map(function(e)
      return array { head, unpack(e) }
    end))
  else
    return array {}
  end
end

return array
