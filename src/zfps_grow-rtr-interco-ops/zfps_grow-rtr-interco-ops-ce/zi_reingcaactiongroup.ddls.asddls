// V001 (CC) - GAP-001 (Delta v2): audit groups and partial-reversal retry.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Actionable group: exactly one row per
// (PeriodYear, PeriodMonth, CalcRunId, CtUuid, MatUuid, OpType, OpUuid) - BR-AG-01.
// Aggregates the narrow line base and derives aggregated status, criticality and the
// per-action eligibility flags the action dialogs need in a single OData read.
//
// SOURCE OF TRUTH: lcl_reing_ca_dml_buffer=>allowed_source_status / check_scope in
// ZBP_REINGCARUN, plus the per-handler scope validation. The Can* block below is a
// controlled read-only MIRROR of that matrix, never the authorization. Every action
// still revalidates its scope at execution time (BR-AG-14) because the state can
// change between the read and the execution.
// If that matrix changes, this block AND ZCL_TC_REING_CA_ACTGROUP must change with it.
//
// Quantifier asymmetry (D5) - do NOT homogenize:
//   CanRelease / CanDelete  -> FOR ALL lines of the group  (min of the flag)
//   CanSimulate / CanPost / CanStorno -> EXISTS one line   (max of the flag)
//
// Duplicate immunity (D4): no COUNT(*) and no SUM anywhere. The joins to zreing_cm_h_a
// and zreing_me_h_a are by business key over UUID-keyed tables and may multiply rows
// (finding H5); COUNT(DISTINCT BukrsRecv), MIN and MAX are idempotent under duplicates.
//
// GroupKey arrives precomputed from ZI_ReingCAActGrpLine and is carried up with max():
// all of its components are constant inside the group, so the aggregate is a no-op on
// the value. It cannot live in the consumption projection - a projection view rejects
// the concat expression.
//
// The @ObjectModel.usageType annotations are deliberately absent: with
// dataClass #TRANSACTIONAL the consumption projection ZC_ReingCAActionGroup is treated
// as a transactional projection view and SAP demands a business object
// ("Transactional Projection View must be part of a business object"), which this
// read-only entity does not have and must not have.
//
// ACTIVATION NOTE: mutual association cycle with ZI_ReingCAActGrpRecv - activate both
// objects in a single mass activation.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Actionable group (agg status/elig)'

define view entity ZI_ReingCAActionGroup
  as select from ZI_ReingCAActGrpLine as GL

  association [1..*] to ZI_ReingCAActGrpRecv as _Receivers
    on  $projection.PeriodYear  = _Receivers.PeriodYear
    and $projection.PeriodMonth = _Receivers.PeriodMonth
    and $projection.CalcRunId   = _Receivers.CalcRunId
    and $projection.CtUuid      = _Receivers.CtUuid
    and $projection.MatUuid     = _Receivers.MatUuid
    and $projection.OpType      = _Receivers.OpType
    and $projection.OpUuid      = _Receivers.OpUuid
    and $projection.CmHId       = _Receivers.CmHId
{
      // ---------- key (BR-AG-01) --------------------------------------
  key GL.PeriodYear         as PeriodYear,
  key GL.PeriodMonth        as PeriodMonth,
  key GL.CalcRunId          as CalcRunId,
  key GL.CtUuid             as CtUuid,
  key GL.MatUuid            as MatUuid,
  key GL.OpType             as OpType,
  key GL.OpUuid             as OpUuid,
  key GL.CmHId              as CmHId,

      // ---------- presentation: constant inside the group -------------
      max( GL.RowType )       as RowType,
      max( GL.CtId )          as CtId,
      max( GL.Lifnr )         as Lifnr,
      max( GL.BpName )        as BpName,
      max( GL.BukrsPrest )    as BukrsPrest,
      max( GL.Matnr )         as Matnr,
      max( GL.OpInstanceNum ) as OpInstanceNum,
      max( GL.IsDelta )       as IsDelta,
      max( GL.DeltaSeq )      as DeltaSeq,
      max( GL.CmLoadSeq )      as CmLoadSeq,
      max( GL.GroupKey )      as GroupKey,

      // ---------- counts (D4: immune to duplicated rows) --------------
      // The line grain of the group IS the receiver grain, so LineCount and
      // ReceiverCount are the same distinct count by construction.
      count( distinct GL.BukrsRecv )                                      as LineCount,
      count( distinct GL.BukrsRecv )                                      as ReceiverCount,
      count( distinct case when GL.OrphanFlag = 1 then GL.BukrsRecv end ) as OrphanLineCount,
      count( distinct GL.LineStatus )                                     as DistinctStatusCount,
      min( GL.BukrsRecv )                                                 as MinBukrsRecv,
      max( GL.BukrsRecv )                                                 as MaxBukrsRecv,

      // ---------- IsProcessing (BR-AG-03) -----------------------------
      // Evaluated over ALL lines of the group, independently of any OData filter
      // the consumer applies on the receiver entity.
      cast( case when max( GL.IsProcFlag ) = 1 then 'X' else '' end as abap.char(1) ) as IsProcessing,

      // ---------- IsOrphan of the group (BR-AG-12) --------------------
      // FOR ALL lines orphan - same quantifier the Delete handler uses.
      cast( case when min( GL.OrphanFlag ) = 1 then 'X' else '' end as abap.char(1) ) as IsOrphan,

      // ---------- GroupStatusKey (BR-AG-04) ---------------------------
      // Precedence: processing > all-error > mixed > uniform status.
      cast( case when max( GL.IsProcFlag ) = 1                then 'procesando'
                 when min( GL.LineStatus ) = 'ANUL_ERR'
                  and max( GL.LineStatus ) = 'ANUL_ERR' then 'ANUL_ERR'
                 when min( GL.LineStatus ) = 'ANULD'
                  and max( GL.LineStatus ) = 'ANUL_ERR' then 'ANUL_PARTIAL'
                 when min( GL.IsErrFlag ) = 1                 then 'error'
                 when count( distinct GL.LineStatus ) > 1     then 'parcial'
                 else max( GL.LineStatus )
            end as abap.char(20) )                                        as GroupStatusKey,

      // ---------- StatusCriticality of the group (BR-AG-05) -----------
      case when max( GL.IsProcFlag ) = 1                then cast( 0 as abap.int4 )
           when max( case when GL.LineStatus = 'ANUL_ERR' then 1 else 0 end ) = 1
                then cast( 1 as abap.int4 )
           when min( GL.IsErrFlag ) = 1                 then cast( 1 as abap.int4 )
           when count( distinct GL.LineStatus ) > 1     then cast( 2 as abap.int4 )
           else max( GL.StatusCriticality )
      end                                                                 as StatusCriticality,

      // ---------- eligibility per action (S9, BR-AG-06..11) -----------
      // CanCalculate (BR-AG-06): not processing AND valid expand mode AND
      // check_insumos satisfied AND (Path A/CM, or Path B/C with >=1 PEND line).
      // V001 (CC) - #115 (Delta v2): protect released and posted groups.
      // FOR ALL: one protected receiver blocks the entire CM load group.
      cast( case when max( GL.IsProcFlag ) = 0
                  and min( case when GL.LineStatus = 'LIBD'
                                  or GL.LineStatus = 'CONT'
                                  or GL.LineStatus = 'POST_ERR'
                                then 0 else 1 end ) = 1
                  and min( GL.ExpandOkFlag ) = 1
                  and min( GL.CmEligFlag ) = 1
                  and min( GL.MeEligFlag ) = 1
                  and ( max( GL.ExpandMode ) = 'B1'
                     or max( GL.PendFlag ) = 1 )
                 then 'X' else '' end as abap.char(1) )                   as CanCalculate,

      // CanRelease (BR-AG-07, FOR ALL): every line in (CALC, SIM_OK) and no orphan
      // line. The handler rejects a scope containing orphans with "Use Delete".
      cast( case when max( GL.IsProcFlag ) = 0
                  and min( GL.RelOkFlag ) = 1
                  and max( GL.OrphanFlag ) = 0
                 then 'X' else '' end as abap.char(1) )                   as CanRelease,

      // CanSimulate (BR-AG-08, EXISTS): >=1 line in (CALC, SIM_ERR).
      cast( case when max( GL.IsProcFlag ) = 0
                  and max( GL.SimOkFlag ) = 1
                  and max( case when GL.LineStatus = 'ANUL_ERR' then 1 else 0 end ) = 0
                 then 'X' else '' end as abap.char(1) )                   as CanSimulate,

      // CanPost (BR-AG-09, EXISTS): >=1 line in (LIBD, POST_ERR).
      cast( case when max( GL.IsProcFlag ) = 0
                  and max( GL.PostOkFlag ) = 1
                  and max( case when GL.LineStatus = 'ANUL_ERR' then 1 else 0 end ) = 0
                 then 'X' else '' end as abap.char(1) )                   as CanPost,

      // CanStorno (BR-AG-10, EXISTS): >=1 line in (CONT).
      cast( case when max( GL.IsProcFlag ) = 0
                  and max( GL.StornoOkFlag ) = 1
                 then 'X' else '' end as abap.char(1) )                   as CanStorno,

      // CanDelete (BR-AG-11, FOR ALL): every line orphan. A mixed scope is a hard
      // error in the handler, so it must not be offered. IsProcessing is kept even
      // though the Delete handler does not call check_scope: stricter than the
      // backend, never enabling something the action would reject.
      cast( case when max( GL.IsProcFlag ) = 0
                  and min( GL.OrphanFlag ) = 1
                  and max( case when GL.LineStatus = 'ANULD' or GL.LineStatus = 'ANUL_ERR'
                                then 1 else 0 end ) = 0
                 then 'X' else '' end as abap.char(1) )                   as CanDelete,

      /* Associations */
      _Receivers
}
group by GL.PeriodYear,
         GL.PeriodMonth,
         GL.CalcRunId,
         GL.CtUuid,
         GL.MatUuid,
         GL.OpType,
         GL.OpUuid,
         GL.CmHId
