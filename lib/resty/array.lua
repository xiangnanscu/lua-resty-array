local Object = require("resty.object")
local select = select
local table_concat = table.concat
local table_remove = table.remove
local table_insert = table.insert
local table_sort = table.sort
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

---@class Array<T>: { [integer]: T }
---@overload fun(t?:table):Array
local Array = setmetatable({}, { __call = Object.__call, __tostring = getmetatable(Object).__call })


Array.__call = Object.__call
Array.__tostring = Object.__tostring
Array.__name__ = 'Array'
Array.__index = Array
Array.__bases__ = { Object }
Array.__mro__ = { Array, Object }

-- {1,2} + {2,3} = {1,2,2,3}
---@param self Array
---@param o Array
function Array.__add(self, o)
  return Array.concat(self, o)
end

-- {1,2} - {2,3} = {1}
---@param self Array
---@param o Array
function Array.__sub(self, o)
  local res = setmetatable({}, Array)
  local od = {}
  for i = 1, #o do
    od[o[i]] = true
  end
  for i = 1, #self do
    if not od[self[i]] then
      res[#res + 1] = self[i]
    end
  end
  return res
end

---@param ... table
---@return Array
function Array.concat(...)
  local n = 0
  local m = select("#", ...)
  for i = 1, m do
    n = n + #select(i, ...)
  end
  local res = setmetatable(table_new(n, 0), Array)
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

---@param self Array
---@param callback function
---@return boolean
function Array.every(self, callback)
  for i = 1, #self do
    if not callback(self[i], i, self) then
      return false
    end
  end
  return true
end

---@param self Array
---@param v any
---@param s? number
---@param e? number
---@return Array
function Array.fill(self, v, s, e)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true, true)
  for i = s, e do
    self[i] = v
  end
  return self
end

---@param self Array
---@param callback function
---@return Array
function Array.filter(self, callback)
  local res = setmetatable({}, Array)
  for i = 1, #self do
    if callback(self[i], i, self) then
      res[#res + 1] = self[i]
    end
  end
  return res
end

---@param self Array
---@param callback function
---@return any
function Array.find(self, callback)
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

---@param self Array
---@param callback function
---@return integer
function Array.find_index(self, callback)
  if type(callback) == 'function' then
    for i = 1, #self do
      if callback(self[i], i, self) then
        return i
      end
    end
  else
    for i = 1, #self do
      if self[i] == callback then
        return i
      end
    end
  end
  return -1
end

Array.findIndex = Array.find_index

---@param self Array
---@param depth? integer
---@return Array
function Array.flat(self, depth)
  -- [0, 1, 2, [3, 4]] => [0, 1, 2, 3, 4]
  if depth == nil then
    depth = 1
  end
  if depth > 0 then
    local n = #self
    local res = setmetatable(table_new(n, 0), Array)
    for i = 1, #self do
      local v = self[i]
      if type(v) == "table" then
        local vt = Array.flat(v, depth - 1)
        for j = 1, #vt do
          res[#res + 1] = vt[j]
        end
      else
        res[#res + 1] = v
      end
    end
    return res
  else
    return setmetatable(clone(self), Array)
  end
end

---@param self Array
---@param callback function
---@return Array
function Array.flat_map(self, callback)
  -- equivalent to self:map(callback):flat(1), more efficient
  local n = #self
  local res = setmetatable(table_new(n, 0), Array)
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

Array.flatMap = Array.flat_map

---@param self Array
---@param callback function
function Array.for_each(self, callback)
  for i = 1, #self do
    callback(self[i], i, self)
  end
end

Array.forEach = Array.for_each

---@param self Array
---@param callback function
---@return table
function Array.group_by(self, callback)
  local res = {}
  if type(callback) == 'function' then
    for i = 1, #self do
      local k = callback(self[i], i, self)
      if not res[k] then
        res[k] = setmetatable({}, Array)
      end
      res[k][#res[k] + 1] = self[i]
    end
  else
    for i = 1, #self do
      local k = self[i][callback]
      if not res[k] then
        res[k] = setmetatable({}, Array)
      end
      res[k][#res[k] + 1] = self[i]
    end
  end
  return res
end

---@param self Array
---@param value any
---@param s? integer
---@return boolean
function Array.includes(self, value, s)
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

---@param self Array
---@param value any
---@param s? integer
---@return integer
function Array.index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, #self do
    if self[i] == value then
      return i
    end
  end
  return -1
end

Array.indexOf = Array.index_of

---@param self Array
---@param sep? string
---@return string
function Array.join(self, sep)
  return table_concat(self, sep)
end

---@param self Array
---@param value any
---@param s? integer
---@return integer
function Array.last_index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, 1, -1 do
    if self[i] == value then
      return i
    end
  end
  return -1
end

Array.lastIndexOf = Array.last_index_of

---@param self Array
---@param callback function
---@return Array
function Array.map(self, callback)
  local n = #self
  local res = setmetatable(table_new(n, 0), Array)
  for i = 1, n do
    res[i] = callback(self[i], i, self)
  end
  return res
end

---@param self Array
---@return any
function Array.pop(self)
  return table_remove(self)
end

---@param self Array
---@param ... any
---@return integer
function Array.push(self, ...)
  local n = #self
  for i = 1, select("#", ...) do
    self[n + i] = select(i, ...)
  end
  return #self
end

---@param self Array
---@param callback function
---@param init any
---@return any
function Array.reduce(self, callback, init)
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

---@param self Array
---@param callback function
---@param init any
---@return any
function Array.reduce_right(self, callback, init)
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

Array.reduceRright = Array.reduce_right

---@param self Array
---@return Array
function Array.reverse(self)
  local n = #self
  local e = n % 2 == 0 and n / 2 or (n - 1) / 2
  for i = 1, e do
    self[i], self[n + 1 - i] = self[n + 1 - i], self[i]
  end
  return self
end

---@param self Array
---@return any
function Array.shift(self)
  return table_remove(self, 1)
end

---@param self Array
---@param s? integer
---@param e? integer
---@return Array
function Array.slice(self, s, e)
  local res = setmetatable({}, Array)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true)
  for i = s, e do
    res[#res + 1] = self[i]
  end
  return res
end

---@param self Array
---@param callback function
---@return boolean
function Array.some(self, callback)
  for i = 1, #self do
    if callback(self[i], i, self) then
      return true
    end
  end
  return false
end

---@param self Array
---@param callback? function
---@return Array
function Array.sort(self, callback)
  table_sort(self, callback)
  return self
end

---@param self Array
---@param s? integer
---@param del_cnt? integer
---@param ... any
---@return Array
function Array.splice(self, s, del_cnt, ...)
  local n = #self
  s = resolve_index(self, s)
  if del_cnt == nil or del_cnt >= n - s + 1 then
    del_cnt = n - s + 1
  elseif del_cnt <= 0 then
    del_cnt = 0
  end
  local removed = setmetatable({}, Array)
  for i = s, del_cnt + s - 1 do
    table_insert(removed, table_remove(self, s))
  end
  for i = select("#", ...), 1, -1 do
    local e = select(i, ...)
    table_insert(self, s, e)
  end
  return removed
end

---@param self Array
---@param ... any
---@return integer
function Array.unshift(self, ...)
  local n = select("#", ...)
  for i = n, 1, -1 do
    local e = select(i, ...)
    table_insert(self, 1, e)
  end
  return #self
end

-- other methods

---@param self Array
---@param key string
---@return Array
function Array.map_key(self, key)
  local n = #self
  local res = setmetatable(table_new(n, 0), Array)
  for i = 1, n do
    res[i] = self[i][key]
  end
  return res
end

Array.sub = Array.slice

---@param self Array
function Array.clear(self)
  return table_clear(self)
end

---@param self Array
---@return any
function Array.dup(self)
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

Array.duplicate = Array.dup

local FIRST_DUP_ADDED = {}

---@param self Array
---@return Array
function Array.dups(self)
  local already = {}
  local res = setmetatable({}, Array)
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

Array.duplicates = Array.dups

---@param self Array
---@param callback function
---@return any
function Array.dup_map(self, callback)
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

Array.duplicate_map = Array.dup_map

---@param self Array
---@param callback function
---@return Array
function Array.dups_map(self, callback)
  local already = {}
  local res = setmetatable({}, Array)
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

Array.duplicates_map = Array.dups_map

---@param self Array
---@return Array
function Array.uniq(self)
  local already = {}
  local res = setmetatable({}, Array)
  for i = 1, #self do
    local key = self[i]
    if not already[key] then
      res[#res + 1] = key
      already[key] = true
    end
  end
  return res
end

Array.unique = Array.uniq

---@param self Array
---@param callback function
---@return Array
function Array.uniq_map(self, callback)
  local already = {}
  local res = setmetatable({}, Array)
  for i = 1, #self do
    local key = callback(self[i], i, self)
    if not already[key] then
      res[#res + 1] = self[i]
      already[key] = true
    end
  end
  return res
end

Array.unique_map = Array.uniq_map

---@param self Array
---@return table
function Array.as_set(self)
  local res = table_new(0, #self)
  for i = 1, #self do
    res[self[i]] = true
  end
  return res
end

---@param self Array
---@param callback function
---@return Array
function Array.exclude(self, callback)
  local res = setmetatable({}, Array)
  if type(callback) == 'function' then
    for i = 1, #self do
      if not callback(self[i], i, self) then
        res[#res + 1] = self[i]
      end
    end
  else
    for i = 1, #self do
      if self[i] ~= callback then
        res[#res + 1] = self[i]
      end
    end
  end
  return res
end

---@param self Array
---@param callback function
---@return integer
function Array.count(self, callback)
  local cnt = 0
  if type(callback) == 'function' then
    for i = 1, #self do
      if callback(self[i], i, self) then
        cnt = cnt + 1
      end
    end
  else
    for i = 1, #self do
      if self[i] == callback then
        cnt = cnt + 1
      end
    end
  end
  return cnt
end

---@param self Array
---@param callback function
---@return integer
function Array.count_exclude(self, callback)
  local cnt = 0
  if type(callback) == 'function' then
    for i = 1, #self do
      if not callback(self[i], i, self) then
        cnt = cnt + 1
      end
    end
  else
    for i = 1, #self do
      if self[i] ~= callback then
        cnt = cnt + 1
      end
    end
  end
  return cnt
end

---@param self Array
---@param n integer
---@return Array
function Array.combine(self, n)
  if #self == n then
    return setmetatable({ self }, Array)
  elseif n == 1 then
    return Array.map(self, function(e)
      return setmetatable({ e }, Array)
    end)
  elseif #self > n then
    local head = self[1]
    local rest = Array.slice(self, 2)
    return Array.concat(Array.combine(rest, n), Array.combine(rest, n - 1):map(function(e)
      return setmetatable({ head, unpack(e) }, Array)
    end))
  else
    return setmetatable({}, Array)
  end
end

---@param self Array
---@param o any
---@return boolean
function Array.equals(self, o)
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
      elseif not Array.equals(self[i], o[i]) then
        return false
      end
    end
  end
  return true
end

-- {1,2} == {1,2}, {1,{2}} == {1,{2}}
Array.__eq = Array.equals

---@param cls Array
---@return Array
function Array.new(cls)
  return setmetatable({}, cls)
end

function Array.init(self, ...)
  for i = 1, select("#", ...) do
    local a = select(i, ...)
    for j = 1, #a do
      self[#self + 1] = a[j]
    end
  end
  return self
end

---@param self Array
---@return Array
function Array.entries(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), Array)
  for i = 1, n do
    res[i] = { i, self[i] }
  end
  return res
end

---@param self Array
---@return Array
function Array.keys(self)
  local n = #self
  local res = setmetatable(table_new(n, 0), Array)
  for i = 1, n do
    res[i] = i
  end
  return res
end

---@param self Array
---@return Array
function Array.values(self)
  return setmetatable(clone(self), Array)
end

return Array
