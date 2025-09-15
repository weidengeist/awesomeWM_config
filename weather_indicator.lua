local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

-- get weather data from wttr.in
local location = "Leipzig"
local language = os.setlocale(os.getenv("LC_TIME"), "time"):match("(%a+)_")

local iconPrefix = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/weather_"
local conditionImages = {
	en ={
		{"No data available.", "unknown"},
		{"[Mm]ist", "mist"},
		{"[Ff]og", "mist"},
		{"[Ss]un", "clear"},
		{"[Cc]lear", "clear"},
		{"[Ss]now", "snow"},
		{"[Rr]ain", "rain"},
		{"[Ss]hower", "rain"},
		{"[Dd]rizzle", "rain"},
		{"[Cc]loudy", "cloudy"},
		{"[Oo]vercast", "cloudy"},
		{"[Tt]hunder", "thunderstorm"},
	},
	de ={
		{"Keine Wetterdaten verfügbar.", "unknown"},
		{"[Nn]ebel", "mist"},
		{"[Ff]og", "mist"},
		{"[Ss]onn", "clear"},
		{"[Kk]lar", "clear"},
		{"[Ss]chnee", "snow"},
		{"[Rr]eg[e]?n", "rain"},
		{"[Ww][oö]*lk", "cloudy"},
		{"[Bb]edeckt", "cloudy"},
		{"[Gg]ewitt", "thunderstorm"},
		{"[Ss]chauer", "rain"},
	}
}
local daytimes = {
	en = {"morning", "noon", "evening", "night"},
	de = {"früh", "mittags", "abends", "nachts"}
}


local function createForecastTable(t, c)
	local tempLength = utf8.len(t[2])
	local condLength = utf8.len(c[2])

	local dateLength = string.len(os.date('%a, %d.%m.', os.time()))

	weatherString = "┌Today"..string.rep("─", dateLength+1-5).."┬"..string.rep("─", tempLength+2).."┬"..string.rep("─", condLength+2).."┐\n"
	local date = os.date('%a, %d.%m.', os.time())
	for i = 2, #t do
		if i % 4 == 2 and i > 2 then
			date = os.date('%a, %d.%m.', os.time() + math.modf((i-2)/4)*3600*24)
			weatherString = weatherString.."├"..date.."─┼"..string.rep("─", tempLength+2).."┼"..string.rep("─", condLength+2).."┤\n"
		end
		weatherString = weatherString.."│"..
			string.rep(" ", dateLength - utf8.len(daytimes[language][(i-2)%4+1]))..daytimes[language][(i-2)%4+1].." │ "..
			string.rep(" ", tempLength - utf8.len(t[i]))..t[i].." │ "..
			string.rep(" ", condLength - utf8.len(c[i]))..c[i].." │\n"
	end
		
	weatherString = weatherString.."└"..string.rep("─", dateLength+1).."┴"..string.rep("─", tempLength+2).."┴"..string.rep("─", condLength+2).."┘"
	return weatherString
end


local function setWidgetValues(t, c, s)
	if t then
		weather:get_all_children()[1].text = t
		weather.condition = c
		weather.forecast.widget.markup = s

		local width, height = weather.forecast.widget:get_preferred_size(1)
		weather.forecast.width, weather.forecast.height = width + 8, height + 4

		for i,v in ipairs(conditionImages[language]) do
			if weather.condition:match(v[1]) then
				weather:get_all_children()[3].image = iconPrefix..v[2]..".symbolic.png"
				break
			end
		end
	end
end


local function getWeatherData_wttrIn()
	local dateLength = string.len(os.date('%a, %d.%m.', os.time()))
	local temperatures = {}
	local conditions = {}

	awful.spawn.easy_async("curl wttr.in/"..location.."?lang="..language, function(result)
		if result:match("°C") then
			-- remove color codes from resulting string
			result = (result:gsub("\x1B%[[0-9;]*[Jkmsu]",""))
		
			local maxTempLength = 0
			result:gsub("[%-%+]*[0-9]*%(*[%-%+]*[0-9]*%)* °C", function(a)
				temperatures[#temperatures+1] = a:gsub("%-", "−"):gsub("%+", ""):gsub("%(", " (")
				maxTempLength = math.max(maxTempLength, utf8.len(temperatures[#temperatures]))
			end)
	
			for i, v in ipairs(temperatures) do
				while utf8.len(v) < maxTempLength and i > 1 do
					v = " "..v
				end
				temperatures[i] = v
			end
	
			conditions[1] = result:match(".-: "..location.."\n.-\n.-([A-z][A-zäöüß ]+[A-z][…]*)\n")
			local maxCondLength = 0
			result:gsub("┤\n│(.-)\n", function(a)
				a:gsub("[%s%p]*([A-z][A-zäöüß ]+[A-z][…]*)%s*│", function(b)
					maxCondLength = math.max(maxCondLength, utf8.len(b))
					conditions[#conditions+1] = b
				end)
			end)
	
			for i, v in ipairs(conditions) do
				while utf8.len(v) < maxCondLength and i > 1 do
					v = " "..v
				end
				conditions[i] = v
			end

			setWidgetValues(temperatures[1], conditions[1], createForecastTable(temperatures, conditions))
		else
			if weather:get_all_children()[1].text:match("°C") and not weather:get_all_children()[1].text:match("(!)") then
				weather:get_all_children()[1].text = weather:get_all_children()[1].text..(" (!)")
			end
		end
	end)
end


local function getWeatherDB_wetterDe()

end	


weather = wibox.widget{
	layout = wibox.layout.align.horizontal,
	{
		widget = wibox.widget.textbox,
		text = "?",
		font = "Georgia Bold 8",
		align = "left"
	},
	{
		widget = wibox.container.margin,
		top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
		bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
		left = 10,
		{
			widget = wibox.widget.imagebox,
			image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/weather_unknown.symbolic.png"
		}
	}
}

weather.condition = conditionImages[language][1][1]
getWeatherData_wttrIn()


weather:buttons(
	awful.button({ }, 1,
		function()
			weather.forecast.visible = not weather.forecast.visible
		end
	)
)

weather.forecast = wibox({
	visible = false,
	bg = beautiful.bg_normal..beautiful.bg_overlay_opacity,
	fg = beautiful.fg_normal,
	ontop = true,
	shape = function(cr, width, height) gears.shape.rounded_rect(cr, width, height, 8) end,
	border_width = beautiful.border_width,
	border_color = beautiful.border_normal,
	widget = wibox.widget{
		align  = 'center',
    valign = 'center',
    widget = wibox.widget.textbox,
		font = 'monofur 8',
		text = conditionImages[language][1][1]
	}
})

local width, height = weather.forecast.widget:get_preferred_size(1)
weather.forecast.width, weather.forecast.height = width + 8, height + 4

weather.timer = gears.timer{
	timeout = 600,
	autostart = true,
	callback = getWeatherData_wttrIn
}

function weather:applyColors()
	self.forecast.bg = beautiful.bg_normal..beautiful.bg_overlay_opacity
	self.forecast.fg = beautiful.fg_normal
	self.forecast.border_color = beautiful.border_normal
	
	iconPrefix = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/weather_"
	for i,v in ipairs(conditionImages[language]) do
		if weather.condition:match(v[1]) then
			weather:get_all_children()[3].image = iconPrefix..v[2]..".symbolic.png"
		end
	end
end

weather.tooltip = require("tooltip")

weather:connect_signal("mouse::enter", function(w, geo)
	w.tooltip.content.text = w.condition
	w.tooltip.content.align = "center"
  w.tooltip.screen = awful.screen.focused()
	local width, height = w.tooltip.content:get_preferred_size(1)
	w.tooltip.width = width + 4
	w.tooltip.height = height + 2
	w.tooltip.x = w.tooltip.screen.geometry.x + math.min(
		geo.x + 0.5 * (geo.width - w.tooltip.width),
		awful.screen.focused().workarea.width - w.tooltip.width - 4
	)
	w.forecast.x = w.tooltip.screen.geometry.x + math.min(
		geo.x + 0.5 * (geo.width - w.forecast.width),
		awful.screen.focused().workarea.width - w.forecast.width - 4
	)
	if geo.y == 0 then
		w.tooltip.y = geo.height + 4
		w.forecast.y = geo.height + 4
	else
		w.tooltip.y = geo.height - 4
		w.forecast.y = geo.height - 4
	end
	w.tooltip.timer = gears.timer{
		timeout = 1,
		autostart = true,
		callback = function() w.tooltip.visible = true end,
		single_shot = true
	}
end)

weather:connect_signal("mouse::leave", function(w)
	if w.tooltip.timer.started then
		w.tooltip.timer:stop()
	end
	w.tooltip.visible = false
end)

-- get weather when starting awesome
getWeatherData_wttrIn()

return weather
