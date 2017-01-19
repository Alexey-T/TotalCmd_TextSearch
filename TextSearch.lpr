library TextSearch;

uses
  SysUtils, ContPlug,
  SProc, TextProc;

const
  _FieldsNum = 1;
  _Fields: array[0.._FieldsNum-1] of PChar = ('Text');
  _FieldTypes: array[0.._FieldsNum-1] of integer = (FT_FULLTEXT);
  _FieldUnits: array[0.._FieldsNum-1] of PChar = ('');


function ContentGetSupportedField(
  FieldIndex: integer;
  FieldName, Units: PChar;
  maxlen: integer): integer; stdcall;
begin
  if (FieldIndex<0) or (FieldIndex>=_FieldsNum) then
    Exit(FT_NOMOREFIELDS);

  StrLCpyA(FieldName, _Fields[FieldIndex], MaxLen);
  StrLCpyA(Units, _FieldUnits[FieldIndex], MaxLen);
  Result:= _FieldTypes[FieldIndex];
end;


function ContentGetValue(
  NamePtr: PChar;
  FieldIndex, UnitIndex: integer;
  FieldValue: PAnsiChar;
  MaxLen, Flags: integer): integer; stdcall;
begin
  Result:= FT_FIELDEMPTY;
end;


function ContentGetValueW(
  NamePtr: PWideChar;
  FieldIndex, UnitIndex: integer;
  FieldValue: PByte;
  MaxLen, Flags: integer): integer; stdcall;
var
  Filename, s: string;
begin
  if (Flags and CONTENT_DELAYIFSLOW)>0 then
    Exit(FT_DELAYED);

  if (FieldIndex=Pred(_FieldsNum)) then
  begin
    //Clear cache
    if UnitIndex=-1 then
    begin
      TextObj.Clear;
      Exit(FT_FIELDEMPTY);
    end;

    //MessageBox(0, PChar(IntToStr(UnitIndex)), 'UnitIndex', MB_OK);
    if UnitIndex=0 then
    begin
      Filename:= UTF8Encode(WideString(NamePtr));
      if not TextObj.ReadFile(Filename) then
        Exit(FT_FILEERROR);
    end;

    s:= Copy(TextObj.Text, UnitIndex+1, MaxLen);
    if s='' then
      Exit(FT_FIELDEMPTY);

    StrLCpyA(PChar(FieldValue), PChar(s), MaxLen);
    Exit(FT_FULLTEXT);
  end;

  Result:= FT_FIELDEMPTY;
end;


//--------------------------------------------
exports
  ContentGetSupportedField,
  ContentGetValue,
  ContentGetValueW;

end.
