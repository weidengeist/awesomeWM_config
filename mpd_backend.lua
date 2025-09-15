local socket = require("socket")


--[[########################
    ### general routines ###
    ########################]]

function secondsToTime(seconds)
	local output = ""
	local t = os.date("*t", seconds)
	t.day = t.day - 1
	t.hour = t.hour - 1

	-- fields sorted by unit size
	local fields = {t.hour, t.min, t.sec}

	local i = 1
	while fields[i] == 0 and i < #fields do
		i = i + 1
	end

	for k = i, #fields do
		if #(tostring(fields[k])) == 1 then
			fields[k] = "0"..tostring(fields[k])
		end
		output = output..":"..fields[k]
	end

	if t.day >= 1 then
		output = t.day.." day, "..output
		if t.day >= 2 then
			output:gsub("day","days")
		end
	end

	return output:gsub("^:","")
end


--[[#############################
    ### MPD-specific routines ###
    #############################]]

local MPD = {}

function MPD:init(host, port)
	obj = {}
	setmetatable(obj, {__index = self})

	local running = os.execute('ps -e | grep "[m]pd$" 1>/dev/null')
	if running then
		obj.host = host
		obj.port = port
		obj.timeout = 1
		obj.retries = {0, max = 20}
		return obj
	elseif #args == 0 then
		print("MPD not running!")
	end
end

function MPD:send(command)
	if not self.connected then
		self.socket = socket.tcp()
		if command:match("^idle") then
			self.socket:settimeout(nil, 't')
		else
			self.socket:settimeout(self.timeout, 't')
		end
		self.connected = self.socket:connect(self.host, self.port)
		local line = self.socket:receive("*l")
		if not line then
			print("Connection failed. Retrying …")
			self.retries[1] = self.retries[1] + 1
			if self.retries[1] <= self.retries.max then
				self:send(command)
			else
				self.retries[1] = 0
				print("Couldn’t establish connection.")
				return 0
			end
		end
	end

	self.socket:send(command.."\n")
	local result = {}
	local line = ""
	if command:match('^update$') then
		print("Updating DB …")
		self.socket:send("idle update\n")
	end
	while not line:match("^OK$") do
		line, err = self.socket:receive()
		if not line then
			self.socket:close()
			self.connected = false
			return err
		elseif line ~= "OK" then
			result[#result + 1] = line
		end
	end
	self.socket:close()
	self.connected = false
	return result
end


function MPD:getCorrectCase(artist, ...)
	local album = ...
	local correctArtist = nil
	local correctAlbum = nil
	local result = nil
	if album then
		result = self:send('search artist "'..artist..'" album "'..album..'" window 00:01')
	else
		result = self:send('search artist "'..artist..'"')
	end
	local i = 1
	while i <= #result and not (correctArtist and correctAlbum) do
		if result[i]:match('Artist: ') then
			correctArtist = result[i]:gsub("Artist: ", "")
		end
		if result[i]:match('Album: ') then
			correctAlbum = result[i]:gsub("Album: ", "")
		end
		i = i + 1
	end
	return correctArtist, correctAlbum
end


function MPD:getArtists(bool_print)
	local result = {}
	local artists = self:send("list artist")
	for _, data in ipairs(artists) do
		if data ~= "Artist: " then
			result[#result+1] = data:gsub("Artist: ", "")
		end
	end

	if bool_print then
		for i, artist in ipairs(result) do
			local index = tostring(i)
			while #index < #(tostring(#result)) do
				index = "0"..index
			end
			-- artistStats[1]: (number of) songs; artistStats[2]: playtime
			local artistStats = test:send('count artist "'..artist..'"')
			print(index..". "..artist)
			print(string.rep(" ", #index + 2)..artistStats[1]:match('%d+').." songs, "..secondsToTime(artistStats[2]:match('%d+')).."\n")
		end
	end

	return result
end


function MPD:getAlbums(artist, bool_print)
	local result = {}
	local artist = test:getCorrectCase(artist)
	if not artist then
		print("Artist not found!")
	else
		local albums = self:send('list album artist "'..artist..'" group date')
		i = 1
		while i <= #albums do
			if albums[i]:match("^Date: ") then
				result[#result+1] = {date = albums[i]:gsub("Date: ", "")}
				result[#result].album = albums[i+1]:gsub("Album: ", "")
				i = i+2
			else
				result[#result+1] = {date = result[#result].date}
				result[#result].album = albums[i]:gsub("Album: ", "")
				i = i+1
			end
		end
		--table.sort(result, function(a,b) return a.date < b.date end)

		if bool_print then
			-- discogStats[1]: (number of) songs; discogStats[2]: playtime
			local discogStats = test:send('count artist "'..artist..'"')
			print("\nAlbums by "..artist..":")
			print(string.rep('0', #(tostring(#result)))..'. complete discography')
			print(string.rep(" ", #(tostring(#result)) + 2)..discogStats[1]:match('%d+')..' songs, '..secondsToTime(discogStats[2]:match('%d+'))..'\n')
		
			for i, disc in ipairs(result) do
				local index = tostring(i)
				while #index < #(tostring(#result)) do
					index = "0"..index
				end
				local albumStats = test:send('count artist "'..artist..'" album "'..disc.album..'"')
				print(index..". »"..disc.album.."« ("..disc.date..")")
				print(string.rep(' ', #index + 2)..albumStats[1]:match('%d+')..' songs, '..secondsToTime(albumStats[2]:match('%d+'))..'\n')
			end
		end
	end

	return result
end


function MPD:getSongs(artist, album, bool_print)
	local result = {}
	local songs = self:send('find artist "'..artist..'" album "'..album..'" sort disc')
	for _, data in ipairs(songs) do
		if data:match("^file: ") then
			result[#result+1] = {file = (data:gsub("file: ",""))}
		end
		local tag = data:match("^%w+")
		result[#result][tag] = (data:gsub(tag..": ", ""))
	end
	
	if bool_print then
		local songStats = test:send('count artist "'..artist..'" album "'..album..'"')
		for i,v in ipairs(songStats) do
			print(i,v)
		end
		print("Songs on »"..album.."« by "..artist..":")
		print(string.rep("0", #(tostring(#result)))..'. complete album ('..secondsToTime(tonumber(songStats[2]:match('%d+')))..')')
		for i, song in ipairs(result) do
			local index = tostring(i)
			while #index < #(tostring(#result)) do
				index = "0"..index
			end
			print(index..". "..result[i].Title.." —— "..secondsToTime(result[i].Time))
		end
	end
	return result
end


function MPD:getPlaylist(bool_print)
	local result = {}
	local playlist = self:send("playlistinfo")
	for _, data in ipairs(playlist) do
		if data:match("^file:") then
			result[#result+1] = {file = data:gsub("file: ", "")}
		else
			local tag = data:match("^%w+")
			result[#result][tag] = data:gsub(tag..": ", "")
		end
	end

	if bool_print then
		local playtime = 0
		local elapsed = 0
		local current = (tonumber(self:getCurrentSong()['Pos']) or (-1)) + 1
		for i = 1, #result do
			local pos = tostring(i)
			while #pos < #(tostring(#result)) do
				pos = "0"..pos
			end
			if i == current then
				elapsed = elapsed + math.floor(tonumber(self:getStatus().elapsed) or 0)
				print("► "..pos.." │ "..result[i].Track..". "..result[i].Title.." —— "..secondsToTime(result[i].Time))
			else
				print("  "..pos.." │ "..result[i].Track..". "..result[i].Title.." —— "..secondsToTime(result[i].Time))
				if current and i < current then
					elapsed = elapsed + tonumber(result[i].Time)
				end
			end
			playtime = playtime + tonumber(result[i].Time)
		end
		local finishedAt = os.time() + playtime - elapsed
		print("Total playtime: "..secondsToTime(playtime))
		print("Elapsed playtime: "..secondsToTime(elapsed))
		print("Remaining playtime: "..secondsToTime(playtime-elapsed).." (at ca. "..os.date("%H:%M", finishedAt)..")")
	end
	
	return result
end
	

function MPD:getCurrentSong(bool_print, field)
	local result = {}
	local status = self:send("currentsong")
	for _, v in ipairs(status) do
		result[v:match("^(%w+)")] = v:match(": (.*)")
	end

	if bool_print and not field then
		if #status > 0 then
			for v in pairs(result) do
				print(v..": "..result[v])
			end
		end
	end

	if field and result[field] then
		if bool_print then
			print(result[field])
		end
		return result[field]
	else
		return result
	end
end


function MPD:getStatus(bool_print, field)
	local result = {}
	local status = self:send("status")
	for _, v in ipairs(status) do
		result[v:match("^(%w+)")] = v:match(": (.*)")
	end

	if bool_print and not field then
		for v in pairs(result) do
			print(v..": "..result[v])
		end
	end
	
	if field and result[field] then
		if bool_print then
			print(result[field])
		end
		return result[field]
	else
		return result
	end
end




-- init queryPath; format: '|artist' or '|artist|album'
local query = ""
local queryPath = ""
local args = {...}

test = MPD:init("localhost", 6666)

--local orphans = test:send('find album ""')
--for i,v in ipairs(orphans) do
	--print(v)
--end


--[[##################
		### query loop ###
		##################]]

while not query:match('^exit$') and test do
	if #args > 0 then
		query = args[1]
	else
		io.write("Query: ")
		query = io.read()
	end

	if query:match('^gui$') then
		os.execute('lua /archive/.tmp/mpd_frontend.lua ')
	end

	if query:match('^status') then
		local field = query:match('^status (.*)')
		-- print output if script was invoked with args (e.g. by awesome wm)  
		test:getStatus(true, field)
	end

	if query:match('^commands$') then
		local result = test:send('commands')
		print(result)
	end
	
	-----------------------
	-- playback commands --
	-----------------------
	if query:match("^play$") then
		test:send("play")
	end

	if query:match("^play %d+$") then
		local index_max = #(test:getPlaylist())
		test:send("play "..math.min(tonumber(query:match("%d+")) - 1, index_max - 1))
	end

	if query:match("^stop$") then
		test:send("stop")
	end

	if query:match("^pause$") then
		local state = test:getStatus(false,'state')
		if state == 'pause' then
			test:send("pause 0")
		else
			test:send("pause 1")
		end
	end

	if query:match("^seek %d+[.0-9]*$") then
		test:send("seekcur "..query:match("seek (.*)"))
	end

	if query:match("^song") then
		local field = query:match('^song (.*)')
		if #args > 0 then
			if field then
				test:getCurrentSong(true, field)
			else
				test:getCurrentSong(true)
			end
		else
			test:getCurrentSong(true, field)
		end
	end

	if query:match("^next$") then
		local status = test:getStatus()
		if status.state == "play" then
			local playlistlength = test:getStatus(false, "playlistlength")
			local songNumber = test:getStatus(false, "song")
			if tonumber(songNumber) == tonumber(playlistlength) - 1 then
				test:send("stop")
			else
				test:send("next")
			end
		end
	end

	if query:match("^previous$") then
		local status = test:getStatus(false, "state")
		if status == "play" then
			test:send("previous")
		end		
	end

	if query:match("^idle mixer") then
		test:send("idle mixer")
	end

	if query:match("^idle player") then
		test:send("idle player")
	end

	if query:match("^noidle$") then
		test:send("noidle")
	end

	if query:match("^music_directory$") then
		local handle = io.popen('cat ~/.mpd/mpd.conf | grep music_directory.*/')
		local musicDir = handle:read("*a"):match('"(.*)"')
		handle:close()
		print(musicDir)
	end

	if query:match("^volume$") then
		test:getStatus(true, "volume")
	end

	if query:match("^volume [%+%-]?%d+$") then
		if not query:match("[%+%-]") then
			test:send("setvol "..query:match("%d+"))
			print("Volume changed to "..query:match("%d+"))
		else
			local currentVol = tonumber(test:getStatus().volume)
			local diff = tonumber(query:match("[%+%-]%d+"))
			local newVol = math.max(math.min(100, currentVol+diff), 0)
			test:send("setvol "..newVol)
			print("Volume changed to "..newVol)
		end
	end

	if query:match("^repeat$") then
		local state = test:getStatus(false, "repeat")
		print("Repeat mode "..(state == "0" and "off" or "on"))
	end

	if query:match("^repeat toggle$") then
		local state = test:getStatus(false, "repeat")
		test:send("repeat "..(state == "0" and "1" or "0"))
		print("Repeat mode "..(state == "0" and "on" or "off"))
	end

	-----------------------
	-- playlist commands --
	-----------------------
	if query:match("^playlist$") then
		test:getPlaylist(true)
	end

	if query:match("^playlist move %d+[:%d+]* %d") then
		local from, move_to = query:match("^playlist move (%d+[:%d+]*) (%d+)")
		local to = from:match(":(%d+)")
		from = from:match("^%d+")
		if to then
			test:send('move '..(tonumber(from)-1)..':'..to..' '..(tonumber(move_to)-1))
			print("Moved songs "..from.." to "..to.." to position "..move_to)
		else
			test:send('move '..(tonumber(from)-1)..' '..(tonumber(move_to)-1))
			print("Moved song "..from.." to position "..move_to)
		end		
	end

	-- delete playlist entries
	if query:match("^playlist delete %d+[:%d+]*") then
		local from = tonumber(query:match("%d+"))
		local to = tonumber(query:match("%d+$"))
		if to and to ~= from then
			if to < from then
				from, to = to, from
			end
			from = from - 1
			to = math.min(to, #(test:getPlaylist()))
			test:send("delete "..from..":"..to)
			print("Deleted songs "..(from+1).." to "..to.." from playlist")
		else
			test:send("delete "..(from-1))
			print("Deleted song "..from.." from playlist")
		end
	end

	if query:match("^playlist delete last$") then
		local index = #(test:getPlaylist()) - 1
		test:send("delete "..index)
		print("Deleted last song from playlist")
	end

	-- add songs or albums to current playlist or replace playlist with those songs
	if query:match('^playlist add %d+[:%d+]*') or query:match('^playlist replace %d+[:%d+]*') then
		local artist = queryPath:match('|([^|]+)')
		local album = queryPath:match('|.*|(.*)')

		local list = nil
		if album then
			list = test:getSongs(artist, album)
		else
			list = test:getAlbums(artist)
		end

		local from = math.min(tonumber(query:match('^playlist %w+ (%d+)')), #list)
		local to = tonumber(query:match('^playlist %w+ %d+:(%d+)')) or from

		if to then to = math.min(to, #list) end

		local keyword = query:match('^playlist (%w+)')
		if keyword == 'replace' then
			test:send("clear")
			print("Playlist cleared.")
		end
	
		-- get the list of albums or songs to be selected from
		if from == 0 then
			if album then
				test:send('findadd artist "'..artist..'" album "'..album..'"')
				print("Album »"..album.."« added to the playlist.")
			else
				test:send('findadd artist "'..artist..'"')
				print("Added all albums by "..artist.." to the playlist.")
			end
		else
			for i = from, to do
				if album then
					test:send('findadd artist "'..artist..'" album "'..album..'" title "'..list[i].Title..'"')
					print("Song »"..list[i].Title.."« added to the playlist.")
				else
					test:send('findadd artist "'..artist..'" album "'..list[i].album..'"')
					print("Album »"..list[i].album.."« added to the playlist.")
				end
			end
		end
	end

	----------------------
	-- database queries --
	----------------------

	if query:match("^update$") then
		test:send("update")
		print("Updated DB successfully")
	end

	if query:match("^artists$") then
		test:getArtists(true)
		queryPath = "|"
	end

	if query:match("^%.%.$") then
		if queryPath:match("^|[^|]+$") then
			print("queryPath match 1, "..queryPath)
			queryPath = "|"
			test:getArtists(true)
		elseif queryPath:match("^|.*|.*") then
			print("queryPath match 2")
			queryPath = queryPath:match("^(|.*)|.*")
			test:getAlbums(queryPath:match("^|(.*)"), true)
		end
	end

	if query:match("^lyrics$") then
		local file = test:getCurrentSong(false, "file")
		local lyrics = musicDir.."/"..file:gsub("^(.*/)(.*).mp3$", "%1lyrics/%2")

		local handle = io.popen('if [[ -e "'..lyrics..'" ]]; then echo 1; fi')
		local found = handle:read("*all*")
		handle:close()

		if found:match("1") then
			os.execute('cat "'..lyrics..'" | less')
		else
			print("No lyrics available.")
		end
	end

	-- query level 0: |
	-- list albums for selected artist
	if query:match("^%d+$") and queryPath:match("^|$") then
		local artists = test:getArtists()
		local selection = tonumber(query)
		
		if selection >= 1 and selection <= #artists then
			local artist = artists[selection]
			queryPath = '|'..artist
			local albums = test:getAlbums(artist, true)
		else
			print("Chosen index exceeds range of artists. Choose again or start new query.")
		end
	
	-- query level 1: |artist|album
	-- list songs for selected album		
	elseif query:match('^%d+$') and queryPath:match("^|") and not queryPath:find("|", 2) then
		local artist = queryPath:gsub("^|","")
		local albums = test:getAlbums(artist)
		local selection = tonumber(query)
		if selection >= 1 and selection <= #albums then
			local album = albums[selection].album
			test:getSongs(artist, album, true)
			queryPath = '|'..artist..'|'..album
		end
		
	-- catch »%[artist] %[album]« queries
	elseif query:match('^%%.*') then
		local artist, album = query:match("^%%(.*)%s%%(.*)")
		if not album then
			artist = test:getCorrectCase(query:match("^%%(.*)"))
			if artist then
				queryPath = '|'..artist
				test:getAlbums(artist, true)
			else
				print("Artist not found in the database!")
			end
		else
			artist_tmp, album_tmp = test:getCorrectCase(artist, album)
			if artist_tmp and album_tmp then
				queryPath = '|'..artist_tmp..'|'..album_tmp
				test:getSongs(artist_tmp, album_tmp, true)
			else
				print("No album »"..album.."« found for artist "..artist.."!")
			end
		end		
	end

	if #args > 0 then
		break
	end
end