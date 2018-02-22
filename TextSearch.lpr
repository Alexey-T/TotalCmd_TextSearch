library TextSearch;

uses
  SysUtils, ContPlug,
  SProc, TextProc;

const
  _FieldsNum = 2;
  _Fields: array[0.._FieldsNum-1] of PChar = ('Text', 'Text (ansi)');
  _FieldTypes: array[0.._FieldsNum-1] of integer = (FT_FULLTEXTW, FT_FULLTEXT);
  _FieldUnits: array[0.._FieldsNum-1] of PChar = ('', '');


function ContentGetSupportedField(
  FieldIndex: integer;
  FieldName, Units: PChar;
  maxlen: integer): integer; stdcall;
begin
  if (FieldIndex<0) or (FieldIndex>=_FieldsNum) then
    Exit(FT_NOMOREFIELDS);

  StrCopyBuf(FieldName, _Fields[FieldIndex], MaxLen);
  StrCopyBuf(Units, _FieldUnits[FieldIndex], MaxLen);
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
  Filename, StrA: string;
  StrW: Widestring;
begin
  if (Flags and CONTENT_DELAYIFSLOW)>0 then
    Exit(FT_DELAYED);

  if (FieldIndex=0) or (FieldIndex=1) then
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

    StrW:= Copy(UTF8Decode(TextObj.Text), UnitIndex+1, MaxLen);
    if StrW='' then
      Exit(FT_FIELDEMPTY);

    if FieldIndex=0 then
    begin
      StrCopyBufW(PWideChar(FieldValue), PWideChar(StrW), MaxLen);
      Exit(FT_FULLTEXTW);
    end
    else
    begin
      StrA:= StrW;
      StrCopyBuf(PChar(FieldValue), PChar(StrA), MaxLen);
      Exit(FT_FULLTEXT);
    end;
  end;

  Result:= FT_FIELDEMPTY;
end;


//--------------------------------------------
exports
  ContentGetSupportedField,
  ContentGetValue,
  ContentGetValueW;

end.
