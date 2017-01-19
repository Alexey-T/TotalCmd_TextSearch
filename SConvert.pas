unit SConvert;

{$MODE Delphi}

interface 

type
  TCodepage = array[0 .. $7F] of char; 

function Conv_UnicodeAuto_ToANSI(const S: string): string;
function Conv_UnicodeBE_ToANSI(const S: string): string;
function Conv_UnicodeLE_ToANSI(const S: string): string;
function Conv_Utf8_ToANSI(const S: string): string;
function Conv_RtfToText(const Value: String): String;


implementation 

//-----------------------------------------------------------
{
From Universal Viewer, SProc.pas
}

function SetStringW(Buffer: PChar; BufSize: Integer; SwapBytes: Boolean): WideString;
var
  P: PChar;
  i, j: Integer;
  ch: char;
begin
  Result := '';
  if BufSize < 2 then Exit;

  SetLength(Result, BufSize div 2);
  Move(Buffer^, Result[1], Length(Result) * 2);

  if SwapBytes then
  begin
    P := @Result[1];
    for i := 1 to Length(Result) do
    begin
      j := (i - 1) * 2;
      ch := P[j];
      P[j] := P[j + 1];
      P[j + 1] := ch;
    end;
  end;
end;

function Conv_UnicodeAuto_ToANSI(const S: string): string;
begin
  Result:= SetStringW(PChar(S), Length(S), (Length(S) >= 2) and (S[1] = #$FE) and (S[2] = #$FF));
end;

function Conv_UnicodeBE_ToANSI(const S: string): string;
begin
  Result:= SetStringW(PChar(S), Length(S), true);
end;

function Conv_UnicodeLE_ToANSI(const S: string): string;
begin
  Result:= SetStringW(PChar(S), Length(S), false);
end;

function Conv_Utf8_ToAnsi(const S: string): string;
var
  SW: Widestring;
  i: integer;
begin
  SW:= UTF8Decode(S);
  SetLength(Result, Length(SW));
  for i:= 1 to Length(SW) do
    Result[i]:= Char(SW[i]);
end;

//-----------------------------------------------------------
function SConvertToANSI(const S, CP: string): string; 
var 
  i: integer; 
begin 
  Result:= ''; 
  for i := 1 to Length(S) do
  begin 
    if Ord(S[i]) < $80 then
      Result:= Result + S[i]
    else
      Result := Result + CP[Ord(S[i]) - $80]; 
  end;
end; 


//-----------------------------------------------------------
{
(C) Alex Demchenko(alex@ritlabs.com)
}

function HexToInt(Value: String): LongWord;
const
  HexStr: String = '0123456789abcdef';
var
  i: Word;
begin
  Result := 0;
  if Value = '' then Exit;
  for i := 1 to Length(Value) do
    Inc(Result, (Pos(Value[i], HexStr) - 1) shl ((Length(Value) - i) shl 2));
end;

{Convert RTF enabled text to plain.}
function Conv_RtfToText(const Value: String): String;
var
  i: Word;
  tag: Boolean;
  st: String;
begin
  Result := ''; tag := False; st := '';
  if Value = '' then Exit;
  if Copy(Value, 0, 6) <> '{\rtf1' then
  begin
    Result := Value;
    Exit;
  end;
  for i := 1 to Length(Value) do
  begin
    if Value[i] in ['\', '}', '{'] then
      tag := True;
    if Value[i + 1] in ['\', '}', '{'] then
    begin
      tag := False;
      if st <> '' then
      begin
        if st = 'par' then Result := Result + #13#10
        else if (st[1] = '''') and (Length(st) >= 3) then
        begin
          Delete(st, 1, 1);
          Result := Result + Chr(HexToInt(Copy(st, 0, 2))) + Copy(st, 3, Length(st) - 2);
        end
        else if ((Pos(' ', st) > 0) or ((Copy(st, 0, 3) = 'par') and (st <> 'pard'))) and (st[Length(st)] <> ';') then
        begin
          while (Pos(#13, st) > 0) do Delete(st, Pos(#13, st), 1);
          while (Pos(#10, st) > 0) do Delete(st, Pos(#10, st), 1);
          if Copy(st, 0, 3) = 'par' then
            Result := Result + #13#10 + Copy(st, 4, Length(st) - 3)
          else
            Result := Result + Copy(st, Pos(' ', st) + 1, Length(st) - Pos(' ', st));
        end;
      end;
      st := '';
    end;
    if tag then
      st := st + Value[i + 1];
  end;
end;



end. 
