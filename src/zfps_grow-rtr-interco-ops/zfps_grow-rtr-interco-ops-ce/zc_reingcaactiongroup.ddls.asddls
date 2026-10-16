//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Consumption view exposed as CAActionGroup in ZREING_CA_SRV. Read only: no
// behavior definition, no behavior projection. The execution contract of the RAP
// actions is untouched - GROUPS is still CtUuid + MatUuid + OpType + OpUuid (TC-05).
//
// WHY "as select from" AND NOT "as projection on" (ERR-004):
// a projection view that uses "redirected to" is classified by SAP as a TRANSACTIONAL
// projection view and activation fails with "Transactional Projection View must be
// part of a business object". This entity is read-only and has no BDEF by design.
// Removing the @ObjectModel.usageType annotations was NOT enough - the trigger is the
// redirection itself. A regular view entity reaches the same result: the association
// is declared directly against the consumption counterpart, so OData navigation
// (_Receivers) is identical for the client.
//
// GroupKey is computed in ZI_ReingCAActGrpLine (line grain, plain fields) and
// carried up as max( GroupKey ). Every component of the key is constant inside the
// group, so the aggregated value is identical.
//
// DistinctStatusCount is deliberately not projected: it is a calculation intermediate,
// not presentation data.
//
// NOTE: @Semantics.booleanIndicator is NOT released in this system, so every flag
// (IsDelta, IsProcessing, IsOrphan and the Can* block) is exposed as its underlying
// abap.char(1) value: 'X' = true, '' = false. Consumers filter them as text, e.g.
// $filter=CanSimulate eq 'X', NOT eq true.
//
// ACTIVATION NOTE: mutual association cycle with ZC_ReingCAActGrpRecv - activate both
// in a single mass activation. After activating the SRVD, the service binding
// ZREING_CA_UI_V4 must be republished or the new entity sets do not show up in
// $metadata.
//----------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Grupo Accionable (Consumo OData)'

define view entity ZC_ReingCAActionGroup
  as select from ZI_ReingCAActionGroup as AG

  association [1..*] to ZC_ReingCAActGrpRecv as _Receivers
    on  $projection.PeriodYear  = _Receivers.PeriodYear
    and $projection.PeriodMonth = _Receivers.PeriodMonth
    and $projection.CalcRunId   = _Receivers.CalcRunId
    and $projection.CtUuid      = _Receivers.CtUuid
    and $projection.MatUuid     = _Receivers.MatUuid
    and $projection.OpType      = _Receivers.OpType
    and $projection.OpUuid      = _Receivers.OpUuid
    and $projection.CmHId       = _Receivers.CmHId
{
  key AG.PeriodYear        as PeriodYear,
  key AG.PeriodMonth       as PeriodMonth,
  key AG.CalcRunId         as CalcRunId,
  key AG.CtUuid            as CtUuid,
  key AG.MatUuid           as MatUuid,
  key AG.OpType            as OpType,
  key AG.OpUuid            as OpUuid,
  @UI.hidden: true
  key AG.CmHId             as CmHId,

      AG.RowType           as RowType,
      AG.CtId              as CtId,
      AG.Lifnr             as Lifnr,
      AG.BpName            as BpName,
      AG.BukrsPrest        as BukrsPrest,
      AG.Matnr             as Matnr,
      AG.OpInstanceNum     as OpInstanceNum,

      AG.IsDelta           as IsDelta,
      AG.DeltaSeq          as DeltaSeq,
      @UI.hidden: true
      AG.CmLoadSeq         as CmLoadSeq,
      AG.GroupKey          as GroupKey,

      AG.LineCount         as LineCount,
      AG.ReceiverCount     as ReceiverCount,
      AG.OrphanLineCount   as OrphanLineCount,
      AG.MinBukrsRecv      as MinBukrsRecv,
      AG.MaxBukrsRecv      as MaxBukrsRecv,

      AG.GroupStatusKey    as GroupStatusKey,
      AG.StatusCriticality as StatusCriticality,

      AG.IsProcessing      as IsProcessing,
      AG.IsOrphan          as IsOrphan,

      AG.CanCalculate      as CanCalculate,
      AG.CanRelease        as CanRelease,
      AG.CanSimulate       as CanSimulate,
      AG.CanPost           as CanPost,
      AG.CanStorno         as CanStorno,
      AG.CanDelete         as CanDelete,

      /* Associations */
      _Receivers
}
