@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bases Facturables Clasificadas- Cabecera'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_INTERCOBASIS
  provider contract transactional_query
  as projection on ZI_INTERCOBASIS
{
  key Id,
      CompanyCode,
      FiscalYear,
      FiscalPeriod,
      Ledger,
      PaymentType,
      IsReleased,
      ReportExecutedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      Description,
      ExecutionStatus,
      LastErrorMessage,
      /* Associations */
      _items : redirected to composition child ZC_INTERCOBASISITEM
      //      _proposals
}
