object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'APU_NES Test'
  ClientHeight = 40
  ClientWidth = 357
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Button3: TButton
    Left = 218
    Top = 8
    Width = 127
    Height = 25
    Caption = 'MoreTick Start/Stop'
    TabOrder = 0
    OnClick = Button3Click
  end
  object ComboBox1: TComboBox
    Left = 8
    Top = 8
    Width = 204
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    ItemIndex = 0
    TabOrder = 1
    Text = 'battle_city_start'
    Items.Strings = (
      'battle_city_start'
      'super_contra_c_stage_1'
      'super_hik_sound'
      'tom_and_jerry_main_theme'
      'tom_and_jerry_stage_2'
      'smb_3_athletic'
      'smb_3_map'
      'smb_2_overworld'
      'smb_1_stage_1'
      'duck_tales_main_theme'
      'proam_main_theme')
  end
end
