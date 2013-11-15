package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.utils.ByteArray;
	
	public class _303 extends BmxMachine
	{
		//globals
		public var tune:int;
		public var cutoff:int;
		public var resonance:int;
		public var envmod:int;
		public var decay:int;
		public var accent:int;
		
		//track
		public var note:int;
		public var slide:int;
		public var endnote:int;
		
		//internal
		private var s:Number;
		public var f:Number;
		public var q:Number;
		private var freq:Number;
		private var freq1:Number;
		private var dfreq:Number;
		private var a:Number;
		private var da:Number;
		private var smax:Number;
		private var dsmax:Number;
		private var df:Number;
		private var buf0:Number;
		private var buf1:Number;
		private var amp:Number;
		private var damp:Number;
		private var pos:Number;
		private var fdecay:Number;
		
		private var f0:Number;
		
		public function _303()
		{
			type = 1;
			numGlobalParameters = 6;
			numTrackParameters = 3;
			numChannels = 1;
			
			tune = 0;
			cutoff = 20;
			resonance = 200;
			envmod = 0;
			decay = 0;
			accent = 0;
			
			note = 0;
			slide = 0;
			endnote = 0;
			
			a = 0;
			amp = 0;
			buf0 = 0;
			buf1 = 0;
			pos = 0;
			dfreq = 0;
		}
		
		public override function Tick():void
		{
			tune = gp(0, tune);
			cutoff = gp(1, cutoff);
			resonance = gp(2, resonance);
			envmod = gp(3, envmod);
			decay = gp(4, decay);
			accent = gp(5, accent);
			
			note = tp(0, note);
			slide = tp(1, slide);
			endnote = tp(2, endnote);
			
			fdecay = decay / 128.0;
			
			f = cutoff / 128.0 * 0.98 + 0.1;
			q = resonance / 128.0 * 0.88;
			
			//trace("note: " + note.toString(16));
			
			if (note != 0)
			{
				freq = getFreq(note + tune - 0x40);

				if (freq != 0)
				{
					amp = 1;
					
					//init saw generator
					s = 0;
					a = -32767.0;
					
					smax = pMasterInfo.SamplesPerSec / freq;
					dsmax = 0;
					damp = -(1.0 * fdecay / pMasterInfo.SamplesPerTick);
					
					dfreq = 0;
					
					da = 65536.0 / smax;
					
					buf0 = 0;
					buf1 = 0;
					
					df = f * damp;
					f0 = f;
				}
			}
			
			if (endnote != 0)
			{
				freq1 = getFreq(endnote + tune - 0x40);
				
				if (freq != 0 && slide != 0)
				{
					var smax1:Number = pMasterInfo.SamplesPerSec / freq1;
					var ispt:Number = 1.0 / pMasterInfo.SamplesPerTick / slide;
					dsmax = (smax1 - smax) * ispt;
					damp = -ispt;
					df = damp * f;
				}
			}
		}
		
		public override function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			for (var i:int = 0; i < numsamples; ++i)
			{
				if (amp > 0)
				{
					var pin:Number = a * amp;
					
					var fb:Number = q + q / (1.0 - f);
					
					//for each sample...
					buf0 = buf0 + f * (pin - buf0 + fb * (buf0 - buf1));
					buf1 = buf1 + f * (buf0 - buf1);
					
					//f += df; // TODO: find out why it lacks accuracy
					f = f0 * amp;
					
					psamples[i] = buf1;
					
					//calculating saw
					smax += dsmax; // period slide
					s++;
					if (s >= smax)
					{
						s = 0;
						a = -32767.0;
					}
					a += da;
					amp += damp;
				}
				else
					psamples[i] = 0;
			}
			return true;
		}
	}
}
