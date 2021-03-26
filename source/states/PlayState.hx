package states;

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
	public static inline final MAX_AGENTS:Int = 15;

	/**
	 * Number of agents we want to spawn in the simulation.
	 */
	public static inline final AGENTS_COUNT:Int = 6;

	/**
	 * Maximum number of agents that can be in the simulation at any time.
	 */
	public static inline final MAX_RESOURCES:Int = 200;

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
	 * UI listview displaying the `agentsList`.
	 */
	var agentsListView:ListView;

	var chosenListView:ListView;

	/**
	 * List containing our agents in the world.
	 */
	var agentsArray:Array<AutoEntity>;

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
		setupCameras();
		// create the ui and wire up functions to buttons
		setupUI();
		// create groups for collision handling and other stuff
		setupGroups();
		// generate world
		generateCaveTilemap();

		var r = new FlxTimer().start(0.5, function(_) {
			refreshAgentsListView();
		}, 0);

		var t = new FlxTimer().start(2, function(_) {
			cleanupDeadAgents();
		}, 0);
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
		agentsArray = [for (i in 0...AGENTS_COUNT) null];
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
		uiView.findComponent("mn_link_website", MenuItem).onClick = link_website_onClick;
		uiView.findComponent("mn_link_github", MenuItem).onClick = link_github_onClick;
		agentsListView = uiView.findComponent("lst_agents", ListView);
		chosenListView = uiView.findComponent("lst_chosen_agents", ListView);
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
		var levelData:Array<Array<Int>> = gen.generateCave(6);

		// reset the groups before filling them again
		emptyGroups([entitiesCollGroup, terrainCollGroup, collidableBodies], agents, resources);

		// destroy previous world
		if (FlxEcho.instance != null)
			FlxEcho.clear();
		// create world before adding any physics objects
		FlxEcho.init({
			width: levelData[0].length * TILE_SIZE, // Make the size of your Echo world equal the size of your play field
			height: levelData.length * TILE_SIZE,
		});
		FlxEcho.reset_acceleration = true;
		FlxEcho.updates = simUpdates; // if the sim is paused pause the world too
		FlxEcho.instance.world.iterations = 2;

		// generate physics bodies for our Tilemap from the levelData - making sure to ignore any tile with the index 2 or 3 so we can create objects out of them later
		var tiles = TileMap.generate(levelData.flatten2DArray(), TILE_SIZE, TILE_SIZE, levelData[0].length, levelData.length, 0, 0, 1, null, [2, 3]);
		for (tile in tiles) {
			var bounds = tile.bounds(); // Get the bounds of the generated physics body to create a Box sprite from it
			var wallTile = new Tile(bounds.min_x, bounds.min_y, bounds.width.floor(), bounds.height.floor(), FlxColor.fromRGB(230, 240, 245));
			bounds.put(); // put() the bounds so that they can be reused later. this can really help with memory management
			// wallTile.set_body(tile); // SHOULD attach the generated body to the FlxObject, doesn't seem to work at the moment so using add_body instead
			wallTile.add_body().bodyType = 1; // sensors understand 1 = wall, 2 = entity, 3 = resource...
			wallTile.get_body().mass = 0; // tiles are immovable
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
		entitiesCollGroup.listen(terrainCollGroup);
		entitiesCollGroup.listen(entitiesCollGroup, {
			stay: (body1, body2, collData) -> {
				switch (body1.bodyType) {
					case 2: // we are an entity
						var ent = cast(body1.get_object(), AutoEntity);
						if (ent.biteAmount > 0) { // we are trying to bite
							switch (body2.bodyType) {
								case 2: // we hit an entity
									var hitEnt = cast(body2.get_object(), AutoEntity);
									var chunk = hitEnt.deplete((ent.bite * (ent.biteAmount * 2)));
									ent.replenishEnergy(chunk * ent.absorption);

									if (hitEnt.biteAmount > 0) { // other entity is biting too
										var ourChunk = ent.deplete((hitEnt.bite * (hitEnt.biteAmount * 2)));
										hitEnt.replenishEnergy(ourChunk * hitEnt.absorption);
									}
								case 3: // we hit a resource
									var res = cast(body2.get_object(), Supply); // grasp the resource
									var chunk = res.deplete(ent.bite * (ent.biteAmount * 2)); // bite a chunk out of it
									ent.replenishEnergy(chunk * ent.absorption); // eat it
								case any: // we hit anything else
									// do nothing
							}
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
	 * It replaces dead agents with low energy with new random agents.
	 */
	function cleanupDeadAgents() {
		if (FlxEcho.updates) {
			for (agent in agents) {
				if (agent.alive && agent.exists) {
					if (agent.currEnergy <= 1) {
						var agX = agent.body.x;
						var agY = agent.body.y;
						agent.kill(); // kill previous agent
						refreshAgentsListView();

						var array = agents.members.filter((a:AutoEntity) -> {
							a != null;
						});
						for (ag in array) {
							trace('member: ${ag.fitnessScore}');
						}
						var par1 = FlxG.random.getObject(array);
						trace('part1: ${par1.fitnessScore} len: ${par1.brain.connections.length}');
						var par2 = FlxG.random.getObject(array);
						trace('part2: ${par2.fitnessScore} len: ${par2.brain.connections.length}');
						var par3 = FlxG.random.getObject(array);
						trace('part3: ${par3.fitnessScore} len: ${par3.brain.connections.length}');
						trace('winner: ${getTournamentWinner(par1, par2).fitnessScore} len: ${getTournamentWinner(par1, par2).brain.connections.length}');
						// runSelection(agents);

						// reproduction is just random right now
						var newAgent = createAgent(agX, agY);
						// setCameraTargetAgent(newAgent);
					}
				}
			}
		}
	}

	/**
	 * Tournament selection.
	 * 
	 * - get 3 agents at random from our group of agents
	 * - get the first 2 and discard the one with the least fitness
	 * - reproduce the two remaining agents
	 * 
	 * @param _agents population from which to choose the individuals
	 */
	function runSelection(_agents:FlxTypedGroup<AutoEntity>) {
		var agentsPool = _agents;
		for (agent in agentsPool) {
			if (agent == null) {
				agentsPool.remove(agent);
			} else {
				if (!agent.alive) {
					agentsPool.remove(agent);
				}
			}
		}

		var participant1:AutoEntity;
		do {
			participant1 = agentsPool.getRandom();
		} while (participant1 == null);
		var participant2:AutoEntity;
		do {
			participant2 = agentsPool.getRandom();
		} while (participant2 == null || participant2 == participant1);
		var participant3:AutoEntity;
		do {
			participant3 = agentsPool.getRandom();
		} while (participant3 == null || participant3 == participant1 || participant3 == participant2);

		var parent1 = getTournamentWinner(participant1, participant2);
		var parent2 = participant3;
		if (parent1 != null && parent2 != null) {
			var a = singlePointCrossover(parent1.brain.connections, parent2.brain.connections);
		} else {
			trace("A parent was NULL!!");
		}
		trace('p1: ${parent1.fitnessScore} p2: ${parent2.fitnessScore}');
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

	function singlePointCrossover(_material1:Array<Float>, _material2:Array<Float>) {
		trace('received connections1: ${_material1} of length: ${_material1.length}\n
		received connections2: ${_material2} of length: ${_material1.length}');
		// store correct array length in new array
		var newMaterial = [for (i in 0..._material1.length) 0.];
		// get random cut point
		var point = FlxG.random.int(1, newMaterial.length - 1);
		trace('cut point: ${point}');
		// cut away the genes on the right of the point, keep the left genes
		_material1.resize(point);
		// insert each cut gene in place of the previous gene
		for (i in 0..._material1.length) {
			_material2[i] = _material1[i];
		}

		newMaterial = _material2;

		trace('created new material: ${newMaterial} of length: ${newMaterial.length}');

		return newMaterial;
	}

	/**
	 * Creates a new agent and adds it to the appropriate groups.
	 * @param _x x position of new agent
	 * @param _y y position of new agent
	 * @return the newly created agent
	 */
	function createAgent(_x:Float, _y:Float):AutoEntity {
		var newAgent = agents.recycle(AutoEntity.new); // recycle agent from pool
		newAgent.init(_x, _y, 30, 15); // add body, brain ecc
		newAgent.add_to_group(collidableBodies); // add to linecasting group
		newAgent.add_to_group(entitiesCollGroup); // add to collision group
		agents.add(newAgent); // add to recycling group
		FlxMouseEventManager.add(newAgent, onAgentClick); // add event listener for mouse clicks

		refreshAgentsListView();

		trace('created new agent with len: ${newAgent.brain.connections.length}');
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

	function refreshAgentsListView() {
		agentsListView.dataSource.allowCallbacks = false; // speeds things up
		agentsListView.dataSource.clear();
		for (agent in agents) {
			if (agent.alive) {
				agentsListView.dataSource.add({
					name: 'agent ${agentsListView.dataSource.size + 1}',
					energy: agent.currEnergy,
					fitness: agent.fitnessScore
				});
			}
		}
		agentsListView.dataSource.allowCallbacks = true;
	}
}
/**
 * Single point crossover proof.
 * Run on try.haxe.org
 */
/*
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
