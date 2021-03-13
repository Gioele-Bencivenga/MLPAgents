package entities;

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
	public static inline final SENSORS_COUNT = 6;

	/**
	 * How often the sensors are cast.
	 * 
	 * The `sense()` function will be run by the `senserTimer` each `SENSORS_TICK` seconds.
	 */
	public static inline final SENSORS_TICK = 0.13;

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
	 * These values have already been mapped to a range between -1 and 1.
	 */
	var brainInputs:Array<Float>;

	public function new(_x:Float, _y:Float, _width:Int, _height:Int, _color:Int) {
		super(_x, _y, _width, _height, _color);

		isCamTarget = false;

		possibleRotations = new FlxRange(-65., 65.);

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

		brain = new MLP(6, 4, 2);

		brainInputs = [for (i in 0...brain.inputLayer.length) 0];
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		act();
	}

	/**
	 * Get information about the environment from the sensors.
	 * 
	 * Called periodically by the `senserTimer`.
	 */
	function sense() {
		var sensorInputs = [for (i in 0...brain.inputLayer.length) 0.];
		// we need an array of bodies for the linecast
		var bodiesArray:Array<Body> = PlayState.collidableBodies.get_group_bodies();

		if (isCamTarget)
			DebugLine.clearCanvas(); // clear previously drawn lines

		for (i in 0...sensors.length) { // do this for each sensor
			sensors[i] = Line.get(); // init the sensor
			// create a vector to subtract from the body's position in order to to gain a relative offset
			var relOffset = Vector2.fromPolar(MathUtil.degToRad(this.get_body().rotation + sensorsRotations[i]),
				(this.get_body().shape.bounds().height / 2) + 10); // radius is distance from body
			var sensorPos = this.get_body()
				.get_position()
				.addWith(relOffset); // this body's pos added with the offset will give us a sensor starting position out of the body
			// set the actual sensors position
			sensors[i].set_from_vector(sensorPos, this.get_body().rotation + sensorsRotations[i], sensorsLengths[i]);
			// cast the line, returning all intersections
			var hit = sensors[i].linecast(bodiesArray);
			if (hit != null) { // if we hit something
				sensorInputs[i] = hit.body.bodyType; // put it in the array
				var lineColor = FlxColor.RED;
				switch (hit.body.bodyType) {
					case 1: // hit a Tile (wall)
						lineColor = FlxColor.YELLOW;
					case 2: // hit an Entity
						lineColor = FlxColor.MAGENTA;
					case 3: // hit a Supply
						lineColor = FlxColor.CYAN;
					default: // hit unknown
						lineColor = FlxColor.BROWN;
				}
				if (isCamTarget)
					DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y, lineColor, 1.5);
			} else { // if we didn't hit anything
				sensorInputs[i] = 0; // reflect it in the array
				if (isCamTarget)
					DebugLine.drawLine(sensors[i].start.x, sensors[i].start.y, sensors[i].end.x, sensors[i].end.y);
			}
			sensors[i].put();
		}
		// put mapped inputs into array
		// we only update the sensors each sense(),
		// but the MLP keeps processing inputs
		brainInputs = [
			for (input in sensorInputs)
				HxFuncs.map(input, 0, 3, -1, 1)
		];
	}

	function act() {
		// decide how to act based on current inputs
		var brainOutputs = brain.feedForward(brainInputs);

		move(brainOutputs[0]);
		rotate(brainOutputs[1]);
	}

	override function kill() {
		super.kill();
		if (senserTimer.active) {
			senserTimer.cancel();
			senserTimer.destroy();
		}
	}
}
