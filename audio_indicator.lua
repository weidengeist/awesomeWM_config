local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")
local color = require("gears.color")
local naughty = require("naughty")
local filesystem = require("gears.filesystem")


function getDefaultSink()
  imageSpeakers = beautiful.icons_path.."/devices/"..beautiful.panel_icons_size.."/audio-speakers.symbolic.png"
  imageHeadphones = beautiful.icons_path.."/devices/"..beautiful.panel_icons_size.."/audio-headphones.symbolic.png"
  awful.spawn.easy_async('pactl info', function(sink, err, errReason)
    if #sink > 1 then
      awful.spawn.easy_async('python "' .. filesystem.get_configuration_dir() .. '/audioSwitching.py" getDefaultOutput', function(result)
        print("CHecking result ", result)
        if string.match(result, "display") then
          audio_indicator:get_all_children()[1].image = imageSpeakers
        else
          audio_indicator:get_all_children()[1].image = imageHeadphones
        end
        if audio_indicator.defaultSinkTimer.started then
          audio_indicator.defaultSinkTimer:stop()
        end
      end)
    else
      audio_indicator.defaultSinkTimer:start()
    end
  end)
end


audio_indicator = wibox.widget{
  widget = wibox.container.margin,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  {
    widget = wibox.widget.imagebox,
  }
}

audio_indicator:buttons(
  awful.button({}, 1, function(test)
    awful.spawn.easy_async('python "' .. filesystem.get_configuration_dir() .. '/audioSwitching.py" switchDefaultOutput', function()
      getDefaultSink()
    end)
  end)
)

audio_indicator.defaultSinkTimer = timer{
  timeout = 1,
  autostart = false,
  callback = getDefaultSink()
}

getDefaultSink()

function audio_indicator:applyColors()
  getDefaultSink()
  collectgarbage("collect")
end

return audio_indicator
