// V001 (CC) - CA-109 (Delta v2): isolate CM loads by operation instance.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Purpose: answer "is there a CM_H_A for this group and period?" with EXACTLY
// ONE row per business key. ZREING_CM_H_A is keyed by cm_h_id (UUID) and admits
// several load_seq for the same ct_uuid/mat_uuid/op_type/period, so a direct
// join by business key would multiply rows (finding H5). Pre-aggregating here
// keeps every LEFT OUTER JOIN against it fan-out free.
//----------------------------------------------------------------------
// Change ID V002 (09.09.2026 | EXT_GONZALCA): a SECOND consumer needed this
// view, so it is generalised instead of cloned. ZI_ReingCALineAll branch A
// joined ZREING_CM_H_A directly and multiplied its persisted lines whenever a
// business key had more than one load (base SUPS + delta LIBD), which made
// SAPUI5 1.151 reject the whole CALineAll page with "Duplicate key predicate".
//   - the cm_status = 'LIBD' filter moved OUT of the WHERE and INTO the
//     CmLibdCount expression, so that column keeps EXACTLY its former meaning;
//   - the new CmCount counts ANY load -- the existence test IsOrphan needs.
// ZI_ReingCAActGrpLine is unaffected: its 4 branches read CmLibdCount only BY
// VALUE ("is not null and > 0"), never as a row-existence test. Where the join
// used to yield NULL it now yields a row with CmLibdCount = 0, so CmEligFlag
// still evaluates to 0.
// The two counters answer DIFFERENT questions ON PURPOSE: any CM load counts
// for CALineAll.IsOrphan, only a released one counts for ActionGroup
// CmEligFlag. That divergence is a pending business decision, not a defect.
//----------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Existencia y elegibilidad CM'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCAActGrpCmElig
  as select from zreing_cm_h_a as CM
{
  key CM.ct_uuid      as CtUuid,
  key CM.mat_uuid     as MatUuid,
  key CM.op_type      as OpType,
  key CM.op_instance_num as OpInstanceNum,
  key CM.period_year  as PeriodYear,
  key CM.period_month as PeriodMonth,

      count( * )      as CmCount,
      sum( case when CM.cm_status = 'LIBD'
                then cast( 1 as abap.int4 )
                else cast( 0 as abap.int4 ) end ) as CmLibdCount
}
group by CM.ct_uuid,
         CM.mat_uuid,
         CM.op_type,
         CM.op_instance_num,
         CM.period_year,
         CM.period_month

