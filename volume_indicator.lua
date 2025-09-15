local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")

local indicator = wibox.widget{
  widget = wibox.container.margin,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  {
    widget = wibox.widget.imagebox,
    image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-high-panel.png",
    resize = false
  }
}

local function getCurrentVolume()
  local handle = io.popen('pactl list sinks | grep -m1 -oP "[0-9]*(?=%.*,)"')
  local result = handle:read("*all"):match("(.-)\n").." %"
  handle:close()
  return result
end

function indicator:setIcon()
  awful.spawn.easy_async("pactl list sinks", function(result)
    local vol = tonumber(result:match("([0-9]+)%%"))
    if vol >= 100 then
      self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-high-panel.png"
    elseif vol >= 50 then
      self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-medium-panel.png"
    elseif vol > 0 then
      self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-low-panel.png"
    elseif vol == 0 then
      self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-zero-panel.png"
    end
  end)
end

indicator:setIcon()


awful.spawn.easy_async("pactl list sinks", function(out)
  indicator.tooltip.content.text = out:match("Volume: .-/ (%d+)%%").." %"
end)

function indicator:mute()
  awful.spawn.easy_async("pactl list sinks", function(result)
    local lastSinkIndex = result:match(".*Sink #([0-9]*)")
    local newMuteMode = result:match("Mute: yes") and 0 or 1
    for i = 0, lastSinkIndex do
      awful.spawn.easy_async("pactl set-sink-mute "..i.." "..newMuteMode, function() end)
    end
    if newMuteMode == 0 then
      self:setIcon()
    else
      self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/audio-volume-muted-panel.png"
    end
  end)
end

indicator.tooltip = require("tooltip")

indicator:connect_signal("mouse::enter", function(c, geo)
  c.tooltip.content.text = getCurrentVolume()
  c.tooltip.content.align = "center"
  c.tooltip.screen = awful.screen.focused()
  local width, height = c.tooltip.content:get_preferred_size(c.tooltip.screen)
  c.tooltip.height = height + 2
  c.tooltip.width = width + 4
  c.tooltip.x = c.tooltip.screen.geometry.x + math.min(
    geo.x + 0.5 * (geo.width - c.tooltip.width),
    c.tooltip.screen.workarea.width - c.tooltip.width - 4
  )
  if geo.y == 0 then
    c.tooltip.y = geo.height + 4
  else
    c.tooltip.y = geo.height - 4
  end
  c.tooltip.timer = gears.timer{
    timeout = 1,
    autostart = true,
    callback = function() c.tooltip.visible = true end,
    single_shot = true
  }
end)

function indicator:applyColors()
  self:setIcon()
end

indicator:connect_signal("mouse::leave", function(c)
  if c.tooltip.timer.started then
    c.tooltip.timer:stop()
  end
  c.tooltip.visible = false
end)

indicator:buttons(gears.table.join(
  awful.button({ }, 1, function()
    local matcher = function(c) 
      return awful.rules.match(c, {class = 'pavucontrol'})
    end
    awful.client.run_or_raise('pavucontrol', matcher)
  end),
  awful.button({ }, 4, function()
    awful.spawn.easy_async("pactl list sinks short", function(result)
       string.gsub("\n"..result, "\n[0-9]+[\t ]+([^ \t]+)", function(source)
          if not string.find(source, "echo%-cancel") then
            awful.spawn.easy_async("pactl set-sink-volume "..source.." +5%", function() end)
            indicator:setIcon()
          end
        end)
    end)
    indicator.tooltip.content.text = (tonumber(indicator.tooltip.content.text:match("%d+"))+5).." %"
    local width, height = indicator.tooltip.content:get_preferred_size(1)
    indicator.tooltip.height = height + 2
    indicator.tooltip.width = width + 4
  end),
  awful.button({ }, 5, function()
    awful.spawn.easy_async("pactl list sinks short", function(result)
       string.gsub("\n"..result, "\n[0-9]+[\t ]+([^ \t]+)", function(source)
          if not string.find(source, "echo%-cancel") then
            awful.spawn.easy_async("pactl set-sink-volume "..source.." -5%", function() end)
            indicator:setIcon()
          end
        end)
    end)
    indicator.tooltip.content.text = (tonumber(indicator.tooltip.content.text:match("%d+"))-5).." %"
    local width, height = indicator.tooltip.content:get_preferred_size(1)
    indicator.tooltip.height = height + 2
    indicator.tooltip.width = width + 4
  end)
))

return indicator
