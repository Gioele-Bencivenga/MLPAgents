package supplies;

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
	public static inline final MAX_START_AMOUNT = 50;

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

	public function new(_x:Float, _y:Float, _color:Int, _minStartAmt:Int = 10, _maxStartAmt:Int = MAX_START_AMOUNT) {
		super(_x, _y);

		canBeDepleted = true;

		startAmount = FlxG.random.int(_minStartAmt, _maxStartAmt);
		currAmount = startAmount;

		makeGraphic(Std.int(currAmount), Std.int(currAmount), _color);

		this.add_body({
			mass: HxFuncs.map(currAmount, 0, MAX_START_AMOUNT, 0, 0.6),
			drag_length: 200,
			rotational_drag: 60
		}).bodyType = 3;
		body = this.get_body();
	}

	/**
	 * Depletes the supply's `currAmount` by `_amount`, flips `canBeDepleted` to `false` until the damage feedback ends.
	 * 
	 * @param _amount the amount we want to deplete the supply by
	 * @return the amount of resource that was actually depleted
	 */
	public function deplete(_amount:Float):Float {
		var depAmt = 0.;
		if (canBeDepleted) {
			canBeDepleted = false;

			if (currAmount >= _amount) {
				currAmount -= _amount;
				depAmt = _amount; // we got out as much as we bit
			} else {
				depAmt = currAmount; // we got out what was left
				currAmount = 0;
			}

			updateSize();
		}

		return depAmt;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
	}

	/** Having problems with this
	 * Sets the `width` and `height` of the object according to its `currAmount`. 
	 * 
	 * Flips `canBeDepleted` back to `true` when done.
	 */
	function updateSize() {
		FlxTween.tween(this, {
			width: currAmount,
			height: currAmount
		}, 0.2, {
			ease: FlxEase.sineIn,
			onComplete: function(_) {
				canBeDepleted = true;
			}
		});
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		super.kill();
		this.get_body().remove_body();
	}
}
