*"* use this source file for your ABAP unit test classes
*----------------------------------------------------------------------*
* Change ID V009 (15.09.2026 | EXT_GONZALCA)
* Unit coverage for the 6-field specificity engine (ET-REING-BR-001 v5
* SS4) and for the intra-company discard that closes bug tracker #69.
*
* These tests live here and not in ZCL_REING_CA_PIPELINE on purpose:
* find_best_rule is stateless and touches no database, so the scoring
* rules can be pinned down with plain in-memory tables -- no CDS test
* environment, no test doubles, no fixture setup. The pipeline's own
* test class covers the propagation of the criteria end to end.
*----------------------------------------------------------------------*
CLASS ltcl_tx_scoring DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS lc_ref_date TYPE d     VALUE '20260630'.
    CONSTANTS lc_from     TYPE begda VALUE '20260101'.
    CONSTANTS lc_to       TYPE endda VALUE '20261231'.
    CONSTANTS lc_lifnr    TYPE lifnr VALUE '0000005000'.
    CONSTANTS lc_matnr    TYPE matnr VALUE 'MAT001'.

    DATA mo_cut TYPE REF TO zcl_reing_ca_tx_scoring.

    METHODS setup.

    " Scoring and discard rules of SS4.3.
    METHODS most_specific_rule_wins      FOR TESTING RAISING cx_static_check.
    METHODS filled_mismatch_discards     FOR TESTING RAISING cx_static_check.
    METHODS empty_field_is_a_wildcard    FOR TESTING RAISING cx_static_check.
    METHODS out_of_validity_discards     FOR TESTING RAISING cx_static_check.
    METHODS rate_zero_is_an_exclusion    FOR TESTING RAISING cx_static_check.
    METHODS score_tie_raises_br_tx_04    FOR TESTING.

    " Bug #69 -- intra-company operations carry no tax.
    METHODS intra_company_drops_wildcard FOR TESTING RAISING cx_static_check.
    METHODS intra_company_keeps_specific FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_tx_scoring IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_reing_ca_tx_scoring( ).
  ENDMETHOD.

  METHOD most_specific_rule_wins.
    " Three applicable rules; the one pinning down the receiving company code
    " (+32) must beat the supplier one (+8) and the bare country one (+2),
    " regardless of reading order.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_COUNTRY' country = 'AR' rate = '10.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_RECV'    country = 'AR' bukrs_recv = '2000' rate = '30.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_LIFNR'   country = 'AR' lifnr = lc_lifnr rate = '20.000000'
        valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'AR'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '2000' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_winner-tx_rule_id exp = 'R_RECV'
      msg = 'BUKRS_RECV (+32) debe ganarle a LIFNR (+8) y a COUNTRY (+2)' ).
  ENDMETHOD.

  METHOD filled_mismatch_discards.
    " A filled field that does not match is a TOTAL exclusion, not a lighter
    " score: the rule for receiver 9999 must not win for receiver 2000 even
    " though its score would be the highest.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_OTHER_RECV' country = 'AR' bukrs_recv = '9999' rate = '30.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_COUNTRY'    country = 'AR' rate = '10.000000'
        valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'AR'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '2000' ).

    cl_abap_unit_assert=>assert_equals( act = ls_winner-tx_rule_id exp = 'R_COUNTRY' ).
  ENDMETHOD.

  METHOD empty_field_is_a_wildcard.
    " A rule with every criterion empty applies to anything and scores 0.
    " This is what keeps pre-V009 rows working (SS4.8, backward compatibility)
    " and what makes a COUNTRY-less rule reachable at all.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_WILDCARD' rate = '15.000000'
        valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'BR'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '2000' ).

    cl_abap_unit_assert=>assert_equals( act = ls_winner-tx_rule_id exp = 'R_WILDCARD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_winner-rate       exp = '15.000000' ).
  ENDMETHOD.

  METHOD out_of_validity_discards.
    " Expired rule -> no surviving rule -> empty result, which is a valid
    " business outcome ("this tax does not apply"), never an exception.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_EXPIRED' country = 'AR' rate = '10.000000'
        valid_from = '20260101' valid_to = '20260131' ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'AR'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '2000' ).

    cl_abap_unit_assert=>assert_initial( act = ls_winner ).
  ENDMETHOD.

  METHOD rate_zero_is_an_exclusion.
    " SS4.3: "RATE = 0 es valido: exclusion explicita. No genera error."
    " The pair-specific rule at 0% must win over the generic 12%, and must be
    " returned as a rule -- not swallowed as "no rule found", which would let
    " the generic one apply. This is the configuration shape that excludes a
    " tax for one pair of company codes.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_GENERIC'   country = 'UY' rate = '12.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_EXCLUSION' country = 'UY' bukrs_prest = '1000' bukrs_recv = '2000'
        rate = '0.000000' valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'UY'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '2000' ).

    cl_abap_unit_assert=>assert_equals( act = ls_winner-tx_rule_id exp = 'R_EXCLUSION' ).
    cl_abap_unit_assert=>assert_equals( act = ls_winner-rate       exp = '0.000000' ).
  ENDMETHOD.

  METHOD score_tie_raises_br_tx_04.
    " BR-TX-04: an exact tie is a blocking error, never "take the first one".
    " Both rules score +2 (country only), so neither is more specific.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_TIE_A' country = 'AR' rate = '10.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_TIE_B' country = 'AR' rate = '20.000000'
        valid_from = lc_from valid_to = lc_to ) ).

    TRY.
        mo_cut->find_best_rule( it_rules       = lt_rules
                                iv_lifnr       = lc_lifnr
                                iv_matnr       = lc_matnr
                                iv_ref_date    = lc_ref_date
                                iv_country     = 'AR'
                                iv_bukrs_prest = '1000'
                                iv_bukrs_recv  = '2000' ).
        cl_abap_unit_assert=>fail( msg = 'Un empate de score debe levantar excepcion (BR-TX-04)' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lo_err).
        " The message has to name the tied rules: with six fields in play the
        " score alone does not identify the offending rows.
        cl_abap_unit_assert=>assert_char_cp(
          act = lo_err->mv_message exp = '*R_TIE_A*' ).
        cl_abap_unit_assert=>assert_char_cp(
          act = lo_err->mv_message exp = '*R_TIE_B*' ).
    ENDTRY.
  ENDMETHOD.

  METHOD intra_company_drops_wildcard.
    " Bug #69, the regression that matters. Line MUR -> MUR (same company code
    " on both sides) against the generic Uruguay rule that gave it a 12%
    " gross-up of 549,47 USD. Generic rules no longer reach an intra-company
    " line, so the result is empty and the caller leaves gross-up at zero.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'TX-UY-WHT-001' country = 'UY' tax_type = 'WHT' gross_up = 'X'
        rate = '12.000000' valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'UY'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '1000' ).

    cl_abap_unit_assert=>assert_initial(
      act = ls_winner
      msg = 'Una linea intra-sociedad no debe tomar una regla wildcard (#69)' ).
  ENDMETHOD.

  METHOD intra_company_keeps_specific.
    " The flip side: the discard must not remove the ability the 6-field
    " engine exists to provide. A rule naming BOTH company codes explicitly
    " still applies to an intra-company line, so the business can configure an
    " exception instead of being hard-coded out of it.
    DATA(lt_rules) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
      ( tx_rule_id = 'R_GENERIC'  country = 'UY' rate = '12.000000'
        valid_from = lc_from valid_to = lc_to )
      ( tx_rule_id = 'R_INTRA'    country = 'UY' bukrs_prest = '1000' bukrs_recv = '1000'
        rate = '5.000000' valid_from = lc_from valid_to = lc_to ) ).

    DATA(ls_winner) = mo_cut->find_best_rule(
                        it_rules       = lt_rules
                        iv_lifnr       = lc_lifnr
                        iv_matnr       = lc_matnr
                        iv_ref_date    = lc_ref_date
                        iv_country     = 'UY'
                        iv_bukrs_prest = '1000'
                        iv_bukrs_recv  = '1000' ).

    cl_abap_unit_assert=>assert_equals( act = ls_winner-tx_rule_id exp = 'R_INTRA' ).
    cl_abap_unit_assert=>assert_equals( act = ls_winner-rate       exp = '5.000000' ).
  ENDMETHOD.

ENDCLASS.
