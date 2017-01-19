unit FProc;

interface

uses
  Windows, SysUtils, FileUtil;

type
  TExecCode = (exOk, exCannotRun, exExcept);

function SExpandVars(const s: string): string;
function FExecProcess(const CmdLine, CurrentDir: string; ShowCmd: integer; DoWait: boolean): TExecCode;
function FShortName(const fn: string): string;

function GetPluginFilename: string;
function ChangeFileName(const fn, NewName: string): string;
function GetTempDir: string;


implementation

function SExpandVars(const s: string): string;
var
  buf: array[0..2*1024-1] of char;
begin
  SetString(Result, buf, ExpandEnvironmentStrings(PChar(s), buf, SizeOf(buf))-1);
end;


function FExecProcess(const CmdLine, CurrentDir: string; ShowCmd: integer; DoWait: boolean): TExecCode;
var
  pi: TProcessInformation;
  si: TStartupInfo;
  code: DWord;
begin
  FillChar(pi, SizeOf(pi), 0);
  FillChar(si, SizeOf(si), 0);
  si.cb:= SizeOf(si);
  si.dwFlags:= STARTF_USESHOWWINDOW;
  si.wShowWindow:= ShowCmd;

  if not CreateProcess(nil, PChar(CmdLine), nil, nil, false, 0,
    nil, PChar(CurrentDir), si, pi) then
    Result:= exCannotRun
  else
    begin
    if DoWait then WaitForSingleObject(pi.hProcess, INFINITE);
    if GetExitCodeProcess(pi.hProcess, code) and
      (code >= $C0000000) and (code <= $C000010E) then
      Result:= exExcept
    else
      Result:= exOk;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    end;
end;


function GetPluginFilename: string;
begin
  Result:= GetModuleName(HInstance);
end;

function ChangeFileName(const fn, NewName: string): string;
var
  i: integer;
begin
  i:= Length(fn);
  while (i>0) and (fn[i]<>'\') do Dec(i);
  Result:= Copy(fn, 1, i)+NewName;
end;

function GetTempDir: string;
begin
  Result:= SExpandVars('%temp%');
end;


function FShortName(const fn: string): string;
var
  buf: array[0..MAX_PATH] of char;
begin
  SetString(Result, buf, GetShortPathName(PChar(fn), buf, SizeOf(buf)));
end;


end.
