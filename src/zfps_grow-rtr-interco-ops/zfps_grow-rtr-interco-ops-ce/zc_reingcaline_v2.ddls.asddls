@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Lineas de Calculo V2'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALine_V2
  as projection on ZI_ReingCALine
{
  key CalcRunId,
  key LineNum,
      CtUuid,
      CtId,
      Lifnr,
      BpName,
      BukrsPrest,
      MatUuid,
      Matnr,
      OpType,
      OpUuid,
      OpInstanceNum,
      ParentOpType,
      OriginRunId,
      OriginLineNum,
      ParentNetAmt,
      ParentCurrency,
      DeferPct,
      DeferCuotaNum,
      DeferCuotaTotal,
      DeferFrom,
      DeferTo,
      BukrsRecv,
      Country,
      BaseAmt,
      SharePct,
      SharePaisPct,
      ShareCombPct,
      CalcAmt,
      BrutoAmt,
      GrossUpAmt,
      TaxAmt,
      NetAmt,
      CtCurrency,
      NetLocalAmt,
      LocalCurrency,
      ExchRate,
      ExchRateType,
      IsDelta,
      DeltaSeq,
      DeltaBaseAmt,
      LineStatus,
      SimMessage,
      ProcStartedAt,
      ProcHeartbeatAt,
      ProcJobId,
      InsumoCheckAt,
      FiAwkey,
      LocalLastChangedAt,
      _LinePC : redirected to composition child ZC_ReingCALinePC_V2,
      _Step   : redirected to composition child ZC_ReingCAStep_V2,
      _Log    : redirected to composition child ZC_ReingCALog_V2,
      _Run    : redirected to parent ZC_ReingCARun_V2
}
