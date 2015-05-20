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
	import flash.geom.Rectangle;

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
		private var mode:int = MODE_OSC;
		public var bytes:ByteArray = new ByteArray();
		
		public function loadSong(url:String):void
		{
			m_maxamp = 0;

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
		
		private var m_fr:Array = new Array();
		private var m_fi:Array = new Array();
		private var m_bits:int = 10;
		private var m_bitmap:BitmapData = new BitmapData(512, 256, false, 0x000000);
		private var m_palette:Array = new Array();
		private var m_scale:Number = 1.0;
		private var m_maxamp:Number = 0;

		private function set_gradient_palette(i1:int, i2:int, c1:uint, c2:uint):void
		{
			var i:int, k:int;
			var R:int, G:int, B:int;
			var R1:int, G1:int, B1:int, R2:int, G2:int, B2:int;
			if (i2 == i1)
				k = 1;
			else
				k = i2 - i1;
			R1 = (c1 >> 16) & 0xFF;
			G1 = (c1 >> 8) & 0xFF;
			B1 = (c1 >> 0) & 0xFF;
			R2 = (c2 >> 16) & 0xFF;
			G2 = (c2 >> 8) & 0xFF;
			B2 = (c2 >> 0) & 0xFF;
			for (i = i1; i <= i2; i++)
			{
				R = (R1 + (i - i1) * (R2 - R1) / k) & 0xFF;
				G = (G1 + (i - i1) * (G2 - G1) / k) & 0xFF;
				B = (B1 + (i - i1) * (B2 - B1) / k) & 0xFF;
				m_palette[i] = (0xff << 24) | (R << 16) | (G << 8) | B;
			}
		}

		public function Main()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.addEventListener(MouseEvent.CLICK, singleClickHandler, false, 0, true);
						
			var bitmap1:Bitmap=new Bitmap(m_bitmap);
			this.addChild(bitmap1);
			set_gradient_palette(0, 64, 0x0000ff, 0x00ff00);
			set_gradient_palette(64, 128, 0x00ff00, 0xff0000);
			set_gradient_palette(128, 192, 0xff0000, 0xffff00);
			set_gradient_palette(192, 255, 0xffff00, 0xffffff);

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
			var x:int;
			var y:int;
			var j:int;
			var k:Number = fft ? 1.0 : 0.75;
			var g:Graphics = this.graphics;
			g.clear();
			g.lineStyle(0, 0x00ff00);

			var fft_size:int = 1 << m_bits;

			var i:int;
			var amp:Number;
			var r:int;
			var l:int;

			if (fft)
			{
				for (i = 0; i < fft_size * 2; i++)
				{
					l = player.buf[i * 2 + 0];
					r = player.buf[i * 2 + 1];
					amp = (l + r) / 2;
					if (i & 1)
						m_fr[i / 2] = amp;
					else
						m_fi[i / 2] = amp;
				}

				fix_fft(m_fr, m_fi, m_bits, 0);

				m_bitmap.fillRect(new Rectangle(0, 0, 512, 256), 0x000000);

				for (i = 0; i < 512; i++)
				{
					x = i; // window?
					j = i; // scale?
					amp = Math.sqrt( m_fr[j] * m_fr[j] + m_fi[j] * m_fi[j] ) / 32768.0;
					amp *= m_scale;
					if (amp > m_maxamp)
						m_maxamp = amp;
					amp /= m_maxamp;
					y = h - amp * h;
					for (j = 0; j < h-y; j++)
					{
						var color:int = j * 255 / h;
						if (color < 0)
							color = 0;
						if (color > 255)
							color = 255;
						m_bitmap.setPixel(x, h-j, m_palette[color]);
					}
				}
			} else
			{
				m_bitmap.fillRect(new Rectangle(0, 0, 512, 256), 0x000000);
				var x0:int = 0;
				var y0:int = 0;
				for (i = 0; i < 512; i++)
				{
					x = i;
					l = player.buf[i * 2 + 0];
					r = player.buf[i * 2 + 1];
					amp = (l + r) / 2;
					amp /= 32768.0;
					y = h - (amp * h / 2 + h / 2);
					if (i == 0)
					{
						x0 = x;
						y0 = y;
					}

					if (y > y0) for (j = y0; j <= y; j++)
						m_bitmap.setPixel(x, j, 0x00ff00);
					else for (j = y; j <= y0; j++)
						m_bitmap.setPixel(x, j, 0x00ff00);

					x0 = x;
					y0 = y;
				}
			}

			/*
			// regular data from ComputeSpectrum
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
			*/
		}

		private var Sinewave:Array = new Array();
		private var LOG2_N_WAVE:int = 0;
		private var N_WAVE:int = 0;

		private function init_fft(m:int):void
		{
			LOG2_N_WAVE = m;
			N_WAVE = 1 << LOG2_N_WAVE;
			var size:int = N_WAVE - N_WAVE / 4;
			for (var i:int = 0; i < size; i++)
				Sinewave[i] = Math.sin ( Math.PI * i / size * 1.50 ) * 32767.0;
		}

		/*
		  FIX_MPY() - fixed-point multiplication & scaling.
		  Substitute inline assembly for hardware-specific
		  optimization suited to a particluar DSP processor.
		  Scaling ensures that result remains 16-bit.
		*/
		private function FIX_MPY(a:int, b:int):int
		{
			/* shift right one less bit (i.e. 15-1) */
			var c:int = ( a * b ) >> 14;
			/* last bit shifted out = rounding-bit */
			b = c & 0x01;
			/* last shift + rounding bit */
			a = (c >> 1) + b;
			return a;
		}

		/*
		  fix_fft() - perform forward/inverse fast Fourier transform.
		  fr[n],fi[n] are real and imaginary arrays, both INPUT AND
		  RESULT (in-place FFT), with 0 <= n < 2**m; set inverse to
		  0 for forward transform (FFT), or 1 for iFFT.
		*/
		private function fix_fft(fr:Array, fi:Array, m:int, inverse:int):int
		{
			var mr:int, nn:int, i:int, j:int, l:int, k:int, istep:int, n:int, scale:int, shift:int;
			var qr:int, qi:int, tr:int, ti:int, wr:int, wi:int;

			if (LOG2_N_WAVE < m)
				init_fft(m);

			n = 1 << m;

			/* max FFT size = N_WAVE */
			if (n > N_WAVE)
				return -1;

			mr = 0;
			nn = n - 1;
			scale = 0;

			/* decimation in time - re-order data */
			for (m = 1; m <= nn; ++m)
			{
				l = n;
				do
				{
					l >>= 1;
				}
				while (mr + l > nn);
				mr = (mr & (l - 1)) + l;

				if (mr <= m)
					continue;
				tr = fr[m];
				fr[m] = fr[mr];
				fr[mr] = tr;
				ti = fi[m];
				fi[m] = fi[mr];
				fi[mr] = ti;
			}

			l = 1;
			k = LOG2_N_WAVE - 1;
			while (l < n)
			{
				if (inverse)
				{
					/* variable scaling, depending upon data */
					shift = 0;
					for (i = 0; i < n; ++i)
					{
						j = fr[i];
						if (j < 0)
							j = -j;
						m = fi[i];
						if (m < 0)
							m = -m;
						if (j > 16383 || m > 16383)
						{
							shift = 1;
							break;
						}
					}
					if (shift)
						++scale;
				}
				else
				{
					/*
					   fixed scaling, for proper normalization --
					   there will be log2(n) passes, so this results
					   in an overall factor of 1/n, distributed to
					   maximize arithmetic accuracy.
					 */
					shift = 1;
				}
				/*
				   it may not be obvious, but the shift will be
				   performed on each data point exactly once,
				   during this pass.
				 */
				istep = l << 1;
				for (m = 0; m < l; ++m)
				{
					j = m << k;
					/* 0 <= j < N_WAVE/2 */
					wr = Sinewave[j + N_WAVE / 4];
					wi = -Sinewave[j];
					if (inverse)
						wi = -wi;
					if (shift)
					{
						wr >>= 1;
						wi >>= 1;
					}
					for (i = m; i < n; i += istep)
					{
						j = i + l;
						tr = FIX_MPY(wr, fr[j]) - FIX_MPY(wi, fi[j]);
						ti = FIX_MPY(wr, fi[j]) + FIX_MPY(wi, fr[j]);
						qr = fr[i];
						qi = fi[i];
						if (shift)
						{
							qr >>= 1;
							qi >>= 1;
						}
						fr[j] = qr - tr;
						fi[j] = qi - ti;
						fr[i] = qr + tr;
						fi[i] = qi + ti;
					}
				}
				--k;
				l = istep;
			}
			return scale;
		}
	}
}
