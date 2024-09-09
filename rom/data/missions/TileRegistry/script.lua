-- Packaged by Leopard's packager&minifier, version 0.1.1
-- Original file name: TileRegistry/init.lua
-- Packaged at: 2024-08-31T14:24:08Z

local script_name = "TileRegistry"

sandbox = {}

-- Detect and setup sandbox-escaped lua
stormworks_debug = debug
real_debug = ebug
debug = real_debug


local writer = stormworks_debug and stormworks_debug.log
	or function(_) end

debug_log_writer = writer


writer("Initial load: "..script_name)

-- Lua 5.1 <> 5.3 compatibility
_G = _G or _ENV

-- Store info about the sandbox for feature detection.
sandbox.dofile  = dofile and true
sandbox.package = package and true
sandbox.require = require and true

if not debug or not debug.traceback then
	writer("Warning: debug.traceback not available: errors will not generate stack traces!")
end

-- We use an environment variable so that the full path to the script does not end up in the packaged script.
local workspace_root = os and os.getenv and os.getenv("Stormworks_AddonLua_Folder")
--writer("workspace_root = "..tostring(workspace_root))
_G.workspace_root = workspace_root


-- These patterns are applied to all require invocations.
-- We use this to remove cases where the ProjectName/ScriptName is prefixed
-- to disambiguate files that exist in multiple missions.
-- Doing that is only needed for the language server to not be confused
-- but if not done consistently you end up with the same file required under multiple names
-- causing it to run twice (and breaking stuff)
-- Instead of being consistent we just patch require to untangle the mess we made.
_require_gsub_pattern = script_name..'%.'
_require_gsub_replace = ''

-- Function for protection, if available.
local function __main__()

-- If dofile is available use it, since it makes errors and stack traces nicer to read.
if workspace_root and dofile then
	if not require then
		writer('Loading package and require from file.')
		require = dofile(workspace_root..'/missions/lib/require.lua')
	end

	writer('Loading using dofile...')
	dofile(workspace_root..'/missions/TileRegistry/init.lua')
	return
elseif dofile then
	writer('dofile is available but workspace_root is not.')
end

writer('Loading from packaged script...')


-- Packaged script:
package = {
	preload = {
		config = function ()
			local config = {
				logging = {
					legacyHttp = { enabled = false },
					terminal = {
						enabled = true,
						ansi_colors = true
					},
					debug_log = { enabled = true },
					file = { enabled = false }
				},
				sandbox = { },
				rust = { enabled = true }
			}
			return config
		end,
		["lib.addonCallbacks.processing"] = function ()
			local meta_thisFileRequirePath = "lib.addonCallbacks.processing"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local serpent = require "lib.serialization.serpent"
			local lib = require "lib.addonCallbacks.registration"
			local newTimer = require "lib.timer".New
			local performance_report_limit = 100000
			local registry = lib._registry
			local performance_reports = { }
			lib.performance_reports = performance_reports
			local function update_performance_report (callback_name, caller_name, elapsed_ms)
				local key = callback_name .. (":" .. caller_name)
				local bucket = performance_reports[key]
				if bucket and bucket[performance_report_limit] then
					bucket = nil
					logger.trace ("Purging bucket '%s' because it had more than %i entries inside (performance).", key, performance_report_limit)
				end
				if not bucket then
					bucket = { }
					performance_reports[key] = bucket
				end
				table.insert (bucket, elapsed_ms)
			end
			local full_timer = newTimer ()
			local callback_timer = newTimer ()
			function lib.processCallback (name, ...)
				full_timer:restart ()
				if name == "onTick" then
					lib.current_tick_number = lib.current_tick_number + 1
				end
				local container = registry[name]
				if not container then
					return 
				end
				container.busy = true
				for _, entry in ipairs (container.registrations) do
					callback_timer:restart ()
					if not entry.handler and xpcall then
						local function handler (e)
							local s = debug.traceback (e, 2)
							logger.critical ("Uncaught Error in Callback '%s' for '%s':\n%s", entry.callbackName, entry.callerName, s)
						end
						entry.handler = handler
					end
					if entry.handler then
						xpcall (entry.fn, entry.handler, ...)
					else
						entry.fn (...)
					end
					update_performance_report (name, entry.callerName, callback_timer:elapsed () * 1000)
				end
				container.busy = false
				update_performance_report (name, "<sum>", full_timer:elapsed () * 1000)
			end
			function lib.logRegistrations ()
				logger.important ("Registrations: %s", serpent.block (registry, {
					keyignore = { register_stacktrace = true },
					metatostring = false
				}))
			end
			local callbacks = {
				"onCreate",
				"onDestroy",
				"onTick",
				"onCustomCommand",
				"onChatMessage",
				"onPlayerJoin",
				"onPlayerSit",
				"onPlayerUnsit",
				"onCharacterSit",
				"onCharacterUnsit",
				"onCharacterPickup",
				"onCreatureSit",
				"onCreatureUnsit",
				"onCreaturePickup",
				"onEquipmentPickup",
				"onEquipmentDrop",
				"onPlayerRespawn",
				"onPlayerLeave",
				"onToggleMap",
				"onPlayerDie",
				"onGroupSpawn",
				"onVehicleSpawn",
				"onVehicleDespawn",
				"onVehicleLoad",
				"onVehicleUnload",
				"onVehicleTeleport",
				"onObjectLoad",
				"onObjectUnload",
				"onButtonPress",
				"onSpawnAddonComponent",
				"onVehicleDamaged",
				"httpReply",
				"onFireExtinguished",
				"onForestFireSpawned",
				"onForestFireExtinguished",
				"onTornado",
				"onMeteor",
				"onTsunami",
				"onWhirlpool",
				"onVolcano"
			}
			for _, name in pairs (callbacks) do
				_G[name] = function (a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69, a70, a71, a72, a73, a74, a75, a76, a77, a78, a79, a80, a81, a82, a83, a84, a85, a86, a87, a88, a89, a90, a91, a92, a93, a94, a95, a96, a97, a98, a99)
					lib.processCallback (name, a01, a02, a03, a04, a05, a06, a07, a08, a09, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69, a70, a71, a72, a73, a74, a75, a76, a77, a78, a79, a80, a81, a82, a83, a84, a85, a86, a87, a88, a89, a90, a91, a92, a93, a94, a95, a96, a97, a98, a99)
				end
			end
			return lib
		end,
		["lib.addonCallbacks.registration"] = function ()
			local M = { }
			M.current_tick_number = 0
			local registry = { }
			M._registry = registry
			local function callbackSort (a, b)
				return a.order < b.order
			end
			function M.registerCallback (callbackName, callerName, fn, order)
				local container = registry[callbackName] or {
					busy = false,
					registrations = { }
				}
				registry[callbackName] = container
				if container.busy then
					error ("Attempted to add a registration to a container that is currently being processed!", 2)
				end
				local entry = {
					callbackName = callbackName,
					callerName = callerName,
					fn = fn,
					order = order or 0,
					register_stacktrace = (debug and debug.traceback) and debug.traceback ("Registration", 2)
				}
				table.insert (container.registrations, entry)
				table.sort (container.registrations, callbackSort)
			end
			function M.unregisterCallback (fn)
				for _, container in pairs (registry) do
					for i, entry in pairs (container.registrations) do
						if entry.fn == fn then
							table.remove (container.registrations, i)
							return true
						end
					end
				end
				return false
			end
			return M
		end,
		["lib.checkArg"] = function ()
			local function checkArg (pos, name, value, expected_type, expected_class)
				if not error then
					return 
				end
				local actual_type = type (value)
				if actual_type ~= expected_type then
					error (string.format ("Invalid argument #%i '%s': (%s expected, got %s)", pos, name, expected_type, actual_type), 3)
				end
				if not expected_class then
					return 
				end
				if not value.__type then
					error (string.format ("Invalid argument #%i '%s': (class %s expected, got plain table)", pos, name, expected_class), 3)
				end
				if value.__type ~= expected_class then
					error (string.format ("Invalid argument #%i '%s': (class %s expected, got %s)", pos, name, expected_class, value.__type), 3)
				end
			end
			return checkArg
		end,
		["lib.environments.stormworks"] = function ()
			_G = _G or _ENV
			_ENV = _ENV or _G
			getmetatable = getmetatable or function (t)
				return nil
			end
			setmetatable = setmetatable or function (t, mt)
				
			end
			pcall = pcall or function (f, ...)
				return true, f (...)
			end
			if not assert then
				function assert (v, m)
					if v then
						return v
					else
						error (m)
					end
				end
			end
			select = select or function (index, ...)
				local args = { ... }
				if index == "#" then
					return # args
				end
				if type (index) ~= "number" then
					error "Incorrect argument #1, expected integer or '#'."
				end
				if index < 0 then
					index = (# args + index) + 1
				end
				return table.unpack (args, index)
			end
			if not error then
				function error (m)
					server.announce ("Uncaught script error", m,  - 1)
					local error
					error ()
				end
				error_is_server_announce = true
			end
		end,
		["lib.executeAtTick"] = function ()
			local file_identifier = "lib.executeAtTickLib"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local executeAtTickLib = { }
			local tickFunctionBuckets = { }
			local tickFunctionNextToken = 0
			function executeAtTickLib.executeAtTick (tick, fun)
				if tick <= addonCallbacks.current_tick_number then
					return nil
				end
				local collection = tickFunctionBuckets[tick] or { }
				tickFunctionBuckets[tick] = collection
				local token = tickFunctionNextToken
				tickFunctionNextToken = token + 1
				collection[token] = fun
				return token
			end
			function executeAtTickLib.executeAfterTicks (numTicks, fun)
				return executeAtTickLib.executeAtTick (addonCallbacks.current_tick_number + numTicks, fun)
			end
			function executeAtTickLib.cancelExecuteAtTick (token)
				if not token then
					error "Invalid token"
				end
				for tick, collection in pairs (tickFunctionBuckets) do
					if collection[token] then
						collection[token] = nil
						if not next (collection) then
							tickFunctionBuckets[tick] = nil
						end
						return true
					end
				end
				return false
			end
			function executeAtTickLib.next_timer ()
				local min = math.huge
				for tick_no, v in pairs (tickFunctionBuckets) do
					min = math.min (min, tick_no)
				end
				if min == math.huge then
					return nil, nil
				end
				return min, min - addonCallbacks.current_tick_number
			end
			local function m_onTick ()
				local last_tick = addonCallbacks.current_tick_number - 2
				for i = last_tick, addonCallbacks.current_tick_number do
					local collection = tickFunctionBuckets[i]
					tickFunctionBuckets[i] = nil
					if collection then
						for token, fun in pairs (collection) do
							fun ()
						end
					end
				end
				executeAtTickLib.any_waiting = (next (tickFunctionBuckets) and true) or false
			end
			addonCallbacks.registerCallback ("onTick", file_identifier, m_onTick)
			return executeAtTickLib
		end,
		["lib.http"] = function ()
			local allow_standalone_even_in_stormworks = false
			local lib = require "lib.http.lib"
			if (((not server or not server.httpGet) or allow_standalone_even_in_stormworks) and pcall) and pcall (require, "socket.http") then
				require "lib.http.standalone"
			end
			return lib
		end,
		["lib.http.lib"] = function ()
			local meta_thisFileRequirePath = "lib.http.lib"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local config = require "config"
			local base64 = require "lib.serialization.base64"
			local executeAtTickLib = require "lib.executeAtTick"
			local executeAfterTicks = executeAtTickLib.executeAfterTicks
			local cancelExecuteAtTick = executeAtTickLib.cancelExecuteAtTick
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local function do_nothing ()
				
			end
			local httpLib = { }
			httpLib.timeout_ticks = 60 * 60
			function httpLib.create_expect_success_handler (expected, name)
				local f = function (port, url, response, response_time)
					if expected[response] then
						return true
					end
					local message = string.format ("Server returned error response for '%s':\n%s", name, response)
					server.announce ("Error", message, 0)
					logger.error (message)
					return false
				end
				return f
			end
			local timeout_message_interval = 60 * 10
			local timeout_last_tick_no = 0
			local num_timeouts = 0
			function httpLib.timeout_handler_log (port, url, wait_time)
				num_timeouts = num_timeouts + 1
				if addonCallbacks.current_tick_number < timeout_last_tick_no + timeout_message_interval then
					return 
				end
				timeout_last_tick_no = addonCallbacks.current_tick_number
				logger.error ("%i messages timed out in the last %.1fs.", num_timeouts, timeout_message_interval / 60)
				num_timeouts = 0
			end
			local query_spec = {
				{
					field = "prefix",
					format = "%s",
					required = true
				},
				{
					field = "path",
					format = "%s",
					required = false
				},
				{
					field = "action",
					format = "?action=%s",
					required = true
				},
				{
					field = "sequenceNumber",
					format = "&sequence_no=%s",
					required = true
				},
				{
					field = "partNumber",
					format = "&part_no=%s",
					required = false
				},
				{
					field = "data",
					format = "&data=%s",
					required = false
				}
			}
			local function constructURL (data)
				local query_str = ""
				for _, spec in ipairs (query_spec) do
					local value = data[spec.field]
					if not value and spec.required then
						return false, string.format ("Field '%s' is required.", spec.field)
					end
					if value then
						query_str = query_str .. string.format (spec.format, value)
					end
				end
				return query_str
			end
			local pending_message_buckets = { }
			local function registerMessage (port, url, response_handler, timeout_handler, timeout_ticks)
				local bucket = pending_message_buckets[port] or { }
				pending_message_buckets[port] = bucket
				timeout_handler = timeout_handler or httpLib.timeout_handler_log
				local send_time = server.getTimeMillisec ()
				local function wrapper ()
					local wait_time = server.getTimeMillisec () - send_time
					bucket[url] = nil
					timeout_handler (port, url, wait_time)
				end
				bucket[url] = {
					port = port,
					url = url,
					response_handler = response_handler or do_nothing,
					timeout_handler = timeout_handler,
					send_time = send_time,
					timeout_cancel_token = executeAfterTicks (timeout_ticks or httpLib.timeout_ticks, wrapper)
				}
			end
			function httpLib.Endpoint (port, prefix)
				assert (port)
				prefix = prefix or ""
				local endpoint = {
					max_data_length = 3000,
					sequenceNumber = 0,
					port = port,
					prefix = prefix
				}
				function endpoint.send_single (path, action, string_data, response_handler, timeout_handler, partNumber)
					if not config.rust.enabled then
						return 
					end
					local query_spec = {
						prefix = endpoint.prefix,
						path = path,
						action = action,
						sequenceNumber = endpoint.sequenceNumber,
						partNumber = partNumber,
						data = base64.encode (string_data)
					}
					local query_string = constructURL (query_spec)
					if not query_string then
						return false
					end
					endpoint.sequenceNumber = endpoint.sequenceNumber + 1
					registerMessage (endpoint.port, query_string, response_handler, timeout_handler)
					server.httpGet (endpoint.port, query_string)
				end
				function endpoint.send_iterator (path, action, iterator, response_evaluator, completion_handler, failure_handler)
					if not config.rust.enabled then
						return 
					end
					if not action then
						return false, "missing parameter: action"
					end
					if not iterator then
						return false, "missing parameter: iterator"
					end
					if not response_evaluator then
						return false, "missing parameter: response_evaluator"
					end
					completion_handler = completion_handler or do_nothing
					failure_handler = failure_handler or do_nothing
					local timeout_handler = function (port, url, wait_time)
						failure_handler ("timeout", port, url)
					end
					local state = { }
					local partNumber = 0
					function state.my_next_handler ()
						local next_data = iterator ()
						if not next_data then
							completion_handler ()
							return 
						end
						endpoint.send_single (path, action, next_data, state.my_response_handler, timeout_handler, partNumber)
						partNumber = partNumber + 1
						if string.lower (action) == "replace" then
							action = "append"
						end
					end
					function state.my_response_handler (port, url, response, response_time)
						local may_continue = response_evaluator (port, url, response, response_time)
						if not may_continue then
							failure_handler ("error", port, url, response, response_time)
							return 
						end
						state.my_next_handler ()
					end
					state.my_next_handler ()
				end
				function endpoint.send (path, action, huge_data, response_evaluator, completion_handler, failure_handler)
					local len = # huge_data
					if not config.rust.enabled then
						return 
					end
					if len < endpoint.max_data_length then
						local function my_response_handler (...)
							if response_evaluator (...) then
								return completion_handler (...)
							else
								return failure_handler (...)
							end
						end
						return endpoint.send_single (path, action, huge_data, my_response_handler, failure_handler)
					end
					local start_index = 1
					local function iterator ()
						local end_index = start_index + endpoint.max_data_length
						local string_data = huge_data:sub (start_index, end_index - 1)
						if # string_data < 1 then
							return nil
						end
						start_index = end_index
						return string_data
					end
					return endpoint.send_iterator (path, action, iterator, response_evaluator, completion_handler, failure_handler)
				end
				return endpoint
			end
			local function my_httpReply (port, url, response)
				local bucket = pending_message_buckets[port]
				if not bucket then
					return 
				end
				local message = bucket[url]
				if not message then
					return 
				end
				bucket[url] = nil
				if message.timeout_cancel_token then
					cancelExecuteAtTick (message.timeout_cancel_token)
				end
				local response_time = server.getTimeMillisec () - message.send_time
				message.response_handler (message.port, message.url, response, response_time)
			end
			addonCallbacks.registerCallback ("httpReply", meta_thisFileRequirePath, my_httpReply)
			return httpLib
		end,
		["lib.http.standalone"] = function ()
			local meta_thisFileRequirePath = "lib.http.standalone"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local require_that_mainfier_cannot_see = require
			local libSocket = require_that_mainfier_cannot_see "socket"
			server = server or { }
			local M = { last_pump_message_count = 0 }
			local pending_responses = { }
			local connections = { }
			local function trySend (port, url, is_retry)
				local connection, err = connections[port], nil
				if not connection then
					logger.trace ("Making fresh connection for port %i.", port)
					connection, err = libSocket.connect ("localhost", port)
					if not connection then
						connections[port] = nil
						logger.warning ("Failed to connect to port %i: %s", port, err)
						return nil, err
					end
					logger.trace ("Connected to port %i", port)
				else
					logger.trace ("Using existing connection for port %i.", port)
				end
				local numByte, err = connection:send (string.format ("GET %s HTTP/1.1\13\nHost: localhost\13\nConnection: keep-alive\13\n\13\n", url))
				logger.trace ("numByte: %s, err: %s", numByte, err)
				if not numByte and (err == "closed" or err == "timeout") then
					if is_retry then
						local msg = string.format ("Not trying again after second attempt sending to port %i resulted in error: %s", port, err)
						logger.warning (msg)
						return nil, msg
					end
					logger.trace ("Connection for port %i timed out or closed, trying again...", port)
					connections[port] = nil
					return trySend (port, url, true)
				end
				connections[port] = connection
				return true
			end
			local function tryReadResponse (connection)
				local headers = { }
				local response, err = connection:receive "*l"
				if not response then
					return {
						success = false,
						message = err
					}
				end
				local _, _, http_version, http_code, http_code_name = string.find (response, "([%w%d/\\.-]) (%d+) (.*)")
				while true do
					local line = connection:receive "*l"
					if line == "" then
						break
					end
					local _, _, key, value = string.find (line, "([%w-]+): (.*)")
					headers[key] = value
					key = string.lower (key)
					headers[key] = value
				end
				local body = ""
				local content_length = headers["content-length"] and tonumber (headers["content-length"])
				if not content_length or content_length <= 0 then
					logger.dump "No content"
					return {
						success = true,
						http_code = http_code,
						http_code_name = http_code_name,
						headers = headers,
						body = body
					}
				end
				local body, reason, partial = connection:receive (content_length)
				logger.dump ("Body: '%s' reason: '%s' partial: '%s'", body or "nil", reason or "nil", partial or "nil")
				if not body then
					error (reason)
				end
				return {
					success = true,
					http_code = http_code,
					http_code_name = http_code_name,
					headers = headers,
					body = body
				}
			end
			M._read_response = tryReadResponse
			function server.httpGet (port, url)
				local start = os.clock ()
				local s, reason = trySend (port, url, false)
				if not s then
					logger.warn ("Failed to send data to port %i: %s", port, reason)
					return 
				end
				local response = tryReadResponse (connections[port])
				if not response.success and response.message == "closed" then
					logger.warning "Request failed with reason 'closed' on read, trying entire request again..."
					connections[port] = nil
					local s, reason = trySend (port, url, true)
					if not s then
						logger.warn ("Failed to send data to port %i: %s", port, reason)
						return 
					end
					response = tryReadResponse (connections[port])
					if not response.success then
						error "Failed to read from response on retry."
					end
				end
				local body, code, headers, status = response.body, response.http_code, response.headers, response.http_code_name
				local pending = {
					port = port,
					url = url,
					code = code,
					status = status,
					body = body
				}
				table.insert (pending_responses, pending)
				local elapsed = os.clock () - start
				logger.trace ("Completed request + response in %4.2fs", elapsed)
			end
			function M.pumpMessages ()
				local counter = 0
				while true do
					local r = table.remove (pending_responses, 1)
					if not r then
						break
					end
					counter = counter + 1
					if type (httpReply) == "function" then
						local port = r.port
						local query = r.url
						local status = r.status
						local body = r.body
						if not body or # body == 0 then
							body = tostring (status)
						end
						httpReply (port, query, body)
					end
				end
				M.last_pump_message_count = counter
				return counter
			end
			addonCallbacks.registerCallback ("onTick", meta_thisFileRequirePath, M.pumpMessages)
			return M
		end,
		["lib.keyValueParser"] = function ()
			local function parseKeyValuePairs (input)
				local result = { }
				local i = 1
				local len = # input
				local key, value, inQuotes, quoteChar
				local function tryAddValue ()
					if not key or key == "" then
						return 
					end
					if value then
						result[key] = value
					else
						result[key] = true
					end
				end
				while i <= len do
					local char = input:sub (i, i)
					if char == "=" and not inQuotes then
						key = (key and key:match "^%s*(.-)%s*$") or ""
						value = ""
						i = i + 1
					elseif char == "\"" or char == "'" then
						if inQuotes then
							if char == quoteChar then
								inQuotes = false
								quoteChar = nil
								tryAddValue ()
								key = nil
								value = nil
							else
								value = value .. char
							end
						else
							inQuotes = true
							quoteChar = char
						end
						i = i + 1
					elseif char == "," and not inQuotes then
						tryAddValue ()
						key, value = nil, nil
						i = i + 1
					else
						if value ~= nil then
							value = value .. char
						else
							key = (key or "") .. char
						end
						i = i + 1
					end
				end
				tryAddValue ()
				return result
			end
			return parseKeyValuePairs
		end,
		["lib.legacyHttp"] = function ()
			local moreTable = require "lib.moreTable"
			local clearTable = moreTable.clearTable
			local serpent = require "lib.serialization.serpent"
			local base64 = require "lib.serialization.base64"
			local function CreateLegacyHttpService (port, path)
				local service = { }
				service.port = port
				service.path = path
				service.serializerOpts = nil
				service.maxQueryLength = 1000
				service.sequenceNumber = 0
				do
					local ql = service.maxQueryLength or 1000
					local rem = ql % 4
					ql = ql - rem
					service.maxQueryLength = ql
				end
				function service.getUnique ()
					
				end
				local function splitData (container, ...)
					container = container or { }
					clearTable (container)
					local args = { ... }
					local data = ""
					if # args == 1 and type (args[1]) == "string" then
						data = args[1]
					elseif # args == 1 then
						data = serpent.block (args[1], service.serializerOpts)
					else
						data = serpent.block (args, service.serializerOpts)
					end
					repeat
						local d = base64.encode (data:sub (1, service.maxQueryLength))
						table.insert (container, d)
						data = data:sub (service.maxQueryLength + 1,  - 1)
						service.sequenceNumber = service.sequenceNumber + 1
					until # data < 1
					return container
				end
				local function send (action, time, content)
					local partNo = 0
					for i, d in ipairs (content) do
						server.httpGet (service.port, string.format ("%s?action=%s&sequence_no=%i&part_no=%i&t=%i&data=%s", service.path, action, service.sequenceNumber, partNo, time, d))
						partNo = partNo + 1
						action = "Append"
					end
				end
				function service.append (...)
					local time = server.getTimeMillisec ()
					local datas = splitData ({ }, ...)
					send ("Append", time, datas)
				end
				function service.delete ()
					local time = tostring (server.getTimeMillisec ())
					server.httpGet (service.port, string.format ("%s?action=%s&t=%i", service.path, "Delete", time))
				end
				function service.replace (...)
					local time = server.getTimeMillisec ()
					local datas = splitData ({ }, ...)
					send ("Replace", time, datas)
				end
				function flush ()
					
				end
				return service
			end
			return CreateLegacyHttpService
		end,
		["lib.logging.api"] = function ()
			local meta_thisFileRequirePath = "lib.logging.api"
			local checkArg = require "lib.checkArg"
			local levelSpec = require "lib.logging.levels"
			local logLevelNameLength = levelSpec.logLevelNameLength
			local name2level = levelSpec.name2level
			local level2name = levelSpec.level2name
			local loggerNameLength = 50
			local libFilter = require "lib.logging.logFilter"
			local applyDefaultFilters = require "lib.logging.filters"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local pcall = pcall or function (f, ...)
				return true, f (...)
			end
			local terminal = require "lib.logging.backend.terminal"
			local debug_log = require "lib.logging.backend.debug_log"
			local transports = { }
			if debug_log then
				table.insert (transports, debug_log)
			end
			if terminal then
				table.insert (transports, terminal)
			end
			if # transports < 1 then
				local file = require "lib.logging.backend.file"
				if file then
					table.insert (transports, file)
				else
					local web = require "lib.logging.backend.legacyServer"
					if web then
						table.insert (transports, web)
					end
					local chat = require "lib.logging.backend.chat"
					table.insert (transports, chat)
				end
			end
			local lib = { global_prefix = "?" }
			lib.transport = transports[1]
			lib.mainFilter = libFilter.createFilter ()
			applyDefaultFilters (lib.mainFilter)
			function lib.LogLevelSource (level, source, message)
				checkArg (1, "level", level, "number")
				checkArg (2, "source", source, "string")
				checkArg (3, "message", message, "string")
				lib.LogLevelSourceFormat (level, source, message)
			end
			local function callDeferredEvaluators (...)
				local arr = { ... }
				for i, v in ipairs (arr) do
					if type (v) == "function" then
						arr[i] = v ()
					end
				end
				return table.unpack (arr)
			end
			function lib.LogLevelSourceFormat (level, source, format, ...)
				checkArg (1, "level", level, "number")
				checkArg (2, "source", source, "string")
				checkArg (3, "format", format, "string")
				local levelStr = level2name[level]
				if not levelStr then
					error ("Invalid argument #1 'level': expected a logLevel integer but '" .. (level .. "' is not a known logLevel."), 2)
				end
				source = lib.global_prefix .. ("!" .. source)
				if not lib.mainFilter.shouldLog (level, source) then
					return 
				end
				local s, str = pcall (string.format, format, callDeferredEvaluators (...))
				if not s then
					local args = ""
					for i, v in ipairs { ... } do
						args = args .. ("\n" .. ((i + 1) .. (" " .. tostring (v))))
					end
					error ("Failed to format log message: " .. (str .. (" | Provided format string: \n" .. (format .. ("\nArgument list (format above is #1):" .. args)))))
				end
				local adjustedName = source .. string.rep ("_", loggerNameLength - source:len ())
				local header = string.format ("[%-" .. (logLevelNameLength .. "s] %s | "), levelStr, adjustedName)
				str = header .. str
				for _, v in ipairs (transports) do
					v.append (str, level)
				end
			end
			function lib.clear ()
				for _, v in ipairs (transports) do
					if v.delete then
						v.delete ()
					end
				end
			end
			local function my_onCreate ()
				lib.setTick ( - 1)
			end
			addonCallbacks.registerCallback ("onCreate", meta_thisFileRequirePath, my_onCreate,  - 1000000)
			local function my_onTick ()
				for _, v in pairs (transports) do
					if type (v) == "table" then
						v.current_tick_no = (v.current_tick_no or 0) + 1
					end
				end
			end
			addonCallbacks.registerCallback ("onTick", meta_thisFileRequirePath, my_onTick,  - 1000000)
			function lib.setTick (tick)
				checkArg (1, "tick", tick, "number")
				for _, v in pairs (transports) do
					if type (v) == "table" then
						v.current_tick_no = tick
					end
				end
			end
			lib.setTick ( - 2)
			if not no_logging_on_logger_init then
				lib.LogLevelSourceFormat (name2level.trace, meta_thisFileRequirePath, "Started logging API using backend: %s", lib.transport.name)
			end
			function lib.active_transports ()
				local r = { }
				for _, v in pairs (transports) do
					table.insert (r, v)
				end
				return r
			end
			return lib
		end,
		["lib.logging.backend.chat"] = function ()
			local config = require "config"
			local lib = { }
			lib.name = "in-game chat"
			lib.log_receiving_peers = { }
			function lib.message (title, body)
				for peer_id in pairs (lib.log_receiving_peers) do
					server.announce (title, body, peer_id)
				end
			end
			function lib.message_no_title (body)
				lib.message (config.script_name, body)
			end
			return lib
		end,
		["lib.logging.backend.debug_log"] = function ()
			local writer = ((debug and debug.log) or (stormworks_debug and stormworks_debug.log)) or debug_log_writer
			if not writer then
				return false
			end
			local writer_max_length = 4091
			local continuation = "%%%_LAST_MESSAGE_CONTINUED_%%%"
			local continuation_slice_length = writer_max_length - # continuation
			local clear_command_text = "%%%_CLEAR_LOG_WINDOW_%%%"
			local config = require "config"
			local moreString = require "lib.moreString"
			local millisecondsToHumanTime = moreString.millisecondsToHumanTime
			local lib = { }
			lib.name = "debug.log (to external program)"
			lib.current_tick_no =  - 4
			local _getRealTimeStamp
			if (os and os.time) and os.date then
				function _getRealTimeStamp ()
					local current_time = os.time ()
					local time_str = os.date ("!%Y-%m-%dT%H:%M:%S", current_time)
					local milliseconds = current_time % 1000
					time_str = time_str .. string.format (".%04.0fZ", milliseconds)
					return time_str
				end
			else
				function _getRealTimeStamp ()
					return "~~~~-~~-~~T~~:~~:~~.~~~~Z"
				end
			end
			local function getRealTimeStamp ()
				local s, r = pcall (_getRealTimeStamp)
				return (s and r) or "unknown"
			end
			function lib.append (str)
				if not config.logging.debug_log or not config.logging.debug_log.enabled then
					return 
				end
				local system_time = getRealTimeStamp ()
				local game_time = millisecondsToHumanTime (server.getTimeMillisec ())
				data = string.format ("%28s (%12s) %4d %s\n", system_time, game_time, lib.current_tick_no, str)
				local needContinuation = false
				while 0 < # data do
					if not needContinuation then
						local part = data:sub (1, writer_max_length)
						writer (part)
						data = data:sub (writer_max_length + 1,  - 1)
					else
						local part = continuation .. data:sub (1, continuation_slice_length)
						writer (part)
						data = data:sub (continuation_slice_length + 1,  - 1)
					end
					needContinuation = true
				end
				writer (data)
			end
			function lib.delete ()
				writer (clear_command_text)
			end
			return lib
		end,
		["lib.logging.backend.file"] = function ()
			if (not io or not pcall) or package.loaded.busted then
				return false
			end
			local config = require "config"
			if not config.logging.file or not config.logging.file.enabled then
				return false
			end
			local moreString = require "lib.moreString"
			local millisecondsToHumanTime = moreString.millisecondsToHumanTime
			local logFilePath = string.format ("%s%s", config.sandbox.server_content, config.logging.legacyHttp.HttpLogFile)
			local lib = { }
			lib.name = "file io (sandbox escape)"
			lib.directToFileSystemLogging = true
			lib.current_tick_no =  - 4
			local function _getRealTimeStamp ()
				local current_time = os.time ()
				local time_str = os.date ("!%Y-%m-%dT%H:%M:%S", current_time)
				local milliseconds = current_time % 1000
				time_str = time_str .. string.format (".%04.0fZ", milliseconds)
				return time_str
			end
			local function getRealTimeStamp ()
				local s, r = pcall (_getRealTimeStamp)
				return (s and r) or "unknown"
			end
			function lib.append (str)
				local logFile, emsg = io.open (logFilePath, "a")
				if not logFile then
					error (string.format ("Error opening file: '%s': ", logFilePath, emsg))
				end
				local system_time = getRealTimeStamp ()
				local game_time = millisecondsToHumanTime (server.getTimeMillisec ())
				data = string.format ("[%28s (%12s) %4d] %s\n", system_time, game_time, lib.current_tick_no, str)
				logFile:write (data)
				logFile:close ()
			end
			function lib.delete ()
				os.remove (logFilePath)
			end
			return lib
		end,
		["lib.logging.backend.legacyServer"] = function ()
			local config = require "config"
			local CreateLegacyHttpService = require "lib.legacyHttp"
			local endpoint = CreateLegacyHttpService (config.logging.legacyHttp.server_port, config.logging.legacyHttp.HttpLogFile)
			local lib = { }
			lib.name = "http server (legacy http)"
			lib.current_tick_no =  - 4
			local function isEnabled ()
				return (config.logging and config.logging.legacyHttp) and config.logging.legacyHttp.enabled
			end
			function lib.append (str)
				if not isEnabled () then
					return 
				end
				endpoint.append (string.format (" %4d] %s", lib.current_tick_no, str))
			end
			function lib.delete ()
				if not isEnabled () then
					return 
				end
				endpoint.delete ()
			end
			return lib
		end,
		["lib.logging.backend.terminal"] = function ()
			if (not print or not pcall) or not os then
				return false
			end
			local config = require "config"
			local moreString = require "lib.moreString"
			local millisecondsToHumanTime = moreString.millisecondsToHumanTime
			local l = require "lib.logging.levels".name2level
			local lib = { }
			lib.name = "terminal (external/standalone lua environment)"
			lib.current_tick_no =  - 4
			local level_to_color = {
				[l.dump] = "\27[38;2;128;128;128m",
				[l.debug] = "\27[38;2;169;169;169m",
				[l.trace] = "\27[38;2;255;255;255m",
				[l.verbose] = "\27[38;2;0;0;255m",
				[l.information] = "\27[38;2;0;128;0m",
				[l.important] = "\27[38;2;50;205;50m",
				[l.warning] = "\27[38;2;255;255;0m",
				[l.error] = "\27[38;2;255;165;0m",
				[l.critical] = "\27[38;2;255;0;0m"
			}
			local function _getRealTimeStamp ()
				local current_time = os.time ()
				local time_str = os.date ("!%Y-%m-%dT%H:%M:%S", current_time)
				local milliseconds = os.clock () * 1000
				time_str = time_str .. string.format (".%03dZ", milliseconds)
				return time_str
			end
			local function getRealTimeStamp ()
				local s, r = pcall (_getRealTimeStamp)
				return (s and r) or "unknown"
			end
			function lib.append (str, level)
				if not config.logging.terminal or not config.logging.terminal.enabled then
					return 
				end
				local game_time = millisecondsToHumanTime (((server and server.getTimeMillisec ()) or (os and os.clock ())) or 0)
				data = string.format ("%12s %4s | %s", game_time, lib.current_tick_no, str)
				local color = level_to_color[level]
				if ((color and config.logging) and config.logging.terminal) and config.logging.terminal.ansi_colors then
					data = color .. (data .. "\27[0m")
				end
				print (data)
			end
			function lib.delete ()
				print "![2J![H"
			end
			return lib
		end,
		["lib.logging.filters"] = function ()
			local levels = require "lib.logging.levels"
			local l = levels.name2level
			local function applyDefaultFilters (filter)
				filter.minimum (l.dump, "*")
				filter.minimum (l.dump, "lib.addon.zone")
				filter.minimum (l.info, "lib.addon.addon.generateObjectByTypeMapping")
				filter.minimum (l.info, "lib.require_error_handler")
				filter.minimum (l.info, "lib.saveData")
				filter.minimum (l.info, "lib.uid")
				filter.minimum (l.debug, "lib.doublyIndexedTable")
				filter.minimum (l.verbo, "lib.scoop.lib")
				filter.minimum (l.warn, "lib.scoop.lib.callConstructors")
				filter.minimum (l.dump, "lib.scoop.classes.VehicleBoundObject")
				filter.minimum (l.dump, "lib.scoop.classes.VehicleBoundObject.class")
				filter.minimum (l.dump, "lib.scoop.classes.VehicleBoundObject.disappear_handling")
				filter.minimum (l.verbose, "lib.scoop.classes.VehicleBoundObject.COM_offset")
				filter.minimum (l.info, "lib.pathfinder")
				filter.minimum (l.verbose, "lib.pathfinder.pathIterator")
				filter.minimum (l.dump, "lib.commands")
				filter.minimum (l.debug, "lib.vehicleObjects")
				filter.minimum (l.debug, "lib.vehicleObjects.spawnAll_iterator")
				filter.minimum (l.dump, "lib.profiler2")
				filter.minimum (l.warning, "lib.http.standalone")
				filter.minimum (l.warning, "lib.kdtree")
				filter.minimum (l.info, "common.objects.commands")
				filter.minimum (l.verbose, "common.mod_objects.trafficLights")
				filter.minimum (l.dump, "main")
				filter.minimum (l.trace, "main.onVehicleSpawn")
				filter.minimum (l.verbo, "scoop")
				filter.minimum (l.info, "scoop.classes.Junction")
				filter.minimum (l.dump, "scoop.classes.Signal")
				filter.minimum (l.verbo, "scoop.classes.Sign")
				filter.minimum (l.dump, "scoop.classes.Wagon")
				filter.minimum (l.debug, "scoop.classes.Wagon.update.update")
				filter.minimum (l.dump, "scoop.classes.Train")
				filter.minimum (l.dump, "scoop.classes.Train.init")
				filter.minimum (l.info, "scoop.classes.Train.update.reservation")
				filter.minimum (l.dump, "scoop.classes.Train.events")
				filter.minimum (l.important, "scoop.classes.Train.update.lzb")
				filter.minimum (l.dump, "trainTrack.raw.loader")
				filter.minimum (l.trace, "trainTrack.raw.loader.fix_long_segments")
				filter.minimum (l.trace, "trainTrack.raw.loader.connect_within_tile")
				filter.minimum (l.trace, "trainTrack.raw.loader.connect_between_tiles")
				filter.minimum (l.dump, "trainTrack.loader")
				filter.minimum (l.trace, "trainTrack.raw.loader.reduceDetail")
				filter.minimum (l.trace, "trainTrack.raw.loader.ensureJunctionsApart")
				filter.minimum (l.trace, "trainTrack.raw.loader.trackSpeed")
				filter.minimum (l.dump, "trainTrack.migrations")
				filter.minimum (l.verbose, "trainTrack.editing")
				filter.minimum (l.dump, "trainTrack.query")
				filter.minimum (l.debug, "trainTrack.query.findClosestSegment")
				filter.minimum (l.dump, "trainTrack.nodeKDTree")
				filter.minimum (l.dump, "trainTrack.vehicle_objects")
				filter.minimum (l.info, "trainTrack.eventProcessing")
				filter.minimum (l.verbose, "routing")
				filter.minimum (l.dump, "commands.commands")
				filter.minimum (l.dump, "commands.commands.eval")
				filter.minimum (l.dump, "commands.commands.debug")
				filter.minimum (l.dump, "commands.commands.dump")
				filter.minimum (l.debug, "rust.api")
				filter.minimum (l.debug, "rust.api.onTick")
				filter.minimum (l.debug, "rust.api.uploadConfigRust")
				filter.minimum (l.debug, "rust.tracking")
				filter.minimum (l.dump, "commands.init.onCommand")
				filter.minimum (l.dump, "LoDObjectTracking")
				filter.minimum (l.dump, "auto_admin")
				filter.minimum (l.verbo, "vehicleDisappearMitigation")
				filter.minimum (l.dump, "rustConnector.TEST_LOGGING")
				filter.minimum (l.dump, "commands.vehicleDespawnInvestigation")
				filter.minimum (l.dump, "commands.catenary")
			end
			return applyDefaultFilters
		end,
		["lib.logging.levels"] = function ()
			local meta_thisFileRequirePath = "lib.logging.levels"
			local lib = { }
			lib.logLevelNameLength = 5
			lib.level2name = {
				"Dump",
				"Trace",
				"Debug",
				"Verbo",
				"Info",
				"Impo",
				"Warn",
				"Error",
				"Crit"
			}
			lib.name2level = {
				dump = 1,
				trace = 2,
				debug = 3,
				verbo = 4,
				verbose = 4,
				info = 5,
				information = 5,
				impo = 6,
				important = 6,
				warn = 7,
				warning = 7,
				error = 8,
				crit = 9,
				critical = 9
			}
			return lib
		end,
		["lib.logging.logFilter"] = function ()
			local meta_thisFileRequirePath = "lib.logging.logFilter"
			local checkArg = require "lib.checkArg"
			local moreTable = require "lib.moreTable"
			local levelSpec = require "lib.logging.levels"
			local logLevelNameLength = levelSpec.logLevelNameLength
			local name2level = levelSpec.name2level
			local level2name = levelSpec.level2name
			local lib = { }
			local neverLogLevel = 999
			local function bestMatch (input, data)
				local orig_input = input
				local input = input:gsub ("<[^>]*>", "<*>")
				local initial = data[input]
				if initial then
					return initial
				end
				local parts = { }
				for part in input:gmatch "[^.]+" do
					table.insert (parts, part)
				end
				for i = # parts, 1,  - 1 do
					local tryKey = table.concat (parts, ".", 1, i)
					local tryValue = data[tryKey]
					if tryValue then
						if input == orig_input then
							data[tryKey] = tryValue
						end
						return tryValue
					end
				end
				local input_np = input:gsub (".*!", "")
				if input_np == input then
					return nil
				end
				return bestMatch (input_np, data)
			end
			function lib.createFilter ()
				local filter = { spec = { } }
				function filter.shouldLog (level, source)
					checkArg (1, "level", level, "number")
					checkArg (2, "source", source, "string")
					local minLevel = bestMatch (source, filter.spec) or filter.spec["*"]
					if not minLevel then
						return true
					end
					return minLevel <= level
				end
				function filter.always (source)
					checkArg (1, "source", source, "string")
					filter.spec[source] = nil
				end
				function filter.never (source)
					checkArg (1, "source", source, "string")
					filter.spec[source] = neverLogLevel
				end
				function filter.minimum (level, source)
					checkArg (1, "level", level, "number")
					checkArg (2, "source", source, "string")
					local levelStr = level2name[level]
					if not levelStr then
						error ("Invalid argument #1 'level': expected a logLevel integer but '" .. (level .. "' is not a known logLevel."), 2)
					end
					filter.spec[source] = level
				end
				function filter.clear ()
					moreTable.clearTable (filter.spec)
				end
				return filter
			end
			return lib
		end,
		["lib.logging.logger"] = function ()
			local meta_thisFileRequirePath = "lib.logging.logger"
			local my_logger
			local checkArg = require "lib.checkArg"
			local logApi = require "lib.logging.api"
			local levelSpec = require "lib.logging.levels"
			local lib = { }
			lib.loggers = { }
			local function createLogger (name)
				checkArg (1, "name", name, "string")
				local logger = {
					name = name,
					creationStackTrace = ((debug and debug) and debug.traceback) and debug.traceback ()
				}
				for level, i in pairs (levelSpec.name2level) do
					if level ~= "never" then
						local function fn (format, ...)
							logApi.LogLevelSourceFormat (i, logger.name, format, ...)
						end
						logger[level] = fn
					end
				end
				function logger.log (level, format, ...)
					logApi.LogLevelSourceFormat (level, logger.name, format, ...)
				end
				function logger.getSubLogger (name)
					return lib.getOrCreateLogger (string.format ("%s.%s", logger.name, name))
				end
				function logger.getMethodLogger (method_name, instance_identifier)
					if type (instance_identifier) == "number" and math.floor (instance_identifier) == instance_identifier then
						instance_identifier = string.format ("%i", instance_identifier)
					end
					return lib.getOrCreateLogger (string.format ("%s<%s>:%s", logger.name, instance_identifier, method_name))
				end
				function logger.getTransientSubLogger (name, transient_id)
					if type (transient_id) == "number" and math.floor (transient_id) == transient_id then
						transient_id = string.format ("%i", transient_id)
					end
					name = (name and string.format ("%s.%s", logger.name, name)) or logger.name
					return lib.createTransient (name, tostring (transient_id))
				end
				if my_logger then
					my_logger.trace ("Created logger '%s'", name)
				end
				return logger
			end
			function lib.createTransient (name, transient_id)
				name = string.format ("%s<%s>", name, tostring (transient_id))
				local logger = lib.getOrCreateLogger (name)
				logger.transient = true
				return logger
			end
			function lib.createLogger (name)
				checkArg (1, "name", name, "string")
				if lib.loggers[name] then
					error (string.format ("Logger with name '%s' exists already. Existing logger created at: %s", name, lib.loggers[name].creationStackTrace or "unknown"))
				end
				local logger = createLogger (name)
				logger.transient = false
				lib.loggers[name] = logger
				return logger
			end
			function lib.getOrCreateLogger (name)
				checkArg (1, "name", name, "string")
				return lib.loggers[name] or lib.createLogger (name)
			end
			my_logger = lib.createLogger (meta_thisFileRequirePath)
			return lib
		end,
		["lib.moreString"] = function ()
			local lib = { }
			function lib.millisecondsToHumanTime (milliseconds)
				local seconds = math.floor (milliseconds / 1000)
				local minutes = math.floor (seconds / 60)
				local hours = math.floor (minutes / 60)
				local milliseconds_remaining = milliseconds % 1000
				local seconds_remaining = seconds % 60
				local minutes_remaining = minutes % 60
				local formatted_time = string.format ("%02d:%02d:%02d.%03d", hours, minutes_remaining, seconds_remaining, milliseconds_remaining)
				return formatted_time
			end
			function lib.toArgumentsList (names, values)
				local r = ""
				for i = 1, math.max (# names, # values) do
					local name = names[i]
					name = (name and name .. "=") or "[" .. (i .. "]=")
					local value = values[i]
					if type (value) == "string" then
						value = "'" .. (value .. "'")
					else
						value = tostring (value)
					end
					r = r .. (((r == "" and "") or ", ") .. (name .. value))
				end
				return r
			end
			function lib.splitOnSpacesPreserveQuoted (str)
				local args = { }
				local in_quote = false
				local current_arg = ""
				for i = 1, # str do
					local c = str:sub (i, i)
					if not in_quote and (c == "\"" or c == "'") then
						in_quote = c
					elseif (c == "\"" or c == "'") then
						in_quote = false
					elseif c == " " and not in_quote then
						if current_arg ~= "" then
							table.insert (args, current_arg)
							current_arg = ""
						end
					else
						current_arg = current_arg .. c
					end
				end
				if current_arg ~= "" then
					table.insert (args, current_arg)
				end
				return args
			end
			function lib.splitStringOnce (value, separator)
				local pos = value:find (separator, 1, true)
				if pos or 1 < 0 then
					return value:sub (1, pos - 1), value:sub (pos + separator:len ())
				else
					return value
				end
			end
			function lib.splitString (value, separator)
				local parts = { }
				while value and 0 < value:len () do
					local part, tail = lib.splitStringOnce (value, separator)
					table.insert (parts, part)
					value = tail
				end
				return parts
			end
			function lib.joinStringArray (stringArray, separator)
				local out, first = "", true
				for _, str in ipairs (stringArray) do
					if first then
						first = false
					else
						out = out .. separator
					end
					out = out .. str
				end
				return out
			end
			function lib.toStringWithStringQuotes (value, quote)
				quote = quote or "'"
				if type (value) == "string" then
					return string.format ("%s%s%s", quote, value, quote)
				end
				return tostring (value)
			end
			function lib.escape_pattern (pattern)
				return (pattern:gsub ("([^%w])", "%%%1"))
			end
			return lib
		end,
		["lib.moreTable"] = function ()
			local checkArg = require "lib.checkArg"
			local lib = { }
			function lib.tableCount (t)
				local c = 0
				for _ in pairs (t) do
					c = c + 1
				end
				return c
			end
			function lib.tableAny (t)
				return (next (t) and true) or false
			end
			function lib.tableCountIsMoreThan (t, n)
				local c = 0
				for _ in pairs (t) do
					c = c + 1
					if n < c then
						return true
					end
				end
				return false
			end
			function lib.tableCountIsExactly (t, n)
				local c = 0
				for _ in pairs (t) do
					c = c + 1
					if n < c then
						return false
					end
				end
				return c == n
			end
			function lib.arrayFind (array, value)
				checkArg (1, "array", array, "table")
				for i, v in ipairs (array) do
					if v == value then
						return i
					end
				end
				return nil
			end
			function lib.mergeTableShallow (target, extra)
				for k, v in pairs (extra) do
					target[k] = v
				end
				return target
			end
			function lib.copyTableShallow (data)
				return lib.mergeTableShallow ({ }, data)
			end
			function lib.mergeSaveDataTable (saveData, localData)
				return lib.mergeTableShallow (localData, saveData or { })
			end
			function lib.clearTable (t)
				for k, _ in pairs (t) do
					t[k] = nil
				end
			end
			function lib.listToMap (t)
				for i, v in ipairs (t) do
					t[v] = v
					t[i] = nil
				end
				return t
			end
			function lib.keysToArray (t, r, iteratorFactory)
				r = r or { }
				iteratorFactory = iteratorFactory or pairs
				for k, _ in iteratorFactory (t) do
					table.insert (r, k)
				end
				return r
			end
			function lib.listToSet (list, result)
				result = result or { }
				for _, value in ipairs (list) do
					result[value] = true
				end
				return result
			end
			function lib.setToList (set, result)
				result = result or { }
				for k in pairs (set) do
					table.insert (result, k)
				end
				return result
			end
			function lib.dereferenceK1K2_K1V (keys, keyValueMap, result)
				checkArg (1, "keys", keys, "table")
				checkArg (2, "keyValueMap", keyValueMap, "table")
				result = result or { }
				checkArg (3, "result", result, "table")
				for i, key in pairs (keys) do
					result[i] = keyValueMap[key]
				end
				return result
			end
			function lib.dereferenceArray_Array (keys, keyValueMap, result)
				return lib.dereferenceK1K2_K1V (keys, keyValueMap, result)
			end
			function lib.dereferenceArray_KV (keys, keyValueMap, result)
				checkArg (1, "keys", keys, "table")
				checkArg (2, "keyValueMap", keyValueMap, "table")
				result = result or { }
				checkArg (3, "result", result, "table")
				for _, key in pairs (keys) do
					result[key] = keyValueMap[key]
				end
				return result
			end
			function lib.dereferenceSet_Set (keys, keyValueMap, result)
				checkArg (1, "keys", keys, "table")
				checkArg (2, "keyValueMap", keyValueMap, "table")
				result = result or { }
				checkArg (3, "result", result, "table")
				for key in pairs (keys) do
					local v = keyValueMap[key]
					if v then
						result[v] = true
					end
				end
				return result
			end
			function lib.dereferenceSet_KV (keys, keyValueMap, result)
				checkArg (1, "keys", keys, "table")
				checkArg (2, "keyValueMap", keyValueMap, "table")
				result = result or { }
				checkArg (3, "result", result, "table")
				for key in pairs (keys) do
					result[key] = keyValueMap[key]
				end
				return result
			end
			function lib.invertTableRelation (input, result)
				result = result or { }
				for k, v in pairs (input) do
					result[v] = k
				end
				return result
			end
			function lib.mapToList (input, result)
				result = result or { }
				for _, v in pairs (input) do
					table.insert (result, v)
				end
				return result
			end
			function lib.pairsConsuming (data)
				local function iterator (t, k)
					local k, v = next (t, k)
					if not v then
						return nil, nil
					end
					t[k] = nil
					return k, v
				end
				local initial_key = nil
				return iterator, data, initial_key
			end
			function lib.pairsFilterPredicate (data, predicate)
				local function filtering_iterator (collection, key)
					while true do
						local k, v = next (collection, key)
						if not v then
							return nil, nil
						end
						if predicate (v) then
							return k, v
						end
						key = k
					end
				end
				local initial_key = nil
				return filtering_iterator, data, initial_key
			end
			function lib.pairsFilterSimple (filterValue, collection, filterKey)
				filterKey = filterKey or "label"
				local function predicate (v)
					return v[filterKey] == filterValue
				end
				return lib.pairsFilterPredicate (collection, predicate)
			end
			function lib.next_forever (collection, initial_key)
				local key, value = next (collection, initial_key)
				if key then
					return key, value
				end
				key, value = next (collection, nil)
				if key then
					return key, value
				end
				return nil
			end
			function lib.pairsLooping (collection, initial_key)
				return lib.next_forever, collection, initial_key
			end
			function lib.singleFlattenedIterator (table_of_tables)
				local i = 0
				local j = next (table_of_tables)
				local k = nil
				local function f ()
					local container = table_of_tables[j]
					if not container then
						return nil
					end
					local value
					k, value = next (container, k)
					if not value then
						j = next (table_of_tables, j)
						k = nil
						return f ()
					end
					i = i + 1
					return value, i, j, k
				end
				return f
			end
			function lib.slices (data, part_size)
				local result = { }
				local current
				local counter = 0
				for k, v in pairs (data) do
					current = current or { }
					current[k] = v
					counter = counter + 1
					if part_size <= counter then
						table.insert (result, current)
						current = nil
						counter = 0
					end
				end
				return result
			end
			function lib.removeElements (array, startIndex, count)
				checkArg (1, "array", array, "table")
				checkArg (2, "startIndex", startIndex, "number")
				checkArg (3, "count", count, "number")
				if startIndex < 1 then
					error ("startIndex should be > 0", 2)
				end
				if count < 0 then
					error ("count should be > 0", 2)
				end
				local length = # array
				if length < startIndex then
					return 
				end
				local afterRemovalRegionIndex = startIndex + count
				local shift = count
				for i = afterRemovalRegionIndex, # array do
					array[i - shift] = array[i]
				end
				for i = # array, (# array - shift) + 1,  - 1 do
					array[i] = nil
				end
			end
			function lib.removeValue (data, value)
				for k, v in pairs (data) do
					if v == value then
						if tonumber (k) == k then
							table.remove (data, k)
						else
							data[k] = nil
						end
					end
				end
			end
			return lib
		end,
		["lib.require_error_handler"] = function ()
			local meta_thisFileRequirePath = "lib.require_error_handler"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local originalRequire = require
			local require_stack = { }
			function require (name)
				if _require_gsub_pattern and _require_gsub_replace then
					name = name:gsub (_require_gsub_pattern, _require_gsub_replace)
				end
				logger.dump ("require('%s') start.", name)
				table.insert (require_stack, name)
				local stack_dump = table.concat (require_stack, " -> ")
				logger.trace ("require: %s", stack_dump)
				local result
				if (xpcall and debug) and debug.traceback then
					local function handler (e)
						local s = debug.traceback (e, 2)
						logger.critical ("Uncaught Error while loading '%s':\n%s\n %s", name, stack_dump, s)
					end
					local success
					success, result = xpcall (originalRequire, handler, name)
					if not success then
						error (result)
					end
				else
					result = originalRequire (name)
				end
				table.remove (require_stack)
				logger.dump ("require('%s') done.", name)
				return result
			end
		end,
		["lib.serialization.base64"] = function ()
			require "lib.environments.stormworks"
			local base64 = { }
			_G.bit = false
			_G.bit32 = false
			if not extract then
				if _G.bit then
					local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
					function extract (v, from, width)
						return band (shr (v, from), shl (1, width) - 1)
					end
				elseif true then
					function extract (v, from, width)
						local w = 0
						local flag = 2 ^ from
						for i = 0, width - 1 do
							local flag2 = flag + flag
							if flag <= v % flag2 then
								w = w + 2 ^ i
							end
							flag = flag2
						end
						return w
					end
				else
					extract = load "return function( v, from, width )\13\n\9\9\9return ( v >> from ) & ((1 << width) - 1)\13\n\9\9end" ()
				end
			end
			function base64.makeencoder (s62, s63, spad)
				local encoder = { }
				for b64code, char in pairs {
					[0] = "A",
					"B",
					"C",
					"D",
					"E",
					"F",
					"G",
					"H",
					"I",
					"J",
					"K",
					"L",
					"M",
					"N",
					"O",
					"P",
					"Q",
					"R",
					"S",
					"T",
					"U",
					"V",
					"W",
					"X",
					"Y",
					"Z",
					"a",
					"b",
					"c",
					"d",
					"e",
					"f",
					"g",
					"h",
					"i",
					"j",
					"k",
					"l",
					"m",
					"n",
					"o",
					"p",
					"q",
					"r",
					"s",
					"t",
					"u",
					"v",
					"w",
					"x",
					"y",
					"z",
					"0",
					"1",
					"2",
					"3",
					"4",
					"5",
					"6",
					"7",
					"8",
					"9",
					s62 or "+",
					s63 or "/",
					spad or "="
				} do
					encoder[b64code] = char:byte ()
				end
				return encoder
			end
			function base64.makedecoder (s62, s63, spad)
				local decoder = { }
				for b64code, charcode in pairs (base64.makeencoder (s62, s63, spad)) do
					decoder[charcode] = b64code
				end
				return decoder
			end
			local DEFAULT_ENCODER = base64.makeencoder ("-", "_")
			local DEFAULT_DECODER = base64.makedecoder ("-", "_")
			local char, concat = string.char, table.concat
			function base64.encode (str, encoder, usecaching)
				encoder = encoder or DEFAULT_ENCODER
				local t, k, n = { }, 1, # str
				local lastn = n % 3
				local cache = { }
				for i = 1, n - lastn, 3 do
					local a, b, c = str:byte (i, i + 2)
					local v = (a * 65536 + b * 256) + c
					local s
					if usecaching then
						s = cache[v]
						if not s then
							s = char (encoder[extract (v, 18, 6)], encoder[extract (v, 12, 6)], encoder[extract (v, 6, 6)], encoder[extract (v, 0, 6)])
							cache[v] = s
						end
					else
						s = char (encoder[extract (v, 18, 6)], encoder[extract (v, 12, 6)], encoder[extract (v, 6, 6)], encoder[extract (v, 0, 6)])
					end
					t[k] = s
					k = k + 1
				end
				if lastn == 2 then
					local a, b = str:byte (n - 1, n)
					local v = a * 65536 + b * 256
					t[k] = char (encoder[extract (v, 18, 6)], encoder[extract (v, 12, 6)], encoder[extract (v, 6, 6)], encoder[64])
				elseif lastn == 1 then
					local v = str:byte (n) * 65536
					t[k] = char (encoder[extract (v, 18, 6)], encoder[extract (v, 12, 6)], encoder[64], encoder[64])
				end
				return concat (t)
			end
			function base64.decode (b64, decoder, usecaching)
				decoder = decoder or DEFAULT_DECODER
				local pattern = "[^%w%+%/%=]"
				if decoder then
					local s62, s63
					for charcode, b64code in pairs (decoder) do
						if b64code == 62 then
							s62 = charcode
						elseif b64code == 63 then
							s63 = charcode
						end
					end
					pattern = ("[^%%w%%%s%%%s%%=]"):format (char (s62), char (s63))
				end
				b64 = b64:gsub (pattern, "")
				local cache = usecaching and { }
				local t, k = { }, 1
				local n = # b64
				local padding = ((b64:sub ( - 2) == "==" and 2) or (b64:sub ( - 1) == "=" and 1)) or 0
				for i = 1, (0 < padding and n - 4) or n, 4 do
					local a, b, c, d = b64:byte (i, i + 3)
					local s
					if usecaching then
						local v0 = ((a * 16777216 + b * 65536) + c * 256) + d
						s = cache[v0]
						if not s then
							local v = ((decoder[a] * 262144 + decoder[b] * 4096) + decoder[c] * 64) + decoder[d]
							s = char (extract (v, 16, 8), extract (v, 8, 8), extract (v, 0, 8))
							cache[v0] = s
						end
					else
						local v = ((decoder[a] * 262144 + decoder[b] * 4096) + decoder[c] * 64) + decoder[d]
						s = char (extract (v, 16, 8), extract (v, 8, 8), extract (v, 0, 8))
					end
					t[k] = s
					k = k + 1
				end
				if padding == 1 then
					local a, b, c = b64:byte (n - 3, n - 1)
					local v = (decoder[a] * 262144 + decoder[b] * 4096) + decoder[c] * 64
					t[k] = char (extract (v, 16, 8), extract (v, 8, 8))
				elseif padding == 2 then
					local a, b = b64:byte (n - 3, n - 2)
					local v = decoder[a] * 262144 + decoder[b] * 4096
					t[k] = char (extract (v, 16, 8))
				end
				return concat (t)
			end
			return base64
		end,
		["lib.serialization.serpent"] = function ()
			require "lib.environments.stormworks"
			local serpent
			local n, v = "serpent", "0.303"
			local c, d = "Paul Kulchenko", "Lua serializer and pretty printer"
			local snum = {
				[tostring (1 / 0)] = "1/0 --[[math.huge]]",
				[tostring ( - 1 / 0)] = "-1/0 --[[-math.huge]]",
				[tostring (0 / 0)] = "0/0"
			}
			local badtype = {
				thread = true,
				userdata = true,
				cdata = true
			}
			local getmetatable = (debug and debug.getmetatable) or getmetatable
			local pairs = function (t)
				return next, t
			end
			local keyword, globals, G = { }, { }, (_G or _ENV)
			for _, k in ipairs {
				"and",
				"break",
				"do",
				"else",
				"elseif",
				"end",
				"false",
				"for",
				"function",
				"goto",
				"if",
				"in",
				"local",
				"nil",
				"not",
				"or",
				"repeat",
				"return",
				"then",
				"true",
				"until",
				"while"
			} do
				keyword[k] = true
			end
			for k, v in pairs (G) do
				globals[v] = k
			end
			for _, g in ipairs {
				"coroutine",
				"debug",
				"io",
				"math",
				"string",
				"table",
				"os"
			} do
				for k, v in pairs ((type (G[g]) == "table" and G[g]) or { }) do
					globals[v] = g .. ("." .. k)
				end
			end
			local function s (t, opts)
				local name, indent, fatal, maxnum = opts.name, opts.indent, opts.fatal, opts.maxnum
				local sparse, custom, huge, nohuge = opts.sparse, opts.custom, not opts.nohuge, opts.nohuge
				local space, maxl = ((opts.compact and "") or " "), (opts.maxlevel or math.huge)
				local maxlen, metatostring = tonumber (opts.maxlen), opts.metatostring
				local iname, comm = "_" .. (name or ""), opts.comment and (tonumber (opts.comment) or math.huge)
				local numformat = opts.numformat or "%.17g"
				local seen, sref, syms, symn = { }, { "local " .. (iname .. "={}") }, { }, 0
				local function gensym (val)
					return "_" .. (tostring (tostring (val)):gsub ("[^%w]", ""):gsub ("(%d%w+)", function (s)
						if not syms[s] then
							symn = symn + 1
							syms[s] = symn
						end
						return tostring (syms[s])
					end))
				end
				local function safestr (s)
					return ((type (s) == "number" and ((huge and snum[tostring (s)]) or numformat:format (s))) or (type (s) ~= "string" and tostring (s))) or ("%q"):format (s):gsub ("\n", "n"):gsub ("\26", "\\026")
				end
				if opts.fixradix and (".1f"):format (1.2) ~= "1.2" then
					local origsafestr = safestr
					function safestr (s)
						return (type (s) == "number" and ((nohuge and snum[tostring (s)]) or numformat:format (s):gsub (",", "."))) or origsafestr (s)
					end
				end
				local function comment (s, l)
					return ((comm and (l or 0) < comm) and " --[[" .. (select (2, pcall (tostring, s)) .. "]]")) or ""
				end
				local function globerr (s, l)
					return ((globals[s] and globals[s] .. comment (s, l)) or (not fatal and safestr (select (2, pcall (tostring, s))))) or error ("Can't serialize " .. tostring (s))
				end
				local function safename (path, name)
					local n = (name == nil and "") or name
					local plain = (type (n) == "string" and n:match "^[%l%u_][%w_]*$") and not keyword[n]
					local safe = (plain and n) or "[" .. (safestr (n) .. "]")
					return (path or "") .. ((((plain and path) and ".") or "") .. safe), safe
				end
				local alphanumsort = (type (opts.sortkeys) == "function" and opts.sortkeys) or function (k, o, n)
					local maxn, to = tonumber (n) or 12, {
						number = "a",
						string = "b"
					}
					local function padnum (d)
						return ("%0" .. (tostring (maxn) .. "d")):format (tonumber (d))
					end
					table.sort (k, function (a, b)
						return (((k[a] ~= nil and 0) or to[type (a)]) or "z") .. (tostring (a):gsub ("%d+", padnum)) < (((k[b] ~= nil and 0) or to[type (b)]) or "z") .. (tostring (b):gsub ("%d+", padnum))
					end)
				end
				local function val2str (t, name, indent, insref, path, plainindex, level)
					local ttype, level, mt = type (t), (level or 0), getmetatable (t)
					local spath, sname = safename (path, name)
					local tag = (plainindex and (((type (name) == "number") and "") or name .. (space .. ("=" .. space)))) or ((name ~= nil and sname .. (space .. ("=" .. space))) or "")
					if seen[t] then
						sref[# sref + 1] = spath .. (space .. ("=" .. (space .. seen[t])))
						return tag .. ("nil" .. comment ("ref", level))
					end
					if (type (mt) == "table" and metatostring ~= false) and (mt.__tostring or mt.__serialize) then
						local to, tr, so, sr
						if mt.__tostring then
							to, tr = pcall (function ()
								return mt.__tostring (t)
							end)
						end
						if mt.__serialize then
							so, sr = pcall (function ()
								return mt.__serialize (t)
							end)
						end
						if (to or so) then
							seen[t] = insref or spath
							t = (so and sr) or tr
							ttype = type (t)
						end
					end
					if ttype == "table" then
						if maxl <= level then
							return tag .. ("{}" .. comment ("maxlvl", level))
						end
						seen[t] = insref or spath
						if next (t) == nil then
							return tag .. ("{}" .. comment (t, level))
						end
						if maxlen and maxlen < 0 then
							return tag .. ("{}" .. comment ("maxlen", level))
						end
						local maxn, o, out = math.min (# t, maxnum or # t), { }, { }
						for key = 1, maxn do
							o[key] = key
						end
						if not maxnum or # o < maxnum then
							local n = # o
							for key in pairs (t) do
								if o[key] ~= key then
									n = n + 1
									o[n] = key
								end
							end
						end
						if maxnum and maxnum < # o then
							o[maxnum + 1] = nil
						end
						if opts.sortkeys and maxn < # o then
							alphanumsort (o, t, opts.sortkeys)
						end
						local sparse = sparse and maxn < # o
						for n, key in ipairs (o) do
							local value, ktype, plainindex = t[key], type (key), n <= maxn and not sparse
							if ((((opts.valignore and opts.valignore[value]) or (opts.keyallow and not opts.keyallow[key])) or (opts.keyignore and opts.keyignore[key])) or (opts.valtypeignore and opts.valtypeignore[type (value)])) or (sparse and value == nil) then
								
							elseif (ktype == "table" or ktype == "function") or badtype[ktype] then
								if not seen[key] and not globals[key] then
									sref[# sref + 1] = "placeholder"
									local sname = safename (iname, gensym (key))
									sref[# sref] = val2str (key, sname, indent, sname, iname, true)
								end
								sref[# sref + 1] = "placeholder"
								local path = seen[t] .. ("[" .. (tostring ((seen[key] or globals[key]) or gensym (key)) .. "]"))
								sref[# sref] = path .. (space .. ("=" .. (space .. tostring (seen[value] or val2str (value, nil, indent, path)))))
							else
								out[# out + 1] = val2str (value, key, indent, nil, seen[t], plainindex, level + 1)
								if maxlen then
									maxlen = maxlen - # out[# out]
									if maxlen < 0 then
										break
									end
								end
							end
						end
						local prefix = string.rep (indent or "", level)
						local head = (indent and "{\n" .. (prefix .. indent)) or "{"
						local body = table.concat (out, "," .. ((indent and "\n" .. (prefix .. indent)) or space))
						local tail = (indent and "\n" .. (prefix .. "}")) or "}"
						return ((custom and custom (tag, head, body, tail, level)) or tag .. (head .. (body .. tail))) .. comment (t, level)
					elseif badtype[ttype] then
						seen[t] = insref or spath
						return tag .. globerr (t, level)
					elseif ttype == "function" then
						seen[t] = insref or spath
						if opts.nocode or opts.nocodeplaceholder then
							if opts.nocodeplaceholder then
								return tag .. ("nil --[[function omitted]]" .. comment (t, level))
							else
								return tag .. ("function() --[[..skipped..]] end" .. comment (t, level))
							end
						end
						local ok, res = pcall (string.dump, t)
						local func = ok and "((loadstring or load)(" .. (safestr (res) .. (",'@serialized'))" .. comment (t, level)))
						return tag .. (func or globerr (t, level))
					else
						return tag .. safestr (t)
					end
				end
				local sepr = (indent and "\n") or ";" .. space
				local body = val2str (t, name, indent)
				local tail = (1 < # sref and table.concat (sref, sepr) .. sepr) or ""
				local warn = ((opts.comment and 1 < # sref) and space .. "--[[incomplete output with shared/self-references skipped]]") or ""
				return (not name and body .. warn) or "do local " .. (body .. (sepr .. (tail .. ("return " .. (name .. (sepr .. "end"))))))
			end
			local function deserialize (data, opts)
				local env = ((opts and opts.safe == false) and G) or setmetatable ({ }, {
					__index = function (t, k)
						return t
					end,
					__call = function (t, ...)
						error "cannot call functions"
					end
				})
				local f, res = load ("return " .. data, nil, nil, env)
				if not f then
					f, res = load (data, nil, nil, env)
				end
				if not f then
					return f, res
				end
				return pcall (f)
			end
			local function merge (a, b)
				if b then
					for k, v in pairs (b) do
						a[k] = v
					end
				end
				return a
			end
			serpent = {
				_NAME = n,
				_COPYRIGHT = c,
				_DESCRIPTION = d,
				_VERSION = v,
				serialize = s,
				load = deserialize,
				dump = function (a, opts)
					return s (a, merge ({
						name = "_",
						compact = true,
						sparse = true,
						nocode = true
					}, opts))
				end,
				line = function (a, opts)
					return s (a, merge ({
						sortkeys = true,
						comment = true,
						nocode = true
					}, opts))
				end,
				block = function (a, opts)
					return s (a, merge ({
						indent = "\9",
						sortkeys = true,
						comment = true,
						nocode = true
					}, opts))
				end
			}
			return serpent
		end,
		["lib.timer"] = function ()
			local m = { }
			local proto = { }
			local millis_to_seconds = 1 / 1000
			function proto:start ()
				if self._start_time then
					return 
				end
				self._start_time = server.getTimeMillisec ()
			end
			function proto:restart ()
				self._duration = 0
				self._start_time = server.getTimeMillisec ()
			end
			function proto:stop ()
				if not self._start_time then
					return 
				end
				self._duration = self:elapsed ()
			end
			function proto:elapsed ()
				if not self._start_time then
					return self._duration * millis_to_seconds
				end
				return (self._duration + (server.getTimeMillisec () - self._start_time)) * millis_to_seconds
			end
			function m.New (start_running)
				local t = { _duration = 0 }
				for k, v in pairs (proto) do
					t[k] = v
				end
				if start_running then
					t:start ()
				end
				return t
			end
			return m
		end,
		["lib.vector3"] = function ()
			local checkArg = require "lib.checkArg"
			local vec = { }
			function vec.New (x, y, z)
				return {
					x = x,
					y = y,
					z = z
				}
			end
			function vec.Copy (v)
				return vec.New (v.x, v.y, v.z)
			end
			function vec.Sub (v, w, z)
				z = z or { }
				z.x = v.x - w.x
				z.y = v.y - w.y
				z.z = v.z - w.z
				return z
			end
			function vec.Add (v, w, z)
				local z = z or { }
				z.x = v.x + w.x
				z.y = v.y + w.y
				z.z = v.z + w.z
				return z
			end
			function vec.Mul (v, w, z)
				z = z or { }
				if tonumber (w) then
					z.x = v.x * w
					z.y = v.y * w
					z.z = v.z * w
				else
					z.x = v.x * w.x
					z.y = v.y * w.y
					z.z = v.z * w.z
				end
				return z
			end
			function vec.Div (v, w, z)
				z = z or { }
				if tonumber (w) then
					z.x = v.x / w
					z.y = v.y / w
					z.z = v.z / w
				else
					z.x = v.x / w.x
					z.y = v.y / w.y
					z.z = v.z / w.z
				end
				return z
			end
			local inverse_vec = vec.New ( - 1,  - 1,  - 1)
			function vec.Inverse (v, z)
				return vec.Mul (v, inverse_vec, z)
			end
			function vec.Len2 (v)
				return (v.x * v.x + v.y * v.y) + v.z * v.z
			end
			function vec.Len (v)
				return math.sqrt (vec.Len2 (v))
			end
			vec.Length = vec.Len
			function vec.Norm (v, r)
				return vec.Mul (v, 1 / vec.Len (v), r)
			end
			function vec.Dot (v, w)
				return (v.x * w.x + v.y * w.y) + v.z * w.z
			end
			function vec.Cross (v, w, z)
				z = z or { }
				z.x = (v.y * w.z) - (v.z * w.y)
				z.y = (v.z * w.x) - (v.x * w.z)
				z.z = (v.x * w.y) - (v.y * w.x)
				return z
			end
			function vec.Angle (v, w)
				local dot = vec.Dot (v, w)
				local lenProduct = vec.Length (v) * vec.Length (w)
				local cosAngle = dot / lenProduct
				local angle = math.acos (cosAngle)
				return angle
			end
			function vec.Min (v, w, z)
				z = z or { }
				z.x = math.min (v.x, w.x)
				z.y = math.min (v.y, w.y)
				z.z = math.min (v.z, w.z)
				return z
			end
			function vec.Max (v, w, z)
				z = z or { }
				z.x = math.max (v.x, w.x)
				z.y = math.max (v.y, w.y)
				z.z = math.max (v.z, w.z)
				return z
			end
			function vec.Equals (v, w)
				return v == w or ((v.x == w.x and v.y == w.y) and v.z == w.z)
			end
			function vec.ApproxEquals (v, w, margin)
				return v == w or ((math.abs (v.x - w.x) < margin and math.abs (v.y - w.y) < margin) and math.abs (v.z - w.z) < margin)
			end
			function vec.Position_From_ArrayMatrix (t)
				checkArg (1, "t", t, "table")
				checkArg (1, "t[13]", t[13], "number")
				checkArg (1, "t[14]", t[14], "number")
				checkArg (1, "t[15]", t[15], "number")
				return {
					x = t[13],
					y = t[14],
					z = t[15]
				}
			end
			function vec.Forward_From_ArrayMatrix (t)
				checkArg (1, "t", t, "table")
				checkArg (1, "t[9]", t[9], "number")
				checkArg (1, "t[10]", t[10], "number")
				checkArg (1, "t[11]", t[11], "number")
				return {
					x = t[9],
					y = t[10],
					z = t[11]
				}
			end
			function vec.Multiply_ArrayMatrix (t, v, w, r)
				local x, y, z, w = matrix.multiplyXYZW (t, v.x, v.y, v.z, w)
				r = r or { }
				r.x = x
				r.y = y
				r.z = z
				return r, w
			end
			function vec.ToString (v, formatStr)
				checkArg (1, "v", v, "table")
				checkArg (1, "v.x", v.x, "number")
				checkArg (1, "v.y", v.y, "number")
				checkArg (1, "v.z", v.z, "number")
				if formatStr == nil then
					formatStr = "(%.2f, %.2f, %.2f)"
				elseif string.match (formatStr, "%%[0-9%.]*[df]") then
					formatStr = "(" .. (formatStr .. (", " .. (formatStr .. (", " .. (formatStr .. ")")))))
				elseif string.match (formatStr, "%%[0-9%.]*[df].*%%[0-9%.]*[df].*%%[0-9%.]*[df]") then
					
				else
					error "Invalid format string"
				end
				return string.format (formatStr, v.x, v.y, v.z)
			end
			return vec
		end,
		main = function ()
			local keyValueParser = require "lib.keyValueParser"
			local meta_thisFileRequirePath = "main"
			local zone_tag = "tile_registry"
			local pretty_print = true
			local script_name = "TileRegistry"
			local version = "1.0.0"
			local build_number = 1
			local script_version = string.format ("%s-%s", version, build_number)
			local node_http_port = 8080
			local HttpSeedDataFolder = string.format ("/file/%s/tile/", script_name)
			local function round (v)
				return math.floor (v + 0.5)
			end
			local serpent = require "lib.serialization.serpent"
			local vec = require "lib.vector3"
			local logging = require "lib.logging.api"
			logging.global_prefix = "TiRe"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local callbackRegistration = require "lib.addonCallbacks.registration"
			require "lib.addonCallbacks.processing"
			local httpLib = require "lib.http"
			local function m_onCreate (is_world_create)
				local logger = logger.getSubLogger "onCreate"
				logger.verbose ("is_world_create %s | script_version: %s", is_world_create, script_version)
			end
			callbackRegistration.registerCallback ("onCreate", meta_thisFileRequirePath, m_onCreate)
			local endpoint = httpLib.Endpoint (node_http_port, HttpSeedDataFolder)
			local function onSeedEntered (seed, user_peer_id)
				local function announce (title, format, ...)
					local message = string.format (format, ...)
					logger.important ("[%s] %s", title, message)
					server.announce (title, message, user_peer_id)
				end
				announce ("Seed Crunch Upload", "Preparing seed crunch upload for seed %i", seed)
				local data = {
					seed = seed,
					tiles = { }
				}
				local counter = 0
				local zones = server.getZones (zone_tag)
				for _, zone in pairs (zones) do
					local tile = server.getTile (zone.transform)
					local world_pos = vec.Position_From_ArrayMatrix (zone.transform)
					local tags = keyValueParser (zone.tags_full)
					local entry = {
						tile_name_zone = tags.tile_name,
						tile_file_zone = tags.tile_file,
						tile_file_runtime = tile.name,
						world_x = world_pos.x,
						world_z = world_pos.z,
						sea_floor = tile.sea_floor,
						zone_transform = zone.transform
					}
					table.insert (data.tiles, entry)
					counter = counter + 1
				end
				announce ("Seed Crunch Upload", "Data ready, found %i zones/tiles to be uploaded", counter)
				local function response_evaluator (port, url, response, response_timer)
					return true
				end
				local function completion_handler ()
					announce ("Seed Crunch Uploaded", "Uploading seed crunch data completed.")
				end
				local function failure_handler ()
					announce ("Seed Crunch Uploaded Failed", "Uploading seed crunch data failed.")
				end
				local string_data = serpent.dump (data, {
					sortkeys = true,
					indent = pretty_print and "\9"
				})
				endpoint.send (string.format ("%s.lua", seed), "replace", string_data, response_evaluator, completion_handler, failure_handler)
				server.notify (user_peer_id, "Seed Crunch Upload", "Uploading world data for seed crunch...", 5)
			end
			local function m_onCustomCommand (full_message, user_peer_id, is_admin, is_auth, namespace, command, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16)
				if not is_admin or not is_auth then
					return 
				end
				if namespace ~= "?seed_crunch" and namespace ~= "?sc" then
					return 
				end
				if not command then
					return 
				end
				local seed = tonumber (command)
				if not seed then
					return 
				end
				onSeedEntered (round (seed), user_peer_id)
			end
			callbackRegistration.registerCallback ("onCustomCommand", meta_thisFileRequirePath, m_onCustomCommand)
		end
	},
	loaded = { },
	fake = true
}

function require (name)
	if _require_gsub_pattern and _require_gsub_replace then
		name = name:gsub (_require_gsub_pattern, _require_gsub_replace)
	end
	local loaded = package.loaded[name]
	if type (loaded) ~= "nil" then
		return loaded
	end
	local preload = package.preload[name]
	if type (preload) == "function" then
		local v = preload ()
		package.loaded[name] = v
		return v
	else
		error (string.format ("package '%s' not found:\n    no entry package.loaded['%s']\n    no entry package.preload['%s']", name))
	end
end

local script_name = "TileRegistry"

local version = "0.0.0"

local build_number = 1

local script_version = string.format ("%s-build-%s", version, build_number)

local save_data_version = "0.0.0"

local node_http_port = 8080

local HttpLogFile = string.format ("/log/%s/server.log", script_name)

_require_gsub_pattern = script_name .. "."

_require_gsub_replace = ""

local meta_thisFileRequirePath = "init"

stormworks_debug = debug

local real_debug = ebug

debug = real_debug or debug

if package and not package.fake then
	local addition = string.format ("%s/missions/%s/?.lua;%s/missions/%s/?/init.lua;%s/missions/?.lua;%s/missions/?/init.lua;", workspace_root, script_name, workspace_root, script_name, workspace_root, workspace_root)
	if not string.find (package.path, addition, nil, true) then
		package.path = addition .. package.path
	end
end

if (jit and package) and not package.fake then
	_ENV = _ENV or _G
	local addition = string.format ("%s/missions/?.lua;", workspace_root)
	if not string.find (package.path, addition, nil, true) then
		package.path = addition .. package.path
	end
	if clean_package then
		package.loaded = { }
	end
end

require "lib.environments.stormworks"

local config = require "config"

config.script_name = script_name

config.script_version = script_version

config.save_data_version = save_data_version

config.logging.legacyHttp.HttpLogFile = HttpLogFile

config.logging.legacyHttp.server_port = node_http_port

if workspace_root then
	config.sandbox.workspace_root = workspace_root
	config.sandbox.server_content = workspace_root .. "\\Content"
	config.sandbox.script_root = workspace_root .. ("\\missions\\" .. script_name)
end

local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)

logger.info "Logger started."

if error_is_server_announce then
	local logger = logger.getSubLogger "error"
	local old_error = error
	function error (message)
		logger.critical ("Uncaught error in script %s (%s): %s", script_name, script_version, message)
		old_error (message)
	end
end

require "lib.require_error_handler"

require "main"

if (xpcall and debug) and debug.traceback then
	logger.info "Applying xpcall wrappers around entryPoints..."
	local function handler (e)
		local s = debug.traceback (e, 2)
		logger.critical ("Uncaught Error: %s", s)
	end
	local protect = {
		"onTick",
		"onCreate",
		"onDestroy",
		"onCustomCommand",
		"onChatMessage",
		"onPlayerJoin",
		"onPlayerSit",
		"onPlayerUnsit",
		"onCharacterSit",
		"onCharacterUnsit",
		"onPlayerRespawn",
		"onPlayerLeave",
		"onPlayerUnsit",
		"onToggleMap",
		"onPlayerDie",
		"onVehicleSpawn",
		"onVehicleDespawn",
		"onVehicleLoad",
		"onVehicleUnload",
		"onVehicleTeleport",
		"onObjectLoad",
		"onObjectUnload",
		"onButtonPress",
		"onSpawnAddonComponent",
		"onVehicleDamaged",
		"httpReply",
		"onFireExtinguished",
		"onForestFireSpawned",
		"onForestFireExtinguished"
	}
	original_global_env = original_global_env or { }
	for _, name in pairs (protect) do
		original_global_env[name] = original_global_env[name] or _ENV[name]
	end
	for _, name in pairs (protect) do
		if type (original_global_env[name]) == "function" then
			_ENV[name] = function (...)
				return xpcall (original_global_env[name], handler, ...)
			end
		end
	end
end

logger.info "Initial script loading complete."
-- End packaged script.
end

if xpcall then
	local error_data
	writer('Running in protected mode...')
	local function handler(message)
		if debug and debug.traceback then
			message = tostring(message)
			message = debug.traceback(message)
		end
		writer(message)
		error_data = message
	end
	xpcall(__main__, handler)
	if error_data then error(error_data) end
else
	writer('xpcall not available, running raw...')
	__main__()
end

writer("Loading done: 'TileRegistry/init.lua'")
