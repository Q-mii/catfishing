pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
global_data_str="palettes={transparent_color_id=0},text={60,5,7,1},gauge_data={position={10,10},size={100,5},settings={4,7,2,3}},power_gauge_colors={8,9,10,11,3},biases={weight=8,size=3},areas={{name=home,mapID=0,music={},fishes={{gradient={8,9,10,11,11,11,10,9,8},successIDs={11},min_gauge_requirement=1,max_gauge_requirement=3,stats={goldfish,2,2.7,12.5},units={cm,g}},{gradient={8,9,10,11,10,9,8},successIDs={11},min_gauge_requirement=4,max_gauge_requirement=inf,stats={yellow fin tuna,4,32,2.25},units={m,kg}}}}}"
function reset()
  global_data_table = unpack_table(global_data_str)
  fishing_area = FishingArea:new(global_data_table.areas[1])
end
BorderRect = {}
function BorderRect:new(position_, size_, border_color, base_color, thickness_size)
  obj = {
    position = position_, 
    size = position_ + size_,
    border = border_color, 
    base = base_color,
    thickness = thickness_size
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end
function BorderRect:draw()
  rectfill(
    self.position.x-self.thickness, self.position.y-self.thickness, 
    self.size.x+self.thickness, self.size.y+self.thickness, 
    self.border
  )
  rectfill(self.position.x, self.position.y, self.size.x, self.size.y, self.base)
end
function BorderRect:resize(position_, size_)
  if (self.position ~= position_) self.position = position_
  if (self.size ~= size_ + position_) self.size = size_ + position_ 
end
function BorderRect:reposition(position_)
  if (self.position == position_) return
  local size = self.size - self.position
  self.position = position_
  self.size = self.position + size
end
GradientSlider = {}
function GradientSlider:new(
  position_, size_, gradient_colors, handle_color, outline_color, thickness_, speed_)
  obj = {
    position=position_, 
    size=size_, 
    colors=gradient_colors,
    handle=handle_color,
    outline=outline_color,
    thickness=thickness_,
    speed=speed_,
    handle_size=Vec:new(3, size_.y+4),
    pos=0,
    dir=1
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end
function GradientSlider:draw()
  local rect_size = self.position + self.size
  rectfill(
    self.position.x-self.thickness, self.position.y-self.thickness, 
    rect_size.x+self.thickness, rect_size.y+self.thickness, 
    self.outline
  )
  for y=0, self.size.y do
    for x=0, self.size.x do
      local pixel_coord = Vec:new(x, y) + self.position 
      pset(pixel_coord.x, pixel_coord.y, self.colors[GradientSlider.get_stage(self, x)])
    end
  end
  local handle_pos = self.position + Vec:new(self.pos, -2)
  local handle_size = handle_pos + self.handle_size
  rectfill(
    handle_pos.x-self.thickness, handle_pos.y-self.thickness,
    handle_size.x+self.thickness, handle_size.y+self.thickness,
    self.outline
  )
  rectfill(
    handle_pos.x, handle_pos.y,
    handle_size.x, handle_size.y,
    self.handle
  )
end
function GradientSlider:update()
  self.pos += self.dir * self.speed
  if self.pos >= self.size.x or self.pos <= 0 then 
    self.dir *= -1
  end
end
function GradientSlider:get_stage(x)
  local p = x or self.pos
  local rate = flr((p / self.size.x) * 100)
  local range = self.size.x \ #self.colors
  return mid(rate \ range + 1, 1, #self.colors)
end
function GradientSlider:reset()
  self.pos = 0
  self.dir = 1
end
Fish = {}
function Fish:new(fish_name, spriteID, weight, fish_size, units_, gradient, successIDs)
  local string_len = longest_string({
    "name: "..fish_name,
    "weight: "..weight..units_[2],
    "size: "..fish_size..units_[1],
    "the fish got away"
  })*5-5
  local box_size = Vec:new(string_len, 32)
  local gauge_data = global_data_table.gauge_data
  obj = {
    name=fish_name,
    sprite = spriteID,
    lb = weight,
    size = fish_size,
    units = units_,
    success_stage_ids = successIDs,
    tension_slider = GradientSlider:new(
      Vec:new(gauge_data.position), Vec:new(gauge_data.size), 
      gradient, unpack(gauge_data.settings)
    ),
    description_box = BorderRect:new(
      Vec:new((128-box_size.x-6) \ 2, 90), box_size, 
      7, 1, 3
    )
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end
function Fish:update()
  GradientSlider.update(self.tension_slider)
end
function Fish:draw_tension()
  GradientSlider.draw(self.tension_slider)
end
function Fish:draw_details()
  line(62, 0, 62, 48, 7)
  draw_sprite_rotated(self.sprite, Vec:new(55, 48), 16, 90)
  BorderRect.draw(self.description_box)
  print_with_outline(
    "name: "..self.name.."\n\nweight: "..self.lb..self.units[2].."\nsize: "..self.size..self.units[1], 
    self.description_box.position.x + 5, 95, 7, 0
  )
end
function Fish:catch()
  return table_contains(
    self.success_stage_ids, 
    self.tension_slider.colors[GradientSlider.get_stage(self.tension_slider)]
  )
end
FishingArea = {}
function FishingArea:new(area_data_)
  local lost_text_len = #"the fish got away"*5-5
  obj = {
    area_data = area_data_,
    power_gauge = GradientSlider:new(
      Vec:new(global_data_table.gauge_data.position), 
      Vec:new(global_data_table.gauge_data.size), 
      global_data_table.power_gauge_colors,
      unpack(global_data_table.gauge_data.settings)
    ),
    lost_box = BorderRect:new(
      Vec:new((128-lost_text_len-6)\2, 48),
      Vec:new(lost_text_len, 16),
      7, 1, 3
    ),
    state = "none",
    fish = nil
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end
function FishingArea:draw()
  if self.state == "none" then 
    print_with_outline("press ❎ to cast line", 2, 120, 7, 1)
  elseif self.state == "casting" then 
    GradientSlider.draw(self.power_gauge)
  elseif self.state == "fishing" then 
    Fish.draw_tension(self.fish)
  elseif self.state == "detail" then 
    Fish.draw_details(self.fish)
  elseif self.state == "lost" then 
    FishingArea.draw_lost(self)
  end
end
function FishingArea:draw_lost()
  BorderRect.draw(self.lost_box)
  print_with_outline(
    "the fish got away", 
    self.lost_box.position.x + 5, self.lost_box.position.y+6, 7, 0
  )
end
function FishingArea:update()
  if btnp(❎) then
    if self.state == "none" then 
      self.state = "casting"
    elseif self.state == "casting" then 
      self.fish = generate_fish(self.area_data, GradientSlider.get_stage(self.power_gauge))
      GradientSlider.reset(self.power_gauge)
      if self.fish == nil then 
        self.state = "lost"
      else
        self.state = "fishing"
      end
    elseif self.state == "fishing" then 
      if Fish.catch(self.fish) then 
        self.state = "detail"
      else
        self.state = "lost"
      end
      GradientSlider.reset(self.fish.tension_slider)
    elseif self.state == "detail" then 
      self.fish = nil
      self.state = "none"
    elseif self.state == "lost" then 
      self.fish = nil
      self.state = "none"
    end
  end
  
  if self.state == "casting" then 
    GradientSlider.update(self.power_gauge)
  elseif self.state == "fishing" then 
    Fish.update(self.fish)
  end
end
function generate_fish(area, stage)
  local possible_fishes = {}
  local stage_gauge = stage -- + bait bonus
  for fish in all(area.fishes) do
    printh(fish.max_gauge_requirement)
    if stage_gauge <= fish.max_gauge_requirement and stage_gauge >= fish.min_gauge_requirement then 
      add(possible_fishes, fish)
    end
  end
  if (#possible_fishes == 0) return nil
  local fish =possible_fishes[flr(rnd(#possible_fishes))+1]
  local name, spriteID, weight, size = unpack(fish.stats)
  size, weight = generate_weight_size_with_bias(weight, size)
  return Fish:new(
    name, spriteID, weight, size, fish.units, fish.gradient, fish.successIDs
  )
end
function generate_weight_size_with_bias(weight, size)
  local bias = global_data_table.biases.size
  local new_size = round_to(mid(size + rnd(bias) - (bias/2), 0.1, size + bias), 2)
  local new_weight = round_to(weight * new_size * 0.3 * global_data_table.biases.weight, 2)
  return new_size, new_weight
end
Vec = {}
function Vec:new(dx, dy)
  local obj = nil
  if type(dx) == "table" then 
    obj = {x=dx[1],y=dx[2]}
  else
    obj={x=dx,y=dy}
  end
  setmetatable(obj, self)
  self.__index = self
  self.__add = function(a, b)
    return Vec:new(a.x+b.x,a.y+b.y)
  end
  self.__sub = function(a, b)
    return Vec:new(a.x-b.x,a.y-b.y)
  end
  self.__mul = function(a, scalar)
    return Vec:new(a.x*scalar,a.y*scalar)
  end
  self.__div = function(a, scalar)
    return Vec:new(a.x/scalar,a.y/scalar)
  end
  self.__eq = function(a, b)
    return (a.x==b.x and a.y==b.y)
  end
  self.__tostring = function(vec)
    return "("..vec.x..", "..vec.y..")"
  end
  self.__concat = function(vec, other)
    return (type(vec) == "table") and Vec.__tostring(vec)..other or vec..Vec.__tostring(other)
  end
  return obj
end
function Vec:unpack()
  return self.x, self.y
end
function Vec:clamp(min, max)
  self.x, self.y = mid(self.x, min, max), mid(self.y, min, max)
end
function normalize(val)
  return (type(val) == "table") and Vec:new(normalize(val.x), normalize(val.y)) or flr(mid(val, -1, 1))
end
function lerp(start, last, rate)
  if type(start) == "table" then 
    return Vec:new(lerp(start.x, last.x, rate), lerp(start.y, last.y, rate))
  else
    return start + (last - start) * rate
  end
end
function _init()
  reset()
end
function _draw()
  cls()
  FishingArea.draw(fishing_area)
end
function _update()
  FishingArea.update(fishing_area)
end
function print_with_outline(text, dx, dy, text_color, outline_color)
  ?text,dx-1,dy,outline_color
  ?text,dx+1,dy
  ?text,dx,dy-1
  ?text,dx,dy+1
  ?text,dx,dy,text_color
end
function print_text_center(text, dy, text_color, outline_color)
  print_with_outline(text, (128-(#text*5-5)-6)\2, dy, text_color, outline_color)
end
function controls()
  if btnp(⬆️) then return 0, -1
  elseif btnp(⬇️) then return 0, 1
  elseif btnp(⬅️) then return -1, 0
  elseif btnp(➡️) then return 1, 0
  end
  return 0, 0
end
function draw_sprite_rotated(sprite_id, position, size, theta, is_opaque)
  local sx, sy = (sprite_id % 16) * 8, (sprite_id \ 16) * 8 
  local sine, cosine = sin(theta / 360), cos(theta / 360)
  local shift = size\2 - 0.5
  for mx=0, size-1 do 
    for my=0, size-1 do 
      local dx, dy = mx-shift, my-shift
      local xx = flr(dx*cosine-dy*sine+shift)
      local yy = flr(dx*sine+dy*cosine+shift)
      if xx >= 0 and xx < size and yy >= 0 and yy <= size then
        local id = sget(sx+xx, sy+yy)
        if id ~= global_data_table.palettes.transparent_color_id or is_opaque then 
          pset(position.x+mx, position.y+my, id)
        end
      end
    end
  end
end
function longest_string(strings)
  local len = 0
  for string in all(strings) do 
    len = max(len, #string)
  end
  return len
end
function round_to(value, places)
  local places = 10 * places
  local val = value * places
  val = flr(val)
  return val / places
end
function table_contains(table, val)
  for obj in all(table) do 
    if (obj == val) return true
  end
end
function unpack_table(str)
  local table,start,stack,i={},1,0,1
  while i <= #str do
    if str[i]=="{" then 
      stack+=1
    elseif str[i]=="}"then 
      stack-=1
      if(stack>0)goto unpack_table_continue
      insert_key_val(sub(str,start,i), table)
      start=i+1
      if(i+2>#str)goto unpack_table_continue
      start+=1
      i+=1
    elseif stack==0 then
      if str[i]=="," then
        insert_key_val(sub(str,start,i-1), table)
        start=i+1
      elseif i==#str then 
        insert_key_val(sub(str, start), table)
      end
    end
    ::unpack_table_continue::
    i+=1
  end
  return table
end
function insert_key_val(str, table)
  local key, val = split_key_value_str(str)
  if key == nil then
    add(table, val)
  else  
    local value
    if val[1] == "{" and val[-1] == "}" then 
      value = unpack_table(sub(val, 2, #val-1))
    elseif val == "True" then 
      value = true 
    elseif val == "False" then 
      value = false 
    else
      value = tonum(val) or val
    end
    if value == "inf" then 
      value = 32767
    end
    table[key] = value
  end
end
function convert_to_array_or_table(str)
  local internal = sub(str, 2, #str-1)
  if (str_contains_char(internal, "{")) return unpack_table(internal) 
  if (not str_contains_char(internal, "=")) return split(internal, ",", true) 
  return unpack_table(internal)
end
function split_key_value_str(str)
  local parts = split(str, "=")
  local key = tonum(parts[1]) or parts[1]
  if str[1] == "{" and str[-1] == "}" then 
    return nil, convert_to_array_or_table(str)
  end
  local val = sub(str, #(tostr(key))+2)
  if val[1] == "{" and val[-1] == "}" then 
    return key, convert_to_array_or_table(val)
  end
  return key, val
end
function str_contains_char(str, char)
  for i=1, #str do
    if (str[i] == char) return true
  end
end
__gfx__
11221122112211220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11221122112211220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22112211221122110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22112211221122110000004888000000000000999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11221122112211220000488880000048000099900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11221122112211220048889900004889000555555000009900000000000000000000000000000000000000000000000000000000000000000000000000000000
221122112211221108a8999990088990005555995550097000000000000000000000000000000000000000000000000000000000000000000000000000000000
22112211221122118a5a999999889900550999999995970000000000000000000000000000000000000000000000000000000000000000000000000000000000
112211221122112288a9999999999000999777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
11221122112211228899999999999900067777777600970000000000000000000000000000000000000000000000000000000000000000000000000000000000
221122112211221109999999aa099990000666799000097000000000000000000000000000000000000000000000000000000000000000000000000000000000
2211221122112211009999aaa00099aa000099009990009900000000000000000000000000000000000000000000000000000000000000000000000000000000
112211221122112200099aaa00000099000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11221122112211220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22112211221122110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22112211221122110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
