@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calc Prop Document'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_INTRC_CP_DOC
  as select from zfi_a_intrc_cpd as _ProrposalDoc
  association              to exact one ZI_IntercoProposal  as _Proposal          on  $projection.Id = _Proposal.Id
  association [0..1]       to ZI_INTERCOPROPSTATUSDOC_SH    as _Status            on  $projection.Status = _Status.Status

  association [0..1]       to ZI_IntercoProposalItemDoc     as _ChildItemDoc      on  $projection.ParentDocumentKey = _ChildItemDoc.Documentkey
  composition of exact one to many ZI_INTRC_CPDLog          as _log
  association of one       to one ZI_INTERCOPROP_DCAT_SH    as _CategoryText      on  $projection.cat_id = _CategoryText.CatId
  association of one       to one ZI_INTERCOPROP_DOCTYP_SH  as _DocTypeText       on  $projection.Documenttype = _DocTypeText.TypId
  association of one       to one ZI_INTERCOPROP_DOCTYP_SH  as _ParentDocTypeText on  $projection.ParentDocumentType = _ParentDocTypeText.TypId
  association of one       to one ZI_IntercoProposalItemDoc as _ItemDoc           on  $projection.Id           = _ItemDoc.id
                                                                                  and $projection.Documenttype = _ItemDoc.Documenttype
                                                                                  and $projection.Documentkey  = _ItemDoc.Documentkey
                                                                                  and $projection.CompanyCode  = _ItemDoc.CompanyCode
                                                                                  and $projection.FiscalYear   = _ItemDoc.FiscalYear
{
      @Semantics.uuid: true
  key _ProrposalDoc.id                 as Id,
      @ObjectModel.text.element:  [ 'DocumentName' ]
  key _ProrposalDoc.documenttype       as Documenttype,
  key _ProrposalDoc.documentkey        as Documentkey,
  key _ProrposalDoc.companycode        as CompanyCode,
  key _ProrposalDoc.fiscalyear         as FiscalYear,
      @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
      _ItemDoc._Items.ProviderCompanyCode,
      _ItemDoc._Items.ProviderCompanyName,
      @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
      _ItemDoc._Items.recipientcompanycode,
      _ItemDoc._Items.RecipientCompanyName,
      @ObjectModel.text.element:  [ 'ProductName' ]
      _ItemDoc._Items.Product,
      _ItemDoc._Items.ProductName,
      @ObjectModel.text.element:  [ 'ParentDocumentName' ]
      _ProrposalDoc.parentdocumenttype as ParentDocumentType,
      _ProrposalDoc.parentdocumentkey  as ParentDocumentKey,
      parentcompanycode                as ParentCompanyCode,
      parentfiscalyear                 as ParentFiscalYear,
      _DocTypeText.TypName             as DocumentName,
      _ParentDocTypeText.TypName       as ParentDocumentName,
      @ObjectModel.text.element:  [ 'CategoryName' ]
      cat_id,
      _CategoryText.CatName            as CategoryName,
      accountingdocumenttype           as accountingdocumenttype,
      isadjustment                     as Isadjustment,
      isdeleted                        as IsDeleted,
      @Consumption: {
        valueHelpDefinition: [{
            entity: {
                name: 'ZI_IntercoPropStatusCalc_SH',
                element: 'Status'
            }
        }]
      }
      //      @ObjectModel.text.association: '_Status'
      @ObjectModel.text.element:  [ 'StatusName' ]
      status                           as Status,
      _Status.StatusName               as StatusName,
      case status
        when ''  then 2
        when 'C' then 3
        when 'E' then 1
        when 'F' then 3
        when 'G' then 1
        else 0
      end                              as StatusCriticality,
      @Semantics.user.createdBy: true
      createdby                        as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat                        as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangeby                     as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangeat                     as LastChangeAt,
      _Proposal,
      _Status,
      _ChildItemDoc,
      _ItemDoc,
      _log,
      _CategoryText,
      _DocTypeText
}
group by
  id,
  documenttype,
  documentkey,
  companycode,
  fiscalyear,
  _ItemDoc._Items.ProviderCompanyCode,
  _ItemDoc._Items.ProviderCompanyName,
  _ItemDoc._Items.recipientcompanycode,
  _ItemDoc._Items.RecipientCompanyName,
  _ItemDoc._Items.Product,
  _ItemDoc._Items.ProductName,
  _ProrposalDoc.parentdocumenttype,
  _ProrposalDoc.parentdocumentkey,
  parentcompanycode,
  parentfiscalyear,
  _DocTypeText.TypName,
  _ParentDocTypeText.TypName,
  _ParentDocTypeText.TypName,
  cat_id,
  _CategoryText.CatName,
  accountingdocumenttype,
  isadjustment,
  isdeleted,
  status,
  _Status.StatusName,
  createdby,
  createdat,
  lastchangeby,
  lastchangeat
