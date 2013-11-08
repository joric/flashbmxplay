package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.utils.ByteArray;
	
	public class _delay extends BmxMachine
	{
		public var length:int;
		public var feedback:int;
		public var dryout:int;
		public var wetout:int;
		
		private var buf1:Vector.<Number>;
		private var buf2:Vector.<Number>;

		private var iw:int;
		private var len:Number;
		private var fb:Number;
		private var dry:Number;
		private var wet:Number;
		private var dsize:int;
		private var pan:int;

		public function _delay()
		{
			type = 1;
			numGlobalParameters = 4;
			numTrackParameters = 0;
			numChannels = 2;
			dsize = 44100;
			buf1 = new Vector.<Number>(dsize, true);
			buf2 = new Vector.<Number>(dsize, true);
		}
		
		public override function Init(msd:ByteArray):void
		{
			pan = 0;
			iw = 0;
			length = 0;
			feedback = 0;
			dryout = 0;
			wetout = 0;
		}
		
		public override function Tick():void
		{
			length = gp(0, length);
			feedback = gp(1, feedback);
			dryout = gp(2, dryout);
			wetout = gp(3, wetout);

			len = length / 128.0;
			fb = feedback / 128.0;
			dry = dryout / 128.0;
			wet = wetout / 128.0;
		}

		public override function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			var delta:int = len * dsize;
			
			var lbuf:Vector.<Number>;
			var rbuf:Vector.<Number>;
			
			if (pan) lbuf = buf1, rbuf = buf2; else lbuf = buf2, rbuf = buf1;
			
			for (var i:int = 0; i < numsamples*2;)
			{
				var pin:Number = psamples[i];

				psamples[i++] = rbuf[iw] * wet + pin * dry;
				rbuf[iw] = fb * rbuf[iw];

				psamples[i++] = lbuf[iw] * wet + pin * dry;
				lbuf[iw] = pin + fb * lbuf[iw];
				
				iw++;
				
				if (iw >= delta)
				{
					iw = 0;
					pan = 1 - pan;
					if (pan) lbuf = buf1, rbuf = buf2; else lbuf = buf2, rbuf = buf1;
				}
			}
			return true;
		}
	}
}
