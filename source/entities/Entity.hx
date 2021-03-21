package entities;

import flixel.util.FlxTimer;
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
	 * Default color of entities on the colorwheel.
	 */
	public static inline final BASE_HUE = 50;

	/**
	 * Color of hurt entities on the colorwheel.
	 */
	public static inline final HURT_HUE = 0;

	/**
	 * The color of this sprite from the colorwheel.
	 */
	var colorHue:Float;

	/**
	 * Reference to this entity's physics body.
	 */
	public var body:Body;

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

	/**
	 * Whether this entity is currently trying to bite what it comes in contact with (`biteAmount > 0`).
	 * 
	 * And how hard it is currently trying to bite, `0.1..1`.
	 * 
	 * Any value of 0 or less means the entity isn't trying to bite.
	 */
	public var biteAmount(default, null):Float;

	/**
	 * How much this entity "bites".
	 * 
	 * Which is the amount we deplete from the resource/entity when biting it.
	 */
	public var bite(default, null):Float;

	/**
	 * Multiplier applied to the amount of energy this entity eats.
	 * 
	 * Higher absorption means the entity will get more energy from the same amount of resource.
	 */
	public var absorption(default, null):Float;

	/**
	 * Whether this entity's energy can be absorbed by other entities.
	 */
	var canBeDepleted:Bool;

	public function new(_x:Float, _y:Float, _width:Int, _height:Int) {
		super(_x, _y);
		makeGraphic(_width, _height, FlxColor.WHITE);
		colorHue = BASE_HUE;

		canBeDepleted = true;

		moveRange = new FlxRange<Float>(-400, 400);
		rotationRange = new FlxRange<Float>(-300, 300);

		/// BODY
		this.add_body({
			mass: FlxG.random.float(0.1, 0.5),
			drag_length: FlxG.random.float(300, 500),
			rotational_drag: FlxG.random.float(40, 60),
			max_velocity_length: Entity.MAX_VELOCITY,
			max_rotational_velocity: Entity.MAX_ROTATIONAL_VELOCITY,
		}).bodyType = 2; // info used by environment sensors
		body = this.get_body();

		biteAmount = 0;
		bite = FlxG.random.float(5, 10);
		absorption = FlxG.random.float(5, 10);
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
		if (useEnergy(_moveAmount)) { // if the energy is successfully expended
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
		if (useEnergy(_rotationAmount / 2)) { // less energy is require to rotate
			var mappedRotationAmt = HxFuncs.map(_rotationAmount, -1, 1, rotationRange.start, rotationRange.end);

			body.rotational_velocity = mappedRotationAmt;
		}
	}

	/**
	 * Receives bite input from the network and tries to bite using energy.
	 * 
	 * If enough activation (`>0`) is received from the network the entity uses energy to bite accordingly.
	 * 
	 * @param _biteAmount how much the brain would like to bite, if at all
	 */
	public function controlBite(_biteAmount:Float) {
		if (_biteAmount > 0) {
			if (useEnergy(_biteAmount * 2)) {
				biteAmount = _biteAmount;
			} else {
				biteAmount = 0;
			}
		} else {
			biteAmount = 0;
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
	 * Uses the entity's `currEnergy`, usually to perform an action.
	 * 
	 * If enough energy is used `true` is returned and the action goes through.
	 * 
	 * @param _energyAmount the amount of energy we want to subtract from `currEnergy`
	 * @return `true` if the depletion was successful, `false` if there wasn't enough energy to deplete
	 */
	public function useEnergy(_energyAmount:Float):Bool {
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
	 * Depletes the entity's `currEnergy` by `_amount`, flips `canBeDepleted` to `false`.
	 * 
	 * @param _amount the amount we want to deplete the energy by
	 * @return the amount of energy that was depleted
	 */
	public function deplete(_amount:Float):Float {
		var depAmt = 0.;
		if (canBeDepleted) {
			colorHue = HURT_HUE;
			canBeDepleted = false;

			if (_amount <= currEnergy) {
				currEnergy -= _amount;
				depAmt = _amount; // we got out as much as we bit
			} else {
				depAmt = currEnergy; // we got out what was left
				currEnergy = 0;
			}

			refreshColor();
			var t = new FlxTimer().start(0.4, (_) -> {
				canBeDepleted = true;
				colorHue = BASE_HUE;
			});
		}

		return depAmt;
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
