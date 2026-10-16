@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Calculation Proposal - DocFlow Categ'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalDocCategory
  as select from zfi_a_intrc_dtyp
{
  key dtyp_id                                     as TypeID,
      dtyp_name                                   as TypeName,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_INTRC_PROPOSAL_DOCCAT_VE'
      cast(0 as abap.int4)                        as Postion,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_INTRC_PROPOSAL_DOCCAT_VE'
      cast('sap-icon://receipt' as abap.char(50)) as Icon
}
