package bmxplay.machines
{
	import bmxplay.BmxPlay;
	import bmxplay.BmxMachine;
	import flash.utils.ByteArray;

	public class _voice extends BmxMachine
	{
		public function _voice()
		{
			type = 1;
			numGlobalParameters = 6;
			numTrackParameters = 3;
			numChannels = 1;
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
