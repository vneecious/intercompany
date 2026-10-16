*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Real implementation of ZIF_REING_CA_SOURCES (blueprint SS6.10/SS D.2).
* No dependencies of its own — direct SELECTs against the external
* tables, each verified against the real structure (blueprint SS5). Not
* unit-tested directly in F2 (would need a real DB) — it is the class the
* test doubles (ltd_sources) replace everywhere else.
* Iteration #2 (07.07.2026, amendment F2-DD-6): get_ct_identity added —
* Architect-verified JOIN against ZREING_CT2_A/ZREING_CT2_MAT_A
* (blueprint SS6.10), same pattern ZI_ReingCALineAll (F1) already uses.
* Iteration #3 (07.07.2026, OB-002): get_average_exch_rate no longer
* calls BAPI_EXCHRATE_GETDETAIL (confirmed by the Reviewer to not exist
* in this system) — now uses READ_EXCHANGE_RATE (classic FM, confirmed to
* exist). Clean Core risk (F2-H5) narrowed, still not verified live.
* Iteration #5 (07.07.2026, real activation ERR-001, F2-DD-10/mechanical
* fixes): get_average_exch_rate migrated to CDS I_ExchangeRate
* (READ_EXCHANGE_RATE confirmed blocked by Clean Core in real activation).
* get_cm_amount/get_ct_option/get_me_shares/get_tx_rules reverted to the
* blueprint's literal SELECT */SELECT SINGLE * / "mi~*" (SS6.10) —
* explicit field lists without MANDT (the real structures' first
* component) were positionally misaligned against their full-structure
* RETURNING/table types, and get_cm_amount also combined SELECT SINGLE
* with ORDER BY (invalid grammar).
* Iteration #6 (07.07.2026, real dry-run + human research): the
* Iteration #5 fix for get_average_exch_rate hit the SAME "ORDER invalid"
* grammar error as get_cm_amount (confirmed by the Architect), and
* I_ExchangeRate/READ_EXCHANGE_RATE/BAPI_EXCHRATE_GETCURRENTRATES all
* turned out blocked by Clean Core anyway — migrated (4th attempt) to
* CL_EXCHANGE_RATES=>convert_to_local_currency (Cloud-released, 3/3 clean
* dry-runs). F2-H5 finally resolved. F2-DD-11 (round_to_currency,
* I_CURRENCY) untouched — already confirmed working in Iteration #5.
* Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-06 — added
* get_op_type_permite_delta / get_cont_baseline for step_delta.
* Change ID V003 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-07 — added
* get_cont_line_pc_baseline for step_pc_split delta lines.
* Change ID V004 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-08 — added
* get_cm_recv_filter (BR-CA-44) for step_02_distribute.
* Change ID V005 (05.08.2026 | EXT_GONZALCA): Delta v2 CA-11 — retirados
* get_metric_granularity/get_me_metric (codigo muerto confirmado tras
* CA-07, sin llamador productivo).
* Change ID V006 (07.09.2026 | EXT_GONZALCA): MELI request — average
* FX now reads TCURR-KURST = 'ICRG', was 'M'.
* Change ID V007 (07.09.2026 | EXT_GONZALCA): get_ct_identity ahora trae
* tambien CT2_A~WAERS (moneda de cabecera del contrato) para el fallback de
* CT_CURRENCY del pipeline - cero SELECT nuevos.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_sources DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
CLASS-METHODS calc_me_period
      IMPORTING iv_offset       TYPE zreing_ct2_opt_a-me_period_offset
                iv_period       TYPE zreing_ca_run_a-fiscal_period
                iv_year         TYPE zreing_ca_run_a-fiscal_year
      EXPORTING ev_period_month TYPE zreing_me_h_a-period_month
                ev_period_year  TYPE zreing_me_h_a-period_year.
    INTERFACES zif_reing_ca_sources.

ENDCLASS.

CLASS zcl_reing_ca_sources IMPLEMENTATION.

  METHOD zif_reing_ca_sources~get_cm_amount.
    " fixes-047 / V001 (CC) - CA-109: productive callers pass CM_H_ID.
    " Callers without an exact load ID must supply an explicit instance.
    CONSTANTS lc_cm_libd TYPE zreing_cm_h_a-cm_status VALUE 'LIBD'.
    IF iv_cm_h_id IS NOT INITIAL.
      SELECT SINGLE *
        FROM zreing_cm_h_a
        WHERE cm_h_id      = @iv_cm_h_id
          AND ct_uuid      = @iv_ct_uuid
          AND mat_uuid     = @iv_mat_uuid
          AND op_type      = @iv_op_type
          AND period_year  = @iv_year
          AND period_month = @iv_period
          AND cm_status    = @lc_cm_libd
        INTO @rs_cm.
    ELSE.
      " V001 (CC) - CA-109 (Delta v2): never select across instances.
      IF iv_op_instance_num IS INITIAL.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'CM sin CM_H_ID requiere numero de instancia'.
      ENDIF.
      SELECT *
        FROM zreing_cm_h_a
        WHERE ct_uuid      = @iv_ct_uuid
          AND mat_uuid     = @iv_mat_uuid
          AND op_type      = @iv_op_type
          AND op_instance_num = @iv_op_instance_num
          AND period_year  = @iv_year
          AND period_month = @iv_period
          AND cm_status    = @lc_cm_libd
        ORDER BY load_seq DESCENDING
        INTO TABLE @DATA(lt_cm)
        UP TO 1 ROWS.
      IF lt_cm IS NOT INITIAL.
        rs_cm = lt_cm[ 1 ].
      ENDIF.
    ENDIF.

    " V001 (CC) - CA-109: unresolved historical loads must not be consumed.
    IF rs_cm-op_instance_num IS INITIAL
       OR ( iv_op_instance_num IS NOT INITIAL
            AND rs_cm-op_instance_num <> iv_op_instance_num ).
      CLEAR rs_cm.
    ENDIF.
    IF rs_cm IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |No existe CM_H_A elegible (LIBD) para CM_H_ID { iv_cm_h_id } | &&
          |{ iv_ct_uuid }/{ iv_mat_uuid }/{ iv_op_type } { iv_period }/{ iv_year }|.
    ENDIF.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_me_shares.
    " N-5: only LIBD is eligible for a fresh calculation (LIBR was already
    " reserved by an earlier run) — centralized in
    " ZIF_REING_CA_C=>me_eligible_status so extending to LIBR later is a
    " one-line change, not a literal hunt.
    " Iteration #5 (activation ERR-001, line 58): explicit field list
    " (without MANDT, the structure's real first component) were
    " positionally misaligned against RT_ITEMS' line type
    " (ZREING_ME_I_A) — reverted to the blueprint's literal "mi~*"
    " (SS6.10, written there as "mi.*").
    " Begin Change ID V016 (17.07.2026 | EXT_GONZALCA)
    " Fix V012 (filtrar solo por MAX(load_version)) resulto INSUFICIENTE:
    " zreing_me_h_a solo tiene me_h_id como PK real -- nada a nivel de base
    " de datos impide DOS headers con el MISMO ct_id/matnr/periodo/
    " load_version/status=LIBD (la deteccion de duplicados de
    " ZBP_REINGMEHEADER/validateheader es una validacion de BDEF, no una
    " constraint de DB; datos cargados por fuera del BDEF -- ej.
    " ZCL_REING_CA_LOAD_TEST -- pueden colar un duplicado). Filtrar solo
    " por "load_version = MAX" seguia trayendo AMBOS headers si compartian
    " esa misma version, sumando shares de los dos (bug real confirmado:
    " seguia dando 101% incluso despues del fix V012). Se resuelve ahora
    " al ME_H_ID especifico, no solo a la version: entre los headers LIBD
    " se toma el de mayor load_version y, a igualdad de version, el de
    " created_at mas reciente -- y el JOIN se filtra a ESE me_h_id puntual.
    SELECT me_h_id, load_version, created_at
      FROM zreing_me_h_a
      WHERE ct_id        = @iv_ct_id
        AND matnr        = @iv_matnr
        AND period_year  = @iv_period_year
        AND period_month = @iv_period_month
        AND me_status    = @zif_reing_ca_c=>me_eligible_status-libd
      INTO TABLE @DATA(lt_hdrs).
    SORT lt_hdrs BY load_version DESCENDING created_at DESCENDING.
    READ TABLE lt_hdrs INTO DATA(ls_hdr) INDEX 1.
    IF sy-subrc = 0.
      SELECT mi~*
        FROM zreing_me_i_a AS mi
        WHERE mi~me_h_id = @ls_hdr-me_h_id
        INTO TABLE @rt_items.
    ENDIF.
    " End Change ID V016 (17.07.2026 | EXT_GONZALCA)
    IF rt_items IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |No existe metrica ME elegible (LIBD) para { iv_ct_id }/{ iv_matnr } { iv_period_month }/{ iv_period_year }|.
    ENDIF.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_ct_option.
    " Iteration #5 (activation ERR-001, line 75): explicit field list
    " (without MANDT, the structure's real first component) was
    " positionally misaligned against RS_OPT — reverted to the
    " blueprint's literal SELECT SINGLE * (SS6.10); RS_OPT's RETURNING
    " type is the full DDIC structure, so a full-row fetch is correct here.
    SELECT SINGLE *
      FROM zreing_ct2_opt_a
      WHERE op_uuid = @iv_op_uuid
      INTO @rs_opt.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_gl_tax_types.
    " CT2_GL_A has no tax_type of its own (only gl_role, plain text) — the
    " bridge to tax_type lives in GL_ROLES (TX-02).
    SELECT DISTINCT roles~tax_type
      FROM zreing_ct2_gl_a AS gl
      INNER JOIN zreing_gl_roles AS roles ON roles~gl_role = gl~gl_role
      WHERE gl~ct_uuid      = @iv_ct_uuid
        AND gl~mat_uuid     = @iv_mat_uuid
        AND roles~role_type = 'T'
      INTO TABLE @rt_tax_types.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_tx_rules.
    " 'AC' assumed as the active tx_status literal — unconfirmed against a
    " value help (P2, inherited from F1-H3). Does not filter by tax_type;
    " the Pipeline filters in memory to reuse one read across candidates.
    " Iteration #5 (activation ERR-001, line 132): explicit field list
    " (without MANDT) was positionally misaligned against RT_RULES' line
    " type (ZREING_TX_RULE_A) — reverted to the blueprint's literal
    " SELECT * (SS6.10). Keep the SELECT * when adding columns to the table.
    " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4.5 -- COUNTRY stops being a mandatory WHERE filter
    " and becomes a scoring criterion: an empty COUNTRY is a wildcard that
    " applies to every country. Without this, rules with COUNTRY empty are
    " never even read, and the specificity engine cannot express "this applies
    " regardless of the receiving country" (SS4.4).
    "
    " DELIBERATE DEVIATION from SS4.5: the spec's WHERE also pre-filters
    " country_prest / bukrs_prest / bukrs_recv with the same OR-wildcard
    " pattern, which would require four new parameters on this method and
    " therefore on ZIF_REING_CA_SOURCES and on every unit-test double that
    " implements it. Those three fields are pure candidate-set REDUCTION: the
    " authoritative discard happens in ZCL_REING_CA_TX_SCORING~find_best_rule,
    " which receives them and drops any rule whose filled field does not match.
    " The selected set is wider, the winning rule is identical, and the blast
    " radius stays inside this method. Volume makes it a non-issue (35 active
    " rules in TS4). Revisit if TX_RULE_A ever grows by orders of magnitude.
    "
    " CUTOVER WARNING (consulta A-03): from now on, a pre-existing row with
    " COUNTRY empty and TX_STATUS = 'AC' starts applying to EVERY country --
    " until today such rows were inert because of this very filter. DS4 is
    " clean (5/5 rules carry a country); TS4 and PRD must be checked before the
    " transport lands:
    "   SELECT * FROM zreing_tx_rule_a WHERE country = '' AND tx_status = 'AC'.
    " Original WHERE kept for reference:
    "    WHERE country   = @iv_country
    SELECT *
      FROM zreing_tx_rule_a
      WHERE ( country   = @iv_country OR country = '' )
        AND gross_up  = @iv_gross_up
        AND tx_status = 'AC'
      INTO TABLE @rt_rules.
    " End Mod V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_manual_exch_rate.
    SELECT SINGLE manual_exch_rate
      FROM zreing_ct_o_r_a
      WHERE ct_uuid         = @iv_ct_uuid
        AND mat_uuid        = @iv_mat_uuid
        AND op_type         = @iv_op_type
        AND op_uuid         = @iv_op_uuid
        AND op_instance_num = @iv_op_instance_num
        AND bukrs_recv      = @iv_bukrs_recv
      INTO @rv_rate.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |Sin tasa manual (ZREING_CT_O_R_A) para receptora { iv_bukrs_recv }|.
    ENDIF.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_average_exch_rate.
    " Iteration #6 (real dry-run confirmed by the Architect): the
    " Iteration #5 fix (SELECT SINGLE ... ORDER BY FROM I_ExchangeRate,
    " F2-DD-10) hit the exact same "ORDER is invalid here" grammar error
    " as M-01 (get_cm_amount) — flagged as a risk when applied, now
    " confirmed broken. On top of that, I_ExchangeRate/READ_EXCHANGE_RATE/
    " BAPI_EXCHRATE_GETCURRENTRATES are ALL blocked by Clean Core in this
    " system (4th attempt total: BAPI_EXCHRATE_GETDETAIL nonexistent ->
    " READ_EXCHANGE_RATE blocked -> I_ExchangeRate broken/blocked ->
    " CL_EXCHANGE_RATES, found by the human, 3/3 clean dry-runs).
    " LOCAL_AMOUNT (with FOREIGN_AMOUNT=1), not EXCHANGE_RATE, is the
    " normalized value — EXCHANGE_RATE is the raw rate, not yet adjusted
    " by FOREIGN_FACTOR/LOCAL_FACTOR. Date resolution logic stays in
    " step_05_fx, unchanged — only the future-period guard lives here, as
    " it always did.

    " Change ID V006 (07.09.2026 | EXT_GONZALCA): MELI request — TCURR-KURST
    " for the average FX branch. Was the literal 'M'.
    CONSTANTS lc_fx_rate_type TYPE kurst_curr VALUE 'ICRG'.

    DATA: lv_exchange_rate  TYPE ukurs_curr,
          lv_foreign_factor TYPE ffact_curr,
          lv_local_amount   TYPE p DECIMALS 5,
          lv_local_factor   TYPE tfact_curr,
          lv_fixed_rate     TYPE ukurs_curr,
          lv_derived_type   TYPE kurst_curr,
          lv_foreign_amount TYPE p DECIMALS 5 VALUE 1.

    IF iv_date > sy-datum.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |No se puede calcular FX promedio (tipo P) de un periodo futuro: { iv_date }|.
    ENDIF.

    TRY.
        cl_exchange_rates=>convert_to_local_currency(
          EXPORTING
            date              = iv_date
            foreign_amount    = lv_foreign_amount
            foreign_currency  = iv_from_currency
            local_currency    = iv_to_currency
            "rate_type         = 'M'
            rate_type         = lc_fx_rate_type   " V006: was 'M'
            do_read_tcurr     = abap_true
          IMPORTING
            exchange_rate     = lv_exchange_rate
            foreign_factor    = lv_foreign_factor
            local_amount      = lv_local_amount
            local_factor      = lv_local_factor
            fixed_rate        = lv_fixed_rate
            derived_rate_type = lv_derived_type ).
      CATCH cx_exchange_rates INTO DATA(lx_error).
        " V006: message interpolates the constant, no literal rate type
        "RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        "  EXPORTING iv_message =
        "    |Sin tasa promedio 'M' para { iv_from_currency }/{ iv_to_currency } en { iv_date }: { lx_error->get_text( ) }|.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message =
            |Sin tasa promedio '{ lc_fx_rate_type }' para { iv_from_currency }/{ iv_to_currency } en { iv_date }: { lx_error->get_text( ) }|.
    ENDTRY.

    rv_rate = lv_local_amount.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_ct_identity.
    " Amendment F2-DD-6 (blueprint SS6.10/SS9.3): same JOIN pattern
    " ZI_ReingCALineAll (F1, Lado B-1) already uses to resolve these same
    " fields for the PEND preview. BP_NAME is intentionally not part of
    " ty_ct_identity — F1 already leaves it blank (cast('' as char80)),
    " ratified here, not a new gap.
    " Begin Change ID V007 (07.09.2026 | EXT_GONZALCA)
    " CT2_A~WAERS added to the column list: the contract header currency is
    " the authoritative CT_CURRENCY source for step_validate's Path B1. It
    " rides on this existing SELECT on purpose - no new database read, and
    " nothing new inside execute()'s LOOP AT it_scope (ATC NonLocal DBREAD).
    " WAERS must be the LAST column, matching the last component of
    " ty_ct_identity (V006): the INTO @rs_identity assignment is positional.
    SELECT SINGLE ct~ct_id, ct~lifnr, ct~bukrs AS bukrs_prest, mat~matnr,
                  ct~waers
    " End Change ID V007 (07.09.2026 | EXT_GONZALCA)
      FROM zreing_ct2_a AS ct
      INNER JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid = ct~ct_uuid
      WHERE ct~ct_uuid   = @iv_ct_uuid
        AND mat~mat_uuid = @iv_mat_uuid
      INTO @rs_identity.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |Contrato/material inexistente para { iv_ct_uuid }/{ iv_mat_uuid }|.
    ENDIF.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_op_type_permite_delta.
    " Delta v2 CA-06: bridge simple para BR-CA-41 (validar PERMITE_DELTA
    " antes de redistribuir). ZREING_OP_TYPE_C.permite_delta ya activo
    " (CA-04/05 lo confirmaron contra el sistema real).
    SELECT SINGLE permite_delta
      FROM zreing_op_type_c
      WHERE op_type = @iv_op_type
      INTO @rv_permite_delta.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cont_baseline.
    " Delta v2 CA-06: LINE_As CONT del grupo base (ct_uuid+mat_uuid+
    " op_type+op_uuid), SIN discriminar delta_seq (incluye original +
    " deltas previos ya contabilizados), acotado al mismo periodo fiscal
    " via JOIN a ZREING_CA_RUN_A (LINE_A no tiene period propio).
    SELECT la~*
      FROM zreing_ca_line_a AS la
      INNER JOIN zreing_ca_run_a AS run ON run~calc_run_id = la~calc_run_id
      WHERE la~ct_uuid        = @iv_ct_uuid
        AND la~mat_uuid       = @iv_mat_uuid
        AND la~op_type        = @iv_op_type
        AND la~op_uuid        = @iv_op_uuid
        AND la~line_status    = 'CONT'
        AND run~fiscal_year   = @iv_period_year
        AND run~fiscal_period = @iv_period_month
      INTO TABLE @rt_lines.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cont_line_pc_baseline.
    " Delta v2 CA-07: baseline de LINE_PC_A agregado por las 4 dimensiones
    " (prctr+campana+role_category+allocation), para UNA receptora
    " puntual, sumando sobre todas las LINE_As CONT del grupo base en el
    " mismo periodo fiscal (mismo patron JOIN que get_cont_baseline).
    SELECT lpc~prctr, lpc~campana, lpc~role_category, lpc~allocation,
           SUM( lpc~calc_amt )      AS calc_amt,
           SUM( lpc~bruto_amt )     AS bruto_amt,
           SUM( lpc~tax_amt )       AS tax_amt,
           SUM( lpc~net_amt )       AS net_amt,
           SUM( lpc~net_local_amt ) AS net_local_amt
      FROM zreing_ca_lpc_a AS lpc
      INNER JOIN zreing_ca_line_a AS la ON la~calc_run_id = lpc~calc_run_id
                                        AND la~line_num    = lpc~line_num
      INNER JOIN zreing_ca_run_a AS run ON run~calc_run_id = la~calc_run_id
      WHERE la~ct_uuid        = @iv_ct_uuid
        AND la~mat_uuid       = @iv_mat_uuid
        AND la~op_type        = @iv_op_type
        AND la~op_uuid        = @iv_op_uuid
        AND la~bukrs_recv     = @iv_bukrs_recv
        AND la~line_status    = 'CONT'
        AND run~fiscal_year   = @iv_period_year
        AND run~fiscal_period = @iv_period_month
      GROUP BY lpc~prctr, lpc~campana, lpc~role_category, lpc~allocation
      INTO CORRESPONDING FIELDS OF TABLE @rt_pc.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cm_recv_filter.
    " fixes-047: receiver restrictions belong to one exact CM load.
    DATA(lv_cm_h_id) = iv_cm_h_id.
    IF lv_cm_h_id IS INITIAL.
      lv_cm_h_id = zif_reing_ca_sources~get_cm_amount(
        iv_ct_uuid  = iv_ct_uuid
        iv_mat_uuid = iv_mat_uuid
        iv_op_type  = iv_op_type
        iv_period   = iv_period
        iv_year     = iv_year
        iv_op_instance_num = iv_op_instance_num )-cm_h_id.
    ENDIF.

    SELECT bukrs_recv
      FROM zreing_cm_recv_a
      WHERE cm_h_id = @lv_cm_h_id
      INTO TABLE @rt_bukrs.
  ENDMETHOD.

  METHOD calc_me_period.
    " Begin Change ID V007 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : resolucion del periodo de lectura de la metrica ME a
    " partir de ME_PERIOD_OFFSET (BR-CA-40). Aritmetica PURA -- sin ninguna
    " lectura de BD -- para que pueda vivir en un solo lugar y ser llamada
    " tanto por ZCL_REING_CA_PIPELINE (que resuelve el offset con
    " get_ct_option por op_uuid) como por ZCL_REING_CA_INSUMO_MGR.
    " Deliberadamente NO se declara en ZIF_REING_CA_SOURCES: no es una
    " fuente de datos, es un calculo, y agregarla a la interfaz obligaria a
    " tocar todos los test doubles que la implementan.
    "
    " Por que existe este metodo: hasta V006 (08.09.2026) esta aritmetica
    " vivia inline y SOLO en step_pc_split, mientras step_validate,
    " step_distribute y step_delta leian ME con el periodo del run. Esa
    " duplicacion-por-omision es exactamente el bug que reporto funcional
    " (IC-0001/ICSRV44, 02/2026, offset '01'): el importe de la linea salia
    " con el share de M y la apertura con el de M-1. Con la regla en un
    " unico lugar, un cambio futuro del offset (por ejemplo admitir valores
    " > 1) no puede volver a quedar aplicado a medias.
    "
    " ME_PERIOD_OFFSET es NUMC(2) ('00' = M, '01' = M-1): conversion
    " explicita a numerico antes de la resta, sin depender de la conversion
    " implicita del tipo. Toda la aritmetica se hace en I y la conversion a
    " NUMC ocurre al final, ya con un mes valido: asignar un intermedio
    " negativo a un NUMC no tiene comportamiento definido.
    DATA(lv_month) = CONV i( iv_period ) - CONV i( iv_offset ).
    DATA(lv_year)  = CONV i( iv_year ).

    " WHILE en lugar de un solo IF: con offset '00'/'01' un unico ajuste
    " alcanza, pero asi la funcion sigue siendo correcta si el dominio
    " admitiera un offset mayor a 12 meses, sin que haya que recordar
    " volver aca.
    WHILE lv_month <= 0.
      lv_month = lv_month + 12.
      lv_year  = lv_year - 1.
    ENDWHILE.

    ev_period_month = lv_month.
    ev_period_year  = lv_year.
    " End Change ID V007 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
ENDCLASS.

