@EndUserText.label: 'CONTAB - Items FI (MON, consumo)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_ReingContabDocItem
  as select from ZI_ReingContabDocItem
{
  key CalcRunId,
  key LineNum,
  key DocTypeCode,
      @UI.lineItem: [{ position: 10, importance: #HIGH, label: 'Pos.' }]
  key ItemNumber,
      @UI.lineItem: [{ position: 20, importance: #HIGH, label: 'Rol Contable' }]
      RoleCode,
      @UI.lineItem: [{ position: 30, importance: #HIGH, label: 'Cuenta GL' }]
      GLAccount,
      @UI.lineItem: [{ position: 40, importance: #MEDIUM, label: 'D/H' }]
      PostingSide,
      @UI.lineItem: [{ position: 50, importance: #HIGH, label: 'Importe' }]
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      @UI.lineItem: [{ position: 60, importance: #LOW, label: 'Moneda' }]
      Currency,
      @UI.lineItem: [{ position: 70, importance: #MEDIUM, label: 'Centro Costo' }]
      CostCenter,
      @UI.lineItem: [{ position: 80, importance: #MEDIUM, label: 'Centro Beneficio' }]
      ProfitCenter,
      @UI.lineItem: [{ position: 90, importance: #LOW, label: 'Campana' }]
      Campaign,
      @UI.lineItem: [{ position: 100, importance: #LOW, label: 'Asignacion' }]
      Allocation,
      @UI.lineItem: [{ position: 110, importance: #LOW, label: 'Referencia' }]
      Assignment
}
