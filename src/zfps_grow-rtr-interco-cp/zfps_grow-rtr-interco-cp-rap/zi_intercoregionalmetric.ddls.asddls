@EndUserText.label: 'Regional Metric Selector Type'

define abstract entity ZI_IntercoRegionalMetric
  //{
  //      // Definir las claves y los tipos
  //  key METRIC       : matkl;
  //  key FISCALYEAR   : fis_gjahr_no_conv;
  //  key FISCALPERIOD : fins_fiscalperiod;
  //  key VERSION      : zde_metric_version;
  //
  //      ISRELEASED   : abap_boolean;
  //      CREATEDBY    : syuname;
  //      // ... (cualquier otro campo necesario)
  //}
{
  // Definimos la clave de la propuesta como parámetro de entrada explícito
  @Consumption.filter.mandatory: true
  ProposalID : abap.raw(16);
}
