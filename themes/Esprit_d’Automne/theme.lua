---------------------------
-- Default awesome theme --
---------------------------
local filesystem = require("gears.filesystem")
local shape = require("gears.shape")

local theme = {}

theme.name = "Esprit_d’Automne"
theme.path = filesystem.get_configuration_dir().."themes/"..theme.name
theme.icons_path = filesystem.get_xdg_config_home():match("(.*/).config")..".icons/"..theme.name

theme.client_shape = function(c,w,h) shape.rounded_rect(c,w,h,5) end
theme.client_shape_maximized = function(c,w,h) shape.rectangle(c,w,h) end

theme.font = "Georgia 7"

theme.bg_normal = "#FFF5F0"
theme.bg_focus = "#FFD2A0"
theme.bg_urgent = "#E64664"
theme.bg_minimize = "#628CC0"
theme.bg_overlay_opacity = "FF" -- C0

theme.fg_normal = "#663333"
theme.fg_focus = "#370000"
theme.fg_urgent = "#FFFFFF"
theme.fg_minimize = "#DA9E9E"

-- space between aligned/snapped windows
theme.useless_gap = 0

theme.border_width = 1
theme.border_normal = "#FFCC99"
theme.border_focus = "#a55a5a"
theme.border_urgent = "#D23C5A"
theme.border_prelight = "#DD8888"

theme.wibar_bg = theme.bg_normal
theme.bg_systray = theme.wibar_bg

theme.tooltip_font = "Georgia 8"
theme.tooltip_border_width = 1
theme.tooltip_border_color = theme.border_focus
theme.tooltip_bg = theme.bg_focus
theme.tooltip_fg = theme.fg_focus
theme.tooltip_shape = function(cr, width, height) shape.rounded_rect(cr, width, height, 3) end

theme.tasklist_plain_task_name = true
theme.tasklist_shape = function(cr, width, height) shape.rounded_rect(cr, width, height, 5) end
theme.tasklist_shape_border_width = 1
theme.tasklist_shape_border_color = theme.wibar_bg
theme.tasklist_shape_border_color_focus = theme.border_focus
theme.tasklist_shape_border_color_minimized = theme.wibar_bg
theme.tasklist_spacing = 2
theme.tasklist_fg_normal = theme.fg_normal
theme.tasklist_fg_minimize = theme.fg_minimize
theme.tasklist_fg_focus = theme.fg_normal
theme.tasklist_bg_normal = theme.bg_normal
theme.tasklist_bg_minimize = theme.wibar_bg
theme.tasklist_bg_focus = theme.bg_normal
theme.tasklist_font = "Georgia 7"
theme.tasklist_font_focus = theme.tasklist_font:gsub("( )(%d+)", "%1Bold %2")

theme.titlebar_fg = theme.fg_normal
theme.titlebar_bg = theme.bg_normal
theme.titlebar_font = "Georgia 7"
theme.titlebar_font_focus = theme.titlebar_font:gsub("( )(%d+)", "%1Bold %2")
theme.titlebar_height = 18

theme.progressbar_bg = "#ffffff"..theme.bg_overlay_opacity
theme.progressbar_fg = theme.fg_normal
theme.progressbar_border_color = theme.border_prelight
theme.progressbar_border_width = 1

--theme.menu_fg = theme.fg_normal
--theme.menu_bg = theme.bg_normal.."80"
--theme.menu_fg_focus = theme.fg_focus
--theme.menu_bg_focus = theme.bg_focus.."80"
--theme.menu_shape = function(c, w, h) shape.rounded_rect(c, w, h, 4) end

theme.notification_icon_size = 48
theme.notification_width = 240
theme.notification_shape = function(c, w, h) shape.rounded_rect(c, w, h, 12) end

theme.notification_fg_low = theme.fg_normal
theme.notification_bg_low = theme.bg_normal..theme.bg_overlay_opacity
theme.notification_border_width_low = 1
theme.notification_border_color_low = theme.border_prelight

theme.notification_fg_normal = theme.fg_normal
theme.notification_bg_normal = theme.bg_normal..theme.bg_overlay_opacity
theme.notification_border_width_normal = 3
theme.notification_border_color_normal = theme.border_normal

theme.notification_fg_critical = theme.fg_urgent
theme.notification_bg_critical = theme.bg_urgent.."FF"
theme.notification_border_width_critical = 1
theme.notification_border_color_critical = theme.border_urgent

theme.clock_font = "Georgia Bold 8"

theme.panel_height = 20
theme.panel_icons_size = 16
theme.systray_icon_spacing = 5
theme.menu_icons_size = 16

theme.menu_icons_path = theme.icons_path.."/apps/"..theme.menu_icons_size
theme.titlebar_height = 18


-- Titlebars
theme.titlebar_close_button_normal = theme.path.."/titlebar/close.png"
theme.titlebar_close_button_focus	= theme.path.."/titlebar/close_focus.png"
theme.titlebar_close_button_focus_hover	= theme.path.."/titlebar/close_focus_hover.png"

theme.titlebar_maximized_button_normal_active = theme.path.."/titlebar/maximized.png"
theme.titlebar_maximized_button_focus_active = theme.path.."/titlebar/maximized_focus.png"
theme.titlebar_maximized_button_focus_active_hover = theme.path.."/titlebar/maximized_focus_hover.png"

theme.titlebar_maximized_button_normal_inactive = theme.path.."/titlebar/maximized_inactive.png"
theme.titlebar_maximized_button_focus_inactive = theme.path.."/titlebar/maximized_inactive_focus.png"
theme.titlebar_maximized_button_focus_inactive_hover = theme.path.."/titlebar/maximized_inactive_focus_hover.png"

theme.titlebar_minimize_button_normal = theme.path.."/titlebar/minimize.png"
theme.titlebar_minimize_button_focus = theme.path.."/titlebar/minimize_focus.png"
theme.titlebar_minimize_button_focus_hover = theme.path.."/titlebar/minimize_focus_hover.png"

theme.titlebar_ontop_button_normal_active = theme.path.."/titlebar/ontop.png"
theme.titlebar_ontop_button_focus_active = theme.path.."/titlebar/ontop_focus.png"
theme.titlebar_ontop_button_focus_active_hover = theme.path.."/titlebar/ontop_focus_hover.png"

theme.titlebar_ontop_button_normal_inactive = theme.path.."/titlebar/ontop_inactive.png"
theme.titlebar_ontop_button_focus_inactive = theme.path.."/titlebar/ontop_inactive_focus.png"
theme.titlebar_ontop_button_focus_inactive_hover = theme.path.."/titlebar/ontop_inactive_focus_hover.png"


theme.wallpaper = {theme.path.."/Anniversary_1st_1920_1080.png", theme.path.."/background.png"}


return theme
