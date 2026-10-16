@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interes Mora - N1 Run FINT'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Run FINT', typeNamePlural: 'Runs FINT',
                  title: { value: 'RunId' }, description: { value: 'InterestRunId' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'RunDate', direction: #DESC }] }]
define view entity ZI_FINT_RUN
  as select from ZI_FINT_CONS_DOC
  association [0..*] to ZI_FINT_CONS_DOC as _Documentos
    on  _Documentos.RunId            = $projection.RunId
    and _Documentos.InterestCurrency = $projection.InterestCurrency
{
      @UI.facet: [ { id: 'St', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 10, targetQualifier: 'DPStatus' },
                   { id: 'Dt', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 20, targetQualifier: 'DPDate' },
                   { id: 'Us', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 30, targetQualifier: 'DPUser' },
                   { id: 'Dc', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 40, targetQualifier: 'DPDocs' },
                   { id: 'Fc', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 50, targetQualifier: 'DPFact' },
                   { id: 'Tt', purpose: #HEADER, type: #DATAPOINT_REFERENCE, position: 60, targetQualifier: 'DPTotal' },
                   { id: 'Docs', purpose: #STANDARD, type: #LINEITEM_REFERENCE, position: 10,
                     label: 'Documentos de Interes Generados', targetElement: '_Documentos' } ]
      @UI.lineItem: [{ position: 10, criticality: 'StatusCriticality' }]
      @UI.selectionField: [{ position: 10 }]
  key RunId,

      // ---- FIX SDFPSINIC-23382: moneda como key (unicidad OData) ----
      @UI.lineItem: [{ position: 15, label: 'Moneda' }]
      @UI.selectionField: [{ position: 30 }]
  key InterestCurrency,

      @UI.selectionField: [{ position: 40 }]
      max( CompanyCode )       as CompanyCode,
      @UI.lineItem: [{ position: 50, label: '# Docs IC' }]
      @UI.dataPoint: { title: 'Docs IC', qualifier: 'DPDocs' }
      count( * )               as DocsICCount,
      @UI.lineItem: [{ position: 60, label: '# Facturas' }]
      @UI.dataPoint: { title: 'Facturas', qualifier: 'DPFact' }
      sum( FacturasCount )     as FacturasCount,
      @UI.lineItem: [{ position: 70, label: 'Total' }]
      @UI.dataPoint: { title: 'Total', qualifier: 'DPTotal' }
      @Semantics.amount.currencyCode: 'InterestCurrency'
      sum( TotalAmount )       as TotalAmount,

      // ---- Semaforo (numerico) ----
      @UI.dataPoint: { title: 'Estado', qualifier: 'DPStatus', criticality: 'StatusCriticality' }
      min( StatusCriticality ) as StatusCriticality,

      // ---- Severidad (codigo + texto) - filtro SEVERIDAD ----
      @UI.selectionField: [{ position: 50 }]
      @UI.lineItem: [{ position: 45, label: 'Severidad', criticality: 'StatusCriticality' }]
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

      @UI.lineItem: [{ position: 20, label: 'Fecha' }]
      @UI.selectionField: [{ position: 20 }]
      @UI.dataPoint: { title: 'Fecha Run', qualifier: 'DPDate' }
      max( CreationDate )      as RunDate,
      @UI.lineItem: [{ position: 30, label: 'Usuario' }]
      @UI.dataPoint: { title: 'Usuario', qualifier: 'DPUser' }
      max( CreatedByUser )     as CreatedByUser,
      @UI.lineItem: [{ position: 40, label: 'ID FINT' }]
      max( InterestRunId )     as InterestRunId,
      _Documentos
}
group by
  RunId,
  InterestCurrency
