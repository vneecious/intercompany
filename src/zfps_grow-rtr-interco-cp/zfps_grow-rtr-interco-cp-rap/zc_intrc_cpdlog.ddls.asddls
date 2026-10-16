@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Document Logs'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_INTRC_CPDLog
  provider contract transactional_query
  as projection on ZI_INTRC_CPDLog
{
  key Id,
      @ObjectModel.text.element:  [ 'DocumentName' ]
  key Documenttype,
  key Documentkey,
  key CompanyCode,
  key FiscalYear,
  key Tstmpl,
      DocumentName,
      msgty,
      message,
      StatusCriticality,
      /* Associations */
//      _ItemDoc,
      _Proposal
}
