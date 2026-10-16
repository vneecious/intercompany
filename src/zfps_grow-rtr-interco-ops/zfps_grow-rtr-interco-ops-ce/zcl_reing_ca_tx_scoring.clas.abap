*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Fiscal scoring engine (BR-CA-03, blueprint SS6.9). Filters validity
* (BEGDA/ENDDA) and discards non-matching rules, scores survivors and
* returns the highest-scoring rule — an empty result is a valid business
* outcome ("this tax does not apply"), not an error. Stateless, no
* dependencies of its own — instantiated once by ZCL_REING_CA_PIPELINE
* and reused for the whole execute() run.
*
* DEVIATION vs blueprint SS6.9/SS D.1 (documented in code-summary.md):
* an exact score tie among the top candidates RAISES
* zcx_reing_ca_calc_error ("reglas ambiguas") instead of silently taking
* the first rule in reading order. normalized-spec.md's own "Reglas de
* Negocio" section states BR-CA-03 explicitly this way ("empate exacto de
* score = error bloqueante... no 'tomar la primera'"), correcting an
* older assumption that blueprint SS6.9 point 5 still echoes verbatim —
* this method follows the more recent, explicit business rule instead.
*----------------------------------------------------------------------*
* Change ID V009 (15.09.2026 | EXT_GONZALCA): specificity engine on SIX
* fields (ET-REING-BR-001 v5 SS4). Was LIFNR+4 / MATNR+2 with COUNTRY as
* a mandatory WHERE filter upstream; now COUNTRY is a scoring field too
* and BUKRS_RECV / BUKRS_PREST / COUNTRY_PREST join it, so a rule can be
* scoped to a pair of company codes. RATE = 0 is an explicit exclusion.
* Plus the intra-company discard — see the note inside the method.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_tx_scoring DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " V009: the four new criteria are OPTIONAL on purpose. Existing callers
    " (and the unit-test doubles) keep compiling unchanged, and an omitted
    " criterion behaves exactly like an empty one: a rule that FILLS that
    " field is then discarded, which is the correct reading -- if the caller
    " cannot say which receiving company code it is calculating, a rule
    " scoped to one specific receiver does not apply.
    METHODS find_best_rule
      IMPORTING it_rules          TYPE zif_reing_ca_types=>ty_tx_rule_t
                iv_lifnr          TYPE lifnr
                iv_matnr          TYPE matnr
                iv_ref_date       TYPE d
                iv_country        TYPE zreing_tx_rule_a-country       OPTIONAL
                iv_country_prest  TYPE zreing_tx_rule_a-country_prest OPTIONAL
                iv_bukrs_prest    TYPE zreing_tx_rule_a-bukrs_prest   OPTIONAL
                iv_bukrs_recv     TYPE zreing_tx_rule_a-bukrs_recv    OPTIONAL
      RETURNING VALUE(rs_rule)    TYPE zreing_tx_rule_a
      RAISING   zcx_reing_ca_calc_error.

ENDCLASS.

CLASS zcl_reing_ca_tx_scoring IMPLEMENTATION.

  METHOD find_best_rule.

    TYPES: BEGIN OF ty_scored,
             rule  TYPE zreing_tx_rule_a,
             score TYPE i,
           END OF ty_scored.
    DATA lt_scored TYPE STANDARD TABLE OF ty_scored WITH EMPTY KEY.

    " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
    " INTRA-COMPANY OPERATIONS CARRY NO TAX.
    "
    " Bug tracker #69: the MUR -> MUR line of RUN-202602 was given a 549,47 USD
    " gross-up by TX-UY-WHT-001, the generic Uruguay rule (COUNTRY = UY,
    " GROSS_UP = X, RATE = 12), because the engine never compared the providing
    " company code with the receiving one. The interdivisional document (DOCTYPE
    " INT) has no role that can receive a withholding -- its role composition is
    " GEXP / RREC / RREE -- so the amount cannot be posted, yet it still inflated
    " NET_AMT and reached the journal entry. The same criterion already governs
    " CONTAB: ZCL_REING_CONTAB_DOC_INT~is_applicable decides the interdivisional
    " document precisely by BUKRS_PREST = BUKRS_RECV (ET-CONTAB SS11.2).
    "
    " Implemented as a DISCARD, not as a guard that short-circuits the whole
    " step: for an intra-company line only rules that name BOTH company codes
    " explicitly survive. Generic/wildcard rules -- where the 12% of UY comes
    " from -- no longer reach it. The difference matters: a guard returning zero
    " unconditionally would have closed the hole but also removed the ability
    " the 6-field engine exists to provide, namely configuring a different rate
    " for one specific pair of companies. This way the case is closed
    " STRUCTURALLY (it does not depend on anybody loading an exclusion row per
    " pair, which the model cannot express generically -- there is no equality
    " operator between two fields of the line) and stays configurable if the
    " business ever asks for an exception.
    "
    " No surviving rule is already a valid outcome of this method ("does not
    " apply"), so the caller needs no new branch.
    DATA(lv_intra_company) = xsdbool(    iv_bukrs_prest IS NOT INITIAL
                                     AND iv_bukrs_prest = iv_bukrs_recv ).
    " End Insert V009 (15.09.2026 | EXT_GONZALCA)

    LOOP AT it_rules INTO DATA(ls_rule).
      " 1) validity window.
      IF iv_ref_date < ls_rule-valid_from OR iv_ref_date > ls_rule-valid_to.
        CONTINUE.
      ENDIF.
      " 2) non-match exclusion — filled and different means total exclusion,
      "    not a partial score penalty.
      IF ls_rule-lifnr IS NOT INITIAL AND ls_rule-lifnr <> iv_lifnr.
        CONTINUE.
      ENDIF.
      IF ls_rule-matnr IS NOT INITIAL AND ls_rule-matnr <> iv_matnr.
        CONTINUE.
      ENDIF.
      " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
      " Same exclusion rule for the four new criteria (SS4.3: "si un campo esta
      " LLENO en la regla y NO coincide con el valor de la LINE_A -> la regla se
      " descarta. Vacio -> wildcard"). COUNTRY is checked HERE now, not in the
      " WHERE of get_tx_rules: it stopped being a mandatory filter, so rules
      " with an empty COUNTRY do reach this point and must not be dropped.
      IF ls_rule-country IS NOT INITIAL AND ls_rule-country <> iv_country.
        CONTINUE.
      ENDIF.
      IF ls_rule-country_prest IS NOT INITIAL AND ls_rule-country_prest <> iv_country_prest.
        CONTINUE.
      ENDIF.
      IF ls_rule-bukrs_prest IS NOT INITIAL AND ls_rule-bukrs_prest <> iv_bukrs_prest.
        CONTINUE.
      ENDIF.
      IF ls_rule-bukrs_recv IS NOT INITIAL AND ls_rule-bukrs_recv <> iv_bukrs_recv.
        CONTINUE.
      ENDIF.
      " Intra-company: only rules naming BOTH company codes survive.
      IF lv_intra_company = abap_true
         AND (    ls_rule-bukrs_prest IS INITIAL
               OR ls_rule-bukrs_recv  IS INITIAL ).
        CONTINUE.
      ENDIF.
      " End Insert V009 (15.09.2026 | EXT_GONZALCA)
      " 3) score.
      " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      " Weights of ET-REING-BR-001 v5 SS4.3. Powers of two, so the winner is
      " always the rule that pins down the most specific combination -- no
      " combination of lighter fields can outweigh a heavier one.
      " Original expression kept for reference:
      "    DATA(lv_score) = COND i( WHEN ls_rule-lifnr IS NOT INITIAL THEN 4 ELSE 0 )
      "                    + COND i( WHEN ls_rule-matnr IS NOT INITIAL THEN 2 ELSE 0 ).
      DATA(lv_score) = COND i( WHEN ls_rule-bukrs_recv    IS NOT INITIAL THEN 32 ELSE 0 )
                      + COND i( WHEN ls_rule-bukrs_prest   IS NOT INITIAL THEN 16 ELSE 0 )
                      + COND i( WHEN ls_rule-lifnr         IS NOT INITIAL THEN  8 ELSE 0 )
                      + COND i( WHEN ls_rule-matnr         IS NOT INITIAL THEN  4 ELSE 0 )
                      + COND i( WHEN ls_rule-country       IS NOT INITIAL THEN  2 ELSE 0 )
                      + COND i( WHEN ls_rule-country_prest IS NOT INITIAL THEN  1 ELSE 0 ).
      " End Mod V009 (15.09.2026 | EXT_GONZALCA)
      APPEND VALUE ty_scored( rule = ls_rule score = lv_score ) TO lt_scored.
    ENDLOOP.

    IF lt_scored IS INITIAL.
      RETURN.  " no surviving rule -> valid "does not apply" outcome, not an error.
    ENDIF.

    SORT lt_scored BY score DESCENDING.
    DATA(lv_top_score) = lt_scored[ 1 ]-score.

    DATA(lv_tied) = REDUCE i( INIT n = 0
                              FOR ls_s IN lt_scored
                              NEXT n = n + COND i( WHEN ls_s-score = lv_top_score THEN 1 ELSE 0 ) ).
    IF lv_tied > 1.
      " V009: this is BR-TX-04 ("empate de score para el mismo TAX_TYPE ->
      " ERROR 'reglas ambiguas'", SS4.3). The message now names the tied rules:
      " with six fields in play, knowing the score alone is not enough to find
      " which rows collide.
      DATA(lv_tied_ids) = REDUCE string( INIT s = ``
                                         FOR ls_t IN lt_scored
                                         NEXT s = COND string(
                                                    WHEN ls_t-score = lv_top_score
                                                    THEN COND string( WHEN s IS INITIAL
                                                                      THEN CONV string( ls_t-rule-tx_rule_id )
                                                                      ELSE |{ s },{ ls_t-rule-tx_rule_id }| )
                                                    ELSE s ) ).
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |Reglas TX ambiguas: { lv_tied } reglas empatadas en score | &&
                               |{ lv_top_score } ({ lv_tied_ids }). Diferenciar el ambito | &&
                               |(pais/sociedad/proveedor/material) o desactivar una|.
    ENDIF.

    rs_rule = lt_scored[ 1 ]-rule.

  ENDMETHOD.

ENDCLASS.

