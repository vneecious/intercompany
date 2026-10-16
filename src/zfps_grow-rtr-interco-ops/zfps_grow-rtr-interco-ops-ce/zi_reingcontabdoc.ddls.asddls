@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONTAB - Documentos FI Generados (MON)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_ReingContabDoc
  as select from zreing_cb_doc_a
  association [0..*] to ZI_ReingContabDocItem as _Item
    on  $projection.CalcRunId   = _Item.CalcRunId
    and $projection.LineNum     = _Item.LineNum
    and $projection.DocTypeCode = _Item.DocTypeCode
  // Begin Change (27.08.2026 | EXT_AGFAGINA) - descripcion legible del tipo de documento
  // DOC_TYPE_CODE es un codigo de 10 chars (ANTARD15, ACTINT...). Se asocia al
  // catalogo para poder mostrar la descripcion en pantalla en lugar del codigo crudo.
  association [0..1] to zreing_doctype_c as _DocType
    on $projection.DocTypeCode = _DocType.doc_type_code
  // End Change (27.08.2026 | EXT_AGFAGINA)
{
  key calc_run_id    as CalcRunId,
  key line_num       as LineNum,
      @ObjectModel.text.element: ['DocTypeDesc']
  key doc_type_code  as DocTypeCode,
      _DocType.description as DocTypeDesc,
      bukrs          as CompanyCode,
      belnr          as DocumentNumber,
      gjahr          as FiscalYear,
      blart          as DocumentType,
      budat          as PostingDate,
      reversal_date  as ReversalDate,
      waers          as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      total_amount   as TotalAmount,
      num_items      as NumberOfItems,
      status         as Status,
      simulated      as Simulated,
      reverse_belnr  as ReverseDocNumber,
      created_by     as CreatedBy,
      created_at     as CreatedAt,
      _Item
}
