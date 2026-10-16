@EndUserText.label: 'CT - Param: Upload Excel Receptoras'

// Autor  : AGF
// Fecha  : 18.06.2026
// P9 - Parametro para accion UploadExcel de Sociedades Receptoras

define abstract entity ZI_ReingCTRecvUploadParam
{
  CtUuid      : sysuuid_x16;
  MatUuid     : sysuuid_x16;
  FileContent : abap.string(0);
  FileName    : abap.char(255);
}
