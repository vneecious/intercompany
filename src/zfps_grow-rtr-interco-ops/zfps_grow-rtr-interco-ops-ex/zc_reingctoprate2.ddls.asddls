//@EndUserText.label: 'CT V2 - Tasas Manuales OP x Receptora Projection'
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@Metadata.allowExtensions: true
//
//define view entity ZC_ReingCTOpRate2
//  as projection on ZI_ReingCTOpRate2
//{
//  key CtUuid,
//  key MatUuid,
//  key OpType,
//  key OpInstanceNum,
//  key BukrsRecv,
//      ManualExchRate,
//      LocalLastChangedAt,
//      _OpType  : redirected to parent ZC_ReingCTOpType2,
//      _Contract : redirected to ZC_ReingCTContract2
//}
@EndUserText.label: 'CT V2 - Tasas Manuales OP x Receptora Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTOpRate2
  as projection on ZI_ReingCTOpRate2
{
  key CtUuid,
  key MatUuid,
  key OpType,
  key OpUuid,
  key OpInstanceNum,
  key BukrsRecv,
      ManualExchRate,
      LocalLastChangedAt,
      _OpType   : redirected to parent ZC_ReingCTOpType2,
      _Contract : redirected to ZC_ReingCTContract2
}
