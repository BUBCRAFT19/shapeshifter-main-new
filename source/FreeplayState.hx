package;

import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.FlxObject;
#if desktop
import Discord.DiscordClient;
#end
import editors.ChartingState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;
import flixel.system.FlxSound;
import openfl.utils.Assets as OpenFlAssets;
import WeekData;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;

	private static var curSelected:Int = 0;

	var curDifficulty:Int = -1;

	private static var lastDifficultyName:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var songTypes:Array<String> = ['main', 'covers'];

	private var iconArray:Array<HealthIcon> = [];
	private var titles:Array<FlxSprite> = [];
	private var icons:Array<FlxSprite> = [];

	var bg:FlxSprite;
	var bgClr:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;
	// D&B variables, lol
	private var inMainFreeplayState:Bool = false;
	private var curPackImage:Int = 0;
	var loadingPack:Bool = false;

	// camera stuff
	private static var prevCamFollow:FlxObject;

	private var camFollow:FlxObject;

	override function create()
	{
		// Paths.clearStoredMemory();
		// Paths.clearUnusedMemory();

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		bgClr = new FlxSprite().loadGraphic(Paths.image('freeplay/freeplayDesat'));
		bgClr.scrollFactor.set();
		bgClr.screenCenter();
		bgClr.antialiasing = ClientPrefs.globalAntialiasing;
		add(bgClr);

		bg = new FlxSprite().loadGraphic(Paths.image('freeplay/freeplayBG'));
		bg.scrollFactor.set();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		for (i in 0...songTypes.length)
		{
			// var songType:FlxSprite = new FlxSprite().loadGraphic(Paths.image('freeplay/images' + (songTypes[i].toLowerCase())));
			var songType:FlxSprite = new FlxSprite().loadGraphic(Paths.image('placeholder', 'shared'));
			songType.x = (1000 * i + 1) + (512 - songType.width);
			songType.y = (FlxG.height / 2) - 256;
			songType.antialiasing = ClientPrefs.globalAntialiasing;

			var typeNames:FlxSprite = new FlxSprite(0, -100).loadGraphic(Paths.image('freeplay/names/' + songTypes[i].toLowerCase(), 'preload'));
			typeNames.setGraphicSize(400);
			typeNames.updateHitbox();
			typeNames.x = (1000 * i + 1) + (512 - songType.width);
			typeNames.antialiasing = ClientPrefs.globalAntialiasing;

			add(songType);
			icons.push(songType);
			add(typeNames);
			titles.push(typeNames);
		}

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(icons[curPackImage].x + (icons[curPackImage].width / 2), icons[curPackImage].y + (icons[curPackImage].height / 2));

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0.04);
		FlxG.camera.focusOn(camFollow.getPosition());

		super.create();
	}

	public function loadProperPack()
	{
		WeekData.reloadWeekFiles(false);

		for (i in 0...WeekData.weeksList.length)
		{
			// This might work, it might not, idk. I'll check back in to see if it works -Ruv
			if (weekPackCheck(WeekData.weeksList[i]) != songTypes[curPackImage].toLowerCase())
				continue;

			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.loadTheFirstEnabledMod();
	}

	public function loadRealFreeplay()
	{
		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);
			songText.scrollFactor.set();

			if (songText.width > 980)
			{
				var textScale:Float = 980 / songText.width;
				songText.scale.x = textScale;
				for (letter in songText.letters)
				{
					letter.x *= textScale;
					letter.offset.x *= textScale;
				}
				// songText.updateHitbox();
				// trace(songs[i].songName + ' new scale: ' + textScale);
			}

			Paths.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.scrollFactor.set();

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreText.scrollFactor.set();

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);
		scoreBG.scrollFactor.set();

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);
		diffText.scrollFactor.set();

		add(scoreText);

		if (curSelected >= songs.length)
			curSelected = 0;
		bgClr.color = songs[curSelected].color;
		intendedColor = bgClr.color;
		FlxTween.tween(bg, {alpha: 0}, 1);

		if (lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		changeSelection();
		changeDiff();

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBG.alpha = 0.6;
		textBG.scrollFactor.set();
		add(textBG);

		#if PRELOAD_ALL
		var leText:String = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 16;
		#else
		var leText:String = "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var size:Int = 18;
		#end
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, leText, size);
		text.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	public function updatePackSelection(change:Int, playSound:Bool = true)
	{
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curPackImage += change;
		if (curPackImage == -1)
			curPackImage = songTypes.length - 1;

		if (curPackImage == songTypes.length)
			curPackImage = 0;

		camFollow.x = icons[curPackImage].x + (icons[curPackImage].width / 2);
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	/*public function addWeek(songs:Array<String>, weekNum:Int, weekColor:Int, ?songCharacters:Array<String>)
		{
			if (songCharacters == null)
				songCharacters = ['bf'];

			var num:Int = 0;
			for (song in songs)
			{
				addSong(song, weekNum, songCharacters[num]);
				this.songs[this.songs.length-1].color = weekColor;

				if (songCharacters.length != 1)
					num++;
			}
	}*/
	var instPlaying:Int = -1;

	public static var vocals:FlxSound = null;

	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space = FlxG.keys.justPressed.SPACE;
		var ctrl = FlxG.keys.justPressed.CONTROL;

		if (!inMainFreeplayState)
		{
			scoreBG = null;
			scoreText = null;
			diffText = null;

			if (controls.UI_LEFT_P)
			{
				updatePackSelection(-1);
			}
			if (controls.UI_RIGHT_P)
			{
				updatePackSelection(1);
			}
			if (accepted && !loadingPack)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				new FlxTimer().start(0.2, function(Dumbshit:FlxTimer)
				{
					loadingPack = true;
					loadProperPack();

					for (item in icons)
					{
						FlxTween.tween(item, {alpha: 0, y: item.y - 200}, 0.2, {ease: FlxEase.cubeInOut});
					}
					for (item in titles)
					{
						FlxTween.tween(item, {alpha: 0, y: item.y - 200}, 0.2, {ease: FlxEase.cubeInOut});
					}

					new FlxTimer().start(0.2, function(Dumbshit:FlxTimer)
					{
						for (item in icons)
						{
							item.visible = false;
						}
						for (item in titles)
						{
							item.visible = false;
						}

						loadRealFreeplay();
						inMainFreeplayState = true;
						loadingPack = false;
					});
				});
			}
			if (controls.BACK)
			{
				FlxG.switchState(new MainMenuState());
			}
			return;
		}
		else
		{
			var shiftMult:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftMult = 3;

			if (songs.length > 1)
			{
				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
						changeDiff();
					}
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
					changeDiff();
				}
			}

			if (controls.UI_LEFT_P)
				changeDiff(-1);
			else if (controls.UI_RIGHT_P)
				changeDiff(1);
			else if (upP || downP)
				changeDiff();

			if (controls.BACK)
			{
				loadingPack = true;

				FlxTween.tween(bg, {alpha: 1}, 1);
				FlxG.sound.play(Paths.sound('cancelMenu'));

				for (i in grpSongs)
				{
					FlxTween.tween(i, {y: 5000, alpha: 0}, 0.3, {
						onComplete: function(twn:FlxTween)
						{
							for (item in icons)
							{
								item.visible = true;
								FlxTween.tween(item, {alpha: 1, y: item.y + 200}, 0.2, {ease: FlxEase.cubeInOut});
							}
							for (item in titles)
							{
								item.visible = true;
								FlxTween.tween(item, {alpha: 1, y: item.y + 200}, 0.2, {ease: FlxEase.cubeInOut});
							}

							if (scoreBG != null)
							{
								FlxTween.tween(scoreBG, {y: scoreBG.y - 100}, 0.5, {
									ease: FlxEase.expoInOut,
									onComplete: function(spr:FlxTween)
									{
										scoreBG = null;
									}
								});
							}

							if (scoreText != null)
							{
								FlxTween.tween(scoreText, {y: scoreText.y - 100}, 0.5, {
									ease: FlxEase.expoInOut,
									onComplete: function(spr:FlxTween)
									{
										scoreText = null;
									}
								});
							}

							if (diffText != null)
							{
								FlxTween.tween(diffText, {y: diffText.y - 100}, 0.5, {
									ease: FlxEase.expoInOut,
									onComplete: function(spr:FlxTween)
									{
										diffText = null;
									}
								});
							}

							inMainFreeplayState = false;
							loadingPack = false;

							for (i in grpSongs)
							{
								remove(i);
							}
							for (i in iconArray)
							{
								remove(i);
							}

							// MAKE SURE TO RESET EVERYTHIN!
							songs = [];
							grpSongs.members = [];
							iconArray = [];
							curSelected = 0;
						}
					});
				}
			}

			if (ctrl)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if (space)
			{
				if (instPlaying != curSelected)
				{
					#if PRELOAD_ALL
					destroyFreeplayVocals();
					FlxG.sound.music.volume = 0;
					Paths.currentModDirectory = songs[curSelected].folder;
					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
					if (PlayState.SONG.needsVoices)
						vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
					else
						vocals = new FlxSound();

					FlxG.sound.list.add(vocals);
					FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
					vocals.play();
					vocals.persist = true;
					vocals.looped = true;
					vocals.volume = 0.7;
					instPlaying = curSelected;
					#end
				}
			}
			else if (accepted)
			{
				persistentUpdate = false;
				var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
				var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
				/*#if MODS_ALLOWED
					if(!sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) && !sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop))) {
					#else
					if(!OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
					#end
						poop = songLowercase;
						curDifficulty = 1;
						trace('Couldnt find file');
				}*/
				trace(poop);

				PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				if (colorTween != null)
				{
					colorTween.cancel();
				}

				if (FlxG.keys.pressed.SHIFT)
				{
					LoadingState.loadAndSwitchState(new ChartingState());
				}
				else
				{
					LoadingState.loadAndSwitchState(new PlayState());
				}

				FlxG.sound.music.volume = 0;

				destroyFreeplayVocals();
			}
			else if (controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
		}

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
		{ // No decimals, add an empty space
			ratingSplit.push('');
		}

		while (ratingSplit[1].length < 2)
		{ // Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		super.update(elapsed);
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length - 1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		lastDifficultyName = CoolUtil.difficulties[curDifficulty];

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		if (inMainFreeplayState)
		{
			var newColor:Int = songs[curSelected].color;
			if (newColor != intendedColor)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bgClr, 1, bgClr.color, intendedColor, {
					onComplete: function(twn:FlxTween)
					{
						colorTween = null;
					}
				});
			}

			// selector.y = (70 * curSelected) + 30;

			#if !switch
			intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
			intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
			#end

			var bullShit:Int = 0;

			for (i in 0...iconArray.length)
			{
				iconArray[i].alpha = 0.6;
			}

			iconArray[curSelected].alpha = 1;

			for (item in grpSongs.members)
			{
				item.targetY = bullShit - curSelected;
				bullShit++;

				item.alpha = 0.6;
				// item.setGraphicSize(Std.int(item.width * 0.8));

				if (item.targetY == 0)
				{
					item.alpha = 1;
					// item.setGraphicSize(Std.int(item.width));
				}
			}

			Paths.currentModDirectory = songs[curSelected].folder;
			PlayState.storyWeek = songs[curSelected].week;

			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
			var diffStr:String = WeekData.getCurrentWeek().difficulties;
			if (diffStr != null)
				diffStr = diffStr.trim(); // Fuck you HTML5

			if (diffStr != null && diffStr.length > 0)
			{
				var diffs:Array<String> = diffStr.split(',');
				var i:Int = diffs.length - 1;
				while (i > 0)
				{
					if (diffs[i] != null)
					{
						diffs[i] = diffs[i].trim();
						if (diffs[i].length < 1)
							diffs.remove(diffs[i]);
					}
					--i;
				}

				if (diffs.length > 0 && diffs[0].length > 0)
				{
					CoolUtil.difficulties = diffs;
				}
			}

			if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
			{
				curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
			}
			else
			{
				curDifficulty = 0;
			}

			var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
			// trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
			if (newPos > -1)
			{
				curDifficulty = newPos;
			}
		}
	}

	function weekPackCheck(name:String)
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return leWeek.pack;
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Paths.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}
}
