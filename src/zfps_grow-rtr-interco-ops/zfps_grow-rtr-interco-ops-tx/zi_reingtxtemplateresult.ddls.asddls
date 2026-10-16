@EndUserText.label: 'TX - Resultado: Template Excel Reglas'

// DF-TX - Resultado de la accion estatica DownloadTemplate de Reglas Fiscales.
// Devuelve el archivo .xlsx vacio (solo fila de titulos) con el layout EXACTO
// que espera ZCL_REING_TX_UPLOAD_HDL=>read_rows (columnas A..L), para que el
// usuario no tenga que armarlo a mano ni adivinar el rango.
// FileContent viaja en base64, mismo contrato que ME/CA/CM.

define abstract entity ZI_ReingTXTemplateResult
{
  FileContent : abap.string(0);
  FileName    : abap.char(255);
  MimeType    : abap.char(100);
}
