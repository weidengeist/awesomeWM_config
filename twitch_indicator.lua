local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local tableG = require("gears.table")
local shape = require("gears.shape")
local filesystem = require("gears.filesystem")
local timer = require("gears.timer")
local naughty = require("naughty")


local channels = {total = 0}
local isSilent = false

local twitchConfigDir = os.getenv("HOME").."/.config/twitch"

local clientID = ""
local oauth = ""
local apiURL = ""

local f = io.open(twitchConfigDir.."/clientID", "r")
if f then
  clientID = f:read("*line")
  f:close()
end

local f = io.open(twitchConfigDir.."/oauth", "r")
if f then
  oauth = f:read("*line")
  f:close()
end

local f = io.open(twitchConfigDir.."/apiURL", "r")
if f then
  apiURL = f:read("*line")
  f:close()
end


local curlParameters = '-sH "Client-ID: '..clientID..'" -H "Authorization: Bearer '..oauth..'" -X GET "'..apiURL
local streamlinkBinary = "streamlink"


function resolveUnicode(str)
  for m in str:gmatch("\\u(....)") do
    str = str:gsub("\\u"..m, utf8.char(tonumber(m, 16)))
  end
  return str
end


function fileExists(path)
  local f = io.open(path, "r")
  if f then
    f.close()
    return true
  else
    return false
  end
end


local twitch = {}

twitch.button = wibox.widget{
  widget = wibox.container.margin,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  {
    widget = wibox.widget.imagebox,
    image = beautiful.icons_path.."/status/"..beautiful.menu_icons_size.."/twitch.symbolic.png"
  }
}

twitch.menu = wibox{
  --x = 50, -- inital values,
  --y = 50, -- changed later
  width = 220,
  height = channels.total * 28 + 5,
  ontop = true,
  bg = beautiful.bg_normal..beautiful.bg_overlay_opacity,
  shape = function(c,w,h) shape.infobubble(c,w,h,5,5,w/2-5) end,
  screen = awful.screen.focused(),
  border_color = beautiful.border_normal,
  border_width = beautiful.border_width,
  visible = false,
  widget = wibox.widget{
    layout = wibox.layout.fixed.vertical,
    bg = beautiful.fg_normal,
    {
      widget = wibox.container.margin,
      top = 5
    }
  }
}


twitch.button:buttons(tableG.join(
  awful.button({}, 1, function()
    twitch.menu.visible = not twitch.menu.visible
  end),
  awful.button({}, 3, function(c)
    isSilent = not isSilent
    twitch.button:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.menu_icons_size.."/twitch"..(isSilent and "_silent" or "")..".symbolic.png"
  end)
))

twitch.button:connect_signal("mouse::enter", function(c, geo)
  twitch.menu.screen = awful.screen.focused()
  twitch.menu.x = twitch.menu.screen.geometry.x + geo.x + 0.5 * geo.width - 0.5 * twitch.menu.width
  twitch.menu.y = beautiful.panel_height + 5
end)



function twitch:getStreamerList(withImageUpdate)
  awful.spawn.easy_async("cat "..twitchConfigDir.."/streamerList", function(result)
    -- streamerList holds the result, removes linebreaks and commented out streamers.
    local streamerList_new = result:gsub("\n", " "):gsub("#[^ ]+", ""):gsub("  *", " ")
    
    newListDiffers = false
    
    _, newListLength = streamerList_new:gsub("[^ ]+", "")
    if newListLength ~= channels.total then
      newListDiffers = true
    end

    
    for i, v in pairs(channels) do
      if type(v) == "table" and not streamerList_new:match(i) then
        newListDiffers = true
        channels[i] = nil
        channels.total = channels.total - 1
      end
    end
      
    if newListDiffers then
      -- Reset the twitch list widget, … 
      self.menu.widget = wibox.widget{
        layout = wibox.layout.fixed.vertical,
        bg = beautiful.fg_normal,
        {
          widget = wibox.container.margin,
          top = 5
        }
      }

      -- … rebuild channels table based on the new streamer list, …
      i = 1
      channels.total = 0
      for c in streamerList_new:gmatch("[^ ]+") do
        if not channels[c] then
          channels[c] = {}
        end
        channels[c].index = i
        channels[c].categoryBackup = nil
        i = i + 1
        channels.total = channels.total + 1
        -- … and add the user’s button to the streamer list.
        self:addChannelToMenu(c)
      end
      
      -- Finally, adjust the new list’s height …
      self.menu.height = channels.total * 28 + 5
    end
    -- … and get channel info and stream status.
    self:getChannelsInfo(withImageUpdate)
  end)
end


function twitch:getChannelsInfo(withImageUpdate)
  -- Build a list of the current streamers to pass as arguments to the twitch status script.
  streamerList_current = ""
  for i, v in pairs(channels) do
    if type(v) == "table" then
      streamerList_current = streamerList_current.." "..i
    end
  end
  streamerList_current = streamerList_current:gsub("^ *", "")

  if fileExists(filesystem.get_configuration_dir()..'twitchStatus_multi.sh') then
    awful.spawn.easy_async('bash '..filesystem.get_configuration_dir()..'twitchStatus_multi.sh --getChannelsInfo '..streamerList_current, function(result)
      if result ~= "" then
        for i, v in pairs(channels) do
          if type(v) == "table" then
            channels[i].display_name = result:match('"login":"'..i..'","display_name":"([^"]*)"') or ""
            channels[i].profile_image_url = result:match('"login":"'..i..'",.-profile_image_url":"([^"]*)') or ""
            
            local f = io.open(twitchConfigDir.."/images/"..i..".jpg", "r")
            
            if withImageUpdate or not f then
              awful.spawn.easy_async('bash '..filesystem.get_configuration_dir()..'twitchStatus_multi.sh --updateProfileImage '..i..' '..channels[i].profile_image_url, function(result)
                self.menu.widget:get_all_children()[-4 + 13 * channels[i].index].text = channels[i].display_name
                self.menu.widget:get_all_children()[-7 + 13 * channels[i].index].image = twitchConfigDir.."/images/"..i..".jpg"
              end)            
            else
              self.menu.widget:get_all_children()[-4 + 13 * channels[i].index].text = channels[i].display_name
              self.menu.widget:get_all_children()[-7 + 13 * channels[i].index].image = twitchConfigDir.."/images/"..i..".jpg"
              f:close()
            end
          end    
        end
        self:getStreamsStatus()
      end
    end)
  end
  
  collectgarbage("collect")
end


twitch.tooltip = require("tooltip")

function twitch:getStreamsStatus()
  streamerList_current = ""
  for i, v in pairs(channels) do
    if type(v) == "table" then
      streamerList_current = streamerList_current.." "..i
    end
  end
  streamerList_current = streamerList_current:gsub("^ *", "")

  if fileExists(filesystem.get_configuration_dir()..'twitchStatus_multi.sh') then
    awful.spawn.easy_async('bash '..filesystem.get_configuration_dir()..'twitchStatus_multi.sh --getStreamsStatus '..streamerList_current, function(result)
  
      for i, v in pairs(channels) do
        if type(v) == "table" then
  
          -- Get the current game.
          local game_name = result:match('"user_login":"'..i..'",.-"game_name":"([^"]*)')
  
          -- If there is a game (ergo: if the stream is online), …
          if game_name then
            -- … set the online indicator.
            self.menu.widget:get_all_children()[13 * channels[i].index].visible = true
  
            -- If the channel has been offline until now, the new category becomes the backup category.
            if not channels[i].categoryBackup then
              channels[i].categoryBackup = game_name
            end
  
            -- Get the stream title.
            local title = result:match('"user_login":"'..i..'",.-"title":"([^"]*)')
            
            -- If the game in the channels variable is not set or differs from the received game name, …
            if not channels[i].game_name or (channels[i].game_name and channels[i].game_name ~= game_name) then
              -- … then save it to the categoryBackup field.
              if channels[i].categoryBackup ~= game_name then
                channels[i].categoryBackup = game_name
                break
              end
              -- … then set the new game name in the list …
              if game_name == "" then game_name = "No activity yet." end
              self.menu.widget:get_all_children()[-2 + 13 * channels[i].index].text = game_name
  
              -- … and notify the user, if the widget is not silences.
              if not isSilent then
                if not channels[i].game_name then
                  naughty.notify{
                    title = channels[i].display_name.." is online.",
                    text = game_name,
                    icon = twitchConfigDir.."/images/"..i..".jpg",
                    icon_size = 48,
                    timeout = 0,
                    preset = naughty.config.presets.low,
                    ontop = true
                  }
                else
                  if channels[i].game_name ~= game_name then
                    naughty.notify{
                      title = channels[i].display_name.." changed activity",
                      text = game_name,
                      icon = twitchConfigDir.."/images/"..i..".jpg",
                      icon_size = 48,
                      timeout = 0,
                      preset = naughty.config.presets.low,
                      ontop = true
                    }
                  end
                end
              end
            end
            channels[i].game_name = game_name
            channels[i].title = title
          else
            self.menu.widget:get_all_children()[13 * channels[i].index].visible = false
            self.menu.widget:get_all_children()[-2 + 13 * channels[i].index].text = ""
            channels[i].game_name = nil
            channels[i].title = nil
            channels[i].categoryBackup = nil
          end
        end
      end
    end)
  end
  collectgarbage("collect")
end


function twitch:addChannelToMenu(user)
  local imagePath = filesystem.get_configuration_dir().."twitchData/"..user..".jpg"
  local channelImage = io.open(imagePath, "r")
  if channelImage then
    channelImage:close()
  else
    imagePath = nil
  end
  local channelButton = wibox.widget{
    widget = wibox.container.background,
    fg = beautiful.fg_normal,
    shape = function(c,w,h) shape.rounded_rect(c,w,h,4) end,
    forced_height = beautiful.font:match("%d+") * 4,
    {
      widget = wibox.container.margin,
      top = 2,
      bottom = 2,
      {
        layout = wibox.layout.align.horizontal,
        wibox.widget{
          widget = wibox.container.margin,
          left = 2,
          right = 4,
          {
            widget = wibox.widget.imagebox,
            image = imagePath, --or filesystem.get_configuration_dir().."twitchData/dummy.png",
            clip_shape = function(c,w,h) shape.rounded_rect(c,300,300,50) end,
          }
        },
        wibox.widget{
          widget = wibox.layout.fixed.vertical,
          {
            widget = wibox.layout.fixed.horizontal,
            {
              widget = wibox.widget.textbox,
              text = channels[user].display_name ~= "" and channels[user].display_name or user,
              font = beautiful.tasklist_font_focus
            },
            {
              widget = wibox.widget.textbox,
              text = ""
            }
          },
          {
            widget = wibox.widget.textbox,
            text = channels[user].game_name or ""
          }
        },
        {
          widget = wibox.container.margin,
          left = 10,
          right = 10,
          {
            widget = wibox.container.background,
            bg = "#78C83C",
            forced_height = 12,
            forced_width = 12,
            shape = function(c,w,h) shape.circle(c,w,h,3) end,
            shape_border_width = 1,
            shape_border_color = "#5AAF19",
            visible = false,
            {
              widget = wibox.widget.textbox
            }
          }
        }
      }
    }
  }

  channelButton:connect_signal("mouse::enter", function(c, geo)
    c.fg = beautiful.fg_focus
    c.bg = beautiful.bg_focus..beautiful.bg_overlay_opacity

    self.tooltip.content.text = channels[user].title or ""
    self.tooltip.content.align = "center"
    self.tooltip.screen = awful.screen.focused()
    local width, height = self.tooltip.content:get_preferred_size(self.tooltip.screen)
    self.tooltip.height = height + 2
    self.tooltip.width = width + 4
    self.tooltip.timer = timer{
      timeout = 1,
      autostart = true,
      callback = function()
        if self.tooltip.content.text ~= "" then
          local mouseCoords = mouse.coords()
          -- Mouse coords are absolute across all screens, but screen.workarea is relative.
          self.tooltip.x = math.min(
            mouseCoords.x - 0.5 * self.tooltip.width,
            self.tooltip.screen.workarea.x + self.tooltip.screen.workarea.width - self.tooltip.width - 4
          )
          self.tooltip.y = mouseCoords.y - self.tooltip.height - 4
          self.tooltip.visible = true
        end
      end,
      single_shot = true
    }
    collectgarbage("collect")
  end)

  channelButton:connect_signal("mouse::leave", function(c, geo)
    c.fg = beautiful.fg_normal
    c.bg = nil

    if self.tooltip.timer and self.tooltip.timer.started then
      self.tooltip.timer:stop()
      self.tooltip.timer = nil
      collectgarbage("collect")
    end
    self.tooltip.visible = false
    collectgarbage("collect")
  end)

  channelButton:buttons(tableG.join(
    -- play the currently running stream
    awful.button({}, 1, function(c)
      c.widget:get_all_children()[8].text = " [Running]"
      self.menu.visible = false
      self.tooltip.timer:stop()
      self.tooltip.timer = nil
      self.tooltip.visible = false
      awful.spawn.easy_async(streamlinkBinary..[[ twitch.tv/]]..user..[[ --title="']]..channels[user].display_name..[[: ]]..channels[user].title..[['"]], function(stdout, stderr, exitreason, exitcode)
        c.widget:get_all_children()[8].text = ""
      end)
      collectgarbage("collect")
    end),
    -- play the most recent VOD
    awful.button({}, 3, function(c)
      self.menu.visible = false
      self.tooltip.timer:stop()
      self.tooltip.timer = nil
      self.tooltip.visible = false
      awful.spawn.easy_async('curl '..curlParameters..'users?login='..user..'"', function(result1)
        local user_id = result1:match('"id":"(.-)"')
        awful.spawn.easy_async('curl '..curlParameters..'videos?user_id='..user_id..'&type=archive&first=1"', function(result2)
          local video_id = result2:match('"id":"(.-)"')
          local video_title = resolveUnicode(result2:match('"title":"(.-)"'))
          local video_date = result2:match('"created_at":"(.-)"'):match("%d%d%d%d%-%d%d%-%d%d")
          c.widget:get_all_children()[8].text = " [Running]"
          awful.spawn.easy_async_with_shell([[mpv -x11-name twitch https://www.twitch.tv/videos/]]..video_id..[[ -title "]]..channels[user].display_name..[[: ]]..video_title..[[ (]]..video_date..[[)"]], function(stdout, stderr, exitreason, exitcode)
            c.widget:get_all_children()[8].text = ""
          end)
        end)
      end)
      collectgarbage("collect")
    end)
  ))

  self.menu.widget:add(channelButton)
  collectgarbage("collect")
end


function twitch:applyColors()
  self.button:get_all_children()[1].image = beautiful.icons_path.."/status/"..beautiful.menu_icons_size.."/twitch"..(isSilent and "_silent" or "")..".symbolic.png"  

  self.menu.bg = beautiful.bg_normal..beautiful.bg_overlay_opacity
  self.menu.border_color = beautiful.border_normal

  for _,v in ipairs(self.menu.widget:get_all_children()) do
    if v.widget_name:match("background") and not v.forced_width then
      v.bg = nil
      v.fg = beautiful.fg_normal
    end
  end
  collectgarbage("collect")
end


timer{
  timeout = 7.5,
  autostart = true,
  callback = function() twitch:getStreamerList() end 
}

twitch:getStreamerList(true)

return twitch
