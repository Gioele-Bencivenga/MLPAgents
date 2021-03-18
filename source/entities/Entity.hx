package entities;

import utilities.HxFuncs;
import flixel.util.helpers.FlxRange;
import flixel.FlxG;
import echo.Body;
import hxmath.math.MathUtil;
import flixel.math.FlxVector;
import hxmath.math.Vector2;
import flixel.FlxSprite;

using echo.FlxEcho;

class Entity extends FlxSprite {
	/**
	 * Maximum velocity that this `Entity`'s physics body can reach.
	 */
	public static inline final MAX_VELOCITY = 200;

	/**
	 * Maximum rotational velocity that this `Entity`'s physics body can reach.
	 */
	public static inline final MAX_ROTATIONAL_VELOCITY = 500;

	/**
	 * Reference to this entity's physics body.
	 */
	public var body:Body;

	/**
	 * Whether the `Entity` can move or not.
	 */
	var canMove:Bool;

	/**
	 * `start` = min move speed (set as negative to go backwards)
	 * 
	 * `end` = max move speed
	 */
	var moveRange:FlxRange<Float>;

	/**
	 * `start` = max anticlockwise rotation speed
	 * 
	 * `end` = max clockwise rotation speed
	 */
	var rotationRange:FlxRange<Float>;

	public function new(_x:Float, _y:Float, _width:Int, _height:Int, _color:Int) {
		super(_x, _y);
		makeGraphic(_width, _height, _color);

		canMove = true;
		moveRange = new FlxRange<Float>(-400, 400);
		rotationRange = new FlxRange<Float>(-300, 300);

		/// BODY
		this.add_body({
			mass: 0.3,
			drag_length: 400,
			rotational_drag: 50,
			max_velocity_length: Entity.MAX_VELOCITY,
			max_rotational_velocity: Entity.MAX_ROTATIONAL_VELOCITY,
		}).bodyType = 2; // info used by environment sensors
		body = this.get_body();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		
		if (FlxG.keys.pressed.W) {
			body.push(400, 0, true);
		}

		if (FlxG.keys.pressed.A) {
			body.rotational_velocity += -20;
		} else if (FlxG.keys.pressed.D) {
			body.rotational_velocity += 20;
		} else {
			body.rotational_velocity = 0;
		}
		
	}

	/**
	 * Pushes a `body` forward/backward along its axis based on the mapped value of `_moveAmount`.
	 * 
	 * @param _moveAmount how much to move forward or backwards (-1 to 1)
	 */
	public function move(_moveAmount:Float) {
		var mappedMoveAmt = HxFuncs.map(_moveAmount, -1, 1, moveRange.start, moveRange.end);

		body.push(mappedMoveAmt, true);
	}

	/**
	 * Rotates a `body` left/right based on the mapped value of `_rotationAmount`.
	 * 
	 * @param _rotationAmount how much to rotate left or right (-1 to 1)
	 */
	public function rotate(_rotationAmount:Float) {
		var mappedRotationAmt = HxFuncs.map(_rotationAmount, -1, 1, rotationRange.start, rotationRange.end);

		body.rotational_velocity = mappedRotationAmt;
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		super.kill();
		body.remove_body();
		// body.dispose(); is this needed?
	}
}
