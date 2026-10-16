@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'All Error Logs in Proposal'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_INTRC_CPLog
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
      _Proposal.IntercoBasisId,
      @ObjectModel.text.element:  [ 'ProviderCompanyCodeName' ]
      _Proposal.ProviderCompanyCode,
      _Proposal.ProviderCompanyCodeName,
      @ObjectModel.text.element:  [ 'ProductName' ]
      _Proposal.Product,
      _Proposal.ProductName,
      _Proposal.FiscalYear as FiscYear,
      _Proposal.FiscalPeriod,
      @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
      _ItemDoc.recipientcompanycode,
      _ItemDoc.RecipientCompanyName,
//      _ItemDoc._ItemDoc._Items.profitcenter,
//      _ItemDoc._ItemDoc._ItemCalc._ItemsBaOGLAccAQ.Department,
//      _ItemDoc._ItemDoc._ItemCalc._ItemsBaOGLAccAQ.CostCenter,
      //    Spras,
      DocumentName,
      MSGIDNO,
      msgty,
      msgv1,
      msgv2,
      msgv3,
      msgv4,
      message,
      StatusCriticality,
      /* Associations */
      _ItemDoc,
      _Proposal
}
where
      ( msgty   =  'E'
      or msgty = 'W' )
  and MSGIDNO <> 'RW609' //RW609 - "Document $ not generated"
