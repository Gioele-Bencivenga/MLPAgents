package supplies;

import states.PlayState;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import utilities.HxFuncs;
import echo.Body;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;

using echo.FlxEcho;

/**
 * A Supply class that can be depleted via the `hurt()` function and that modifies its dimensions according to its quantity (represented by the `health` variable).
 */
class Supply extends FlxSprite {
	/**
	 * Maximum amount that any resource can start from when created.
	 */
	public static inline final MAX_START_AMOUNT = 40;

	/**
	 * This supply's body.
	 */
	public var body(default, null):Body;

	/**
	 * Whether `hurt()` can be called on the object or not.
	 *
	 * This gets flipped to `false` as soon as `hurt()` is called and gets flipped back to `true` once the damage feedback ends.
	 */
	var canBeDepleted:Bool;

	/**
	 * Current amount of resource there is.
	 */
	public var currAmount(default, null):Float;

	/**
	 * Starting amount of resource there was when creating it.
	 */
	public var startAmount(default, null):Float;

	/**
	 * Tween that shrinks the size when depletion occurs.
	 */
	var sizeTween:FlxTween;

	public function new() {
		super();
	}

	/**
	 * Initializes the resource.
	 */
	public function init(_x:Float, _y:Float, _minStartAmt:Int = 15, _maxStartAmt:Int = MAX_START_AMOUNT) {
		x = _x;
		y = _y;

		canBeDepleted = true;

		startAmount = FlxG.random.int(_minStartAmt, _maxStartAmt);
		currAmount = startAmount;

		makeGraphic(Std.int(currAmount), Std.int(currAmount), FlxColor.WHITE);
		var newCol = new FlxColor();
		newCol.setHSB(310, 1, 1, 1);
		color = newCol;

		this.add_body({
			shape: {
				type: RECT,
				width: currAmount,
				height: currAmount
			},
			mass: HxFuncs.map(currAmount, 0, MAX_START_AMOUNT, 0, 0.6),
			drag_length: 200,
			rotational_drag: 60
		}).bodyType = 3;
		body = this.get_body();
	}

	/**
	 * Depletes the supply's `currAmount` by `_amount`, flips `canBeDepleted` to `false`.
	 * 
	 * @param _amount the amount we want to deplete the supply by
	 * @return the amount of resource that was actually depleted
	 */
	public function deplete(_amount:Float):Float {
		var depAmt = 0.;
		if (canBeDepleted) {
			canBeDepleted = false;

			if (_amount <= currAmount) {
				currAmount -= _amount;
				depAmt = _amount; // we got out as much as we bit
			} else {
				depAmt = currAmount; // we got out what was left
				currAmount = 0;
				kill();
			}

			refreshSize();
			var t = new FlxTimer().start(0.05, (_) -> {
				canBeDepleted = true;
			});
		}

		return depAmt;
	}

	override function update(elapsed:Float) {
		if (FlxEcho.updates) {
			super.update(elapsed);
		}
	}

	/**
	 * Sets the `width` and `height` of the object according to its `currAmount`. 
	 * 
	 * Flips `canBeDepleted` back to `true` when done.
	 */
	function refreshSize() {
		body.scale_x = HxFuncs.map(currAmount, 0, startAmount, 0.2, 1);
		body.scale_y = HxFuncs.map(currAmount, 0, startAmount, 0.2, 1);
		scale.x = HxFuncs.map(currAmount, 0, startAmount, 0.2, 1);
		scale.y = HxFuncs.map(currAmount, 0, startAmount, 0.2, 1);
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		super.kill();
		this.remove_from_group(PlayState.collidableBodies);
		this.remove_from_group(PlayState.entitiesCollGroup);
		body.remove_body();
	}
}
