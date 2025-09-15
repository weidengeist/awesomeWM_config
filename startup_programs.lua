local awful = require("awful")
local filesystem = require("gears.filesystem")
local naughty = require("naughty")
local timer = require("gears.timer")

local homeDir = filesystem.get_xdg_config_home():match("(.*)/.config")

local programs = {
	"mpd"
}

for _, v in ipairs(programs) do
	awful.spawn.easy_async('ps -x' , function(result)
		if not result:match(" "..v.."\n") then
			awful.spawn(v)
		end
	end)
end

awful.spawn.easy_async('bash -c "'..homeDir..'/.scripts/birthday-reminder.sh"', function() end)