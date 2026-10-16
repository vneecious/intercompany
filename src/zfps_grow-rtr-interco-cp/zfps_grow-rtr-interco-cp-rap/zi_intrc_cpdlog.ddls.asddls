@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Document Log'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTRC_CPDLog
  as select from zfi_a_intrc_cpdl as _doclog
  association        to exact one ZI_IntercoProposal as _Proposal    on  $projection.Id = _Proposal.Id
  association        to parent ZI_INTRC_CP_DOC       as _ItemDoc     on  $projection.Id           = _ItemDoc.Id
                                                                     and $projection.Documenttype = _ItemDoc.Documenttype
                                                                     and $projection.Documentkey  = _ItemDoc.Documentkey
                                                                     and $projection.CompanyCode  = _ItemDoc.CompanyCode
                                                                     and $projection.FiscalYear   = _ItemDoc.FiscalYear
  association of one to one ZI_INTERCOPROP_DOCTYP_SH as _DocTypeText on  $projection.Documenttype = _DocTypeText.TypId

{
  key _doclog.id                   as Id,
      @ObjectModel.text.element:  [ 'DocumentName' ]
  key _doclog.documenttype         as Documenttype,
  key _doclog.documentkey          as Documentkey,
  key _doclog.companycode  as CompanyCode,
  key _doclog.fiscalyear   as FiscalYear,
      @Semantics.systemDateTime.createdAt: true
  key _doclog.tstmpl               as Tstmpl,
      spras                as Spras,
      _DocTypeText.TypName as DocumentName,
      msgid,
      msgno,
      concat(msgid, msgno) as MSGIDNO,
      msgty,
      msgv1,
      msgv2,
      msgv3,
      msgv4,
      message,
      case msgty
        when 'S'  then 3
        when 'W' then 2
        when 'E' then 1
        when 'I' then 5
        else 0
      end as StatusCriticality,
      _Proposal,
      _ItemDoc
}
