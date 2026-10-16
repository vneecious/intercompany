// V001 (CC) - GAP-001 (Delta v2): terminal/retry states and criticality.
// V001 (CC) - CA-109 (Delta v2): isolate CM loads by operation instance.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Narrow line-grain base for the actionable-group entity. It reproduces the same 4
// functional branches of ZI_ReingCALineAll (persisted / pending / pending-delta /
// deferral child) but drops every amount, currency, exchange rate, share-by-country
// and deferral-quota source, because the action dialogs do not consume them. A
// GROUP BY cannot be applied on the result of a UNION inside one view entity, hence
// this two-layer split (TC-02).
//
// SOURCE OF TRUTH: lcl_reing_ca_dml_buffer=>allowed_source_status / check_scope in
// ZBP_REINGCARUN. The status flag block below is a controlled read-only mirror of
// that matrix. If that matrix changes, this block AND ZCL_TC_REING_CA_ACTGROUP must
// change with it.
//
// Typing rule: every numeric literal is cast individually to abap.int4. Casting the
// whole CASE is not supported, and a bare literal makes the first branch infer a
// length-1 integer, which raises the UNION length mismatch warning (lesson from
// Change ID V005 of ZI_ReingCALineAll).
//
// Predicate rule: IN ( list ) is not accepted inside a CASE WHEN in this release
// (SDDL parser: Unexpected word "in"), so every such test is written as a chained
// OR of equality comparisons. The literal lists are unchanged.
//
// GroupKey rule: the key string is built HERE, at line grain over plain fields, and
// carried up with max() by ZI_ReingCAActionGroup. It cannot live in the consumption
// projection ("Field GROUPKEY contains a not supported expression") and nesting
// concat_with_space over max(...) aggregates would be worse. Every component is
// constant inside a group, so aggregating it does not change the value. The result is
// cast to a fixed abap.char(120) so all 4 UNION branches agree on the type.
//
// Change ID V001 (11.09.2026 | EXT_GONZALCA): two defects kept the Calculate
// dialog empty for EVERY contract in TS4 (reported against IC-0008 / 02.2026).
// (1) Branches B-1 and B-1b filtered by OPT.op_status = 'EN'. That column is
// EMPTY in 48 of 48 rows and 13 of 13 contracts, and its data element
// ZREING_STATUS2 has no domain with fixed values, so 'EN' is a literal with
// nothing backing it: the two pending branches could never return a row. The
// reference view ZI_ReingCALineAll had already neutralised the same predicate
// by COMMENTING IT OUT, with no change marker -- which is exactly what made
// the divergence invisible when this view cloned the branches. The filter is
// therefore DELETED here, not commented, so the next reader sees an intentional
// removal instead of dead code.
// (2) The anti-join to zreing_ca_line_a did not restrict the period, so a line
// calculated in ANY earlier run suppressed the pending row of the period being
// looked at, forever. Confirmed in TS4: line F/DAB of RUN-202512 (2025/12)
// hid the pending F/DAB of 2026/02, leaving 13 of 14 receiving companies.
// The join now goes through ZI_ReingCALinePeriod, which carries the fiscal
// period of the run, and compares it against the period of the branch itself.
// Change ID V002 (16.09.2026 | EXT_GONZALCA): bug tracker #74, misma causa
// raiz que el Change ID V010 de ZI_ReingCALineAll -- ME_PERIOD_OFFSET se
// ignoraba al leer la metrica. Aca el sintoma NO es la fila invisible sino
// MeEligFlag = 0, que baja a CanCalculate y deja el grupo como NO
// calculable: sin este cambio IC-0015 pasaria de invisible a visible pero
// no accionable, que para el usuario es el mismo bug con otra cara.
// Corregido en las ramas A, B-1 y B-1b. El periodo de metrica sale de la
// vista auxiliar ZI_ReingCACmMePeriod (la aritmetica del offset no entra en
// un ON, SDDL_PARSER_MSG 066).
// Rama A: la CM ya estaba unida por el periodo del run, asi que CMP se
// engancha a esa misma fila (CM.cm_h_id + LA.op_uuid) y no hace falta una
// segunda auxiliar sobre el run. Queda un efecto de borde honesto: si una
// linea persistida NO tiene CM del periodo (caso huerfano, IsOrphan = 'X'),
// CMP no resuelve y MeEligFlag pasa a 0 aunque exista metrica. Es
// consistente: sin CM el grupo no es calculable y CmEligFlag ya daba 0.
// Rama B-2 (deferidos) NO se toca: su periodo viene del cronograma
// (CRN.cron_year / cron_month) y el comentario D7/H1 de mas abajo declara
// que ese MeEligFlag replica A PROPOSITO el comportamiento del backend.
// Si el offset tambien debe aplicar a las cuotas deferidas es una decision
// FUNCIONAL pendiente (pregunta 3 del diagnostico de #74), no un descuido.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Narrow line base for act. groups'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCAActGrpLine

  // ==================================================================
  // Branch A - persisted lines (zreing_ca_line_a)
  // ==================================================================
  as select from zreing_ca_line_a as LA
    inner join      zreing_ca_run_a        as RN
      on LA.calc_run_id = RN.calc_run_id
    left outer join zreing_op_type_c       as OPC
      on OPC.op_type = LA.op_type
    left outer join zreing_cm_h_a          as CM
      on CM.cm_h_id = LA.cm_h_id
    left outer join ZI_ReingCAActGrpCmElig as CME
      on  CME.CtUuid      = LA.ct_uuid
      and CME.MatUuid     = LA.mat_uuid
      and CME.OpType      = LA.op_type
      and CME.OpInstanceNum = LA.op_instance_num
      and CME.PeriodYear  = RN.fiscal_year
      and CME.PeriodMonth = RN.fiscal_period
    // Begin Insert V002 (16.09.2026 | EXT_GONZALCA)
    left outer join ZI_ReingCACmMePeriod   as CMP
      on  CMP.CmHId  = CM.cm_h_id
      and CMP.OpUuid = LA.op_uuid
    // End Insert V002 (16.09.2026 | EXT_GONZALCA)
    left outer join ZI_ReingCAActGrpMeElig as MEE
      on  MEE.CtId        = LA.ct_id
      and MEE.Matnr       = LA.matnr
      // Begin Mod V002 (16.09.2026 | EXT_GONZALCA)
      // Lineas originales (periodo del run, sin offset -- bug #74):
      //    and MEE.PeriodYear  = RN.fiscal_year
      //    and MEE.PeriodMonth = RN.fiscal_period
      and MEE.PeriodYear  = CMP.MePeriodYear
      and MEE.PeriodMonth = CMP.MePeriodMonth
      // End Mod V002 (16.09.2026 | EXT_GONZALCA)
{
      // ---------- key -------------------------------------------------
  key LA.ct_uuid                                  as CtUuid,
  key LA.mat_uuid                                 as MatUuid,
  key LA.op_type                                  as OpType,
  key LA.op_uuid                                  as OpUuid,
  key LA.cm_h_id                                  as CmHId,
  key LA.bukrs_recv                               as BukrsRecv,
  key RN.fiscal_year                              as PeriodYear,
  key RN.fiscal_period                            as PeriodMonth,

      // ---------- context ---------------------------------------------
      cast( 'A' as zreing_ca_row_type )           as RowType,
      LA.calc_run_id                              as CalcRunId,

      // ---------- presentation ----------------------------------------
      LA.ct_id                                    as CtId,
      LA.lifnr                                    as Lifnr,
      LA.bp_name                                  as BpName,
      LA.bukrs_prest                              as BukrsPrest,
      LA.matnr                                    as Matnr,
      LA.op_instance_num                          as OpInstanceNum,
      LA.country                                  as Country,
      LA.is_delta                                 as IsDelta,
      LA.delta_seq                                as DeltaSeq,
      LA.cm_load_seq                              as CmLoadSeq,

      // GroupKey: same shape as ZC_ReingCALineAll (S5), so both entities agree on
      // the identifier the dialogs use. See the GroupKey rule in the header.
      cast( concat_with_space( LA.ct_id,
        concat_with_space( LA.bukrs_prest,
          concat_with_space( LA.matnr,
            concat_with_space( LA.op_type,
              concat_with_space( LA.op_instance_num,
                case when LA.delta_seq <> '00'
                     then concat( 'D', cast( LA.delta_seq as abap.char(2) ) )
                     else ''
                end
              , 1 ), 1 ), 1 ), 1 ), 1 ) as abap.char(120) ) as GroupKey,

      // ---------- status ----------------------------------------------
      LA.line_status                              as LineStatus,

      // StatusCriticality: verbatim copy of Change ID V005 of ZI_ReingCALineAll.
      // 0 neutral / 1 error / 2 warning / 3 success.
      case LA.line_status
        when 'PEND'     then cast( 0 as abap.int4 )
        when 'SIM_ERR'  then cast( 1 as abap.int4 )
        when 'CALC_ERR' then cast( 1 as abap.int4 )
        when 'POST_ERR' then cast( 1 as abap.int4 )
        when 'ANUL_ERR' then cast( 1 as abap.int4 )
        when 'ANULD'    then cast( 1 as abap.int4 )
        when 'CALC'     then cast( 2 as abap.int4 )
        when 'SIM_OK'   then cast( 3 as abap.int4 )
        when 'LIBD'     then cast( 3 as abap.int4 )
        when 'CONT'     then cast( 3 as abap.int4 )
        else                 cast( 0 as abap.int4 )
      end                                         as StatusCriticality,

      // IsOrphan: verbatim from the persisted branch of ZI_ReingCALineAll.
      cast( case when OPC.cm_loadable = 'X' and CM.ct_uuid is null then 'X'
                 else ''
            end as abap.char(1) )                 as IsOrphan,

      // ---------- aggregation flags (0/1, abap.int4) ------------------
      case when ( LA.line_status = 'CALC_PROC' or LA.line_status = 'SIM_PROC'
               or LA.line_status = 'POST_PROC' or LA.line_status = 'ANUL_PROC' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as IsProcFlag,
      case when ( LA.line_status = 'CALC_ERR' or LA.line_status = 'SIM_ERR'
               or LA.line_status = 'POST_ERR' or LA.line_status = 'ANUL_ERR' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as IsErrFlag,
      case when ( LA.line_status = 'CALC' or LA.line_status = 'SIM_OK' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as RelOkFlag,
      case when ( LA.line_status = 'CALC' or LA.line_status = 'SIM_ERR' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as SimOkFlag,
      case when ( LA.line_status = 'LIBD' or LA.line_status = 'POST_ERR' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as PostOkFlag,
      case when ( LA.line_status = 'CONT' or LA.line_status = 'POST_ERR'
               or LA.line_status = 'ANUL_ERR' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as StornoOkFlag,
      case when OPC.cm_loadable = 'X' and CM.ct_uuid is null
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as OrphanFlag,
      case when LA.line_status = 'PEND'
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as PendFlag,

      // ---------- op_type expansion mode (S10) ------------------------
      // Mirrors zcl_reing_ca_optype_factory=>dispatch_from_entry: the dispatch is
      // decided only by active / cm_loadable / parent_type, with zero CASE op_type.
      cast( case when OPC.active = 'X' and OPC.cm_loadable = 'X' then 'B1'
                 when OPC.active = 'X'
                  and ( OPC.parent_type = 'A' or OPC.parent_type = 'ANT' ) then 'B2'
                 else ''
            end as abap.char(2) )                 as ExpandMode,
      case when LA.line_status <> 'ANULD' and LA.line_status <> 'ANUL_ERR'
            and OPC.active = 'X'
            and ( OPC.cm_loadable = 'X'
               or OPC.parent_type = 'A' or OPC.parent_type = 'ANT' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as ExpandOkFlag,

      // ---------- check_insumos inputs (S11) --------------------------
      case when CME.CmLibdCount is not null and CME.CmLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as CmEligFlag,
      case when MEE.MeLibdCount is not null and MEE.MeLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as MeEligFlag
}
// V001 (CC) - GAP-001 (Delta v2): keep history for partial-reversal aggregation.

union all

// ==================================================================
// Branch B-1 - normal pending (CM loadable, no delta)
// ==================================================================
select from zreing_ct2_a as CT
  inner join      zreing_ct2_mat_a       as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join      zreing_ct2_opt_a       as OPT
    on  OPT.ct_uuid  = MAT.ct_uuid
    and OPT.mat_uuid = MAT.mat_uuid
  inner join      zreing_op_type_c       as OPC
    on OPC.op_type = OPT.op_type
  inner join      zreing_cm_h_a          as CM
    on  CM.ct_uuid  = CT.ct_uuid
    and CM.mat_uuid = MAT.mat_uuid
    and CM.op_type  = OPT.op_type
    and CM.op_instance_num = OPT.op_instance_num
  // Begin Insert V002 (16.09.2026 | EXT_GONZALCA)
  inner join      ZI_ReingCACmMePeriod   as CMP
    on  CMP.CmHId  = CM.cm_h_id
    and CMP.OpUuid = OPT.op_uuid
  // End Insert V002 (16.09.2026 | EXT_GONZALCA)
  inner join      zreing_me_h_a          as ME
    on  ME.ct_id        = CT.ct_id
    and ME.matnr        = MAT.matnr
    // Begin Mod V002 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and ME.period_year  = CM.period_year
    //    and ME.period_month = CM.period_month
    and ME.period_year  = CMP.MePeriodYear
    and ME.period_month = CMP.MePeriodMonth
    // End Mod V002 (16.09.2026 | EXT_GONZALCA)
  inner join      ZI_ReingCAMeShareBySoc as MS
    on  MS.CtId        = ME.ct_id
    and MS.Matnr       = ME.matnr
    and MS.PeriodYear  = ME.period_year
    and MS.PeriodMonth = ME.period_month
    // Begin Change ID V001 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCALinePeriod   as LN
    on  LN.CtUuid      = CT.ct_uuid
    and LN.MatUuid     = MAT.mat_uuid
    and LN.OpType      = OPT.op_type
    and LN.OpUuid = OPT.op_uuid
    and LN.BukrsRecv   = MS.BukrsRecv
    and LN.PeriodYear  = CM.period_year
    and LN.PeriodMonth = CM.period_month
    and LN.CmHId       = CM.cm_h_id
    // V001 (CC) - #105: ANULD only remains in the audit/list entity.
    and LN.LineStatus <> 'ANULD'
    // End Change ID V001 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCAActGrpCmElig as CME
    on  CME.CtUuid      = CT.ct_uuid
    and CME.MatUuid     = MAT.mat_uuid
    and CME.OpType      = OPT.op_type
    and CME.OpInstanceNum = OPT.op_instance_num
    and CME.PeriodYear  = CM.period_year
    and CME.PeriodMonth = CM.period_month
  left outer join ZI_ReingCAActGrpMeElig as MEE
    on  MEE.CtId        = CT.ct_id
    and MEE.Matnr       = MAT.matnr
    // Begin Mod V002 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and MEE.PeriodYear  = CM.period_year
    //    and MEE.PeriodMonth = CM.period_month
    and MEE.PeriodYear  = CMP.MePeriodYear
    and MEE.PeriodMonth = CMP.MePeriodMonth
    // End Mod V002 (16.09.2026 | EXT_GONZALCA)
{
  key CT.ct_uuid                                  as CtUuid,
  key MAT.mat_uuid                                as MatUuid,
  key cast( OPT.op_type as zreing_op_type )       as OpType,
  key OPT.op_uuid                                 as OpUuid,
  key CM.cm_h_id                                   as CmHId,
  key MS.BukrsRecv                                as BukrsRecv,
  key CM.period_year                              as PeriodYear,
  key CM.period_month                             as PeriodMonth,

      cast( 'B1' as zreing_ca_row_type )          as RowType,
      cast( '' as abap.char(20) )                 as CalcRunId,

      CT.ct_id                                    as CtId,
      CT.lifnr                                    as Lifnr,
      cast( '' as abap.char(80) )                 as BpName,
      CT.bukrs                                    as BukrsPrest,
      MAT.matnr                                   as Matnr,
      OPT.op_instance_num                         as OpInstanceNum,
      MS.Country                                  as Country,
      cast( '' as abap.char(1) )                  as IsDelta,
      cast( '00' as abap.numc(2) )                as DeltaSeq,
      CM.load_seq                                  as CmLoadSeq,

      // GroupKey - see the GroupKey rule in the header. No delta suffix here.
      cast( concat_with_space( CT.ct_id,
        concat_with_space( CT.bukrs,
          concat_with_space( MAT.matnr,
            concat_with_space( OPT.op_type,
              concat_with_space( OPT.op_instance_num, ''
              , 1 ), 1 ), 1 ), 1 ), 1 ) as abap.char(120) ) as GroupKey,

      cast( 'PEND' as zreing_ca_line_status )     as LineStatus,
      cast( 0 as abap.int4 )                      as StatusCriticality,
      cast( '' as abap.char(1) )                  as IsOrphan,

      cast( 0 as abap.int4 )                      as IsProcFlag,
      cast( 0 as abap.int4 )                      as IsErrFlag,
      cast( 0 as abap.int4 )                      as RelOkFlag,
      cast( 0 as abap.int4 )                      as SimOkFlag,
      cast( 0 as abap.int4 )                      as PostOkFlag,
      cast( 0 as abap.int4 )                      as StornoOkFlag,
      cast( 0 as abap.int4 )                      as OrphanFlag,
      cast( 1 as abap.int4 )                      as PendFlag,

      cast( case when OPC.active = 'X' and OPC.cm_loadable = 'X' then 'B1'
                 when OPC.active = 'X'
                  and ( OPC.parent_type = 'A' or OPC.parent_type = 'ANT' ) then 'B2'
                 else ''
            end as abap.char(2) )                 as ExpandMode,
      case when OPC.active = 'X'
            and ( OPC.cm_loadable = 'X'
               or OPC.parent_type = 'A' or OPC.parent_type = 'ANT' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as ExpandOkFlag,

      case when CME.CmLibdCount is not null and CME.CmLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as CmEligFlag,
      case when MEE.MeLibdCount is not null and MEE.MeLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as MeEligFlag
}
where CT.ct_status    = 'AC'
  and OPC.cm_loadable = 'X'
  and CM.cm_status    = 'LIBD'
  and CM.delta_flag  <> 'X'
  and ( ME.me_status = 'LIBD' or ME.me_status = 'LIBR' )
  // Begin Change ID V001 (11.09.2026 | EXT_GONZALCA)
  and LN.CtUuid      is null
  // End Change ID V001 (11.09.2026 | EXT_GONZALCA)

union all

// ==================================================================
// Branch B-1b - delta pending (CM delta_flag = 'X', op_type permite_delta)
// ==================================================================
select from zreing_ct2_a as CT
  inner join      zreing_ct2_mat_a          as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join      zreing_ct2_opt_a          as OPT
    on  OPT.ct_uuid  = MAT.ct_uuid
    and OPT.mat_uuid = MAT.mat_uuid
  inner join      zreing_op_type_c          as OPC
    on OPC.op_type = OPT.op_type
  inner join      zreing_cm_h_a             as CM
    on  CM.ct_uuid  = CT.ct_uuid
    and CM.mat_uuid = MAT.mat_uuid
    and CM.op_type  = OPT.op_type
    and CM.op_instance_num = OPT.op_instance_num
  // Begin Insert V002 (16.09.2026 | EXT_GONZALCA)
  inner join      ZI_ReingCACmMePeriod      as CMP
    on  CMP.CmHId  = CM.cm_h_id
    and CMP.OpUuid = OPT.op_uuid
  // End Insert V002 (16.09.2026 | EXT_GONZALCA)
  inner join      zreing_me_h_a             as ME
    on  ME.ct_id        = CT.ct_id
    and ME.matnr        = MAT.matnr
    // Begin Mod V002 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and ME.period_year  = CM.period_year
    //    and ME.period_month = CM.period_month
    and ME.period_year  = CMP.MePeriodYear
    and ME.period_month = CMP.MePeriodMonth
    // End Mod V002 (16.09.2026 | EXT_GONZALCA)
  inner join      ZI_ReingCAMeShareBySoc    as MS
    on  MS.CtId        = ME.ct_id
    and MS.Matnr       = ME.matnr
    and MS.PeriodYear  = ME.period_year
    and MS.PeriodMonth = ME.period_month
  left outer join ZI_ReingCADeltaSeqCount   as DC
    on  DC.CtUuid    = CT.ct_uuid
    and DC.MatUuid   = MAT.mat_uuid
    and DC.OpType    = OPT.op_type
    and DC.OpUuid    = OPT.op_uuid
    and DC.BukrsRecv = MS.BukrsRecv
    // Begin Change ID V001 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCALinePeriod      as LN
    on  LN.CtUuid      = CT.ct_uuid
    and LN.MatUuid     = MAT.mat_uuid
    and LN.OpType      = OPT.op_type
    and LN.OpUuid = OPT.op_uuid
    and LN.BukrsRecv   = MS.BukrsRecv
    and LN.PeriodYear  = CM.period_year
    and LN.PeriodMonth = CM.period_month
    and LN.IsDelta     = 'X'
    // V001 (CC) — fixes-050 (Delta v2): CM_H_ID is the stable identity of
    // the delta load. Matching the predicted next sequence fabricated D02
    // after D01 had already been persisted for the same CM load.
    and LN.CmHId       = CM.cm_h_id
    // V001 (CC) - #105: ANULD only remains in the audit/list entity.
    and LN.LineStatus <> 'ANULD'
    // End Change ID V001 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCAActGrpCmElig    as CME
    on  CME.CtUuid      = CT.ct_uuid
    and CME.MatUuid     = MAT.mat_uuid
    and CME.OpType      = OPT.op_type
    and CME.OpInstanceNum = OPT.op_instance_num
    and CME.PeriodYear  = CM.period_year
    and CME.PeriodMonth = CM.period_month
  left outer join ZI_ReingCAActGrpMeElig    as MEE
    on  MEE.CtId        = CT.ct_id
    and MEE.Matnr       = MAT.matnr
    // Begin Mod V002 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and MEE.PeriodYear  = CM.period_year
    //    and MEE.PeriodMonth = CM.period_month
    and MEE.PeriodYear  = CMP.MePeriodYear
    and MEE.PeriodMonth = CMP.MePeriodMonth
    // End Mod V002 (16.09.2026 | EXT_GONZALCA)
{
  key CT.ct_uuid                                  as CtUuid,
  key MAT.mat_uuid                                as MatUuid,
  key cast( OPT.op_type as zreing_op_type )       as OpType,
  key OPT.op_uuid                                 as OpUuid,
  key CM.cm_h_id                                   as CmHId,
  key MS.BukrsRecv                                as BukrsRecv,
  key CM.period_year                              as PeriodYear,
  key CM.period_month                             as PeriodMonth,

      cast( 'B1' as zreing_ca_row_type )          as RowType,
      cast( '' as abap.char(20) )                 as CalcRunId,

      CT.ct_id                                    as CtId,
      CT.lifnr                                    as Lifnr,
      cast( '' as abap.char(80) )                 as BpName,
      CT.bukrs                                    as BukrsPrest,
      MAT.matnr                                   as Matnr,
      OPT.op_instance_num                         as OpInstanceNum,
      MS.Country                                  as Country,
      cast( 'X' as abap.char(1) )                 as IsDelta,
      coalesce( DC.NextDeltaSeq,
                cast( '01' as abap.numc(2) ) )    as DeltaSeq,
      CM.load_seq                                  as CmLoadSeq,

      // GroupKey - see the GroupKey rule in the header. Delta suffix always present:
      // this branch only produces delta rows, whose DeltaSeq is never '00'.
      cast( concat_with_space( CT.ct_id,
        concat_with_space( CT.bukrs,
          concat_with_space( MAT.matnr,
            concat_with_space( OPT.op_type,
              concat_with_space( OPT.op_instance_num,
                concat( 'D', cast( coalesce( DC.NextDeltaSeq,
                                             cast( '01' as abap.numc(2) ) )
                                   as abap.char(2) ) )
              , 1 ), 1 ), 1 ), 1 ), 1 ) as abap.char(120) ) as GroupKey,

      cast( 'PEND' as zreing_ca_line_status )     as LineStatus,
      cast( 0 as abap.int4 )                      as StatusCriticality,
      cast( '' as abap.char(1) )                  as IsOrphan,

      cast( 0 as abap.int4 )                      as IsProcFlag,
      cast( 0 as abap.int4 )                      as IsErrFlag,
      cast( 0 as abap.int4 )                      as RelOkFlag,
      cast( 0 as abap.int4 )                      as SimOkFlag,
      cast( 0 as abap.int4 )                      as PostOkFlag,
      cast( 0 as abap.int4 )                      as StornoOkFlag,
      cast( 0 as abap.int4 )                      as OrphanFlag,
      cast( 1 as abap.int4 )                      as PendFlag,

      cast( case when OPC.active = 'X' and OPC.cm_loadable = 'X' then 'B1'
                 when OPC.active = 'X'
                  and ( OPC.parent_type = 'A' or OPC.parent_type = 'ANT' ) then 'B2'
                 else ''
            end as abap.char(2) )                 as ExpandMode,
      case when OPC.active = 'X'
            and ( OPC.cm_loadable = 'X'
               or OPC.parent_type = 'A' or OPC.parent_type = 'ANT' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as ExpandOkFlag,

      case when CME.CmLibdCount is not null and CME.CmLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as CmEligFlag,
      case when MEE.MeLibdCount is not null and MEE.MeLibdCount > 0
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as MeEligFlag
}
where CT.ct_status      = 'AC'
  and OPC.cm_loadable   = 'X'
  and OPC.permite_delta = 'X'
  and CM.cm_status      = 'LIBD'
  and CM.delta_flag     = 'X'
  and ( ME.me_status = 'LIBD' or ME.me_status = 'LIBR' )
  // Begin Change ID V001 (11.09.2026 | EXT_GONZALCA)
  and LN.CtUuid        is null
  // End Change ID V001 (11.09.2026 | EXT_GONZALCA)

union all

// ==================================================================
// Branch B-2 - deferral child (parent line in CONT, schedule row planned)
// ==================================================================
select from zreing_ct2_a as CT
  inner join      zreing_ct2_mat_a       as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join      zreing_ct2_opt_a       as OPT_CHILD
    on  OPT_CHILD.ct_uuid  = MAT.ct_uuid
    and OPT_CHILD.mat_uuid = MAT.mat_uuid
  inner join      zreing_op_type_c       as OPC
    on  OPC.op_type = OPT_CHILD.op_type
    and OPC.active  = 'X'
  inner join      zreing_ct2_opt_a       as OPT_PARENT
    on  OPT_PARENT.ct_uuid       = CT.ct_uuid
    and OPT_PARENT.mat_uuid      = MAT.mat_uuid
    and OPT_PARENT.op_type       = OPC.parent_type
    and ( OPT_PARENT.op_uuid     = OPT_CHILD.parent_instance_id
       or OPT_PARENT.op_instance_num = OPT_CHILD.op_instance_num )
  inner join      zreing_ct2_crn_a       as CRN
    on  CRN.ct_uuid  = OPT_CHILD.ct_uuid
    and CRN.mat_uuid = OPT_CHILD.mat_uuid
    and CRN.op_type  = OPT_CHILD.op_type
    and CRN.op_uuid  = OPT_CHILD.op_uuid
  inner join      zreing_ca_line_a       as PARENT_LINE
    on  PARENT_LINE.ct_uuid     = CT.ct_uuid
    and PARENT_LINE.mat_uuid    = MAT.mat_uuid
    and PARENT_LINE.op_uuid     = OPT_PARENT.op_uuid
    and PARENT_LINE.line_status = 'CONT'
  left outer join ZI_ReingCALinePeriod   as LN
    on  LN.CtUuid      = OPT_CHILD.ct_uuid
    and LN.MatUuid     = OPT_CHILD.mat_uuid
    and LN.OpUuid      = OPT_CHILD.op_uuid
    and LN.BukrsRecv   = PARENT_LINE.bukrs_recv
    and LN.CmHId       = PARENT_LINE.cm_h_id
    // V001 (CC) - #105: ANULD only remains in the audit/list entity.
    and LN.LineStatus <> 'ANULD'
    and LN.PeriodYear  = CRN.cron_year
    and LN.PeriodMonth = CRN.cron_month
{
  key CT.ct_uuid                                  as CtUuid,
  key MAT.mat_uuid                                as MatUuid,
  key cast( OPT_CHILD.op_type as zreing_op_type ) as OpType,
  key OPT_CHILD.op_uuid                           as OpUuid,
  key PARENT_LINE.cm_h_id                          as CmHId,
  key PARENT_LINE.bukrs_recv                      as BukrsRecv,
  key CRN.cron_year                               as PeriodYear,
  key CRN.cron_month                              as PeriodMonth,

      cast( 'B2' as zreing_ca_row_type )          as RowType,
      cast( '' as abap.char(20) )                 as CalcRunId,

      CT.ct_id                                    as CtId,
      CT.lifnr                                    as Lifnr,
      cast( '' as abap.char(80) )                 as BpName,
      CT.bukrs                                    as BukrsPrest,
      MAT.matnr                                   as Matnr,
      OPT_CHILD.op_instance_num                   as OpInstanceNum,
      PARENT_LINE.country                         as Country,
      cast( '' as abap.char(1) )                  as IsDelta,
      cast( '00' as abap.numc(2) )                as DeltaSeq,
      PARENT_LINE.cm_load_seq                      as CmLoadSeq,

      // GroupKey - see the GroupKey rule in the header. No delta suffix here.
      cast( concat_with_space( CT.ct_id,
        concat_with_space( CT.bukrs,
          concat_with_space( MAT.matnr,
            concat_with_space( OPT_CHILD.op_type,
              concat_with_space( OPT_CHILD.op_instance_num, ''
              , 1 ), 1 ), 1 ), 1 ), 1 ) as abap.char(120) ) as GroupKey,

      cast( 'PEND' as zreing_ca_line_status )     as LineStatus,
      cast( 0 as abap.int4 )                      as StatusCriticality,
      cast( '' as abap.char(1) )                  as IsOrphan,

      cast( 0 as abap.int4 )                      as IsProcFlag,
      cast( 0 as abap.int4 )                      as IsErrFlag,
      cast( 0 as abap.int4 )                      as RelOkFlag,
      cast( 0 as abap.int4 )                      as SimOkFlag,
      cast( 0 as abap.int4 )                      as PostOkFlag,
      cast( 0 as abap.int4 )                      as StornoOkFlag,
      cast( 0 as abap.int4 )                      as OrphanFlag,
      cast( 1 as abap.int4 )                      as PendFlag,

      cast( case when OPC.active = 'X' and OPC.cm_loadable = 'X' then 'B1'
                 when OPC.active = 'X'
                  and ( OPC.parent_type = 'A' or OPC.parent_type = 'ANT' ) then 'B2'
                 else ''
            end as abap.char(2) )                 as ExpandMode,
      case when OPC.active = 'X'
            and ( OPC.cm_loadable = 'X'
               or OPC.parent_type = 'A' or OPC.parent_type = 'ANT' )
           then cast( 1 as abap.int4 ) else cast( 0 as abap.int4 ) end as ExpandOkFlag,

      // B2 is sourced by the CONT parent plus the planned schedule row.
      cast( 1 as abap.int4 )                       as CmEligFlag,
      cast( 1 as abap.int4 )                       as MeEligFlag
}
where ( CRN.cron_status = 'PL' or CRN.cron_status = '' )
  and PARENT_LINE.line_status = 'CONT'
  and LN.CtUuid              is null

