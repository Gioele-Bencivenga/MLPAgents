package entities;

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
	public static inline final MAX_VELOCITY = 500;

	/**
	 * Maximum rotational velocity that this `Entity`'s physics body can reach.
	 */
	public static inline final MAX_ROTATIONAL_VELOCITY = 1000;

	/**
	 * The desired velocity vector this `Entity` has regarding the target it wants to reach.
	 */
	var desiredDirection:Vector2;

	/**
	 * The actual direction of the `Entity`, calculated from subtracting the desired and actual velocity of this entity.
	 */
	var direction:Vector2;

	/**
	 * Whether the `Entity` can move or not.
	 */
	var canMove:Bool;

	/**
	 * Whether the `Entity` is moving or not.
	 */
	var isMoving:Bool;

	/**
	 * Maximum speed an `Entity` can move at.
	 */
	var maxSpeed:Float;

	/**
	 * Maximum speed at which the `Entity` is able to react to vector changes.
	 */
	var maxReactionSpeed:Float;

	/**
	 * Reference to this entity's physics body.
	 */
	public var body:Body;

	public function new(_x:Float, _y:Float, _width:Int, _height:Int, _color:Int) {
		super(_x, _y);
		makeGraphic(_width, _height, _color);

		canMove = true;
		maxSpeed = 350;
		maxReactionSpeed = 5000;

		/// BODY
		this.add_body({
			mass: 1,
			drag_length: 10,
			rotational_drag: 5,
			max_velocity_length: Entity.MAX_VELOCITY,
			max_rotational_velocity: Entity.MAX_ROTATIONAL_VELOCITY,
		}).bodyType = 2; // info returned by environment sensors
		body = this.get_body();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.pressed.W) {
			body.push(100, true);
		}

		if (FlxG.keys.pressed.A) {
			body.rotational_velocity = -50;
		} else if (FlxG.keys.pressed.D) {
			body.rotational_velocity = 50;
		} else{
			body.rotational_velocity = 0;
		}
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		super.kill();
		body.remove_body();
		//body.dispose(); is this needed?
	}
}
