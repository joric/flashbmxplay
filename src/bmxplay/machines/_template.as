package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.utils.ByteArray;

	public class _template extends BmxMachine
	{
		public function _template()
		{
			type = 1;
			numGlobalParameters = 0;
			numTrackParameters = 1;
			numChannels = 1;
		}

		public override function Init(msd:ByteArray):void
		{

		}

		public override function Tick():void
		{

		}

		public override function Work(psamples:Vector.<Number>, numsamples:int, channels:int):Boolean
		{
			for (var i:int = 0; i < numsamples; ++i)
			{
				psamples[i] = 0;
			}
			return true;
		}
	}
}
