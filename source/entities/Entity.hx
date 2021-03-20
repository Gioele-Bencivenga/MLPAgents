package entities;

import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import utilities.HxFuncs;
import flixel.util.helpers.FlxRange;
import flixel.FlxG;
import echo.Body;
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
	 * The color of this sprite from the colorwheel.
	 */
	var colorHue:Float;

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

	/**
	 * Maximum amount of `energy` this entity has.
	 */
	public var maxEnergy(default, null):Float;

	/**
	 * Current amount of `energy` this entity has.
	 * 
	 * `energy` is used to move, attack, eat...
	 * 
	 * and is replenished by eating and resting.
	 */
	public var currEnergy(default, null):Float;

	public function new(_x:Float, _y:Float, _width:Int, _height:Int) {
		super(_x, _y);
		makeGraphic(_width, _height, FlxColor.WHITE);
		colorHue = 45;

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

		maxEnergy = FlxG.random.float(500, 1000);
		currEnergy = maxEnergy;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.keys.pressed.W) {
			move(0.8);
		} else if (FlxG.keys.pressed.S) {
			move(-0.8);
		}

		if (FlxG.keys.pressed.F) {}

		if (FlxG.keys.pressed.A) {
			rotate(-0.8);
		} else if (FlxG.keys.pressed.D) {
			rotate(0.8);
		} else {
			rotate(0);
		}
	}

	/**
	 * Pushes the entity forward/backward along its axis based on the mapped value of `_moveAmount`, if it has enough energy.
	 * 
	 * Also depletes the entity's energy by `_moveAmount`.
	 * 
	 * @param _moveAmount how much to move forward or backwards (-1 to 1), and how much energy will be depleted
	 */
	public function move(_moveAmount:Float) {
		if (depleteEnergy(_moveAmount)) { // if the energy is successfully expended
			var mappedMoveAmt = HxFuncs.map(_moveAmount, -1, 1, moveRange.start, moveRange.end);

			body.push(mappedMoveAmt, true);
		}
	}

	/**
	 * Rotates a `body` left/right based on the mapped value of `_rotationAmount`.
	 * 
	 * @param _rotationAmount how much to rotate left or right (-1 to 1)
	 */
	public function rotate(_rotationAmount:Float) {
		if (depleteEnergy(_rotationAmount / 2)) { // less energy is require to rotate
			var mappedRotationAmt = HxFuncs.map(_rotationAmount, -1, 1, rotationRange.start, rotationRange.end);

			body.rotational_velocity = mappedRotationAmt;
		}
	}

	/**
	 * Replenishes the entity's `currEnergy` by an absolute amount.
	 * 
	 * @param _energyAmount the amount of energy we want to add to `currEnergy`
	 * @return `true` if the current energy amount reached `maxEnergy`, `false` if we just increased it
	 */
	public function replenishEnergy(_energyAmount:Float):Bool {
		_energyAmount = Math.abs(_energyAmount);

		if (currEnergy <= maxEnergy - _energyAmount) { // if the amount doesn't exceed our max
			currEnergy += _energyAmount; // increase by the amount

			refreshColor();
			return false;
		} else { // if the amount would exceed
			currEnergy = maxEnergy; // just reach the max

			refreshColor();
			return true;
		}
	}

	/**
	 * Depletes the entity's `currEnergy` by an absolute amount.
	 * 
	 * @param _energyAmount the amount of energy we want to subtract from `currEnergy`
	 * @return `true` if the depletion was successful, `false` if there wasn't enough energy to deplete
	 */
	function depleteEnergy(_energyAmount:Float):Bool {
		_energyAmount = Math.abs(_energyAmount);

		if (currEnergy >= _energyAmount) { // if we have enough energy to deplete
			currEnergy -= _energyAmount; // deplete by the amount

			refreshColor();

			return true;
		} else {
			return false;
		}
	}

	function refreshColor() {
		var sat = HxFuncs.map(currEnergy, 0, maxEnergy, 0, 1);
		var bri = HxFuncs.map(currEnergy, 0, maxEnergy, 0.65, 1);
		var newCol = new FlxColor();
		newCol.setHSB(colorHue, sat, bri, 1);
		color = newCol;
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
