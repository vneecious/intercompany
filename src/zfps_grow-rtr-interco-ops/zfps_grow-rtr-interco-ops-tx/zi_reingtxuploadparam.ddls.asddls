@EndUserText.label: 'TX - Param: Upload Excel Reglas'

// DF-TX - Parametro para accion estatica UploadRules de Reglas Fiscales.
// Solo transporta el archivo; las reglas son root sin padre.

define abstract entity ZI_ReingTXUploadParam
{
  FileContent : abap.string(0);
  FileName    : abap.char(255);
}
