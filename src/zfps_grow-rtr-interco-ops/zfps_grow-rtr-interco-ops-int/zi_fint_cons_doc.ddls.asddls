@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interes Mora - N2 Doc Consolidado'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Documento IC', typeNamePlural: 'Documentos IC',
                  title: { value: 'TradingPartner' }, description: { value: 'Concepto' } }
define view entity ZI_FINT_CONS_DOC
  as select from ZI_FINT_SRC_INV
  association [0..*] to ZI_FINT_SRC_INV as _Facturas
    on  _Facturas.RunId            = $projection.RunId
    and _Facturas.TradingPartner   = $projection.TradingPartner
    and _Facturas.Concepto         = $projection.Concepto
    and _Facturas.InterestCurrency = $projection.InterestCurrency
{
      @UI.facet: [ { id: 'IdDoc', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     position: 10, label: 'Datos del Documento' },
                   { id: 'Fact', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
                     position: 20, label: 'Facturas de Origen',
                     targetElement: '_Facturas' } ]
  key RunId,
      @UI.lineItem: [{ position: 10, criticality: 'StatusCriticality', label: 'Prestataria' }]
      @UI.identification: [{ position: 10, label: 'Prestataria' }]
  key TradingPartner,
      @UI.lineItem: [{ position: 20, label: 'Concepto' }]
      @UI.identification: [{ position: 20, label: 'Concepto' }]
  key Concepto,

      // ---- FIX SDFPSINIC-23382: moneda como key (unicidad OData) ----
      @UI.lineItem: [{ position: 25, label: 'Moneda' }]
      @UI.identification: [{ position: 25, label: 'Moneda' }]
  key InterestCurrency,

      @UI.identification: [{ position: 27, label: 'Sociedad' }]
      max( CompanyCode )       as CompanyCode,

      // ---- Ejercicio del documento consolidado (parametro IBN) ----
      max( ConsFiscalYear )    as ConsFiscalYear,

      // ---- Doc AR / IC : contabilizado en MLA (CompanyCode) ----
      @UI.lineItem: [{ position: 30, label: 'Doc AR (MLA)' }]
      @UI.identification: [{ position: 30, label: 'Doc AR (MLA)' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'CompanyCode',    element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( DocICBelnr )        as DocICBelnr,

      // ---- Doc AP / IR : contabilizado en la PRESTATARIA (TradingPartner = VBUND) ----
      @UI.lineItem: [{ position: 40, label: 'Doc AP (Prest.)' }]
      @UI.identification: [{ position: 40, label: 'Doc AP (Prest.)' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'TradingPartner', element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( DocIRBelnr )        as DocIRBelnr,

      // ---- Doc CH : contabilizado en MLA (CompanyCode) ----
      @UI.lineItem: [{ position: 50, label: 'Doc CH (MLA)' }]
      @UI.identification: [{ position: 50, label: 'Doc CH (MLA)' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'CompanyCode',    element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( DocCHBelnr )        as DocCHBelnr,

      @UI.lineItem: [{ position: 60, label: '# Facturas' }]
      count( * )               as FacturasCount,
      @UI.lineItem: [{ position: 70, label: 'Total' }]
      @UI.identification: [{ position: 70, label: 'Total' }]
      @Semantics.amount.currencyCode: 'InterestCurrency'
      sum( InterestAmount )    as TotalAmount,

      // ---- Semaforo (numerico) ----
      min( StatusCriticality ) as StatusCriticality,

      // ---- Severidad (codigo + texto) ----
      @UI.lineItem: [{ position: 75, label: 'Severidad', criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 75, label: 'Severidad' }]
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: [ 'WorstSeverityText' ]
      case min( StatusCriticality )
        when 1 then 'E'
        when 2 then 'W'
        when 3 then 'S'
        when 5 then 'I'
      end                      as WorstSeverity,

      case min( StatusCriticality )
        when 1 then 'Error'
        when 2 then 'Advertencia'
        when 3 then 'Correcto'
        when 5 then 'Informativo'
      end                      as WorstSeverityText,

      @UI.identification: [{ position: 80, label: 'Fecha' }]
      max( CreationDate )      as CreationDate,
      max( CreationTime )      as CreationTime,
      @UI.identification: [{ position: 90, label: 'Usuario' }]
      max( CreatedByUser )     as CreatedByUser,
      @UI.identification: [{ position: 95, label: 'ID FINT' }]
      max( InterestRunId )     as InterestRunId,
      _Facturas
}
group by
  RunId,
  TradingPartner,
  Concepto,
  InterestCurrency
