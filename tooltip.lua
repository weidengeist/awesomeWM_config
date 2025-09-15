local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")
local awful = require("awful")

local tooltip = wibox{
	visible = false,
	shape = beautiful.tooltip_shape,
	ontop = true,
	border_width = beautiful.tooltip_border_width,
	border_color = beautiful.color,
	bg = beautiful.tooltip_bg,
	fg = beautiful.tooltip_fg,
  screen = awful.screen.focused()
}

tooltip.content = wibox.widget{
	text = "",
	align = "center",
	widget = wibox.widget.textbox	
}

tooltip.widget = tooltip.content

return tooltip
