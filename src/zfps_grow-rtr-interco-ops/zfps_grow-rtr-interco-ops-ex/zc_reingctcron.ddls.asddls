@EndUserText.label: 'CT - Cronograma Devengamiento Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTCron
  as projection on ZI_ReingCTCron
{
  key CtId,
  key Matnr,
  key OpType,
  key CronYear,
  key CronMonth,
      Percentage,
      CronStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _OpType   : redirected to parent ZC_ReingCTOpType,
      _Contract : redirected to ZC_ReingCTContract
}
