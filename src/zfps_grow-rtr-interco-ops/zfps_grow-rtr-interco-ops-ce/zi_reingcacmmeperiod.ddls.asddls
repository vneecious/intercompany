// V001 (CC) - CA-109 (Delta v2): isolate CM loads by operation instance.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° : Bug tracker #74
// Date           : 16.09.2026
// Description    : CA - Carga de montos con el periodo de metrica resuelto
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Purpose: expose each monthly-amount load (CM) together with the METRIC
// period that feeds it, already resolved through ME_PERIOD_OFFSET, so the
// pending branches of ZI_ReingCALineAll and ZI_ReingCAActGrpLine can join
// ZREING_ME_H_A by the period the backend really reads (BR-CA-40).
//
// Why this view exists: the offset arithmetic CANNOT live inside an ON
// condition (SDDL_PARSER_MSG 066 -- the very restriction already recorded
// in Change ID V004 of ZI_ReingCALineAll), so the resolved period has to be
// precomputed in its own view and joined by a plain field. Same reason
// ZI_ReingCALinePeriod (V008) and ZI_ReingCADfrBaseAmt (DD-16) exist.
//
// Grain: one row per CM load x op_type INSTANCE. It is keyed by cm_h_id --
// the real primary key of zreing_cm_h_a -- plus op_uuid, so a consumer that
// joins on those two fields CANNOT fan out. That matters: the consuming
// branches already carry a known [0..N] exposure on zreing_cm_h_a (Change
// ID V006/V007 of ZI_ReingCALineAll, still open), and this view must not
// make it worse. op_uuid is part of the key because one op_type may have
// several instances, each with its own offset.
//
// Offset mapping: a CASE over the two FIXED VALUES of domain
// ZREING_ME_PERIOD_OFFSET ('00' = M, '01' = M-1), NOT a numeric cast of the
// field. Two reasons: the data element is CHAR(2) and not NUMC, and a
// CHAR-to-numeric CAST is not part of the CDS cast matrix.
// >>> IF THE DOMAIN EVER GAINS A VALUE ('02' = M-2, ...), THIS CASE MUST BE
// >>> EXTENDED. The ELSE branch resolves to offset 0, i.e. it would read the
// >>> metric of the month itself -- exactly the defect this view exists to
// >>> fix, and it would fail silently again. MePeriodOffset is exposed so a
// >>> unit test or an ATC check can assert the mapping against the domain.
//
// The arithmetic runs over a month index (year * 12 + month - 1) so the
// January year rollover needs no second CASE. It mirrors
// ZCL_REING_CA_SOURCES=>calc_me_period, whose WHILE loop yields the same
// result for every legal offset. The int -> char -> ltrim -> lpad -> numc
// chain is the pattern already ACTIVE in this project (DeferCuotaNum in
// branch B2 of ZI_ReingCALineAll), and the cast targets are the data
// elements of ZREING_ME_H_A so the consuming ON conditions compare
// identical types.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - CM con Periodo de Metrica'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCACmMePeriod
  as select from zreing_cm_h_a as CM
    inner join zreing_ct2_opt_a as OPT
      on  OPT.ct_uuid  = CM.ct_uuid
      and OPT.mat_uuid = CM.mat_uuid
      and OPT.op_type  = CM.op_type
      and OPT.op_instance_num = CM.op_instance_num
{
  key CM.cm_h_id           as CmHId,
  key OPT.op_uuid          as OpUuid,

      CM.ct_uuid           as CtUuid,
      CM.mat_uuid          as MatUuid,
      CM.op_type           as OpType,
      CM.period_year       as PeriodYear,
      CM.period_month      as PeriodMonth,
      OPT.me_period_offset as MePeriodOffset,

      cast( lpad( ltrim( cast( div( cast( CM.period_year  as abap.int4 ) * 12
                                  + cast( CM.period_month as abap.int4 ) - 1
                                  - case OPT.me_period_offset
                                      when '00' then cast( 0 as abap.int4 )
                                      when '01' then cast( 1 as abap.int4 )
                                      else           cast( 0 as abap.int4 )
                                    end,
                                    12 ) as abap.char(20) ), ' ' ), 4, '0' )
            as zreing_period_year )  as MePeriodYear,

      cast( lpad( ltrim( cast( mod( cast( CM.period_year  as abap.int4 ) * 12
                                  + cast( CM.period_month as abap.int4 ) - 1
                                  - case OPT.me_period_offset
                                      when '00' then cast( 0 as abap.int4 )
                                      when '01' then cast( 1 as abap.int4 )
                                      else           cast( 0 as abap.int4 )
                                    end,
                                    12 ) + 1 as abap.char(20) ), ' ' ), 2, '0' )
            as zreing_period_month ) as MePeriodMonth
}

