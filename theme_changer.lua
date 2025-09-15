local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")

local handle = io.popen("file "..beautiful.path.."/icons/theme_changer_prelight.png")
local result = handle:read("*all")
handle:close()

local w, h = result:match("([0-9]*) x ([0-9]*)")

local changer = wibox{
  width = w,
  height = h,
  x = awful.screen.focused().geometry.width - w,
  y = 0,
  bg = "#00000000",
  visible = true,
  widget = wibox.widget{
    widget = wibox.widget.imagebox,
    image = nil
  }
}

changer.theme1 = "Lumière_de_la_Lune"
changer.theme2 = "Esprit_d’Automne"

changer:connect_signal("mouse::enter", function(w)
  w.widget.image = beautiful.path.."/icons/theme_changer_prelight.png"
end)

changer:connect_signal("mouse::leave", function(w)
  w.widget.image = nil
end)

changer:connect_signal("button::press", function(_, _, _, button)
  if button == 1 then
    changeThemeColors()
  end
end)

function changer:applyColors()
  awful.spawn.easy_async("file "..beautiful.path.."/icons/theme_changer_prelight.png", function(result)
    local w, h = result:match("([0-9]*) x ([0-9]*)")
    self.width = w
    self.height = h
    self.x = awful.screen.focused().geometry.width - w
    self.widget.image = beautiful.path.."/icons/theme_changer_prelight.png"
  end)
end


return changer
