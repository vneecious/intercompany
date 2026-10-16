//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° : Bug #88
// Change ID      : V001
// Date           : 23.09.2026
// Description    : CA - Chronological accrual installment sequence
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// V001 (CC) — Bug #88 (Delta v2).
// Derive the installment ordinal from the schedule chronology, not from the
// number of EX rows. Processing out of sequence must not renumber later
// installments. The self-join also supports manual schedules with month gaps.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Secuencia Cuotas Devengo'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCADfrCuotaSeq
  as select from zreing_ct2_crn_a as CurrentQuota
    inner join zreing_ct2_crn_a as PreviousQuota
      on  PreviousQuota.ct_uuid  = CurrentQuota.ct_uuid
      and PreviousQuota.mat_uuid = CurrentQuota.mat_uuid
      and PreviousQuota.op_type  = CurrentQuota.op_type
      and PreviousQuota.op_uuid  = CurrentQuota.op_uuid
      and ( PreviousQuota.cron_year < CurrentQuota.cron_year
         or ( PreviousQuota.cron_year  = CurrentQuota.cron_year
          and PreviousQuota.cron_month <= CurrentQuota.cron_month ) )
{
  key CurrentQuota.ct_uuid                         as CtUuid,
  key CurrentQuota.mat_uuid                        as MatUuid,
  key CurrentQuota.op_type                         as OpType,
  key CurrentQuota.op_uuid                         as OpUuid,
  key CurrentQuota.cron_year                       as CronYear,
  key CurrentQuota.cron_month                      as CronMonth,

      count( * )                                      as CuotaNum
}
group by CurrentQuota.ct_uuid,
         CurrentQuota.mat_uuid,
         CurrentQuota.op_type,
         CurrentQuota.op_uuid,
         CurrentQuota.cron_year,
         CurrentQuota.cron_month
