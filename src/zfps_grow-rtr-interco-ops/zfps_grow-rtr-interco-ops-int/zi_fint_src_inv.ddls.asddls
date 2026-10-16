@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interes Mora - N3 Factura Origen'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Factura Origen', typeNamePlural: 'Facturas Origen',
                  title: { value: 'SourceAccountingDocument' },
                  description: { value: 'TradingPartner' } }
define view entity ZI_FINT_SRC_INV
  as select from ZI_FINT_POST_LOG
{
      @UI.facet: [ { id: 'IdFact', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     position: 10, label: 'Detalle de la Factura' } ]
  key RunId,
  key TradingPartner,
  key Concepto,
      @UI.lineItem: [{ position: 10, label: 'Doc. Origen', criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 10, label: 'Doc. Origen' }]
  key SourceAccountingDocument,
      @UI.lineItem: [{ position: 20, label: 'Ejercicio' }]
      @UI.identification: [{ position: 20, label: 'Ejercicio' }]
  key SourceFiscalYear,

      // ---- FIX SDFPSINIC-23382: moneda como key (unicidad OData) ----
      @UI.identification: [{ position: 22, label: 'Moneda' }]
  key InterestCurrency,

      @UI.lineItem: [{ position: 30, label: 'Sociedad' }]
      @UI.identification: [{ position: 30, label: 'Sociedad' }]
      max( CompanyCode )                                                     as CompanyCode,

      // ---- Ejercicio del documento consolidado (parametro IBN) ----
      max( ConsFiscalYear )                                                  as ConsFiscalYear,

      // ---- Doc IC : contabilizado en MLA (CompanyCode) ----
      @UI.lineItem: [{ position: 40, label: 'Doc IC' }]
      @UI.identification: [{ position: 40, label: 'Doc IC' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'CompanyCode',    element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( case DocClass when 'IC' then ConsAccountingDocument else '' end ) as DocICBelnr,

      // ---- Doc IR : contabilizado en la PRESTATARIA (TradingPartner = VBUND) ----
      @UI.lineItem: [{ position: 50, label: 'Doc IR' }]
      @UI.identification: [{ position: 50, label: 'Doc IR' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'TradingPartner', element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( case DocClass when 'IR' then ConsAccountingDocument else '' end ) as DocIRBelnr,

      // ---- Doc CH : contabilizado en MLA (CompanyCode) ----
      @UI.lineItem: [{ position: 60, label: 'Doc CH' }]
      @UI.identification: [{ position: 60, label: 'Doc CH' }]
      @Consumption.semanticObject: 'AccountingDocument'
      @Consumption.semanticObjectMapping.element: 'AccountingDocument'
      @Consumption.semanticObjectMapping.additionalBinding: [ { localElement: 'CompanyCode',    element: 'CompanyCode' },
                                                              { localElement: 'ConsFiscalYear', element: 'FiscalYear' } ]
      max( case DocClass when 'CH' then ConsAccountingDocument else '' end ) as DocCHBelnr,

      @UI.lineItem: [{ position: 70, label: 'Importe' }]
      @UI.identification: [{ position: 70, label: 'Importe' }]
      @Semantics.amount.currencyCode: 'InterestCurrency'
      max( case DocClass when 'IC' then InterestAmount else 0 end )          as InterestAmount,
      @UI.lineItem: [{ position: 80, label: 'Dias Mora' }]
      @UI.identification: [{ position: 80, label: 'Dias Mora' }]
      max( DaysInArrears )                                                   as DaysInArrears,

      // ---- Semaforo (numerico) ----
      min( case Severity
             when 'E' then 1
             when 'W' then 2
             when 'S' then 3
             when 'I' then 5
             else 3
           end )                                                             as StatusCriticality,

      // ---- Severidad (codigo + texto) ----
      @UI.lineItem: [{ position: 85, label: 'Severidad', criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 85, label: 'Severidad' }]
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: [ 'WorstSeverityText' ]
      case min( case Severity
                  when 'E' then 1
                  when 'W' then 2
                  when 'S' then 3
                  when 'I' then 5
                  else 3
                end )
        when 1 then 'E'
        when 2 then 'W'
        when 3 then 'S'
        when 5 then 'I'
      end                                                                    as WorstSeverity,

      case min( case Severity
                  when 'E' then 1
                  when 'W' then 2
                  when 'S' then 3
                  when 'I' then 5
                  else 3
                end )
        when 1 then 'Error'
        when 2 then 'Advertencia'
        when 3 then 'Correcto'
        when 5 then 'Informativo'
      end                                                                    as WorstSeverityText,

      @UI.lineItem: [{ position: 90, label: 'Mensaje' }]
      @UI.identification: [{ position: 90, label: 'Mensaje' }]
      max( MsgText )                                                         as MsgText,
      @UI.identification: [{ position: 100, label: 'Fecha' }]
      max( CreationDate )                                                    as CreationDate,
      max( CreationTime )                                                    as CreationTime,
      @UI.identification: [{ position: 110, label: 'Usuario' }]
      max( CreatedByUser )                                                   as CreatedByUser,
      max( InterestRunId )                                                   as InterestRunId
}
group by
  RunId,
  TradingPartner,
  Concepto,
  SourceAccountingDocument,
  SourceFiscalYear,
  InterestCurrency
