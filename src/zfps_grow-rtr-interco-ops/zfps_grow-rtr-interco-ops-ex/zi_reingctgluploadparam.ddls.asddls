@EndUserText.label: 'CT - Param: Upload Excel Lineas GL'

// Autor  : AGF
// DF-515 - Parametro para accion UploadGLLines de Lineas GL

define abstract entity ZI_ReingCTGLUploadParam
{
  CtUuid      : sysuuid_x16;
  MatUuid     : sysuuid_x16;
  FileContent : abap.string(0);
  FileName    : abap.char(255);
}
