package entities;

import echo.data.Types.ForceType;
import PlayState;
import flixel.util.FlxTimer;
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
	public static inline final MAX_VELOCITY = 50;

	/**
	 * Maximum rotational velocity that this `Entity`'s physics body can reach.
	 */
	public static inline final MAX_ROTATIONAL_VELOCITY = 50;

	/**
	 * Maximum amount that this `Entity` can change its rotation by.
	 */
	public static inline final MAX_ROTATION_AMOUNT = 7;

	/**
	 * The maximum amount that this entity's `age` can reach.
	 */
	public static inline final MAX_AGE = 8;

	/**
	 * The age value at which an entity is considered old.
	 */
	public static inline final OLD_AGE = 6;

	/**
	 * Default color of entities on the colorwheel.
	 */
	public static inline final BASE_HUE = 60;

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
	 * Maximum amount of `energy` this entity can have.
	 */
	public var maxEnergy(default, null):Float;

	/**
	 * Current amount of `energy` this entity has.
	 * 
	 * `energy` is used to move, attack, eat...
	 * 
	 * and is replenished by eating.
	 */
	public var currEnergy(default, null):Float;

	/**
	 * The fitness score of this entity.
	 * 
	 * This variable is increased over time by an amount proportionate to the entity's energy level.
	 */
	public var fitnessScore(default, null):Float;

	/**
	 * Whether this entity is currently trying to bite what it comes in contact with (`biteAmount > 0`).
	 * 
	 * And how hard it is currently trying to bite, `0.1..1`.
	 * 
	 * Any value of 0 or less means the entity isn't trying to bite.
	 */
	public var biteAmount(default, null):Float;

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

	/**
	 * Set to false when entity dashes and reset shortly after.
	 */
	var canDash:Bool;

	/**
	 * The amount of energy this entity has ingested until its death.
	 */
	public var energyEaten(default, null):Float;

	/**
	 * This entity's current age.
	 * 
	 * Incremented every `n` seconds, when this variable's value reaches `MAX_AGE` the entity dies.
	 */
	var age:Int;

	/**
	 * Timer used for the poison effect.
	 */
	var poisonTimer:FlxTimer;

	public function new() {
		super();
	}

	/**
	 * Initialise the Entity by adding body, setting color and values.
	 */
	public function init(_x:Float, _y:Float, _width:Int, _height:Int, ?_connections:Array<Float>, _bodyType:Int = 2) {
		x = _x;
		y = _y;
		makeGraphic(_width, _height, FlxColor.WHITE);

		colorHue = BASE_HUE;

		canBeDepleted = true;
		canDash = true;

		var move = 3;
		moveRange = new FlxRange<Float>(0, move);
		var rot = MAX_ROTATION_AMOUNT;
		rotationRange = new FlxRange<Float>(-rot, rot);

		/// BODY
		this.add_body({
			shape: {
				type: RECT,
				width: _width,
				height: _height
			},
			max_velocity_length: MAX_VELOCITY,
			max_rotational_velocity: MAX_ROTATIONAL_VELOCITY,
		}).bodyType = _bodyType; // info used by environment sensors
		body = this.get_body();
		body.rotation = FlxG.random.int(0, 360);

		energyEaten = 0;
		biteAmount = 0.9;
		absorption = 10;
		maxEnergy = 700;
		currEnergy = maxEnergy;
		fitnessScore = 0;
		age = 0;

		var fitnessTimer = new FlxTimer().start(1, function(_) calculateFitness(), 0);
		var ageTimer = new FlxTimer().start(10, function(_) calculateAge(), 0);
		poisonTimer = new FlxTimer();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		/* control the entity yourself
			if (FlxG.keys.pressed.W) {
				move(0.8);
			} else if (FlxG.keys.pressed.S) {
				move(-0.8);
			}

			controlBite(0);
			if (FlxG.keys.pressed.F) {
				controlBite(0.2);
			}

			controlDash(0.5);
			if(FlxG.keys.pressed.SHIFT){
				controlDash(0.7);
			}

			if (FlxG.keys.pressed.A) {
				rotate(-1);
			} else if (FlxG.keys.pressed.D) {
				rotate(1);
			} else {
				rotate(0);
			}
		 */
	}

	/**
	 * Pushes the entity's `body` forward/backward along its axis based on the mapped value of `_moveAmount`.
	 * 
	 * @param _moveAmount how much to move forward or backwards (-1 to 1)
	 */
	public function move(_moveAmount:Float) {
		var mappedMoveAmt = HxFuncs.map(_moveAmount, -1, 1, moveRange.start, moveRange.end);

		mappedMoveAmt += HxFuncs.map(currEnergy, 0, maxEnergy, 4, 0);

		body.push(mappedMoveAmt, true, ForceType.POSITION);
	}

	/**
	 * Rotates this entity's `body` left based on the mapped value of `_rotationAmount`.
	 * 
	 * @param _rotationAmount how much to rotate left (-1 to 1)
	 */
	public function rotateL(_rotationAmount:Float) {
		var mappedRotationAmt = 0.;
		
		mappedRotationAmt = HxFuncs.map(_rotationAmount, -1, 1, rotationRange.start, rotationRange.end);
		body.rotation -= mappedRotationAmt;
	}

	/**
	 * Rotates this entity's `body` right based on the mapped value of `_rotationAmount`.
	 * 
	 * @param _rotationAmount how much to rotate right (-1 to 1)
	 */
	public function rotateR(_rotationAmount:Float) {
		var mappedRotationAmt = 0.;
		
		mappedRotationAmt = HxFuncs.map(_rotationAmount, -1, 1, rotationRange.start, rotationRange.end);
		body.rotation += mappedRotationAmt;
	}

	/**
	 * Receives bite input from the network and tries to bite using energy.
	 * 
	 * If enough activation [`> 0`] is received from the network the entity uses energy to bite.
	 * 
	 * @param _activation how much the brain would like to bite, if at all
	 */
	public function controlBite(_activation:Float) {
		if (_activation > 0) {
			biteAmount = _activation;
		} else {
			biteAmount = 0;
		}
		refreshColor();
	}

	/**
	 * Receives dash input from the network and tries to dash using energy.
	 * 
	 * If enough activation [`> 0`] is received from the network the entity uses energy to dash.
	 * 
	 * @param _activation how much the brain would like to dash, if at all
	 */
	public function controlDash(_activation:Float) {
		if (_activation > 0.5) {
			if (canDash) {
				if (useEnergy(50)) { // lots of energy required to dash
					body.push(moveRange.end, true, VELOCITY);
					canDash = false;

					var t = new FlxTimer().start(0.3, function(_) {
						canDash = true;
					});
				}
			}
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

		energyEaten += _energyAmount; // keep track of energy eaten for fitness
		increaseFitnessSc(_energyAmount); // increase fitness by how much we ate

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
	 * If the entity had energy to use `true` is returned and the action goes through.
	 * 
	 * @param _energyAmount the amount of energy we want to subtract from `currEnergy`
	 * @return `true` if the depletion was successful, `false` if the entity had 0 or less energy left
	 */
	public function useEnergy(_energyAmount:Float):Bool {
		_energyAmount = Math.abs(_energyAmount);

		if (currEnergy > 0) {
			currEnergy -= _energyAmount; // deplete by the amount
			refreshColor();
			return true;
		} else {
			return false;
		}
	}

	function calculateFitness() {
		if (FlxEcho.updates) {
			increaseFitnessSc(HxFuncs.map(currEnergy, 0, maxEnergy, 0, 1));
		}
	}

	/**
	 * Increases the `fitnessScore` by a set amount.
	 * @param _amount how much we want to increase `fitnessScore` by
	 */
	function increaseFitnessSc(_amount:Float) {
		fitnessScore += _amount;
	}

	function refreshColor() {
		if (!canBeDepleted) {
			colorHue = HURT_HUE;
		} else if (biteAmount > 0) {
			colorHue = 170;
		} else {
			colorHue = BASE_HUE;
		}

		var sat = HxFuncs.map(currEnergy, 0, maxEnergy, 0.25, 1);
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
			canBeDepleted = false;
			refreshColor();
			var t = new FlxTimer().start(0.15, (_) -> {
				canBeDepleted = true;
				refreshColor();
			});

			if (_amount <= currEnergy) {
				currEnergy -= _amount;
				depAmt = _amount; // we depleted the full amount
			} else {
				depAmt = currEnergy; // we depleted what was left
				currEnergy = 0;
			}
		}

		return depAmt;
	}

	public function getPoisoned() {
		if (poisonTimer.active) {
			poisonTimer.loops += 2;
		} else {
			deplete(50);
			poisonTimer.start(0.5, function(_) deplete(200), 3);
		}
	}

	/**
	 * Increases the entity's `age` or kills it for old age if `MAX_AGE` is reached.
	 * 
	 * The entity isn't actually killed, rather its `currEnergy` is set to 0 so that it will be swept up by `PlayState.cleanupDeadAgents()`.
	 */
	function calculateAge() {
		if (FlxEcho.updates) {
			if (currEnergy > 0) {
				if (age < MAX_AGE) {
					age++;

					#if debug
					trace('age incremented to ${age}');
					#end

					if (age == 6) {
						PlayState.oldenCounter++;
					}
				} else {
					currEnergy = 0;
					biteAmount = 0;

					color = FlxColor.GREEN;

					#if debug
					trace('entity died of old age');
					#end
				}
			}
		}
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		poisonTimer.cancel();
		this.remove_from_group(PlayState.collidableBodies);
		this.remove_from_group(PlayState.entitiesCollGroup);
		body.remove_body();
		super.kill();
	}
}
