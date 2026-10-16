//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 06.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// Change ID V002 (04.08.2026 | EXT_GONZALCA): "DeltaSeq > 0" comparaba
// NUMC(2) contra un literal INT1, tipos incompatibles en esta version de
// CDS. Se compara como texto contra '00' en su lugar (DeltaSeq es NUMC,
// equivalente a comparar digitos).
// Change ID V003 (07.09.2026 | EXT_GONZALCA): propagate the new calculated
// field StatusCriticality from ZI_ReingCALineAll (V005). Mandatory: this
// projection uses an explicit field list (no select *), so without it the
// field reaches neither the OData metadata nor the DDLX -- same issue
// already documented in ZC_ReingCALine V001.
// Change ID V004 (10.09.2026 | EXT_GONZALCA): propagate the key extension
// from ZI_ReingCALineAll (V007). RowType and DeltaSeq become key elements
// so that a persisted line and its pending delta stop colliding as one
// OData entity -- row A (RUN-202602 / 0000042, DeltaSeq 01) and the pending
// B1 (DeltaSeq 02) share every other key field and made SAPUI5 1.151 reject
// the whole page with "Duplicate key predicate", leaving the table empty
// for 02/2026. Mandatory here: this projection uses an explicit field list,
// so the key change does not propagate on its own. View entities require
// key elements at the head of the select list, hence the reordering; the
// GroupKey expression keeps reading DeltaSeq, which is allowed for a key
// element. This CHANGES $metadata of ZREING_CA_SRV (binding
// ZREING_CA_UI_V4) -- the frontend regenerates metadata.xml and the
// CALineAll.json mock.
// Change ID V005 (11.09.2026 | EXT_GONZALCA): expose a native OData
// navigation from a real CALineAll row to its CalcLine, so that Fiori
// elements can reach the Object Page without the frontend building the
// entity path by hand (one extra request plus a manual context binding per
// click, today).
// Target is the CONSUMPTION view ZC_ReingCALine, not the interface view:
// only the consumption view is exposed in ZREING_CA_SRV, and SADL emits the
// NavigationPropertyBinding solely when both entity sets live in the same
// service. Same pattern already activated and published for
// ZC_ReingCALine._ContabDocC -> ContabDoc.
// Cardinality [0..1] is safe by construction: CalcRunId + LineNum is the
// primary key of zreing_ca_line_a and the declared key of ZC_ReingCALine.
// Verified on TS4/400: the 73 RowType 'A' rows resolve exactly one CalcLine
// each, no fan-out and no orphan.
// The RowType = 'A' guard is redundant against today's data -- the B1/B2
// branches emit CalcRunId as an empty literal and LineNum as '0000000', and
// no persisted line carries those values -- but it states the intent and
// survives any future change to those literals. Pending rows therefore
// navigate to nothing, which is the required behaviour.
// This CHANGES $metadata of ZREING_CA_SRV (binding ZREING_CA_UI_V4): the
// frontend regenerates its local metadata.xml. The change is purely
// additive (a new NavigationProperty), no key or field is touched.
// Change ID V006 (15.09.2026 | EXT_GONZALCA): expose HasParent as a flat
// element of CALineAll. The Object Page now runs on CALineAll instead of
// CalcLine (Fiori elements models cross-page navigation only over to-many
// navigation properties, and _Line is to-one), and the "Origen" section of
// the detail must stay hidden when the line has no parent. @UI.facet in
// this release exposes no hidden property, neither literal nor path-based
// -- already assessed and rejected, see the closing note of the DDLX of
// ZC_ReingCALine -- so the frontend resolves that visibility on its side
// and needs the flag as a plain property, without a to-one hop. Same
// expression as HasParent in ZI_ReingCALine V001. Purely additive: this
// CHANGES $metadata of ZREING_CA_SRV (binding ZREING_CA_UI_V4) by one new
// property, no key and no existing field is touched.
// CORRECTION (16.09.2026 | EXT_GONZALCA): the reason given above is WRONG,
// even though the conclusion (resolve it in the frontend) turned out to be
// right. @UI.facet DOES expose a hidden property. The real blocker is the
// type of the path -- see V008 below.
// Change ID V007 (16.09.2026 | EXT_GONZALCA): frontend request of
// 16.09.2026, point 3.1 -- restore the criticality of the 4 header KPIs of
// the Object Page. Two constant elements, CritCriticalFix (1) and
// CritPositiveFix (3), consumed by @UI.dataPoint.criticality in the DDLX:
// Impuesto renders negative, Neto Cto. and Neto Local positive, Bruto stays
// neutral.
// The KPIs lost their colour when the Object Page moved from CalcLine to
// CALineAll on 15.09.2026: ZC_ReingCALine carries these two fields (from
// ZI_ReingCALine V001) and CALineAll never did, so the dataPoints were
// recreated without a criticality reference. That was a deliberate omission
// of the request of the day, not a defect -- it is documented in block B of
// the DDLX header.
// DEVIATION from the request, on purpose: the relevamiento asked for the
// two fields in ZI_ReingCALineAll and then projected here. They are
// CONSTANTS, so they live in this projection instead -- exactly the pattern
// V006 above used for HasParent. That keeps the 4 UNION ALL branches of
// ZI_ReingCALineAll untouched, which matters for two reasons: the select
// lists of a UNION must stay positionally aligned (8 insertions at the
// identical position, with nothing to gain), and bare integer literals make
// branch A infer a length-1 integer that clashes with the int4 of the
// pending branches -- the "Longitud de 1 incidente debe ser mayor" warning
// already documented in ZI_ReingCALineAll V005. Same emitted OData type,
// same value, far smaller surface.
// The cast to abap.int4 is deliberate and not cosmetic: it keeps the OData
// type aligned with CalcLine.CritCriticalFix / CritPositiveFix, so the same
// KPI renders identically on both entities of ZREING_CA_SRV.
// This CHANGES $metadata of ZREING_CA_SRV (binding ZREING_CA_UI_V4) by two
// new properties. The frontend regenerates its local metadata.xml. No key
// and no existing field is touched.
// Change ID V008 (16.09.2026 | EXT_GONZALCA): POC of point 4.1 of the same
// request -- hide the "Origen" facet from the backend instead of from the
// frontend manifest. RESULT: NOT VIABLE in this system. No element is added
// by this change; the number that follows is burned on purpose so the
// finding has a stable reference, because the conclusion is what matters.
// The chain, each step verified against DS4-200:
//  1. @UI.facet.hidden EXISTS, in both its literal form ("hidden: true")
//     and its dynamic-path form ("hidden: #(Field)"). Both pass a
//     non-persistent syntax check with no message, and the check is not
//     permissive -- calibrated with an invented property it answers
//     "Annotation 'UI.facet.notarealproperty' unknown". This REFUTES the
//     July assessment quoted in V006 above and in the closing note of the
//     DDLX of ZC_ReingCALine, which had never been tested against the
//     compiler and was propagated as fact.
//  2. UI.Hidden needs a BOOLEAN path. HasParent cannot serve: it is
//     CHAR(1) 'X'/'' and therefore Edm.String.
//  3. Producing a real Edm.Boolean requires @Semantics.booleanIndicator on
//     the element. A cast to ABAP_BOOLEAN is NOT enough -- ABAP_BOOLEAN is
//     a CHAR(1) data element and the activation says so literally, "CAST
//     CHAR to identical type".
//  4. @Semantics.booleanIndicator is NOT RELEASED in this system.
//     Activation is cancelled with SDDIC_DDLA_ANNOCHECK 006, "Use of
//     Annotation 'Semantics.booleanIndicator' is not permitted (not
//     released)". In the DDLX layer it is rejected for a different reason
//     ("not permitted for use in metadata extensions"), so there is no
//     layer where it can be placed.
// CONSEQUENCE: with no way to expose a Boolean, the facet cannot be hidden
// from the backend in this release. The frontend keeps resolving it through
// the manifest with HasParent, which stays exactly as it is. Revisit only
// if booleanIndicator gets released.
// CORRECTION to what backend told frontend on 16.09.2026: HideDeltaFields
// in ZI_ReingCALine was cited as "the proven pattern for an Edm.Boolean in
// this project". That is WRONG. It carries the same cast WITHOUT the
// annotation -- which could not have been added anyway -- so it is exposed
// as Edm.String and works only because the frontend reads it as 'X' / ''.
// It is not touched here: it has a live consumer and changing its OData
// type would break it.
// Change ID V009 (17.09.2026 | EXT_GONZALCA): bug tracker #81, second half
// -- "incluir el numero del contrato externo en la linea de calculo".
// fixes-038 added HeaderTitle to ZI_ReingCALine and pointed the DDLX of
// ZC_ReingCALine at it, but the Object Page the user actually reaches from
// the list report is the one running on THIS entity since 15.09.2026 (see
// V006 above), whose header still showed GroupKey alone. Verified on
// TS4-400: title "IC-0008 MUR ICSRV45 F 001", description "SIM_ERR".
// The association is NOT exposed in the select list, same criterion as
// _Supplier in ZI_ReingCALine V003: nothing navigates to the contract from
// here, so the service metadata gains only the new element.
// The 4 UNION ALL branches of ZI_ReingCALineAll are deliberately NOT
// touched: this is a view entity over that view, so the association and the
// derived element belong here -- exactly the reasoning already applied to
// HasParent (V006) and to the two criticality constants (V007).
// Change ID V001 (CC) - fixes-057 (25.09.2026): expose OpTypeDesc from
// ZI_ReingOpTypeText in the session language. The DDLX groups by the
// existing HeaderTitle so visual group headers include ExtContract, while
// GroupKey and action identity remain stable.
// Change ID V001 (CC) - fixes-059 (28.09.2026): expose the contract
// material description as a separate list column (tracker #102).
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Tabla Principal de Lineas (Consumo OData)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALineAll
  as select from ZI_ReingCALineAll

  // Begin Change ID V005 (11.09.2026 | EXT_GONZALCA)
  association [0..1] to ZC_ReingCALine as _Line
    on  $projection.RowType   = 'A'
    and $projection.CalcRunId = _Line.CalcRunId
    and $projection.LineNum   = _Line.LineNum
  // End Change ID V005 (11.09.2026 | EXT_GONZALCA)
  // Begin Insert V009 (17.09.2026 | EXT_GONZALCA)
  // Bug #81. ExtContract lives in ZREING_CT2_A and is already exposed by
  // ZI_ReingCTContract2, keyed by CtUuid -- which this view already carries
  // as a key element, so the join is on the natural key. Not exposed in the
  // select list on purpose: nothing navigates to the contract from here.
  association [0..1] to ZI_ReingCTContract2 as _Contract2
    on _Contract2.CtUuid = $projection.CtUuid
  // End Insert V009 (17.09.2026 | EXT_GONZALCA)
  // Begin Change ID V001 (CC) - fixes-057: operation text for CA list.
  association [0..1] to ZI_ReingOpTypeText as _OpTypeText
    on  _OpTypeText.OpType   = $projection.OpType
    and _OpTypeText.Language = $session.system_language
  // End Change ID V001 (CC) - fixes-057
  // Begin Change ID V001 (CC) - fixes-059: contract material text.
  association [0..1] to zreing_ct2_mat_a as _ContractMaterial
    on  _ContractMaterial.ct_uuid  = $projection.CtUuid
    and _ContractMaterial.mat_uuid = $projection.MatUuid
  // End Change ID V001 (CC) - fixes-059
{
  key CtUuid,
  key MatUuid,
  key OpType,
  key OpUuid,
  key BukrsRecv,
  key PeriodYear,
  key PeriodMonth,
  // Begin Change ID V004 (10.09.2026 | EXT_GONZALCA)
  key RowType,
  key DeltaSeq,
  @UI.hidden: true
  key CmHId,
  // V001 (CC) - #105: preserve physical identity of archived rows.
  key CalcRunId,
  key LineNum,
  @UI.hidden: true
      CmLoadSeq,
  // End Change ID V004 (10.09.2026 | EXT_GONZALCA)

      CtId,
      Lifnr,
      BpName,
      BukrsPrest,
      OpInstanceNum,
      Matnr,
      // Begin Change ID V001 (CC) - fixes-059
      _ContractMaterial.mat_desc as MatDesc,
      // End Change ID V001 (CC) - fixes-059
      Country,
      SharePct,
      SharePaisPct,
      ShareCombPct,
      // Begin Change ID V001 (CC) - fixes-057
      _OpTypeText.OpTypeDesc as OpTypeDesc,
      // End Change ID V001 (CC) - fixes-057

      // CAUTION (V009): the expression below is DUPLICATED, on purpose, in
      // HeaderTitle right after it. CDS forbids referencing the alias
      // GroupKey from another element of the same view, and GroupKey must
      // stay byte-for-byte unchanged because CA actions consume it and the
      // "Grupo" column renders it. The visual group header now uses
      // HeaderTitle, which appends the external contract number.
      // ANY change to the grouping expression MUST be replicated in BOTH
      // places, or the key and displayed title drift apart.
      concat_with_space( CtId,
        concat_with_space( BukrsPrest,
          concat_with_space( Matnr,
            concat_with_space( OpType,
              concat_with_space( OpInstanceNum,
                case when DeltaSeq <> '00'
                     then concat( 'D', cast( DeltaSeq as abap.char(2) ) )
                     else '' end
              , 1 ), 1 ), 1 ), 1 ), 1 )
      as GroupKey,

      // Begin Insert V009 (17.09.2026 | EXT_GONZALCA)
      // Bug #81 -- @UI.headerInfo.title accepts exactly ONE element, and the
      // request is to read the external contract number next to what the
      // header already shows. Overwriting headerInfo.description was not an
      // option: it carries LineStatus, the state of the line (SIM_ERR in the
      // reported screenshot), which the user reads at a glance.
      // GroupKey already contains the company code, so the new value is
      // appended at the END of the very same expression. GroupKey itself is
      // left untouched, so the "Grupo" column and action identity stay
      // stable. The group header now uses HeaderTitle (fixes-057).
      // The coalesce is MANDATORY, not defensive: _Contract2 is a [0..1]
      // association and therefore resolves as a LEFT OUTER JOIN, so
      // ExtContract is NULL for any row whose contract header is missing --
      // which is EVERY row in DS4-200, where ZREING_CT2_A is empty, and also
      // the B1/B2 pending branches. On HANA a concatenation with NULL yields
      // NULL, which would blank out the WHOLE header title instead of just
      // the part that is missing. Already proven in ZI_ReingCALine V005.
      // Separator 1 = single blank, and concat_with_space skips it when the
      // second operand is empty, so a line with no external contract renders
      // "IC-0008 MUR ICSRV45 F 001" and not a trailing space.
      concat_with_space(
        concat_with_space( CtId,
          concat_with_space( BukrsPrest,
            concat_with_space( Matnr,
              concat_with_space( OpType,
                concat_with_space( OpInstanceNum,
                  case when DeltaSeq <> '00'
                       then concat( 'D', cast( DeltaSeq as abap.char(2) ) )
                       else '' end
                , 1 ), 1 ), 1 ), 1 ), 1 ),
        coalesce( _Contract2.ExtContract,
                  cast( '' as zreing_ct_ext_num ) ),
        1 )
      as HeaderTitle,
      // End Insert V009 (17.09.2026 | EXT_GONZALCA)

      IsDelta,
      DeltaCriticality,
      DeltaBaseAmt,

      BaseAmt,
      CalcAmt,
      BrutoAmt,
      GrossUpAmt,
      TaxAmt,
      NetAmt,
      NetLocalAmt,
      CtCurrency,
      LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): additive transaction-currency exposure.
      TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      NetTransAmt,
      ExchRate1,
      ExchRate1Type,
      ExchRate,
      ExchRateType,

      LineStatus,
      // Begin Change ID V003 (07.09.2026 | EXT_GONZALCA)
      StatusCriticality,
      // End Change ID V003 (07.09.2026 | EXT_GONZALCA)

      // Begin Insert V007 (16.09.2026 | EXT_GONZALCA)
      // Fixed criticality of the header KPIs (frontend request 16.09.2026,
      // point 3.1). Same values and same names as ZI_ReingCALine V001, so
      // the KPI renders identically on CalcLine and on CALineAll:
      // 1 = negative (Impuesto), 3 = positive (Neto Cto. / Neto Local).
      // Constants, hence declared here and not in the 4 UNION branches of
      // ZI_ReingCALineAll -- see the header note for the full reasoning.
      // Consumed by @UI.dataPoint.criticality in the DDLX; hidden as a
      // column there, they are technical support fields.
      cast( 1 as abap.int4 ) as CritCriticalFix,
      cast( 3 as abap.int4 ) as CritPositiveFix,
      // End Insert V007 (16.09.2026 | EXT_GONZALCA)

      SimMessage,
      IsOrphan,
      InsumoCheckAt,

      ParentNetAmt,
      ParentCurrency,
      DeferPct,
      DeferCuotaNum,
      DeferCuotaTotal,
      DeferFrom,
      DeferTo,
      OriginRunId,
      OriginLineNum,

      // Begin Change ID V006 (15.09.2026 | EXT_GONZALCA)
      // V008: stays. It is what the frontend manifest reads to hide the
      // "Origen" section, and that solution is now permanent in this
      // release -- see the V008 note in the header.
      case when ParentNetAmt <> 0 then 'X' else '' end as HasParent,
      // End Change ID V006 (15.09.2026 | EXT_GONZALCA)

      // Begin Change ID V005 (11.09.2026 | EXT_GONZALCA)
      _Line
      // End Change ID V005 (11.09.2026 | EXT_GONZALCA)
}

