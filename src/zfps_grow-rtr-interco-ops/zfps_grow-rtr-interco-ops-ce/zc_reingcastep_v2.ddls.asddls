@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Memoria de Calculo V2'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCAStep_V2
  as projection on ZI_ReingCAStep
{
  key CalcRunId,
  key LineNum,
  key StepNum,
  key Seq,
      StepCategory,
      TaxType,
      TxRuleId,
      StepDesc,
      InputAmt,
      InputCurrency,
      RatePct,
      RateDesc,
      OutputAmt,
      OutputCurrency,
      Sign,
      SourceTable,
      SourceKey,
      _Line : redirected to parent ZC_ReingCALine_V2,
      _Run  : redirected to ZC_ReingCARun_V2
}
