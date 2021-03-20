package entities;

import supplies.Supply;
import echo.data.Data.Intersection;
import flixel.math.FlxMath;
import flixel.FlxSprite;
import flixel.FlxG;
import brains.MLP;
import hxmath.math.MathUtil;
import flixel.util.helpers.FlxRange;
import hxmath.math.Vector2;
import flixel.util.FlxColor;
import utilities.DebugLine;
import flixel.util.FlxTimer;
import echo.Body;
import echo.Line;
import states.PlayState;
import utilities.HxFuncs;

using echo.FlxEcho;

/**
 * Autonomous Entity.
 */
class AutoEntity extends Entity {
	/**
	 * Number of environment sensors that agents have.
	 */
	public static inline final SENSORS_COUNT:Int = 6;

	/**
	 * Each sensor activates 5 input neurons: 
	 * - distanceToWall `0..1` distance to wall hit by sensor
	 * - distanceToEntity `0..1` distance to entity hit by sensor
	 * - distanceToResource `0..1` distance to resource hit by sensor
	 * - entityEnergy `0..1` the amount of energy of the hit entity (if any)
	 * - supplyAmount `0..1` the amount of the hit resource (if any)
	 * 
	 * Shorter distance = higher activation and vice versa.
	 */
	public static inline final SENSORS_INPUTS:Int = SENSORS_COUNT * 5;

	/**
	 * How often the sensors are cast.
	 * 
	 * The `sense()` function will be run by the `senserTimer` each `SENSORS_TICK` seconds.
	 */
	public static inline final SENSORS_TICK:Float = 0.1;

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
	var brain:MLP;

	/**
	 * The timer that will `sense()` each `SENSORS_TICK` seconds.
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

	public function new(_x:Float, _y:Float, _width:Int, _height:Int) {
		super(_x, _y, _width, _height);

		isCamTarget = false;

		var rot = FlxG.random.float(20, 130);
		possibleRotations = new FlxRange(-rot, rot);

		sensorsRotations = [
			for (i in 0...SENSORS_COUNT) {
				switch (i) {
					case 0:
						possibleRotations.start;
					case 1:
						possibleRotations.start + (possibleRotations.end / 2);
					case 2:
						possibleRotations.start + (possibleRotations.end - (possibleRotations.end / 10));
					case 3:
						possibleRotations.end + (possibleRotations.start + (possibleRotations.end / 10));
					case 4:
						possibleRotations.end + (possibleRotations.start / 2);
					case 5:
						possibleRotations.end;
					default:
						0;
				}
			}
		];

		sensorsLengths = [
			for (i in 0...SENSORS_COUNT) {
				switch (i) {
					case 0:
						120;
					case 1:
						135;
					case 2:
						160;
					case 3:
						160;
					case 4:
						135;
					case 5:
						120;
					default:
						100;
				}
			}
		];

		sensors = [for (i in 0...SENSORS_COUNT) null]; // fill the sensors array with nulls

		senserTimer = new FlxTimer();
		senserTimer.start(SENSORS_TICK, (_) -> sense(), 0);

		brain = new MLP(SENSORS_INPUTS // number of input neurons dedicated to sensors
			+ 1 // own energy level neuron
			+ 1 // bias neuron that's always firing 1
			, 4 // hidden layer
			, 2); // output layer, for now thrust and rotation

		brainInputs = [for (i in 0...brain.inputLayerSize) 0];
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		// act();
	}

	/**
	 * Get information about the environment from the sensors.
	 * 
	 * Called periodically by the `senserTimer`.
	 */
	function sense() {
		var sensorInputs = [for (i in 0...SENSORS_INPUTS) 0.];
		// we need an array of bodies for the linecast
		var bodiesArray:Array<Body> = PlayState.collidableBodies.get_group_bodies();

		if (isCamTarget)
			DebugLine.clearCanvas(); // clear previously drawn lines

		for (i in 0...sensors.length) { // do this for each sensor
			sensors[i] = Line.get(); // init the sensor
			// create a vector to subtract from the body's position in order to to gain a relative offset
			var relOffset = Vector2.fromPolar(MathUtil.degToRad(body.rotation + sensorsRotations[i]), SENSORS_DISTANCE); // radius is distance from body

			var sensorPos = body.get_position()
				.addWith(relOffset); // this body's pos added with the offset will give us a sensor starting position out of the body

			// set the actual sensors position,rotation, and length
			sensors[i].set_from_vector(sensorPos, body.rotation + sensorsRotations[i], sensorsLengths[i]);
			// cast the line, returning all intersections
			var hit = sensors[i].linecast(bodiesArray);
			if (hit != null) { // if we hit something
				sensorInputs[i] = hit.body.bodyType; // put it in the array
				var lineColor = FlxColor.RED;
				switch (hit.body.bodyType) {
					case 1: // hit a wall
						lineColor = FlxColor.YELLOW;
						sensorInputs[i] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToWall neuron
					case 2: // hit an agent
						lineColor = FlxColor.MAGENTA;
						sensorInputs[i + 1] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToEntity neuron
						var agent = cast(hit.body.get_object(), AutoEntity);
						sensorInputs[i + 3] = HxFuncs.map(agent.currEnergy, 0, agent.maxEnergy, 0, 1); // put agent's energy amount in entityEnergy neuron
					case 3: // hit a resource
						lineColor = FlxColor.CYAN;
						sensorInputs[i + 2] = invDistanceTo(hit, sensorsLengths[i]); // put distance in distanceToResource neuron
						var supp = cast(hit.body.get_object(), Supply);
						sensorInputs[i + 4] = HxFuncs.map(supp.currAmount, 0, Supply.MAX_START_AMOUNT, 0, 1); // put supply's amount in supplyAmount neuron
					case unknown: // hit unknown
						lineColor = FlxColor.BROWN;
						sensorInputs[i] = 0;
						sensorInputs[i + 1] = 0;
						sensorInputs[i + 2] = 0;
						sensorInputs[i + 3] = 0;
						sensorInputs[i + 4] = 0;
				}
				if (isCamTarget)
					DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y, lineColor, 2);
			} else { // if we didn't hit anything
				// reflect it in the array
				sensorInputs[i] = 0;
				sensorInputs[i + 1] = 0;
				sensorInputs[i + 2] = 0;
				sensorInputs[i + 3] = 0;
				sensorInputs[i + 4] = 0;

				if (isCamTarget)
					DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y);
			}
			sensors[i].put(); // put the linecast
		}
		// put mapped sensor inputs into array of inputs
		brainInputs = [
			for (input in sensorInputs)
				HxFuncs.map(input, 0, 3, 0, 1)
		];

		// add input neuron for current energy level
		brainInputs = brainInputs.concat([HxFuncs.map(currEnergy, 0, maxEnergy, 0, 1)]);

		// add bias neuron at the end
		brainInputs = brainInputs.concat([1]);
	}

	function act() {
		// decide how to act based on current inputs
		var brainOutputs = brain.feedForward(brainInputs);

		move(brainOutputs[0]);
		rotate(brainOutputs[1]);
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
		return HxFuncs.map(_inters.closest.distance, 0, _maxDistance, 1, 0);
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
						possibleRotations.start + (possibleRotations.end - (possibleRotations.end / 10));
					case 3:
						possibleRotations.end + (possibleRotations.start + (possibleRotations.end / 10));
					case 4:
						possibleRotations.end + (possibleRotations.start / 2);
					case 5:
						possibleRotations.end;
					default:
						0;
				}
			}
		];
	}

	override function kill() {
		super.kill();
		if (senserTimer.active) {
			senserTimer.cancel();
			senserTimer.destroy();
		}
	}
}

// make them eat, attack, lose energy etc
// measure of fitness (lifetime/energy)
