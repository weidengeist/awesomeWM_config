local wibox = require("wibox")
local awful = require("awful")
local timer = require("gears.timer")
local shape = require("gears.shape")
local beautiful = require("beautiful")
local naughty = require("naughty")

--[[local handle = io.open("/archive/.tmp/calendarDatesTest", "r")
local personalDates = {}
line = handle:read("*line")
while line do
	local field = line:gsub("([0-9]*)%-([0-9]*)%-([0-9]*).*", function(a,b,c) return a..b..c end)
	if not personalDates[field] then
		personalDates[field] = " • "..line:match(" (.*)")
	else
		personalDates[field] = personalDates[field].."\n • "..line:match(" (.*)")
	end
	line = handle:read("*line")
end]]

function rgbToHex(color)
	local hexString = "#"
	local transform = {}
	for i, hex in ipairs({"a", "b", "c", "d", "e", "f"}) do
		transform[i+9] = hex
	end
	for _, c in ipairs({"r", "g", "b"}) do
		hexString = hexString..(transform[math.modf(color[c]/16)] or (math.modf(color[c]/16))) 
		hexString = hexString..(transform[color[c] % 16] or tostring(color[c] % 16))
	end
	return hexString
end

function hexToRgb(color)
	local color = color:lower()
	local transform = {a = 10, b = 11, c = 12, d = 13, e = 14, f = 15}
	local rgbColor = {}
	for i,c in ipairs({"r","g","b"}) do
		rgbColor[c] = 0
		rgbColor[c] = rgbColor[c] + (transform[color:sub((i-1)*2+2,(i-1)*2+2)] or tonumber(color:sub((i-1)*2+2,(i-1)*2+2)))*16 
		rgbColor[c] = rgbColor[c] + (transform[color:sub((i-1)*2+3,(i-1)*2+3)] or tonumber(color:sub((i-1)*2+3,(i-1)*2+3)))
	end
	return rgbColor
end

function shade(color1, color2, percentage)
	if color1:match("#") then
		color1 = hexToRgb(color1)
	end
	if color2:match("#") then
		color2 = hexToRgb(color2)
	end
	return {
		r = math.floor(color1.r + (color2.r - color1.r) * percentage),
		g = math.floor(color1.g + (color2.g - color1.g) * percentage),
		b = math.floor(color1.b + (color2.b - color1.b) * percentage)
	}
end

os.setlocale(os.getenv("LC_TIME"), "time")

local clock = wibox.widget{
	widget = wibox.widget.textbox,
	text = "Mo., 28. Dez. — 00:00 Uhr   ",
	font = beautiful.clock_font,
	align = "right"
}

-- set actual time
clock.dateformat = "%a., %d. %b. — %H:%M Uhr  "
clock.text = os.date(clock.dateformat)
clock.forced_width = clock:get_preferred_size(1) * 1.1


-- sync time with OS only once, afterwards update every 60 seconds
timer.start_new(60 - os.date("%S"), function()
	clock.text = os.date(clock.dateformat)
	clock.timer = timer{
		timeout = 60,
		autostart = true,
		callback = function()
      clock.text = os.date(clock.dateformat)
      clock.timer.timeout = 60 - os.date("%S")
    end
	}
end)


	

--[[####################################
    ## create calendar for left-click ##
    ####################################]]

-------------
-- headers --
-------------
local yearHeader = wibox.widget{
	widget = wibox.container.background,
	{
		widget = wibox.widget.textbox,
		text = " ",
		align = "center"
	}
}
local _, h = yearHeader:get_all_children()[1]:get_preferred_size(1)
yearHeader.forced_height = h + 2

local monthHeader = wibox.widget{
	widget = wibox.container.background,
	{
		widget = wibox.widget.textbox,
		text = " ",
		align = "center",
		font = beautiful.font:match("[^%d]*").."Bold "..beautiful.font:match("%d")
	}
}
local _, h = monthHeader:get_all_children()[1]:get_preferred_size(1)
monthHeader.forced_height = h + 4

--------------------
-- calendar sheet --
--------------------
local calSheet = wibox.widget{
	layout = wibox.layout.grid,
	homogeneous = true,
	orientation = "horizontal",
	min_cols_size = 15,
	min_rows_size = 15,
	expand = true
}

-----------------------------
-- populate calendar sheet --
-----------------------------
function populateCalendar(now)
	calSheet:reset()

	-- top-left corner of calendarium
	local widget = wibox.widget{
		widget = wibox.container.background,
		bg = beautiful.bg_focus.."dd",
		{
			widget = wibox.widget.textbox,
			text = ""
		}
	}
	calSheet:add_widget_at(widget, 1, 1, 1, 1)

	-- weekdays header
	for i = 1, 7 do
		local weekDay = os.date('%a',os.time{year=1,day=i,month=1})
		local widget = wibox.widget{
			widget = wibox.container.background,
			bg = beautiful.bg_focus.."dd",
			{
				widget = wibox.widget.textbox,
				text = weekDay,
				align = "center"
			}
		}
		calSheet:add_widget_at(widget, 1, i+1, 1, 1)
	end

	if tostring(now.year) == os.date("%Y")
	and tostring(now.month) == os.date("%m"):gsub("^0","") then
		now = os.date("*t")
	end

	yearHeader:get_all_children()[1].text = "⸺".." "..now.year.." ".."⸺"
	monthHeader:get_all_children()[1].text = "• "..os.date("%B", os.time(now)).." •"

	local daysInCurrMonth = os.difftime(
		os.time({year = now.year, month = now.month + 1, day = 1}),
		os.time({year = now.year, month = now.month, day = 1})
	) / 24 / 3600

  -- compensate summer time
  daysInCurrMonth = math.floor(daysInCurrMonth + 0.5)

	local firstWeekOfMonth = os.date("%V", os.time{year = now.year, month = now.month, day = 1})

	local weeksInCurrMonth = os.date("%V", os.time{year = now.year, month = now.month + 1, day = 1}) - firstWeekOfMonth

	if os.date("%w", os.time{year = now.year, month = now.month + 1, day = 1}) ~= "1" then
		weeksInCurrMonth = weeksInCurrMonth + 1
	end

	local row = 2
	for i = 1, daysInCurrMonth do
		local entity = wibox.widget{
			widget = wibox.container.background,
			shape_border_color = beautiful.fg_normal.."88",
			{
				widget = wibox.widget.textbox,
				text = i,
				align = "center"
			}
		}
    if i == now.day
		and tostring(now.year) == os.date("%Y")
		and tostring(now.month) == os.date("%m"):gsub("^0","") then
			entity.shape = function(c,w,h) shape.rounded_rect(c,w,h,3) end
			entity.shape_border_width = 1
		end
		local personalMemo = nil --personalDates[tostring(now.year)..(#tostring(now.month) == 1 and "0"..tostring(now.month) or tostring(now.month))..(#tostring(i) == 1 and "0"..tostring(i) or tostring(i))]
		if personalMemo then
			entity.bg = rgbToHex(shade(beautiful.bg_focus, beautiful.bg_normal, 0.5))
			entity.tooltip = require("tooltip")
			entity.tooltip.content.align = "left"
			entity:connect_signal("mouse::enter", function(c, geo)
				print(geo.x)
				c.tooltip.content.text = personalMemo
				local width, height = c.tooltip.content:get_preferred_size(1)
				c.tooltip.width = width + 4
				c.tooltip.height = height + 2
				c.tooltip.x = math.min(
					geo.x + 0.5 * (geo.width - c.tooltip.width) + clock.calendar.x,
					awful.screen.focused().workarea.width - c.tooltip.width - 4
				)
        c.tooltip.screen = awful.screen.focused()
				c.tooltip.y = clock.calendar.y + geo.y - c.tooltip.height
				c.tooltip.timer = timer{
					timeout = 1,
					autostart = true,
					callback = function() c.tooltip.visible = true end,
					single_shot = true
				}
			end)
			entity:connect_signal("mouse::leave", function(c)
				if c.tooltip.timer.started then
					c.tooltip.timer:stop()
				end
					c.tooltip.visible = false
					collectgarbage("collect")
			end)
		end
		local weekNumber = os.date("%V", os.time{year= now.year, month = now.month, day = i})
		local weekday = os.date("%w", os.time{year= now.year, month = now.month, day = i})
		if weekday == "1" or i == 1 then
			local weekNumberWidget = wibox.widget{
				widget = wibox.container.background,
				bg = beautiful.bg_focus.."dd",
				{
					widget = wibox.widget.textbox,
					text = os.date("%V", os.time{year = now.year, month = now.month, day = i}),
					align = "center"
				}
			}
			calSheet:add_widget_at(weekNumberWidget, row, 1, 1, 1)
		end
		calSheet:add_widget_at(entity, row, (weekday - 1) % 7 + 2, 1, 1)
		if weekday == "0" then row = row + 1 end
	end

	local rows = calSheet:get_dimension()
	if rows < 7 then
		local entity = wibox.widget{
			widget = wibox.container.background,
			bg = beautiful.bg_focus.."dd",
			{
				widget = wibox.widget.textbox,
				text = ""
			}
		}
		calSheet:add_widget_at(entity, rows+1, 1, 7-rows, 1)
	end
end

-------------------------------
-- compose complete calendar --
-------------------------------
clock.calendar = wibox{
	x = 500,
	y = 500,
	width = 180,
	height = 100,
	ontop = true,
	shape = beautiful.notification_shape,
	border_width = beautiful.border_width,
	border_color = beautiful.border_normal,
	bg = beautiful.bg_normal..beautiful.bg_overlay_opacity,
	widget = wibox.widget
	{
		widget = wibox.container.margin,
		margins = 5,
		{
			layout = wibox.layout.align.horizontal,
			nil,
			wibox.widget{
				layout = wibox.layout.fixed.vertical,
				yearHeader,
				monthHeader,
				calSheet
			},
			nil
		}
	}
}

clock.calendar.height = 2 * clock.calendar.widget:get_top() + yearHeader.forced_height + monthHeader.forced_height + 7 * 15


local now = os.date("*t")

clock.calendar.displayedDate = now
populateCalendar(now)


function clock:applyColors()
	self.calendar.bg = beautiful.bg_normal..beautiful.bg_overlay_opacity
	self.calendar.border_color = beautiful.border_normal
	self.calendar.border_width = beautiful.border_width
	self.calendar.shape = beautiful.notification_shape

	yearHeader.fg = beautiful.fg_normal
	monthHeader.fg = beautiful.fg_normal	
	self.calendar.fg = beautiful.fg_normal

	for i = 1, 7 do
		calSheet:get_widgets_at(i,1)[1].bg = beautiful.bg_focus.."dd"
		calSheet:get_widgets_at(1,i)[1].bg = beautiful.bg_focus.."dd"
	end
	calSheet:get_widgets_at(1,8)[1].bg = beautiful.bg_focus.."dd"

	self.tooltip.fg = beautiful.tooltip_fg
	self.tooltip.bg = beautiful.tooltip_bg
	collectgarbage("collect")
end



--[[###########################
    ## signals and callbacks ##
    ###########################]]

clock:buttons(
awful.button({}, 1, nil,
	function ()
		clock.calendar.visible = not clock.calendar.visible
		clock.calendar.displayedDate = os.date("*t")
		populateCalendar(clock.calendar.displayedDate)
	end)
)

clock.tooltip = require("tooltip")

clock:connect_signal("mouse::enter", function(c, geo, a, b, e, f, h)
	c.tooltip.content.text = os.date("%a, %d. %b. %Y")
	c.tooltip.content.align = "center"
	c.tooltip.screen = awful.screen.focused()
	local width, height = c.tooltip.content:get_preferred_size(c.tooltip.screen)
	c.tooltip.width = width + 4
	c.tooltip.height = height + 2
  c.tooltip.x = c.tooltip.screen.geometry.x + math.min(
    geo.x + 0.5 * (geo.width - c.tooltip.width),
		c.tooltip.screen.workarea.width - c.tooltip.width - 4
	)
	c.calendar.x = c.tooltip.screen.geometry.x + math.min(
		geo.x + 0.5 * (geo.width - c.calendar.width),
		awful.screen.focused().workarea.width - c.calendar.width - 4
	)
  if geo.y == 0 then
		c.calendar.y = geo.height + 4
		c.tooltip.y = geo.height + 4
	else
		c.tooltip.y = geo.y - geo.height - 4
		c.calendar.y = geo.y - geo.height - 4
	end
	c.tooltip.timer = timer{
		timeout = 1,
		autostart = true,
		callback = function() c.tooltip.visible = true end,
		single_shot = true
	}
end)

clock:connect_signal("mouse::leave", function(c)
	if c.tooltip.timer.started then
		c.tooltip.timer:stop()
	end
	c.tooltip.visible = false
  collectgarbage("collect")
end)

yearHeader:connect_signal("button::press", function(c,_,_,button)
	if button == 5 then
		local d = clock.calendar.displayedDate
		d = os.time{year = d.year+1, month = d.month, day = 1}
		clock.calendar.displayedDate = os.date("*t", d)
		populateCalendar(clock.calendar.displayedDate)
	end
	if button == 4 then
		local d = clock.calendar.displayedDate
		d = os.time{year = d.year-1, month = d.month, day = 1}
		clock.calendar.displayedDate = os.date("*t", d)
		populateCalendar(clock.calendar.displayedDate)
	end
	collectgarbage("collect")
end)

monthHeader:connect_signal("button::press", function(c,_,_,button)
	if button == 5 then
		local d = clock.calendar.displayedDate
		d = os.time{year = d.year, month = d.month+1, day = 1}
		clock.calendar.displayedDate = os.date("*t", d)
		populateCalendar(clock.calendar.displayedDate)
	end
	if button == 4 then
		local d = clock.calendar.displayedDate
		d = os.time{year = d.year, month = d.month-1, day = 1}
		clock.calendar.displayedDate = os.date("*t", d)
		populateCalendar(clock.calendar.displayedDate)
	end
	collectgarbage("collect")
end)

return clock
