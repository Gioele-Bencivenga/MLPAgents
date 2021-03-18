package;

import flixel.util.FlxColor;
import flixel.FlxG;
import states.PlayState;
import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite {
	public function new() {
		super();
		addChild(new FlxGame(1366, 768, PlayState, 1, 60, 60, true)); // set to true to run in fullscreen
		addChild(new openfl.display.FPS(5, 300, FlxColor.GREEN)); // fps display

		/* we use the system cursor instead of the default one
			as it reduces cursor lag on some systems */
		FlxG.mouse.useSystemCursor = true;
	}
}
