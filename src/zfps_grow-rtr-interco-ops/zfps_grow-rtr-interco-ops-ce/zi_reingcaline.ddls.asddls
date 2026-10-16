// V001 (CC) - GAP-001 (Delta v2): terminal/retry states and criticality.
//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 03.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Lineas de Calculo'
@ObjectModel.semanticKey: ['CalcRunId', 'LineNum']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCALine
  as select from zreing_ca_line_a
  association to parent ZI_ReingCARun as _Run
    on $projection.CalcRunId = _Run.CalcRunId
  composition [0..*] of ZI_ReingCALinePC as _LinePC
  composition [0..*] of ZI_ReingCAStep   as _Step
  composition [0..*] of ZI_ReingCALog    as _Log
  // V001 (CC) - Local FX: persisted stage identity, independent of switch.
  association [0..1] to zreing_ca_step_a as _LocalFxStage
    on  _LocalFxStage.calc_run_id = $projection.CalcRunId
    and _LocalFxStage.line_num = $projection.LineNum
    and _LocalFxStage.step_num = '05'
    and _LocalFxStage.seq = '02'
  // Begin Change (27.08.2026 | EXT_AGFAGINA) - documento contable en app CA
  // Asociacion de solo lectura a los documentos FI generados por CONTAB.
  // Cardinalidad [0..*]: el motor genera un documento por paso activo del
  // flujo (ZREING_DOCFLOW_C), o sea 3 o 4 por linea, no uno solo.
  // No es composicion: CB_DOC_A no pertenece al BO de CalcRun, se navega para consulta.
  association [0..*] to ZI_ReingContabDoc as _ContabDoc
    on  $projection.CalcRunId = _ContabDoc.CalcRunId
    and $projection.LineNum   = _ContabDoc.LineNum
  // End Change (27.08.2026 | EXT_AGFAGINA)
  // Begin Insert V003 (16.09.2026 | EXT_GONZALCA)
  // Bug tracker #65 -- "el nombre del proveedor no esta completado".
  // BpName read the raw BP_NAME column of ZREING_CA_LINE_A, a column NOBODY
  // writes (see the "BP_NAME stays blank" note in
  // ZCL_REING_CA_PIPELINE~step_validate), so the field was always empty.
  // fixes-026 (V009) already fixed this in ZI_ReingCALineAll by association to
  // I_Supplier, and that view is correct end to end -- but the "Contrato" field
  // group of the object page is rendered through a #FIELDGROUP_REFERENCE facet
  // whose targetElement is '_Line' (DDLX ZC_ReingCALineAll), so what the user
  // actually reads comes from THIS view and not from the *All one. Verified on
  // TS4-400 for IC-0001: ZC_ReingCALineAll returns "Google LLC" while
  // ZC_ReingCALine returns blank with the same LIFNR 9600000005.
  // No UNION here, so $projection.Lifnr is safe and is exactly the form used by
  // ZI_ReingCTContract2, the view that ratified this pattern in the project.
  // The association is deliberately NOT exposed in the select list: nothing
  // navigates to the supplier, and leaving it out keeps the service metadata
  // unchanged.
  association [0..1] to I_Supplier as _Supplier
    on _Supplier.Supplier = $projection.Lifnr
  // End Insert V003 (16.09.2026 | EXT_GONZALCA)
  // Begin Insert V004 (16.09.2026 | EXT_GONZALCA)
  // Bug tracker #71 -- el campo "Tipo Tasa de Cam. IC" mostraba el ID ('P') y
  // no el texto. fixes-032 cambio la descripcion del valor fijo P del dominio
  // ZREING_EXRT_TYPE a "ICRG", pero EXCHRATETYPE estaba expuesto SIN ninguna
  // anotacion de texto, asi que Fiori Elements renderizaba el valor crudo y
  // nunca consultaba la descripcion.
  // La asociacion NO se expone en el select list y el texto se resuelve como
  // ELEMENTO (ExchRateTypeDesc + @ObjectModel.text.element), no con
  // @ObjectModel.text.association: la variante con text.association activa
  // limpio pero el ATC la rechaza con PRIORIDAD 1 sobre la vista de consumo
  // ("Use of annotation OBJECTMODEL.TEXT.ASSOCIATION is not allowed for
  // element EXCHRATETYPE", check SADL Runtime Checks) -- no esta permitida en
  // una projection view, que es lo que es ZC_ReingCALine. Un P1 bloquea la
  // liberacion de la OT. Mismo criterio de exposicion que _Supplier arriba.
  association [0..1] to ZI_ReingExrtTypeVH as _ExrtType
    on $projection.ExchRateType = _ExrtType.ExchRateType
  // End Insert V004 (16.09.2026 | EXT_GONZALCA)
  // Begin Insert V005 (17.09.2026 | EXT_GONZALCA)
  // Bug tracker #81 -- the external contract number must show up next to the
  // receiving company in the header of the calculation line object page.
  // The value lives in ZREING_CT2_A-EXT_CONTRACT and is already exposed as
  // ExtContract by ZI_ReingCTContract2, keyed by CtUuid -- which this view
  // already carries, so the join is on the natural key and needs no extra
  // field. Same exposure criterion as _Supplier (V003) and _ExrtType (V004):
  // the association is NOT exposed in the select list, because nothing
  // navigates to the contract from here and leaving it out keeps the service
  // metadata unchanged.
  association [0..1] to ZI_ReingCTContract2 as _Contract2
    on _Contract2.CtUuid = $projection.CtUuid
  // End Insert V005 (17.09.2026 | EXT_GONZALCA)
{
  key calc_run_id           as CalcRunId,
  key line_num              as LineNum,
      ct_uuid               as CtUuid,
      ct_id                 as CtId,
      // Begin Insert V005 (17.09.2026 | EXT_GONZALCA)
      // Bug #81 -- two new elements, both fed by the _Contract2 association.
      //
      // ExtContract is selected through the path expression without a cast:
      // unlike BpName in V003 (whose source is MD_SUPPLIER_NAME, a different
      // type that had to be cast back to keep the Spanish label), the source
      // element here ALREADY is zreing_ct_ext_num, so a cast would be a no-op.
      // The data element carries English labels ("Contract Number"), so the
      // Spanish label is set where it belongs, in the DDLX (V002).
      //
      // HeaderTitle exists because @UI.headerInfo.title accepts exactly ONE
      // element and the request is to read the company AND the external
      // contract number side by side. Overwriting headerInfo.description was
      // not an option either: it carries BpName, which is the fix for bug #65.
      // So the two values are concatenated here, in the interface view, and
      // the DDLX just points title at this element.
      //
      // The coalesce is MANDATORY, not defensive: _Contract2 is a [0..1]
      // association, so it resolves as a LEFT OUTER JOIN and ExtContract is
      // NULL for any line whose contract header is missing. On HANA a
      // concatenation with NULL yields NULL, which would blank out the WHOLE
      // header title -- including the company code that works today -- instead
      // of just the missing part.
      //
      // concat_with_space right-trims its first argument, so the CHAR 4 BUKRS
      // does not drag its padding into the title: the result reads
      // "DRU GITHUB ENTERPRSE", not "DRU  GITHUB ENTERPRSE". The source field
      // bukrs_recv is used instead of $projection.BukrsRecv because the
      // expression only needs the raw column.
      _Contract2.ExtContract as ExtContract,
      @EndUserText.label: 'Soc. Receptora / N. Contrato Ext.'
      concat_with_space( bukrs_recv,
                         coalesce( _Contract2.ExtContract,
                                   cast( '' as zreing_ct_ext_num ) ),
                         1 )  as HeaderTitle,
      // End Insert V005 (17.09.2026 | EXT_GONZALCA)
      lifnr                 as Lifnr,
      // Begin Mod V003 (16.09.2026 | EXT_GONZALCA)
      // Bug #65: era "bp_name as BpName". El cast es DELIBERADO y no cosmetico:
      // preserva el tipo (CHAR 80, identico a MD_SUPPLIER_NAME) y sobre todo el
      // label "Nombre de Proveedor" -- sin el, el elemento heredaria el label
      // ingles de MD_SUPPLIER_NAME. Mismo criterio que V009 de ZI_ReingCALineAll.
      cast( _Supplier.SupplierName as zreing_ca_bp_name ) as BpName,
      // End Mod V003 (16.09.2026 | EXT_GONZALCA)
      bukrs_prest           as BukrsPrest,
      mat_uuid              as MatUuid,
      matnr                 as Matnr,
      op_type               as OpType,
      op_uuid               as OpUuid,
      cm_h_id               as CmHId,
      cm_load_seq           as CmLoadSeq,
      op_instance_num       as OpInstanceNum,
      parent_op_type        as ParentOpType,
      origin_run_id         as OriginRunId,
      origin_line_num       as OriginLineNum,
      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : agregar @Semantics.amount.currencyCode para ParentNetAmt (falta simbolo de moneda en metadata OData V4)
      @Semantics.amount.currencyCode: 'ParentCurrency'
      parent_net_amt        as ParentNetAmt,
      parent_currency       as ParentCurrency,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)
      defer_pct             as DeferPct,
      defer_cuota_num       as DeferCuotaNum,
      defer_cuota_total     as DeferCuotaTotal,
      defer_from            as DeferFrom,
      defer_to              as DeferTo,
      bukrs_recv            as BukrsRecv,
      country               as Country,
      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : agregar @Semantics.amount.currencyCode a los campos de importe en moneda de contrato (CtCurrency)
      // y en moneda local (LocalCurrency) - falta simbolo de moneda en metadata OData V4, pedido de Frontend
      @Semantics.amount.currencyCode: 'CtCurrency'
      base_amt              as BaseAmt,
      share_pct             as SharePct,
      share_pais_pct        as SharePaisPct,
      share_comb_pct        as ShareCombPct,
      @Semantics.amount.currencyCode: 'CtCurrency'
      calc_amt              as CalcAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      bruto_amt             as BrutoAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      gross_up_amt          as GrossUpAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      tax_amt               as TaxAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      net_amt               as NetAmt,
      ct_currency           as CtCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      net_local_amt         as NetLocalAmt,
      local_currency        as LocalCurrency,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // V001 (CC) - CA-11 (Brazil): expose persisted transaction amounts.
      trans_currency        as TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      net_trans_amt         as NetTransAmt,
      exch_rate_1           as ExchRate1,
      exch_rate_1_type      as ExchRate1Type,
      exch_rate             as ExchRate,
      // Begin Mod V004 (16.09.2026 | EXT_GONZALCA)
      // Bug #71: el texto del dominio se resuelve por ELEMENTO, no por
      // asociacion (ver la nota de la asociacion _ExrtType arriba).
      @ObjectModel.text.element: ['ExchRateTypeDesc']
      exch_rate_type        as ExchRateType,
      @Semantics.text: true
      case
        when _LocalFxStage.step_num is not null and exch_rate_type <> ''
          then cast( 'Tipo de cotización SAP' as abap.char(60) )
        else _ExrtType.ExchRateTypeDesc
      end as ExchRateTypeDesc,
      // End Mod V004 (16.09.2026 | EXT_GONZALCA)
      // Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Descripcion : Delta v2 CA-05 - quitar HasPcBreakdown (step_pc_split ahora siempre genera
      // apertura); exponer campos delta de CA-02 (IsDelta/DeltaSeq/DeltaBaseAmt)
      is_delta              as IsDelta,
      delta_seq             as DeltaSeq,
      @Semantics.amount.currencyCode: 'CtCurrency'
      delta_base_amt        as DeltaBaseAmt,
      // Begin Change (27.08.2026 | EXT_AGFAGINA) - presentacion de campos delta
      // HideDeltaFields: booleano para @UI.hidden condicional. En una linea que
      // NO es delta, los 3 campos delta no aportan nada y se ocultan.
      case when is_delta = 'X' then cast( '' as abap_boolean )
           else cast( 'X' as abap_boolean ) end   as HideDeltaFields,
      // DeltaAmtCriticality: signo explicito del importe delta.
      // negativo = 1 (rojo), positivo = 3 (verde), cero = 0 (neutral).
      case when delta_base_amt < 0 then cast( 1 as abap.int1 )
           when delta_base_amt > 0 then cast( 3 as abap.int1 )
           else cast( 0 as abap.int1 ) end        as DeltaAmtCriticality,
      // End Change (27.08.2026 | EXT_AGFAGINA)
      // End Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Begin Insert V006 (18.09.2026 | EXT_GONZALCA)
      // ET-REING-CA-001 v50 SS9.3 -- section "Origen del Delta" of the object
      // page. The section shows four values and three of them already exist as
      // elements (DeltaSeq, DeltaBaseAmt and BrutoAmt). The fourth, "Total
      // efectivo", is explicitly defined by the ET as DERIVED and NOT
      // PERSISTED: "DELTA_BASE_AMT + BRUTO_AMT (derivado, no persistido)".
      // It answers the question the accountant asks when reading a delta line:
      // how much does this receiver add up to AFTER applying this correction.
      // Worked example from the ET: base 1.000,00 + delta 200,00 = 1.200,00;
      // and for a receiver that dropped out of ME, 400,00 + (-424,00) = -24,00.
      //
      // The cast is NOT cosmetic and must stay. Both operands are CURR(15,2)
      // over the same domain ZREING_CA_AMT_D, but leaving the sum untyped lets
      // the compiler infer the result type, which is exactly the class of
      // defect that produced the COLLECT/packed truncation bugs in this same
      // app (see the V018 note in ZCL_REING_CA_PIPELINE~step_distribute and the
      // V006 precision notes in step_pc_split). The target data element is
      // ZREING_CA_DLT_BASE_AMT because it is the one of the delta family with
      // the right length and decimals; its own label ("Monto Base Delta")
      // would be wrong here, so the label is set explicitly right below --
      // same pattern already used by HeaderTitle above.
      //
      // The currency annotation is mandatory: without it OData V4 emits the
      // amount with no currency and Fiori renders a bare number. CtCurrency is
      // the right reference -- both operands are contract-currency amounts.
      @Semantics.amount.currencyCode: 'CtCurrency'
      @EndUserText.label: 'Total Efectivo'
      cast( delta_base_amt + bruto_amt as zreing_ca_dlt_base_amt ) as TotalEfectivo,
      // End Insert V006 (18.09.2026 | EXT_GONZALCA)
      line_status           as LineStatus,
      sim_message           as SimMessage,
      proc_started_at       as ProcStartedAt,
      proc_heartbeat_at     as ProcHeartbeatAt,
      proc_job_id           as ProcJobId,
      insumo_check_at       as InsumoCheckAt,
      fi_awkey              as FiAwkey,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : 2 campos calculados nuevos pedidos por Frontend para el Object Page de CalcLineType:
      // StatusCriticality (int, deriva criticidad visual desde LineStatus para @UI.lineItem/criticality) y
      // HasParent (boolean, indica si la linea tiene un padre de diferimiento). Sin cast() por restriccion
      // conocida de este sistema (cast(<expr entera> as abap.numc(n)) no soportado en view entities) - se
      // dejan literales puros para que CDS infiera abap.int4 / abap.boolean nativamente.
      // Iteracion #4 - fix post-activacion (ERR-002): @UI.dataPoint.criticality debe ser un string con el
      // nombre de un campo, nunca un enum estatico #CRITICAL/#POSITIVE - se agregan 2 campos calculados
      // constantes (cast de literal tipado, mismo patron ya usado con exito en ZI_ReingCALineAll) para los
      // 3 KPI de criticidad fija segun ADR-006 (Impuesto=critico, NetoCto/NetoLocal=positivo).
      cast( 1 as abap.int4 ) as CritCriticalFix,
      cast( 3 as abap.int4 ) as CritPositiveFix,

      case line_status
        when 'PEND'    then 0
        when 'SIM_ERR' then 1
        when 'CALC_ERR' then 1
        when 'POST_ERR' then 1
        when 'ANUL_ERR' then 1
        when 'ANULD'    then 1
        when 'CALC'    then 2
        when 'SIM_OK'  then 3
        when 'LIBD'    then 3
        when 'CONT'    then 3
        else                0
      end                                        as StatusCriticality,

      case when parent_net_amt <> 0 then 'X' else '' end
                                                   as HasParent,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)

      _LinePC,
      _Step,
      _Log,
      _Run,
      _ContabDoc
}


