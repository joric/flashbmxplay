package bmxplay
{	
	import flash.utils.ByteArray;
	
	public class BmxMachine
	{
		public var type:int;
		public var pMasterInfo:BmxPlay;
		public var numGlobalParameters:int;
		public var numTrackParameters:int;
		public var numChannels:int;
		public var xPos:Number;
		public var yPos:Number;
		public var GlobalVals:ByteArray;
		public var TrackVals:ByteArray;
		public var sources:int;
		public var name:String;
		public var dllname:String;
		public var patterns:Vector.<BmxPattern>;
		public var events:Vector.<Array>;
		
		public var currentPattern:int;
		public var currentRow:int;
		public var patternRows:int;
		
		public var scount:int;
		
		public var buf:Vector.<Number>;
		
		public function BmxMachine()
		{
			type = 0;			
			numGlobalParameters = 5;
			numTrackParameters = 0;
			numChannels = 2;			
			events = new Vector.<Array>;
			patterns = new Vector.<BmxPattern>;
			currentPattern = 0;
			currentRow = 0;
			patternRows = 0;
		}

		public function Init(msd:ByteArray):void
		{
		}
		
		public function Tick():void
		{
		}
		
		public function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			return false;
		}
		
		public function getFreq(note:Number):Number
		{
			if (note != 0xFF && note > 0)
			{
				var l_Note:int = ((note >> 4) * 12) + (note & 0x0f) - 70;
				return 440.0 * Math.pow(2.0, l_Note / 12.0);
			}
			else
				return 0;
		}
		
		private function getByte(src:ByteArray, ofs:int, def:int = 0):int
		{
			if (src == null || ofs >= src.length || src[ofs] == 0xff)
				return def;
			else
				return src[ofs] & 0xff;
		}
		
		public function gp(ofs:int, def:int = 0):int
		{
			return getByte(GlobalVals, ofs, def);
		}
		
		public function tp(ofs:int, def:int = 0):int
		{
			return getByte(TrackVals, ofs, def);
		}
		
		public function loadValues(pattern:int, row:int):void
		{
			if (patterns == null || patterns.length <= pattern)
				return;
			
			var p:BmxPattern = patterns[pattern];
			
			p.gdata.position = row * numGlobalParameters;
			p.gdata.readBytes(GlobalVals, 0, numGlobalParameters);
			p.tdata.position = row * numTrackParameters;
			p.tdata.readBytes(TrackVals, 0, numTrackParameters * p.numTracks);
		}
	}
}
