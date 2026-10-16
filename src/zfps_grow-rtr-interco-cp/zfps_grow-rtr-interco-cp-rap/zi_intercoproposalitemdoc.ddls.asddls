@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calc Prop Item retaled to Document gen'
@Metadata.ignorePropagatedAnnotations: false
define view entity ZI_IntercoProposalItemDoc
  as select from zfi_a_intrc_cpid as _ItemDoc
  association        to exact one ZI_IntercoProposal          as _Proposal          on  $projection.id = _Proposal.Id
  association        to exact one ZI_IntercoProposalItem      as _Items             on  $projection.id      = _Items.Id
                                                                                    and $projection.item_id = _Items.Item_Id
  association        to exact one ZI_IntercoProposalItemBasis as _ItemsBasis        on  $projection.id           = _ItemsBasis.id
                                                                                    and $projection.item_id      = _ItemsBasis.item_id
                                                                                    and $projection.itembasis_id = _ItemsBasis.itembasis_id
  association        to parent ZI_IntercoProposalItemCalc     as _ItemCalc          on  $projection.id           = _ItemCalc.id
                                                                                    and $projection.item_id      = _ItemCalc.item_id
                                                                                    and $projection.itembasis_id = _ItemCalc.itembasis_id
                                                                                    and $projection.itemcalc_id  = _ItemCalc.itemcalc_id
  association [0..1] to ZI_INTERCOPROPSTATUSDOC_SH            as _Status            on  $projection.Status = _Status.Status

  association [0..1] to ZI_IntercoProposalItemDoc             as _ChildItemDoc      on  $projection.ParentDocumentKey = _ChildItemDoc.Documentkey
  //  composition of exact one to many zi_intercoproposallog            as _log
  //  association of one to many ZI_INTRC_CPDLog                  as _log               on  $projection.Id           = _log.Id
  //                                                                                    and $projection.Documenttype = _log.Documenttype
  //                                                                                    and $projection.Documentkey  = _log.Documentkey
  //                                                                                    and $projection.CompanyCode  = _ItemDoc.companycode
  //                                                                                    and $projection.FiscalYear   = _ItemDoc.fiscalyear
  association of one to one ZI_INTERCOPROP_DCAT_SH            as _CategoryText      on  $projection.cat_id = _CategoryText.CatId
  association of one to one ZI_INTERCOPROP_DOCTYP_SH          as _DocTypeText       on  $projection.Documenttype = _DocTypeText.TypId
  association of one to one ZI_INTERCOPROP_DOCTYP_SH          as _ParentDocTypeText on  $projection.ParentDocumentType = _ParentDocTypeText.TypId
{
      @Semantics.uuid: true
  key id,
  key item_id,
  key itembasis_id,
  key itemcalc_id,
      @ObjectModel.text.element:  [ 'DocumentName' ]
  key documenttype                as Documenttype,
  key documentkey                 as Documentkey,
  key _ItemDoc.companycode        as CompanyCode,
  key _ItemDoc.fiscalyear         as FiscalYear,
      _ItemDoc.parentdocumentkey  as ParentDocumentKey,
      @ObjectModel.text.element:  [ 'ParentDocumentName' ]
      _ItemDoc.parentdocumenttype as ParentDocumentType,
      _DocTypeText.TypName        as DocumentName,
      _ParentDocTypeText.TypName  as ParentDocumentName,
      _ItemDoc.parentcompanycode  as ParentCompanyCode,
      _ItemDoc.parentfiscalyear   as ParentFiscalYear,
      @ObjectModel.text.element:  [ 'CategoryName' ]
      cat_id,
      _CategoryText.CatName       as CategoryName,
      accountingdocumenttype      as accountingdocumenttype,
      isadjustment                as Isadjustment,
      isdeleted                   as IsDeleted,
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
      status                      as Status,
      _Status.StatusName          as StatusName,
      case status
        when ''  then 2
        when 'C' then 3
        when 'E' then 1
        else 0
      end                         as StatusCriticality,
      @Semantics.user.createdBy: true
      createdby                   as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat                   as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangeby                as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangeat                as LastChangeAt,
      _Proposal,
      _Items,
      _ItemsBasis,
      _ItemCalc,
      _Status,
      _ChildItemDoc,
      //      _log,
      _CategoryText,
      _DocTypeText
}
//where _ItemDoc.parentdocumentkey is initial
where
  status <> ''
