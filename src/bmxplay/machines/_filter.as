package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.utils.ByteArray;
	
	public class _filter extends BmxMachine
	{
		public var param1:int;
		public var param2:int;
		public var param3:int;
		
		private var f:Number;
		private var q:Number;
		private var d:Number;
		
		private var buf0:Number;
		private var buf1:Number;
		
		public function _filter()
		{
			type = 1;
			numGlobalParameters = 3;
			numTrackParameters = 0;
			numChannels = 1;
			buf0 = 0;
			buf1 = 0;
		}
		
		public override function Tick():void
		{
			param1 = gp(0, param1);
			param2 = gp(1, param2);
			param3 = gp(2, param3);
			
			f = param1 / 128.0 * 0.99;
			q = param2 / 128.0 * 0.98;
			d = param3 / 128.0;
		}
		
		public override function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			for (var i:int = 0; i < numsamples; ++i)
			{
				var pin:Number = psamples[i];
				
				var fb:Number = q + q / (1.0 - f);
				
				//for each sample...
				buf0 = buf0 + f * (pin - buf0 + fb * (buf0 - buf1));
				buf1 = buf1 + f * (buf0 - buf1);
				
				psamples[i] = buf1;
				
				// distortion
				if (d > 0)
				{
					var amp:Number = 1.0 / (1.0 - d);
					var a:Number = psamples[i];
					a *= amp;					
					if (a > 32767)
						a = 32767;
					else if (a < -32767)
						a = -32767;
					psamples[i] = a;
				}
			}
			return true;
		}
	}
}
