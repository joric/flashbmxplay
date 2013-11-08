package
{
	import flash.display.LoaderInfo;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.utils.ByteArray;
	import flash.display.StageScaleMode;
	import flash.display.SimpleButton;
	import flash.display.Shape;
	import flash.net.FileReference;
	import flash.net.FileFilter;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLLoaderDataFormat;	
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;

	import flash.utils.Timer;
	import flash.events.TimerEvent;
	
	import flash.media.SoundMixer;

	import bmxplay.BmxPlay;

	[SWF(width='512',height='256',frameRate='30',backgroundColor='0x000000')]
	
	public class Main extends Sprite
	{
		[Embed(source='../bin/default.bmx',mimeType='application/octet-stream')]
		private const song:Class;
		
		private var songName:String = "default.bmx";
		private var currentSong:int = 0;
		
		private var file:FileReference;
		private var player:BmxPlay;
		
		private var playing:Boolean = true;
		private var loaded:Boolean = false;
		private var playlist:Array = [];
		
		private var btn:Vector.<SimpleButton> = new Vector.<SimpleButton>;
		
		private var w:int = 512;
		private var h:int = 256;
		
		private var btn_alpha:Number;
		private var dest_alpha:Number;
		
		private var display_ms:Number;
		
		protected var text:TextField;
		
		private var url:String;
		private var request:URLRequest;
		private var urlLoader:URLLoader;
				
		private const MODE_OSC:int = 0;
		private const MODE_FFT:int = 1;	
		private const modes:Array = ["Waveform", "FFT (db)", "FFT (amp)"];		
		private var mode:int = MODE_FFT;
		public var bytes:ByteArray = new ByteArray();
		
		public function loadSong(url:String):void
		{
			request = new URLRequest(url);
			urlLoader = new URLLoader(request);
			urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
			
			urlLoader.addEventListener(Event.COMPLETE, function onLoaded(e:Event):void
				{
					loaded = (0 == player.Load(urlLoader.data));
					songName = url;
					var p:Array = songName.split('/');
					songName = p[p.length - 1];
					text.text = songName;
					
					if (playing && loaded)
					{
						player.Stop();
						player.Play();
					}
				});
		}		
		
		private function singleClickHandler(e:MouseEvent):void
		{					
			mode++;
			if (mode > MODE_FFT)
				mode = 0;		
		}
		
		public function Main()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.addEventListener(MouseEvent.CLICK, singleClickHandler, false, 0, true);
						
			player = new BmxPlay();
			text = new TextField();
			player.SetCallback ( callback );
			
			try
			{
				var paramObj:Object = LoaderInfo(this.root.loaderInfo).parameters;
				for (var keyStr:String in paramObj)
				{
					var valueStr:String = String(paramObj[keyStr]);
					
					if (keyStr.match("play") && valueStr.match("false"))
						playing = false;
					
					if (keyStr.match("song"))
						loadSong(valueStr);
					
					if (keyStr.match("playlist"))
					{
						request = new URLRequest(valueStr);
						urlLoader = new URLLoader(request);
						urlLoader.dataFormat = URLLoaderDataFormat.TEXT;
						urlLoader.addEventListener(Event.COMPLETE, function onLoaded(e:Event):void
							{
								var txt:String = urlLoader.data;
								var src:Array = [];
								src = txt.split('\n');
								var s:String;
								var i:int;
								for (i = 0; i < src.length; i++ )
								{
									s = src[i];
									s = s.replace("\r", "");
									s = s.replace("\n", "");
									if (s.length != 0)
										playlist.push(s);
								}	
																
								if (playlist.length > currentSong)
									loadSong(playlist[currentSong]);
							});
					}
				}
			}
			catch (e:Error)
			{
				trace(e.getStackTrace());
			}
			
			text.textColor = 0xffffff;
			text.text = songName;
			addChild(text);			
			
			btn.push(button(w / 2, h / 2, h / 3, 0, btnPlay));
			btn.push(button(w - h / 16 * 7, h - h / 16, h / 16, 1, btnStop));			
			if (!playing)
				addChild(btn[0]);
			addChild(btn[1]);
						
			btn.push(button(w - h / 16, h - h / 16, h / 16, 2, btnBrowse));
			addChild(btn[2]);

			btn.push(button(w - h / 16 * 5, h - h / 16, h / 16, 4, btnPrev));
			addChild(btn[3]);
			
			btn.push(button(w - h / 16 * 3, h - h / 16, h / 16, 3, btnNext));
			addChild(btn[4]);

			btn_alpha = 1.0;
			dest_alpha = 1.0;

			if (!loaded)
				loaded = (0 == player.Load(ByteArray(new song())));
			
			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
			stage.addEventListener(Event.MOUSE_LEAVE, mouseLeaveHandler);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
			stage.addEventListener(Event.ENTER_FRAME, enterFrameHandler);

			if (playing && loaded)
				player.Play();
		}
		
		public function zeroPad(number:int, width:int):String {
			var ret:String = number.toString(10);
			while( ret.length < width )
				ret = "0" + ret;
			return ret;
		}

		private function enterFrameHandler(evt:Event):void
		{
			drawWave();

			text.x = 2;
			text.width = 512;
			text.height = 48;
			text.multiline = false;
			text.wordWrap = false;			
			text.text = songName + " (" + zeroPad(player.CurrentTick, 4) + "/" + zeroPad(player.songsize, 4) + ") - " + modes[mode];
						
			if (dest_alpha > btn_alpha)
				btn_alpha += 0.1;
			else if (dest_alpha < btn_alpha)
				btn_alpha -= 0.1;
			else
				return;
			
			for each (var b:SimpleButton in btn)
				b.alpha = btn_alpha * 0.75;
			
			text.alpha = btn_alpha;
		}
		
		private function mouseLeaveHandler(evt:Event):void
		{
			if (playing)
				dest_alpha = 0.0;
		}
		
		private function mouseMoveHandler(evt:Event):void
		{
			dest_alpha = 1.0;
		}
		
		private function drawTriangle(x:int, y:int, g:Graphics, r:Number, rot:Number):void
		{
			g.moveTo(x, y);
			for (var a:Number = 0; a <= Math.PI * 2; a += Math.PI * 2 / 3)
				g.lineTo(x + Math.cos(a + rot) * r, y + Math.sin(a + rot) * r);
		}
		
		private function drawBars(g:Graphics, r:Number):void
		{
			r *= 0.67;
			var gap:Number = r * 0.25;
			for (var i:int = 0; i < 2; ++i)
				g.drawRect(i * (r + gap) - r - gap / 2, -r, r, r * 2);
		}
		
		private function btnShape(r:Number, icon:int):Shape
		{
			var shape:Shape = new Shape();
			shape.graphics.beginFill(0xf0f0f0, 1);
			shape.graphics.drawCircle(0, 0, r);
			shape.graphics.endFill();
			shape.graphics.beginFill(0x000000, 1);
			switch (icon)
			{
				case 0: // play
					drawTriangle(0, 0, shape.graphics, r * 0.75, 0);
					break;
				case 1: // stop
					drawBars(shape.graphics, r * 0.75);
					break;
				case 2: // open
					drawTriangle(0, 0, shape.graphics, r * 0.75, -Math.PI / 2);
					break;
				case 3: // ff
					drawTriangle(-r / 2 + 1, 0, shape.graphics, r * 0.5, 0);
					shape.graphics.endFill();
					shape.graphics.beginFill(0x000000, 1);
					drawTriangle(r / 2 - 2, 0, shape.graphics, r * 0.5, 0);
					break;
				case 4: // rev
					drawTriangle(-r / 2 + 1, 0, shape.graphics, r * 0.5, -Math.PI);
					shape.graphics.endFill();
					shape.graphics.beginFill(0x000000, 1);
					drawTriangle(r / 2 - 2, 0, shape.graphics, r * 0.5, -Math.PI);
					break;
					
			}
			shape.graphics.endFill();
			return (shape);
		}
		
		private function button(x:int, y:int, r:int, icon:int, listener:Function):SimpleButton
		{
			var b:SimpleButton = new SimpleButton();
			b.x = x;
			b.y = y;
			b.alpha = 0.75;
			b.upState = btnShape(r * 0.8, icon);
			b.overState = btnShape(r * 0.85, icon);
			b.downState = btnShape(r * 0.9, icon);
			b.hitTestState = b.upState;
			b.addEventListener(MouseEvent.CLICK, listener);
			return b;
		}
		
		private function btnBrowse(e:MouseEvent):void
		{
			e.stopPropagation();
			browse();
		}
		
		private function btnPlay(e:MouseEvent):void
		{
			e.stopPropagation();
			if ( !playing )
			{
				player.Play();
				removeChild(btn[0]);
				playing = true;
			}
		}
		
		private function btnStop(e:MouseEvent):void
		{
			e.stopPropagation();
			if ( playing )
			{
				player.Stop();
				addChild(btn[0]);
				playing = false;
			}
			e.stopPropagation();
		}
		
		private function btnNext(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!playlist.length)
				return;
			
			currentSong++;
			
			if (currentSong > playlist.length - 1)
				currentSong = 0;
			
			loadSong(playlist[currentSong]);						
		}

		private function btnPrev(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!playlist.length)
				return;
			
			currentSong--;
			
			if (currentSong < 0)
				currentSong = playlist.length - 1;
			
			loadSong(playlist[currentSong]);
		}
		
		private function cancelHandler(e:Event):void
		{
			file.removeEventListener(Event.CANCEL, cancelHandler);
			file.removeEventListener(Event.SELECT, selectHandler);
		}
		
		private function selectHandler(e:Event):void
		{
			cancelHandler(e);
			file.addEventListener(Event.COMPLETE, loadCompleteHandler);
			file.load();
		}
		
		private function loadCompleteHandler(e:Event):void
		{
			file.removeEventListener(Event.COMPLETE, loadCompleteHandler);
			player.Load(file.data);
			songName = file.name;
			text.text = songName;
		}
		
		private function browse():void
		{
			file = new FileReference();
			file.addEventListener(Event.CANCEL, cancelHandler);
			file.addEventListener(Event.SELECT, selectHandler);
			var buzzTypes:FileFilter = new FileFilter("Buzz Tracker (*.bmx;*.bmw)", "*.bmx;*.bmw");
			var allTypes:FileFilter = new FileFilter("All files", "*.*");
			file.browse(new Array(buzzTypes, allTypes));
		}
		
		private function keyDown(e:KeyboardEvent):void
		{
			switch (e.keyCode)
			{
				case 114: //F3					
					browse();
					break;
			}
		}
		
		public function callback():void
		{
			SoundMixer.computeSpectrum(bytes, mode==MODE_FFT, 0);
		}
		
		private function drawWave():void
		{			
			var fft:Boolean = (mode == MODE_FFT);
			var x:Number;
			var y:Number;
			var k:Number = fft ? 1.0 : 0.75;			
									
			var g:Graphics = this.graphics;
			g.clear();
			g.lineStyle(0, 0x00ff00);			
			
			for (var i:int = 0; i < 256; i++)
			{
				var amp:Number = 0;
				try { 
					amp = bytes.readFloat() * k;
				} catch (e:Error) 
				{ };
				
				x = i * 2;
				
				if (fft)
					y = h - amp * h;
				else
					y = h - (amp * h / 2 + h / 2);
					
				i == 0 ? g.moveTo(x, y) : g.lineTo(x, y);
			}
		}
	}
}
