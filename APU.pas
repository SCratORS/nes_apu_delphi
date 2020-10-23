unit APU;

interface
uses MMSystem, Windows;

type
  u8    = Byte;
  u16   = Word;
  u32   = LongWord;
  bool  = Boolean;
  int   = Integer;
  short = SmallInt;
  pInt  = ^Integer;
  float = Double;
  s8    = ShortInt;

type RegBit = packed record
    private
      var reg_data: u32;
      function get_bit(Index: Integer):u16;
      procedure set_bit(Index: Integer; Value: u16);
    public
      // 4000, 4004, 400C, 4012:
      property reg0: u16                    index $0008 read get_bit write set_bit;// 0-8
      property DutyCycle: u16               index $0602 read get_bit write set_bit;// 6-2
      property EnvDecayLoopEnable: u16      index $0501 read get_bit write set_bit;// 5-1
      property LengthCounterDisable: u16    index $0501 read get_bit write set_bit;// 5-1
      property EnvDecayDisable: u16         index $0401 read get_bit write set_bit;// 4-1
      property EnvDecayRate: u16            index $0004 read get_bit write set_bit;// 0-4
      property FixedVolume: u16             index $0004 read get_bit write set_bit;// 0-4
      property LinearCounterInit: u16       index $0007 read get_bit write set_bit;// 0-7
      property LinearCounterDisable: u16    index $0701 read get_bit write set_bit;// 7-1
      // 4001, 4005, 4013:
      property reg1: u16                    index $0808 read get_bit write set_bit;// 8-8
      property SweepShift: u16              index $0803 read get_bit write set_bit;// 8-3
      property SweepDecrease: u16           index $0B01 read get_bit write set_bit;// 11-1
      property SweepRate: u16               index $0C03 read get_bit write set_bit;// 12-3
      property SweepEnable: u16             index $0F01 read get_bit write set_bit;// 15-1
      property PCMlength: u16               index $0808 read get_bit write set_bit;// 8-8
      // 4002, 4006, 400A, 400E:
      property reg2: u16                    index $1008 read get_bit write set_bit;// 16-8
      property NoiseFreq: u16               index $1004 read get_bit write set_bit;// 16-4
      property NoiseType: u16               index $1701 read get_bit write set_bit;// 23-1
      property WaveLength: u16              index $100B read get_bit write set_bit;// 16-11
      // 4003, 4007, 400B, 400F, 4010:
      property reg3: u16                    index $1808 read get_bit write set_bit;// 24-8
      property LengthCounterInit: u16       index $1B05 read get_bit write set_bit;// 27-5
      property LoopEnabled: u16             index $1E01 read get_bit write set_bit;// 30-1
      property IRQenable: u16               index $1F01 read get_bit write set_bit;// 31-1
end;

type
  TChannel = packed record
    level, phase, envelope, linear_counter:u8;
    hold, address, length_counter, wave_counter,sweep_delay,env_delay:u16;
    reg: RegBit;
    function tick(c:u8):u8;
  end;

type
  Thz240counter = packed record
    lo, hi: short;
  end;

const LengthCounters: array [0..31] of u8  = ( 10,254,20, 2,40, 4,80, 6,160, 8,60,10,14,12,26,14, 12, 16,24,18,48,20,96,22,192,24,72,26,16,28,32,30 );
const NoisePeriods  : array [0..15] of u16 = ( 2,4,8,16,32,48,64,80,101,127,190,254,381,508,1017,2034 );
const DMCperiods    : array [0..15] of u16 = ( 428,380,340,320,286,254,226,214,190,160,142,128,106,85,72,54 );

const SoundSamplesPerSec = 192000;
const buffer_size = SoundSamplesPerSec div 8;
const SkeepBuffer = round(1789773 / SoundSamplesPerSec * 2);

var
FiveCycleDivider: bool = false; IRQdisable: bool = true;
ChannelsEnabled: array [0..4] of bool = ( false, false, false, false, false );
PeriodicIRQ: bool = false; DMC_IRQ: bool = false;
channels: array [0..4] of TChannel;
ROMAddress: PByte;
ROMOffset:u16;
hz240counter: Thz240counter;
buffer: array [0..1, 0..buffer_size] of u8;
bufptr: u32 = 0;
SelectBuf: byte;
wh :array [0..1] of  TWAVEHDR;
hwo: HWAVEOUT;
hEvent: THandle;

procedure init;
procedure tick;
procedure write(index: u8; value: u8);
function read():u8;

implementation

procedure init;
var
wfx : TWAVEFORMATEX;
i:integer;
begin
  FillChar(wfx,Sizeof(TWAVEFORMATEX),#0);
  with wfx do begin
    wFormatTag := WAVE_FORMAT_PCM;
    nChannels := 1;
    nSamplesPerSec := SoundSamplesPerSec;
    wBitsPerSample := 8;
    nBlockAlign := wBitsPerSample div 8 * nChannels;
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
    cbSize := 0;
  end;
 hEvent := CreateEvent(nil,false,false,nil);
 WaveOutOpen(@hwo,0,@wfx,hEvent,0,CALLBACK_EVENT);
 for I := 0 to buffer_size do begin
  buffer[0,i]:=0;
  buffer[1,i]:=0;
 end;
 for i := 0 to 1 do begin
  with wh[i] do begin
  lpData := @buffer[i];
  dwBufferLength := sizeof(buffer[i]);
  dwFlags := 0;
  dwLoops := 0;
 end;
 waveOutPrepareHeader(hwo, @wh[i], sizeof(TWAVEHDR));
 end;
end;

function iif(opr:bool; a,b:u8):u8;begin if opr then result:=a else result:=b;end;
function count(var v: u16; reset: u16): bool;begin result:=false;if v = 0 then begin v := reset;result:=true;end else dec(v);end;

procedure write(index: u8; value: u8);
var
  ch, c: u8;
begin
  ch := (index div 4) mod 5;
  case iif(index<$10, index mod 4, index) of
  0: channels[ch].reg.reg0 := value;
  1: begin channels[ch].reg.reg1 := value; channels[ch].sweep_delay := channels[ch].reg.SweepRate; end;
  2: channels[ch].reg.reg2 := value;
  3: begin
      channels[ch].reg.reg3 := value;
      channels[ch].length_counter := LengthCounters[channels[ch].reg.LengthCounterInit];
      channels[ch].linear_counter := channels[ch].reg.LinearCounterInit;
      channels[ch].env_delay      := channels[ch].reg.EnvDecayRate;
      channels[ch].envelope       := 15;
     end;
  $10: begin channels[ch].reg.reg3 := value; channels[ch].reg.WaveLength := DMCperiods[value and $0F]; end;
  $11: channels[ch].linear_counter := value and $7F; // dac value
  $12: begin channels[ch].reg.reg0 := value; channels[ch].address :=  (channels[ch].reg.reg0 or $300) shl 6; end;
  $13: begin channels[ch].reg.reg1 := value; channels[ch].length_counter := (channels[ch].reg.PCMlength shl 4) + 1; end; // sample length
  $15: for c := 0 to 4 do begin
          ChannelsEnabled[c] := (value and (1 shl c))<>0;
          if(not ChannelsEnabled[c]) then channels[c].length_counter := 0
            else if(c = 4) and (channels[c].length_counter = 0) then begin
            channels[c].length_counter := (channels[c].reg.PCMlength shl 4) + 1;
            channels[c].address :=  (channels[c].reg.reg0 or $300) shl 6;
            end;
        end;
  $17: begin
         IRQdisable       := (value and $40)<>0;
         FiveCycleDivider := (value and $80)<>0;
         hz240counter.lo:=0; hz240counter.hi:=0;
         if (IRQdisable) then begin
           PeriodicIRQ := false;
           DMC_IRQ := false;
         end;
       end;
  end;
end;

function read():u8;
var
c: u8;
begin
  result := 0;
  for c := 0 to 4 do result:= result or iif((channels[c].length_counter)<>0, 1 shl c, 0);
  if(PeriodicIRQ) then result := result or $40; PeriodicIRQ := false;
  if(DMC_IRQ) then result := result or $80; DMC_IRQ := false;
end;

procedure tick;
  function _s(c:u8):u8;begin result:=channels[c].tick(c);end;
  function _v(m,n,d: float):float;begin if n <> 0.0 then result:=m/n else result:=d;end;
var
  HalfTick, FullTick: bool;
  c: u8;
  wl,s: int;
  d: array [0..3] of int;
  sample: u8;
begin
  hz240counter.lo := hz240counter.lo + 2;
  if(hz240counter.lo >= 14913) then begin
    hz240counter.lo := hz240counter.lo - 14913;
    inc(hz240counter.hi);
    if(hz240counter.hi >= 4 + u8(FiveCycleDivider)) then hz240counter.hi := 0;
    if( not IRQdisable and not FiveCycleDivider and (hz240counter.hi=0)) then {CPU::intr = }PeriodicIRQ := true;
    HalfTick := (hz240counter.hi and 5) = 1; FullTick := hz240counter.hi < 4 + u8(FiveCycleDivider);
    for c := 0 to 3 do begin
      wl := channels[c].reg.WaveLength;
      if(HalfTick and (channels[c].length_counter<>0) and not((iif(c=2,channels[c].reg.LinearCounterDisable,channels[c].reg.LengthCounterDisable))<>0)) then dec(channels[c].length_counter);
      if(HalfTick and (c < 2) and count(channels[c].sweep_delay, channels[c].reg.SweepRate)) then
                    if((wl >= 8) and (channels[c].reg.SweepEnable<>0) and (channels[c].reg.SweepShift<>0)) then
                    begin
                        s := wl shr channels[c].reg.SweepShift;
                        d[0]:=s;d[1]:=s;d[2]:= not s; d[3]:=-s;
                        wl := wl + d[channels[c].reg.SweepDecrease*2 + c];
                        if(wl < $800) then channels[c].reg.WaveLength := wl;
                    end;
      if(FullTick and (c = 2)) then channels[c].linear_counter := iif((channels[c].reg.LinearCounterDisable)<>0,channels[c].reg.LinearCounterInit,iif(channels[c].linear_counter > 0,channels[c].linear_counter - 1,0));
      if(FullTick and (c <> 2) and count(channels[c].env_delay, channels[c].reg.EnvDecayRate)) then
                    if ((channels[c].envelope > 0) or (channels[c].reg.EnvDecayLoopEnable>0)) then channels[c].envelope := (channels[c].envelope-1) and $F;
    end;
  end;
  sample := round($FF * (_v(95.88, (100.0 + _v(8128.0, _s(0) + _s(1), -100.0)), 0.0) + _v(159.79, (100.0 + _v(1.0, _s(2)/(8227.0) + _s(3)/(12241.0) + _s(4)/(22638.0), -100.0)), 0.0)));
  //write sample to out buffer;
  if (hz240counter.lo mod SkeepBuffer) < 2 then begin
    buffer[SelectBuf, bufptr]:=sample;
    inc(bufptr);
  end;
  if (bufptr > buffer_size) then begin
    bufptr := 0;
    waveOutWrite(hwo, @wh[SelectBuf], sizeof(WAVEHDR));
    WaitForSingleObject(hEvent, INFINITE);
    SelectBuf:= SelectBuf xor 1;
  end;
end;

{ channel }

function Tchannel.tick(c:u8): u8;
var
wl:u16;
s: PByte;
v: int;
ROM_Data: PByte;
volume:u8;
begin
  if(not ChannelsEnabled[c]) or (length_counter = 0) then begin result := iif(c=4,64,8);exit;end;
  case c of
    0..1: wl:=(reg.WaveLength+1) shl 1;
    3:    wl:=NoisePeriods[reg.NoiseFreq] shl 1;
    else  wl:=(reg.WaveLength+1);
  end;
  volume := iif((length_counter<>0),iif((reg.EnvDecayDisable<>0),reg.FixedVolume,envelope),0);
  S := @level;
  if( not count(wave_counter, wl)) then begin result := S^; exit;end;
  case c of
    2: begin
      if ((length_counter=0) or (linear_counter=0)) then begin
        S^ := 8;result:= S^;exit;
      end;
      S^ := (phase and $F) xor iif((phase and $10)<>0,$F,0);
      inc(phase);
      result:= S^;exit;
    end;
    3: begin // Noise: Linear feedback shift register
      if hold=0 then hold := 1;
      hold := (hold shr 1) or (((hold xor (hold shr iif(reg.NoiseType<>6,1,1))) and 1) shl 14);
      S^ := iif((hold and 1)<>0,volume,0);
      result:=S^;exit;
    end;
    4: begin// Delta modulation channel (DMC)
      if(phase = 0) then begin// Nothing in sample buffer?
        if(length_counter=0) and (reg.LoopEnabled<>0) then begin // Loop?
          length_counter :=  (reg.PCMlength shl 4) + 1;
          address        :=  (reg.reg0 or $300) shl 6;
        end;
        if(length_counter > 0) then begin// Load next 8 bits if available
          ROM_Data := ROMAddress;
          Inc(ROM_Data, (address or $8000) - ROMOffset);
          hold  := ROM_Data^;
          inc(address);
          phase := 8;
          dec(length_counter);
        end else begin// Otherwise, disable channel or issue IRQ
          DMC_IRQ := true;
          ChannelsEnabled[4] := False;
        end;
      end;
      if(phase > 0) then begin// Update the signal if sample buffer nonempty
        v := linear_counter;
        dec(phase);
        if(hold and ($80 shr phase))<>0 then v := v + 2 else v := v - 2;
        if((v >= 0) and (v <= $7F)) then linear_counter := v;
      end;
      S^ := linear_counter;
      result:= S^;exit;
    end;
    else begin// Square wave. With four different 8-step binary waveforms (32 bits of data total).
      if(wl < 8) then begin s^ := 8;result:= S^;exit;end;
      S^ := iif(($9F786040 and (1 shl ((reg.DutyCycle shl 3) + (phase mod 8))))<>0,volume,0);
      inc(phase);
      result:=S^;exit;
    end;
  end;
end;

{ RegBit }

function RegBit.get_bit(Index: Integer): u16;
begin
  result:= (reg_data shr (index shr 8)) and ((1 shl (index and $F)) - 1);
end;

procedure RegBit.set_bit(Index: Integer; Value: u16);
var
  bitno:u8;
  mask:u32;
begin
  bitno:=index shr 8;
  mask:=(1 shl (index and $F)) - 1;
  reg_data := (reg_data and not(mask shl bitno)) or ((Value and mask) shl bitno);
end;

end.
