//----------------------------------------------------------------------
// Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Change ID      : V001 (CC)
// Date           : 08.07.2026
// Description    : App CA - Motor de Calculo IC - F3.1 Fundamentos RAP (DD-B6)
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
//Begin Change V002 (CC) - bug #78: missing accent in view label
@EndUserText.label: 'CA - Memoria de Cálculo (Drill-down)'
//End Change V002 (CC)
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCAStep
  as projection on ZI_ReingCAStep
{
  key CalcRunId,
  key LineNum,
  key StepNum,
  key Seq,
      StepCategory,
      // V001 (CC) - #118: expose semantic row highlighting.
      RowCriticality,
      TaxType,
      TxRuleId,
      StepDesc,
      InputAmt,
      InputCurrency,
      RatePct,
      RateDesc,
      OutputAmt,
      OutputCurrency,
      // V001 (CC) - CA-11 (Brazil): additive transaction output.
      TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      OutputTransAmt,
      Sign,
      SourceTable,
      SourceKey,
      _Line : redirected to parent ZC_ReingCALine,
      //Begin Insert V001 (CC) - DD-B6
      _Run : redirected to ZC_ReingCARun
      //End Insert V001 (CC) - DD-B6
}

