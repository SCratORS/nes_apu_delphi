unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, APU, ExtCtrls, resources;
type
  PByteArray = ^TByteArray;
  TForm1 = class(TForm)
    Button3: TButton;
    ComboBox1: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    procedure writeAPU(arrd:u16; v:u8);
    procedure InfinityTick(mus:PByteArray);
  public
    { Public declarations }
  end;


var
  Form1: TForm1;
  runningTick:Boolean;
implementation

{$R *.dfm}

procedure TForm1.Button3Click(Sender: TObject);
begin
if runningTick then runningTick:=false else begin
runningTick:=true;
case combobox1.ItemIndex of
0:  InfinityTick(@resources.battle_city_start);
1:  InfinityTick(@resources.super_contra_c_stage_1);
2:  InfinityTick(@resources.super_hik_sound);
3:  InfinityTick(@resources.tom_and_jerry_main_theme);
4:  InfinityTick(@resources.tom_and_jerry_stage_2);
5:  InfinityTick(@resources.smb_3_athletic);
6:  InfinityTick(@resources.smb_3_map);
7:  InfinityTick(@resources.smb_2_overworld);
8:  InfinityTick(@resources.smb_1_stage_1);
9:  InfinityTick(@resources.duck_tales_main_theme);
10:  InfinityTick(@resources.proam_main_theme);
end;
//resources.battle_city_start
//resources.super_contra_c_stage_1;
//resources.super_hik_sound;
//resources.tom_and_jerry_main_theme;
//resources.tom_and_jerry_stage_2
//resources.smb_3_athletic;
//resources.smb_3_map;
//resources.smb_2_overworld;
//resources.smb_1_stage_1
//resources.duck_tales_main_theme
//resources.proam_main_theme
//resources.jungle_book_title   <-- for test. not work =(
end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  APU.init;
end;

procedure TForm1.InfinityTick(mus:PByteArray);
var
i:u32;
vgm_index:u32;
vgm_wait:u32;
wait:array [$62..$63] of u16;
begin
wait[$62]:=$02DF;
wait[$63]:=$0372;
vgm_index := PLongWord(@mus^[$34])^;
if vgm_index = $0C then vgm_index:=$40
else vgm_index:=vgm_index+$34;
APU.ROMAddress:=@mus^[0];
vgm_wait:=0;

while runningTick do begin
  if (vgm_wait = 0) then begin
    case mus^[vgm_index] of
     $61: begin vgm_wait:=PWord(@mus^[vgm_index+1])^;
          vgm_index :=vgm_index+2;
          end;
     $62..$63: vgm_wait := wait[mus^[vgm_index]];
     $64: begin wait[mus^[vgm_index+1]]:=PWord(@mus^[vgm_index+2])^;
          vgm_index := vgm_index+3;
          end;
     $66: runningTick:=false;
     $67: begin
          APU.ROMAddress:=@mus^[vgm_index+9];
          APU.ROMOffset:=PWord(@mus^[vgm_index+7])^;
          vgm_index:= vgm_index + PLongWord(@mus^[vgm_index+3])^ + 6;
          end;
     $70..$7F: vgm_wait:= (mus^[vgm_index] and $0F) + 1;
     $B4: begin writeAPU(mus^[vgm_index + 1], mus^[vgm_index + 2]);
          vgm_index := vgm_index+2;
          end;
     else showmessage('0x'+inttohex(mus^[vgm_index],2)+' at '+inttostr(vgm_index div 16));
    end;
    inc(vgm_index);
  end else dec(vgm_wait);
  for i := 0 to 42 do APU.tick;
end;
  for i := 0 to 42 do APU.tick;
end;

procedure TForm1.writeAPU(arrd:u16; v:u8);
begin
APU.write(arrd and $1F, v);
end;

end.
