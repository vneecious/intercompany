// V001 (CC) - Bugs 113/114 (Delta v2): exact-load orphan consistency.
// The historical V006 business-key aggregate is superseded in branch A:
// only the original CM_H_ID can validate a persisted calculation reference.
// V001 (CC) - GAP-001 (Delta v2): terminal/retry states and criticality.
// V001 (CC) - CA-109 (Delta v2): isolate CM loads by operation instance.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 05.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// Change ID V003 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-04 -- reversion
// puntual. ZI_ReingCAMeShareBySoc revirtio a su definicion original
// (agregada por sociedad, campo SharePctSoc) -- ver su propio header para
// el detalle. Este archivo solo revierte las 2 referencias a MS.SharePct
// (Lado B-1 y B-1b) de vuelta a MS.SharePctSoc; el resto de los cambios
// de CA-04 (IsDelta/DeltaSeq/DeltaBaseAmt, Lado B-1b con
// ZI_ReingCADeltaSeqCount) no se tocan.
// Change ID V004 (04.08.2026 | EXT_GONZALCA): "coalesce(...)+1" no esta
// soportado dentro de una condicion ON (SDDL_PARSER_MSG 066). Se usa
// DC.NextDeltaSeq (ya calculado en ZI_ReingCADeltaSeqCount) en el ON y en
// el SELECT list de Lado B-1b.
// Change ID V005 (07.09.2026 | EXT_GONZALCA): frontend needs a visual
// criticality code derived from LineStatus in order to highlight rows.
// New calculated field StatusCriticality, added to all 4 UNION ALL
// branches. The mapping is copied verbatim from ZI_ReingCALine so that the
// same status renders identically across the CalcLine and CALineAll
// entities of service ZREING_CA_SRV. Every literal is cast to
// abap.int4: bare literals make branch A infer a length-1 integer, which
// raises a "Longitud de 1 incidente debe ser mayor" UNION warning against
// the int4 of the pending branches, and int4 also keeps the OData type
// aligned with CalcLine.StatusCriticality.
// Change ID V006 (09.09.2026 | EXT_GONZALCA): fix "Duplicate key predicate"
// on the CALineAll read -- SAPUI5 1.151 rejects the whole page and the
// table stays empty. Branch A joined ZREING_CM_H_A directly by business
// key, but that table is keyed by cm_h_id (UUID) and admits several
// load_seq for the same ct_uuid/mat_uuid/op_type/period. With a base load
// in SUPS plus a delta in LIBD the join returned 2 rows for ONE persisted
// line, both carrying the identical declared key -- e.g.
// RUN-202602 / 0000042 for 02/2026. The alias is now the pre-aggregated
// ZI_ReingCAActGrpCmElig, which yields exactly one row per business key,
// so the branch is fan-out free. CM contributed NO field to the SELECT
// list here: its only consumer was IsOrphan, adapted below.
// Historical V006 rule below applies to the pre-fix implementation only.
// Persisted branch A now uses exact CM_H_ID per the approved orphan fix.
// IsOrphan semantics are PRESERVED on purpose: it tests CmCount (ANY load,
// including historical or SUPS), not CmLibdCount. That leaves a known
// divergence -- CALineAll.IsOrphan accepts any load while
// ActionGroup.CmEligFlag demands a released one -- which is a pending
// business decision, not a defect.
// Branches B1 (both) still join ZREING_CM_H_A directly and carry the SAME
// [0..N] exposure: delta_flag separates base from delta but does not
// protect against two loads of the same kind. They CANNOT be migrated to an
// aggregated view the way branch A was, because unlike branch A they read
// DATA fields from CM -- CM.amount feeds BaseAmt and CM.currency feeds
// CtCurrency. Collapsing several loads would require deciding WHICH amount
// wins (sum / max / highest load_seq), and that changes reported figures:
// it is a business decision, not a cardinality fix. Escalated as its own
// item, deliberately NOT resolved here.
// Also corrected in the V005 note above: the live service is
// ZREING_CA_SRV (binding ZREING_CA_UI_V4); ZREING_CA_SRV_V2 is deprecated.
// Change ID V007 (10.09.2026 | EXT_GONZALCA): two independent defects kept
// the CALineAll read broken for 02/2026 (SAPUI5 1.151 "Duplicate key
// predicate"). Both are fixed here; both were needed.
// (1) The B1-delta branch joined ZI_ReingCAMeShareByCountry WITHOUT
// PeriodMonth, while B1-base already had it -- an incomplete copy-paste
// when the branch was cloned. That view is keyed by
// CtId/Matnr/PeriodYear/PeriodMonth/Country, so omitting PeriodMonth makes
// the join [0..N] by construction: one row per loaded month. For
// IC-0001/ICSRV44 two months exist in 2026 (01 and 02), hence the exact x2
// fan-out on the 11 receiving companies. Worse than the cardinality, one
// of the two copies carried the SharePctPais of ANOTHER month and thus a
// wrong ShareCombPct -- a DATA defect that SAPUI5 1.120 silently hides by
// keeping one arbitrary row.
// This CORRECTS the conclusion recorded in V006 above: the fan-out was NOT
// caused by zreing_cm_h_a. For the reported case CM contributes exactly one
// row (of its two loads only the LIBD/delta_flag=X one survives the where),
// and both duplicates carried an identical BaseAmt, so no "which amount
// wins" decision was ever involved. The [0..N] exposure of zreing_cm_h_a
// that V006 describes is real and STILL OPEN, but it is a latent risk, not
// the cause of this incident.
// (2) The declared key did not separate a persisted line from its pending
// delta: for the same CtUuid/MatUuid/OpType/OpUuid/BukrsRecv/period, row A
// (RUN-202602 / 0000042, DeltaSeq 01) and the pending B1 (DeltaSeq 02) are
// both functionally correct and MUST coexist, yet OData saw one entity.
// RowType and DeltaSeq are now key elements in all 4 branches. RowType
// alone would have covered the reported case; DeltaSeq additionally closes
// the symmetric A<->A exposure (two persisted deltas are both RowType='A').
// Neither is nullable in any branch -- table field, casted literals or a
// coalesce -- which is what lets them be keys, and view entities require
// key elements at the head of the select list, hence the reordering.
// This CHANGES $metadata of ZREING_CA_SRV (binding ZREING_CA_UI_V4): the
// frontend regenerates its local metadata.xml and CALineAll.json mock.
// Still open, deliberately untouched: the B1-base anti-join to
// zreing_ca_line_a omits LN.op_uuid (B1-delta has it). It cannot duplicate
// rows -- it does the opposite, suppressing pending lines when a calculated
// line of a DIFFERENT op_uuid of the same op_type exists. Fixing it makes
// rows APPEAR, a functional change, so it is reported separately instead of
// being bundled here.
// Change ID V008 (11.09.2026 | EXT_GONZALCA): the anti-join to
// zreing_ca_line_a in branches B-1 and B-1b did not restrict the PERIOD, so a
// line calculated in any earlier run suppressed the pending row of the period
// being looked at, permanently. Confirmed in TS4 for IC-0008: line F/DAB of
// RUN-202512 (2025/12) hid the pending F/DAB of 2026/02, so the app showed 13
// of the 14 receiving companies. zreing_ca_line_a has no period_year /
// period_month of its own -- the period lives in zreing_ca_run_a, reachable
// through calc_run_id -- and a LEFT OUTER JOIN cannot take a nested join as
// its right operand, so the pair is resolved by the new auxiliary view
// ZI_ReingCALinePeriod (same grain as the line table, enriched with the run
// period). Both branches now compare that period against the period of the
// branch itself. Every other predicate of the anti-join is unchanged,
// including LN.op_uuid in B-1b and its absence in B-1 (see the note above,
// still open and deliberately untouched).
// Change ID V009 (15.09.2026 | EXT_GONZALCA): bug tracker #65 -- "el nombre
// del proveedor no esta completado". BpName llegaba VACIO en las CUATRO
// ramas: la rama A leia LA.bp_name, una columna que NADIE escribe (ver la
// nota "BP_NAME stays blank" en ZCL_REING_CA_PIPELINE~step_validate), y las
// tres ramas PEND lo hardcodeaban con cast('' as char80) -- la
// "simplificacion ratificada en F1" a la que esa misma nota se remite. O sea
// que el campo nunca mostro nada, en ningun estado de la linea.
// Se resuelve por ASOCIACION a I_Supplier y no persistiendo la columna, por
// tres razones: (1) es el patron YA RATIFICADO en este proyecto para este
// mismo dato -- ZI_ReingCTContract2 declara la misma asociacion y
// ZC_ReingCTContract2 expone "_Supplier.SupplierName as SupplierName" con el
// comentario "text element de Lifnr"; (2) arregla las 4 ramas de una vez,
// mientras persistir solo podria arreglar la rama A (las PEND no tienen fila
// en LINE_A que poblar) y encima exigiria backfill de lo ya calculado;
// (3) NADA consume bp_name aguas abajo -- verificado: ZCL_REING_CONTAB_DOC no
// lo menciona y el documento FI identifica al proveedor por LIFNR -- asi que
// congelar el nombre al momento del calculo no aporta valor de auditoria: es
// un texto de dato maestro, no un dato transaccional.
// El cast a ZREING_CA_BP_NAME es DELIBERADO y no cosmetico: preserva el tipo
// (CHAR 80, identico a md_supplier_name, asi que las 4 ramas del UNION
// siguen alineadas) y sobre todo el LABEL "Nombre de Proveedor". Sin el, el
// elemento heredaria el label ingles de MD_SUPPLIER_NAME, porque la Metadata
// Extension ZC_ReingCALineAll expone BpName SIN @EndUserText.label propio.
// La columna zreing_ca_line_a-bp_name queda sin uso; se deja en su lugar y
// anotada, no se borra en este pase.
// Change ID V010 (16.09.2026 | EXT_GONZALCA): bug tracker #74 -- "el
// contrato IC-0015 no aparece en el motor de calculo". Las dos ramas B1
// unian zreing_me_h_a por el periodo de la CM, IGNORANDO ME_PERIOD_OFFSET.
// El offset ya se respetaba en el pipeline ABAP desde el fix del 08.09.2026
// (ZCL_REING_CA_SOURCES=>calc_me_period, llamado por step_validate,
// step_distribute, step_pc_split y step_delta), pero NUNCA llego a la capa
// CDS de lectura: el fix quedo a medias y la mitad que falto es esta.
// Consecuencia real (TS4-400, IC-0015 / ICSRV45 / F): con offset '01' la
// metrica de un calculo de 02/2026 es la de 01/2026 -- que es exactamente
// como Rochelle cargo el dato -- pero el INNER JOIN buscaba la de 02/2026,
// no la encontraba y BORRABA LA FILA. El contrato desaparecia de la app sin
// ningun mensaje de error, que es lo que hizo caro el diagnostico.
// IC-0016 no fallaba por estar mejor configurado: tiene el mismo offset
// '01' y sobrevivia porque tiene metrica cargada en TODOS los meses, asi
// que el join encontraba "una" ME -- la del mes EQUIVOCADO. De ahi el
// defecto secundario que este mismo cambio corrige: los shares que la lista
// de pendientes mostraba eran los de M mientras el calculo aplicaba los de
// M-1, o sea que lo que el usuario veia no era lo que se iba a aplicar.
// El periodo de metrica se resuelve en la vista auxiliar nueva
// ZI_ReingCACmMePeriod porque la aritmetica del offset no se puede escribir
// dentro de un ON (SDDL_PARSER_MSG 066, ver Change ID V004 arriba). Se une
// por CM.cm_h_id + OPT.op_uuid -- clave real de la CM mas la instancia del
// op_type -- de modo que el join es 1:1 y NO agrega fan-out sobre la
// exposicion [0..N] de zreing_cm_h_a que V006/V007 dejaron abierta.
// Los alias MS (share por sociedad) y MC (share por pais) NO se tocan: ya
// unian por ME.period_year / ME.period_month, asi que al corregir el
// periodo de ME siguen el offset automaticamente.
// El anti-join LN (ZI_ReingCALinePeriod) TAMPOCO se toca, a proposito:
// compara el periodo del RUN de la linea calculada, que es el periodo de la
// CM y no el de la metrica. Igual las claves declaradas PeriodYear /
// PeriodMonth, que siguen siendo las de la CM -- el periodo de la linea es
// el del calculo, no el de su insumo.
// NO cambia $metadata de ZREING_CA_SRV (binding ZREING_CA_UI_V4): solo se
// modifican condiciones ON y se agrega un JOIN; ni la lista de campos ni
// las claves cambian. A diferencia del V007, el frontend NO tiene que
// regenerar metadata.xml ni el mock CALineAll.json.
// Change ID V011 (18.09.2026 | EXT_GONZALCA): bug tracker #85 -- "al calcular
// la prevision, el sistema muestra unicamente el saldo de delta, ignorando el
// saldo real de la provision del mes" (Rochelle, TS4-400, 18.09.2026).
// The LN anti-join of the B-1 BASE branch did not tell delta lines apart from
// original ones: it matched ANY zreing_ca_line_a row of the same
// CtUuid / MatUuid / OpType / BukrsRecv / period. Once a group has its delta
// calculated, those delta lines make LN.CtUuid non-null and the BASE CM load
// is suppressed from the pending side -- so it is never offered for
// calculation at all.
// Reported case (IC-0008 / ICSRV45 / 02-2026): zreing_cm_h_a holds two loads
// of op_type P, the base one for 180.000,00 (delta_flag blank, LIBD) and the
// delta for 2.000,00 (delta_flag = 'X', LIBD). The 42 lines of RUN-202602 are
// 14 of A, 14 of F and 14 of P, and all 14 of P carry IS_DELTA = 'X',
// DELTA_SEQ = 01 and BASE_AMT = 2.000,00. Not one line exists for the
// 180.000. In the app the groups "P 001 D01" and "P 001 D02" are there, but
// the "P 001" base group does not exist.
// The fix adds "LN.IsDelta <> 'X'" to the ON condition, so the base branch is
// only suppressed by an ORIGINAL line. The sibling B-1b branch already got
// this right with its own "LN.IsDelta = 'X'" (V008).
// Backed by text that is NEW in ET-REING-CA-001 v50 SS5.3: "El anti-join de
// B-1 y B-2 utiliza la clave sin DELTA_SEQ (para originales). El anti-join de
// B-1b utiliza la clave CON DELTA_SEQ (para deltas)."
// Does NOT change $metadata of ZREING_CA_SRV (binding ZREING_CA_UI_V4): a
// single ON condition is added, neither the field list nor the keys move, so
// the frontend regenerates nothing. What DOES change is that pending rows
// hidden until now APPEAR.
// Still open and deliberately left out of this change: the missing LN.OpUuid
// in this same anti-join (see the V007 note above). It is NOT the cause of
// #85 -- IC-0008 / P has a single operation instance, so op_uuid
// discriminates nothing here -- and bundling it would mean verifying two
// functional changes at once.
// Change ID V001 (CC) — fixes-049 (Delta v2): bug #85. La rama B-1b
// consume una carga delta por CM_H_ID sin comparar DeltaSeq contra la
// secuencia siguiente. No cambia claves, campos ni metadata OData.
// Change ID V001 (CC) — fixes-056 (Delta v2): bug #88.
// DeferCuotaNum is now the chronological schedule position, independent of
// prior CRON_STATUS values. No keys, fields or OData metadata are changed.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Vista Unificada de Lineas (Real + Pendientes)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCALineAll
  as select from zreing_ca_line_a as LA
    inner join zreing_ca_run_a  as RN
      on LA.calc_run_id = RN.calc_run_id
    left outer join zreing_op_type_c as OPC
      on OPC.op_type = LA.op_type
    // V001 (CC) - Bugs 113/114 (Delta v2): validate the exact consumed load.
    // CM_H_ID is unique per client; replacement base/delta loads cannot
    // make a persisted calculation reference valid or multiply its rows.
    left outer join zreing_cm_h_a as CM_REF
      on CM_REF.cm_h_id = LA.cm_h_id
    // Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
    // Bug #65. La condicion ON usa el campo de la fuente (LA.lifnr) y no
    // $projection.Lifnr: dentro de una rama de UNION es mas explicito y no
    // depende de como se resuelva el alias de proyeccion en cada rama.
    association [0..1] to I_Supplier as _Supplier
      on _Supplier.Supplier = LA.lifnr
    // End Insert V009 (15.09.2026 | EXT_GONZALCA)
{
  key LA.ct_uuid                    as CtUuid,
  key LA.mat_uuid                   as MatUuid,
  key LA.op_type                    as OpType,
  key LA.op_uuid                    as OpUuid,
  key LA.bukrs_recv                 as BukrsRecv,
  key RN.fiscal_year                as PeriodYear,
  key RN.fiscal_period              as PeriodMonth,
  // Begin Change ID V007 (10.09.2026 | EXT_GONZALCA)
  key cast( 'A' as zreing_ca_row_type )   as RowType,
  key LA.delta_seq                        as DeltaSeq,
  key LA.cm_h_id                           as CmHId,
  // V001 (CC) - #105: archived and replacement rows have distinct OData keys.
  key LA.calc_run_id as CalcRunId,
  key LA.line_num as LineNum,
      LA.cm_load_seq                       as CmLoadSeq,
  // End Change ID V007 (10.09.2026 | EXT_GONZALCA)


      LA.ct_id                            as CtId,
      LA.lifnr                            as Lifnr,
      // Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      // Bug #65: era "LA.bp_name as BpName" -- columna que nadie escribe.
      cast( _Supplier.SupplierName as zreing_ca_bp_name ) as BpName,
      // End Mod V009 (15.09.2026 | EXT_GONZALCA)
      LA.bukrs_prest                      as BukrsPrest,
      LA.op_instance_num                  as OpInstanceNum,
      LA.matnr                            as Matnr,
      LA.country                          as Country,
      LA.share_pct                        as SharePct,
      LA.share_pais_pct                   as SharePaisPct,
      LA.share_comb_pct                   as ShareCombPct,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.base_amt                         as BaseAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.calc_amt                         as CalcAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.bruto_amt                        as BrutoAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.gross_up_amt                     as GrossUpAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.tax_amt                          as TaxAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.net_amt                          as NetAmt,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      LA.net_local_amt                    as NetLocalAmt,
      LA.ct_currency                      as CtCurrency,
      LA.local_currency                   as LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): persisted values on real rows.
      LA.trans_currency                  as TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      LA.net_trans_amt                   as NetTransAmt,
      LA.exch_rate_1                     as ExchRate1,
      LA.exch_rate_1_type                as ExchRate1Type,
      LA.exch_rate                        as ExchRate,
      LA.exch_rate_type                   as ExchRateType,
      LA.line_status                      as LineStatus,
      // Begin Change ID V005 (07.09.2026 | EXT_GONZALCA)
      // Mapping copied verbatim from ZI_ReingCALine (StatusCriticality).
      // 0 neutral / 1 negative / 2 critical / 3 positive. Each literal is
      // cast individually -- the same shape as DeltaCriticality below;
      // casting the whole CASE expression is not supported here.
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
      end                                 as StatusCriticality,
      // End Change ID V005 (07.09.2026 | EXT_GONZALCA)
      LA.sim_message                      as SimMessage,
      LA.is_delta                         as IsDelta,
      case when LA.is_delta = 'X' then cast( 3 as abap.int1 )
           else cast( 0 as abap.int1 ) end as DeltaCriticality,
      @Semantics.amount.currencyCode: 'CtCurrency'
      LA.delta_base_amt                   as DeltaBaseAmt,
      @Semantics.amount.currencyCode: 'ParentCurrency'
      LA.parent_net_amt                   as ParentNetAmt,
      LA.parent_currency                  as ParentCurrency,
      LA.defer_pct                        as DeferPct,
      LA.defer_cuota_num                  as DeferCuotaNum,
      LA.defer_cuota_total                as DeferCuotaTotal,
      LA.defer_from                       as DeferFrom,
      LA.defer_to                         as DeferTo,
      LA.origin_run_id                    as OriginRunId,
      LA.origin_line_num                  as OriginLineNum,
      LA.insumo_check_at                  as InsumoCheckAt,

      // V001 (CC) - Bugs 113/114 (Delta v2): mirror the action-group
      // orphan rule. CM-independent operations keep their existing rule.
      cast(
        case
          when OPC.cm_loadable = 'X' and CM_REF.cm_h_id is null then 'X'
          else ''
        end as abap.char(1)
      )                                    as IsOrphan

}
union all
select from zreing_ct2_a as CT
  inner join zreing_ct2_mat_a as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join zreing_ct2_opt_a as OPT
    on  OPT.ct_uuid  = MAT.ct_uuid
    and OPT.mat_uuid = MAT.mat_uuid
  inner join zreing_op_type_c as OPC
    on OPC.op_type = OPT.op_type
  inner join zreing_cm_h_a as CM
    on  CM.ct_uuid  = CT.ct_uuid
    and CM.mat_uuid = MAT.mat_uuid
    and CM.op_type  = OPT.op_type
    and CM.op_instance_num = OPT.op_instance_num
  // Begin Insert V010 (16.09.2026 | EXT_GONZALCA)
  // Periodo de metrica resuelto con ME_PERIOD_OFFSET. Join 1:1 por la clave
  // real de la CM (cm_h_id) mas la instancia del op_type (op_uuid): no
  // agrega cardinalidad.
  inner join ZI_ReingCACmMePeriod as CMP
    on  CMP.CmHId  = CM.cm_h_id
    and CMP.OpUuid = OPT.op_uuid
  // End Insert V010 (16.09.2026 | EXT_GONZALCA)
  inner join zreing_me_h_a as ME
    on  ME.ct_id        = CT.ct_id
    and ME.matnr        = MAT.matnr
    // Begin Mod V010 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and ME.period_year  = CM.period_year
    //    and ME.period_month = CM.period_month
    and ME.period_year  = CMP.MePeriodYear
    and ME.period_month = CMP.MePeriodMonth
    // End Mod V010 (16.09.2026 | EXT_GONZALCA)
  inner join ZI_ReingCAMeShareBySoc as MS
    on  MS.CtId        = ME.ct_id
    and MS.Matnr       = ME.matnr
    and MS.PeriodYear  = ME.period_year
    and MS.PeriodMonth = ME.period_month
  left outer join ZI_ReingCAMeShareByCountry as MC
    on  MC.CtId        = ME.ct_id
    and MC.Matnr       = ME.matnr
    and MC.PeriodYear  = ME.period_year
    and MC.PeriodMonth = ME.period_month
    and MC.Country     = MS.Country
    // Begin Change ID V008 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCALinePeriod as LN
    on  LN.CtUuid       = CT.ct_uuid
    and LN.MatUuid      = MAT.mat_uuid
    and LN.OpType       = OPT.op_type
    and LN.OpUuid = OPT.op_uuid
    and LN.BukrsRecv    = MS.BukrsRecv
    and LN.PeriodYear   = CM.period_year
    and LN.PeriodMonth  = CM.period_month
    and LN.CmHId       = CM.cm_h_id
    // V001 (CC) - #105: cancelled history does not consume the pending slot.
    and LN.LineStatus <> 'ANULD'
    // End Change ID V008 (11.09.2026 | EXT_GONZALCA)
    // Begin Insert V011 (18.09.2026 | EXT_GONZALCA)
    // Bug #85: only an ORIGINAL line may suppress the base CM load. Without
    // this predicate the delta lines of the same group hide it. See header.
    and LN.IsDelta      <> 'X'
    // End Insert V011 (18.09.2026 | EXT_GONZALCA)
  // Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
  association [0..1] to I_Supplier as _Supplier
    on _Supplier.Supplier = CT.lifnr
  // End Insert V009 (15.09.2026 | EXT_GONZALCA)
{
  key CT.ct_uuid                                    as CtUuid,
  key MAT.mat_uuid                                  as MatUuid,
  key cast( OPT.op_type as zreing_op_type )         as OpType,
  key OPT.op_uuid                                   as OpUuid,
  key MS.BukrsRecv                                  as BukrsRecv,
  key CM.period_year                                as PeriodYear,
  key CM.period_month                                as PeriodMonth,
  // Begin Change ID V007 (10.09.2026 | EXT_GONZALCA)
  key cast( 'B1' as zreing_ca_row_type )            as RowType,
  key cast( '00' as abap.numc(2) )                  as DeltaSeq,
  key CM.cm_h_id                                     as CmHId,
  // V001 (CC) - #105: archived and replacement rows have distinct OData keys.
  key cast( '' as abap.char(20) ) as CalcRunId,
  key cast( '0000000' as abap.numc(7) ) as LineNum,
      CM.load_seq                                    as CmLoadSeq,
  // End Change ID V007 (10.09.2026 | EXT_GONZALCA)


      CT.ct_id                                      as CtId,
      CT.lifnr                                      as Lifnr,
      // Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      // Bug #65: era "cast( '' as abap.char(80) ) as BpName".
      cast( _Supplier.SupplierName as zreing_ca_bp_name ) as BpName,
      // End Mod V009 (15.09.2026 | EXT_GONZALCA)
      CT.bukrs                                      as BukrsPrest,
      OPT.op_instance_num                           as OpInstanceNum,
      MAT.matnr                                     as Matnr,
      MS.Country                                    as Country,
      MS.SharePctSoc                                as SharePct,
      MC.SharePctPais                               as SharePaisPct,
      cast(
        case when MC.SharePctPais is not null and MC.SharePctPais <> 0
             then MS.SharePctSoc / MC.SharePctPais * 100
             else 0 end as abap.dec(9,6)
      )                                              as ShareCombPct,
      cast( CM.amount as abap.curr(15,2) )          as BaseAmt,
      cast( 0 as abap.curr(15,2) )                  as CalcAmt,
      cast( 0 as abap.curr(15,2) )                  as BrutoAmt,
      cast( 0 as abap.curr(15,2) )                  as GrossUpAmt,
      cast( 0 as abap.curr(15,2) )                  as TaxAmt,
      cast( 0 as abap.curr(15,2) )                  as NetAmt,
      cast( 0 as abap.curr(15,2) )                  as NetLocalAmt,
      CM.currency                                   as CtCurrency,
      cast( '' as waers )                           as LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): pending rows have no computed FX.
      cast( '' as zreing_trans_waers )       as TransCurrency,
      cast( 0 as zreing_ca_net_trans_amt )   as NetTransAmt,
      cast( 0 as zreing_ca_exch_rate_1 )     as ExchRate1,
      cast( '' as zreing_ca_exr1_type )      as ExchRate1Type,
      cast( 0 as abap.dec(9,5) )                    as ExchRate,
      cast( OPC.default_exch_rate_type as abap.char(4) ) as ExchRateType,
      cast( 'PEND' as zreing_ca_line_status )       as LineStatus,
      // Begin Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( 0 as abap.int4 )                        as StatusCriticality,
      // End Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( '' as abap.char(220) )                  as SimMessage,
      cast( '' as abap.char(1) )                    as IsDelta,
      cast( 0 as abap.int1 )                        as DeltaCriticality,
      cast( 0 as abap.curr(15,2) )                  as DeltaBaseAmt,
      cast( 0 as abap.curr(15,2) )                  as ParentNetAmt,
      cast( '' as waers )                           as ParentCurrency,
      cast( 0 as abap.dec(9,6) )                    as DeferPct,
      cast( '000' as abap.numc(3) )                 as DeferCuotaNum,
      cast( '000' as abap.numc(3) )                 as DeferCuotaTotal,
      cast( '00000000' as abap.dats )               as DeferFrom,
      cast( '00000000' as abap.dats )               as DeferTo,
      cast( '' as abap.char(20) )                   as OriginRunId,
      cast( '0000000' as abap.numc(7) )             as OriginLineNum,
      cast( 0 as timestampl )                       as InsumoCheckAt,
      cast(
        case
          when OPC.cm_loadable = 'X' and CM.ct_uuid is null then 'X'
          else ''
        end as abap.char(1)
      )                                              as IsOrphan
}
where CT.ct_status   = 'AC'
//  and OPT.op_status   = 'EN'
  and OPC.cm_loadable = 'X'
  and CM.cm_status    = 'LIBD'
  and ( ME.me_status = 'LIBD' or ME.me_status = 'LIBR' )
  and CM.delta_flag  <> 'X'
  // Begin Change ID V008 (11.09.2026 | EXT_GONZALCA)
  and LN.CtUuid       is null
  // End Change ID V008 (11.09.2026 | EXT_GONZALCA)
union all
select from zreing_ct2_a as CT
  inner join zreing_ct2_mat_a as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join zreing_ct2_opt_a as OPT
    on  OPT.ct_uuid  = MAT.ct_uuid
    and OPT.mat_uuid = MAT.mat_uuid
  inner join zreing_op_type_c as OPC
    on OPC.op_type = OPT.op_type
  inner join zreing_cm_h_a as CM
    on  CM.ct_uuid  = CT.ct_uuid
    and CM.mat_uuid = MAT.mat_uuid
    and CM.op_type  = OPT.op_type
    and CM.op_instance_num = OPT.op_instance_num
  // Begin Insert V010 (16.09.2026 | EXT_GONZALCA)
  // Periodo de metrica resuelto con ME_PERIOD_OFFSET. Join 1:1 por la clave
  // real de la CM (cm_h_id) mas la instancia del op_type (op_uuid): no
  // agrega cardinalidad.
  inner join ZI_ReingCACmMePeriod as CMP
    on  CMP.CmHId  = CM.cm_h_id
    and CMP.OpUuid = OPT.op_uuid
  // End Insert V010 (16.09.2026 | EXT_GONZALCA)
  inner join zreing_me_h_a as ME
    on  ME.ct_id        = CT.ct_id
    and ME.matnr        = MAT.matnr
    // Begin Mod V010 (16.09.2026 | EXT_GONZALCA)
    // Lineas originales (periodo de la CM, sin offset -- bug #74):
    //    and ME.period_year  = CM.period_year
    //    and ME.period_month = CM.period_month
    and ME.period_year  = CMP.MePeriodYear
    and ME.period_month = CMP.MePeriodMonth
    // End Mod V010 (16.09.2026 | EXT_GONZALCA)
  inner join ZI_ReingCAMeShareBySoc as MS
    on  MS.CtId        = ME.ct_id
    and MS.Matnr       = ME.matnr
    and MS.PeriodYear  = ME.period_year
    and MS.PeriodMonth = ME.period_month
  left outer join ZI_ReingCAMeShareByCountry as MC
    on  MC.CtId        = ME.ct_id
    and MC.Matnr       = ME.matnr
    and MC.PeriodYear  = ME.period_year
    // Begin Change ID V007 (10.09.2026 | EXT_GONZALCA)
    and MC.PeriodMonth = ME.period_month
    // End Change ID V007 (10.09.2026 | EXT_GONZALCA)
    and MC.Country     = MS.Country
  left outer join ZI_ReingCADeltaSeqCount as DC
    on  DC.CtUuid    = CT.ct_uuid
    and DC.MatUuid   = MAT.mat_uuid
    and DC.OpType    = OPT.op_type
    and DC.OpUuid    = OPT.op_uuid
    and DC.BukrsRecv = MS.BukrsRecv
    // Begin Change ID V008 (11.09.2026 | EXT_GONZALCA)
  left outer join ZI_ReingCALinePeriod as LN
    on  LN.CtUuid       = CT.ct_uuid
    and LN.MatUuid      = MAT.mat_uuid
    and LN.OpType       = OPT.op_type
    and LN.OpUuid       = OPT.op_uuid
    and LN.BukrsRecv    = MS.BukrsRecv
    and LN.PeriodYear   = CM.period_year
    and LN.PeriodMonth  = CM.period_month
    and LN.IsDelta      = 'X'
    // V001 (CC) — fixes-049 (Delta v2).
    // CM_H_ID identifica la carga ya consumida. NextDeltaSeq solo etiqueta una
    // carga nueva; usarlo en el anti-join recreaba D01 como D02 PEND.
    and LN.CmHId        = CM.cm_h_id
    // V001 (CC) - #105: cancelled history does not consume the pending slot.
    and LN.LineStatus <> 'ANULD'
    // End Change ID V008 (11.09.2026 | EXT_GONZALCA)
  // Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
  association [0..1] to I_Supplier as _Supplier
    on _Supplier.Supplier = CT.lifnr
  // End Insert V009 (15.09.2026 | EXT_GONZALCA)
{
  key CT.ct_uuid                                    as CtUuid,
  key MAT.mat_uuid                                  as MatUuid,
  key cast( OPT.op_type as zreing_op_type )         as OpType,
  key OPT.op_uuid                                   as OpUuid,
  key MS.BukrsRecv                                  as BukrsRecv,
  key CM.period_year                                as PeriodYear,
  key CM.period_month                                as PeriodMonth,
  // Begin Change ID V007 (10.09.2026 | EXT_GONZALCA)
  key cast( 'B1' as zreing_ca_row_type )            as RowType,
  key coalesce( DC.NextDeltaSeq, cast( '01' as abap.numc(2) ) )
                                                     as DeltaSeq,
  key CM.cm_h_id                                     as CmHId,
  // V001 (CC) - #105: archived and replacement rows have distinct OData keys.
  key cast( '' as abap.char(20) ) as CalcRunId,
  key cast( '0000000' as abap.numc(7) ) as LineNum,
      CM.load_seq                                    as CmLoadSeq,
  // End Change ID V007 (10.09.2026 | EXT_GONZALCA)


      CT.ct_id                                      as CtId,
      CT.lifnr                                      as Lifnr,
      // Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      // Bug #65: era "cast( '' as abap.char(80) ) as BpName".
      cast( _Supplier.SupplierName as zreing_ca_bp_name ) as BpName,
      // End Mod V009 (15.09.2026 | EXT_GONZALCA)
      CT.bukrs                                      as BukrsPrest,
      OPT.op_instance_num                           as OpInstanceNum,
      MAT.matnr                                     as Matnr,
      MS.Country                                    as Country,
      MS.SharePctSoc                                as SharePct,
      MC.SharePctPais                               as SharePaisPct,
      cast(
        case when MC.SharePctPais is not null and MC.SharePctPais <> 0
             then MS.SharePctSoc / MC.SharePctPais * 100
             else 0 end as abap.dec(9,6)
      )                                              as ShareCombPct,
      cast( CM.amount as abap.curr(15,2) )          as BaseAmt,
      cast( 0 as abap.curr(15,2) )                  as CalcAmt,
      cast( 0 as abap.curr(15,2) )                  as BrutoAmt,
      cast( 0 as abap.curr(15,2) )                  as GrossUpAmt,
      cast( 0 as abap.curr(15,2) )                  as TaxAmt,
      cast( 0 as abap.curr(15,2) )                  as NetAmt,
      cast( 0 as abap.curr(15,2) )                  as NetLocalAmt,
      CM.currency                                   as CtCurrency,
      cast( '' as waers )                           as LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): pending rows have no computed FX.
      cast( '' as zreing_trans_waers )       as TransCurrency,
      cast( 0 as zreing_ca_net_trans_amt )   as NetTransAmt,
      cast( 0 as zreing_ca_exch_rate_1 )     as ExchRate1,
      cast( '' as zreing_ca_exr1_type )      as ExchRate1Type,
      cast( 0 as abap.dec(9,5) )                    as ExchRate,
      cast( OPC.default_exch_rate_type as abap.char(4) ) as ExchRateType,
      cast( 'PEND' as zreing_ca_line_status )       as LineStatus,
      // Begin Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( 0 as abap.int4 )                        as StatusCriticality,
      // End Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( '' as abap.char(220) )                  as SimMessage,
      cast( 'X' as abap.char(1) )                   as IsDelta,
      cast( 3 as abap.int1 )                        as DeltaCriticality,
      cast( 0 as abap.curr(15,2) )                  as DeltaBaseAmt,
      cast( 0 as abap.curr(15,2) )                  as ParentNetAmt,
      cast( '' as waers )                           as ParentCurrency,
      cast( 0 as abap.dec(9,6) )                    as DeferPct,
      cast( '000' as abap.numc(3) )                 as DeferCuotaNum,
      cast( '000' as abap.numc(3) )                 as DeferCuotaTotal,
      cast( '00000000' as abap.dats )               as DeferFrom,
      cast( '00000000' as abap.dats )               as DeferTo,
      cast( '' as abap.char(20) )                   as OriginRunId,
      cast( '0000000' as abap.numc(7) )             as OriginLineNum,
      cast( 0 as timestampl )                       as InsumoCheckAt,
      cast(
        case
          when OPC.cm_loadable = 'X' and CM.ct_uuid is null then 'X'
          else ''
        end as abap.char(1)
      )                                              as IsOrphan
}
where CT.ct_status   = 'AC'
  and OPC.cm_loadable = 'X'
  and CM.cm_status    = 'LIBD'
  and ( ME.me_status = 'LIBD' or ME.me_status = 'LIBR' )
  and CM.delta_flag  = 'X'
  and OPC.permite_delta = 'X'
  // Begin Change ID V008 (11.09.2026 | EXT_GONZALCA)
  and LN.CtUuid       is null
  // End Change ID V008 (11.09.2026 | EXT_GONZALCA)
union all
select from zreing_ct2_a as CT
  inner join zreing_ct2_mat_a as MAT
    on MAT.ct_uuid = CT.ct_uuid
  inner join zreing_ct2_opt_a as OPT_CHILD
    on  OPT_CHILD.ct_uuid  = MAT.ct_uuid
    and OPT_CHILD.mat_uuid = MAT.mat_uuid
  inner join zreing_op_type_c as OPC_CHILD
    on  OPC_CHILD.op_type = OPT_CHILD.op_type
    and OPC_CHILD.active  = 'X'
  inner join zreing_ct2_opt_a as OPT_PARENT
    on  OPT_PARENT.ct_uuid       = CT.ct_uuid
    and OPT_PARENT.mat_uuid      = MAT.mat_uuid
    and OPT_PARENT.op_type       = OPC_CHILD.parent_type
    and ( OPT_PARENT.op_uuid     = OPT_CHILD.parent_instance_id
       or OPT_PARENT.op_instance_num = OPT_CHILD.op_instance_num )
  inner join zreing_ct2_crn_a as CRN
    on  CRN.ct_uuid  = OPT_CHILD.ct_uuid
    and CRN.mat_uuid = OPT_CHILD.mat_uuid
    and CRN.op_type  = OPT_CHILD.op_type
    and CRN.op_uuid  = OPT_CHILD.op_uuid
  inner join zreing_ca_line_a as PARENT_LINE
    on  PARENT_LINE.ct_uuid     = CT.ct_uuid
    and PARENT_LINE.mat_uuid    = MAT.mat_uuid
    and PARENT_LINE.op_uuid     = OPT_PARENT.op_uuid
    and PARENT_LINE.line_status = 'CONT'
  // Begin Change ID V001 (CC) — fixes-056 (Delta v2)
  // The quota number is the chronological position of this schedule row.
  // It must not depend on how many previous rows have CRON_STATUS = 'EX'.
  inner join ZI_ReingCADfrCuotaSeq as CQS
    on  CQS.CtUuid    = OPT_CHILD.ct_uuid
    and CQS.MatUuid   = OPT_CHILD.mat_uuid
    and CQS.OpType    = OPT_CHILD.op_type
    and CQS.OpUuid    = OPT_CHILD.op_uuid
    and CQS.CronYear  = CRN.cron_year
    and CQS.CronMonth = CRN.cron_month
  // End Change ID V001 (CC) — fixes-056 (Delta v2)
  left outer join ZI_ReingCALinePeriod as LN
    on  LN.CtUuid      = OPT_CHILD.ct_uuid
    and LN.MatUuid     = OPT_CHILD.mat_uuid
    and LN.OpUuid      = OPT_CHILD.op_uuid
    and LN.BukrsRecv   = PARENT_LINE.bukrs_recv
    and LN.PeriodYear  = CRN.cron_year
    and LN.PeriodMonth = CRN.cron_month
    and LN.CmHId       = PARENT_LINE.cm_h_id
    // V001 (CC) - #105: cancelled history does not consume the pending slot.
    and LN.LineStatus <> 'ANULD'
  left outer join ZI_ReingCADfrBaseAmt as BA
    on  BA.CtUuid    = OPT_CHILD.ct_uuid
    and BA.MatUuid   = OPT_CHILD.mat_uuid
    and BA.OpType    = OPT_CHILD.op_type
    and BA.OpUuid    = OPT_CHILD.op_uuid
    and BA.CronYear  = CRN.cron_year
    and BA.CronMonth = CRN.cron_month
    and BA.BukrsRecv = PARENT_LINE.bukrs_recv
  // Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
  association [0..1] to I_Supplier as _Supplier
    on _Supplier.Supplier = CT.lifnr
  // End Insert V009 (15.09.2026 | EXT_GONZALCA)
{
  key CT.ct_uuid                                    as CtUuid,
  key MAT.mat_uuid                                  as MatUuid,
  key cast( OPT_CHILD.op_type as zreing_op_type )   as OpType,
  key OPT_CHILD.op_uuid                             as OpUuid,
  key PARENT_LINE.bukrs_recv                        as BukrsRecv,
  key CRN.cron_year                                 as PeriodYear,
  key CRN.cron_month                                as PeriodMonth,
  // Begin Change ID V007 (10.09.2026 | EXT_GONZALCA)
  key cast( 'B2' as zreing_ca_row_type )            as RowType,
  key cast( '00' as abap.numc(2) )                  as DeltaSeq,
  key PARENT_LINE.cm_h_id                            as CmHId,
  // V001 (CC) - #105: archived and replacement rows have distinct OData keys.
  key cast( '' as abap.char(20) ) as CalcRunId,
  key cast( '0000000' as abap.numc(7) ) as LineNum,
      PARENT_LINE.cm_load_seq                        as CmLoadSeq,
  // End Change ID V007 (10.09.2026 | EXT_GONZALCA)


      CT.ct_id                                      as CtId,
      CT.lifnr                                      as Lifnr,
      // Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      // Bug #65: era "cast( '' as abap.char(80) ) as BpName".
      cast( _Supplier.SupplierName as zreing_ca_bp_name ) as BpName,
      // End Mod V009 (15.09.2026 | EXT_GONZALCA)
      CT.bukrs                                      as BukrsPrest,
      OPT_CHILD.op_instance_num                     as OpInstanceNum,
      MAT.matnr                                     as Matnr,
      PARENT_LINE.country                           as Country,
      PARENT_LINE.share_pct                         as SharePct,
      PARENT_LINE.share_pais_pct                    as SharePaisPct,
      PARENT_LINE.share_comb_pct                    as ShareCombPct,
      BA.BaseAmt                                     as BaseAmt,   -- antes: PARENT_LINE.net_amt * CRN.percentage / 100 (fallo en activacion real, ver DD-16/Fix D)
      cast( 0 as abap.curr(15,2) )                  as CalcAmt,
      cast( 0 as abap.curr(15,2) )                  as BrutoAmt,
      cast( 0 as abap.curr(15,2) )                  as GrossUpAmt,
      cast( 0 as abap.curr(15,2) )                  as TaxAmt,
      cast( 0 as abap.curr(15,2) )                  as NetAmt,
      cast( 0 as abap.curr(15,2) )                  as NetLocalAmt,
      PARENT_LINE.ct_currency                       as CtCurrency,
      PARENT_LINE.local_currency                    as LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): pending rows have no computed FX.
      cast( '' as zreing_trans_waers )       as TransCurrency,
      cast( 0 as zreing_ca_net_trans_amt )   as NetTransAmt,
      cast( 0 as zreing_ca_exch_rate_1 )     as ExchRate1,
      cast( '' as zreing_ca_exr1_type )      as ExchRate1Type,
      cast( 0 as abap.dec(9,5) )                    as ExchRate,
      cast( OPT_CHILD.exch_rate_type as abap.char(4) ) as ExchRateType,
      cast( 'PEND' as zreing_ca_line_status )       as LineStatus,
      // Begin Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( 0 as abap.int4 )                        as StatusCriticality,
      // End Change ID V005 (07.09.2026 | EXT_GONZALCA)
      cast( '' as abap.char(220) )                  as SimMessage,
      cast( '' as abap.char(1) )                    as IsDelta,
      cast( 0 as abap.int1 )                        as DeltaCriticality,
      cast( 0 as abap.curr(15,2) )                  as DeltaBaseAmt,
      PARENT_LINE.net_amt                           as ParentNetAmt,
      PARENT_LINE.ct_currency                       as ParentCurrency,
      CRN.percentage                                as DeferPct,
      // V001 (CC) — fixes-056: chronological position, status-independent.
      cast( lpad( ltrim( cast( CQS.CuotaNum as abap.char(20) ), ' ' ), 3, '0' ) as abap.numc(3) ) as DeferCuotaNum,
      OPT_CHILD.installments                        as DeferCuotaTotal,
      OPT_CHILD.defer_from                          as DeferFrom,
      OPT_CHILD.defer_to                            as DeferTo,
      PARENT_LINE.calc_run_id                       as OriginRunId,
      PARENT_LINE.line_num                          as OriginLineNum,
      cast( 0 as timestampl )                       as InsumoCheckAt,
      cast( '' as abap.char(1) )                    as IsOrphan
}
where ( CRN.cron_status = 'PL' or CRN.cron_status = '' )
  and PARENT_LINE.line_status = 'CONT'
  and LN.CtUuid                is null




