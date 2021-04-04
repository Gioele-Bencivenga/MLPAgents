package;

import echo.Body;
import echo.Line;
import utilities.DebugLine;
import echo.shape.Circle;
import echo.Shape;
import haxe.ds.Vector;
import haxe.ds.List;
import haxe.ui.containers.ListView;
import flixel.util.FlxTimer;
import openfl.display.StageQuality;
import flixel.FlxObject;
import haxe.ui.themes.Theme;
import utilities.HxFuncs;
import entities.AutoEntity;
import supplies.Supply;
import flixel.math.FlxMath;
import flixel.addons.display.FlxZoomCamera;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.core.Component;
import haxe.ui.macros.ComponentMacros;
import haxe.ui.components.*;
import haxe.ui.Toolkit;
import flixel.FlxCamera;
import generators.Generator;
import tiles.Tile;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import echo.util.TileMap;
import flixel.input.mouse.FlxMouseEventManager;

using Math;
using echo.FlxEcho;
using hxmath.math.Vector2;
using flixel.util.FlxArrayUtil;
using flixel.util.FlxSpriteUtil;

class PlayState extends FlxState {
	/**
	 * Size of our tilemaps tiles.
	 */
	public static inline final TILE_SIZE:Int = 32;

	/**
	 * Camera follow speed that gets applied to the `lerp` argument in the `cam.follow()` function.
	 */
	public static inline final CAM_SPEED:Float = 0.2;

	/**
	 * Minimum zoom level reachable by the `simCam`.
	 */
	public static inline final CAM_MIN_ZOOM:Float = 0.25;

	/**
	 * Maximum zoom level reachable by the `simCam`.
	 */
	public static inline final CAM_MAX_ZOOM:Float = 1.6;

	/**
	 * Maximum number of agents that can be in the simulation at any time.
	 */
	public static inline final MAX_AGENTS:Int = 26;

	/**
	 * Number of agents we want to spawn in the simulation.
	 */
	public static inline final AGENTS_COUNT:Int = 25;

	/**
	 * Maximum number of agents that can be in the simulation at any time.
	 */
	public static inline final MAX_RESOURCES:Int = 100;

	/**
	 * Whether we want to draw the sensors for all agents or not.
	 */
	public static var DEBUG_SENSORS:Bool = false;

	/**
	 * Canvas is needed in order to `drawLine()` with `DebugLine`.
	 */
	public static var canvas:FlxSprite;

	/**
	 * Collision group containing the terrain tiles.
	 */
	public static var terrainCollGroup:FlxGroup;

	/**
	 * Collision group containing the entities.
	 */
	public static var entitiesCollGroup:FlxGroup;

	/**
	 * Group containing the entities, terrain and resources bodies.
	 * 
	 * This is used for ease of linecasting in the `agentsEntity.sense()` function.
	 */
	public static var collidableBodies:FlxGroup;

	/**
	 * Typed group of our agents in the world.
	 * 
	 * Used by the camera and cleanup function.
	 */
	public static var agents:FlxTypedGroup<AutoEntity>;

	/**
	 * Typed group of our resources in the world.
	 */
	public static var resources:FlxTypedGroup<Supply>;

	/**
	 * Simulation camera, the camera displaying the simulation.
	 */
	public static var simCam:FlxZoomCamera;

	/**
	 * UI camera, the camera displaying the interface indipendently from zoom.
	 */
	var uiCam:FlxCamera;

	/**
	 * Our UI using haxeui, this contains the list of components and all.
	 */
	var uiView:Component;

	/**
	 * Whether the simulation updates or not.
	 */
	var simUpdates(default, set):Bool = true;

	/**
	 * Array containing the fitness values of deceased entities over time.
	 * 
	 * Used to export values for further analysis.
	 */
	var fitnessData:Array<Float>;

	/**
	 * Automatically sets the value of `FlxEcho.updates`.
	 * @param newVal the new value `FlxEcho.updates` and `simUpdates`
	 */
	function set_simUpdates(newVal) {
		if (FlxEcho.instance != null)
			FlxEcho.updates = newVal;

		return simUpdates = newVal;
	}

	override function create() {
		FlxG.autoPause = false;
		setupCameras();
		// create the ui and wire up functions to buttons
		setupUI();
		// create groups for collision handling and other stuff
		setupGroups();
		// generate world
		generateCaveTilemap();

		var t = new FlxTimer().start(1, function(_) {
			cleanupDeadAgents();
		}, 0);

		fitnessData = [0];
	}

	function setupCameras() {
		/// SETUP
		var cam = FlxG.camera;
		simCam = new FlxZoomCamera(Std.int(cam.x), Std.int(cam.y), cam.width, cam.height, cam.zoom); // create the simulation camera
		FlxG.cameras.reset(simCam); // dump all current cameras and set the simulation camera as the main one

		uiCam = new FlxCamera(0, 0, FlxG.width, FlxG.height); // create the ui camera
		uiCam.bgColor = FlxColor.TRANSPARENT; // transparent bg so we see what's behind it
		FlxG.cameras.add(uiCam); // add it to the cameras list (simCam doesn't need because we set it as the main already)

		/// CUSTOMIZATION
		simCam.zoomSpeed = 4;
		simCam.targetZoom = 1.2;
		simCam.zoomMargin = 0.2;
		simCam.bgColor.setRGB(25, 21, 0);
	}

	/**
	 * Must call `setupCameras()` before this.
	 */
	function setupGroups() {
		/// ECHO COLLISION GROUPS
		terrainCollGroup = new FlxGroup();
		add(terrainCollGroup);
		terrainCollGroup.cameras = [simCam];
		entitiesCollGroup = new FlxGroup();
		add(entitiesCollGroup);
		entitiesCollGroup.cameras = [simCam];

		/// OTHER GROUPS
		collidableBodies = new FlxGroup();
		resources = new FlxTypedGroup<Supply>(MAX_RESOURCES);
		agents = new FlxTypedGroup<AutoEntity>(MAX_AGENTS);
	}

	/**
	 * Must call `setupCameras()` before this.
	 * 
	 * Generates the UI from the XML and associates functions to buttons.
	 */
	function setupUI() {
		Toolkit.init(); // needed before using any haxeui
		Toolkit.scale = 1; // temporary fix for scaling while ian fixes it
		Toolkit.theme = Theme.DARK;

		// build UI from XML
		uiView = ComponentMacros.buildComponent("assets/ui/main-view.xml");
		uiView.cameras = [uiCam]; // all of the ui components contained in uiView will be rendered by uiCam
		uiView.scrollFactor.set(0, 0); // and they won't scroll
		add(uiView);
		// wire functions to UI buttons
		uiView.findComponent("mn_gen_cave", MenuItem).onClick = btn_generateCave_onClick;
		uiView.findComponent("mn_clear_world", MenuItem).onClick = btn_clearWorld_onClick;
		uiView.findComponent("mn_debug_lines", MenuItem).onClick = btn_drawLines_onClick;
		uiView.findComponent("mn_save_agents", MenuItem).onClick = btn_saveAgents_onClick;
		uiView.findComponent("mn_link_website", MenuItem).onClick = link_website_onClick;
		uiView.findComponent("mn_link_github", MenuItem).onClick = link_github_onClick;
		uiView.findComponent("btn_play_pause", Button).onClick = btn_play_pause_onClick;
		uiView.findComponent("btn_target", Button).onClick = btn_target_onClick;
		uiView.findComponent("sld_zoom", Slider).onChange = sld_zoom_onChange;
		uiView.findComponent("lbl_version", Label).text = haxe.macro.Compiler.getDefine("PROJECT_VERSION");
	}

	function btn_generateCave_onClick(_) {
		generateCaveTilemap();
	}

	function btn_clearWorld_onClick(_) {
		emptyGroups([entitiesCollGroup, terrainCollGroup, collidableBodies], agents, resources);
		// destroy world
		if (FlxEcho.instance != null)
			FlxEcho.clear();
	}

	function btn_drawLines_onClick(_) {
		if (DEBUG_SENSORS) {
			DEBUG_SENSORS = false;
			for (agent in agents) {
				agent.isCamTarget = false;
			}
			DebugLine.clearCanvas();
		} else {
			DEBUG_SENSORS = true;
			if (simCam.target != null)
				cast(simCam.target, AutoEntity).isCamTarget = true;
		}
	}

	function btn_saveAgents_onClick(_) {
		#if sys
		var filePath = "C:/Users/gioel/Documents/Repositories/GitHub/MLPAgents/MLPAgents/assets/data/fitnessData.txt";
		try {
			sys.io.File.saveContent(filePath, fitnessData.join("\n"));
		} catch (e) {
			trace(e.details());
		}
		#end
	}

	function link_website_onClick(_) {
		FlxG.openURL("https://gioele-bencivenga.github.io", "_blank");
	}

	function link_github_onClick(_) {
		FlxG.openURL("https://github.com/Gioele-Bencivenga/MLPAgents", "_blank");
	}

	function btn_play_pause_onClick(_) {
		var item = uiView.findComponent("btn_play_pause", Button);

		if (item.selected == true) {
			simUpdates = false;
			item.text = "play";
			item.icon = "assets/icons/icon_play_light.png";
		} else {
			simUpdates = true;
			item.text = "pause";
			item.icon = "assets/icons/icon_pause_light.png";
		}
	}

	function btn_target_onClick(_) {
		setCameraTargetAgent(agents.getRandom());
	}

	function sld_zoom_onChange(_) {
		var slider = uiView.findComponent("sld_zoom", Slider);

		simCam.targetZoom = HxFuncs.map(slider.pos, slider.min, slider.max, CAM_MIN_ZOOM, CAM_MAX_ZOOM);
	}

	function generateCaveTilemap() {
		// instantiate generator and generate the level
		var gen = new Generator(70, 110);
		var levelData:Array<Array<Int>> = gen.generateCave(AGENTS_COUNT, 0.09, 2, 2, 2);

		// reset the groups before filling them again
		emptyGroups([entitiesCollGroup, terrainCollGroup, collidableBodies], agents, resources);

		// destroy previous world
		if (FlxEcho.instance != null)
			FlxEcho.clear();
		// create world before adding any physics objects
		FlxEcho.init({
			x: 0,
			y: 0,
			width: levelData[0].length * TILE_SIZE, // Make the size of your Echo world equal the size of your play field
			height: levelData.length * TILE_SIZE,
		});
		FlxEcho.reset_acceleration = true;
		FlxEcho.updates = simUpdates; // if the sim is paused pause the world too
		FlxEcho.instance.world.iterations = 1;

		// generate physics bodies for our Tilemap from the levelData - making sure to ignore any tile with the index 2 or 3 so we can create objects out of them later
		var tiles = TileMap.generate(levelData.flatten2DArray(), TILE_SIZE, TILE_SIZE, levelData[0].length, levelData.length, 0, 0, 1, null, [2, 3]);
		for (tile in tiles) {
			var bounds = tile.bounds(); // Get the bounds of the generated physics body to create a Box sprite from it
			var wallTile = new Tile(bounds.min_x, bounds.min_y, bounds.width.floor(), bounds.height.floor(), FlxColor.fromRGB(230, 240, 245));
			bounds.put(); // put() the bounds so that they can be reused later. this can really help with memory management
			// wallTile.set_body(tile); // SHOULD attach the generated body to the FlxObject, doesn't seem to work at the moment so using add_body instead
			wallTile.add_body({
				shape: {
					type: RECT,
					width: wallTile.width,
					height: wallTile.height
				}
			});
			wallTile.get_body().mass = 0; // tiles are immovable
			wallTile.get_body().bodyType = 1; // sensors understand 1 = wall, 2 = entity, 3 = resource...
			wallTile.add_to_group(terrainCollGroup); // Instead of `group.add(object)` we use `object.add_to_group(group)`
			wallTile.add_to_group(collidableBodies);
		}

		/// CANVAS
		if (canvas != null)
			canvas.kill(); // kill previous canvas
		canvas = new FlxSprite();
		// make new canvas as big as the world
		canvas.makeGraphic(Std.int(FlxEcho.instance.world.width), Std.int(FlxEcho.instance.world.height), FlxColor.TRANSPARENT, true);
		canvas.cameras = [simCam];
		add(canvas);

		/// ENTITIES
		for (j in 0...levelData.length) { // step through level data and add entities
			for (i in 0...levelData[j].length) {
				switch (levelData[j][i]) {
					case 2:
						createAgent(i * TILE_SIZE, j * TILE_SIZE);
					case 3:
						createResource(i * TILE_SIZE, j * TILE_SIZE);
					default:
						continue;
				}
			}
		}

		/// COLLISIONS
		entitiesCollGroup.listen(terrainCollGroup, {
			stay: (body1, body2, collData) -> {
				switch (body1.bodyType) {
					case 2: // we are an entity
						switch (body2.bodyType) {
							case 1: // we hit a wall
								var ent = cast(body1.get_object(), AutoEntity);
								ent.deplete(100);
							case any:
								// do nothing
						}
					case any:
						// do nothing
				}
			}
		});
		entitiesCollGroup.listen(entitiesCollGroup, {
			stay: (body1, body2, collData) -> {
				switch (body1.bodyType) {
					case 2: // we are an entity
						var ent = cast(body1.get_object(), AutoEntity);
						switch (body2.bodyType) {
							case 2: // we hit an entity
								if (ent.biteAmount > 0) { // we are trying to bite
									var hitEnt = cast(body2.get_object(), AutoEntity);
									var chunk = hitEnt.deplete((ent.bite * (ent.biteAmount * 2)));
									ent.replenishEnergy(chunk * ent.absorption);
									if (hitEnt.biteAmount > 0) { // other entity is biting too
										var ourChunk = ent.deplete((hitEnt.bite * (hitEnt.biteAmount * 2)));
										hitEnt.replenishEnergy(ourChunk * hitEnt.absorption);
									}
								}
							case 3: // we hit a resource
								if (ent.biteAmount > 0) { // we are trying to bite
									var res = cast(body2.get_object(), Supply); // grasp the resource
									var chunk = res.deplete(ent.bite * (ent.biteAmount * 2)); // bite a chunk out of it
									ent.replenishEnergy(chunk * ent.absorption); // eat it
								}
							case any: // we hit anything else
								// do nothing
						}
					case 3: // we are a resource
						switch (body2.bodyType) {
							case 2: // we hit an entity
								var ent = cast(body2.get_object(), AutoEntity);
								if (ent.biteAmount > 0) { // entity is biting
									var res = cast(body1.get_object(), Supply);
									var chunk = res.deplete(ent.bite * (ent.biteAmount * 2));

									ent.replenishEnergy(chunk * ent.absorption);
								}
							case any: // we hit anything else
								// do nothing
						}
					case any: // we are anything else
						// do nothing
				}
			}
		});
		setCameraTargetAgent(agents.getFirstAlive());
	}

	override function update(elapsed:Float) {
		if (FlxEcho.updates) {
			super.update(elapsed);
		}

		// if (FlxG.mouse.wheel != 0) {
		//	var slider = uiView.findComponent("sld_zoom", Slider);

		//	slider.pos += FlxMath.bound(FlxG.mouse.wheel, -7, 7);
		// }
	}

	/**
	 * Function that gets called when an agent is clicked.
	 * @param _agent the agent that was clicked (need to be `FlxSprite`)
	 */
	function onAgentClick(_agent:FlxSprite) {
		setCameraTargetAgent(_agent);
	}

	/**
	 * Updates the `simCam`'s target and flips the agent's flag.
	 * @param _target the new target we want the camera to follow
	 */
	function setCameraTargetAgent(_target:FlxObject) {
		if (simCam.target != null)
			cast(simCam.target, AutoEntity).isCamTarget = false;

		simCam.follow(_target, 0.2);
		if (DEBUG_SENSORS)
			cast(_target, AutoEntity).isCamTarget = true;
	}

	/**
	 * This function `kill()`s, `clear()`s, and `revive()`s the passed `FlxGroup`s.
	 *
	 * It's mostly used when re-generating the world.
	 *
	 * I think doing this resets the groups and it helped fix a bug with collision when regenerating the map.
	 * If you read this and you know that I could do this better please let me know!
	 *
	 * @param _groupsToEmpty an array containing the `FlxGroup`s that you want to reset.
	 * @param _typedGroups need to empty some `FlxTypedGroup<AutoEntity>` too?
	 */
	function emptyGroups(_groupsToEmpty:Array<FlxGroup>, ?_agentGroup:FlxTypedGroup<AutoEntity>, ?_resGroup:FlxTypedGroup<Supply>) {
		for (group in _groupsToEmpty) {
			group.kill();
			group.clear();
			group.revive();
		}

		if (_agentGroup.length > 0) {
			_agentGroup.kill();
			_agentGroup.clear();
			_agentGroup.revive();
		}

		if (_resGroup.length > 0) {
			_resGroup.kill();
			_resGroup.clear();
			_resGroup.revive();
		}
	}

	/**
	 * This function is periodically run by a timer.
	 * 
	 * It replaces dead agents with children generated by applying crossover and mutation on the population.
	 */
	function cleanupDeadAgents() {
		if (FlxEcho.updates) {
			var newAgent:AutoEntity = null;
			for (agent in agents) {
				if (agent.alive && agent.exists) {
					if (agent.currEnergy <= 1) {
						var agX = agent.body.x;
						var agY = agent.body.y;
						// trace('fit: ${agent.fitnessScore}');
						fitnessData.push(agent.fitnessScore);
						agent.kill(); // kill previous agent

						var array = agents.members.filter((a:AutoEntity) -> {
							a != null;
						});
						var competitors:Array<AutoEntity> = [for (i in 0...4) null];
						competitors[0] = FlxG.random.getObject(array);
						// trace('part1: ${par1.fitnessScore} len: ${par1.brain.connections.length}');
						competitors[1] = FlxG.random.getObject(array);
						while (competitors[1] == competitors[0]) { // need to be 2 different competitors
							competitors[1] = FlxG.random.getObject(array);
						}
						// trace('part2: ${par2.fitnessScore} len: ${par2.brain.connections.length}');
						var winner = getTournamentWinner(competitors[0], competitors[1]);
						// trace('winner: ${winner.fitnessScore} len: ${winner.brain.connections.length}');

						var parent1 = winner;
						var parent2 = FlxG.random.getObject(array);
						while (parent2 == parent1) {
							parent2 = FlxG.random.getObject(array);
						}
						// trace('parent1: ${parent1.brain.connections} of len: ${parent1.brain.connections.length}\n
						// parent2: ${parent2.brain.connections} of len: ${parent2.brain.connections.length}');

						var cutPoint = FlxG.random.int(1, parent1.brain.connectionsCount - 1);
						// trace('cut point: ${cutPoint}');
						for (i in 0...cutPoint) {
							parent2.brain.connections[i] = parent1.brain.connections[i];
						}
						// trace('crossed brain: ${parent2.brain.connections} len: ${parent2.brain.connections.length}');

						// gaussian mutation
						var mutatedBrain = [for (i in 0...parent2.brain.connections.length) FlxG.random.floatNormal(0, 0.05)];
						for (i in 0...mutatedBrain.length) {
							mutatedBrain[i] = mutatedBrain[i] + parent2.brain.connections[i];
							if (mutatedBrain[i] > 1)
								mutatedBrain[i] = 1;
							if (mutatedBrain[i] < -1)
								mutatedBrain[i] = -1;
						}
						// trace('mutant brain: ${mutatedBrain} len: ${mutatedBrain.length}');

						var newAgentPos = getEmptySpace();
						newAgent = createAgent(newAgentPos.x, newAgentPos.y, mutatedBrain);
						// trace('child brain: ${newAgent.brain.connections} len: ${newAgent.brain.connections.length}');

						var resourceAmt = 3;
						if (resources.countLiving() <= 55) {
							for (i in 0...resourceAmt) {
								var newResPos = getEmptySpace();
								createResource(newResPos.x, newResPos.y);
							}
						}
					}
				}
			}

			if (simCam.target.alive == false) {
				setCameraTargetAgent(newAgent);
			}
		}
	}

	/**
	 * Returns the agent with the highest fitness score between the 2.
	 * 
	 * In case of same fitness the first participant wins.
	 * @param _part1 first participant in the tournament 
	 * @param _part2 second participant in the tournament 
	 */
	function getTournamentWinner(_part1:AutoEntity, _part2:AutoEntity) {
		var winner = _part1;
		if (_part1.fitnessScore < _part2.fitnessScore)
			winner = _part2;
		return winner;
	}

	/**
	 * Creates a new agent and adds it to the appropriate groups.
	 * @param _x x position of new agent
	 * @param _y y position of new agent
	 * @return the newly created agent
	 */
	function createAgent(_x:Float, _y:Float, ?_connections:Array<Float>):AutoEntity {
		var newAgent = agents.recycle(AutoEntity.new); // recycle agent from pool
		newAgent.init(_x, _y, 30, 15, _connections); // add body, brain ecc
		newAgent.add_to_group(collidableBodies); // add to linecasting group
		newAgent.add_to_group(entitiesCollGroup); // add to collision group
		agents.add(newAgent); // add to recycling group
		FlxMouseEventManager.add(newAgent, onAgentClick); // add event listener for mouse clicks

		// trace('created new agent with len: ${newAgent.brain.connections.length}');
		return newAgent;
	}

	/**
	 * Creates a new resource and adds it to the appropriate groups.
	 * @param _x x position of new resource
	 * @param _y y position of new resource
	 */
	function createResource(_x:Float, _y:Float) {
		var newRes = resources.recycle(Supply.new); // recycle
		newRes.init(_x, _y); // initialise values
		newRes.add_to_group(collidableBodies); // add to bodies visible by sensors
		newRes.add_to_group(entitiesCollGroup); // add to bodies that should collide
		resources.add(newRes); // add to recycling group
	}

	/**
	 * Gets a random position in the world and checks it for bodies.
	 * 
	 * If no bodies are found the position is returned.
	 */
	function getEmptySpace(_lineLength:Float = 80, _lineAmt:Int = 20) {
		var foundEmptySpace = false;
		var emptyPosition = new Vector2(50, 50);
		do {
			// we need an array of bodies for the linecast, sometimes its shape will be null and an exception will be thrown
			var bodiesArray:Array<Body> = [
				for (i in 0...collidableBodies.get_group_bodies().length)
					if (collidableBodies.get_group_bodies()[i].shapes != null) {
						collidableBodies.get_group_bodies()[i];
					}
			];

			emptyPosition.set(FlxG.random.float(FlxEcho.instance.world.x + 100, FlxEcho.instance.world.width - 100),
				FlxG.random.float(FlxEcho.instance.world.y + 100, FlxEcho.instance.world.height - 100));

			var hitBody:Bool = false;
			var line = Line.get();
			for (i in 0..._lineAmt) {
				line.set_from_vector(emptyPosition, 360 * (i / _lineAmt), _lineLength);
				var result = line.linecast(bodiesArray);
				if (result != null) {
					hitBody = true;
				}
				line.put();
			}

			if (hitBody == true) {
				foundEmptySpace = false;
			} else {
				foundEmptySpace = true;
			}
		} while (foundEmptySpace == false);

		return emptyPosition;
	}
}
/**
 * Single point crossover proof.
 * Run on try.haxe.org
 */ /*
	class Test {
	public static inline final CUT_POINT = 9; // change cut point here

	static function main() {
		var m1:Array<Float> = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
		var m2:Array<Float> = [20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
		var m3 = singlePointCrossover(m1, m2);
	}

	public static function singlePointCrossover(_material1:Array<Float>, _material2:Array<Float>) {
		trace('m1: ${_material1}');
		trace('m2: ${_material2}\n');
		// store correct length in new array
		var newMaterial = [for (i in 0..._material1.length) 0.];
		// get random cut point
		var point = CUT_POINT;
		// cut away the genes on the right of the point, keep the left genes
		_material1.resize(point);
		trace('resize m1: ${_material1}');
		// insert each cut gene in place of the previous gene
		for (i in 0..._material1.length) {
			_material2[i] = _material1[i];
			trace('push: ${_material2}');
		}

		newMaterial = _material2;
		trace('m3: ${newMaterial}\n');

		return newMaterial;
	}
	}
 */