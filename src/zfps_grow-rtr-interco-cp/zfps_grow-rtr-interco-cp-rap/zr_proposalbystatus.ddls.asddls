@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Resume Proposal by Status'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZR_PROPOSALBYSTATUS as select from ZI_IntercoProposalStatus_SH
as _sh
inner join ZI_IntercoProposal as _h on _h.Status = _sh.Status
inner join zfi_a_cph_stat as _sts on _h.Status = _sts.status
inner join zfi_a_stat_grp as _stsgrp on _stsgrp.status_grp = _sts.grp1
                                    and _stsgrp.langu = $session.system_language
{
    key _stsgrp.status_grp as Status, 
    _stsgrp.stat_grp_name as StatusName,
    _sts.critic_1 as StatusCriticaly,
//    case _stsgrp.status_grp
//        when 'W' then 2
//        when ''  then 0
//        when 'E' then 1
//        when 'S' then 3
//        else 4
//    end    as StatusCriticaly,
    count( distinct _h.Id ) as quan
}
group by _stsgrp.status_grp, _stsgrp.stat_grp_name, _sts.critic_1
 