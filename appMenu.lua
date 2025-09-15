local wibox = require("wibox")
local beautiful = require("beautiful")
local shape = require("gears.shape")
local awful = require("awful")
local filesystem = require("gears.filesystem")

local hLineCount = 0

local menu = wibox{
  width = 120,
  height = 300,
  ontop = true,
  bg = beautiful.bg_normal..beautiful.bg_overlay_opacity,
  screen = awful.screen.focused(),
  shape = beautiful.menu_shape,
  shape_clip = beautiful.menu_shape, -- needed for removing border residues  
  border_color = beautiful.border_normal,
  border_width = beautiful.border_width,
  visible = false,
  widget = wibox.widget{
    layout = wibox.layout.fixed.vertical,
    bg = beautiful.fg_normal
  }
}

menu.icons = {}

menu:connect_signal("mouse::leave", function(c)
  if c.visible then
    c.visible = false
  end
end)

menu.button = wibox.widget{
  widget = wibox.container.margin,
  left = 4,
  right = 4,
  top = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  bottom = (beautiful.panel_height - beautiful.panel_icons_size) / 2,
  screen = awful.screen.focused(),
  {
    widget = wibox.widget.imagebox,
    image = beautiful.path.."/icons/appMenu.png"
  }
}

menu.button:connect_signal("button::press",
  function(_,_,_,button,_,geo)
    if button == 1 then
      menu.visible = not menu.visible
    end
    if button == 3 then
      awful.spawn.easy_async(
        'python "' .. filesystem.get_configuration_dir() .. '/appMenu.py"',
        function(result)
        end
      )
    end
  end
)


menu.button:connect_signal("mouse::enter", function(c, geo)
  menu.screen = awful.screen.focused()
  menu.x = menu.screen.geometry.x + 4
  menu.y = menu.screen.geometry.y + 24
end)

function menu:addApp(name, command, icon)
  local icon = icon or "blank"
  local iconPath = ""

  if icon:match("/") then
    iconPath = beautiful.icons_path.."/"..icon..".png"
  else
    iconPath = beautiful.menu_icons_path.."/"..icon..".png"
  end
  
  local file = io.open(iconPath)

  if not file then
    iconPath = beautiful.menu_icons_path.."/blank.png"
  else
    file:close()
  end

  local entry = wibox.widget{
    widget = wibox.container.background,
    fg = beautiful.fg_normal,
    shape = function(c,w,h) shape.rounded_rect(c,w,h,4) end,
    forced_height = beautiful.menu_icons_size + 4,
    {
      widget = wibox.container.margin,
      top = 2,
      bottom = 2,
      {
        layout = wibox.layout.fixed.horizontal,
        spacing = 5,
        wibox.widget{
          widget = wibox.container.margin,
          left = 5,
          right = 5,
          {
            widget = wibox.widget.imagebox,
            image = iconPath
          }
        },
        wibox.widget{
          widget = wibox.widget.textbox,
          text = name,
          valign = "center"
        }
      }
    }
  }

  entry:connect_signal("mouse::enter", function(c)
    c.fg = beautiful.fg_focus
    c.bg = beautiful.bg_focus..beautiful.bg_overlay_opacity
  end)

  entry:connect_signal("mouse::leave", function(c)
    c.fg = beautiful.fg_normal
    c.bg = nil
  end)

  entry:buttons(
    awful.button({}, 1, function()
      menu.visible = false
      awful.spawn.easy_async(command, function() end)
    end)
  )

  self.widget:add(entry)
  self.icons[#self.icons+1] = iconPath:gsub(beautiful.icons_path, "")
end

--function menu:addSubmenu(name, icon)
  --local entry = wibox.widget{
    --layout = wibox.layout.align.horizontal,
    --{
      --widget = wibox.container.background,
      --fg = beautiful.menu_fg,
      --shape = function(c,w,h) shape.rounded_rect(c,w,h,3) end,
      --{
        --widget = wibox.container.margin,
        --top = 2,
        --bottom = 2,
        --{
          --layout = wibox.layout.fixed.horizontal,
          --forced_height = 20,
          --spacing = 5,
          --wibox.widget{
            --widget = wibox.container.margin,
            --left = 5,
            --right = 5,
            --{
              --widget = wibox.widget.imagebox,
              --image = beautiful.icons_path.."/"..(icon or "null")..".png"
            --}
          --},
          --wibox.widget{
            --widget = wibox.widget.textbox,
            --text = name,
            --valign = "center"
          --}
        --}
      --}
    --},
    --nil,
    --wibox.widget{
      --widget = wibox.container.margin,
      --right = 5,
      --{
        --widget = wibox.widget.textbox,
        --text = "▶"
      --}
    --}
  --}

  --entry:connect_signal("mouse::enter", function(c)
    --c.fg = beautiful.menu_fg_focus
    --c.bg = beautiful.menu_bg_focus
  --end)

  --entry:connect_signal("mouse::leave", function(c)
    --c.fg = beautiful.menu_fg
    --c.bg = nil
  --end)

  --self.widget:add(entry)

  --return
--end


function menu:applyColors()
  self.bg = beautiful.bg_normal..beautiful.bg_overlay_opacity
  self.border_color = beautiful.border_normal
  self.button.widget.image = beautiful.path.."/icons/appMenu.png"

  local i = 1
  local bg = nil
  for _,v in ipairs(self.widget:get_all_children()) do
    if v.widget_name:match("background") then
      v.fg = beautiful.fg_normal  
      entry = v
    end
    if v.widget_name:match("imagebox") then
      v.image = beautiful.icons_path..self.icons[i]
      i = i + 1
    end
  end
end


function menu:addHLine()
  local hLine = wibox.widget{
    widget = wibox.widget.textbox,
    text = "——————————————",
    font = "Liberation Mono 8",
    forced_height = 4,
  }

  local hLineContainer = wibox.widget{
    widget = wibox.container.background,
    fg = beautiful.fg_normal,
    {
      layout = wibox.layout.align.horizontal,
      expand = "outside",
      nil,
      {
        widget = hLine
      },
      nil
    }
  }

  self.widget:add(hLineContainer)
  hLineCount = hLineCount + 1
end


menu:addApp("Firefox", filesystem.get_xdg_config_home():match("(.*)/.config").."/Firefox_commonRelease/firefox", "firefox")
menu:addApp("Thunar", "thunar", "thunar")
menu:addApp("JDownloader", "jdownloader", "JDownloader")
menu:addApp("Steam", "steam -vgui -nofriendsui -nochatui", "steam")
menu:addApp("GIMP", "gimp", "gimp")
menu:addApp("Inkscape", "inkscape", "Inkscape")
menu:addApp("Geany", "geany", "geany")
menu:addApp("LMMS", "lmms", "lmms")
menu:addApp("Tuxguitar", "tuxguitar", "tuxguitar")
menu:addApp("ScummVM", "scummvm", "scummvm")
menu:addApp("SNES9x", "snes9x-gtk", "snes9x")
--menu:addSubmenu("Test")
menu:addHLine()
menu:addApp("Logout", "pkill -f awesome", "actions/"..beautiful.menu_icons_size.."/application-exit")
menu:addApp("Shutdown", "shutdown now", "actions/"..beautiful.menu_icons_size.."/system-shutdown")

menu.height = (#menu.widget:get_all_children() - hLineCount * 3) / 6 * (beautiful.menu_icons_size + 4) + hLineCount * 4

return menu
