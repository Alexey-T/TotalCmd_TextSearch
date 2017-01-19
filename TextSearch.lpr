library TextSearch;

{$MODE Delphi}

uses
  Windows, SysUtils, ContPlug,
  SProc, FProc, TextProc;

const
  _FieldsNum = 1;
  _Fields: array[0.._FieldsNum-1] of PChar = ('Text');
  _FieldTypes: array[0.._FieldsNum-1] of integer = (FT_FULLTEXT);
  _FieldUnits: array[0.._FieldsNum-1] of PChar = ('');

//--------------------------------------------
function ContentGetSupportedField(
  FieldIndex: integer;
  FieldName, Units: pAnsiChar;
  maxlen: integer): integer; stdcall;
begin
  if (FieldIndex<0) or (FieldIndex>=_FieldsNum) then
    begin Result:= FT_NOMOREFIELDS; Exit end;

  StrLCpyA(FieldName, PAnsiChar(Ansistring(_Fields[FieldIndex])), MaxLen);
  StrLCpyA(Units, PAnsiChar(Ansistring(_FieldUnits[FieldIndex])), MaxLen);
  Result:= _FieldTypes[FieldIndex];
end;

//--------------------------------------------
function ContentGetValue(fn: pAnsiChar;
  FieldIndex, UnitIndex: integer;
  FieldValue: PAnsiChar;
  maxlen, flags: integer): integer; stdcall;
begin
  Result:= FT_FIELDEMPTY;
end;

function ContentGetValueW(fn: pWideChar;
  FieldIndex, UnitIndex: integer;
  FieldValue: PByte;
  maxlen, flags: integer): integer; stdcall;
var
  s: string;  
begin
  if (flags and CONTENT_DELAYIFSLOW)>0 then
    begin Result:= FT_DELAYED; Exit end;

  //Text field
  if (FieldIndex=Pred(_FieldsNum)) then
    begin
    //Clear cache
    if UnitIndex=-1 then
    begin
      Text.Clear;
      Result:= FT_FIELDEMPTY;
      Exit
    end;

    //MessageBox(0, PChar(IntToStr(UnitIndex)), 'UnitIndex', MB_OK);
    if UnitIndex=0 then
      if not Text.ReadFile(fn) then
        begin Result:= FT_FILEERROR; Exit end;

    s:= Copy(Text.Text, UnitIndex+1, MaxLen);
    if s='' then
      Result:= FT_FIELDEMPTY
    else
    begin
      StrLCpyA(PAnsiChar(FieldValue), PAnsiChar(Ansistring(s)), MaxLen);
      Result:= FT_FULLTEXT;
    end;
    Exit;
    end;

  Result:= FT_FIELDEMPTY;
end;


//--------------------------------------------
exports
  ContentGetSupportedField,
  ContentGetValue,
  ContentGetValueW;

end.
