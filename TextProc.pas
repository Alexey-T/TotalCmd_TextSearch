unit TextProc;

interface

type
  TText = class
    private
      FFileName: string;
      FText: string;
      FLogFileName: string;
      FLogEnabled: boolean;
      FBoxEnabled: boolean;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      procedure Message(const S: string);
      procedure InitLogging;
      function ReadFile(const fn: string): boolean;
      property Text: string read FText;
    end;

var
  TextObj: TText;
  ConfigIni: string;


implementation

uses
  SysUtils, SProc, SConvert,
  FileUtil, FProc;

//TText
constructor TText.Create;
begin
  Clear;
end;

destructor TText.Destroy;
begin
  Clear;
end;

procedure TText.Clear;
begin
  FFileName:= '';
  FText:= '';
end;


//Search for '{Macro:xxxxx}' substring and returning of 'xxxxx' part
function CmdMacroParam(var Cmd: string; const Macro: string): string;
var
  N, N2: integer;
begin
  Result:= '';
  N:= Pos('{' + Macro + ':', Cmd);
  if N > 0 then
    begin
    N2:= PosFrom('}', Cmd, N);
    Result:= Copy(Cmd, N + Length(Macro) + 2, N2 - N - Length(Macro) - 2);
    Delete(Cmd, N, N2 - N + 1);
    end;
end;

function SCheckAndDelete(var S: string; const SubStr: string): boolean;
var
  n: integer;
begin
  n:= Pos(SubStr, S);
  Result:= n > 0;
  if Result then
    Delete(S, n, Length(SubStr));
end;


procedure TText.Message(const S: string);
var
  f: System.Text;
begin
  if FBoxEnabled then
    DoErrorMessage(S);

  if FLogEnabled then
    begin
    AssignFile(f, FLogFileName);
    Append(f);
    if IOResult <> 0 then
      Rewrite(f);
    if IOResult <> 0 then Exit;
    Writeln(f, Format('%s %s: File "%s" : %s', [DateToStr(Date), TimeToStr(Time), FFileName, S]));
    CloseFile(f);
    end;
end;

procedure TText.InitLogging;
begin
  FLogFileName:= GetTempDir+'\TextSearch.log';
  FLogEnabled:= boolean(StrToInt(GetIniKey('Options', 'Log', '0', ConfigIni)));
  FBoxEnabled:= boolean(StrToInt(GetIniKey('Options', 'ShowErrors', '1', ConfigIni)));
end;


function TText.ReadFile(const fn: string): boolean;
const
  sTempName = 'TextSrch.txt'; //Should be 8.3 name
var
  Cmd, Ext, Dir, Out, OutShort, S: string;
  CPs: set of TMyCodepage;
  CP: TMyCodepage;
  ParamHome: string;
  CmdRequired: boolean;
  i: integer;
begin
  Result:= false;

  FFileName:= fn;
  FText:= '';

  if not FileExists(FFileName) then
    Exit;

  //----------------------------------------------------------
  //Init logging
  InitLogging;

  //----------------------------------------------------------
  //Search for converter

  Ext:= ExtractFileExt(FFileName);
  if Ext <> '' then
    Delete(Ext, 1, 1);

  Cmd:= GetIniKey('Converters', Ext, '', ConfigIni);
  CmdRequired:= false;

  //Extension points to another extension:
  if (Cmd <> '') and (Pos(' ', Cmd) = 0) and (Pos('{', Cmd) = 0) then
    begin
    Cmd:= GetIniKey('Converters', Cmd, '', ConfigIni);
    CmdRequired:= true;
    end
  else
  //Try to find the '*' converter:
  if (Cmd = '') then
    begin
    Cmd:= GetIniKey('Converters', '*', '', ConfigIni);
    end;

  if Cmd='' then
    begin
    if CmdRequired then
      Message(Format('Cannot find specified converter for "%s".', [Ext]));
    Exit
    end;

  Dir:= ExtractFileDir(GetPluginFilename);
  Out:= GetTempDir+'\'+sTempName;
  OutShort:= ExtractShortPathName(GetTempDir)+'\'+sTempName;

  //----------------------------------------------------------
  //Process macros

  //{CP:xxxx}

  CPs:= [];
  repeat
    S:= CmdMacroParam(Cmd, 'CP');
    if S = '' then Break;
    CP:= CodepageStringToCodepageId(S);
    if CP = cpUnknown then
      begin
      Message(Format('Unknown codepage specified for "%s" converter: "%s".', [Ext, S]));
      Exit
      end;
    Include(CPs, CP);
  until false;

  //{Home:xxxx}

  ParamHome:= CmdMacroParam(Cmd, 'Home');
  ParamHome:= DoExpandVars(ParamHome);

  //{In}, {Out} etc

  SReplaceI(Cmd, '{In}', FFileName);
  SReplaceI(Cmd, '{InShort}', ExtractShortPathName(FFileName));
  SReplaceI(Cmd, '{Out}', Out);
  SReplaceI(Cmd, '{OutShort}', OutShort);

  Cmd:= DoExpandVars(Cmd);
  Cmd:= Trim(Cmd); //Need to trim when multiple CPs specified

  //----------------------------------------------------------
  //Run converter or read file directly

  if Pos(' ', Cmd) > 0 then
    //Run converter
    try
      DeleteFile(Out);
      SetCurrentDir(Dir);

      if ParamHome <> '' then
        Dir:= ParamHome;

      case DoRunProcess(Cmd, Dir) of
        run_CannotRun:
          begin
          Message(Format('Cannot run converter for "%s".'#13'Command: "%s".', [Ext, Cmd]));
          Exit
          end;
        run_Exception:
          begin
          Message(Format('Converter exception for "%s".'#13'Command: "%s".', [Ext, Cmd]));
          Exit
          end;
      end;

      FText:= ReadFileToString(Out);
      if FText='' then
        begin
        Message(Format('Cannot convert file "%s" to "%s".'#13'Command: "%s".', [FFileName, Out, Cmd]));
        Exit
        end;
    finally
      DeleteFile(Out);
    end
  else
    //Read directly
    begin
    FText:= ReadFileToString(FFileName);
    if FText='' then
      begin
      Message(Format('Cannot read file "%s".', [FFileName]));
      Exit
      end;
    end;

  //----------------------------------------------------------
  //Perform the decoding

  if CPs <> [] then
    begin
    S:= FText;
    FText:= '';
    for CP in TMyCodepage do
      if CP in CPs then
        FText:= FText + Conv_AnyCodepage(S, CP) + #13#10;
    end;

  //----------------------------------------------------------
  //Delete zeroes (file may be binary):
  for i:= 1 to Length(FText) do
    if FText[i]=#0 then
      FText[i]:= ' ';

  Result:= true;
end;


var
  SampleIni: string;

initialization
  ConfigIni:= ChangeFileName(GetPluginFilename, 'TextSearch.ini');
  SampleIni:= ChangeFileName(GetPluginFilename, 'TextSearch.Sample.ini');
  if not FileExists(ConfigIni) and FileExists(SampleIni) then
    CopyFile(SampleIni, ConfigIni);
  TextObj:= TText.Create;

finalization
  FreeAndNil(TextObj);

end.
