program Project1;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  SkImageCache in 'SkImageCache.pas',
  SkVirtualList.Core in 'SkVirtualList.Core.pas',
  SkUiDsl in 'SkUiDsl.pas',
  SkCardRenderers.Biz in 'SkCardRenderers.Biz.pas',
  Unit1 in 'Unit1.pas' {Form1};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
