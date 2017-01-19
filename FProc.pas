unit FProc;

{$MODE Delphi}

interface

uses
  Windows, ShellAPI, SysUtils, FileUtil;

type
  TExecCode = (exOk, exCannotRun, exExcept);

function SExpandVars(const s: string): string;
function FExecProcess(const CmdLine, CurrentDir: string; ShowCmd: integer; DoWait: boolean): TExecCode;
function FReadToString(const fn: string; var s: string): boolean;
function FWriteString(const fn: string; const s: string): boolean;
function FSearchDir(const sname, sdir: string; var fn: string): boolean;
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


function FReadToString(const fn: string; var s: string): boolean;
const
  cMaxSize = 200*1024*1024;
var
  Buffer: PAnsiChar;
  BufferSize: Int64;
  ReadSize: DWORD;
  Handle: THandle;
begin
  Result:= false;
  S:= '';

  BufferSize:= FileSize(fn);
  if (BufferSize=0) or (BufferSize>cMaxSize) then Exit;

  Handle:= CreateFile(PChar(fn), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
  if Handle=INVALID_HANDLE_VALUE then Exit;

  GetMem(Buffer, BufferSize+1);
  FillChar(Buffer^, BufferSize+1, 0);
  ReadSize:= 0;
  if not ReadFile(Handle, Buffer^, BufferSize, ReadSize, nil) then
    begin FileClose(Handle); { *Converted from CloseHandle* } Exit end;
  S:= AnsiString(Buffer);
  FreeMem(Buffer);

  FileClose(Handle); { *Converted from CloseHandle* }
  Result:= true;
end;


function FWriteString(const fn: string; const s: string): boolean;
var
  Handle: THandle;
  OutSize: DWORD;
begin
  Result:= false;
  if s='' then Exit;

  Handle:= CreateFile(PChar(fn), GENERIC_WRITE, FILE_SHARE_READ, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  Result:= Handle<>INVALID_HANDLE_VALUE;
  if not Result then Exit;

  Result:= WriteFile(Handle, s[1], Length(s), OutSize, nil);
  FileClose(Handle); { *Converted from CloseHandle* }
end;


function FSearchDir(const sname, sdir: string; var fn: string): boolean;
var
  h: THandle;
  fd: TWin32FindData;
begin
  if not DirectoryExists(sdir) then begin Result:= false; Exit end;

  h:= FindFirstFile(PChar(sdir+'\'+sname), fd);
  Result:= h<>INVALID_HANDLE_VALUE;
  if Result then
    begin fn:= sdir+'\'+fd.cFileName; Windows.FindClose(h); Exit end;

  h:= FindFirstFile(PChar(sdir+'\*.*'), fd);
  if h=INVALID_HANDLE_VALUE then Exit;

  repeat
    if ((fd.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY)<>0) and
      (fd.cFileName[0]<>'.') then
        begin
        Result:= FSearchDir(sname, sdir+'\'+fd.cFileName, fn);
        if Result then Break;
        end;

  until not FindNextFile(h, fd);

  Windows.FindClose(h);
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
