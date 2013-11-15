package bmxplay
{
	import flash.events.SampleDataEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.utils.setTimeout;
	import flash.utils.getDefinitionByName;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import flash.media.SoundMixer;
	
	import bmxplay.machines.*;
	
	public class BmxPlay
	{
		//list all machines in the package (for getDefinitionByName)
		private var imports:Array = [_303, _xi, _filter, _delay, _voice];
		
		public var BUFSIZE:int = 2048;

		public var BeatsPerMin:int;
		public var TicksPerBeat:int; // [1..32]
		public var SamplesPerSec:int; // usually 44100, but machines should support any rate from 11050 to 96000
		public var SamplesPerTick:int; // (int)((60 * SPS) / (BPM * TPB))  
		public var PosInTick:int; // [0..SamplesPerTick-1]
		public var TicksPerSec:Number; // (float)SPS / (float)SPT
		
		public var CurrentTick:int;
		public var TicksPerPattern:int;
		
		public var songsize:int;
		public var startloop:int;
		public var endloop:int;
		
		private var machines:Vector.<BmxMachine>;
		private var connections:Vector.<BmxConnection>;
		
		public var buf:Vector.<Number>;
		private var m:BmxMachine;
	
		public static const MT_MASTER:int = 0;
		public static const MT_GENERATOR:int = 1;
		public static const MT_EFFECT:int = 2;
						
		private var snd:Sound;
		private var soundChannel:SoundChannel = new SoundChannel();	
		
		private var callbackHandler:Function;
		public var ms:Number;
				
		public function BmxPlay()
		{
			machines = new Vector.<BmxMachine>;
			connections = new Vector.<BmxConnection>;
			buf = new Vector.<Number>(BUFSIZE * 2, true);
			SetCallback(function():void{});			
			snd = new Sound();
			snd.addEventListener('sampleData', sampleData);
		}
		
		public function SetCallback(callback:Function):void
		{
			callbackHandler = callback;
		}
		
		public function dumpPattern(p:BmxPattern):void
		{
			trace("--- pattern name: " + p.name + " rows: " + p.numRows + " ---");
			
			var ngp:int = p.gdata.length / p.numRows;
			var ntp:int = p.tdata.length / p.numRows;
			
			for (var row:int = 0; row < p.numRows; ++row)
			{
				var s:String = "";
				
				for (var gp:int = 0; gp < ngp; ++gp)
				{
					var gbyte:int = p.gdata[row * ngp + gp];
					s += gbyte.toString(16) + "\t";
				}
				
				s += "|\t";
				
				for (var tp:int = 0; tp < ntp; ++tp)
				{
					var tbyte:int = p.tdata[row * ntp + tp];
					s += tbyte.toString(16) + "\t";
				}
				trace(s);
			}
			trace("---");
		}
		
		private function chr(i:int):String
		{
			return String.fromCharCode(i);
		}
		
		private function FCC(i:int):String
		{
			return chr(i & 0xff) + chr((i >> 8) & 0xff) + chr((i >> 16) & 0xff) + chr((i >> 24) & 0xff);
		}
		
		private function readArray(src:ByteArray, len:int):ByteArray
		{
			var dest:ByteArray = new ByteArray();
			dest.length = len;
			if (dest.length > 0)
				src.readBytes(dest, 0, dest.length);
			return dest;
		}
		
		private function readString(_ba:ByteArray):String
		{
			var pos:uint = _ba.position;
			while (_ba.position < _ba.length)
			{
				var c:uint = _ba.readByte();
				if (c == 0)
				{
					break;
				}
			}
			var length:uint = _ba.position - pos;
			_ba.position = pos;
			return _ba.readUTFBytes(length);
		}
		
		public function Load(data:ByteArray):int
		{
			data.endian = Endian.LITTLE_ENDIAN;
			
			trace("Loading song, bytes: ", data.length);
			
			machines.length = 0;
			connections.length = 0;
			
			if (FCC(data.readInt()) != "Buzz")
				return -1;
			
			var numSections:int = data.readInt();
			
			for (var h:int = 0; h < numSections; ++h)
			{
				var fourcc:int = data.readInt();
				var offset:int = data.readInt();
				var size:int = data.readInt();
				var lastpos:int = data.position;
				var section:String = FCC(fourcc);				
    			data.position = offset;				
				trace(section);

				switch (section)
				{
					case "MACH": 
						var numMachines:int = data.readShort();
						for (var i:int = 0; i < numMachines; ++i)
						{
							var name:String = readString(data);
							trace("machine: " + i + " name: " + name);
							var type:int = data.readByte();
							
							if (type == MT_MASTER)
							{
								m = new BmxMachine();
							}
							else
							{
								var dllname:String = readString(data);
								try
								{
									var ClassRef:Class = getDefinitionByName("bmxplay.machines." + dllname) as Class;
									m = new ClassRef() as BmxMachine;
									trace("Loaded class: " + dllname);
								}
								catch (e:Error)
								{
									trace("Could not find class: " + dllname);
									break;
								}
							}
							
							m.name = name;
							m.dllname = dllname;
							m.pMasterInfo = this;
							m.buf = new Vector.<Number>(BUFSIZE * m.numChannels, true);
							
							trace("numGlobalParameters: " + m.numGlobalParameters);
							trace("numTrackParameters: " + m.numTrackParameters);
							
							m.xPos = data.readFloat();
							m.yPos = data.readFloat();
							
							var datalen:int = data.readInt();
							var msd:ByteArray = readArray(data, datalen);
							
							m.Init(msd);
							
							var numAttrs:int = data.readShort();
							trace("numAttrs: " + numAttrs);
							for (var k:int = 0; k < numAttrs; ++k)
							{
								var attrName:String = readString(data);
								var attrValue:int = data.readInt();
								trace("attrName: " + attrName + " attrValue: " + attrValue);
							}
							
							m.GlobalVals = readArray(data, m.numGlobalParameters);
							
							var numTracks:int = data.readShort();
							trace("numTracks: " + numTracks);
							m.TrackVals = readArray(data, m.numTrackParameters * numTracks);
							
							machines.push(m);
						}
						break;
					
					case "CONN": 
						var numConnections:int = data.readShort();
						trace("numConnections: " + numConnections);
						for (i = 0; i < numConnections; i++)
						{
							var c:BmxConnection = new BmxConnection();
							c.src = data.readShort();
							c.dst = data.readShort();
							c.amp = data.readShort();
							c.pan = data.readShort();
							trace(c.src + " => " + c.dst + "\tamp: " + c.amp + "\tpan: " + c.pan);
							connections.push(c);
							
							for (j = 0; j < machines.length; ++j)
							{
								if (c.dst == j)
									machines[j].sources++;
							}
						}
						
						break;
					
					case "PATT": 
						var n:int = 0;
						for (i = 0; i < machines.length; i++)
						{
							m = machines[i];

							var numPatterns:int = data.readShort();
							var tracks:int = data.readShort();
							
							//trace("mach: " + i + " patterns: " + numPatterns + " tracks: " + tracks);
							
							for (var j:int = 0; j < numPatterns; j++)
							{
								var p:BmxPattern = new BmxPattern();
								p.numTracks = tracks;
								p.name = readString(data);
								p.numRows = data.readShort();
								
								//trace("sources: " + m.sources);
								
								for (k = 0; k < m.sources; ++k)
								{
									data.readShort();
									readArray(data, p.numRows * 2 * 2);
								}
								
								p.gdata = readArray(data, m.numGlobalParameters * p.numRows);
								p.tdata = readArray(data, m.numTrackParameters * p.numRows * p.numTracks);
								m.patterns.push(p);
								
								//dumpPattern(p);
							}
						}
						
						break;
					
					case "SEQU": 
						songsize = data.readInt();
						startloop = data.readInt();
						endloop = data.readInt();
						
						trace("songsize: " + songsize + " startloop: " + startloop + " endloop: " + endloop);
						
						var numSequences:int = data.readShort();
						trace("numSequences: " + numSequences);
						for (i = 0; i < numSequences; i++)
						{
							var iMachine:int = data.readShort();
							
							m = machines[iMachine];
							
							var numEvents:int = data.readInt();
							
							//trace("sequence: " + i + " machine: " + iMachine + " events: " + numEvents);
							
							var posSize:int = data.readByte();
							var evtSize:int = data.readByte();
							
							for (j = 0; j < numEvents; j++)
							{
								var pos:int = (posSize == 1) ? data.readByte() & 0xff : data.readShort();
								var event:int = (evtSize == 1) ? data.readByte() & 0xff : data.readShort();
								var rec:Array = new Array(pos, event);
								m.events.push(rec);
								//trace(rec[0] + " -> " + rec[1]);
							}
						}
						break;
				}
				
				data.position = lastpos;
			}
					
			BeatsPerMin = machines[0].gp(2);
			TicksPerBeat = machines[0].gp(4);		
			SamplesPerSec = 44100;				
			SamplesPerTick = (int)((60 * SamplesPerSec) / (BeatsPerMin * TicksPerBeat));
						
			PosInTick = 0;
			TicksPerSec = SamplesPerSec / SamplesPerTick;
			
			trace("SamplesPerTick: " + SamplesPerTick);
			
			CurrentTick = 0;
			TicksPerPattern = 16;
			
			for each (m in machines)
				m.Tick();

			BmxWorkBuffer(buf, BUFSIZE);
				
			return 0;
		}
		
		public function Play():void
		{
			soundChannel = snd.play();
		}
		
		public function Stop():void
		{
			soundChannel.stop();
		}
		
		public function BmxSmartMix(out:Vector.<Number>, ofs:int, size:int):void
		{
			if (machines.length==0)
				return;
			
			var src:Vector.<Number>;
			var dest:Vector.<Number>;
			var i:int;

			for each (m in machines)
			{
				m.scount = m.sources;
				
				dest = m.buf;
				i = size * m.numChannels;
				while (i--)
					dest[i] = 0;
			}

			var machine:int = 0;
			
			while (machines[0].scount != 0)
			{
				if (machines[machine].scount != 0 || machines[machine].scount < 0)
				{
					//next, if cannot evaluate yet, or machine has been processed
					machine++;
				}
				else
				{
					m = machines[machine];
					m.Work(m.buf, size, m.numChannels);

					for each (var c:BmxConnection in connections)
					{
						var m1:BmxMachine;
						if (c.src == machine)
						{
							m1 = machines[c.dst];

							//copy source to destination with corresponding amplitude and panning							
							var amp:Number = c.amp / 0x4000;
							var rpan:Number = c.pan / 0x8000;
							var lpan:Number = 1.0 - rpan;
							
							var lamp:Number = amp * lpan;
							var ramp:Number = amp * rpan;

							src = m.buf;
							dest = m1.buf;							
							i = size;
							
							var j:int;
							var n:int;
							
							if (m.numChannels == 1 && m1.numChannels == 1)
							{
								while (i--)
									dest[i] += src[i] * amp;
							}
							else if (m.numChannels == 1 && m1.numChannels == 2)
							{								
								for (i = 0, j = 0; i < size; i++)
								{							
									dest[j++] += src[i] * lamp;
									dest[j++] += src[i] * ramp;
								}
							}
							else if (m.numChannels == 2 && m1.numChannels == 2)
							{
								for (i = 0, j = 0; i < size*2; )
								{
									dest[j++] += src[i++] * lamp;
									dest[j++] += src[i++] * ramp;
								}
							}
							
							m1.scount--;
						}
					}
					m.scount--;
					machine = 0;
				}
			}
			
			src = machines[0].buf;
			dest = out;
			for (i = 0, j = ofs*2; i < size * 2;)
				dest[j++] = src[i++];
		}
		
		public function Tick(m:BmxMachine, tick:int):void
		{
			var evt:Array;
			for each (evt in m.events)
			{
				var pos:int = evt[0];
				var event:int = evt[1];
								
				if (pos == tick)
				{
					//trace("pos: " + pos + " tick: " + tick + " event: " + event);
					
					if (event >= 0x10)
					{
						m.currentPattern = event - 0x10;
						m.currentRow = 0;
						m.patternRows = m.patterns[m.currentPattern].numRows;
						//trace("pattern: " + m.currentPattern);
					}
				}
			}
			
			if (m.currentRow < m.patternRows)
			{
				m.loadValues(m.currentPattern, m.currentRow);
				m.Tick();
			}
			
			m.currentRow++;
		}
		
		public function GetPos():int
		{
			return soundChannel.position * SamplesPerSec / 1000;
		}
		
		public function BmxWorkBuffer(psamples:Vector.<Number>, numsamples:int):void
		{
			var portion:int = 0;
			var count:int = numsamples;
			var maxsize:int = 0;
			var ofs:int = 0;
			
			while (count != 0)
			{
				if (PosInTick == 0)
				{
					for each (m in machines)
						Tick(m, CurrentTick);
					
					CurrentTick++;
					if (CurrentTick >= songsize)
						CurrentTick = startloop;
				}
				
				maxsize = SamplesPerTick - PosInTick;
				
				portion = count;
				
				if (portion > BUFSIZE)
					portion = BUFSIZE;
				
				if (portion > maxsize)
					portion = maxsize;
				
				PosInTick += portion;
				
				if (PosInTick == SamplesPerTick)
					PosInTick = 0;
				
				BmxSmartMix(psamples, ofs, portion);
				
				//trace("ofs: " + ofs + " portion: " + portion);
				
				ofs += portion;
				
				count -= portion;
			}
		}

		private function sampleData(e:SampleDataEvent):void
		{							
			callbackHandler();
			
			//note SampleData API only allows between 2048 and 8192 samples for continued playback			
			var mastervolume:Number = 1.0 / 32767.0;
						
			for (var i:int = 0; i < BUFSIZE*2; ++i)
				e.data.writeFloat( buf[i] * mastervolume );

			BmxWorkBuffer(buf, BUFSIZE);
		}
		
	}
}
