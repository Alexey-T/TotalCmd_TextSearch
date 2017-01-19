{$I-}

unit TextProc;

{$MODE Delphi}

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
  Text: TText;
  Ini: string;


implementation

uses
  Windows, SysUtils, SProc, SConvert,
  FProc;

type
  TMyCodepage = (
    cpUnknown,
    cpANSI,
    cpOEM,
    cpUTF8,
    cpUTF16,
    cpUTF16BE,
    cpUTF16LE,
    cpRTF
    );

const
  cCodepageNames: array[TMyCodepage] of string = (
    '',
    'ANSI',
    'OEM',
    'UTF8',
    'UTF16',
    'UTF16BE',
    'UTF16LE',
    'RTF'
    );

function SCodepageIdToCodepage(const S: string): TMyCodepage;
var
  i: TMyCodepage;
begin
  Result:= cpUnknown;
  for i in TMyCodepage do
    if S = cCodepageNames[i] then
      begin Result:= i; Break end;
end;

function SConvertFromCodepage(const S: string; CP: TMyCodepage): string;
begin
  Result:= '';
  case CP of
    cpANSI:
      Result:= S;
    cpOEM:
      begin
        SetLength(Result, Length(S));
        OemToAnsiBuff(PChar(S), PChar(Result), Length(S));
      end;
    cpUTF8:
      Result:= Conv_Utf8_ToANSI(S);
    cpUTF16:
      Result:= Conv_UnicodeAuto_ToANSI(S);
    cpUTF16BE:
      Result:= Conv_UnicodeBE_ToANSI(S);
    cpUTF16LE:
      Result:= Conv_UnicodeLE_ToANSI(S);
    cpRTF:
      Result:= Conv_RtfToText(S);
  end;
end;


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
    MessageBox(0, PChar(S), 'TextSearch plugin', MB_OK or MB_ICONERROR or MB_TASKMODAL);

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
  FLogEnabled:= boolean(StrToInt(GetIniKey('Options', 'Log', '0', Ini)));
  FBoxEnabled:= boolean(StrToInt(GetIniKey('Options', 'ShowErrors', '1', Ini)));
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

  Cmd:= GetIniKey('Converters', Ext, '', Ini);
  CmdRequired:= false;

  //Extension points to another extension:
  if (Cmd <> '') and (Pos(' ', Cmd) = 0) and (Pos('{', Cmd) = 0) then
    begin
    Cmd:= GetIniKey('Converters', Cmd, '', Ini);
    CmdRequired:= true;
    end
  else
  //Try to find the '*' converter:
  if (Cmd = '') then
    begin
    Cmd:= GetIniKey('Converters', '*', '', Ini);
    end;

  if Cmd='' then
    begin
    if CmdRequired then
      Message(Format('Cannot find specified converter for "%s".', [Ext]));
    Exit
    end;

  Dir:= ExtractFileDir(GetPluginFilename);
  Out:= GetTempDir+'\'+sTempName;
  OutShort:= FShortName(GetTempDir)+'\'+sTempName;

  //----------------------------------------------------------
  //Process macros

  //{CP:xxxx}

  CPs:= [];
  repeat
    S:= CmdMacroParam(Cmd, 'CP');
    if S = '' then Break;
    CP:= SCodepageIdToCodepage(S);
    if CP = cpUnknown then
      begin
      Message(Format('Unknown codepage specified for "%s" converter: "%s".', [Ext, S]));
      Exit
      end;
    Include(CPs, CP);
  until false;

  //{Home:xxxx}

  ParamHome:= CmdMacroParam(Cmd, 'Home');
  ParamHome:= SExpandVars(ParamHome);

  //{In}, {Out} etc

  SReplaceI(Cmd, '{In}', FFileName);
  SReplaceI(Cmd, '{InShort}', FShortName(FFileName));
  SReplaceI(Cmd, '{Out}', Out);
  SReplaceI(Cmd, '{OutShort}', OutShort);

  Cmd:= SExpandVars(Cmd);
  Cmd:= Trim(Cmd); //Need to trim when multiple CPs specified

  //----------------------------------------------------------
  //Run converter or read file directly

  if Pos(' ', Cmd) > 0 then
    //Run converter
    try
      DeleteFile(PChar(Out));
      SetCurrentDirectory(PChar(Dir));

      if ParamHome <> '' then
        Dir:= ParamHome;

      case FExecProcess(Cmd, Dir, SW_HIDE, true) of
        exCannotRun:
          begin
          Message(Format('Cannot run converter for "%s".'#13'Command: "%s".', [Ext, Cmd]));
          Exit
          end;
        exExcept:
          begin
          Message(Format('Converter exception for "%s".'#13'Command: "%s".', [Ext, Cmd]));
          Exit
          end;
      end;

      if not FReadToString(Out, FText) then
        begin
        Message(Format('Cannot convert file "%s" to "%s".'#13'Command: "%s".', [FFileName, Out, Cmd]));
        Exit
        end;
    finally
      DeleteFile(PChar(Out));
    end
  else
    //Read directly
    begin
    if not FReadToString(FFileName, FText) then
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
    for CP:= Low(TMyCodepage) to High(TMyCodepage) do
      if CP in CPs then
        FText:= FText + SConvertFromCodepage(S, CP) + #13#10;
    end;

  //----------------------------------------------------------
  //Delete zeroes (file may be binary):
  for i:= 1 to Length(FText) do
    if FText[i]=#0 then
      FText[i]:= ' ';

  Result:= true;
end;


var
  ss: string;
initialization
  Ini:= ChangeFileName(GetPluginFilename, 'TextSearch.ini');
  ss:= ChangeFileName(GetPluginFilename, 'TextSearch.Sample.ini');
  if not FileExists(Ini) then
    CopyFile(PChar(ss), PChar(Ini), true);
  Text:= TText.Create;

finalization
  FreeAndNil(Text);

end.