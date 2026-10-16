@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Document Generated'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_INTRC_CPD
  provider contract transactional_query
  as projection on ZI_INTRC_CP_DOC
{
  key Id,
      @ObjectModel.text.element:  [ 'DocumentName' ]
  key Documenttype,
  key Documentkey,
  key CompanyCode,
  key FiscalYear,
      @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
      ProviderCompanyCode,
      ProviderCompanyName,
      @ObjectModel.text.element:  [ 'recipientcompanyName' ]
      recipientcompanycode,
      RecipientCompanyName,
      @ObjectModel.text.element:  [ 'ProductName' ]
      Product,
      ProductName,
      @ObjectModel.text.element:  [ 'ParentDocumentName' ]
      ParentDocumentType,
      ParentDocumentKey,
      ParentCompanyCode,
      ParentFiscalYear,
      DocumentName,
      ParentDocumentName,
      @ObjectModel.text.element:  [ 'CategoryName' ]
      cat_id as Category_id,
      CategoryName,
      accountingdocumenttype,
      Isadjustment,
      @ObjectModel.text.element:  [ 'StatusName' ]
      Status,
      StatusName,
      StatusCriticality,
      @Semantics.user.createdBy: true
      Createdby,
      @Semantics.systemDateTime.createdAt: true
      Createdat,
      /* Associations */
      _CategoryText,
      _ChildItemDoc,
      _DocTypeText,
      _log : redirected to ZC_INTRC_CPDLog,
      _Proposal,
      _Status
}
where IsDeleted = ''

