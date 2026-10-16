@EndUserText.label: 'ME - Resultado Export Template'
define abstract entity ZI_ReingMEExportResult
{
  FileContent : abap.string(0);
  FileName    : abap.char(255);
  MimeType    : abap.char(255);
}
