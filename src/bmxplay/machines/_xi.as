package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.geom.Point;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	public class _xi extends BmxMachine
	{
		private var note:int;
		
		private var datasize:int;
		private var samplesize:int;
		private var loopstart:int;
		private var looplength:int;
		private var volpts:int;
		private var volflg:int;
		private var sampletype:int;
		private var compression:int;
		private var relnote:int;
		private var finetune:int;
		
		private var volenv:Vector.<Point>;
		private var wave:Vector.<Number>;
		
		private var freq:Number;
		private var basefreq:Number;
		private var sn:int;
		private var dsn:int;
		private var a:Number;
		private var ta:Number;
		private var da:Number;
		private var tick:Number;
		private var last_tick:Number;
		private var env_tick:int;
		private var env_pos:int;
		private var env_index:int;
		private var tps:Number;
		
		private var sndf:int;
		
		private var play:Boolean;
		
		public function _xi()
		{
			type = 1;
			numGlobalParameters = 0;
			numTrackParameters = 1;
			numChannels = 1;
		}
		
		public override function Init(msd:ByteArray):void
		{
			note = 0;
			samplesize = 0;
			play = false;
			
			if (msd && msd.length)
			{
				msd.endian = Endian.LITTLE_ENDIAN;
				
				datasize = msd.readInt();
				samplesize = msd.readInt();
				loopstart = msd.readInt();
				looplength = msd.readInt();
				volpts = msd.readByte();
											
				volenv = new Vector.<Point>;
				for (var k:int = 0; k < 12; k++)
				{
					var p:Point = new Point(msd.readShort(), msd.readShort());
					volenv.push(p);
				}
				volflg = msd.readByte();
				sampletype = msd.readByte();
				compression = msd.readByte();
				relnote = msd.readByte();
				finetune = msd.readByte();
				
				//skip pointers
				msd.readInt();
				msd.readInt();
				
				wave = new Vector.<Number>(samplesize, true);

				trace("machine: " + name + " loading xi, size: " + samplesize + " comp: " + compression + " type: " + sampletype + " loop length: " + looplength);
								
				var i:int;
				if (compression == 1) //4-bit
				{
					for (i = 0; i < samplesize/2; ++i)
					{
						if (msd.bytesAvailable == 0)
							break;
						var b:Number = msd.readByte();
						var b1:int = (b & 0x0f) << 4;
						var b2:int = (b & 0xf0);
						wave[i * 2 + 0] = b1 > 127 ? b1 - 256 : b1;
						wave[i * 2 + 1] = b2 > 127 ? b2 - 256 : b2;
					}
				}
				else
				{
					for (i = 0; i < samplesize; ++i)
						wave[i] = msd.readByte();
				}
			}
			sn = -1;
			basefreq = 261.7;
		}

		public override function Tick():void
		{
			note = tp(0, note);
			if (note != 0)
			{
				freq = getFreq(note);
				sn = 0;
				dsn = freq * 256.0 / basefreq;
				startenv();
				play = true;
			}
		}

		public override function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			if (basefreq == 0 || sn == -1) 
				return false;

			for (var i:int = 0; i < numsamples; ++i)
			{
				var index:int = sn / 256;
				
				if (index < samplesize-1 && play)
				{
					var a1:Number = wave[index];
					var a2:Number = wave[index + 1];
													
					a = (a1 * 256) + (a2 - a1) * (sn & 0x000000ff);
					
					if (sampletype != 0)
						psamples[i] = a * nextenv();
					else
						psamples[i] = a;
					
					sndf = (sn + dsn) / 256;
										
					//forward loop
					if (sampletype == 1)
					{
						if (sndf >= loopstart + looplength)
							sn = loopstart * 256;
					}
					
					//pingpong loop
					if (sampletype == 2)
					{
						if (sndf >= loopstart + looplength-1)
							dsn = -dsn;
						else if (sndf <= loopstart && dsn < 0)
							dsn = -dsn;
					}
				}
				else
					psamples[i] = 0;
					
				sn += dsn;
			}
			return true;
		}	

		private function startenv():void
		{
			if (volpts == 0)
				return;
			
			da = 0;
			tick = 0;
			last_tick = -1;
			
			//6 - xi's propertiary magnifier
			tps = 6.0 / pMasterInfo.SamplesPerTick;
			
			ta = volenv[0].y / 64.0;
			env_index = 0;		
		}
		
		private function nextenv():Number
		{
			var y:Number;
			var k:Number;
			var i:int;
			
			i = env_index;

			if (i == volpts)
			{
				play = false;
				return 0;
			}
			
			k = volenv[i].x;
			
			tick += tps;
			
			if (tick >= k && last_tick < k)
			{
				k = volenv[i + 1].x;
				y = volenv[i + 1].y / 64.0;
				da = (y - ta) * tps / (k - tick);
				env_index++;
			}
			else
				ta += da;
			
			last_tick = tick;
			
			return ta;
		}
	}
}
