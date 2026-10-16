@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calc Prop Item retaled to Document'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define view entity ZC_IntercoProposalItemDoc
  as projection on ZI_IntercoProposalItemDoc
{
  key Id,
  key Item_id as ItemId,
  key Itembasis_id as ItembasisId,
  key Itemcalc_id as ItemcalcId,
  key Documenttype,
  key Documentkey,
  key CompanyCode,
  key FiscalYear,
      DocumentName,
      ParentDocumentKey,
      ParentDocumentType,
      ParentDocumentName,
      ParentCompanyCode,
      ParentFiscalYear,
      Cat_id as Category_id,
      CategoryName,
      Isadjustment,
      Status,
      StatusName,
      StatusCriticality,
      Createdby,
      Createdat,
      /* Associations */
      _Proposal     : redirected to ZC_IntercoProposalTP,
      _Items        : redirected to ZC_IntercoProposalItemTP,
      _ItemsBasis   : redirected to ZC_IntercoProposalItemBasisTP,
      _ItemCalc     : redirected to parent ZC_IntercoProposalItemCalcTP,
      _Status,
      _ChildItemDoc : redirected to ZC_IntercoProposalItemDoc,
      _CategoryText,
      _DocTypeText
}
