@EndUserText.label: 'CA - Resultado Export Excel'

// F6-07 - Parametro de resultado para accion ExportExcel (CalcRun)
// Mismo shape que ZI_ReingMEExportResult (precedente FX-XLS, App ME)
define abstract entity ZI_ReingCAExportResult
{
  FileContent : abap.string(0);
  FileName    : abap.char(255);
  MimeType    : abap.char(255);
}
