package entities;

import flixel.FlxG;
import supplies.Supply;
import echo.data.Data.Intersection;
import flixel.math.FlxMath;
import brains.MLP;
import hxmath.math.MathUtil;
import flixel.util.helpers.FlxRange;
import hxmath.math.Vector2;
import flixel.util.FlxColor;
import utilities.DebugLine;
import flixel.util.FlxTimer;
import echo.Body;
import echo.Line;
import PlayState;
import utilities.HxFuncs;

using echo.FlxEcho;

/**
 * Autonomous Entity.
 */
class AutoEntity extends Entity {
	/**
	 * Number of environment sensors that agents have.
	 */
	public static inline final SENSORS_COUNT:Int = 5;

	/**
	 * Each sensor can activate up to 5 input neurons: 
	 * - distanceToWall `0..1` distance to wall hit by sensor
	 * - distanceToEntity `0..1` distance to entity hit by sensor
	 * - distanceToResource `0..1` distance to resource hit by sensor
	 * 
	 * Shorter distance = higher activation and vice versa.
	 * 
	 * - entityEnergy `0..1` the amount of energy of the hit entity (if any)
	 * - supplyAmount `0..1` the amount of the hit resource (if any)
	 * 
	 * Higher amount = higher activation and vice versa.
	 */
	public static inline final SENSORS_INPUTS:Int = SENSORS_COUNT * 5;

	/**
	 * How often the sensors are cast.
	 * 
	 * The `sense()` function will be run by the `senserTimer` each `sensorRefreshRate` seconds.
	 */
	public static inline final SENSORS_REFRESH_RATE:Float = 0.027;

	/**
	 * The sensors' distance from the center of this entity's body.
	 */
	public static inline final SENSORS_DISTANCE:Float = 19;

	/**
	 * Bias is added via a neuron that's always firing 1.
	 */
	public static inline final BIAS:Int = 1;

	/**
	 * This entity's multilayer perceptron, getting inputs from the sensors and giving outputs as movement.
	 */
	public var brain(default, null):MLP;

	/**
	 * The timer that will `sense()` each `sensorRefreshRate` seconds.
	 */
	var senserTimer:FlxTimer;

	/**
	 * The array containing the entity's environment sensors.
	 */
	public var sensors(default, null):Array<Line>;

	/**
	 * Array containing the rotations of the sensors.
	 */
	var sensorsRotations:Array<Float>;

	/**
	 * The range of possible rotations that sensors of an entity can assume.
	 */
	var possibleRotations:FlxRange<Float>;

	/**
	 * Array containing the lengths of the sensors.
	 */
	var sensorsLengths:Array<Float>;

	/**
	 * Whether this entity is the camera's target or not.
	 * 
	 * Updated in the PlayState's `onAgentClick()` function.
	 */
	public var isCamTarget:Bool;

	/**
	 * The current inputs that are being fed to the `MLP`.
	 * 
	 * The array has 5 neurons for each sensors:
	 * - `distanceToWall` `0` sensor sees no wall, `0.1` far away wall, `0.9` very close wall
	 * - `distanceToEntity` `0` sensor sees no entity, `0.1` far away entity, `0.9` very close entity
	 * - `distanceToResource` `0` sensor sees no resource, `0.1` far away resource, `0.9` very close resource
	 * - `entityEnergy` `0` no entity sensed, `0.1` sensed low energy entity, `0.9` sensed high energy entity
	 * - `supplyAmount` `0` no supply sensed, `0.1` sensed low quantity supply, `0.9` sensed high quantity supply 
	 * 
	 * These values are mapped to a range between 0 and 1.
	 */
	var brainInputs:Array<Float>;

	/**
	 * If this entity's brain has been initialized.
	 */
	public var brainReady(default, null):Bool = false;

	/**
	 * Calculating 1/length of genotype (number of connections) is quite slow to do at every reproduction and for every connection, so we calculate the value only once and store it here.
	 */
	public var oneOverLength(default, null):Float;

	public function new() {
		super();
	}

	/**
	 * Initialise the Entity by creating sensors, adding body, creating brain ecc..
	 */
	override public function init(_x:Float, _y:Float, _width:Int, _height:Int, ?_connections:Array<Float>) {
		super.init(_x, _y, _width, _height);

		possibleRotations = new FlxRange(0., 0.);

		var rot = 60.;
		setSensorRotations(-rot, rot);

		var lengthVals = [500, 550, 600];
		sensorsLengths = [
			for (i in 0...SENSORS_COUNT) {
				switch (i) {
					case 0:
						lengthVals[0];
					case 1:
						lengthVals[1];
					case 2:
						lengthVals[2];
					case 3:
						lengthVals[1];
					case 4:
						lengthVals[0];
					case any:
						lengthVals[0];
				}
			}
		];

		sensors = [for (i in 0...SENSORS_COUNT) null]; // fill the sensors array with nulls

		senserTimer = new FlxTimer();
		senserTimer.start(SENSORS_REFRESH_RATE, (_) -> sense(), 0);

		brain = new MLP(SENSORS_INPUTS // number of input neurons dedicated to sensors
			+ 1 // own energy level neuron
			// HIDDEN LAYER
			, 5 // arbitrary number
			// OUTPUT LAYER
			, 2 // rotation and movement outputs
			//+ 1 // bite output / AUTO BITE FOR NOW
			//+ 1 // dash output
			, _connections);

		brainInputs = [for (i in 0...brain.inputLayerSize) 0];

		oneOverLength = 1 / brain.connections.length;
	}

	override function update(elapsed:Float) {
		if (FlxEcho.updates) {
			super.update(elapsed);

			act();
		}
	}

	function act() {
		if (brain != null) {
			if (useEnergy(0.6)) { // acting costs energy
				// decide how to act based on current inputs
				var brainOutputs:Array<Float> = brain.feedForward(brainInputs);
				// communicate how to act to the body
				move(brainOutputs[0]);
				rotate(brainOutputs[1]);
				//controlBite(brainOutputs[2]);
				//controlDash(brainOutputs[3]);
			}
		}
	}

	/**
	 * Get information about the environment from the sensors.
	 * 
	 * Called periodically by the `senserTimer`.
	 */
	function sense() {
		if (FlxEcho.updates) {
			if (useEnergy(0.6)) { // sensing costs energy
				var sensorInputs = [for (i in 0...SENSORS_INPUTS) 0.];
				// we need an array of bodies for the linecast
				var bodiesArray:Array<Body> = [
					for (i in 0...PlayState.collidableBodies.get_group_bodies().length)
						if (PlayState.collidableBodies.get_group_bodies()[i].shapes != null) {
							PlayState.collidableBodies.get_group_bodies()[i];
						}
				];

				if (isCamTarget)
					DebugLine.clearCanvas(); // clear previously drawn lines

				for (i in 0...sensors.length) { // do this for each sensor
					sensors[i] = Line.get(); // init the sensor
					// create a vector to subtract from the body's position in order to to gain a relative offset
					var relOffset = Vector2.fromPolar(MathUtil.degToRad(body.rotation + sensorsRotations[i]),
						SENSORS_DISTANCE); // radius is distance from body

					var sensorPos = body.get_position()
						.addWith(relOffset); // this body's pos added with the offset will give us a sensor starting position out of the body

					// set the actual sensors position,rotation, and length
					sensors[i].set_from_vector(sensorPos, body.rotation + sensorsRotations[i], sensorsLengths[i]);
					// cast the line, returning the first intersection
					var hit:Intersection = null;
					hit = sensors[i].linecast(bodiesArray);
					if (hit != null) { // if we hit something
						var lineColor = FlxColor.RED;
						switch (hit.body.bodyType) {
							case 1: // hit a wall
								lineColor = FlxColor.WHITE;
								sensorInputs[i] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToWall neuron
							case 2: // hit an agent
								lineColor = FlxColor.ORANGE;
								sensorInputs[i + SENSORS_COUNT] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToEntity neuron
								var agent = cast(hit.body.get_object(), AutoEntity);
								sensorInputs[i + (SENSORS_COUNT * 2)] = HxFuncs.map(agent.currEnergy, 0, agent.maxEnergy, 0,
									1); // put agent's energy amount in entityEnergy neuron
							case 3: // hit a resource
								lineColor = FlxColor.MAGENTA;
								sensorInputs[i + (SENSORS_COUNT * 3)] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToResource neuron
								var supp = cast(hit.body.get_object(), Supply);
								sensorInputs[i + (SENSORS_COUNT * 4)] = HxFuncs.map(supp.currAmount, 0, Supply.MAX_START_AMOUNT, 0,
									1); // put supply's amount in supplyAmount neuron
							case unknown: // hit unknown
								lineColor = FlxColor.BROWN;
								sensorInputs[i] = 0;
								sensorInputs[i + SENSORS_COUNT] = 0;
								sensorInputs[i + (SENSORS_COUNT * 2)] = 0;
								sensorInputs[i + (SENSORS_COUNT * 3)] = 0;
								sensorInputs[i + (SENSORS_COUNT * 4)] = 0;
						}
						if (isCamTarget)
							DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y, lineColor, 2);
					} else { // if we didn't hit anything
						// reflect it in the array
						sensorInputs[i] = 0;
						sensorInputs[i + SENSORS_COUNT] = 0;
						sensorInputs[i + (SENSORS_COUNT * 2)] = 0;
						sensorInputs[i + (SENSORS_COUNT * 3)] = 0;
						sensorInputs[i + (SENSORS_COUNT * 4)] = 0;

						if (isCamTarget)
							DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y);
					}
					sensors[i].put(); // put the linecast
				}
				// put sensor inputs into array of inputs
				brainInputs = [
					for (input in sensorInputs)
						input
				];

				// add input neuron for current own energy level
				brainInputs = brainInputs.concat([HxFuncs.map(currEnergy, 0, maxEnergy, 0, 1)]);
			}
		}
	}

	/**
	 * Returns the distance to the intersection in a range of `1` to `0`. 
	 * 
	 * Meaning that if the intersection happens furthest from the sensor a value close to `0` will be returned, 
	 * while a close intersection will return a value close to `1`.
	 * 
	 * This is because the agents should prefer and prioritise closer stuff.
	 * 
	 * @param _inters the intersection that we want to measure the distance of
	 * @param _maxDistance the maximum distance at which an intersection can happen (sensor's length)
	 * @return the intersection's distance as represented by a value in a range of `1` to `0`
	 */
	function invDistanceTo(_inters:Intersection, _maxDistance:Float):Float {
		var dist = HxFuncs.map(_inters.closest.distance, 0, _maxDistance, 1, 0);
		return dist;
	}

	/**
	 * Sets the limits for the sensors rotation positioning.
	 *
	 * @param _newStart 
	 * @param _newEnd 
	 */
	function setSensorRotations(_newStart:Float, _newEnd:Float) {
		possibleRotations.set(_newStart, _newEnd);

		sensorsRotations = [
			for (i in 0...SENSORS_COUNT) {
				switch (i) {
					case 0:
						possibleRotations.start;
					case 1:
						possibleRotations.start + (possibleRotations.end / 2);
					case 2:
						possibleRotations.start + possibleRotations.end;
					case 3:
						possibleRotations.end + (possibleRotations.start / 2);
					case 4:
						possibleRotations.end;
					case any:
						0;
				}
			}
		];
	}

	override function kill() {
		brainReady = false;
		if (senserTimer != null) {
			if (senserTimer.active) {
				senserTimer.cancel();
				senserTimer.destroy();
			}
		}
		PlayState.agents.remove(this);
		super.kill();
	}
}
