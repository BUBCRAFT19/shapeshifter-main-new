package;

import flixel.FlxSprite;

using StringTools;

class BGSprite extends FlxSprite
{
	public function new(posX:Float, posY:Float, path:String = '', animations:Array<Animation>, scrollX:Float = 1, scrollY:Float = 1, antialiasing:Bool = true,
			active:Bool = true)
	{
		super(posX, posY);

		var hasAnimations:Bool = animations != null;

		if (path != '')
		{
			if (hasAnimations)
			{
				frames = Paths.getSparrowAtlas(path);
				for (i in 0...animations.length)
				{
					var curAnim = animations[i];
					if (curAnim != null)
					{
						if (curAnim.indices != null)
						{
							animation.addByIndices(curAnim.name, curAnim.prefixName, curAnim.indices, "", curAnim.frames, curAnim.looped, curAnim.flip[0],
								curAnim.flip[1]);
						}
						else
						{
							animation.addByPrefix(curAnim.name, curAnim.prefixName, curAnim.frames, curAnim.looped, curAnim.flip[0], curAnim.flip[1]);
						}
					}
				}
			}
			else
			{
				loadGraphic(Paths.image(path));
			}
		}
		this.antialiasing = antialiasing;
		scrollFactor.set(scrollX, scrollY);
		this.active = active;
	}
}
