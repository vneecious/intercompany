@EndUserText.label: 'MC - Contratos vinculados Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingMCContracts
  as select from ZI_ReingMCContracts
{
  key MetricCode,
  key VersionNum,
  key CtUuid,
  key MatUuid,
  key MetricSeq,
      CtId,
      ExtContract,
      Lifnr,
      Bukrs,
      Responsible,
      CtStatus,
      ValidFrom,
      ValidTo,
      Matnr,
      MetStatus
}
