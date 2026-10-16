@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Log Posting Interes Mora (Consolidado)'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: 'Documento Interes Mora', typeNamePlural: 'Documentos Interes Mora' }
@UI.presentationVariant: [{ sortOrder: [ { by: 'CreationDate', direction: #DESC },
                                         { by: 'CreationTime', direction: #DESC } ] }]
define view entity ZC_FINT_POST_LOG
  as select from ZI_FINT_POST_LOG
{
      @UI.selectionField: [{ position: 10 }]
      @UI.lineItem: [{ position: 10, label: 'Sociedad' }]
  key CompanyCode,
      @UI.lineItem: [{ position: 20, label: 'Socio' }]
  key TradingPartner,
      @UI.selectionField: [{ position: 20 }]
      @UI.lineItem: [{ position: 30, label: 'Concepto' }]
  key Concepto,
      @UI.selectionField: [{ position: 30 }]
      @UI.lineItem: [{ position: 40, label: 'Doc.Consolidado' }]
  key ConsAccountingDocument,
  key ConsFiscalYear,
  key DocumentNumber,
  key InterestRunId,
      @UI.selectionField: [{ position: 40 }]
      @UI.lineItem: [{ position: 50, label: 'Estado Doc' }]
  key DocStatus,
      @UI.lineItem: [{ position: 60, label: 'Estado Run' }]
  key RunStatus,
  key Severity,
  key MsgId,
  key MsgNo,
      @UI.lineItem: [{ position: 70, label: 'Mensaje' }]
  key MsgText,
  key ConsGeneration,
  key ParentConsAccountingDocument,
  key CancelAccountingDocument,
  key InterestCurrency,
  key CreatedByUser,
      @UI.lineItem: [{ position: 80, label: 'Importe Interes' }]
      sum( InterestAmount ) as InterestAmount,
      max( DaysInArrears )  as DaysInArrears,
      @UI.lineItem: [{ position: 90, label: 'Fecha Creacion' }]
      max( CreationDate )   as CreationDate,
      @UI.lineItem: [{ position: 100, label: 'Hora Creacion' }]
      max( CreationTime )   as CreationTime
}
group by
  CompanyCode,
  TradingPartner,
  Concepto,
  ConsAccountingDocument,
  ConsFiscalYear,
  DocumentNumber,
  InterestRunId,
  DocStatus,
  RunStatus,
  Severity,
  MsgId,
  MsgNo,
  MsgText,
  ConsGeneration,
  ParentConsAccountingDocument,
  CancelAccountingDocument,
  InterestCurrency,
  CreatedByUser
