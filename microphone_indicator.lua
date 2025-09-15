local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")
local color = require("gears.color")
local naughty = require("naughty")
local filesystem = require("gears.filesystem")


mic_indicator = wibox.widget{
  widget = wibox.container.margin,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  {
    widget = wibox.widget.imagebox,
  }
}

mic_indicator:buttons(
  awful.button({}, 1, function(test)
    awful.spawn.easy_async('python "' .. filesystem.get_configuration_dir() .. '/audioSwitching.py" toggleMicMuteStatus', function()
      mic_indicator:getMicMuteStatus()
    end)
  end)
)

function mic_indicator:getMicMuteStatus()
  imageMuted = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/microphone-sensitivity-muted.symbolic.png"
  imageActive = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/microphone-sensitivity-high.symbolic.png"
  awful.spawn.easy_async('pactl info', function(sink, err, errReason)
    print("MIC MUTE STATUS: ", sink, err, errReason)
    if #sink > 0 then
      awful.spawn.easy_async('python "' .. filesystem.get_configuration_dir() .. '/audioSwitching.py" getMicMuteStatus', function(result, a, b, c)
        print("RESULT: ", result)
        if string.match(result, "yes") then
          self:get_all_children()[1].image = imageMuted
        else
          self:get_all_children()[1].image = imageActive
        end
        if self.defaultSinkTimer.started then
          self.defaultSinkTimer:stop()
        end
      end)
    else
      self.defaultSinkTimer:start()
    end
  end)
end

mic_indicator.defaultSinkTimer = timer{
  timeout = 1,
  autostart = false,
  callback = mic_indicator:getMicMuteStatus()
}

function mic_indicator:applyColors()
  mic_indicator:getMicMuteStatus()
  collectgarbage("collect")
end

mic_indicator:getMicMuteStatus()

return mic_indicator
