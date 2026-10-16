@EndUserText.label: 'CM - Param: Upload Excel'
define abstract entity ZI_ReingCMUploadParam
{
  PeriodYear  : abap.numc(4);
  PeriodMonth : abap.numc(2);
  FileContent : abap.string(0);
  FileName    : abap.char(255);
}
