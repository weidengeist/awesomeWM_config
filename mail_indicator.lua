local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")
local awful = require("awful")
local color = require("gears.color")

local function getmail()
	awful.spawn.easy_async('bash /archive/.mail/receiveMail.sh', function() end)
	collectgarbage("collect")
end

indicator = wibox.widget{
	widget = wibox.container.margin,
	top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
	bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
	{
		widget = wibox.widget.imagebox,
		image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/mail.png"
	}
}

indicator:buttons(
	awful.button({}, 1,	function()
		getmail()
		local spawnable = true
		local clients = client.get(nil, false)
		for i, c in ipairs(clients) do
			if c.class and c.class:match("^[Cc]laws%-mail$") then
				spawnable = false
				c:raise()
				if c.minimized then c.minimized = false end
				client.focus = c
				break
			end
		end
		if spawnable then
			awful.spawn.easy_async('claws-mail', function() end)
		end
		--awful.spawn.raise_or_spawn('claws-mail', {class = '[Cc]laws%-mail', callback = function(c) awful.spawn('claws-mail --receive') end})
	end)
)

function indicator:applyColors()
	self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/mail.png"
end

-- check for new mail every 30 seconds
indicator.timer = timer{
	timeout = 30,
	autostart = true,
	callback = getmail
}

getmail()

return indicator
