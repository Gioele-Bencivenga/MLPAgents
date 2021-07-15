package supplies;

import PlayState;
import flixel.util.FlxColor;
import utilities.HxFuncs;
import echo.Body;
import flixel.FlxG;
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
	 * Current amount of resource there is.
	 */
	public var currAmount(default, null):Float;

	/**
	 * Starting amount of resource there was when creating it.
	 */
	public var startAmount(default, null):Float;

	public function new() {
		super();
	}

	/**
	 * Initializes the resource.
	 */
	public function init(_x:Float, _y:Float, _minStartAmt:Int = 20, _maxStartAmt:Int = MAX_START_AMOUNT, _bodyType:Int = 3) {
		x = _x;
		y = _y;

		startAmount = FlxG.random.int(_minStartAmt, _maxStartAmt);
		currAmount = startAmount;

		makeGraphic(Std.int(currAmount), Std.int(currAmount), FlxColor.WHITE);
		color = FlxColor.MAGENTA;

		this.add_body({
			shape: {
				type: CIRCLE,
				radius: currAmount / 2
			}
		}).bodyType = _bodyType;
		body = this.get_body();

		refreshSize();
	}

	/**
	 * Depletes the supply's `currAmount` by `_amount`, flips `canBeDepleted` to `false`.
	 * 
	 * @param _amount the amount we want to deplete the supply by
	 * @return the amount of resource that was actually depleted
	 */
	public function deplete(_amount:Float):Float {
		var depAmt = 0.;

		if (_amount <= currAmount) {
			currAmount -= _amount;
			depAmt = _amount; // we got out as much as we bit
		} else {
			depAmt = currAmount; // we got out what was left
			currAmount = 0;
			kill();
		}

		refreshSize();

		return depAmt;
	}

	override function update(elapsed:Float) {
		if (FlxEcho.updates) {
			super.update(elapsed);
		}
	}

	/**
	 * Sets the `width` and `height` of the object according to its `currAmount`.
	 */
	function refreshSize() {
		body.scale_x = HxFuncs.map(currAmount, 0, startAmount, 0.5, 1);
		body.scale_y = HxFuncs.map(currAmount, 0, startAmount, 0.5, 1);
		scale.x = HxFuncs.map(currAmount, 0, startAmount, 0.5, 1);
		scale.y = HxFuncs.map(currAmount, 0, startAmount, 0.5, 1);
	}

	/**
	 * Killing this object will also remove its physics body.
	 */
	override function kill() {
		PlayState.eatenResources++;
		this.remove_from_group(PlayState.collidableBodies);
		this.remove_from_group(PlayState.entitiesCollGroup);
		body.remove_body();
		super.kill();
	}
}
