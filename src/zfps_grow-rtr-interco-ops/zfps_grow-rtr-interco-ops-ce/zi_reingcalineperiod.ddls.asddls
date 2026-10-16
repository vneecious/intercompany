//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 11.09.2026
// Description    : CA - Linea calculada con el periodo de su run
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Purpose: expose each persisted calculation line together with the fiscal
// period of the run that produced it, so the pending branches of
// ZI_ReingCALineAll and ZI_ReingCAActGrpLine can run their anti-join
// PER PERIOD.
//
// Why a separate view: zreing_ca_line_a does NOT carry period_year /
// period_month. The period only exists in zreing_ca_run_a, reachable through
// calc_run_id. A LEFT OUTER JOIN cannot have a nested join as its right
// operand in CDS, so the line+run pair has to be resolved in its own view
// first. Same reason ZI_ReingCADfrBaseAmt exists (DD-16).
//
// Grain: UNCHANGED with respect to zreing_ca_line_a -- one row per line,
// keyed by its real primary key (calc_run_id + line_num). No aggregation
// and no grain change, so substituting this view for the table in an
// existing anti-join adds the period predicate and nothing else.
//
// The INNER JOIN to zreing_ca_run_a is intentional: a line whose run header
// is missing is a referential-integrity violation (calc_run_id is part of
// the line primary key) and has no period to compare against, so it cannot
// take part in a per-period existence test.
//
// No amount / currency field is selected on purpose: nothing here needs
// them, and keeping them out avoids propagating @Semantics.amount
// annotations into the consuming UNION branches.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Linea con Periodo del Run'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCALinePeriod
  as select from zreing_ca_line_a as LA
    inner join zreing_ca_run_a as RN
      on RN.calc_run_id = LA.calc_run_id
{
  key LA.calc_run_id   as CalcRunId,
  key LA.line_num      as LineNum,

      RN.fiscal_year   as PeriodYear,
      RN.fiscal_period as PeriodMonth,

      LA.ct_uuid       as CtUuid,
      LA.mat_uuid      as MatUuid,
      LA.op_type       as OpType,
      LA.op_uuid       as OpUuid,
      LA.cm_h_id       as CmHId,
      LA.cm_load_seq   as CmLoadSeq,
      LA.bukrs_recv    as BukrsRecv,
      LA.is_delta      as IsDelta,
      LA.delta_seq     as DeltaSeq,
      // V001 (CC) - #105: callers exclude terminal reversals from anti-joins.
      LA.line_status   as LineStatus
}
