@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal: Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoProposalStatus
  as select from zfi_a_cph_stat
  association [0..*] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _StatusText   on  _StatusText.domain_name = 'ZINT_DOM_CPH_STATUS'
                                                                       and _StatusText.value_low   = $projection.Status
                                                                       and _StatusText.language    = $session.system_language
  association [0..*] to ZI_IntercoProposalStatusGroup as _StatusGroup1 on  $projection.StatusGroup1 = _StatusGroup1.StatusGroup
  association [0..*] to ZI_IntercoProposalStatusGroup as _StatusGroup2 on  $projection.StatusGroup1 = _StatusGroup2.StatusGroup
{
      @ObjectModel.text.element: [ 'StatusName' ]
  key status                                                    as Status,
      _StatusText( p_domain_name: 'ZINT_DOM_CPH_STATUS'  ).text as StatusName,
      @ObjectModel.text.association: '_StatusGroup1'
      grp1                                                      as StatusGroup1,
      @ObjectModel.text.association: '_StatusGroup2'
      grp2                                                      as StatusGroup2,
      critic_1                                                  as Criticality1,
      critic_2                                                  as Criticality2,
      _StatusGroup1,
      _StatusGroup2
}
