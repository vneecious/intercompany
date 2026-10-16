@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bases Facturables Clasif. - Cabecera'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_INTERCOBASIS
  as select from zfi_a_intrc_bh as head
  composition [1..*] of ZI_IntercoBasisItem as _items

  //  association [0..1] to ZI_IntercoProposal  as _Proposals on head.id = _Proposals.IntercoBasisId
{
  key head.id               as Id,
      head.companycode      as CompanyCode,
      head.fiscalyear       as FiscalYear,
      head.fiscalperiod     as FiscalPeriod,
      head.ledger           as Ledger,
      head.paymenttype      as PaymentType,
      head.isreleased       as IsReleased,
      head.reportexecutedat as ReportExecutedAt,
      // head.createdon        as CreatedOn,
      @Semantics.systemDateTime.createdAt: true
      head.createdat        as CreatedAt,
      @Semantics.user.createdBy: true
      head.createdby        as CreatedBy,
      head.description      as Description,
      head.mindatetime      as Mindatetime,
      head.maxdatetime      as Maxdatetime,
      head.executionstatus  as ExecutionStatus,
      head.last_error_message as LastErrorMessage,
      head.frombackground as FromBackground,
      //Associations
      _items
      //      _Proposals
}
