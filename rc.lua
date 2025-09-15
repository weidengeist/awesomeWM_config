local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup").widget
require("awful.hotkeys_popup.keys")

local confDir = gears.filesystem.get_configuration_dir()
local homeDir = gears.filesystem.get_xdg_config_home():match("(.*/).config")

--local notificationTimer = require("webNotifications")

awful.mouse.snap.edge_enabled = false

--[[####################
    ## Error handling ##
    ####################]]
if awesome.startup_errors then
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Oops, there were errors during startup!",
    text = awesome.startup_errors
  })
end

-- Handle runtime errors after startup
do
  local in_error = false
  awesome.connect_signal("debug::error", function (err)
    -- Make sure we don't go into an endless error loop
    if in_error then return end
    in_error = true
    naughty.notify({
      preset = naughty.config.presets.critical,
      title = "Oops, an error happened!",
      text = tostring(err)
    })
    in_error = false
    end
  )
end


----------------------
-- theme definition --
----------------------

-- read name of currently activated GTK theme
local handle = io.popen([[cat ~/.config/gtk-3.0/settings.ini | grep -oP '(?<=gtk-theme-name=)[^\n]+']])
GtkTheme = handle:read('*all'):match("(.*)%s$")
handle:close()

print("Theme: ", GtkTheme)

beautiful.init(confDir.."/themes/"..GtkTheme.."/theme.lua")
awful.spawn.easy_async('xrdb -merge '..homeDir..'/.themes/'..GtkTheme..'/Xresources', function() end)


for i,v in ipairs {"low", "normal", "critical"} do
  naughty.config.presets[v] = {
    bg = beautiful["notification_bg_"..v],
    fg = beautiful["notification_fg_"..v],
    border_color = beautiful["notification_border_color_"..v],
    border_width = beautiful["notification_border_width_"..v],
    timeout = 0
  }
  -- applies the styles to dbus notifications
  naughty.dbus.config.mapping[i][2] = naughty.config.presets[v]
end

-- prevents notifications from covering fullscreen windows
--naughty.config.notify_callback = function(args)
  --args.ontop = true
  --naughty.dbus.config.mapping[1][2].ontop = true
  --naughty.dbus.config.mapping[2][2].ontop = true
  --local clients = client.get(nil, false)
  --for i, c in ipairs(clients) do      
    --if c.fullscreen then
      --args.ontop = false
      --naughty.dbus.config.mapping[1][2].ontop = false
      --naughty.dbus.config.mapping[2][2].ontop = false  
      --break
    --end
  --end
  --return args
--end


-- This is used later as the default terminal and editor to run.
terminal = 'urxvt'
--terminal_themed = terminal..' -e bash -c "bash ~/.config/urxvt/changeColor.sh '..beautiful.name..' && bash"'
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal.." -e "..editor


local function get_GTK3_icon(client)
  propertyChecks = {'startup_id', 'instance', 'class', 'icon_name'}

  for _, p in ipairs(propertyChecks) do
    local property = (client[p] and client[p]:gsub(" ", "")) or ""
    local path = beautiful.icons_path.."/apps/"..beautiful.panel_icons_size.."/"..property..".png"
    local file = io.open(path, "r")
    print("Checking ", file, ", ", p, "property", property)
    if file then
      file:close()
      print("Match!")
      return path
    end
  end
end

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interfere with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
  awful.layout.suit.floating,
  awful.layout.suit.tile,
  awful.layout.suit.tile.left,
  awful.layout.suit.tile.bottom,
  awful.layout.suit.tile.top,
  awful.layout.suit.fair,
  awful.layout.suit.fair.horizontal,
  awful.layout.suit.spiral,
  awful.layout.suit.spiral.dwindle,
  awful.layout.suit.max,
  awful.layout.suit.max.fullscreen,
  awful.layout.suit.magnifier,
  awful.layout.suit.corner.nw,
  -- awful.layout.suit.corner.ne,
  -- awful.layout.suit.corner.sw,
  -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Helper functions
local function client_menu_toggle_fn()
  local instance = nil
  return function ()
    if instance and instance.wibox.visible then
      instance:hide()
      instance = nil
    else
      instance = awful.menu.clients({ theme = { width = 250 } })
    end
  end
end
-- }}}



function updateList(w, buttons, label, data, objects)
  -- update the widgets, creating them if needed
  w:reset()
  for i, o in ipairs(objects) do
    local cache = data[o]
    local ib, tb, bgb, tbm, ibm, l
    if cache then
      ib = cache.ib -- Image box.
      ibm = cache.ibm -- Image box margin.
      tb = cache.tb -- Text box.
      tbm = cache.tbm -- Text box margin.
      bgb = cache.bgb -- Background box.
    else
      ib = wibox.widget.imagebox()
      ibm = wibox.container.margin(ib, 4, 0, 0.5 * (beautiful.panel_height - beautiful.panel_icons_size))
      tb = wibox.widget.textbox()
      tbm = wibox.container.margin(tb, 4, 4)
      bgb = wibox.container.background()
      l = wibox.layout.fixed.horizontal()

      ib.forced_width = beautiful.panel_icons_size
      ib.forced_height = beautiful.panel_icons_size

      --tb.forced_width = 80

      -- All of this is added to a horizontal layout widget.
      --l:fill_space(true)
      l:add(ibm)
      l:add(tbm)

      -- The layout widget is put into a (colorable) background widget.
      bgb:set_widget(l)
      bgb:buttons(create_buttons(buttons, o))
      data[o] = {ib  = ib, tb  = tb, bgb = bgb, tbm = tbm, ibm = ibm}
    end

    local text, bg, bg_image, icon, args = label(o, tb)
    args = args or {}

    --print("text", text)

    if text == nil or text == "" then
      tbm:set_margins(0)
    else
      if not tb:set_markup_silently(text) then
        tb:set_markup("<i>&lt;Invalid text&gt;</i>")
      end
    end
    
    bgb:set_bg(bg)
    if type(bg_image) == "function" then
      -- TODO: Why does this pass nil as an argument?
      bg_image = bg_image(tb,o,nil,objects,i)
    end
    bgb:set_bgimage(bg_image)

    icon = o.iconPath or icon
    ib:set_image(icon)

    if o.minimized then
      ib.opacity = 0.5
    else
      ib.opacity = 1.0
    end

    bgb.shape = args.shape
    bgb.shape_border_width = args.shape_border_width
    bgb.shape_border_color = args.shape_border_color
    bgb.forced_width = 120

    w:add(bgb)
  end
end



local tasklist_buttons = gears.table.join(
  awful.button({ }, 1, function(c)
    if c == client.focus then
      c.minimized = true
    else
      c.minimized = false
      client.focus = c
      c:raise()
    end
  end),
  awful.button({ }, 3, function(c) client.focus = c os.execute("kill -15 "..c.pid) end),
  awful.button({ }, 4, function (c)
    -- Scrolling up
    local clients = client.get(awful.screen.focused(), false)
    for i, c in ipairs(clients) do
      if c.window == client.focus.window then
        -- if task is first one, then put to end of tasklist
        if i == 1 then
          for j = 2, #clients do
            client.focus:swap(clients[j])
          end
        -- else swap positions with previous one
        else
          clients[i-1]:swap(client.focus)
        end
        collectgarbage("collect")
        break
      end
    end    
  end),
  awful.button({ }, 5, function ()
    -- Scrolling down
    local clients = client.get(awful.screen.focused(), false)
    for i, c in ipairs(clients) do
      if c.window == client.focus.window then
        -- if task is last one, then put to start of tasklist
        if i == #clients then
          for j = #clients-1, 1, -1 do
            client.focus:swap(clients[j])
          end
        -- else swap positions with next one
        else
          clients[i+1]:swap(client.focus)
        end
        collectgarbage("collect")
        break
      end
    end
  end)
)

appMenu = require("appMenu")
audioIndicator = require("audio_indicator")
micIndicator = require("microphone_indicator")
textClock = require("clock")
mailIndicator = require("mail_indicator")
mpdIndicator = require("mpd_indicator")
themeChanger = require("theme_changer")
twitchIndicator = require("twitch_indicator")
volumeIndicator = require("volume_indicator")
weatherIndicator = require("weather_indicator")


-- Wallpaper.
local function set_wallpaper(s)
  print("Screen: ", s.index)
  if beautiful.wallpaper then
    local wallpaper
    if type(beautiful.wallpaper) == "string" then
      wallpaper = beautiful.wallpaper
    end
    if type(beautiful.wallpaper) == "table" then
      if #beautiful.wallpaper >= s.index then
        wallpaper = beautiful.wallpaper[s.index]
      else
        wallpaper = beautiful.wallpaper[(s.index % #beautiful.wallpaper) + 1]
      end
    end
    if type(beautiful.wallpaper) == "function" then
      wallpaper = wallpaper(s)
    end
    gears.wallpaper.maximized(wallpaper, s, true)
  end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

-- set wallpaper again when screen resolution changes
awful.screen.connect_for_each_screen(function(s)
  set_wallpaper(s)

  -- Each screen has its own tag table.
  awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

  -- Create a tasklist widget
  s.tasklist = awful.widget.tasklist{
    screen = s,
    filter = awful.widget.tasklist.filter.currenttags,
    buttons = tasklist_buttons,
    update_function = updateList
  }

  s.systemTray = wibox.widget{
    widget = wibox.container.margin,
    top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
    bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
    left = 5,
    {
      widget = wibox.widget.systray(),
      set_reverse = true,
      set_base_size = beautiful.panel_icons_size
    }
  }

  -- Create the wibox
  s.panel = awful.wibar{
    position = "top",
    screen = s,
    height = beautiful.panel_height
  }

  vertline = wibox.widget{text = "│", valign = "center", widget = wibox.widget.textbox}

  -- Add widgets to the wibox
  s.panel:setup{
    layout = wibox.layout.align.horizontal,
    { -- Left widgets
      layout = wibox.layout.fixed.horizontal,
      appMenu.button,
      vertline,
      
    },
    { -- Middle widget
      layout = wibox.layout.fixed.horizontal,
      s.tasklist
    },
    { -- Right widgets
      layout = wibox.layout.fixed.horizontal,
      s.systemTray,
      --twitterIndicator.button,
      twitchIndicator.button,
      vertline,
      mailIndicator,
      --vertline,
      mpdIndicator,
      --vertline,
      micIndicator,
      audioIndicator,
      volumeIndicator,
      vertline,
      weatherIndicator,
      --vertline,
      textClock,
      spacing = 5
    }
  }
end)



function create_buttons(buttons, object)
  if buttons then
    local btns = {}
    for _, b in ipairs(buttons) do
      local btn = button{ modifiers = b.modifiers, button = b.button }
      btn:connect_signal("press", function () b:emit_signal("press", object) end)
      btn:connect_signal("release", function () b:emit_signal("release", object) end)
      btns[#btns + 1] = btn
    end
    return btns
  end
end


--gears.wallpaper.maximized(beautiful.wallpaper)

-- Each screen has its own tag table.
--awful.tag({"1"}, awful.screen.focused(), awful.layout.layouts[1])



function changeThemeColors()
  if GtkTheme == themeChanger.theme1 then
    GtkTheme = themeChanger.theme2
  else
    GtkTheme = themeChanger.theme1
  end

  awful.spawn.easy_async([[bash ]]..homeDir..[[/.scripts/changeTheme.sh "]]..GtkTheme..[["]], function() end)

  beautiful.init(confDir.."/themes/"..GtkTheme.."/theme.lua")

  -- refresh notification config
  for i,v in ipairs {"low", "normal", "critical"} do
    naughty.config.presets[v] = {
      bg = beautiful["notification_bg_"..v],
      fg = beautiful["notification_fg_"..v],
      border_color = beautiful["notification_border_color_"..v],
      border_width = beautiful["notification_border_width_"..v],
      timeout = 0
    }
    naughty.dbus.config.mapping[i][2] = naughty.config.presets[v]
  end

  for s in screen do
    set_wallpaper(s)
  end

  for _, c in ipairs(client.get()) do
    c:emit_signal("request::titlebars")
    c.border_color = beautiful.border_normal
  end

  if client.focus then
    client.focus.border_color = beautiful.border_focus
  end

  for s in screen do
    s.panel.bg = beautiful.wibar_bg
    s.panel.fg = beautiful.fg_normal
  end

  appMenu:applyColors()
  audioIndicator:applyColors()
  micIndicator:applyColors()
  mailIndicator:applyColors()
  mpdIndicator:applyColors()
  textClock:applyColors()
  themeChanger:applyColors()
  volumeIndicator:applyColors()
  weatherIndicator:applyColors()
  twitchIndicator:applyColors()
  collectgarbage("collect")
end



--[[####################
    ### Key bindings ###
    ####################]]

globalkeys = gears.table.join(
  awful.key({}, "Print",
    function()
      local timestamp = os.date("%Y-%m-%d_%H:%M:%S")
      os.execute('import ' .. homeDir .. '.screenshots/' .. timestamp .. '.png')
      os.execute('cat ' .. homeDir .. '.screenshots/' .. timestamp .. '.png | xclip -i -selection clipboard -t image/png')
      naughty.notify{timeout = 2, title = "Screenshot created", text = "Rectangle captured", icon = beautiful.icons_path.."/apps/48/applets-screenshooter.png"}
    end,
    {description="screenshot rectangle", group="awesome"}
  ),
  awful.key({modkey}, "Print",
    function()
      local client = awful.client.next(0)
      if client then
        local timestamp = os.date("%Y-%m-%d_%H:%M:%S")
        os.execute('import -window '..client.window..' -frame ' .. homeDir .. '.screenshots/' .. timestamp .. '.png')
        os.execute('cat ' .. homeDir .. '.screenshots/' .. timestamp .. '.png | xclip -i -selection clipboard -t image/png')
        naughty.notify{timeout = 2, title = "Screenshot created", text = "Active window captured", icon = beautiful.icons_path.."/apps/48/applets-screenshooter.png"}
      end
    end,
    {description="screenshot active window", group="awesome"}
  ),
  awful.key({modkey, "Shift"}, "Print",
    function()
      local timestamp = os.date("%Y-%m-%d_%H:%M:%S")
      os.execute('import -window root ' .. homeDir .. '.screenshots/' .. timestamp .. '.png')
      os.execute('cat ' .. homeDir .. '.screenshots/' .. timestamp .. '.png | xclip -i -selection clipboard -t image/png')
      naughty.notify{timeout = 2, title = "Screenshot created", text = "All screens captured", icon = beautiful.icons_path.."/apps/48/applets-screenshooter.png"}
    end,
    {description="screenshot all screens", group="awesome"}
  ),
  awful.key({}, "XF86AudioMute",
    function()
      volumeIndicator:mute()
    end,
    {description="mute audio", group="awesome"}
  ),
  awful.key({}, "XF86Calculator",
    function()
      awful.spawn.easy_async('python "' .. gears.filesystem.get_configuration_dir() .. '/audioSwitching.py" toggleMicMuteStatus', function()
        micIndicator:getMicMuteStatus()
      end)
    end,
    {description="mute microphone"}
  ),
  awful.key(
    {modkey, }, "s", hotkeys_popup.show_help,
    {description="show help", group="awesome"}
  ),
  --awful.key(
  --  {modkey, }, "Left",   awful.tag.viewprev,
  --  {description = "view previous", group = "tag"}
  --),
  --awful.key(
  --  {modkey, }, "Right",  awful.tag.viewnext,
  --  {description = "view next", group = "tag"}
  --),
  awful.key(
    {modkey, }, "Escape", awful.tag.history.restore,
    {description = "go back", group = "tag"}
  ),
  awful.key(
    {modkey, }, "j",
    function ()
      awful.client.focus.byidx(1)
    end,
    {description = "focus next by index", group = "client"}
  ),
  awful.key(
    {modkey, }, "k",
    function ()
      awful.client.focus.byidx(-1)
    end,
    {description = "focus previous by index", group = "client"}
  ),
  awful.key(
    {modkey, }, "w",
    function ()
      mymainmenu:show()
    end,
    {description = "show main menu", group = "awesome"}
  ),
  -- Layout manipulation
  awful.key(
    {modkey, "Shift"}, "j",
    function ()
      awful.client.swap.byidx(1)
    end,
    {description = "swap with next client by index", group = "client"}
  ),
  awful.key(
    {modkey, "Shift"}, "k",
    function ()
      awful.client.swap.byidx(-1)
    end,
    {description = "swap with previous client by index", group = "client"}
  ),
  awful.key(
    {modkey, "Control"}, "j",
    function ()
      awful.screen.focus_relative(1)
    end,
    {description = "focus the next screen", group = "screen"}
  ),
  awful.key(
    {modkey, "Control"}, "k",
    function ()
      awful.screen.focus_relative(-1)
    end,
    {description = "focus the previous screen", group = "screen"}
  ),
  awful.key(
    {modkey, }, "u", awful.client.urgent.jumpto,
    {description = "jump to urgent client", group = "client"}
  ),
  awful.key(
    {modkey, }, "Tab",
    function ()
      awful.client.focus.history.previous()
      if client.focus then
        client.focus:raise()
      end
    end,
    {description = "go back", group = "client"}
  ),
  -- Standard program
  awful.key(
    {modkey, }, "Return", 
    function()
      awful.spawn(terminal)
    end,
    {description = "open a terminal", group = "launcher"}
  ),
  awful.key(
    {modkey, "Control"}, "r", awesome.restart,
    {description = "reload awesome", group = "awesome"}
  ),
  awful.key(
    {modkey, "Shift"}, "q", awesome.quit,
    {description = "quit awesome", group = "awesome"}
  ),
  awful.key(
    {modkey, }, "l",
    function ()
      awful.tag.incmwfact(0.05)
    end,
    {description = "increase master width factor", group = "layout"}
  ),
  awful.key(
    {modkey, }, "h",
    function ()
      awful.tag.incmwfact(-0.05)
    end,
    {description = "decrease master width factor", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "h",
    function ()
      awful.tag.incnmaster(1, nil, true)
    end,
    {description = "increase the number of master clients", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "l",
    function ()
      awful.tag.incnmaster(-1, nil, true)
    end,
    {description = "decrease the number of master clients", group = "layout"}
  ),
  awful.key(
    {modkey, "Control"}, "h",
    function ()
      awful.tag.incncol(1, nil, true)
    end,
    {description = "increase the number of columns", group = "layout"}
  ),
  awful.key(
    {modkey, "Control"}, "l",
    function ()
      awful.tag.incncol(-1, nil, true)
    end,
    {description = "decrease the number of columns", group = "layout"}
  ),
  awful.key(
    {modkey, }, "space",
    function ()
      awful.layout.inc( 1)
    end,
    {description = "select next", group = "layout"}
  ),
  awful.key(
    {modkey, "Shift"}, "space",
    function ()
      awful.layout.inc(-1)
    end,
    {description = "select previous", group = "layout"}
  ),
  awful.key(
    {modkey, "Control" }, "n",
    function ()
      local c = awful.client.restore()
      -- Focus restored client
      if c then
        client.focus = c
        c:raise()
      end
    end,
    {description = "restore minimized", group = "client"}
  )
)

clientkeys = gears.table.join(
  awful.key({modkey, }, "f",
    function (c)
      c.fullscreen = not c.fullscreen
      c:raise()
    end,
    {description = "toggle fullscreen", group = "client"}
  ),
  awful.key({modkey, "Shift"}, "c",
    function (c)
      c:kill()
    end,
    {description = "close", group = "client"}
  ),
  awful.key({modkey, "Control"}, "space",
    awful.client.floating.toggle,
    {description = "toggle floating", group = "client"}
  ),
  awful.key({modkey, "Control"}, "Return",
    function (c)
      c:swap(awful.client.getmaster())
    end,
    {description = "move to master", group = "client"}
  ),
  awful.key({modkey, }, "Left",
    function (c)
      local coords = mouse.coords()
      c:move_to_screen(c.screen.index-1)
      mouse.coords{x = coords.x, y = coords.y}
    end,
    {description = "move to previous screen", group = "client"}
  ),
  awful.key({modkey, }, "Right",
    function (c)
      local coords = mouse.coords()
      c:move_to_screen(c.screen.index+1)
      mouse.coords{x = coords.x, y = coords.y}
    end,
    {description = "move to next screen", group = "client"}
  ),
  -----------------------------------
  -- Move the window by one pixel. --
  -----------------------------------
  awful.key({modkey, "Control"}, "Left",
    function (c)
      c.x = c.x - 1
    end,
    {description = "move left by one pixel", group = "client"}
  ),
  awful.key({modkey, "Control"}, "Right",
    function (c)
      c.x = c.x + 1
    end,
    {description = "move right by one pixel", group = "client"}
  ),
  awful.key({modkey, "Control"}, "Up",
    function (c)
      c.y = c.y - 1
    end,
    {description = "move up by one pixel", group = "client"}
  ),
  awful.key({modkey, "Control"}, "Down",
    function (c)
      c.y = c.y + 1
    end,
    {description = "move down by one pixel", group = "client"}
  ),
  -----------------------------------
  -----------------------------------
  -----------------------------------
  awful.key({modkey, }, "t",
    function (c)
      c.ontop = not c.ontop
    end,
    {description = "toggle keep on top", group = "client"}
  ),
  awful.key({modkey, }, "n",
    function (c)
      -- The client currently has the input focus, so it cannot be
      -- minimized, since minimized clients can't have the focus.
      c.minimized = true
    end ,
    {description = "minimize", group = "client"}
  ),
  awful.key({modkey, }, "m",
    function (c)
      c.maximized = not c.maximized
      c:raise()
    end ,
    {description = "(un)maximize", group = "client"}
  ),
  awful.key({modkey, "Control"}, "m",
    function (c)
      c.maximized_vertical = not c.maximized_vertical
      c:raise()
    end,
    {description = "(un)maximize vertically", group = "client"}
  ),
  awful.key({modkey, "Shift"}, "m",
    function (c)
      c.maximized_horizontal = not c.maximized_horizontal
      c:raise()
    end ,
    {description = "(un)maximize horizontally", group = "client"}
  )
)

local clientbuttons = gears.table.join(
  awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
  awful.button({ modkey }, 1, awful.mouse.client.move),
  awful.button({ modkey }, 3, awful.mouse.client.resize)
)

-- Set keys
root.keys(globalkeys)
-- }}}


--[[#############
    ### Rules  ###
    #############]]
awful.rules.rules = gears.table.join(
  {
    {rule = { },
      properties = {
        border_width = beautiful.border_width,
        border_color = beautiful.border_normal,
        focus = awful.client.focus.filter,
        raise = true,
        keys = clientkeys,
        ontop = false,
        buttons = clientbuttons,
        screen = awful.screen.preferred,
        placement = awful.placement.no_offscreen,
        skip_taskbar = false
      }
    },
    -- Floating clients.
    {rule_any =
      {name = "Event Tester"},
      properties = { floating = true }
    },
    -- Add titlebars to normal clients and dialogs
    {rule_any =
      {type = {"normal", "dialog"}},
      properties = {titlebars_enabled = function(c) return not c.requests_no_titlebar end}
    }
  }
)

awful.titlebar.enable_tooltip = false



local gtable = require("gears.table")

function adjustPositionOnly(c, context, hints)
  if context == "ewmh" and hints then
    for i, v in pairs(hints) do
      print("HINT", i, v)
    end
    hints.x = nil
    hints.y = nil
    if c.immobilized_horizontal then
      hints = gtable.clone(hints)
      hints.x = nil
    end
    if c.immobilized_vertical then
      hints = gtable.clone(hints)
      hints.y = nil
    end
    c:geometry(hints)
  end
end


--[[###############
    ### Signals ###
    ###############]]
-- All¹ clients spawn on the currently focused screen. (¹ Some programs ignore the »screen« rule, but this signal disconnection fixes that.)
--client.disconnect_signal("request::geometry", awful.ewmh.client_geometry_requests)
--client.connect_signal("request::geometry", adjustPositionOnly)


client.connect_signal("manage", function (c)
  --c:disconnect_signal("property::position", awful.ewmh.client_geometry_requests)
  for i,v in pairs(c:geometry()) do
    print(i, v)
  end
  for i,v in pairs(c.size_hints) do
    print("size hint", i, v)
    if i == "user_position" or i == "program_position" then
      for a, b in pairs(v) do
        print(i, a, b)
      end
    end
  end
  if c.maximized or c.fullscreen then
    c.border_width = 0
    -- experimental; take care of RAM
  else
    c.shape = beautiful.client_shape
    collectgarbage("collect")
    -- experimental end
  end
  --sorts tasklist items from left to right when spawning new client
  if not awesome.startup then 
    awful.client.setslave(c)
  end
  -- optional: 
  --if awesome.startup and not c.size_hints.program_position and not c.size_hints.user_position then
    -- Prevent clients from being unreachable after screen count changes.
  --awful.placement.no_offscreen(c)
  --end
  c:move_to_screen(mouse.screen.index)
  if not c.size_hints.program_position then
    --c:connect_signal("request::geometry", awful.ewmh.client_geometry_requests)
    awful.placement.center_horizontal(c)
  --else
    --awful.placement.center_horizontal(c)
    --c:disconnect_signal("request::geometry", awful.ewmh.client_geometry_requests)
  end
  if not c.iconPath then
    c.iconPath = get_GTK3_icon(c)
  end
  collectgarbage("collect")
end)


-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
  -- buttons for the titlebar
  local buttons = gears.table.join(
    awful.button({ }, 1, function()
      client.focus = c
      c:raise()
      awful.mouse.client.move(c)
    end),
    awful.button({ }, 3, function()
      client.focus = c
      c:raise()
      awful.mouse.client.resize(c)
    end)
  )
  
  c.iconPath = get_GTK3_icon(c)
  if c.iconPath then
    iconImage = wibox.widget.imagebox(c.iconPath)
  else
    iconImage = awful.widget.clienticon(c)
  end

  local appIcon = wibox.widget{
    widget = wibox.container.margin,
    top = 1,
    bottom = 1,
    left = 1,
    {
      layout = wibox.layout.fixed.horizontal,
      iconImage
    }
  }

  awful.titlebar(c, {size = beautiful.titlebar_height}):setup{
    layout = wibox.layout.align.horizontal,
    { -- Left
      appIcon,
      buttons = buttons,
      layout  = wibox.layout.fixed.horizontal
    },
    { -- Middle
      { -- Title
        align  = "center",
        widget = awful.titlebar.widget.titlewidget(c)
      },
      buttons = buttons,
      layout  = wibox.layout.flex.horizontal
    },
    { -- Right
      awful.titlebar.widget.ontopbutton(c),
      awful.titlebar.widget.minimizebutton(c),
      awful.titlebar.widget.maximizedbutton(c),
      awful.titlebar.widget.closebutton(c),
      layout = wibox.layout.fixed.horizontal()
    },
  }

  collectgarbage("collect")
end)

--local wa = awful.screen.focused().workarea

client.connect_signal("focus", function(c)
  c.border_color = beautiful.border_focus
  -- Experimental! Disable font change when problems occur
  --awful.titlebar(c).widget:get_all_children()[6].font = beautiful.titlebar_font_focus
  collectgarbage("collect")
end)

client.connect_signal("unfocus", function(c)
  c.border_color = beautiful.border_normal
  -- Experimental! Disable font change when problems occur
  --if awful.titlebar(c).widget then
  --  awful.titlebar(c).widget:get_all_children()[6].font = beautiful.titlebar_font
  --end
  collectgarbage("collect")
end)

client.connect_signal("property::fullscreen", function(c)
  if c.fullscreen or c.maximized then
    c.border_width = 0
    c.shape = beautiful.client_shape_maximized
    collectgarbage("collect")
  else
    c.border_width = beautiful.border_width
    c.shape = beautiful.client_shape
    collectgarbage("collect")
  end
  collectgarbage("collect")
end)

client.connect_signal("property::maximized", function(c)
  if c.maximized or c.fullscreen then
    c.border_width = 0
    -- experimental; keep eye on RAM
    c.shape = beautiful.client_shape_maximized
    collectgarbage("collect")
  else
    c.border_width = beautiful.border_width
    -- experimental; keep eye on RAM
    c.shape = beautiful.client_shape
    collectgarbage("collect")
  end
  collectgarbage("collect")
end)

require("startup_programs")
