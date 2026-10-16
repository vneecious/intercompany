//@EndUserText.label: 'CT V2 - Cronograma Projection'
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@Metadata.allowExtensions: true
//
//// Autor  : EXT_OSCUGALD
//// Fecha  : 04.06.2026
//// Cambio : OpInstanceNum como campo no-key
//
//define view entity ZC_ReingCTCron2
//  as projection on ZI_ReingCTCron2
//{
//  key CtUuid,
//  key MatUuid,
//  key OpType,
//  key CronYear,
//  key CronMonth,
//      OpInstanceNum,
//      Percentage,
//      CronStatus,
//      CreatedBy,
//      CreatedAt,
//      ChangedBy,
//      ChangedAt,
//      _OpType   : redirected to parent ZC_ReingCTOpType2,
//      _Contract : redirected to ZC_ReingCTContract2
//}
@EndUserText.label: 'CT V2 - Cronograma Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTCron2
  as projection on ZI_ReingCTCron2
{
  key CtUuid,
  key MatUuid,
  key OpType,
  key OpUuid,
  key CronYear,
  key CronMonth,
      OpInstanceNum,
      Percentage,
      CronStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _OpType   : redirected to parent ZC_ReingCTOpType2,
      _Contract : redirected to ZC_ReingCTContract2
}
