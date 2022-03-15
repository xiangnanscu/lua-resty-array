local set = require("resty.set")
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
  table_clear = function(t)
    for key, _ in pairs(t) do
      t[key] = nil
    end
  end
  clone = function(t)
    local copy = {}
    for key, value in pairs(t) do
      copy[key] = value
    end
    return copy
  end
end

local function resolve_index(t, index, is_end, no_max)
  if index == nil then
    return is_end and #t or 1
  elseif index == 0 then
    return 1
  elseif index < 0 then
    if #t + index >= 0 then
      return #t + index + 1
    else
      return 1
    end
  -- index >= 1
  elseif index > #t then
    if not no_max then
      return #t == 0 and 1 or #t
    else
      return index
    end
  else
    return index
  end
end

local array = setmetatable({}, {
  __call = function(t, attrs)
    return setmetatable(attrs or {}, t)
  end
})
array.__index = array
function array.new(cls, t)
  return setmetatable(t or {}, cls)
end

function array.concat(...)
  local n = 0
  local m = select("#", ...)
  for i = 1, m do
    n = n + #select(i, ...)
  end
  local res = array:new(table_new(n, 0))
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

function array.entries(t)
  local n = #t
  local res = array:new(table_new(n, 0))
  for i = 1, n do
    res[i] = {i, t[i]}
  end
  return res
end

function array.every(t, callback)
  for i = 1, #t do
    if not callback(t[i], i, t) then
      return false
    end
  end
  return true
end

function array.fill(t, v, s, e)
  s = resolve_index(t, s)
  e = resolve_index(t, e, true)
  for i = s, e do
    t[i] = v
  end
  return t
end

function array.filter(t, callback)
  local res = array:new()
  for i = 1, #t do
    if callback(t[i], i, t) then
      res[#res + 1] = t[i]
    end
  end
  return res
end

function array.find(t, callback)
  for i = 1, #t do
    if callback(t[i], i, t) then
      return t[i]
    end
  end
end

function array.find_index(t, callback)
  for i = 1, #t do
    if callback(t[i], i, t) then
      return i
    end
  end
  return -1
end
array.findIndex = array.find_index


function array.flat(t, depth)
  -- [0, 1, 2, [3, 4]] => [0, 1, 2, 3, 4]
  if depth == nil then
    depth = 1
  end
  if depth > 0 then
    local n = #t
    local res = array:new(table_new(n, 0))
    for i = 1, #t do
      local v = t[i]
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
    return array:new(clone(t))
  end
end

function array.flat_map(t, callback)
  -- equivalent to t:map(callback):flat(1), more efficient
  local n = #t
  local res = array:new(table_new(n, 0))
  for i = 1, n do
    local v = callback(t[i], i, t)
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

function array.for_each(t, callback)
  for i = 1, #t do
    callback(t[i], i, t)
  end
end
array.forEach = array.for_each

function array.group_by(t, callback)
  local res = {}
  for i = 1, #t do
    local key = callback(t[i], i, t)
    if not res[key] then
      res[key] = array:new()
    end
    res[key][#res[key] + 1] = t[i]
  end
  return res
end

function array.includes(t, value, s)
  -- array{'a', 'b', 'c'}:includes('c', 3)    // true
  -- array{'a', 'b', 'c'}:includes('c', 100)  // false
  s = resolve_index(t, s, false, true)
  for i = s, #t do
    if t[i] == value then
      return true
    end
  end
  return false
end

function array.index_of(t, value, s)
  s = resolve_index(t, s, false, true)
  for i = s, #t do
    if t[i] == value then
      return i
    end
  end
  return -1
end
array.indexOf = array.index_of

function array.join(t, sep)
  return table_concat(t, sep)
end

function array.keys(t)
  local n = #t
  local res = array:new(table_new(n, 0))
  for i = 1, n do
    res[i] = i
  end
  return res
end

function array.last_index_of(t, value, s)
  s = resolve_index(t, s, false, true)
  for i = s, 1, -1 do
    if t[i] == value then
      return i
    end
  end
  return -1
end
array.lastIndexOf = array.last_index_of

function array.map(t, callback)
  local n = #t
  local res = array:new(table_new(n, 0))
  for i = 1, n do
    res[i] = callback(t[i], i, t)
  end
  return res
end

function array.pop(t)
  return table_remove(t)
end

function array.push(t, ...)
  local n = #t
  for i = 1, select("#", ...) do
    t[n + i] = select(i, ...)
  end
  return #t
end

function array.reduce(t, callback, init)
  local i = 1
  if init == nil then
    init = t[1]
    i = 2
  end
  if init == nil and #t == 0 then
    error("Reduce of empty array with no initial value")
  end
  for j = i, #t do
    init = callback(init, t[j], j, t)
  end
  return init
end

function array.reduce_right(t, callback, init)
  local i = #t
  if init == nil then
    init = t[i]
    i = i - 1
  end
  if init == nil and #t == 0 then
    error("Reduce of empty array with no initial value")
  end
  for j = i, 1, -1 do
    init = callback(init, t[j], j, t)
  end
  return init
end
array.reduceRright = array.reduce_right

function array.reverse(t)
  local n = #t
  local e = n % 2 == 0 and n / 2 or (n - 1) / 2
  for i = 1, e do
    t[i], t[n + 1 - i] = t[n + 1 - i], t[i]
  end
  return t
end

function array.shift(t)
  return table_remove(t, 1)
end

function array.slice(t, s, e)
  local res = array:new()
  s = resolve_index(t, s)
  e = resolve_index(t, e, true)
  for i = s, e do
    res[#res + 1] = t[i]
  end
  return res
end

function array.some(t, callback)
  for i = 1, #t do
    if callback(t[i], i, t) then
      return true
    end
  end
  return false
end

function array.sort(t, callback)
  table_sort(t, callback)
  return t
end

function array.splice(t, s, del_cnt, ...)
  local n = #t
  s = resolve_index(t, s)
  if del_cnt == nil or del_cnt >= n - s + 1 then
    del_cnt = n - s + 1
  elseif del_cnt <= 0 then
    del_cnt = 0
  end
  local removed = array:new()
  for i = s, del_cnt + s - 1 do
    table_insert(removed, table_remove(t, s))
  end
  for i = select("#", ...), 1, -1 do
    local e = select(i, ...)
    table_insert(t, s, e)
  end
  return removed
end

function array.unshift(t, ...)
  local n = select("#", ...)
  for i = n, 1, -1 do
    local e = select(i, ...)
    table_insert(t, 1, e)
  end
  return #t
end

function array.values(t)
  return array:new(clone(t))
end

-- other methods

function array.group_by_key(t, attr)
  local res = {}
  for i = 1, #t do
    local key = t[i][attr]
    if not res[key] then
      res[key] = array:new()
    end
    res[key][#res[key] + 1] = t[i]
  end
  return res
end

function array.map_key(t, key)
  local n = #t
  local res = array:new(table_new(n, 0))
  for i = 1, n do
    res[i] = t[i][key]
  end
  return res
end

array.sub = array.slice

function array.clear(t)
  return table_clear(t)
end

function array.dup(t)
  local already = {}
  for i = 1, #t do
    local e = t[i]
    if already[e] then
      return e
    else
      already[e] = true
    end
  end
end
array.duplicate = array.dup

local FIRST_DUP_ADDED = {}
function array.dups(t)
  local already = {}
  local res = array:new()
  for i = 1, #t do
    local e = t[i]
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

function array.dup_map(t, callback)
  local already = {}
  for i = 1, #t do
    local e = t[i]
    local k = callback(e, i, t)
    if already[k] then
      return e
    else
      already[k] = true
    end
  end
end

function array.dups_map(t, callback)
  local already = {}
  local res = array:new()
  for i = 1, #t do
    local e = t[i]
    local k = callback(e, i, t)
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

function array.uniq(t)
  local already = {}
  local res = array:new()
  for i = 1, #t do
    local key = t[i]
    if not already[key] then
      res[#res + 1] = key
      already[key] = true
    end
  end
  return res
end

function array.uniq_map(t, callback)
  local already = {}
  local res = array:new()
  for i = 1, #t do
    local key = callback(t[i], i, t)
    if not already[key] then
      res[#res + 1] = t[i]
      already[key] = true
    end
  end
  return res
end

function array.as_set(t)
  local res = set:new(table_new(0, #t))
  for i = 1, #t do
    res[t[i]] = true
  end
  return res
end

function array.equals(t, o)
  if type(o) ~= 'table' or #o ~= #t then
    return false
  end
  for i = 1, #t do
    local tt, ot = type(t[i]), type(o[i])
    if tt ~= ot then
      return false
    elseif tt ~= 'table' then
      if t[i] ~= o[i] then
        return false
      end
    elseif not array.equals(t[i], o[i]) then
      return false
    end
  end
  return true
end
-- {1,2} == {1,2}
array.__eq = array.equals
-- {1,2} + {2,3} = {1,2,2,3}
function array.__add(t, o)
  return array.concat(t, o)
end
-- {1,2} - {2,3} = {1}
function array.__sub(t, o)
  local res = array:new()
  local od = o:as_set()
  for i = 1, #t do
    if not od[t[i]] then
      res[#res + 1] = t[i]
    end
  end
  return res
end

if select('#', ...) == 0 then
  local inspect = require "resty.inspect"
  local p = function(e)
    print(inspect(e))
  end
  assert(array{1,2,3} + array{3,4} == array{1,2,3,3,4})
  assert(array{1,2,3} - array{3,4} == array{1,2})
  assert(array{'a','b','c'}:entries() == array{{1,'a'},{2,'b'},{3,'c'}})
  assert(array{1,2,3}:every(function(n) return n > 0 end) == true)
  assert(array{0,0,0}:fill(8) == array{8,8,8})
  assert(array{0,0,0}:fill(8,2,3) == array{0,8,8})
  assert(array{1,'not',3,'number'}:filter(function(e) return tonumber(e) end) == array{1,3})
  assert(array{{id=1},{id=101}, {id=3}}:find(function(e) return e.id == 101 end).id == 101)
  assert(array{{id=1},{id=101}, {id=3}}:find_index(function(e) return e.id == 101 end) == 2)
  assert(array{1,{2},3}:flat() == array{1,2,3})
  array{'a','b','c'}:for_each(print)
  assert(array{1,2,3}:includes(1) == true)
  assert(array{1,2,3}:includes(1, 4) == false)
  assert(array{1,2,3}:includes(5) == false)
  assert(array{'a','b'}:index_of('b') == 2)
  assert(array{'a','b','c'}:join('|') == 'a|b|c')
  assert(array{'a','b','c'}:keys() == array{1,2,3})
  assert(array{'a','b','b','c'}:last_index_of('b',-1) == 3)
  assert(array{'a','b','b','c'}:index_of('b') == 2)
  assert(array{1,2,3}:map(function(n) return n+10 end) == array{11,12,13})
  assert(array{1,2,100}:pop()==100)
  assert(array{1,2,3}:reverse() == array{3,2,1})
  local a = array{1,2,3}
  assert(a:push(4,5,6)==6)
  assert(a==array{1,2,3,4,5,6})
  assert(a:shift()==1)
  assert(a==array{2,3,4,5,6})
  assert(array{1,2,3}:reduce(function(x,y) return x+y end) == 6)
  assert(array{1,2,3,4}:slice() == array{1,2,3,4})
  assert(array{1,2,3,4}:slice(2) == array{2,3,4})
  assert(array{1,2,3,4}:slice(1,-1) == array{1,2,3,4})
  assert(array{1,2,3,4}:slice(2,3) == array{2,3})
  assert(array{1,2,3}:some(function(n) return n < 0 end) == false)
  assert(array{-1,2,3}:some(function(n) return n < 0 end) == true)
  local b = array{}
  assert(b:splice(1,0,1,2,3,4) == array{})
  assert(b == array{1,2,3,4})
  assert(b:splice(1,1) == array{1})
  assert(b == array{2,3,4})
  assert(b:splice(2,1,5,6) == array{3})
  assert(b == array{2,5,6,4})
  local c = array{}
  assert(c:unshift('c','d','e')==3)
  assert(c == array{'c','d','e'})
  p(c)
  assert(c:unshift('a','b')==5)
  assert(c == array{'a','b','c','d','e'})
  assert(array{{id=1},{id=101}, {id=3}}:map_key('id')==array{1,101,3})
  assert(array{1,2,2,3}:dup()==2)
  assert(array{1,2,2,3,4,4,4,5}:dups()==array{2,2,4,4,4})
  assert(array{1,2,2,3,4,4,4,5}:uniq()==array{1,2,3,4,5})
end

return array
