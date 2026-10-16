@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONTAB - Items del Documento FI (MON)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_ReingContabDocItem
  as select from zreing_cb_item_a
  association [1..1] to ZI_ReingContabDoc as _Doc
    on  $projection.CalcRunId   = _Doc.CalcRunId
    and $projection.LineNum     = _Doc.LineNum
    and $projection.DocTypeCode = _Doc.DocTypeCode
{
  key calc_run_id   as CalcRunId,
  key line_num      as LineNum,
  key doc_type_code as DocTypeCode,
  key item_num      as ItemNumber,
      role_code     as RoleCode,
      hkont         as GLAccount,
      posting_side  as PostingSide,
      @Semantics.amount.currencyCode: 'Currency'
      amount        as Amount,
      waers         as Currency,
      kostl         as CostCenter,
      prctr         as ProfitCenter,
      campana       as Campaign,
      allocation    as Allocation,
      zuonr         as Assignment,
      _Doc
}
