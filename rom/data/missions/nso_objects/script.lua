-- Packaged by Leopard's packager&minifier, version 0.1.1
-- Original file name: NSO_Objects/init.lua
-- Packaged at: 2024-09-05T15:45:54Z

local script_name = "NSO_Objects"

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
	dofile(workspace_root..'/missions/NSO_Objects/init.lua')
	return
elseif dofile then
	writer('dofile is available but workspace_root is not.')
end

writer('Loading from packaged script...')


-- Packaged script:
package = {
	preload = {
		["RailroadSignals.config"] = function ()
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
				debug = {
					boundsVisualizationUpdateInterval = 0,
					profiler1_live_interval_ticks = 60 * 5,
					memory_log_interval_ticks = (60 * 60) * 1
				},
				sandbox = { },
				rust = {
					enabled = true,
					tracking = {
						player = {
							interval = 60 * 1,
							retry_interval = 60 * 30,
							timeout_retry_interval = 60 * 120
						},
						vehicle = {
							interval = 60 * 1,
							retry_interval = 60 * 30,
							timeout_retry_interval = 60 * 120
						}
					},
					upload_progress_interval_ms = 1000 * 20,
					viz_max_distance = nil,
					include_metadata = { send_time_gms = false }
				},
				signalling = {
					signal_must_have_bind_filter = false,
					pathfinder_train_max_speed_default = 300
				},
				vehicle_objects = {
					just_loaded_duration_ticks = 1 * 60,
					disappear_mitigation = {
						items_per_tick = 1,
						allow_respawn = true
					}
				},
				signal_vehicle = {
					default_right_offset =  - 0.5,
					default_up_offset = 0,
					default_forward_offset = 0
				},
				train = {
					tick_interval = 60,
					trains_per_update = 1,
					stock_max_distance = 100,
					default_wagon_length = 10,
					junction_release_delay_ticks = 60 * 30,
					occupancy = {
						check_all_wagons = false,
						next_segment_search_tries = 10,
						try_global_search_threshold = 20,
						unconditional_remove_threshold_wagon = 100,
						unconditional_remove_threshold_train = 1000,
						movement_margin = 1,
						wagon_length_multiplier_from_components = 1.1,
						wagon_length_margin = 1.1,
						initial_segment_search_max_distance = 50,
						wagon_tick_interval = 60,
						wagons_per_tick = 60,
						wagon_occupancy_callback_order = 1,
						train_occupancy_callback_order = 2
					},
					lzb = { always_update_distance = false }
				},
				tracks = {
					spawn_on_load = true,
					raw = {
						enable_KDTree = true,
						segment_max_length = 250,
						both_segment_min_len = 10,
						single_segment_min_len = 5,
						line_max_offset = 1,
						line_max_result_len = 100,
						line_ratio_limit = 0.8,
						merge_node_threshold = 1,
						fix_too_long_segments = true,
						connect_within_tile = true,
						connect_across_borders = true,
						remove_unnecessary_detail = true,
						ensure_junctions_apart = true,
						sanity_check = true,
						apply_track_speed = true,
						load_named_destinations = true,
						zone_tile_once = nil
					},
					destinations = { show_on_map = true }
				},
				pathfinder = {
					async_steps_per_tick = 100,
					async_log_interval_ticks = 60 * 5
				}
			}
			return config
		end,
		commands = function ()
			require "common.objects.commands"
			local libCommandHandler = require "lib.legacyCommands.handler"
			libCommandHandler.commandNamespace = "?nso"
			require "common.mod_objects.commands.traffic"
			require "commands.dump"
			require "commands.info"
			require "common.mod_objects.commands.catenary"
			libCommandHandler.init ()
		end,
		["commands.dump"] = function ()
			local meta_thisFileRequirePath = "commands.dump"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local saveData = require "lib.saveData"
			local config = require "config"
			local moreTable = require "lib.moreTable"
			local mapToList = moreTable.mapToList
			local invertTableRelation = moreTable.invertTableRelation
			local serpent = require "lib.serialization.serpent"
			local persistence = require "persistence"
			local tsignals = persistence.TrafficLights
			local intersections = persistence.TrafficIntersections
			local httpLib = require "lib.http"
			local dump_endpoint = httpLib.Endpoint (8080, string.format ("%s/file/%s/dumps/", config.sandbox.server_content, config.script_name))
			local libCommandHandler = require "lib.legacyCommands.handler"
			local commands = libCommandHandler.commands
			local function bind (f, c)
				return function ()
					return f (c)
				end
			end
			local performance_summary_options = {
				min_average_ms = 0,
				sort_by = "nonzero_average_ms",
				sort_asc = false
			}
			local dump_aliases = {
				savedata = "g_savedata",
				env = "_env",
				logfilters = "logFilters"
			}
			local dump_whats = {
				g_savedata = function ()
					return "g_savedata", g_savedata
				end,
				intersections = function ()
					return "intersections", intersections
				end,
				tsignals = function ()
					return "tsignals", bind (tsignals.map_SUID_Object, tsignals)
				end,
				logFilters = function ()
					return "logFilters", require "lib.logging.api".mainFilter.spec
				end,
				loggers = function ()
					return "loggers", require "lib.logging.logger".loggers
				end,
				performance = function ()
					return "performance", require "lib.addonCallbacks.processing".performance_reports
				end,
				performance2 = function ()
					return "performance2", require "lib.addonCallbacks.report".make_summary (performance_summary_options)
				end,
				uid_states = function ()
					return "uid_states", function ()
						return saveData.get "uid_states"
					end
				end
			}
			for k in pairs (dump_whats) do
				if k:sub ( - 1) == "s" then
					dump_aliases[k:sub (1,  - 2)] = k
				end
			end
			local dumpable_things_help = table.concat (mapToList (invertTableRelation (dump_whats)), ", ")
			function commands.dump (context)
				if not context.is_admin then
					return 
				end
				local what = context.args[1]
				if not what then
					context.announce ("Error", "Specify what to dump: %s", dumpable_things_help)
					return 
				end
				local lwhat = string.lower (what)
				if lwhat == "all" then
					for k in pairs (dump_whats) do
						commands.dump {
							is_admin = true,
							args = { k },
							user_peer_id = context.user_peer_id
						}
					end
					return 
				end
				local fwhat = dump_whats[lwhat] or (dump_aliases[lwhat] and dump_whats[dump_aliases[lwhat]])
				if not fwhat then
					context.announce ("Error", "Unknown dumpable '%s', options are: %s", what, dumpable_things_help)
					return 
				end
				local name, data, serpent_settings = fwhat ()
				local tData = type (data)
				logger.dump ("type(data) = %s", tData)
				if tData == "function" then
					data = data ()
				end
				serpent_settings = serpent_settings or { }
				serpent_settings = moreTable.mergeTableShallow ({
					name = name,
					indent = "\9",
					comment = true,
					sortkeys = true,
					sparse = true,
					valtypeignore = { ["function"] = true }
				}, serpent_settings)
				local str = serpent.dump (data, serpent_settings)
				if io then
					local path = string.format ("%s/file/%s/dumps/%s.lua", config.sandbox.server_content, config.script_name, name)
					local file, emsg = io.open (path, "w")
					if file then
						file:write (str)
						file:close ()
						context.announce (string.format ("Dump %s Complete", name), "Dumping of %s has completed successfully, %i items dumped.", name, (data and moreTable.tableCount (data)) or  - 1)
						return 
					end
					logger.warn ("Unable to create file '%s', will fall back to http transport. %s", path, emsg)
				end
				local evaluator = httpLib.create_expect_success_handler ({ Ok = true }, string.format ("dump: '%s'", name))
				local function completion ()
					context.announce (string.format ("Dump %s Complete", name), "Dumping of %s has completed successfully.", name)
				end
				local function failure ()
					context.announce (string.format ("Dump %s Failed", name), "Dumping of %s has failed.")
				end
				dump_endpoint.send (name .. ".lua", "Replace", str, evaluator, completion, failure)
				context.notify (7, string.format ("Dump %s", name), "Starting dump...")
			end
		end,
		["commands.info"] = function ()
			local meta_thisFileRequirePath = "commands.info"
			local logger = require "lib.logging.logger".getOrCreateLogger (meta_thisFileRequirePath)
			local libCommandHandler = require "lib.legacyCommands.handler"
			local commands = libCommandHandler.commands
			local version = require "version"
			function commands.info (context)
				local message = string.format ("North Sawyer Overhaul (NSO) is installed, version %s.\13\nPlease note that NSO is still a work in progress, not all regions are done!\13\nTo see this information again use the command:\13\n?nso info\13\n\13\nFor information on other commands use:\13\n?nso commands\13\n\13\n", version)
				context.announce ("North Sawyer Overhaul", message)
			end
			function commands.commands (context)
				if not context.is_admin then
					context.announce ("NSO Commands", "You are currently not allowed to use special commands. If you do get permission the '?nso info' command will show them instead of this message.")
					return 
				end
				local message = "As an admin you have access to:\13\n?nso spawn FILTER\13\n?nso despawn FILTER\13\n?nso respawn FILTER\13\n\13\nThese commands know what objects have been spawned already so you don't need to worry about duplicates.\13\n\13\nThere are several filters:\13\nFor managing Level of Detail: 'LOD' this includes things like road markings.\13\nFor Train signals and junctions 'signalling_equipment'\13\n"
				context.announce ("NSO Commands 1", message)
				local message = "For managing Catenary:\13\n?nso catenary spawn FILTER\13\n?nso catenary despawn FILTER\13\n?nso catenary respawn FILTER\13\n?nso catenary height HEIGHT FILTER\13\nFILTER is always optional, options are: 'Cat1', 'Cat2', ... 'Cat5'.\13\nHEIGHT is the height above the top of the rail in meters.\13\nThe standard height is 5.5. Typical values found on 'standard' mainline tracks range from 4.5 to 6.\13\nNote: if you input values outside of the recommended range it may look wrong on and under bridges, and in tunnels.\13\n"
				context.announce ("NSO Commands 2", message)
				local message = "For managing TrafficLights:\13\nFor complicated technical reasons the traffic lights don't work with the standard spawn/despawn command, you must use the commands below instead:\13\n?nso traffic spawn\13\n?nso traffic despawn\13\n?nso traffic respawn"
				context.announce ("NSO Commands 3", message)
			end
		end,
		["common.mod_objects.commands.catenary"] = function ()
			local meta_thisFileRequirePath = "commands.catenary"
			local logger = require "lib.logging.logger".getOrCreateLogger (meta_thisFileRequirePath)
			local serpentf = require "lib.serialization.serpentf"
			local libCommandHandler = require "lib.legacyCommands.handler"
			local commands = libCommandHandler.commands
			local libObjects = require "common.objects.commands"
			local addon = require "lib.addon"
			local hasTag = addon.hasTag
			local identity = matrix.identity ()
			local commandHeader = "Catenary"
			local helpText = "Specify a subcommand: 'spawn', 'despawn', 'respawn', 'height'"
			local function common_argument_transform (context)
				table.remove (context.args, 1)
				table.remove (context.argsQ, 1)
				if not context.args[1] then
					table.insert (context.args, "Cat")
					table.insert (context.argsQ, "Cat")
				end
			end
			local function spawn (context)
				common_argument_transform (context)
				commands.spawn (context)
			end
			local function respawn (context)
				common_argument_transform (context)
				commands.respawn (context)
			end
			local function despawn (context)
				common_argument_transform (context)
				commands.despawn (context)
			end
			local function height (context)
				local logger = logger.getSubLogger "height"
				local height_s = context.argsQ[2]
				if not height_s then
					context.announce ("Error", "Missing argument #1 height.")
					return 
				end
				local target_height = tonumber (height_s)
				if not target_height then
					context.announce ("Error", "Could not parse a number for argument 'height' from '%s'", height_s)
					return 
				end
				local filter = context.argsQ[3]
				if not filter then
					context.announce (commandHeader, "Adjusting catenary height for all catenary to %.2fm", target_height)
				else
					context.announce (commandHeader, "Adjusting catenary height for catenary matching filter '%s' to %.2fm", filter, target_height)
				end
				local counter = 0
				local function each (data)
					if (not data.meta or not data.meta.Height) or not (not filter or hasTag (data.tags, filter)) then
						if not data.meta then
							logger.dump ("Discarding vehicle_id %4i: missing meta", data.vehicle_id)
							return 
						end
						if not data.meta.Height then
							logger.dump ("Discarding vehicle_id %4i: missing meta.Height", data.vehicle_id)
							return 
						end
						if not (not filter or hasTag (data.tags, filter)) then
							logger.dump ("Discarding vehicle_id %4i: filter '%s' does not match any tag: %s", data.vehicle_id, filter, serpentf.line (data.tags))
							return 
						end
						return 
					end
					local spawned_height = tonumber (data.meta.Height)
					if not spawned_height then
						return 
					end
					data.meta.height = spawned_height
					local spawn_transform = data.spawn_transform
					local new_transform = matrix.multiply (identity, spawn_transform)
					new_transform[14] = (new_transform[14] + target_height) - spawned_height
					local s = server.moveVehicle (data.vehicle_id, new_transform)
					if not s then
						logger.error ("Failed to move catenary object with vehicle_id: %4i", data.vehicle_id)
						return 
					end
					logger.trace ("Moved catenary object with vehicle_id %4i", data.vehicle_id)
					counter = counter + 1
				end
				for _, data in pairs (libObjects.spawned.vehicle_id__to__component) do
					logger.dump ("%3i Looking at vehicle_id %4i", _, data.vehicle_id)
					each (data)
				end
				context.announce (commandHeader, "Moved %i catenary objects to height %.2fm", counter, target_height)
			end
			function commands.catenary (context)
				if not context.is_admin then
					return 
				end
				local subCommand = context.args[1]
				if not subCommand then
					context.announce (commandHeader, helpText)
					return 
				end
				if subCommand == "spawn" then
					spawn (context)
				elseif subCommand == "despawn" then
					despawn (context)
				elseif subCommand == "respawn" then
					respawn (context)
				elseif subCommand == "height" then
					height (context)
				else
					context.announce (commandHeader, "Unknown subcommand '%s'\n%s", subCommand, helpText)
					return 
				end
				context.announce (commandHeader, "Executed command '%s'", subCommand)
			end
			logger.dump "Loaded"
		end,
		["common.mod_objects.commands.traffic"] = function ()
			local meta_thisFileRequirePath = "commands.traffic"
			local logger = require "lib.logging.logger".getOrCreateLogger (meta_thisFileRequirePath)
			local libCommandHandler = require "lib.legacyCommands.handler"
			local commands = libCommandHandler.commands
			local libTrafficLights = require "common.mod_objects.trafficLights.init"
			local helpText = "Specify a subcommand: 'spawn', 'despawn', 'respawn', 'reset'"
			function commands.traffic (context)
				if not context.is_admin then
					return 
				end
				local subCommand = context.args[1]
				if not subCommand then
					context.announce ("Traffic", helpText)
					return 
				end
				if subCommand == "spawn" then
					libTrafficLights.spawn_all ()
				elseif subCommand == "despawn" then
					libTrafficLights.despawn_all (true)
				elseif subCommand == "respawn" then
					libTrafficLights.despawn_all (true)
					libTrafficLights.spawn_all ()
				elseif subCommand == "reset" then
					libTrafficLights.reset ()
				else
					context.announce ("Traffic", "Unknown subcommand '%s'\n%s", subCommand, helpText)
					return 
				end
				context.announce ("Traffic", "Executed command '%s'", subCommand)
			end
		end,
		["common.mod_objects.trafficLights.enums"] = function ()
			local M = { }
			M.indication_ids = {
				red = 1,
				amber = 2,
				green = 3
			}
			M.indications_names = {
				[1] = "red",
				[2] = "amber",
				[3] = "green"
			}
			return M
		end,
		["common.mod_objects.trafficLights.init"] = function ()
			local meta_thisFileRequirePath = "common.mod_objects.trafficLights.init"
			local logger = require "lib.logging.logger".getOrCreateLogger (meta_thisFileRequirePath)
			require "common.mod_objects.trafficLights.intersection"
			local trafficLightPrototype = require "common.mod_objects.trafficLights.trafficLight"
			local trafficIntersectionPrototype = require "common.mod_objects.trafficLights.intersection"
			local uid = require "common.mod_objects.trafficLights.uid"
			local persistence = require "persistence"
			local vso = require "lib.vehicleObjects"
			local M = { }
			local primary_tag = "traffic_equipment"
			local spawn_categories = {
				{
					category = "traffic_intersection",
					default_variant = "never",
					proto = trafficIntersectionPrototype,
					container = persistence.TrafficLights,
					variants_by_category = { [true] = {
						meta = { },
						spawn = function (_)
							return  - 1, true
						end
					} }
				},
				{
					category = "trafficLight",
					default_variant = "standard",
					proto = trafficLightPrototype,
					container = persistence.TrafficLights
				}
			}
			vso.registerSpawnCategories (spawn_categories)
			function M.spawn_all ()
				logger.important "Spawning trafficLights..."
				local context = {
					spawn_categories = spawn_categories,
					filter_tags = { primary_tag },
					no_duplicates_behavior = "all"
				}
				vso.spawnAll (context)
			end
			function M.despawn_all (instant)
				logger.important "Despawning trafficLights..."
				vso.despawnAll (spawn_categories, instant)
				uid.TrafficLightGlobal.reset ()
				uid.TrafficIntersection.reset ()
				logger.important "Done despawning trafficLights."
			end
			function M.respawn_all ()
				M.despawn_all (true)
				M.spawn_all ()
			end
			function M.reset ()
				for _, intersection in pairs (persistence.TrafficIntersections) do
					intersection:restart_phasing ()
				end
			end
			return M
		end,
		["common.mod_objects.trafficLights.intersection"] = function ()
			local meta_thisFileRequirePath = "common.mod_objects.trafficLights.intersection"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local persistence = require "persistence"
			local libScoop = require "lib.scoop.lib"
			local classInitializer = libScoop._classInitializer
			local parentPrototype = require "lib.scoop.classes.SCOOP_Object"
			local scoped_id_generator = require "common.mod_objects.trafficLights.uid".TrafficIntersection
			local executeAtTickLib = require "lib.executeAtTick"
			local execAfterTicks = executeAtTickLib.executeAfterTicks
			local cancelExecAfter = executeAtTickLib.cancelExecuteAtTick
			local enums = require "common.mod_objects.trafficLights.enums"
			local indications = enums.indication_ids
			local container = require "persistence".TrafficIntersections
			local config = require "config"
			local reset_delay = 60 * 1
			local intersectionPrototype = {
				__type = "TrafficIntersection",
				__parent_prototype__ = parentPrototype,
				trafficLight_ids = libScoop.createNewTableForEachInstance ()
			}
			libScoop.registerClass (intersectionPrototype)
			function intersectionPrototype.New (instance)
				return classInitializer (intersectionPrototype, instance)
			end
			local function parseProperty (self, prop, logger)
				local strVal = self.zone.meta[prop]
				if not strVal then
					return 
				end
				local numVal = tonumber (strVal)
				if not numVal then
					logger.error ("Could not parse tag '%s' with value '%s' to number.", prop, strVal)
					return 
				end
				self[prop] = numVal
			end
			function intersectionPrototype:constructor ()
				self.Intersection_ID = self.Intersection_ID or scoped_id_generator.next ()
				container[self.Intersection_ID] = self
				local logger = logger.getMethodLogger ("constructor", self.Intersection_ID)
				logger.dump ("Constructing TrafficIntersection #%i", self.Intersection_ID)
				self.green_duration = config.trafficIntersection.green_duration
				self.amber_duration = config.trafficIntersection.amber_duration
				self.red_duration = config.trafficIntersection.red_duration
				parseProperty (self, "green_duration", logger)
				parseProperty (self, "amber_duration", logger)
				parseProperty (self, "red_duration", logger)
				logger.dump ("Settings: green_duration: %.1fs, amber_duration: %.1fs, red_duration: %.1fs", self.green_duration / 60, self.amber_duration / 60, self.red_duration / 60)
			end
			function intersectionPrototype:add_trafficLight (tl)
				local logger = logger.getMethodLogger ("add_trafficLight", self.Intersection_ID)
				logger.debug ("Adding TL#%i", tl.Global_ID)
				self.trafficLight_ids[tl.Global_ID] = true
				self:execAfterExclusive (reset_delay, self.update_phasePlan)
			end
			function intersectionPrototype:signals_map ()
				local results = { }
				for id in pairs (self.trafficLight_ids) do
					local instance = persistence.TrafficLights:by_global_id (id)
					if instance then
						results[id] = instance
					else
						logger.error ("No TrafficLight for Global_ID %i", id)
					end
				end
				return results
			end
			function intersectionPrototype:signals_set ()
				local results = { }
				for id in pairs (self.trafficLight_ids) do
					local instance = persistence.TrafficLights:by_global_id (id)
					if instance then
						results[instance] = true
					else
						logger.error ("No TrafficLight for Global_ID %i", id)
					end
				end
				return results
			end
			function intersectionPrototype:signals_list ()
				local results = { }
				for id in pairs (self.trafficLight_ids) do
					local instance = persistence.TrafficLights:by_global_id (id)
					if instance then
						table.insert (results, instance)
					else
						logger.error ("No TrafficLight for Global_ID %i", id)
					end
				end
				return results
			end
			local function get_GAR (s)
				if not s.phaseProperties then
					return nil, nil, nil
				end
				local s_green = s.phaseProperties.green_duration
				local s_amber = s.phaseProperties.amber_duration
				local s_red = s.phaseProperties.red_duration
				return s_green, s_amber, s_red
			end
			function intersectionPrototype:update_phasePlan ()
				local signals_set = self:signals_set ()
				local phase_plan = { }
				for s in pairs (signals_set) do
					local s_green, s_amber, s_red = get_GAR (s)
					local array = (s.phaseProperties and s.phaseProperties.phases) or { s.phaseProperties and s.phaseProperties.phase }
					for _, pn in pairs (array) do
						local entry = phase_plan[pn] or {
							lights = { },
							green_duration = s_green or self.green_duration,
							amber_duration = s_amber or self.amber_duration,
							red_duration = s_red or self.red_duration
						}
						phase_plan[pn] = entry
						table.insert (entry.lights, s.Global_ID)
						s.intersection_id = self.Intersection_ID
					end
				end
				for s in pairs (signals_set) do
					local s_green, s_amber, s_red = get_GAR (s)
					if s.intersection_id ~= self.Intersection_ID then
						local entry = {
							lights = { s.Global_ID },
							green_duration = s_green or self.green_duration,
							amber_duration = s_amber or self.amber_duration,
							red_duration = s_red or self.red_duration
						}
						table.insert (phase_plan, entry)
						s.intersection_id = self.Intersection_ID
					end
				end
				self.phase = 1
				self.phase_plan = phase_plan
				self.phase_plan_length = # phase_plan
				self:restart_phasing ()
			end
			function intersectionPrototype:restart_phasing ()
				local logger = logger.getMethodLogger ("restart_phasing", self.Intersection_ID)
				logger.trace "."
				local signals_set = self:signals_set ()
				local any_transitioning = false
				for signal in pairs (signals_set) do
					if signal.indication ~= indications.red and signal.indication ~= indications.amber then
						signal:setIndication (indications.amber)
						any_transitioning = true
					end
				end
				if any_transitioning then
					logger.trace ("Waiting %it %.1fs for signals to show amber.", self.amber_duration, self.amber_duration / 60)
					self:execAfterExclusive (self.amber_duration, intersectionPrototype.restart_phasing)
					return 
				end
				for signal in pairs (signals_set) do
					if signal.indication ~= indications.red then
						signal:setIndication (indications.red)
					end
				end
				logger.trace ("Waiting %it %.1fs in red state before starting phasing...", self.amber_duration, self.amber_duration / 60)
				self:execAfterExclusive (self.amber_duration, intersectionPrototype._do_phase_green)
			end
			local function safeSetIndication (light_id, indication, logger)
				local instance = persistence.TrafficLights:by_global_id (light_id)
				if not instance then
					logger.error ("Did not receive a TrafficLight for ID number %i", light_id)
					return 
				end
				instance:setIndication (indication)
			end
			function intersectionPrototype:_do_phase (indication, next, logger)
				logger.trace "Start."
				local plan_entry = self.phase_plan[self.phase]
				for _, id in pairs (plan_entry.lights) do
					safeSetIndication (id, indication, logger)
				end
				local name = enums.indications_names[indication]
				local duration = plan_entry[name .. "_duration"]
				self:execAfterExclusive (duration, next)
				logger.trace ("Timer set for %.1f.", duration / 60)
			end
			function intersectionPrototype:_do_phase_green ()
				local logger = logger.getMethodLogger ("_do_phase_green", self.Intersection_ID)
				self:_do_phase (indications.green, self._do_phase_amber, logger)
			end
			function intersectionPrototype:_do_phase_amber ()
				local logger = logger.getMethodLogger ("_do_phase_amber", self.Intersection_ID)
				self:_do_phase (indications.amber, self._do_phase_red, logger)
			end
			function intersectionPrototype:_do_phase_red ()
				local logger = logger.getMethodLogger ("_do_phase_red", self.Intersection_ID)
				self:_do_phase (indications.red, self._do_phase_green, logger)
				self.phase = (self.phase % self.phase_plan_length) + 1
				logger.trace ("Advanced phase to: %i", self.phase)
			end
			function intersectionPrototype:execAfterExclusive (ticks, fn)
				local function f2 ()
					fn (self)
				end
				if self.timer_token then
					cancelExecAfter (self.timer_token)
				end
				local token = execAfterTicks (ticks, f2)
				self.timer_token = token
				return token
			end
			return intersectionPrototype
		end,
		["common.mod_objects.trafficLights.persistence"] = function ()
			local scoopLib = require "lib.scoop.lib"
			local scoop_load_fn = scoopLib.deserializeClassMethods
			local libSaveData = require "lib.saveData"
			local persistence = require "lib.persistenceHelper"
			local createWrapperWithBackingContainer = persistence.createWrapperWithBackingContainer
			local M = { }
			do
				local container, wrapper = createWrapperWithBackingContainer ({
					key = "TrafficLights",
					load_fn = scoop_load_fn
				}, "Global_ID", "vehicle_id")
				M._trafficLights = container
				M.TrafficLights = wrapper
			end
			M.TrafficIntersections = libSaveData.register {
				key = "TrafficIntersections",
				load_fn = scoop_load_fn
			}
			return M
		end,
		["common.mod_objects.trafficLights.trafficLight"] = function ()
			local meta_thisFileRequirePath = "common.mod_objects.trafficLights.trafficLight"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local phase_input_name = "!Traffic_Light"
			local persistence = require "persistence"
			local libScoop = require "lib.scoop.lib"
			local classInitializer = libScoop._classInitializer
			local parentPrototype = require "lib.scoop.classes.VehicleBoundObject"
			local scoped_id_generator = require "common.mod_objects.trafficLights.uid".TrafficLightGlobal
			local vec = require "lib.vector3"
			local serpent = require "lib.serialization.serpent"
			local lightsContainer = require "persistence".TrafficLights
			local vehicleBoundObjectRegistration = require "lib.scoop.classes.VehicleBoundObject.registration"
			vehicleBoundObjectRegistration.registerDoublyIndexedTable ("TrafficLightGlobal", lightsContainer)
			local trafficLightPrototype = {
				__type = "TrafficLight",
				__parent_prototype__ = parentPrototype,
				indication = 0,
				disappear_detection = true,
				disappear_respawn = true
			}
			libScoop.registerClass (trafficLightPrototype)
			function trafficLightPrototype.New (instance)
				return classInitializer (trafficLightPrototype, instance)
			end
			function trafficLightPrototype:constructor ()
				self.Global_ID = self.Global_ID or scoped_id_generator.next ()
				lightsContainer:add (self)
				logger.dump ("Constructing TrafficLight with Global_ID %i and vehicle_id %i", self.Global_ID, self.vehicle_id)
			end
			local proto_logger = logger.getSubLogger "proto"
			local function sanitize_variant_label (input)
				if type (input) == "string" then
					return input
				else
					return "default"
				end
			end
			local function getPhaseProperty (self, prop, logger)
				local strVal = self.meta[prop]
				if not strVal then
					return 
				end
				local numVal = tonumber (strVal)
				if not numVal then
					logger.error ("Could not parse tag '%s' with value '%s' to number.", prop, strVal)
					return 
				end
				return numVal
			end
			local function parsePhaseProperty (self, prop, logger)
				local numVal = getPhaseProperty (self, prop, logger)
				if not numVal then
					return 
				end
				self.phaseProperties = self.phaseProperties or { }
				self.phaseProperties[prop] = numVal
			end
			local function parsePhaseProperties (self, logger)
				parsePhaseProperty (self, "phase", logger)
				parsePhaseProperty (self, "green_duration", logger)
				parsePhaseProperty (self, "amber_duration", logger)
				parsePhaseProperty (self, "red_duration", logger)
				local numPhases = getPhaseProperty (self, "num_phases", logger)
				if numPhases then
					local phases = { }
					for i = 1, numPhases do
						local p = getPhaseProperty (self, "phase_" .. i, logger)
						if p then
							table.insert (phases, p)
						end
					end
					self.phaseProperties = self.phaseProperties or { }
					self.phaseProperties.phases = phases
				end
			end
			function trafficLightPrototype:onVehicleSpawn (vehicle_id, spawned_by_peer_id, x, y, z, cost)
				self:parent_proto ().onVehicleSpawn (self, vehicle_id, spawned_by_peer_id, x, y, z, cost)
				local logger = proto_logger.getMethodLogger ("onVehicleSpawn", string.format ("I%03i", self.Global_ID))
				local variant_label = self.meta.trafficLight
				self.variant = sanitize_variant_label (variant_label)
				if not self.variant then
					logger.warn ("Encountered TrafficLight without variant label: %s", function ()
						return serpent.block (self)
					end)
				end
				local transform = server.getVehiclePos (self.vehicle_id)
				self.position = vec.Position_From_ArrayMatrix (transform)
				self.direction = vec.Forward_From_ArrayMatrix (transform)
				parsePhaseProperties (self, logger)
				for _, intersection in pairs (persistence.TrafficIntersections) do
					local zone = intersection.zone
					local zone_transform = zone.transform
					local zone_size = zone.size
					local sx, sy, sz = zone_size.x, zone_size.y, zone_size.z
					if server.isInTransformArea (transform, zone_transform, sx, sy, sz) then
						intersection:add_trafficLight (self)
					end
				end
			end
			function trafficLightPrototype:Initialize ()
				
			end
			function trafficLightPrototype:onVehicleLoad ()
				self:parent_proto ().onVehicleLoad (self)
				self:_writeIndicationToVehicle ()
			end
			function trafficLightPrototype:onVehicleDespawn ()
				lightsContainer:remove (self)
				self:parent_proto ().onVehicleDespawn (self)
			end
			function trafficLightPrototype:setIndication (index)
				self.indication = index
				self:_writeIndicationToVehicle ()
			end
			function trafficLightPrototype:_writeIndicationToVehicle ()
				logger.dump ("Writing phase %i to TrafficLight %i (vehicle_id %i)", self.indication, self.Global_ID, self.vehicle_id)
				server.setVehicleKeypad (self.vehicle_id, phase_input_name, self.indication)
			end
			return trafficLightPrototype
		end,
		["common.mod_objects.trafficLights.uid"] = function ()
			local uid = require "lib.uid"
			local M = { }
			M.TrafficLightGlobal = uid.getStandard "TrafficLightGlobal"
			M.TrafficIntersection = uid.getStandard "TrafficIntersection"
			return M
		end,
		["common.mod_objects.vehicleDisappearMitigation"] = function ()
			local meta_thisFileRequirePath = "common.mod_objects.vehicleDisappearMitigation"
			require "lib.addon.wrappers"
			local keyValueParser = require "lib.keyValueParser"
			local config = require "config"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local addon = require "lib.addon"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local libSaveData = require "lib.saveData"
			local registry = libSaveData.register { key = "vehicleDisappearMitigationRegistry" }
			local function is_respawn_enabled (data)
				if not data or not data.tags then
					return false
				end
				for _, tag in pairs (data.tags) do
					if tag == "RespawnIfMissing" or tag == "respawnifmissing" then
						return true
					end
				end
				return false
			end
			local displayTags = {
				"Cat1",
				"Cat2",
				"Cat3",
				"Cat4",
				"Cat5",
				"Cat6",
				"Cat",
				"LOD"
			}
			local function getDisplayTag (data)
				if not data then
					return "unknown"
				end
				for _, t in pairs (displayTags) do
					if data[t] then
						return t
					end
				end
				return "unknown"
			end
			local function m_onSpawnAddonVehicle (transform, addon_index, component_id, vehicle_id)
				local logger = logger.getSubLogger "m_onSpawnAddonVehicle"
				local component, component_index, location_index = addon.componentById (addon_index, component_id)
				if not component then
					logger.error ("Did not find component_id %i in addon_index %i", component_id, addon_index)
					return 
				end
				local meta = keyValueParser (component.tags_full)
				if not meta.RespawnIfMissing then
					return 
				end
				if not vehicle_id then
					logger.debug ("No vehicle was spawned for this component (addon_index %i, location_index %i, component_index %i, component_id %i).", addon_index, location_index, component_index, component_id)
					return 
				end
				logger.dump ("Working on: addon_index %i, location_index %i, component_index %i, component_id %i.", addon_index, location_index, component_index, component_id)
				local now = server.getTimeMillisec ()
				local tag = getDisplayTag (meta)
				registry[vehicle_id] = {
					tag = tag,
					vehicle_id = vehicle_id,
					spawned_at = now,
					despawned = false,
					is_loaded = false,
					is_missing = false,
					last_seen_at = now,
					addon_index = addon_index,
					location_index = location_index,
					component_index = component_index,
					component_id = component_id,
					component_spawn_transform = transform
				}
				logger.debug ("Registered disappear-mitigation for vehicle_id %i addon_index %i and component_id %i", vehicle_id, addon_index, component_id)
			end
			addonCallbacks.registerCallback ("_onSpawnAddonVehicle", meta_thisFileRequirePath, m_onSpawnAddonVehicle)
			local function m_onVehicleSpawn (vehicle_id, peer_id)
				local existing = registry[vehicle_id]
				if existing then
					existing.spawned_by = peer_id
					logger.debug ("Updated metadata on disappear-mitigation for %s (vehicle_id %i).", existing.tag, vehicle_id)
					return 
				end
				local data = addon.getExtendedVehicleData (vehicle_id)
				if not data then
					logger.error ("Received no data for vehicle_id %i inside the onVehicleSpawn of that vehicle", vehicle_id)
					return 
				end
				if not is_respawn_enabled (data) then
					return 
				end
				local now = server.getTimeMillisec ()
				local tag = getDisplayTag (data.meta)
				registry[vehicle_id] = {
					tag = tag,
					vehicle_id = vehicle_id,
					spawned_at = now,
					spawned_by = peer_id,
					despawned = false,
					is_loaded = false,
					is_missing = false,
					last_seen_at = now
				}
				logger.debug ("Registered disappear-mitigation for %s (vehicle_id %i)", tag, vehicle_id)
			end
			addonCallbacks.registerCallback ("onVehicleSpawn", meta_thisFileRequirePath, m_onVehicleSpawn)
			local function m_onVehicleLoad (vehicle_id)
				local entry = registry[vehicle_id]
				if not entry then
					return 
				end
				entry.is_loaded = true
				entry.loaded_at = server.getTimeMillisec ()
				logger.debug ("Disappear-mitigation tracked tag %s (vehicle_id %i) is now loaded.", entry.tag, vehicle_id)
			end
			addonCallbacks.registerCallback ("onVehicleLoad", meta_thisFileRequirePath, m_onVehicleLoad)
			local function m_onVehicleUnload (vehicle_id)
				local entry = registry[vehicle_id]
				if not entry then
					return 
				end
				entry.is_loaded = false
				entry.unloaded_at = server.getTimeMillisec ()
				logger.debug ("Disappear-mitigation tracked %s (vehicle_id %i) is now unloaded.", entry.tag, vehicle_id)
			end
			addonCallbacks.registerCallback ("onVehicleUnload", meta_thisFileRequirePath, m_onVehicleUnload)
			local function m_onVehicleDespawn (vehicle_id, peer_id)
				local entry = registry[vehicle_id]
				if not entry then
					return 
				end
				entry.despawned = true
				entry.despawned_at = server.getTimeMillisec ()
				entry.despawned_by = peer_id
				registry[vehicle_id] = nil
				logger.debug ("Disappear-mitigation tracked %s (vehicle_id %i) despawned.", entry.tag, entry.vehicle_id)
			end
			addonCallbacks.registerCallback ("onVehicleDespawn", meta_thisFileRequirePath, m_onVehicleDespawn)
			local function onWentMissing (entry)
				if (not entry.component_spawn_transform or not entry.addon_index) or not entry.component_id then
					return 
				end
				local logger = logger.getSubLogger "onWentMissing"
				local id, s, _ = server.spawnAddonVehicle (entry.component_spawn_transform, entry.addon_index, entry.component_id)
				if s then
					logger.verbose ("Respawned %s (old vehicle_id %i, new vehicle_id %i)", entry.tag, entry.vehicle_id, id)
				else
					local c = addon.componentById (entry.addon_index, entry.component_id)
					local reason = " - unknown"
					if not c then
						reason = " - No addon component data found for it."
					elseif c and c.display_name then
						reason = string.format (" - A component '%s' on addon#%i with component_id %i was found, but spawning still failed.", c.display_name, entry.addon_index, entry.component_id)
					end
					logger.error ("Failed to respawn %s (old vehicle_id %i)%s.", entry.tag, entry.vehicle_id, reason)
				end
			end
			do
				local index = nil
				local function m_onTick ()
					if not config.vehicleDisappearMitigation.enabled then
						return 
					end
					local logger = logger.getSubLogger "m_onTick"
					local entry
					index, entry = next (registry, (index and registry[index]) and index)
					local now = server.getTimeMillisec ()
					if not entry then
						return 
					end
					if entry.despawned then
						registry[index] = nil
						logger.debug ("Removing record for despawned vehicle_id %i", entry.vehicle_id)
						return 
					end
					if entry.is_missing then
						local elapsed = (now - (entry.despawned_at or entry.last_seen_at)) / 1000
						if (config.vehicleDisappearMitigation and config.vehicleDisappearMitigation.staleRecordTimeoutSeconds) and config.vehicleDisappearMitigation.staleRecordTimeoutSeconds < elapsed then
							registry[index] = nil
							logger.verbose ("Removing stale record for %s (vehicle_id %i) status: ", entry.tag, entry.vehicle_id, (entry.is_missing and "missing") or "unknown")
						end
						return 
					end
					local data, found = server.getVehicleData (entry.vehicle_id)
					if data and found then
						entry.last_seen_at = now
						return 
					end
					entry.is_missing = true
					entry.detected_missing_at = now
					local elapsed = (now - entry.last_seen_at) / 1000
					logger.warning ("Disappear-mitigation tracked %s (vehicle_id %i) went missing! It was last seen %.1fs ago.", entry.tag, entry.vehicle_id, elapsed)
					onWentMissing (entry)
				end
				addonCallbacks.registerCallback ("onTick", meta_thisFileRequirePath, m_onTick)
			end
			logger.debug ("initialized %s", meta_thisFileRequirePath)
		end,
		["common.mod_objects.welcome"] = function ()
			local meta_thisFileRequirePath = "common.mod_objects.welcome"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local vec = require "lib.vector3"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local persistence = require "persistence"
			local welcomed_players = persistence.welcomed_players
			local libAddonPlayer = require "lib.addon.player"
			local libCommandHandler = require "lib.legacyCommands.handler"
			local pending_players = { }
			local function onPlayerJoin (steam_id, name, peer_id, admin, auth)
				if welcomed_players[steam_id] then
					return 
				end
				pending_players[peer_id] = { }
				logger.trace ("Added peer_id #%i ('%s') to the pending welcome list.", peer_id, name)
			end
			addonCallbacks.registerCallback ("onPlayerJoin", meta_thisFileRequirePath, onPlayerJoin)
			local function sendWelcomeMessage (peer_id)
				pending_players[peer_id] = nil
				local player = libAddonPlayer.getPlayer (peer_id)
				if not player then
					logger.warning ("Player %i went missing, unable to send welcome message.", peer_id)
					return 
				end
				logger.trace ("Sending welcome message to peer_id %i", peer_id)
				local full_command = string.format ("%s info", libCommandHandler.commandNamespace)
				onCustomCommand (full_command, peer_id, player.admin, player.auth, libCommandHandler.commandNamespace, "info")
			end
			local function onTick ()
				for peer_id, data in pairs (pending_players) do
					local prev_pos = data.position
					local prev_look = data.look
					local new_transform, found = server.getPlayerPos (peer_id)
					if new_transform and found then
						local new_pos = vec.Position_From_ArrayMatrix (new_transform)
						if prev_pos then
							if not vec.Equals (prev_pos, new_pos) then
								sendWelcomeMessage (peer_id)
								return 
							end
						else
							data.position = new_pos
						end
					end
					local nlx, nly, nlz, found = server.getPlayerLookDirection (peer_id)
					if ((nlx and nly) and nlz) and found then
						local new_look = vec.New (nlx, nly, nlz)
						if prev_look then
							if not vec.Equals (prev_look, new_look) then
								sendWelcomeMessage (peer_id)
								return 
							end
						else
							data.look = new_look
						end
					end
				end
			end
			addonCallbacks.registerCallback ("onTick", meta_thisFileRequirePath, onTick)
		end,
		["common.objects.commands"] = function ()
			local meta_thisFileRequirePath = "common.objects.commands"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local keyValueParser = require "lib.keyValueParser"
			local addon = require "lib.addon"
			local hasTag = addon.hasTag
			local iterLocations = addon.iterLocations
			local iterComponents = addon.iterComponents
			local callbackRegistration = require "lib.addonCallbacks.registration"
			local serpent = require "lib.serialization.serpent"
			local libCommandHandler = require "lib.legacyCommands.handler"
			local commands = libCommandHandler.commands or { }
			libCommandHandler.commands = commands
			local commandHelpers = require "lib.legacyCommands.helpers"
			local complain_if_not_admin = commandHelpers.complain_if_not_admin
			local M = {
				addon_tag = "undefined",
				default_spawn_filter = "undefined",
				formatting = {
					command_title_name = "ADO",
					addon_short_name = "ADDON_NAME",
					addon_long_name = "Addon Long Name"
				}
			}
			local tile_map
			local spawned = {
				vehicle_id__to__component = { },
				no_duplicates_set = { },
				objects = { }
			}
			M.spawned = spawned
			local function tableCount (t)
				local count = 0
				for _, _ in pairs (t) do
					count = count + 1
				end
				return count
			end
			local function getTileZones ()
				if tile_map then
					return tile_map
				end
				local search_tag = "tile_registry"
				zones = server.getZones (search_tag)
				logger.debug ("Received %i zones.", # zones)
				tile_map = { }
				for i, zone in pairs (zones) do
					zone.meta = keyValueParser (zone.tags_full)
					local tile_file = zone.meta.tile_file
					local bucket = tile_map[tile_file] or { }
					tile_map[tile_file] = bucket
					table.insert (bucket, zone)
					logger.dump ("Added zone #%4i to bucket '%s'", i, tile_file)
				end
				return tile_map
			end
			local EMPTY_TABLE = { }
			local function getOccurrencesForTile (tile_path)
				local map = getTileZones ()
				return map[tile_path] or EMPTY_TABLE
			end
			local function get_no_duplicates_key (component_id, zone_id)
				return string.format ("C%i-Z%s", component_id, zone_id or "?")
			end
			local type_to_default_variant = {
				train_station = "default",
				junction = "symm",
				signalling_equipment_type = "Asig",
				train_buffer = "default",
				sign = "default"
			}
			local type_to_variant_map = { }
			local function m_onCreate ()
				spawned = (g_savedata or spawned) or { }
				spawned.vehicles = spawned.vehicles or { }
				spawned.objects = spawned.objects or { }
				spawned.no_duplicates_set = spawned.no_duplicates_set or { }
				spawned.vehicle_id__to__component = spawned.vehicle_id__to__component or { }
				M.spawned = spawned
				g_savedata = spawned
				for type_str, default_variant in pairs (type_to_default_variant) do
					local r = addon.generateVariantByCategoryMapping (type_str, default_variant)
					type_to_variant_map[type_str] = r
				end
			end
			callbackRegistration.registerCallback ("onCreate", meta_thisFileRequirePath, m_onCreate)
			local function getTypeAndVariant (meta)
				local type_str, variant
				do
					local junction_type = meta.junction
					if junction_type then
						type_str = "junction"
						variant = junction_type
						return type_str, variant
					end
				end
				do
					local signal_type = meta.signalling_equipment_type
					if signal_type then
						type_str = "signalling_equipment"
						variant = signal_type
						return type_str, variant
					end
				end
				do
					local buffer = meta.train_buffer
					if buffer then
						type_str = "train_buffer"
						variant = (buffer == true and "default") or buffer
					end
				end
				do
					local variant = meta.train_station_vehicle
					if variant then
						type_str = "train_station"
						return type_str, variant
					end
				end
				do
					local variant = meta.sign
					if variant then
						type_str = "sign"
						return type_str, variant
					end
				end
			end
			local function getPrefab (meta)
				local logger = logger.getSubLogger "getPrefab"
				local type_str, variant = getTypeAndVariant (meta)
				local r = type_to_variant_map[type_str]
				if not r then
					local default = type_to_default_variant[type_str]
					if not default then
						return nil
					end
					logger.trace ("Generating VariantByCategoryMapping on-the-fly for %s...", type_str)
					r = addon.generateVariantByCategoryMapping (type_str, default)
					type_to_variant_map[type_str] = r
				end
				return r[variant]
			end
			local function m_onSpawnAddonVehicle (transform, addon_index, component_id, spawned_id)
				if not spawned_id then
					return 
				end
				if spawned.vehicle_id__to__component[spawned_id] then
					return 
				end
				local logger = logger.getSubLogger "m_onSpawnAddonVehicle"
				local vehicle_data, s = server.getVehicleData (spawned_id)
				if not vehicle_data or not s then
					logger.warning ("No vehicle_data for vehicle_id %i", spawned_id)
					return 
				end
				local component, component_index, location_index = addon.componentById (addon_index, component_id)
				if not component then
					logger.warning ("No component_data for vehicle_id %i", spawned_id)
					return 
				end
				component.vehicle_id = spawned_id
				spawned.vehicle_id__to__component[spawned_id] = component
				component.vehicle_is_static = vehicle_data.static or false
				if not component.meta then
					logger.trace "Parsing meta tags on the fly..."
					component.meta = keyValueParser (component.tags_full)
				end
				if vehicle_data.static or component.meta.no_duplicate_spawn then
					spawned.no_duplicates_set[component.id] = true
				end
				logger.debug ("Adding vehicle_id %i to registration of spawned vehicles.", spawned_id)
			end
			callbackRegistration.registerCallback ("_onSpawnAddonVehicle", meta_thisFileRequirePath, m_onSpawnAddonVehicle)
			local function spawn_component_vehicle (cdata, addon_index, location_index, zone_id, location_matrix, component_index, component)
				local logger = logger.getSubLogger "spawn_component_vehicle"
				local no_duplicates_key = get_no_duplicates_key (component.id, zone_id)
				if spawned.no_duplicates_set[no_duplicates_key] then
					logger.trace ("Not spawning Component %i in location %i in addon %i because it's static and has already been spawned.", component.id, location_index, addon_index)
					return 
				end
				local global_transform = matrix.multiply (location_matrix, component.transform)
				local spawned_id, did_succ = server.spawnAddonVehicle (global_transform, addon_index, component.id)
				if not spawned_id or not did_succ then
					logger.trace ("Failed to spawn vehicle: location_index: %i / component_index: %i", location_index, component_index)
					return 
				end
				logger.trace ("Spawned vehicle: '%s' with id %i", (((component.display_name and component.display_name ~= "") and component.display_name) or (component.meta and component.meta.label)) or "", spawned_id)
				component.vehicle_id = spawned_id
				component.spawn_transform = global_transform
				component.zone_id = zone_id
				spawned.vehicle_id__to__component[spawned_id] = component
				local vehicle_data = server.getVehicleData (spawned_id)
				component.vehicle_is_static = vehicle_data.static or false
				if vehicle_data.static or component.meta.no_duplicate_spawn then
					spawned.no_duplicates_set[no_duplicates_key] = true
				end
				return true
			end
			local function spawn_component_zone_vehicle (cdata, addon_index, location_index, zone_id, location_matrix, component_index, component)
				local logger = logger.getSubLogger "spawn_component_zone_vehicle"
				local prefab = getPrefab (component.meta)
				if not prefab then
					logger.warning ("Did not get a prefab: location_index: %i / component_index: %i tags: %s", location_index, component_index, component.tags_full)
					return 
				end
				local no_duplicates_key = get_no_duplicates_key (component.id, zone_id)
				if spawned.no_duplicates_set[no_duplicates_key] then
					logger.trace ("Not spawning Component %i in location %i in addon %i because it's static and has already been spawned.", component.id, location_index, addon_index)
					return 
				end
				local global_transform = matrix.multiply (location_matrix, component.transform)
				local spawned_id, did_succ = prefab.spawn (global_transform)
				if not spawned_id or not did_succ then
					logger.error ("Failed to spawn vehicle: location_index: %i / component_index: %i", location_index, component_index)
					return 
				end
				logger.trace ("Spawned vehicle: '%s' with id %i from component # %i with tags: %s", component.display_name, spawned_id, component.id, component.tags_full)
				component.vehicle_id = spawned_id
				component.spawn_transform = global_transform
				component.zone_id = zone_id
				spawned.vehicle_id__to__component[spawned_id] = component
				local vehicle_data = server.getVehicleData (spawned_id)
				component.vehicle_is_static = vehicle_data.static or false
				if vehicle_data.static or component.meta.no_duplicate_spawn then
					spawned.no_duplicates_set[no_duplicates_key] = true
				end
				return true
			end
			local function spawn_at_component_index (cdata, addon_index, location_index, zone_id, location_matrix, component_index, filter)
				local logger = logger.getSubLogger "spawn_at_component_index"
				local component, did_succ = server.getLocationComponentData (addon_index, location_index, component_index)
				if not component or not did_succ then
					logger.warning ("no component data for location_index: %i / component_index: %i", location_index, component_index)
					return 
				end
				local meta = component.meta or keyValueParser (component.tags_full)
				component.meta = meta
				if filter and (not hasTag (component.tags, filter) and not component.meta[filter]) then
					logger.trace ("No match with filter. Component_id: %i Tags: %s", component.id, component.tags_full)
					return 
				end
				if component.type == "vehicle" then
					return spawn_component_vehicle (cdata, addon_index, location_index, zone_id, location_matrix, component_index, component)
				elseif component.type == "zone" then
					return spawn_component_zone_vehicle (cdata, addon_index, location_index, zone_id, location_matrix, component_index, component)
				else
					logger.error ("No handler for type %s", component.type)
				end
			end
			local function location_type_str (location)
				return (location and ((location.env_mod and "env") or "mis")) or "nil"
			end
			local function spawn_at_location_tile (cdata, addon_index, location_index, location, zone, filter)
				local logger = logger.getSubLogger "spawn_at_location_tile"
				logger.trace ("Working on location_index: %2d %s '%s' tile: '%s' Zone_ID: %i ...", location_index, location_type_str (location), location.name, location.tile or "<<nil>>", zone.id)
				local location_matrix, did_suck = server.getTileTransform (zone.transform, location.tile, 499)
				if did_suck == false then
					if location.name:match "Prefabs - " then
						return 0
					end
					logger.error ("Did not receive tile transform for location_index: %2d %s '%s' tile: '%s'", location_index, location_type_str (location), location.name, location.tile or "<<nil>>")
					return 0
				end
				local counter = 0
				for component_index = 0, location.component_count - 1 do
					local did_spawn = spawn_at_component_index (cdata, addon_index, location_index, zone.id, location_matrix, component_index, filter)
					if did_spawn then
						counter = counter + 1
					end
				end
				return counter
			end
			local function spawn_at_location_index (cdata, addon_index, location_index, filter)
				local logger = logger.getSubLogger "spawn_at_location_index"
				local location, did_succ = server.getLocationData (addon_index, location_index)
				if not did_succ then
					logger.error ("No location data for location_index: %i", location_index)
					return 0
				end
				logger.trace ("Working on location_index: %2d %s '%s' tile: '%s' ...", location_index, location_type_str (location), location.name, location.tile or "<<nil>>")
				local counter = 0
				for i, zone in pairs (getOccurrencesForTile (location.tile)) do
					zone.id = i
					counter = counter + spawn_at_location_tile (cdata, addon_index, location_index, location, zone, filter)
				end
				return counter
			end
			function commands.spawn (context)
				local command_name = "Spawn"
				local logger = logger.getSubLogger (string.lower (command_name))
				local title = string.format ("%s %s", M.formatting.command_title_name, command_name)
				if complain_if_not_admin (context) then
					return 
				end
				local addon_index, did_succ = server.getAddonIndex ()
				if not addon_index or not did_succ then
					context.announce (title, "Error: did not receive addon_index!")
					return 
				end
				local addon = server.getAddonData (addon_index)
				if not addon then
					context.announce (title, "Error: did not receive addon data!")
					return 
				end
				local filter = context.args[1] or M.default_spawn_filter
				if context.args[1] then
					local format = "Spawning components that match filter: '%s'..."
					logger.trace (format, filter)
					context.announce (title, format, filter)
				else
					local format = "Spawning all components using the everything filter: '%s'..."
					logger.trace (format, filter)
					context.announce (title, format, filter)
				end
				local counter = 0
				for location_index = 0, addon.location_count - 1 do
					logger.debug ("Working on location_index %4i / %3i", location_index, addon.location_count)
					counter = counter + spawn_at_location_index (context, addon_index, location_index, filter)
				end
				logger.trace ("Done spawning, %i items spawned. Total counts of currently spawned vehicles %i", counter, tableCount (spawned.vehicle_id__to__component))
				context.announce (title, "Spawning Objects completed!\nSpawned %i total things. There are currently %i vehicles and %i objects total.", counter, tableCount (spawned.vehicle_id__to__component), tableCount (spawned.objects))
			end
			function commands.despawn (context)
				local command_name = "Despawn"
				local title = string.format ("%s %s", M.formatting.command_title_name, command_name)
				if complain_if_not_admin (context) then
					return 
				end
				local filter = context.args[1]
				if filter then
					context.announce (title, "Despawning components that match filter '%s'...", filter)
				end
				local vc, oc = 0, 0
				for id, data in pairs (spawned.vehicle_id__to__component) do
					if not filter or hasTag (data.tags, filter) then
						server.despawnVehicle (id, true)
						spawned.vehicle_id__to__component[id] = nil
						vc = vc + 1
						spawned.no_duplicates_set[data.id] = nil
					end
				end
				for id, data in pairs (spawned.objects) do
					if not filter or hasTag (data.tags, filter) then
						server.despawnObject (id, true)
						spawned.objects[id] = nil
						oc = oc + 1
					end
				end
				context.announce (title, "Despanwing completed!\nRemoved %i vehicles and %i objects.", vc, oc)
			end
			function commands.respawn (context)
				local command_name = "Respawn"
				local title = string.format ("%s %s", M.formatting.command_title_name, command_name)
				if complain_if_not_admin (context) then
					return 
				end
				commands.despawn (context)
				commands.spawn (context)
				context.announce (title, "Respawning objects completed!")
			end
			function commands.deleteAll (context)
				local command_name = "Delete_ALL"
				local title = string.format ("%s %s", M.formatting.command_title_name, command_name)
				if complain_if_not_admin (context) then
					return 
				end
				context.notify (7, title, "Despawning all vehicles!", 7)
				local cnt = 0
				for i = 0, 10000 do
					local succ = server.despawnVehicle (i, true)
					if succ then
						cnt = cnt + 1
					end
				end
				spawned.vehicle_id__to__component = { }
				spawned.objects = { }
				spawned.no_duplicates_set = { }
				context.announce (title, "Despawning all vehicles completed!\nRemoved %i vehicles.", cnt)
			end
			local list_tags_exclude_patterns = { "^id_%d+$" }
			local function is_excluded_tag (name)
				for _, pattern in pairs (list_tags_exclude_patterns) do
					if name:match (pattern) then
						return true
					end
				end
				return false
			end
			local function increment_or_create_key (table, key)
				local value = table[key] or 0
				value = value + 1
				table[key] = value
				return value
			end
			function commands.list_tags (context)
				if not context.is_admin then
					return 
				end
				local results = { }
				local addon_index = server.getAddonIndex ()
				for location_index, location_data in iterLocations (addon_index) do
					for component_index, component in iterComponents (addon_index, location_index) do
						local meta = component.meta or keyValueParser (component.tags_full)
						component.meta = meta
						for name, value in pairs (meta) do
							local test_name = name
							if value ~= true then
								test_name = string.format ("%s=%s", tostring (name), tostring (value))
							end
							if not is_excluded_tag (test_name) then
								increment_or_create_key (results, test_name)
							end
						end
					end
				end
				local entries = { }
				for k, v in pairs (results) do
					table.insert (entries, {
						name = k,
						occ = v
					})
				end
				table.sort (entries, function (a, b)
					return b.occ < a.occ
				end)
				local lines = { }
				for k, v in pairs (entries) do
					table.insert (lines, string.format ("[%3i] %s", v.occ, v.name))
				end
				context.announce ("Tags list", "[Occurrances] Tag\n%s", table.concat (lines, "\n"))
			end
			function commands.dump (cdata)
				if not context.is_admin then
					return 
				end
				local logger = logger.getSubLogger "dump"
				logger.dump (serpent.block (spawned))
			end
			function commands.test_logging (context)
				local logger = logger.getSubLogger "TEST_LOGGING"
				logger.dump "Log level: Dump"
				logger.debug "Log level: Debug"
				logger.trace "Log level: Trace"
				logger.verbose "Log level: Verbose"
				logger.info "Log level: Information"
				logger.important "Log level: Important"
				logger.warning "Log level: Warning"
				logger.error "Log level: Error"
				logger.critical "Log level: Critical"
			end
			function commands.dump_disappear_tracking (context)
				if not context.is_admin then
					return 
				end
				local saveData = require "lib.saveData"
				local registry = saveData.get "vehicleDisappearMitigationRegistry"
				local dump = serpent.block (registry)
				logger.important ("Vehicle Disappear Mitigation Registry:\n%s", dump)
				local lines = { }
				for _, entry in pairs (registry) do
					if entry.missing then
						table.insert (lines, string.format ("vehicle_id %i is marked as missing.", entry.tag, entry.vehicle_id))
					elseif entry.despawned then
						table.insert (lines, string.format ("vehicle_id %i is marked as despawned.", entry.tag, entry.vehicle_id))
					end
				end
				if next (lines) then
					context.announce ("Vehicle Disappear Mitigation", "Data dumped to log file.\nProblems detected:\n" .. table.concat (lines, "\n"))
				else
					context.announce ("Vehicle Disappear Mitigation", "Data dumped to log file.\nNo problems detected.")
				end
			end
			function commands.reset_disappear_tracking (context)
				if not context.is_admin then
					return 
				end
				local saveData = require "lib.saveData"
				local registry = saveData.get "vehicleDisappearMitigationRegistry"
				for k in pairs (registry) do
					registry[k] = nil
				end
				logger.important "Cleared Vehicle Disappear Registry"
				context.announce ("Vehicle Disappear Mitigation", "Registry cleared.")
			end
			return M
		end,
		config = function ()
			local secondsPerMinute = 60
			local minutesPerHour = 60
			local config = {
				logging = {
					legacyHttp = { enabled = false },
					terminal = {
						enabled = true,
						ansi_colors = true
					},
					debug_log = { enabled = true }
				},
				vehicleDisappearMitigation = {
					enabled = true,
					staleRecordTimeoutSeconds = (secondsPerMinute * minutesPerHour) * 1
				},
				vehicle_objects = { disappear_mitigation = {
					allow_respawn = true,
					items_per_tick = 1
				} },
				trafficIntersection = {
					green_duration = 60 * 17.5,
					amber_duration = 60 * 2.5,
					red_duration = 60 * 1
				},
				sandbox = { },
				rust = { enabled = true }
			}
			return config
		end,
		["lib.addon"] = function ()
			local m = { }
			local list = {
				"addon",
				"tag",
				"vehicle",
				"zone",
				"player"
			}
			for _, name in pairs (list) do
				local module = require ("lib.addon." .. name)
				for k, v in pairs (module) do
					m[k] = v
				end
			end
			return m
		end,
		["lib.addon.addon"] = function ()
			local meta_thisFileRequirePath = "lib.addon.addon"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local keyValueParser = require "lib.keyValueParser"
			local serpentf = require "lib.serialization.serpentf"
			local moreString = require "lib.moreString"
			local joinStringArray = moreString.joinStringArray
			local splitString = moreString.splitString
			local checkArg = require "lib.checkArg"
			local m = { }
			function m.sortTypeParts (typeString)
				local parts = splitString (typeString, "&")
				table.sort (parts)
				return joinStringArray (parts, "&")
			end
			function m.iterComponents (addon_index, location_index)
				local location_data = server.getLocationData (addon_index, location_index)
				local object_count = 0
				if location_data then
					object_count = location_data.component_count
				end
				local object_index = 0
				return function ()
					local object_data = nil
					local index = object_count
					while not object_data and object_index < object_count do
						object_data = server.getLocationComponentData (addon_index, location_index, object_index)
						index = object_index
						object_index = object_index + 1
					end
					if object_data then
						return index, object_data
					else
						return nil
					end
				end
			end
			function m.iterLocations (addon_index)
				local addon_data = server.getAddonData (addon_index)
				local location_count = 0
				if addon_data then
					location_count = addon_data.location_count
				end
				local location_index = 0
				return function ()
					local location_data = nil
					local index = location_count
					while not location_data and location_index < location_count do
						location_data = server.getLocationData (addon_index, location_index)
						local local_location_index = location_index
						function location_data.iterate ()
							return m.iterComponents (addon_index, local_location_index)
						end
						index = location_index
						location_index = location_index + 1
					end
					if location_data then
						return index, location_data
					else
						return nil
					end
				end
			end
			function m.iterAddons ()
				local addon_count = server.getAddonCount ()
				local addon_index = 0
				return function ()
					local addon_data = nil
					local index = addon_count
					while not addon_data and addon_index < addon_count do
						addon_data = server.getAddonData (addon_index)
						local local_addon_index = addon_index
						function addon_data.iterate ()
							return m.iterLocations (local_addon_index)
						end
						index = addon_index
						addon_index = addon_index + 1
					end
					if addon_data then
						return index, addon_data
					else
						return nil
					end
				end
			end
			function m.objectByTypeMapping_Component (component_data, spawn_tag, addon_index, our_addon_index, objects_by_type)
				local meta = keyValueParser (component_data.tags_full)
				component_data.meta = meta
				local variant = meta[spawn_tag]
				if component_data.type ~= "vehicle" then
					return 
				end
				if not variant then
					return 
				end
				if addon_index ~= our_addon_index or objects_by_type[variant] == nil then
					local local_addon_index = addon_index
					local local_component_index = component_data.id
					function component_data.spawn (position)
						checkArg (1, "position", position, "table")
						local transform = matrix.multiply (position, component_data.transform)
						return server.spawnAddonVehicle (transform, local_addon_index, local_component_index)
					end
					objects_by_type[variant] = component_data
				end
			end
			function m.generateVariantByCategoryMapping (category_tag, default_variant)
				local logger = logger.getSubLogger "generateObjectByTypeMapping"
				local spawn_tag = "spawn_" .. category_tag
				logger.trace ("Begin: (category_tag: '%s', default_variant: '%s') -> spawn_tag", category_tag, default_variant, spawn_tag)
				local objects_by_type = { }
				local our_addon_index = server.getAddonIndex ()
				for addon_index, addon_data in m.iterAddons () do
					for _, location_data in addon_data.iterate () do
						if not location_data.env_mod then
							for _, component_data in location_data.iterate () do
								m.objectByTypeMapping_Component (component_data, spawn_tag, addon_index, our_addon_index, objects_by_type)
							end
						end
					end
				end
				logger.dump ("Done: Mapping for tag: '%s' ('%s') default variant: '%s'\n%s", category_tag, spawn_tag, default_variant, serpentf.block (objects_by_type))
				return objects_by_type
			end
			function m.componentById (addon_index, component_id)
				for location_index in m.iterLocations (addon_index) do
					for component_index, component in m.iterComponents (addon_index, location_index) do
						if component.id == component_id then
							return component, component_index, location_index
						end
					end
				end
				return nil, nil, nil
			end
			return m
		end,
		["lib.addon.player"] = function ()
			local M = { }
			function M.getPlayer (peer_id)
				local players = server.getPlayers ()
				for _, player in pairs (players) do
					if player.id == peer_id then
						return player
					end
				end
			end
			function M.isAdmin (peer_id)
				local player = M.getPlayer (peer_id)
				return player and player.admin
			end
			function M.isAuth (peer_id)
				local player = M.getPlayer (peer_id)
				return player and player.auth
			end
			return M
		end,
		["lib.addon.tag"] = function ()
			local moreString = require "lib.moreString"
			local splitStringOnce = moreString.splitStringOnce
			local m = { }
			function m.hasTag (tags, targetTag)
				for _, tag in ipairs (tags) do
					if tag == targetTag then
						return true
					end
				end
				return false
			end
			function m.parseTags (tags, container)
				for _, tag in ipairs (tags) do
					local k
					local v
					k, v = splitStringOnce (tag, "=")
					if v == nil then
						v = true
					end
					container[k] = v
				end
				return container
			end
			return m
		end,
		["lib.addon.vehicle"] = function ()
			local keyValueParser = require "lib.keyValueParser"
			local m = { }
			function m.getExtendedVehicleData (vehicle_id)
				local vehicle, s = server.getVehicleData (vehicle_id)
				if not vehicle or not s then
					return nil
				end
				vehicle.vehicle_id = vehicle_id
				vehicle.meta = keyValueParser (vehicle.tags_full)
				return vehicle
			end
			return m
		end,
		["lib.addon.wrappers"] = function ()
			local processing = require "lib.addonCallbacks.processing"
			local originals = { }
			for _, n in pairs { "spawnAddonVehicle" } do
				originals[n] = server[n]
			end
			function server.spawnAddonVehicle (transform, addon_index, component_id)
				local id, success = originals.spawnAddonVehicle (transform, addon_index, component_id)
				processing.processCallback ("_onSpawnAddonVehicle", transform, addon_index, component_id, success and id)
				return id, success
			end
		end,
		["lib.addon.zone"] = function ()
			local meta_thisFileRequirePath = "lib.addon.zone"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local keyValueParser = require "lib.keyValueParser"
			local m = { }
			function m.getZones (...)
				local filters = { ... }
				return m.getZonesFromFilterArray (filters)
			end
			function m.getZonesFromFilterArray (filters)
				local initial_result = server.getZones ()
				local result = { }
				for i, zone in ipairs (initial_result) do
					local meta = keyValueParser (zone.tags_full)
					zone.meta = meta
					local skip = false
					for _, filter in pairs (filters) do
						if meta[filter] == nil then
							skip = true
							break
						end
					end
					zone.unique_id = i
					if not skip then
						table.insert (result, zone)
					end
				end
				logger.verbose ("Found %i zones using filter: ['%s'].", # result, table.concat (filters, "', '"))
				return result
			end
			return m
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
		["lib.addonCallbacks.report"] = function ()
			local meta_thisFileRequirePath = "lib.addonCallbacks.report"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local M = { }
			function M.make_summary (options)
				options = options or { }
				local min_average_ms = options.min_average_ms
				local min_nonzero_average_ms = options.min_nonzero_average_ms
				local sort_by = options.sort_by
				local sort_asc = options.sort_asc
				local raw_report = require "lib.addonCallbacks.processing".performance_reports
				local summaries = { }
				for name, data in pairs (raw_report) do
					if options.skip then
						if string.match (name, options.skip) then
							logger.dump ("Skipping due to match: '%s' '%s'", name, options.skip)
							goto continue
						end
					end
					local count = 0
					local nonzero_count = 0
					local total = 0
					local min, max = math.maxinteger, math.mininteger
					for i, value in pairs (data) do
						count = count + 1
						total = total + value
						if 0 < value then
							nonzero_count = nonzero_count + 1
						end
						min = math.min (min, value)
						max = math.max (max, value)
					end
					local average = total / count
					local nonzero_average = (0 < nonzero_count and (total / nonzero_count)) or 0
					if ((not min_average_ms and not min_nonzero_average_ms) or (min_average_ms and min_average_ms < average)) or (min_nonzero_average_ms and min_nonzero_average_ms < nonzero_average) then
						local entry = {
							name = name,
							call_count = count,
							total_ms = total,
							average_ms = average,
							nonzero_average_ms = nonzero_average,
							min_ms = min,
							max_ms = max
						}
						table.insert (summaries, entry)
					end
					::continue::
				end
				if sort_by then
					local c
					if sort_asc then
						function c (a, b)
							return a[sort_by] < b[sort_by]
						end
					else
						function c (a, b)
							return b[sort_by] < a[sort_by]
						end
					end
					table.sort (summaries, c)
				end
				return summaries
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
		["lib.doublyIndexedTable"] = function ()
			local meta_thisFileRequirePath = "lib.doublyIndexedTable"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local serpentf = require "lib.serialization.serpentf"
			local M = { }
			local proto = { }
			function proto:add (o)
				local guid = o[self.guid_key]
				local suid = o[self.suid_key]
				if not guid or not suid then
					self.logger.warning ("Skip add (missing guid or suid) for %s", serpentf.block (o))
					error "Missing guid and/or suid."
					return false
				end
				self.container[guid] = o
				self.suid_to_guid_map[suid] = guid
				self.logger.dump ("Add [%i]<%i>", guid, suid)
				return true
			end
			function proto:remove (o)
				local guid = o[self.guid_key]
				local suid = o[self.suid_key]
				if not guid or not suid then
					self.logger.warning ("Skip remove (missing guid or suid) for %s", serpentf.block (o))
					error "Missing guid and/or suid."
					return false
				end
				self.container[guid] = nil
				self.suid_to_guid_map[suid] = nil
				self.logger.dump ("Remove [%i]<%i>", guid, suid)
				return true
			end
			function proto:change_suid (old_value, new_value)
				local guid = self.suid_to_guid_map[old_value]
				if not guid then
					return false
				end
				self.suid_to_guid_map[old_value] = nil
				self.suid_to_guid_map[new_value] = guid
				return true
			end
			function proto:by_guid (guid)
				local global_result = self.container[guid]
				if not global_result then
					return 
				end
				local suid = global_result[self.suid_key]
				return self.suid_to_guid_map[suid] and self.container[guid]
			end
			function proto:by_suid (suid)
				local guid = self.suid_to_guid_map[suid]
				if not guid then
					return nil
				end
				return self.container[guid]
			end
			function proto:guid_by_suid (suid)
				local o = self:by_suid (suid)
				return o and o[self.guid_key]
			end
			function proto:next (suid)
				if suid and not self.suid_to_guid_map[suid] then
					return nil
				end
				local k, guid = next (self.suid_to_guid_map, suid)
				return k, self:by_guid (guid)
			end
			function proto:iterator ()
				local first = true
				local suid = nil
				return function ()
					if not suid then
						if not first then
							return nil, nil
						end
						suid = next (self.suid_to_guid_map, suid)
					end
					first = false
					local o = self:by_suid (suid)
					if not o then
						return nil, nil
					end
					local return_suid = suid
					suid = next (self.suid_to_guid_map, suid)
					return return_suid, o
				end
			end
			function proto:map_SUID_Object ()
				local r = { }
				for suid, o in self:iterator () do
					r[suid] = o
				end
				return r
			end
			function proto:map_SUID_GUID ()
				local r = { }
				for suid, o in self:iterator () do
					r[suid] = o[self.guid_key]
				end
				return r
			end
			function proto:init ()
				for guid, o in pairs (self.container) do
					local suid = o[self.suid_key]
					if suid then
						self.suid_to_guid_map[suid] = guid
					end
				end
			end
			function M.New (suid_key, guid_key, container, suid_to_guid_map)
				if not suid_key then
					error "Missing argument 3 'suid_key'"
				end
				if not guid_key then
					error "Missing argument 4 'guid_key'"
				end
				local self = { }
				for k, v in pairs (proto) do
					self[k] = v
				end
				self.logger = logger.getSubLogger (string.format ("[%s]<%s>", guid_key, suid_key))
				self.guid_key = guid_key
				self.suid_key = suid_key
				self.container = container or { }
				self.suid_to_guid_map = suid_to_guid_map or { }
				return self
			end
			function M.Restore (instance)
				for k, v in pairs (proto) do
					instance[k] = v
				end
			end
			return M
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
		["lib.legacyCommands.handler"] = function ()
			local meta_thisFileRequirePath = "lib.legacyCommands.handler"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local helpers = require "lib.legacyCommands.helpers"
			local moreTable = require "lib.moreTable"
			local keysToArray = moreTable.keysToArray
			local callbackRegistration = require "lib.addonCallbacks.registration"
			local serpent = require "lib.serialization.serpent"
			local M = { }
			M.commands = { }
			local commandNames = { }
			function M.init ()
				if not M.commandNamespace then
					error "Missing commandNamespace"
				end
				logger.dump ("All command functions: %s", table.concat (keysToArray (M.commands), ", "))
				for name, fn in pairs (M.commands) do
					local lowerName = string.lower (name)
					M.commands[lowerName] = fn
					table.insert (commandNames, name)
				end
			end
			function M.invokeCommandContext (context)
				local logger = logger.getSubLogger "onCommand"
				logger.dump ("onCustomCommand", serpent.block (context))
				if not context.command then
					context.announce ("Missing subcommand", "Missing subcommand, possible subcommands are:\n" .. table.concat (commandNames, ", "))
					return 
				end
				local commandInstance = M.commands[context.command]
				if not commandInstance then
					context.announce ("Unknown command", "Unknown command '%s'", context.commandRaw)
					return 
				end
				local title, message
				if (xpcall and debug) and debug.traceback then
					local success, xpcall_error
					success, title, message = xpcall (commandInstance, debug.traceback, context)
					xpcall_error = title
					if not success then
						logger.critical ("Error executing command for [%i]: %s\nError: %s", context.user_peer_id, context.full_message, xpcall_error)
						message = (title and tostring (title)) or "Unknown error"
						title = string.format ("Uncaught Error in command '%s'", context.commandRaw)
						message = string.format ("Full command: %s\n%s", serpent.line (context.full_message), message)
					end
				else
					title, message = commandInstance (context)
				end
				if title and message then
					context.announce (title, message)
					logger.debug ("%s: %s", title, message)
				end
			end
			function M.handleCommand (full_message, user_peer_id, is_admin, is_auth, namespace, command, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16)
				if namespace ~= M.commandNamespace then
					return 
				end
				local context = helpers.create_CommandInvocationContext (full_message, user_peer_id, is_admin, is_auth, namespace, command, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16)
				M.invokeCommandContext (context)
			end
			callbackRegistration.registerCallback ("onCustomCommand", meta_thisFileRequirePath, M.handleCommand)
			return M
		end,
		["lib.legacyCommands.helpers"] = function ()
			local meta_thisFileRequirePath = "lib.legacyCommands.helpers"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local moreString = require "lib.moreString"
			local splitOnSpacesPreserveQuoted = moreString.splitOnSpacesPreserveQuoted
			local M = { }
			function M.create_CommandInvocationContext (full_message, user_peer_id, is_admin, is_auth, namespace, command, arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16)
				local player_name, s = server.getPlayerName (user_peer_id)
				if not s then
					player_name = nil
				end
				local context = {
					full_message = full_message,
					user_peer_id = user_peer_id,
					user_name = player_name,
					is_admin = is_admin,
					is_auth = is_auth,
					namespace = string.lower (string.sub (namespace, 2)),
					commandRaw = command,
					command = string.lower (command),
					args = {
						arg0,
						arg1,
						arg2,
						arg3,
						arg4,
						arg5,
						arg6,
						arg7,
						arg8,
						arg9,
						arg10,
						arg11,
						arg12,
						arg13,
						arg14,
						arg15,
						arg16
					},
					argsQ = splitOnSpacesPreserveQuoted (string.sub (full_message, (# namespace + # command) + 3))
				}
				function context.announce (title, format, ...)
					logger.info ("Command announce: [%s] " .. format, title, ...)
					if user_peer_id < 0 then
						return 
					end
					server.announce (title, string.format (format, ...), user_peer_id)
				end
				function context.notify (notification_type, title, format, ...)
					logger.info ("Command notify: [%s] " .. format, title, ...)
					if user_peer_id < 0 then
						return 
					end
					server.notify (user_peer_id, title, string.format (format, ...), notification_type)
				end
				function context.adminGate ()
					return M.complain_if_not_admin (context)
				end
				function context.authGate ()
					return M.complain_if_not_auth (context)
				end
				function context.silentAdminGate ()
					logger.important ("Silently denying non-admin player '%s' (%i) access to command: %s", context.user_name, context.user_peer_id, context.full_message)
					return not context.is_admin
				end
				function context.silentAuthGate ()
					logger.important ("Silently denying non-auth player '%s' (%i) access to command: %s", context.user_name, context.user_peer_id, context.full_message)
					return not context.is_auth
				end
				return context
			end
			function M.complain_if_not_admin (context)
				if context.is_admin then
					return false
				end
				context.announce ("Not Admin", "You don't have access to the '%s' command!", context.command)
				return true
			end
			function M.complain_if_not_auth (context)
				if context.is_admin then
					return false
				end
				context.announce ("Not Authorized", "You don't have access to the '%s' command!", context.command)
				return true
			end
			return M
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
		["lib.moreMath"] = function ()
			local function round (v)
				return math.floor (v + 0.5)
			end
			local function tointeger (str)
				local number = tonumber (str)
				if not number then
					return nil
				end
				local integer = round (number)
				if number ~= integer then
					return nil
				end
				return integer
			end
			local function lerp (start, finish, t)
				t = math.max (0, math.min (1, t))
				return start + (finish - start) * t
			end
			local function clamp (v, lb, ub)
				return math.min (math.max (v, lb), ub)
			end
			local function remap (value, oldMin, oldMax, newMin, newMax)
				value = clamp (value, oldMin, oldMax)
				return ((value - oldMin) / (oldMax - oldMin)) * (newMax - newMin) + newMin
			end
			local function percentile (data, percentile)
				if not data or # data == 0 then
					error "Data range cannot be empty"
				end
				table.sort (data)
				local k = (percentile / 100) * (# data - 1) + 1
				local f = math.floor (k)
				local c = math.ceil (k)
				if f == c then
					return data[f]
				else
					local d0 = data[f] * (c - k)
					local d1 = data[c] * (k - f)
					return d0 + d1
				end
			end
			return {
				round = round,
				tointeger = tointeger,
				lerp = lerp,
				clamp = clamp,
				remap = remap,
				percentile = percentile
			}
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
		["lib.persistenceHelper"] = function ()
			local meta_thisFileRequirePath = "lib.persistenceHelper"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local libDoublyIndexedTable = require "lib.doublyIndexedTable"
			local libSaveData = require "lib.saveData"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local M = { }
			local all_wrappers = { }
			function M.createWrapper (container, lookup, lookup_key, primary_key)
				primary_key = primary_key or "UID"
				local t = libDoublyIndexedTable.New (lookup_key, primary_key, container, lookup)
				table.insert (all_wrappers, t)
				return t
			end
			function M.createWrapperWithBackingContainer (container_specification, primary_key, lookup_key)
				local container = libSaveData.register (container_specification)
				local wrapper = M.createWrapper (container, { }, lookup_key, primary_key)
				wrapper["by_" .. string.lower (primary_key)] = wrapper.by_guid
				wrapper["by_" .. string.lower (lookup_key)] = wrapper.by_suid
				return container, wrapper
			end
			local function m_onSaveDataLoaded ()
				logger.debug "Starting persistence wrapper init."
				for _, w in pairs (all_wrappers) do
					w:init ()
				end
				logger.debug "Completed persistence wrapper init."
			end
			addonCallbacks.registerCallback ("onSaveDataLoaded", meta_thisFileRequirePath, m_onSaveDataLoaded)
			return M
		end,
		["lib.prng"] = function ()
			local prng = require "lib.prng.implementation"
			local floor = math.floor
			local function remap (v, a, b, x, y)
				return (((v - a) * (y - x)) / (b - a)) + x
			end
			local M = { }
			local function range_wrapper (v, m, n)
				if m and not n then
					return floor (remap (v, 0, 4294967295, 1, m))
				elseif m and n then
					return floor (remap (v, 0, 4294967295, m, n))
				else
					return remap (v, 0, 4294967295, 0, 1)
				end
			end
			function M.Create (seed)
				return M.CreateOrDeserialize (nil, seed)
			end
			function M.CreateOrDeserialize (maybe_instance, initial_seed)
				maybe_instance = maybe_instance or { }
				maybe_instance.state = (maybe_instance.state or initial_seed) or 0
				local r = maybe_instance
				function r.next (m, n)
					local v = r.next_u32 ()
					return range_wrapper (v, m, n)
				end
				function r.next_u32 ()
					prng.set_seed (r.state)
					local v = prng.get_random_32 ()
					r.state = prng.get_seed ()
					return v
				end
				function r.shuffle (tbl)
					prng.set_seed (r.state)
					for i = # tbl, 2,  - 1 do
						local j = range_wrapper (prng.get_random_32 (), i)
						tbl[i], tbl[j] = tbl[j], tbl[i]
					end
					r.state = prng.get_seed ()
				end
				return r
			end
			return M
		end,
		["lib.prng.implementation"] = function ()
			local set_seed, get_seed, get_random_32
			do
				local secret_key_6 = 58
				local secret_key_7 = 110
				local secret_key_44 = 3580861008710
				local floor = math.floor
				local function primitive_root_257 (idx)
					local g, m, d = 1, 128, 2 * idx + 1
					repeat
						g, m, d = ((g * g) * ((m <= d and 3) or 1)) % 257, m / 2, d % m
					until m < 1
					return g
				end
				local param_mul_8 = primitive_root_257 (secret_key_7)
				local param_mul_45 = secret_key_6 * 4 + 1
				local param_add_45 = secret_key_44 * 2 + 1
				local state_45 = 0
				local state_8 = 2
				function set_seed (seed_53)
					state_45 = seed_53 % 35184372088832
					state_8 = floor (seed_53 / 35184372088832) % 255 + 2
				end
				function get_seed ()
					return (state_8 - 2) * 35184372088832 + state_45
				end
				function get_random_32 ()
					state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
					repeat
						state_8 = (state_8 * param_mul_8) % 257
					until state_8 ~= 1
					local r = state_8 % 32
					local n = (floor (state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32) / 2 ^ r
					return floor ((n % 1) * 2 ^ 32) + floor (n)
				end
			end
			local lib = { }
			lib.set_seed = set_seed
			lib.get_seed = get_seed
			lib.get_random_32 = get_random_32
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
		["lib.saveData"] = function ()
			local meta_thisFileRequirePath = "lib.saveData"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local config = require "config"
			local save_data_version = config.save_data_version
			local checkArg = require "lib.checkArg"
			local moreTable = require "lib.moreTable"
			local clearTable = moreTable.clearTable
			local lib = { }
			local accepting_registrations = true
			local specifications = { }
			local persistent = { }
			lib.persistent = persistent
			local function load_spec (spec)
				local logger = logger.getSubLogger "load_spec"
				logger.trace ("Loading spec '%s'...", spec.key)
				local loaded_data = g_savedata[spec.key] or { }
				local existing_container = spec.value
				local load_counter, merge_counter, transformed_counter, splat_counter = 0, 0, 0, 0
				for k, loaded in pairs (loaded_data) do
					local preExisting = existing_container[k]
					if preExisting and spec.merge_fn then
						local result = spec.merge_fn (preExisting, loaded)
						if result == nil then
							error (string.format ("Error in merge_fn for spec '%s': the merge_fn returned nil for key %s", spec.key, tostring (k)))
						end
						existing_container[k] = result
						merge_counter = merge_counter + 1
					else
						existing_container[k] = loaded
						splat_counter = splat_counter + 1
					end
					load_counter = load_counter + 1
				end
				g_savedata[spec.key] = existing_container
				if spec.load_fn then
					for _, v in pairs (existing_container) do
						spec.load_fn (v)
						transformed_counter = transformed_counter + 1
					end
				end
				if spec.loaded then
					spec.loaded (existing_container)
				end
				persistent[spec.key] = existing_container
				spec.is_loaded = true
				logger.dump ("loaded %i entries (of which %i merged, %i splatted). %i transformed.", load_counter, merge_counter, splat_counter, transformed_counter)
				return load_counter, merge_counter, splat_counter, transformed_counter
			end
			function lib.register (descriptor)
				local logger = logger.getSubLogger "register"
				if not accepting_registrations then
					error "Not accepting registrations."
				end
				checkArg (1, "descriptor", descriptor, "table")
				checkArg (1, "descriptor.key", descriptor.key, "string")
				if specifications[descriptor.key] then
					error (string.format ("PersistenceDescriptor with key '%s' already exists, the key must be unique.", descriptor.key), 2)
				end
				descriptor.value = descriptor.value or { }
				specifications[descriptor.key] = descriptor
				persistent[descriptor.key] = descriptor.value
				logger.info ("Registered '%s' for persistence.", descriptor.key)
				return descriptor.value
			end
			function lib.get (key)
				local logger = logger.getSubLogger "get"
				logger.dump ("get(%s)", key)
				checkArg (1, "key", key, "string")
				local spec = specifications[key] or error (string.format ("There is no persistent data registered for '%s'. You may need to require the module that defines it.", key), 2)
				local data = spec.value
				logger.dump ("is_loaded %s", tostring (spec.is_loaded))
				if not spec.is_loaded then
					logger.verbose ("Late-Loading %s", key)
					load_spec (spec)
				end
				return data
			end
			function lib.closeRegistrations ()
				accepting_registrations = false
			end
			function lib.reset ()
				accepting_registrations = true
				clearTable (specifications)
				clearTable (persistent)
			end
			function lib.load ()
				local logger = logger.getSubLogger "load"
				g_savedata = g_savedata or { }
				g_savedata.data_version = save_data_version
				local spec_counter = 0
				local merge_counter = 0
				local load_counter = 0
				local splat_counter = 0
				local transformed_counter = 0
				for _, spec in pairs (specifications) do
					spec_counter = spec_counter + 1
					local l, m, s, t = load_spec (spec)
					load_counter = load_counter + l
					merge_counter = merge_counter + m
					splat_counter = splat_counter + s
					transformed_counter = transformed_counter + t
				end
				logger.info ("Done loading persistent data, %i entries processed. %i instances loaded (of which %i merged, %i splatted). %i instances transformed.", spec_counter, load_counter, merge_counter, splat_counter, transformed_counter)
				logger.debug "Dispatching callback 'onSaveDataLoaded'..."
				require "lib.addonCallbacks.processing".processCallback "onSaveDataLoaded"
			end
			local function m_onCreate ()
				lib.load ()
			end
			addonCallbacks.registerCallback ("onCreate", meta_thisFileRequirePath, m_onCreate)
			return lib
		end,
		["lib.scoop.classes.SCOOP_Object"] = function ()
			local libScoop = require "lib.scoop.lib"
			local classInitializer = libScoop._classInitializer
			local scoopObjectPrototype = {
				__type = "SCOOP_Object",
				__parent_prototype__ = nil
			}
			libScoop.registerClass (scoopObjectPrototype)
			function scoopObjectPrototype.New (instance)
				return classInitializer (scoopObjectPrototype, instance)
			end
			function scoopObjectPrototype:proto ()
				return libScoop.typeNameToPrototypeMap[self.__type]
			end
			function scoopObjectPrototype:parent_proto ()
				return libScoop.typeNameToPrototypeMap[self.__type].__parent_prototype__
			end
			return scoopObjectPrototype
		end,
		["lib.scoop.classes.VehicleBoundObject"] = function ()
			require "lib.scoop.classes.VehicleBoundObject.events"
			require "lib.scoop.classes.VehicleBoundObject.registration"
			require "lib.scoop.classes.VehicleBoundObject.disappear_handling"
			return require "lib.scoop.classes.VehicleBoundObject.class"
		end,
		["lib.scoop.classes.VehicleBoundObject.class"] = function ()
			local meta_thisFileRequirePath = "lib.scoop.classes.VehicleBoundObject.class"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local libAddonVehicle = require "lib.addon.vehicle"
			local moreTable = require "lib.moreTable"
			local executeAtTick = require "lib.executeAtTick"
			local libScoop = require "lib.scoop.lib"
			local classInitializer = libScoop._classInitializer
			local config = require "RailroadSignals.config"
			local vec = require "lib.vector3"
			local scoopObjectPrototype = require "lib.scoop.classes.SCOOP_Object"
			local proto = {
				__type = "VehicleBoundObject",
				__parent_prototype__ = scoopObjectPrototype
			}
			libScoop.registerClass (proto)
			function proto.New (overrides)
				return classInitializer (proto, overrides)
			end
			function proto:constructor ()
				if self.vehicle_id then
					logger.trace ("Constructing VehicleBoundObject: '%s' tracking vehicle_id %i", self:proto ().__type, self.vehicle_id)
				else
					logger.trace "No vehicle_id given at construction time!"
				end
			end
			function proto:onVehicleSpawn (vehicle_id, spawned_by_peer_id, x, y, z, cost)
				local logger = logger.getMethodLogger ("onVehicleSpawn", self.vehicle_id)
				self.vehicle_id = vehicle_id
				self.is_spawned = true
				self.spawn_pos = vec.New (x, y, z)
				self.spawned_by_peer_id = spawned_by_peer_id
				self.spawn_cost = cost
				local vehicle = libAddonVehicle.getExtendedVehicleData (vehicle_id)
				if not vehicle then
					return error "Did not get vehicle data."
				end
				self.group_id = vehicle.group_id
				logger.debug ("Connecting vehicle_id %i to group_id %i", vehicle_id, self.group_id)
				self.meta = moreTable.mergeTableShallow (self.meta or { }, vehicle.meta)
			end
			local function computeCenterOfMassOffset (self)
				local logger = logger.getSubLogger "COM_offset"
				local tc, s = server.getVehiclePos (self.vehicle_id)
				if not tc or not s then
					logger.error ("Failed to retrieve position from vehicle_id: " .. self.vehicle_id)
					return 
				end
				local to, s = server.getVehiclePos (self.vehicle_id, 0, 0, 0)
				if not tc or not s then
					logger.error ("Failed to retrieve position from vehicle_id: " .. self.vehicle_id)
					return 
				end
				local vc = vec.Position_From_ArrayMatrix (tc)
				local vo = vec.Position_From_ArrayMatrix (to)
				local delta = vec.Sub (vc, vo)
				logger.dump ("Center of mass offset: %s (using com_pos: %s and origin_pos: %s)", vec.ToString (delta), vec.ToString (vc), vec.ToString (vo))
				local deltaMag = vec.Len (delta)
				if deltaMag < 0.001 then
					
				end
				self.com_pos = delta
				self:onCenterOfMassOffsetKnown ()
			end
			function proto:onFirstLoad ()
				local logger = logger.getMethodLogger ("onFirstLoad", self.vehicle_id)
				logger.trace "."
				self.is_loaded_ever = true
				local t, s = server.getVehiclePos (self.vehicle_id)
				if (not self.spawn_pos and t) and s then
					self.spawn_pos = vec.Position_From_ArrayMatrix (t)
					logger.debug ("Using onFirstLoad position: %s as spawn_pos.", vec.ToString (self.spawn_pos))
				end
				local function f ()
					computeCenterOfMassOffset (self)
				end
				executeAtTick.executeAfterTicks (10, f)
			end
			function proto:onCenterOfMassOffsetKnown ()
				
			end
			function proto:onVehicleLoad ()
				local logger = logger.getMethodLogger ("onVehicleLoad", self.vehicle_id)
				logger.trace "."
				self.is_loaded = true
				if not self.is_loaded_ever then
					self:onFirstLoad ()
				end
				self.just_loaded = true
				local delay_ticks = config.vehicle_objects.just_loaded_duration_ticks
				local function f ()
					self.just_loaded = false
					self._just_loaded_token = nil
				end
				self._just_loaded_token = executeAtTick.executeAfterTicks (delay_ticks, f)
			end
			function proto:onVehicleUnload ()
				local logger = logger.getMethodLogger ("onVehicleUnload", self.vehicle_id)
				logger.trace "."
				self.is_loaded = false
				self.just_loaded = false
				if self._just_loaded_token then
					executeAtTick.cancelExecuteAtTick (self._just_loaded_token)
					self._just_loaded_token = nil
				end
			end
			function proto:onVehicleDespawn ()
				local logger = logger.getMethodLogger ("onVehicleDespawn", self.vehicle_id)
				logger.trace "."
				self.is_spawned = false
				self.vehicle_id = nil
			end
			function proto:transform (voxel_offset)
				local t, s
				if voxel_offset then
					t, s = server.getVehiclePos (self.vehicle_id, voxel_offset.x, voxel_offset.y, voxel_offset.z)
				else
					t, s = server.getVehiclePos (self.vehicle_id)
				end
				if not s then
					local logger = logger.getMethodLogger ("transform", self.vehicle_id)
					logger.error ("Failed to retrieve transform for vehicle_id: %i", self.vehicle_id)
				end
				return t
			end
			function proto:position (transform, voxel_offset)
				local t = (not voxel_offset and transform) or self:transform (voxel_offset)
				return vec.Position_From_ArrayMatrix (t)
			end
			function proto:onDisappeared ()
				
			end
			function proto:onRespawned (vehicle_id)
				self.vehicle_id = vehicle_id
			end
			function proto:getButton (name)
				local data, success = server.getVehicleButton (self.vehicle_id, name)
				return (success and data) or nil
			end
			function proto:pressButton (name)
				server.pressVehicleButton (self.vehicle_id, name)
			end
			function proto:setToggleButton (name, value)
				local current = self:getButton (name)
				if not current then
					return nil
				end
				if current.on == value then
					return false
				end
				self:pressButton (name)
				return true
			end
			function proto:getDial (name)
				local result, success = server.getVehicleDial (self.vehicle_id, name)
				return (success and result) or nil
			end
			return proto
		end,
		["lib.scoop.classes.VehicleBoundObject.disappear_handling"] = function ()
			local meta_thisFileRequirePath = "lib.scoop.classes.VehicleBoundObject.disappear_handling"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local config = require "config"
			local serpentf = require "lib.serialization.serpentf"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local registration = require "lib.scoop.classes.VehicleBoundObject.registration"
			local vo
			local function m_onCreate ()
				vo = require "lib.vehicleObjects"
			end
			addonCallbacks.registerCallback ("onCreate", meta_thisFileRequirePath, m_onCreate)
			local iterator
			local function is_eligible (vbo)
				return (((vbo and vbo.disappear_detection) and not vbo.is_disappeared) and vbo.is_spawned) and vbo.vehicle_id
			end
			local fake_context = { }
			local function do_respawn (vbo)
				logger.trace ("Trying to respawn %s with old_vehicle_id %i...", vbo.__type, vbo.vehicle_id)
				local old_vehicle_id = vbo.vehicle_id
				local category = vbo.category or vbo.tag
				if not category then
					logger.warning ("Unable to respawn %s with vehicle_id %i because it does not have a category / tag", vbo.__type, old_vehicle_id)
					return 
				end
				local spec = vo.findSpawnCategory (category)
				if not spec then
					logger.warning ("Unable to respawn %s with vehicle_id %i because no specification was found for its category '%s'.", vbo.__type, old_vehicle_id, category)
					return 
				end
				local zone = vbo.zone
				if not zone then
					logger.warning ("Unable to respawn %s with vehicle_id %i because no zone was found.", vbo.__type, old_vehicle_id)
					return 
				end
				local variant = zone.meta[category]
				local transform = vo.get_spawn_transform (fake_context, zone)
				local prefab, _ = vo.getPrefabAndSource (variant, spec.default_variant, spec.variants_by_category)
				if not prefab then
					logger.warning ("Unable to respawn %s with vehicle_id %i because no prefab was found for variant '%s'.", vbo.__type, old_vehicle_id, variant)
					return 
				end
				local vehicle_id, success = prefab.spawn (transform)
				if not success or not vehicle_id then
					logger.error ("Error spawning %s - spawn not success.", category:gsub ("_", " "))
					logger.dump ("Zone data: %s", serpentf.block (zone))
					return 
				end
				vbo.is_disappeared = false
				if vbo.onRespawned then
					logger.trace ("Invoking onRespawned for %s (vehicle_id %i replaced by %i)", vbo.__type, old_vehicle_id, vehicle_id)
					vbo:onRespawned (vehicle_id)
				end
				vbo.vehicle_id = vehicle_id
				local success = registration.replaceVehicleID (old_vehicle_id, vehicle_id)
				if not success then
					logger.warning "Failed to update vehicle_id to the new value in lookup."
				end
				logger.trace ("Respawned: %s (vehicle_id %i replaced by %i)", vbo.__type, old_vehicle_id, vehicle_id)
			end
			local function detect (now, vbo)
				local data, found = server.getVehicleData (vbo.vehicle_id)
				if data and found then
					vbo.disappear_detection_last_seen = now
					return 
				end
				if vbo.is_disappeared then
					return 
				end
				vbo.is_disappeared = true
				local last_seen_at = vbo.disappear_detection_last_seen
				if not last_seen_at then
					logger.warning ("Detected %s (vehicle_id %i) missing but was never seen before. The last seen time will be set to now.", vbo.__type, vbo.vehicle_id)
					vbo.disappear_detection_last_seen = now
				else
					local elapsed = (now - last_seen_at) / 1000
					logger.warning ("Detected %s (vehicle_id %i) went missing! It was last seen %.1fs ago.", vbo.__type, vbo.vehicle_id, elapsed)
					if vbo.onDisappeared then
						logger.trace ("Invoking onDisappeared for %s with vehicle_id %i", vbo.__type, vbo.vehicle_id)
						vbo:onDisappeared ()
					end
					if vbo.disappear_respawn and config.vehicle_objects.disappear_mitigation.allow_respawn then
						do_respawn (vbo)
					end
				end
			end
			local function m_onTick ()
				local items_per_tick = config.vehicle_objects.disappear_mitigation.items_per_tick
				if items_per_tick < 1 then
					return 
				end
				iterator = iterator or registration.iterator ()
				local now = server.getTimeMillisec ()
				local count = 0
				for _ = 1, items_per_tick do
					local vbo = iterator ()
					if not vbo then
						iterator = nil
						break
					end
					if is_eligible (vbo) then
						detect (now, vbo)
					end
					count = count + 1
				end
			end
			addonCallbacks.registerCallback ("onTick", meta_thisFileRequirePath, m_onTick)
		end,
		["lib.scoop.classes.VehicleBoundObject.events"] = function ()
			local meta_thisFileRequirePath = "lib.scoop.classes.VehicleBoundObject.events"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local registration = require "lib.scoop.classes.VehicleBoundObject.registration"
			local getObject = registration.getByVehicleID
			local m = { }
			local function myLog (event_name, collection_name, guid_key_name, guid_key_value, vehicle_id)
				logger.debug ("Dispatching %s to %s with %s %s and vehicle_id %i", event_name, collection_name, guid_key_name, guid_key_value, vehicle_id)
			end
			local function m_onVehicleSpawn (vehicle_id, spawned_by_peer_id, x, y, z, cost)
				local obj, collection_name, guid_key_name, guid_key_value = getObject (vehicle_id)
				if not obj then
					return 
				end
				myLog ("onVehicleSpawn", collection_name, guid_key_name, guid_key_value, vehicle_id)
				obj:onVehicleSpawn (vehicle_id, spawned_by_peer_id, x, y, z, cost)
			end
			addonCallbacks.registerCallback ("onVehicleSpawn", meta_thisFileRequirePath, m_onVehicleSpawn)
			local function m_onVehicleLoad (vehicle_id)
				local obj, collection_name, guid_key_name, guid_key_value = getObject (vehicle_id)
				if not obj then
					return 
				end
				myLog ("onVehicleLoad", collection_name, guid_key_name, guid_key_value, vehicle_id)
				obj:onVehicleLoad ()
			end
			addonCallbacks.registerCallback ("onVehicleLoad", meta_thisFileRequirePath, m_onVehicleLoad)
			local function m_onVehicleUnload (vehicle_id)
				local obj, collection_name, guid_key_name, guid_key_value = getObject (vehicle_id)
				if not obj then
					return 
				end
				myLog ("onVehicleUnload", collection_name, guid_key_name, guid_key_value, vehicle_id)
				obj:onVehicleUnload ()
			end
			addonCallbacks.registerCallback ("onVehicleUnload", meta_thisFileRequirePath, m_onVehicleUnload)
			local function m_onVehicleDespawn (vehicle_id)
				local obj, collection_name, guid_key_name, guid_key_value = getObject (vehicle_id)
				if not obj then
					return 
				end
				myLog ("onVehicleDespawn", collection_name, guid_key_name, guid_key_value, vehicle_id)
				obj:onVehicleDespawn ()
			end
			addonCallbacks.registerCallback ("onVehicleDespawn", meta_thisFileRequirePath, m_onVehicleDespawn)
			return m
		end,
		["lib.scoop.classes.VehicleBoundObject.registration"] = function ()
			local meta_thisFileRequirePath = "lib.scoop.classes.VehicleBoundObject.registration"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local m = { }
			local doublyIndexedTables = { }
			m._doublyIndexedTables = doublyIndexedTables
			function m.registerDoublyIndexedTable (key, container)
				doublyIndexedTables[key] = container
				logger.info ("Registering Container '%s'", key)
			end
			function m.getByVehicleID (vehicle_id)
				for collection_name, collection in pairs (doublyIndexedTables) do
					local obj = collection:by_vehicle_id (vehicle_id)
					if obj then
						local guid_key_name = collection.guid_key
						local guid_key_value = obj[guid_key_name]
						return obj, collection_name, guid_key_name, guid_key_value
					end
				end
				return nil
			end
			function m.replaceVehicleID (old_vehicle_id, new_vehicle_id)
				local obj, collection_name, _, _ = m.getByVehicleID (old_vehicle_id)
				if not obj then
					return false
				end
				local collection = doublyIndexedTables[collection_name]
				if not collection then
					error "wtf"
				end
				return collection:change_suid (old_vehicle_id, new_vehicle_id)
			end
			function m.iterator ()
				local container_index = next (doublyIndexedTables)
				local iterator
				local function f ()
					local container = doublyIndexedTables[container_index]
					if not iterator then
						iterator = container:iterator ()
					end
					local _, object = iterator ()
					if not object then
						iterator = nil
						container_index = next (doublyIndexedTables, container_index)
						if not container_index then
							return nil
						end
						return f ()
					end
					return object, container_index
				end
				return f
			end
			return m
		end,
		["lib.scoop.lib"] = function ()
			local meta_thisFileRequirePath = "lib.scoop.lib"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local moreTable = require "lib.moreTable"
			local copyTableShallow = moreTable.copyTableShallow
			local mergeTableShallow = moreTable.mergeTableShallow
			local lib = { }
			local classInitializer_IgnoreKeys = {
				New = true,
				__parent_prototype__ = true,
				__additional_ignore_keys = true,
				__set_allowed_keys = true
			}
			local classInitializer_createShallowCopyFor = { }
			function lib.createNewTableForEachInstance (data)
				data = data or { }
				if classInitializer_createShallowCopyFor[data] then
					logger.warning ("Encountered duplicate data for createNewTableForEachInstance: %s", tostring (data))
				end
				classInitializer_createShallowCopyFor[data] = true
				return data
			end
			local function callConstructors (proto, instance)
				local logger = logger.getSubLogger "callConstructors"
				logger.trace ("Begin %s", proto.__type)
				if proto.__parent_prototype__ then
					logger.trace ("Recurse %s --> %s", proto.__type, proto.__parent_prototype__.__type)
					callConstructors (proto.__parent_prototype__, instance)
				end
				if proto.constructor then
					logger.trace ("Invoke %s", proto.__type)
					proto.constructor (instance)
				end
				logger.trace ("End %s", proto.__type)
			end
			local function classInitializer (prototype, overrides, instance, context)
				instance = instance or { }
				local is_root = not context
				context = context or { }
				if prototype.__additional_ignore_keys then
					context.additional_ignore_keys = mergeTableShallow (context.additional_ignore_keys or { }, prototype.__additional_ignore_keys)
				end
				if prototype.__parent_prototype__ then
					classInitializer (prototype.__parent_prototype__, nil, instance, context)
				end
				for k, v in pairs (prototype) do
					if not classInitializer_IgnoreKeys[k] and not (context.additional_ignore_keys and context.additional_ignore_keys[k]) then
						if classInitializer_createShallowCopyFor[v] then
							instance[k] = copyTableShallow (v)
						else
							instance[k] = v
						end
					end
				end
				if overrides then
					for k, v in pairs (overrides) do
						instance[k] = v
					end
				end
				if is_root then
					callConstructors (prototype, instance)
				end
				return instance
			end
			lib._classInitializer = classInitializer
			local function oopType (v)
				local t = type (v)
				if t ~= "table" then
					return t
				end
				return v.__type or t
			end
			lib.oopType = oopType
			local function isOopType (v)
				local t = oopType (v)
				local p = lib.typeNameToPrototypeMap[t]
				return (p and true) or false
			end
			lib.isOopType = isOopType
			local function getPrototype (v)
				local t = oopType (v)
				local p = lib.typeNameToPrototypeMap[t]
				return p
			end
			lib.getPrototype = getPrototype
			local typeNameToPrototypeMap = { }
			lib.typeNameToPrototypeMap = typeNameToPrototypeMap
			lib.classes = typeNameToPrototypeMap
			function lib.registerClass (proto)
				typeNameToPrototypeMap[proto.__type] = proto
			end
			local function deserializeClassMethods (instance, proto)
				for _, v in pairs (instance) do
					local v_proto = getPrototype (v)
					if v_proto then
						deserializeClassMethods (v, v_proto)
					end
				end
				if proto then
					deserializeClassMethods (instance, proto.__parent_prototype__ or false)
					for k, v in pairs (proto) do
						if type (v) == "function" then
							instance[k] = v
						end
					end
					return instance
				elseif proto == false then
					return instance
				end
				local basePrototype = getPrototype (instance)
				return deserializeClassMethods (instance, basePrototype or false)
			end
			lib.deserializeClassMethods = deserializeClassMethods
			local function stripClassMethods (instance, proto)
				for _, v in pairs (instance) do
					local v_proto = getPrototype (v)
					if v_proto then
						stripClassMethods (v, v_proto)
					end
				end
				if proto then
					stripClassMethods (instance, proto.__parent_prototype__ or false)
					for k, v in pairs (proto) do
						if type (v) == "function" then
							instance[k] = nil
						end
					end
					return instance
				elseif proto == false then
					return instance
				end
				local oopType = oopType (instance)
				local basePrototype = typeNameToPrototypeMap[oopType]
				return stripClassMethods (instance, basePrototype or false)
			end
			lib.stripClassMethods = stripClassMethods
			return lib
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
		["lib.serialization.serpentf"] = function ()
			local serpent = require "lib.serialization.serpent"
			local M = { }
			for k, v in pairs (serpent) do
				M[k] = v
			end
			function M.load (data, opts)
				return function ()
					return serpent.load (data, opts)
				end
			end
			function M.serialize (data, opts)
				return function ()
					return serpent.serialize (data, opts)
				end
			end
			function M.dump (data, opts)
				return function ()
					return serpent.dump (data, opts)
				end
			end
			function M.line (data, opts)
				return function ()
					return serpent.line (data, opts)
				end
			end
			function M.block (data, opts)
				return function ()
					return serpent.block (data, opts)
				end
			end
			return M
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
		["lib.uid"] = function ()
			local meta_thisFileRequirePath = "lib.uid.init"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local libSaveData = require "lib.saveData"
			local function merge_fn (existing, loaded)
				logger.verbose ("Merging uid_generator '%s'", existing.key or loaded.key)
				for k, lv in pairs (loaded) do
					local ev = existing[k]
					if type (ev) == "function" then
						
					else
						logger.dump ("[%s] old: %s | new: %s", k, tostring (ev), tostring (lv))
						existing[k] = lv
					end
				end
				return existing
			end
			local states = libSaveData.register {
				key = "uid_states",
				merge_fn = merge_fn
			}
			logger.debug ("Received uid_states %s from saveData", tostring (states))
			local cod_standard = require "lib.uid.standard"
			local cod_shuffle = require "lib.uid.shuffle"
			local lib = { }
			function lib.getStandard (key)
				local existing_state = states[key]
				if existing_state and existing_state.next then
					logger.trace ("Providing existing 'Standard' UID generator '%s'", key)
				elseif existing_state then
					logger.trace ("Reviving existing 'Standard' UID generator '%s'", key)
				else
					logger.trace ("Creating fresh 'Standard' UID generator '%s'.", key)
				end
				local v = cod_standard (existing_state)
				v.key = key
				states[key] = v
				return v
			end
			function lib.getShuffle (key, seed, range_start, range_end)
				local existing_state = states[key]
				if existing_state and existing_state.next then
					logger.trace ("Providing existing 'Shuffle' UID generator '%s'", key)
				elseif existing_state then
					logger.trace ("Reviving existing 'Shuffle' UID generator '%s'", key)
				else
					logger.trace ("Creating fresh 'Shuffle' UID generator '%s'.", key)
				end
				local v = cod_shuffle (existing_state, seed, range_start, range_end)
				v.key = key
				states[key] = v
				return v
			end
			return lib
		end,
		["lib.uid.shuffle"] = function ()
			local moreMath = require "lib.moreMath"
			local round = moreMath.round
			local prngLib = require "lib.prng"
			local function make_sequence (seed, range_start, range_end)
				local sequence = { }
				for v = range_start, range_end do
					table.insert (sequence, v)
				end
				local rng = prngLib.Create (seed)
				rng.shuffle (sequence)
				local function get_sequence ()
					return sequence
				end
				return get_sequence
			end
			local function create_or_deserialize (maybe_state, seed, range_start, range_end)
				local s = maybe_state or { }
				if ((s.range_start and s.range_start ~= range_start) or (s.range_end and s.range_end ~= range_end)) or (s.seed and s.seed ~= seed) then
					error "Changing the range bounds or seed is not supported."
				end
				s.range_start = s.range_start or range_start
				s.range_end = s.range_end or range_end
				s.range_size = range_end - range_start
				s.seed = s.seed or seed
				s.index = s.index or 1
				s.sequence = make_sequence (s.seed, s.range_start, s.range_end)
				function s.peek ()
					local index = s.index
					local range_size = s.range_size
					local v
					if index <= range_size then
						v = s.sequence ()[index]
					else
						v = s.range_end + (index - range_size)
					end
					return round (v)
				end
				function s.next ()
					local v = s.peek ()
					s.index = s.index + 1
					return v
				end
				function s.reset ()
					s.index = 1
				end
				return s
			end
			return create_or_deserialize
		end,
		["lib.uid.standard"] = function ()
			local moreMath = require "lib.moreMath"
			local round = moreMath.round
			local function create_or_deserialize (maybe_state)
				local r = maybe_state or { }
				r.index = r.index or 0
				function r.peek ()
					return round (r.index + 1)
				end
				function r.next ()
					local v = r.peek ()
					r.index = v
					return v
				end
				function r.reset ()
					r.index = 0
				end
				return r
			end
			return create_or_deserialize
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
		["lib.vehicleObjects"] = function ()
			local meta_thisFileRequirePath = "lib.vehicleObjects"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local LibAddon = require "lib.addon"
			local serpentf = require "lib.serialization.serpentf"
			local executeAtTick = require "lib.executeAtTick"
			local registry = require "lib.vehicleObjectsRegistry"
			local function typeAwareToString (value)
				if type (value) == "string" then
					return "'" .. (value .. "'")
				end
				return tostring (value)
			end
			local allSpawnCategories = { }
			local M = { }
			function M.registerSpawnCategory (spec)
				logger.debug ("Adding category '%s' to global list.", spec.category)
				table.insert (allSpawnCategories, spec)
			end
			function M.registerSpawnCategories (list)
				for _, spec in pairs (list) do
					M.registerSpawnCategory (spec)
				end
			end
			local function apply_extra_transformations (transform, meta)
				local logger = logger.getSubLogger "apply_extra_transformations"
				local str = meta.spawn_rotation_y
				if not str then
					return transform
				end
				local n = tonumber (str)
				if not n then
					logger.error ("Could not parse number from '%s' for spawn_rotation_y.", str)
					return transform
				end
				local rotation = matrix.rotationY (math.rad (n))
				transform = matrix.multiply (transform, rotation)
				return transform
			end
			local function findSpawnCategory (category)
				for _, spec in pairs (allSpawnCategories) do
					if spec.category == category then
						if not spec.variants_by_category then
							logger.debug ("Generating variants_by_category on-the-fly for '%s'", category)
							spec.variants_by_category = spec.variants_by_category or LibAddon.generateVariantByCategoryMapping (spec.category, spec.default_variant)
						end
						return spec
					end
				end
				return nil
			end
			local function getPrefabAndSource (variant, default_variant, variants_by_category)
				local prefab, source = nil, "none"
				if variant then
					prefab = variants_by_category[variant]
					source = (prefab and "variants_by_category[zone.meta[type_tag]]") or source
				end
				if not prefab and variant ~= default_variant then
					prefab = variants_by_category[default_variant]
					source = (prefab and "variants_by_category[default_variant]") or source
				end
				return prefab, source
			end
			local function get_spawn_transform (context, zone)
				local transform
				if context.default_rotation then
					transform = matrix.multiply (zone.transform, context.default_rotation)
				else
					transform = zone.transform
				end
				transform = apply_extra_transformations (transform, zone.meta)
				return transform
			end
			local function spawnAtZone (context, prefab, category, variant, zone, proto)
				if not prefab then
					logger.error ("Error spawning %s - no prefab for variant: %s\nZone Data", category, typeAwareToString (variant), function ()
						return serpentf.block (zone)
					end)
					return 
				end
				if context.no_duplicates_behavior then
					local registry = (context.no_duplicates_behavior == "static" and context.static_registry) or context.all_registry
					local obj = registry:by_zone_id (zone.unique_id)
					if obj then
						context.no_duplicates_count = (context.no_duplicates_count or 0) + 1
						logger.trace ("Skipping Zone #%4i because vehicle_id %4i was previously spawned for it.", zone.unique_id, obj.vehicle_id)
						return 
					end
				end
				local transform = get_spawn_transform (context, zone)
				local vehicle_id, success = prefab.spawn (transform)
				if not success then
					logger.error ("Error spawning %s - spawn not success.", category)
					logger.dump ("Zone data: %s", serpentf.block (zone))
					return 
				end
				local registry_entry = {
					Zone_ID = zone.unique_id,
					vehicle_id = vehicle_id
				}
				context.all_registry:add (registry_entry)
				local is_static
				if context.static_registry then
					local data, s = server.getVehicleData (vehicle_id)
					is_static = (s and data) and data.static
					if is_static then
						context.static_registry:add (registry_entry)
					end
				end
				local overrides = {
					tag = category,
					vehicle_id = vehicle_id,
					zone = zone,
					meta = zone.meta,
					is_static = is_static
				}
				local vehicle_data = proto.New (overrides)
				logger.trace ("Created vehicle from zone #%i. Vehicle_ID %i, tag: '%s'.", zone.unique_id, vehicle_id, category)
				logger.dump ("Vehicle Data: %s", serpentf.block (vehicle_data))
				if context.spawned then
					table.insert (context.spawned, vehicle_data)
				end
			end
			function M.spawnAll_iterator (context)
				local logger = logger.getSubLogger "spawnAll_iterator"
				logger.info "Creating iterator"
				logger.dump ("Context before assigning defaults: %s", serpentf.block (context))
				local spawn_categories = context.spawn_categories
				local onCompletionFn = context.onCompletionFn
				context.filter_tags = context.filter_tags or { }
				context.all_registry = context.all_registry or registry.all
				context.static_registry = context.static_registry or (context.no_duplicates_behavior and registry.static)
				context.skipped_duplicates_count = context.skipped_duplicates_count or 0
				logger.dump ("Context after assigning defaults: %s", serpentf.block (context))
				local category_index, spec = nil, nil
				local spawn_zones
				local zone_index, zone = nil, nil
				local done = false
				local function iterator ()
					if done then
						logger.warning "Iterator called while already done."
						return true
					end
					if not spec then
						category_index, spec = next (spawn_categories, category_index)
						if not category_index then
							logger.trace "Iterator done."
							done = true
							if onCompletionFn then
								logger.trace "Calling onCompletionFn..."
								onCompletionFn (context)
							end
							return true
						end
						logger.trace ("Iterator advancing to spawn_category #%i '%s'", category_index, spec.category)
						zone_index = nil
					end
					local category, default_variant, proto = spec.category, spec.default_variant, spec.proto
					local variants_by_category = spec.variants_by_category or LibAddon.generateVariantByCategoryMapping (category, default_variant)
					spec.variants_by_category = variants_by_category
					if not spawn_zones then
						local filter_tags = context.filter_tags
						table.insert (filter_tags, category)
						spawn_zones = spawn_zones or LibAddon.getZonesFromFilterArray (filter_tags)
						table.remove (filter_tags)
					end
					zone_index, zone = next (spawn_zones, zone_index)
					if not zone_index then
						spec = nil
						zone_index = nil
						spawn_zones = nil
						return 
					end
					local variant = zone.meta[category]
					local prefab, _ = getPrefabAndSource (variant, default_variant, variants_by_category)
					spawnAtZone (context, prefab, category, variant, zone, proto)
				end
				logger.trace "Created iterator."
				return iterator
			end
			function M.spawnAll (context)
				local iterator = M.spawnAll_iterator (context)
				local function f ()
					if iterator () then
						return 
					end
					executeAtTick.executeAfterTicks (1, f)
				end
				f ()
			end
			function M.spawnAll_instant (context)
				local logger = logger.getSubLogger "spawnAll_instant"
				logger.info "Start ------------------------------------------------------"
				local iterator = M.spawnAll_iterator (context)
				while true do
					if iterator () then
						break
					end
				end
				logger.info "Done -------------------------------------------------------"
			end
			function M.despawnAll (spawn_categories, instant)
				local logger = logger.getSubLogger "despawnAll"
				logger.info "Start ------------------------------------------------------"
				for _, spec in pairs (spawn_categories) do
					local container = spec.container
					for _, obj in container:iterator () do
						local vehicle_id = obj.vehicle_id
						if vehicle_id then
							local s = server.despawnVehicle (vehicle_id, instant)
							if s then
								logger.dump ("Despawned %s with vehicle_id %i.", spec.category, vehicle_id)
							else
								logger.dump ("Failed to despawn %s with vehicle_id %i.", spec.category, vehicle_id)
							end
						else
							logger.warning ("Failed to despawn %s: missing vehicle_id.", spec.category)
						end
					end
				end
				logger.info "Done -------------------------------------------------------"
			end
			M.findSpawnCategory = findSpawnCategory
			M.get_spawn_transform = get_spawn_transform
			M.getPrefabAndSource = getPrefabAndSource
			return M
		end,
		["lib.vehicleObjectsRegistry"] = function ()
			local meta_thisFileRequirePath = "lib.vehicleObjectsRegistry"
			local addonCallbacks = require "lib.addonCallbacks.registration"
			local persistence = require "lib.persistenceHelper"
			local createWrapperWithBackingContainer = persistence.createWrapperWithBackingContainer
			local _, all_container = createWrapperWithBackingContainer ({ key = "lib.vehicleObjectsRegistry.all" }, "Zone_ID", "vehicle_id")
			local _, static_container = createWrapperWithBackingContainer ({ key = "lib.vehicleObjectsRegistry.static" }, "Zone_ID", "vehicle_id")
			local function onVehicleDespawn_all (vehicle_id)
				local obj = all_container:by_vehicle_id (vehicle_id)
				if not obj then
					return 
				end
				all_container:remove (obj)
			end
			local function onVehicleDespawn_static (vehicle_id)
				local obj = static_container:by_vehicle_id (vehicle_id)
				if not obj then
					return 
				end
				static_container:remove (obj)
			end
			local function onVehicleDespawn (vehicle_id)
				onVehicleDespawn_all (vehicle_id)
				onVehicleDespawn_static (vehicle_id)
			end
			addonCallbacks.registerCallback ("onVehicleDespawn", meta_thisFileRequirePath, onVehicleDespawn,  - 1)
			local M = { }
			M.all = all_container
			M.static = static_container
			return M
		end,
		main = function ()
			local meta_thisFileRequirePath = "main"
			local logger = require "lib.logging.logger".createLogger (meta_thisFileRequirePath)
			local logging = require "lib.logging.api"
			logging.global_prefix = "NSOO"
			local config = require "config"
			local addonCallbacks = require "lib.addonCallbacks.processing"
			require "lib.saveData"
			require "commands"
			require "common.mod_objects.vehicleDisappearMitigation"
			require "common.mod_objects.trafficLights.init"
			require "persistence"
			require "common.mod_objects.welcome"
			do
				
			end
			local function m_onCreate (is_world_create)
				local logger = logger.getSubLogger "onCreate"
				logger.trace ("version: %s", config.script_version)
				if is_world_create then
					logger.important "Executing commands to spawn LOD and traffic signals."
					local peer_id =  - 2
					local is_admin = true
					local is_auth = true
					onCustomCommand ("?nso spawn LOD", peer_id, is_admin, is_auth, "?nso", "spawn", "LOD")
					onCustomCommand ("?nso spawn Cat", peer_id, is_admin, is_auth, "?nso", "spawn", "Cat")
					onCustomCommand ("?nso traffic spawn", peer_id, is_admin, is_auth, "?nso", "traffic", "spawn")
				end
				logger.trace "Done"
			end
			addonCallbacks.registerCallback ("onCreate", meta_thisFileRequirePath, m_onCreate)
		end,
		persistence = function ()
			local libSaveData = require "lib.saveData"
			local persistence_tl = require "common.mod_objects.trafficLights.persistence"
			local M = { }
			M._trafficLights = persistence_tl._trafficLights
			M.TrafficLights = persistence_tl.TrafficLights
			M.TrafficIntersections = persistence_tl.TrafficIntersections
			M.welcomed_players = libSaveData.register { key = "welcomed_players" }
			return M
		end,
		version = function ()
			return "Alpha 2.1"
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

local script_name = "NSO_Objects"

local script_version = "0.0.6.0"

local save_data_version = "1.0.0"

local HttpLogFile = string.format ("/log/%s/server.log", script_name)

local HttpTrailsPath = string.format ("/file/%s/trails/", script_name)

local node_http_port = 8080

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

config.logging.legacyHttp.HttpTrailsPath = HttpTrailsPath

config.logging.legacyHttp.server_port = node_http_port

if workspace_root then
	config.sandbox.workspace_root = workspace_root
	config.sandbox.server_content = workspace_root .. "\\Content"
	config.sandbox.script_root = workspace_root .. ("\\missions\\" .. script_name)
end

local logging = require "lib.logging.api"

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

writer("Loading done: 'NSO_Objects/init.lua'")
