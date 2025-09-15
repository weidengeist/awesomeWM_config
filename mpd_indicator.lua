local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local shape = require("gears.shape")
local timer = require("gears.timer")
local table = require("gears.table")
local color = require("gears.color")
local filesystem = require("gears.filesystem")

local confDir = filesystem.get_configuration_dir()

local handle = io.popen('cat ~/.mpd/mpd.conf | grep music_directory.*/')
local musicDir = handle:read("*all"):match('"(.*)"')
handle:close()

local function secondsToTime(seconds)
  local string = tostring(math.modf(seconds % 60))
  if #string < 2 then
    string = "0"..string
  end
  local remaining = (seconds - (seconds % 60)) / 60
  while remaining > 0 do
    if #(tostring(math.modf(remaining % 60))) == 1 then
      string = "0"..tostring(math.modf(remaining % 60))..":"..string
    else
      string = tostring(math.modf(remaining % 60))..":"..string
    end
    remaining = (remaining - (remaining % 60)) / 60
  end
  if #string == 1 then
    string = "00:0"..string
  elseif #string == 2 then
    string = "00:"..string
  end
  return string
end

--[[###############################################
    ### control panel components (no callbacks) ###
    ###############################################]]

local margin_width = 10

-----------------
-- base window --
-----------------
local controlLayout = wibox.layout{
  layout = wibox.layout.manual,
}

local controlPanel = wibox{
  -- size and position will be calculated later (subsection "special buttons")
  bg = beautiful.bg_normal..beautiful.bg_overlay_opacity,
  visible = false,
  shape = function(c, w, h) shape.rounded_rect(c, w, h, 4) end,
  border_width = beautiful.border_width,
  border_color = beautiful.border_normal,
  widget = controlLayout,
  ontop = true,
  connected = false
}

---------------
-- cover art --
---------------
local cover = wibox.widget{
  widget = wibox.widget.imagebox,
  image = beautiful.path.."/icons/null.png",
  forced_width = 100,
  forced_height = 100,
  margin = 4
}

local coverBox = wibox.container.background()
coverBox:setup{
  layout = wibox.layout.fixed.horizontal,
  {
    widget = wibox.container.background,
    shape = function(c, w, h) shape.rounded_rect(c, w, h, 2) end,
    shape_border_width = 1,
    shape_border_color = beautiful.border_normal,
    {
      widget = wibox.container.margin,
      margins = cover.margin,
      {
        widget = cover
      },
    },
  },
}
controlLayout:add_at(coverBox, {
  x = margin_width - cover.margin,
  y = margin_width - cover.margin
})

controlPanel.height = margin_width + cover.forced_height + margin_width
controlPanel.width = 2 * margin_width + 3* cover.forced_width

-------------------------
-- seeker/progress bar --
-------------------------
local seeker = wibox.widget{
  {
    widget = wibox.widget.progressbar,
    max_value = 1,
    value = 0,
    border_width = beautiful.progressbar_border_width,
    border_color = beautiful.progressbar_border_color,
    forced_width = controlPanel.width - 3 * margin_width - cover.forced_width - cover.margin,
    forced_height = 10,
    shape = function(c, w, h) shape.rounded_rect(c, w, h, 5) end,
    bar_shape = function(c,w,h) shape.rounded_rect(c, w, h, 4) end,
    background_color = beautiful.progressbar_bg,
    color = beautiful.bg_focus
  },
  {
    {
      widget = wibox.widget.textbox,
      text = "0:00",
      align = "center"
    },
    fg = beautiful.progressbar_fg,
    widget = wibox.container.background
  },
  layout = wibox.layout.stack  
}

local _,height = seeker:get_all_children()[3]:get_preferred_size()
seeker:get_all_children()[1].forced_height = height
seeker:get_all_children()[3].text = ""

-- timer for capturing changing songs and playtime
seeker.timer = timer{
  timeout = 1,
  autostart = false,
  callback = function() seeker:update() end
}

seeker.coords = {
  x = 2 * margin_width + cover.forced_width + cover.margin,
  y = controlPanel.height - margin_width + cover.margin - seeker:get_children()[1].forced_height
}
controlLayout:add_at(seeker, seeker.coords)

----------------------
-- playback buttons --
----------------------
prevButton = wibox.widget.imagebox()
stopButton = wibox.widget.imagebox()
playButton = wibox.widget.imagebox()
nextButton = wibox.widget.imagebox()
queryButton = wibox.widget.imagebox()

local playbackButtons = {prevButton, stopButton, playButton, nextButton, queryButton}

for i,b in ipairs(playbackButtons) do
  b.forced_width = 12
  b.forced_height = 12
  b.opacity = 0.5
  b.align = "center"
    
  if i == 1 then
    b.image = beautiful.icons_path.."/actions/16/media-skip-backward.png"
  elseif i == 2 then
    b.image = beautiful.icons_path.."/actions/16/media-playback-stop.png"
  elseif i == 3 then
    b.image = beautiful.icons_path.."/actions/16/media-playback-start.png"
  elseif i == 4 then
    b.image = beautiful.icons_path.."/actions/16/media-skip-forward.png"
  elseif i == 5 then
    b.image = beautiful.icons_path.."/status/16/mpd_query.png"
  end

  b:connect_signal("mouse::enter", function(b)
    b.opacity = 1.0
    b:emit_signal("widget::redraw_needed")
  end)

  b:connect_signal("mouse::leave", function(b)
    b.opacity = 0.5
    b:emit_signal("widget::redraw_needed")
  end)
end

-- create a (decorated) group of playback buttons
local buttonSpacing = 5
local hlineSpacing = 2

local playbackButtonsPanel = wibox.widget{
  widget = wibox.container.background,
  shape = function(c,w,h) shape.rectangle(c,w,1) end,
  fg = beautiful.fg_minimize,
  bg = beautiful.fg_minimize,
  {
    widget = wibox.container.margin,
    top = hlineSpacing,
    {
      layout = wibox.layout.fixed.horizontal,
      prevButton,
      stopButton,
      playButton,
      nextButton,
      queryButton,
      spacing = buttonSpacing,
    },
  },
}

playbackButtonsPanel.coords = {
  x = controlPanel.width - margin_width - #playbackButtons * (playbackButtons[1].forced_width + buttonSpacing) + buttonSpacing,
  y = margin_width - cover.margin
}
controlLayout:add_at(playbackButtonsPanel, playbackButtonsPanel.coords)

-----------------------
-- song info textbox --
-----------------------
local songInfo = wibox.widget{
  widget = wibox.container.background,
  {
    widget = wibox.widget.textbox,
    forced_width = seeker:get_all_children()[1].forced_width,
    forced_height = seeker.coords.y - playbackButtonsPanel.coords.y - prevButton.forced_height - hlineSpacing,
    valign = "center",
    markup = "<b>No running MPD instance!</b>"
  }
}

songInfo.coords = {
  x = 2 * margin_width + cover.forced_width + cover.margin,
  y = playbackButtonsPanel.coords.y + prevButton.forced_height
}
controlLayout:add_at(songInfo, songInfo.coords) 

--[[#############################
    ### signals and callbacks ###
    #############################]]

function setIdlePlayback()
  --~ awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "idle player"', function()
    --~ seeker.timer:again()
    --~ seeker:update()
    --~ songInfo:update()
    --~ setIdlePlayback()
  --~ end)
end

mpdTimer = timer{
  timeout = 1,
  autostart = true,
  callback = function()
    awful.spawn.easy_async('ps -e', function(result)
      if result:match("[0-9]* mpd\n") then
        songInfo:get_all_children()[1].markup = "<b>MPD up and running</b>"
        setIdlePlayback()
        mpdTimer:stop()
      end
    end)
  end
}

function songInfo:update()
  --~ awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status state"', function(state)
    --~ if state:match("stop") then
      --~ self:get_all_children()[1].markup = "<b>Stopped</b>"
    --~ else
      --~ awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "song"', function(song)
        --~ if #song > 0 then
          --~ local artist = song:match("Artist: (.-)\n"):gsub("&", "&amp;")
          --~ local album = song:match("Album: (.-)\n"):gsub("&", "&amp;")
          --~ local date = song:match("Date: (.-)\n")
          --~ local title = song:match("Title: (.-)\n"):gsub("&", "&amp;")
          --~ local file = song:match("file: (.-)\n")
          
          --~ local currentSong = self:get_all_children()[1].markup

          --~ if not currentSong:match("<b>"..title.."</b>") or not currentSong:match(artist) then
            --~ if not currentSong:match(album) or not currentSong:match(artist) then
              --~ local songDir = musicDir.."/"..file:match("(.*)/.*")
              --~ print("songdir", songDir)
              --~ awful.spawn.easy_async([[find "]]..songDir..[[" -regextype sed -maxdepth 1 -regex ".*cover\.\(jpe\?g\|png\)"]], function(coverPath)
                --~ print("cover", coverPath)
                --~ if coverPath and coverPath ~= "" then
                  --~ cover.image = coverPath:gsub("\n$","")
                --~ end
              --~ end)
            --~ end
            --~ -- put title, artist and album in [[…]] to prevent problems with »&« symbols
            --~ self:get_all_children()[1].markup = "<b>"..title.."</b>\nby "..artist.." from »"..album.."« ("..date..")"
            --~ collectgarbage("collect")
          --~ end
        --~ end
        --~ collectgarbage("collect")
      --~ end)
    --~ end
    --~ collectgarbage("collect")
  --~ end)
  --~ collectgarbage("collect")
end

-----------------------------------------------------
-- update seeker, song info, and play button state --
-----------------------------------------------------
function seeker:update()
  --~ awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status"', function(status)
    --~ local progressbar = self:get_all_children()[1]
    --~ local textWidget = self:get_all_children()[3]

    --~ local state = status:match('state: (%a+)') or ""
    
    --~ if state:match("stop") then
      --~ playButton.image = beautiful.icons_path.."/actions/16/media-playback-start.png"
      --~ progressbar.value = 0
      --~ textWidget.text = ""
    --~ elseif state:match("pause") then
      --~ playButton.image = beautiful.icons_path.."/actions/16/media-playback-start.png"
    --~ elseif state:match("play") then
      --~ playButton.image = beautiful.icons_path.."/actions/16/media-playback-pause.png"
      --~ songPos, songTime = status:match('time: (%d+):(%d+)')
      --~ progressbar.value = tonumber(songPos / songTime)
      --~ textWidget.text = secondsToTime(songPos).."/"..secondsToTime(songTime)
    --~ end
  --~ collectgarbage("collect")
  --~ end)
end

------------------------------------------------
-- enable seeking via the seeker/progress bar --
------------------------------------------------
seeker:buttons(
  awful.button({}, 1, function(s)
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status state"', function(state)
      if not state:match('stop') then
        local relPos = (mouse.coords().x - controlPanel.x - seeker.coords.x) / seeker:get_all_children()[1].forced_width
        seeker:get_all_children()[1].value = relPos
        awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "song duration"', function(dur)
          awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "seek '..(relPos * tonumber(dur))..'"', function()
            seeker:update()
          end)
        end)
      end
    end)
    collectgarbage("collect")
  end)
)

--------------------------------
-- playback buttons callbacks --
--------------------------------
playButton:buttons(
  awful.button({}, 1, function()
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status state"', function(state)
      if state:match('play') or state:match('pause') then
        awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "pause"', function() seeker:update() end)
      elseif state:match('stop') then
        awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "play"', function() seeker:update() end)
      end
    end)
  collectgarbage("collect")
  end)
)

stopButton:buttons(
  awful.button({}, 1, function()
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "stop"', function() end)
  end)
)

prevButton:buttons(
  awful.button({}, 1, function()
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "previous"', function() end)
  end)
)

nextButton:buttons(
  awful.button({}, 1, function()
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "next"', function() end)
  end)
)

queryButton:buttons(
  awful.button({ }, 1, function()
    local title = "Query MPD database"
    awful.spawn.single_instance(terminal..' -hold -name "mpd" -title "'..title..'" -e lua '..confDir..'mpd_backend.lua', {instance = "mpd"})
  end)
)


--[[#####################
    ### tasklist icon ###
    #####################]]

local indicator = wibox.widget{
  widget = wibox.container.margin,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  {
    widget = wibox.widget.imagebox,
    image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/mpd_indicator.png",
  }
}

function indicator:applyColors()
  self:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.panel_icons_size.."/mpd_indicator.png"
  
  controlPanel.bg = beautiful.bg_normal..beautiful.bg_overlay_opacity
  controlPanel.border_color = beautiful.border_normal
  
  coverBox.widget:get_all_children()[1].shape_border_color = beautiful.border_normal

  prevButton.image = beautiful.icons_path.."/actions/16/media-skip-backward.png"
  stopButton.image = beautiful.icons_path.."/actions/16/media-playback-stop.png"
  playButton.image = beautiful.icons_path.."/actions/16/media-playback-start.png"
  nextButton.image = beautiful.icons_path.."/actions/16/media-skip-forward.png"
  queryButton.image = beautiful.icons_path.."/status/16/mpd_query.png"

  playbackButtonsPanel.bg = beautiful.fg_minimize

  songInfo.fg = beautiful.fg_normal
  
  seeker:get_all_children()[1].border_width = beautiful.progressbar_border_width
  seeker:get_all_children()[1].border_color = beautiful.progressbar_border_color
  seeker:get_all_children()[1].background_color = beautiful.progressbar_bg
  seeker:get_all_children()[1].color = beautiful.bg_focus
  seeker:get_all_children()[2].fg = beautiful.progressbar_fg
end

indicator:connect_signal("button::press", function(_,_,_,button,_,geo)
  if button == 1 then
    controlPanel.x = awful.screen.focused().geometry.x + math.min(
      geo.x + 0.5 * (geo.width - controlPanel.width),
      awful.screen.focused().workarea.width - controlPanel.width - 4
    )
    if geo.y == 0 then
      controlPanel.y = geo.height + 4
    else
      controlPanel.y = geo.height - 4
    end
    controlPanel.visible = not controlPanel.visible
    if controlPanel.visible then
      songInfo:update()
      seeker:update()
    end
  elseif button == 3 then
    --awful.spawn.easy_async('lua /archive/.tmp/mpd_frontend.lua', function() end)
    local spawnable = true
    local clients = client.get(nil, false)
    for i, c in ipairs(clients) do
      if c.role and c.role == "mpd_frontend" then
        spawnable = false
        c:raise()
        if c.minimized then c.minimized = false end
        client.focus = c
        break
      end
    end
    if spawnable then
      print('python '..filesystem.get_xdg_config_home():match("(.*/).config")..".scripts/mpd_gui.py")
      awful.spawn.easy_async('python '..filesystem.get_xdg_config_home():match("(.*/).config")..".scripts/mpd_gui.py", function(a, b, c, d) print(a, b, c, d) end)
    end
  elseif button == 4 then
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status"', function(status)
      local vol = tonumber(status:match("volume: ([0-9]+)"))
      awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "volume '..(vol + 5)..'"', function() end)
    end)
  elseif button == 5 then
    awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "status"', function(status)
      local vol = tonumber(status:match("volume: ([0-9]+)"))
      awful.spawn.easy_async('lua '..confDir..'mpd_backend.lua "volume '..(vol - 5)..'"', function() end)
    end)
  end
end)

return indicator
