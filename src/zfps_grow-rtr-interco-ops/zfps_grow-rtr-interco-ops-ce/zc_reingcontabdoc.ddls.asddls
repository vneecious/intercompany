@EndUserText.label: 'CONTAB - Documentos FI (MON, consumo)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
// Begin Change (27.08.2026 | EXT_AGFAGINA) - consulta de documento contable en app CA
// Anotaciones UI inline (no DDLX: la vista no declara @Metadata.allowExtensions).
@UI.headerInfo: {
  typeName:       'Documento Contable',
  typeNamePlural: 'Documentos Contables',
  title:          { type: #STANDARD, value: 'DocumentNumber' },
  description:    { type: #STANDARD, value: 'DocTypeDesc' }
}
// End Change (27.08.2026 | EXT_AGFAGINA)
define view entity ZC_ReingContabDoc
  as select from ZI_ReingContabDoc
  association [0..*] to ZC_ReingContabDocItem as _ItemC
    on  $projection.CalcRunId   = _ItemC.CalcRunId
    and $projection.LineNum     = _ItemC.LineNum
    and $projection.DocTypeCode = _ItemC.DocTypeCode
{
      @UI.facet: [
        { id: 'ContabDocItemTab', type: #LINEITEM_REFERENCE,
          label: 'Posiciones', position: 10,
          targetElement: '_ItemC' }
      ]
  key CalcRunId,
  key LineNum,
      @UI.lineItem: [{ position: 10, importance: #HIGH, label: 'Tipo Documento' }]
  key DocTypeCode,
      DocTypeDesc,
      @UI.lineItem: [{ position: 20, importance: #HIGH, label: 'Nro. Documento' }]
      DocumentNumber,
      // Restaurado (27.08.2026): FiscalYear se habia perdido al reescribir la lista
      // de campos. Es parte de la identidad del documento FI (BUKRS+BELNR+GJAHR),
      // no puede faltar. ReversalDate idem (fecha de estorno).
      @UI.lineItem: [{ position: 25, importance: #MEDIUM, label: 'Ejercicio' }]
      FiscalYear,
      @UI.lineItem: [{ position: 30, importance: #MEDIUM, label: 'Sociedad' }]
      CompanyCode,
      @UI.lineItem: [{ position: 40, importance: #LOW, label: 'Clase Doc.' }]
      DocumentType,
      @UI.lineItem: [{ position: 50, importance: #MEDIUM, label: 'Fecha Contab.' }]
      PostingDate,
      @UI.lineItem: [{ position: 60, importance: #HIGH, label: 'Importe' }]
      @Semantics.amount.currencyCode: 'Currency'
      TotalAmount,
      @UI.lineItem: [{ position: 70, importance: #LOW, label: 'Moneda' }]
      Currency,
      @UI.lineItem: [{ position: 80, importance: #HIGH, label: 'Estado',
                       criticality: 'DocCriticality',
                       criticalityRepresentation: #WITH_ICON }]
      Status,
      @UI.lineItem: [{ position: 90, importance: #MEDIUM, label: 'Simulado' }]
      Simulated,
      @UI.lineItem: [{ position: 100, importance: #MEDIUM, label: 'Doc. Estorno' }]
      ReverseDocNumber,
      @UI.lineItem: [{ position: 105, importance: #LOW, label: 'Fecha Estorno' }]
      ReversalDate,
      @UI.lineItem: [{ position: 110, importance: #LOW, label: 'Nro. Posiciones' }]
      NumberOfItems,
      CreatedBy,
      CreatedAt,
      // Criticidad del documento: estornado = negativo (1), simulado = critico (2),
      // contabilizado = positivo (3). Consumido por @UI.lineItem de Status.
      case
        when ReverseDocNumber is not initial then 1
        when Simulated        =  'X'         then 2
        else                                      3
      end as DocCriticality,
      _ItemC
}
