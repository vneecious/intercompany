@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Apertura Profit Center V2'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALinePC_V2
  as projection on ZI_ReingCALinePC
{
  key CalcRunId,
  key LineNum,
  key PcSeq,
      Prctr,
      ShareAbs,
      CalcAmt,
      BrutoAmt,
      TaxAmt,
      NetAmt,
      CtCurrency,
      NetLocalAmt,
      LocalCurrency,
      _Line : redirected to parent ZC_ReingCALine_V2,
      _Run  : redirected to ZC_ReingCARun_V2
}
