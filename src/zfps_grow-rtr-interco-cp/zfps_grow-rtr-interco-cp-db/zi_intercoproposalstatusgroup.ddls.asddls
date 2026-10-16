@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal: Status Group'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoProposalStatusGroup
  as select from zfi_a_stat_grp
{
  key status_grp    as StatusGroup,
      @Semantics.language: true
  key langu         as Language,
      stat_grp_name as StatusGroupName
}
