CLASS zcl_proposal_bo_ar DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           gsty_glitems TYPE LINE OF gsty_post-%param-_glitems.
    DATA: gta_je_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          gta_jr_rev  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab.

  PROTECTED     SECTION.
    METHODS:
      preparedata REDEFINITION,
      exe_bo REDEFINITION,
      mapping_bo_sec REDEFINITION,
      mapping_reverse_sec REDEFINITION.
  PRIVATE SECTION.
* Ini EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR
    TYPES:
      gsty_taxitems TYPE LINE OF gsty_post-%param-_taxitems,
      gtty_taxitems TYPE STANDARD TABLE OF gsty_taxitems WITH EMPTY KEY.

    TYPES ty_lineitem TYPE n LENGTH 6.

    METHODS:
      map_tax_items
        IMPORTING
          it_tax_out     TYPE zif_calculate_taxes_net=>_rtax1u38
          iv_waers       TYPE waers
          iv_curr_line   TYPE ty_lineitem
        EXPORTING
          et_tax_params  TYPE gtty_taxitems
          ev_tax_total   TYPE wrbtr
          ev_lines_added TYPE i.
* Fin EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR* Ini EXT_OSCUGALD 29.07.2026 - Bermudas MIC (SDFPSINIC-23362)
    METHODS mapping_bo_sec_mic.
* Fin EXT_OSCUGALD 29.07.2026 - Bermudas MIC

ENDCLASS.



CLASS ZCL_PROPOSAL_BO_AR IMPLEMENTATION.


  METHOD exe_bo.
    DATA debug TYPE abap_boolean..
    DATA status_log TYPE c.
    DATA lt_journalentry TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.

    DATA ar_parallel TYPE REF TO zcl_proposal_bo_ar_parallel.

    DATA(parallel_processor) = NEW cl_abap_parallel( ).
    parallel_processor->run_inst(
      EXPORTING
        p_in_tab  = gtd_list_bo
        p_debug   = debug
      IMPORTING
        p_out_tab = DATA(parallel_results)
    ).

    LOOP AT parallel_results REFERENCE INTO DATA(parallel_result).

      IF parallel_result->inst IS INITIAL.
        ar_parallel ?= gtd_list_bo[ parallel_result->index ].
        lt_journalentry = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                         number   = '022'
                                                         severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
            iv_doctype    = mv_posting_doctype
            it_reported   = lt_journalentry
          CHANGING
            ct_map_id_doc = ar_parallel->gt_doc_map_ar
            cv_status     = status_log
        ).

        DATA current_timestamp TYPE abp_creation_tstmpl.
        GET TIME STAMP FIELD current_timestamp.
        mapping_doc( EXPORTING
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-je_sales
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
                               iv_attime       = current_timestamp
                     CHANGING  ct_map_id_doc   = ar_parallel->gt_doc_map_ar ).

      ELSE.
        ar_parallel ?= parallel_result->inst.
      ENDIF.
      APPEND LINES OF ar_parallel->gt_doc_map_ar TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.


  METHOD mapping_bo_sec.
    TYPES ty_lineitem TYPE n LENGTH 6.
    TYPES:
      BEGIN OF ty_glitem_mapping,
        type         TYPE string,
        amount_field TYPE string,
        rate_field   TYPE string,
        base_unit    TYPE meins,
      END OF ty_glitem_mapping.

    DATA amount_in_transaction_currency TYPE f. "  we use a float so we don't lost in rounding.
    DATA total_in_transaction_currency TYPE i_journalentryitem-amountintransactioncurrency.
    DATA total_in_global_currency TYPE i_journalentryitem-amountinglobalcurrency.

    TYPES: rs_t_range_bukrs TYPE RANGE OF bukrs.

    zcl_interco_utils=>unit_code_outbound( EXPORTING im_value = '%'
                                           IMPORTING ex_value = FINAL(base_unit) ).

    " just to get a better naming
    DATA(proposal_items) = gtd_items_add.
    DATA(journal_entries) = gta_je_post.
    DATA journalentry_reported TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.

* Ini EXT_OSCUGALD 29.07.2026 - Bermudas MIC (SDFPSINIC-23362)
    " Dispatch: producto MIC (Bermudas) → asiento AR dedicado (2 lineas, importe
    " unico). El metodo MIC arma y ejecuta; aqui se exporta doc_map y se valida.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
      INTO @DATA(lv_mic_prod_found).
    IF sy-subrc = 0.
      mapping_bo_sec_mic( ).

      et_doc_map = me->gt_doc_map.

      IF gt_doc_map[] IS INITIAL OR
         line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] ) OR
         line_exists( gt_doc_map[ status = abap_false ] ) OR
         line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      ENDIF.

      RETURN.
    ENDIF.
* Fin EXT_OSCUGALD 29.07.2026 - Bermudas MIC

*Ini EXT_OSCUGALD 17.02.2026 - Genova MLA
    " Identificamos qué sociedades tienen el registro 299 (Génova)
    DATA(lt_genova_active) = VALUE rs_t_range_bukrs(
        FOR item IN proposal_items WHERE ( profitcenter = '0000000299' )
        ( sign = 'I' option = 'EQ' low = item-recipientcompanycode ) ).

    " Borramos los registros 200 redundantes
    IF lt_genova_active IS NOT INITIAL.
      DELETE proposal_items WHERE ( profitcenter = '0000000200' AND recipientcompanycode IN lt_genova_active ).
    ENDIF.
*Fin EXT_OSCUGALD 17.02.2026 - Genova MLA
    DATA(proposal_items_details) = mo_data->get_for_journalentry( CORRESPONDING #( proposal_items ) ).

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

    " Replace the original GL account and Cost Center with their target values
    " determined by business rules:
    "   - Cost Center: obtained from BRF+ determination logic
    "   - GL Account: obtained from a custom account determination class
    DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
    DATA(account_determination) = NEW zcl_interco_doc_glaccount(
      i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-ar
      i_product               = gs_header-product
      i_provider_company_code = gs_header-providercompanycode
      i_valid_at              = last_day_of_month ).

    DATA(proposal) = mo_data->get_all( ).

    SELECT DISTINCT sourcecurrency, targetcurrency, abs( i_exchangeraterawdata~exchangerate ) AS exchangerate FROM i_exchangeraterawdata
    INNER JOIN @proposal_items_details AS proposal_items_details
        ON proposal_items_details~companycodecurrency = i_exchangeraterawdata~sourcecurrency AND
           proposal_items_details~globalcurrency = i_exchangeraterawdata~targetcurrency
      WHERE exchangeratetype = 'B'
        AND validitystartdate = @last_day_of_month
      INTO TABLE @DATA(exchange_rates).

*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
    " Detectar si la propuesta es Cost Sharing leyendo products desde ZI_TVARVC
    SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_PRODUCT'
            AND type = 'S'
            AND low  = @gs_header-product
          INTO @DATA(lv_cs_prod_found).
    DATA(lv_is_cs) = xsdbool( sy-subrc = 0 ).

    DATA lv_cs_ceco_prefix TYPE c LENGTH 4.
    DATA lv_cs_cebe        TYPE c LENGTH 3.
    IF lv_is_cs = abap_true.
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
        INTO @lv_cs_ceco_prefix.
      IF sy-subrc <> 0. lv_cs_ceco_prefix = '9590'. ENDIF.

      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
        INTO @lv_cs_cebe.
      IF sy-subrc <> 0. lv_cs_cebe = '999'. ENDIF.

****Ini EXT_OSCUGALD 22.06.2026 - CS Fix AR: apertura por P&L ID real (glaccount+costcenter de base)
***      " PROBLEMA ANTERIOR: READ TABLE por tarifftype siempre retornaba la primera fila
***      " porque las 26 cuentas CS comparten tarifftype = '06'. Resultado: 690005CS en todo.
***
***      " 1. Tabla de determinacion de cuentas indexada por pandlid (= idl2).
***      SELECT pandlid, glaccount1
***        FROM zi_intercoglacctdetermination
***        WHERE product             = @gs_header-product
***          AND providercompanycode = @gs_header-providercompanycode
***          AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
***          AND isdeleted           = ''
***        INTO TABLE @DATA(lt_cs_glacct_det).

    ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

**Ini --> EXT_EMSANGEN -> COA_MIGRATION Cuenta redondeo non-MLA desde TVARVC
*    SELECT SINGLE low FROM zi_tvarvc
*      WHERE name = 'ZINTERCO_ROUNDING_ACCOUNT'
*      INTO @DATA(lv_round_acct_nonmla).
*    IF sy-subrc <> 0 OR lv_round_acct_nonmla IS INITIAL.
*      lv_round_acct_nonmla = '7301010008'.
*    ENDIF.
**Fin --> EXT_EMSANGEN -> COA_MIGRATION Cuenta redondeo non-MLA desde TVARVC
*Ini --> COA_MIGRATION: leer cuenta redondeo fuera del loop (ATC: Local Nested DB OP)
    DATA lv_round_acct_nonmla TYPE hkont.
    DATA lv_tvarvc_low        TYPE zi_tvarvc-low.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZWT_GLACCOUNT_REDONDEO'
      INTO @lv_tvarvc_low.
    IF sy-subrc = 0 AND lv_tvarvc_low IS NOT INITIAL.
      lv_round_acct_nonmla = |{ lv_tvarvc_low ALPHA = IN }|.
    ENDIF.
*Fin --> COA_MIGRATION

    LOOP AT proposal_items_details REFERENCE INTO DATA(proposal_item_detail).
      " Cost Center Determination
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via TVARVC para ICSRV30/ICSRV31
      " Para CS: CeCo = prefijo STVARV (9590) + internalcode + CeBe STVARV (999)
      " No se llama BRF+ para evitar impacto en otros países/productos
      IF lv_is_cs = abap_true.
        proposal_item_detail->costcenter =
          |{ lv_cs_ceco_prefix }{ gs_header-internalcode }{ lv_cs_cebe }|.
      ELSE.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
        FINAL(target_costcenter) = brf_helper->get_cc_code(
          iv_product      = proposal_item_detail->product
          iv_cc_origen    = proposal_item_detail->costcenterd4
          iv_departamento = proposal_item_detail->department
          iv_tipo_doc     = brf_helper->co_with_doctype-sales ).
        IF target_costcenter IS NOT INITIAL.
          DATA(target_cc_length) = strlen( target_costcenter ).
          proposal_item_detail->costcenter(target_cc_length) = target_costcenter.
          IF proposal_item_detail->profitcentereq IS NOT INITIAL.
            proposal_item_detail->costcenter+7(3) = proposal_item_detail->profitcentereq.
          ENDIF.
        ELSE.
          CLEAR proposal_item_detail->costcenter.
        ENDIF.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing
      ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
      " Account determination
*Ini EXT_OSCUGALD 23.06.2026 - CS Fix AR: glaccount resuelta en bloque expansion pandlid
      " Para CS: glaccount ya viene correcta desde el bloque expansion pandlid (abajo).
      " Solo se aplica fix currencies. glaccount e idl3 no se modifican aqui para CS.
      IF lv_is_cs = abap_true.
        IF proposal_item_detail->transactioncurrency IS INITIAL.
          proposal_item_detail->transactioncurrency = gs_header-companycodecurrency.
        ENDIF.
        IF proposal_item_detail->companycodecurrency IS INITIAL.
          proposal_item_detail->companycodecurrency = gs_header-companycodecurrency.
        ENDIF.
        IF proposal_item_detail->globalcurrency IS INITIAL.
          proposal_item_detail->globalcurrency = gs_header-globalcurrency.
        ENDIF.
      ENDIF.
*Ini EXT_OSCUGALD 07.09.2026 - Fix AR ICSRV52: account_determination usar IDL2 en vez de IDL3
      " Motivo: el maestro ZI_INTERCOGLACCTDETERMINATION para servicios con desglose
      " fino por P&L (ej. ICSRV52) esta parametrizado a nivel IDL2, no IDL3.
      " IDL3 solo funcionaba para servicios historicos via fila comodin (pandlid='').
      IF lv_is_cs = abap_false.
        DATA(gl_account) = account_determination->get(
          i_tarifftype = proposal_item_detail->tarifftype
          i_department = proposal_item_detail->department
*          i_pandlid    = proposal_item_detail->idl3
          i_pandlid    = proposal_item_detail->idl2
        ).
        proposal_item_detail->glaccount = gl_account-glaccount1.
      ENDIF.
*Fin EXT_OSCUGALD 07.09.2026 - Fix AR ICSRV52: account_determination usar IDL2 en vez de IDL3
    ENDLOOP.

****Ini EXT_OSCUGALD 23.06.2026 - CS Fix AR: apertura por P&L L2 en tiempo real (ATC clean)
***    " Para CS: calcular monto por (sociedad, glaccount) usando ratio sobre total USD
***    " de TODA la sociedad. Ratio = SUM(amount_l sociedad+cuenta) / SUM(ABS(amount_l sociedad))
***    " Monto = total_BRL_sociedad × ratio. Garantiza cierre exacto en ultima fila.
***    IF lv_is_cs = abap_true.
***
***      " 1. (recipientcompanycode, glaccount_CS, amount_l) agrupado por P&L L2
***      TYPES: BEGIN OF ty_cs_soc_pandl,
***               recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
***               glaccount1           TYPE saknr,
***               amount_l             TYPE zint_dte_fis_ksl,
***               total_item           TYPE zint_dte_fis_ksl,
***             END OF ty_cs_soc_pandl.
***
***      DATA lt_cs_soc_aux TYPE STANDARD TABLE OF ty_cs_soc_pandl WITH EMPTY KEY.
***      SELECT orgl~recipientcompanycode,
***             det~glaccount1,
***             SUM( orgl~amountinglobalcurrency ) AS amount_l
***        FROM zi_intercoproposalitemorglacct AS orgl
***        INNER JOIN zi_intercopandlhierflattened AS pand
***          ON pand~id = orgl~pandll5id
***        INNER JOIN zi_intercoglacctdetermination AS det
***          ON  det~pandlid             = pand~idl2
***          AND det~product             = @gs_header-product
***          AND det~providercompanycode = @gs_header-providercompanycode
***          AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
***          AND det~tarifftype          = '6'
***          AND det~isdeleted           = ''
***        INNER JOIN @proposal_items AS pi
***          ON pi~id = orgl~id AND pi~item_id = orgl~itemid
***        WHERE orgl~id = @gs_header-id
***        GROUP BY orgl~recipientcompanycode, det~glaccount1
***        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_soc_aux.
***
***      " 2. Colapsar multiples idl2 → misma glaccount1 por sociedad
***      DATA lt_cs_soc TYPE SORTED TABLE OF ty_cs_soc_pandl
***                     WITH NON-UNIQUE KEY recipientcompanycode.
***      SELECT recipientcompanycode, glaccount1, SUM( amount_l ) AS amount_l
***        FROM @lt_cs_soc_aux AS t
***        GROUP BY recipientcompanycode, glaccount1
***        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_soc.
***
***      " 3. Total absoluto por sociedad — SUM(ABS) evita cancelacion de signos
***      TYPES: BEGIN OF ty_cs_soc_total,
***               recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
***               total_item           TYPE zint_dte_fis_ksl,
***             END OF ty_cs_soc_total.
***      DATA lt_cs_soc_totals TYPE HASHED TABLE OF ty_cs_soc_total
***                            WITH UNIQUE KEY recipientcompanycode.
***      SELECT recipientcompanycode, SUM( abs( amount_l ) ) AS total_item
***        FROM @lt_cs_soc AS t
***        GROUP BY recipientcompanycode
***        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_soc_totals.
***
***      " 4. Total BRL por sociedad — suma de amountintransactioncurrency de todos sus items
***      TYPES: BEGIN OF ty_cs_brl_total,
***               recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
***               total_brl            TYPE zint_dte_fis_ksl,
***               total_gc             TYPE zint_dte_fis_ksl,
***               total_cc             TYPE zint_dte_fis_hsl,
***               transactioncurrency  TYPE zint_dte_fis_rkcur,
***               globalcurrency       TYPE zint_dte_fis_rkcur,
***               companycodecurrency  TYPE zint_dte_fis_hwaer,
***             END OF ty_cs_brl_total.
***      DATA lt_cs_brl_totals TYPE HASHED TABLE OF ty_cs_brl_total
***                            WITH UNIQUE KEY recipientcompanycode.
***      SELECT recipientcompanycode,
***             SUM( amountintransactioncurrency ) AS total_brl,
***             SUM( amountinglobalcurrency )      AS total_gc,
***             SUM( amountincompanycodecurrency ) AS total_cc,
***             transactioncurrency,
***             globalcurrency,
***             companycodecurrency
***        FROM @proposal_items_details AS d
***        GROUP BY recipientcompanycode, transactioncurrency,
***                 globalcurrency, companycodecurrency
***        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_brl_totals.
***
***      " 5. Enriquecer lt_cs_soc con total_item via JOIN
***      SELECT s~recipientcompanycode, s~glaccount1, s~amount_l, t~total_item
***        FROM @lt_cs_soc AS s
***        INNER JOIN @lt_cs_soc_totals AS t
***          ON t~recipientcompanycode = s~recipientcompanycode
***        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_soc.
***
***      " 6. Construir proposal_items_details expandida — 1 fila por (item, glaccount_sociedad)
***      " La glaccount y el monto vienen del ratio a nivel de SOCIEDAD, no de item.
***      " Ultima fila por sociedad absorbe residuo para garantizar balance exacto.
***      DATA lt_details_cs LIKE proposal_items_details.
***
***      " Procesar por sociedad
***      DATA lt_socs_procesadas TYPE HASHED TABLE OF ty_cs_soc_total
***                              WITH UNIQUE KEY recipientcompanycode.
***
***      LOOP AT proposal_items_details INTO DATA(ls_detail_orig).
***        DATA(lv_soc) = ls_detail_orig-recipientcompanycode.
***
***        " Solo procesar la primera fila de cada sociedad para generar los GL items
***        " Las filas adicionales del mismo item/sociedad ya no se necesitan
***        CHECK NOT line_exists( lt_socs_procesadas[ recipientcompanycode = lv_soc ] ).
***        INSERT VALUE #( recipientcompanycode = lv_soc ) INTO TABLE lt_socs_procesadas.
***
***        " Totales BRL de esta sociedad
***        TRY.
***            DATA(ls_brl) = lt_cs_brl_totals[ recipientcompanycode = lv_soc ].
***          CATCH cx_sy_itab_line_not_found.
***            CONTINUE.
***        ENDTRY.
***
***        " Filas de cuentas CS para esta sociedad
***        DATA lt_soc_cuentas TYPE STANDARD TABLE OF ty_cs_soc_pandl WITH EMPTY KEY.
***        lt_soc_cuentas = VALUE #( FOR ls_sc_f IN lt_cs_soc
***                                          WHERE ( recipientcompanycode = lv_soc )
***                                          ( ls_sc_f ) ).
***
***        DATA(lv_rows_soc)  = lines( lt_soc_cuentas ).
***        DATA(lv_row_soc)   = 0.
***        DATA(lv_sum_tc)    = CONV decfloat34( 0 ).
***        DATA(lv_sum_gc)    = CONV decfloat34( 0 ).
***        DATA(lv_sum_cc)    = CONV decfloat34( 0 ).
***
***        DO lv_rows_soc TIMES.
***          READ TABLE lt_soc_cuentas INTO DATA(ls_sc) INDEX sy-index.
***          lv_row_soc += 1.
***
***          DATA(lv_ratio_cs) = COND decfloat34(
***                      WHEN CONV decfloat34( ls_sc-total_item ) <> 0
***                      THEN CONV decfloat34( ls_sc-amount_l ) / CONV decfloat34( ls_sc-total_item )
***                      ELSE 1 ).
***
***          DATA(ls_new) = ls_detail_orig.
***          ls_new-recipientcompanycode    = lv_soc.
***          ls_new-transactioncurrency     = ls_brl-transactioncurrency.
***          ls_new-globalcurrency          = ls_brl-globalcurrency.
***          ls_new-companycodecurrency     = ls_brl-companycodecurrency.
***          ls_new-glaccount               = ls_sc-glaccount1.
***
***          IF lv_row_soc < lv_rows_soc.
***            ls_new-amountintransactioncurrency = ls_brl-total_brl * lv_ratio_cs.
***            ls_new-amountinglobalcurrency      = ls_brl-total_gc  * lv_ratio_cs.
***            ls_new-amountincompanycodecurrency = ls_brl-total_cc  * lv_ratio_cs.
***            lv_sum_tc += ls_new-amountintransactioncurrency.
***            lv_sum_gc += ls_new-amountinglobalcurrency.
***            lv_sum_cc += ls_new-amountincompanycodecurrency.
***          ELSE.
***            " Ultima cuenta: absorbe residuo → balance exacto
***            ls_new-amountintransactioncurrency = ls_brl-total_brl - lv_sum_tc.
***            ls_new-amountinglobalcurrency      = ls_brl-total_gc  - lv_sum_gc.
***            ls_new-amountincompanycodecurrency = ls_brl-total_cc  - lv_sum_cc.
***          ENDIF.
***
***          APPEND ls_new TO lt_details_cs.
***        ENDDO.
***
***      ENDLOOP.
***      proposal_items_details = lt_details_cs.
***
***    ENDIF.
****Fin EXT_OSCUGALD 23.06.2026 - CS Fix AR
****Fin EXT_OSCUGALD 23.06.2026 - CS Fix AR

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AR v2: base_BRL_L2 x sharerate (signo correcto)
    IF lv_is_cs = abap_true.

      " 1. base_BRL agrupada por glaccount1 (100%, sin filtrar por sociedad)
      TYPES: BEGIN OF ty_cs_base_l2,
               glaccount1 TYPE saknr,
               base_brl   TYPE zint_dte_fis_ksl,
             END OF ty_cs_base_l2.

      DATA lt_cs_base_l2 TYPE HASHED TABLE OF ty_cs_base_l2
                         WITH UNIQUE KEY glaccount1.

      SELECT det~glaccount1,
               SUM( bas~amountincompanycodecurrency ) AS base_brl
          FROM zi_intercobasisitem AS bas
          INNER JOIN zi_intercopandlhierflattened AS pand
            ON pand~id = bas~pandll5id
          INNER JOIN zi_intercoglacctdetermination AS det
            ON  det~pandlid             = pand~idl2
            AND det~product             = @gs_header-product
            AND det~providercompanycode = @gs_header-providercompanycode
            AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
            AND det~tarifftype          = '6'
            AND det~isdeleted           = ''
            WHERE bas~providercompanycode = @gs_header-providercompanycode
            AND bas~fiscalyear          = @gs_header-fiscalyear
            AND bas~fiscalperiod        = @gs_header-fiscalperiod
            AND bas~product             = @gs_header-product
          GROUP BY det~glaccount1
          INTO CORRESPONDING FIELDS OF TABLE @lt_cs_base_l2.

      " Validar P&L IDs con importe en base pero sin mapeo en determinacion de cuentas
      " Si existen → loguear cada uno y abortar sin generar documentos
      TYPES: BEGIN OF ty_cs_pandl_no_map,
               idl2 TYPE zi_intercopandlhierflattened-idl2,
             END OF ty_cs_pandl_no_map.
      DATA lt_cs_pandl_no_map TYPE STANDARD TABLE OF ty_cs_pandl_no_map WITH EMPTY KEY.
      SELECT DISTINCT pand~idl2
        FROM zi_intercobasisitem AS bas
        INNER JOIN zi_intercopandlhierflattened AS pand
          ON pand~id = bas~pandll5id
        WHERE bas~providercompanycode = @gs_header-providercompanycode
          AND bas~fiscalyear          = @gs_header-fiscalyear
          AND bas~fiscalperiod        = @gs_header-fiscalperiod
          AND bas~product             = @gs_header-product
          AND NOT EXISTS (
            SELECT pandlid FROM zi_intercoglacctdetermination
            WHERE pandlid             = pand~idl2
              AND product             = @gs_header-product
              AND providercompanycode = @gs_header-providercompanycode
              AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
              AND tarifftype          = '6'
              AND isdeleted           = ''
          )
        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_pandl_no_map.
      " lt_cs_pandl_no_map cargada → el error se registra en el loop de GL items abajo

      " 2. sharerate por sociedad desde proposal_items
      TYPES: BEGIN OF ty_cs_share,
               recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
               sharedrate           TYPE zi_intercoproposalitem-sharedrate,
             END OF ty_cs_share.

      DATA lt_cs_shares TYPE HASHED TABLE OF ty_cs_share
                        WITH UNIQUE KEY recipientcompanycode.

      LOOP AT proposal_items INTO DATA(ls_pi_share).
        IF ls_pi_share-sharedrate <> 0 AND
           NOT line_exists( lt_cs_shares[ recipientcompanycode = ls_pi_share-recipientcompanycode ] ).
          INSERT VALUE #(
            recipientcompanycode = ls_pi_share-recipientcompanycode
            sharedrate           = ls_pi_share-sharedrate
          ) INTO TABLE lt_cs_shares.
        ENDIF.
      ENDLOOP.

      " 3. total BRL por sociedad (para residuo en ultima cuenta)
      TYPES: BEGIN OF ty_cs_brl_soc,
               recipientcompanycode       TYPE zfi_a_intrc_cpi-recipientcompanycode,
               amountintrasactioncurrency TYPE zfi_proposalitem_add-amountintrasactioncurrency,
             END OF ty_cs_brl_soc.

      DATA lt_cs_brl_soc TYPE HASHED TABLE OF ty_cs_brl_soc
                         WITH UNIQUE KEY recipientcompanycode.

      SELECT recipientcompanycode,
             SUM( amountintrasactioncurrency ) AS amountintrasactioncurrency
        FROM @proposal_items AS pi
        GROUP BY recipientcompanycode
        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_brl_soc.

      " 4. cliente correcto por sociedad
      DATA lt_cs_customers TYPE TABLE OF zi_intercorelationship WITH EMPTY KEY.

      SELECT providercompanycode, recipientcompanycode, recipientcustomer
        FROM zi_intercorelationship
        WHERE providercompanycode = @gs_header-providercompanycode
        INTO CORRESPONDING FIELDS OF TABLE @lt_cs_customers.

      " 5. ordenar cuentas para residuo deterministico
      DATA lt_base_sorted TYPE STANDARD TABLE OF ty_cs_base_l2 WITH EMPTY KEY.
      lt_base_sorted = VALUE #( FOR ls_b IN lt_cs_base_l2 ( ls_b ) ).
      SORT lt_base_sorted BY glaccount1.
      DATA(lv_rows_cuentas) = lines( lt_base_sorted ).

      " 6. construir proposal_items_details: 1 fila por (sociedad x glaccount1)
      DATA lt_details_cs     LIKE proposal_items_details.
      DATA lt_socs_procesadas TYPE HASHED TABLE OF ty_cs_share
                              WITH UNIQUE KEY recipientcompanycode.

      LOOP AT proposal_items_details INTO DATA(ls_detail_orig).
        DATA(lv_soc) = ls_detail_orig-recipientcompanycode.
        CHECK NOT line_exists( lt_socs_procesadas[ recipientcompanycode = lv_soc ] ).
        INSERT VALUE #( recipientcompanycode = lv_soc ) INTO TABLE lt_socs_procesadas.

        TRY.
            DATA(ls_share) = lt_cs_shares[ recipientcompanycode = lv_soc ].
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.
        DATA(lv_sharerate) = CONV decfloat34( ls_share-sharedrate ) / 100.

        TRY.
            DATA(ls_brl_soc) = lt_cs_brl_soc[ recipientcompanycode = lv_soc ].
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.
        DATA(lv_total_brl_soc) = CONV decfloat34( ls_brl_soc-amountintrasactioncurrency ).

        READ TABLE lt_cs_customers INTO DATA(ls_cs_cust)
          WITH KEY recipientcompanycode = lv_soc.

        DATA(lv_sum_tc) = CONV decfloat34( 0 ).

        DO lv_rows_cuentas TIMES.
          READ TABLE lt_base_sorted INTO DATA(ls_base) INDEX sy-index.

          DATA(ls_new_cs) = ls_detail_orig.
          ls_new_cs-recipientcompanycode = lv_soc.
          ls_new_cs-glaccount            = ls_base-glaccount1.
          ls_new_cs-costcenter           = |{ lv_cs_ceco_prefix }{ gs_header-internalcode }{ lv_cs_cebe }|.

          IF ls_cs_cust-recipientcustomer IS NOT INITIAL.
            ls_new_cs-recipientcustomer = ls_cs_cust-recipientcustomer.
          ENDIF.

          DATA lv_importe TYPE decfloat34.
          IF sy-index < lv_rows_cuentas.
            " formula principal: base_BRL_L2 x sharerate
            lv_importe = ls_base-base_brl * lv_sharerate.
            lv_sum_tc += lv_importe.
          ELSE.
            " ultima cuenta: absorbe residuo para total exacto
            lv_importe = lv_total_brl_soc - lv_sum_tc.
          ENDIF.

          ls_new_cs-amountintransactioncurrency = lv_importe.
          ls_new_cs-amountinglobalcurrency      = lv_importe.
          ls_new_cs-amountincompanycodecurrency = lv_importe.

          APPEND ls_new_cs TO lt_details_cs.
        ENDDO.
      ENDLOOP.

      proposal_items_details = lt_details_cs.

    ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AR v2

    " Prepare the data to be posted as GL items in the financial documents.
    SELECT
       id,
       providercompanycode,
       product,
       recipientcompanycode,
       recipientcountry,
       recipientcustomer,
       department,
       tarifftype,
       tariffdescription,
       tariffrate,
       profitcenter,
       costcenter,
       glaccount,
       SUM( amountintransactioncurrency ) AS amountintransactioncurrency,
       transactioncurrency,
       SUM( amountinglobalcurrency ) AS amountinglobalcurrency,
       globalcurrency,
       SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
       companycodecurrency,
       exchangerate
    FROM @proposal_items_details AS proposal_items_calc_detail
    GROUP BY
      id,
      product,
      recipientcompanycode,
      recipientcountry,
      providercompanycode,
      recipientcustomer,
      department,
      tarifftype,
      tariffdescription,
      tariffrate,
      profitcenter,
      costcenter,
      glaccount,
      transactioncurrency,
      companycodecurrency,
      globalcurrency,
      exchangerate
*    HAVING SUM( amountintransactioncurrency ) <> 0  "evita registros en ceros
          INTO TABLE @DATA(recipient_glitems).

    IF recipient_glitems IS INITIAL.
      RETURN.
    ENDIF.

* LInha AR ->
*    SELECT items~recipientcompanycode,
*           SUM( items_details~amountinglobalcurrency ) AS amountinglobalcurrency,
*           SUM( items_details~amountincompanycodecurrency ) AS amountincompanycodecurreny,
*           SUM( items_details~amountinglobalcurrency ) AS amountintransactioncurrency
*      FROM zi_intercoproposalitemcalcdet AS items_details
*      INNER JOIN @proposal_items AS items ON items~id = items_details~id AND items~itembasis_id = items_details~itembasis_id AND items~item_id = items_details~item_id
*      GROUP BY recipientcompanycode, recipientcountry
*      INTO TABLE @DATA(total_by_recipients).
*
*    LOOP AT total_by_recipients REFERENCE INTO DATA(total_by_recipient).
*      DATA(proposal_item) = REF #( proposal_items[ recipientcompanycode = total_by_recipient->recipientcompanycode ] ).
*      " if same country, we have to calculate the transaction currency based on the exchange_rate
*      IF proposal_item->recipientcountry <> proposal_item->providercountry.
*        CONTINUE.
*      ENDIF.
*      total_by_recipient->amountintransactioncurrency = total_by_recipient->amountincompanycodecurreny.
*    ENDLOOP.

    SELECT recipientcompanycode,
        SUM( proposal_items~amountintrasactioncurrency +
             proposal_items~mkupamntintcurr +
             proposal_items~gupmamntintcurr +
             proposal_items~gupbamntintcurr +
             proposal_items~intmamntintcurr +
             proposal_items~guppamntintcurr ) AS amountintransactioncurrency
   FROM @proposal_items AS proposal_items
   GROUP BY recipientcompanycode
   INTO TABLE @DATA(total_by_recipients).
    " Linha AR <-

    DATA tolerance TYPE wrbtr VALUE '1.5'.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_ROUNDING_TOLERANCE'
      INTO @DATA(param_tolerance).

    IF sy-subrc = 0.
      tolerance = param_tolerance.
    ENDIF.


    " Withholding Tax
    SELECT customer,
           companycode,
           withholdingtaxtype,
           withholdingtaxcode
             FROM i_customerwithtax WITH PRIVILEGED ACCESS
             INNER JOIN @recipient_glitems AS recipient_glitems ON recipient_glitems~recipientcustomer = i_customerwithtax~customer
                    AND i_customerwithtax~companycode = recipient_glitems~providercompanycode
             INTO TABLE @DATA(customers_withtaxes).

    "  Build Journal Entries
    LOOP AT recipient_glitems REFERENCE INTO DATA(recipient_glitem)
        GROUP BY recipient_glitem->recipientcompanycode INTO FINAL(recipient_company_code).

      CLEAR: total_in_transaction_currency,
             total_in_global_currency.

      " Linha AR ->
*      DATA(total_posting_in_global_curr) = total_by_recipients[ recipientcompanycode = recipient_company_code ]-amountinglobalcurrency.
      " Linha AR <-
      DATA lv_total_posting TYPE i_journalentryitem-amountintransactioncurrency.
      IF lv_is_cs = abap_true.
        TRY.
            lv_total_posting = CONV #( lt_cs_brl_soc[ recipientcompanycode = recipient_company_code ]-amountintrasactioncurrency ).
          CATCH cx_sy_itab_line_not_found.
            lv_total_posting = total_by_recipients[ recipientcompanycode = recipient_company_code ]-amountintransactioncurrency.
        ENDTRY.
      ELSE.
        lv_total_posting = total_by_recipients[ recipientcompanycode = recipient_company_code ]-amountintransactioncurrency.
      ENDIF.
      DATA(total_posting_in_trans_curr) = lv_total_posting.
      DATA(has_error) = abap_false.
      DATA(lv_pandl_err_logged) = abap_false.
      APPEND INITIAL LINE TO journal_entries REFERENCE INTO DATA(journal_entry).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " HEADER
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      journal_entry->%cid = gs_header-providercompanycode && gs_header-product && sy-datum && sy-index.
      journal_entry->%param-accountingdocumenttype = COND #(  WHEN total_posting_in_trans_curr >= 0 THEN 'IC' ELSE 'AI' ).
      journal_entry->%param-createdbyuser = sy-uname.
      journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient_company_code } { gs_header-productname }|.
      journal_entry->%param-companycode = gs_header-providercompanycode.
      journal_entry->%param-documentreferenceid = gs_header-product.
      journal_entry->%param-documentdate = last_day_of_month.
      journal_entry->%param-postingdate = last_day_of_month.

      DATA tax_code TYPE c LENGTH 2.
      brf_helper->get_tax_code(
        EXPORTING
          iv_provider   = gs_header-providercompanycode
          iv_recipient  = recipient_company_code
          iv_product    = gs_header-product
        IMPORTING
          ev_taxcode_ar = tax_code
      ).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " GL_ITEMS
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(lineitem) = CONV ty_lineitem( 1 ).
      LOOP AT GROUP recipient_company_code REFERENCE INTO FINAL(recipient_item).
        DATA: log_status TYPE zfi_a_intrc_cpdl-msgty.
        lineitem += 1.
*        data(roposal_item) = REF #( proposal_items[ id      = recipient_item->id item_id = proposal_item_detail->item_id ] ).

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AR: para CS buscar solo por sociedad+glaccount
        IF lv_is_cs = abap_true.
          TRY.
              proposal_item_detail = REF #( proposal_items_details[ recipientcompanycode = recipient_item->recipientcompanycode glaccount = recipient_item->glaccount ] ).
            CATCH cx_sy_itab_line_not_found.
              proposal_item_detail = REF #( proposal_items_details[ recipientcompanycode = recipient_item->recipientcompanycode ] ).
          ENDTRY.
        ELSE.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AR
          proposal_item_detail = REF #( proposal_items_details[ recipientcompanycode = recipient_item->recipientcompanycode profitcenter = recipient_item->profitcenter ] ).
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AR
        ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AR
        TRY.
            DATA(exchange_rate) = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency  targetcurrency = recipient_item->globalcurrency ]-exchangerate.
          CATCH cx_sy_itab_line_not_found.
            CLEAR exchange_rate.
        ENDTRY.
        "  We have to recaculate the transaction currency for same country porque essa moeda de transacao foi calculada originalmente quando ainda estava sumarizado por profit center, e portanto, perde-se muito em arredondamentos
*        IF recipient_item->recipientcountry = gs_header-providercountry.
*          amount_in_transaction_currency = recipient_item->amountinglobalcurrency * exchange_rate.
*          recipient_item->amountintransactioncurrency = amount_in_transaction_currency.
*        ENDIF.

        " generate a dummy document key for logging purporses in case anything fails
        DATA(dummy_documentkey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }{ proposal_item_detail->recipientcompanycode }|.

        " This is required to map the exact ProposalItem so we can log it correctly

        TRY.
            DATA(document_map) = REF #( gt_doc_map[
                id           = proposal_item_detail->id
                item_id      = proposal_item_detail->item_id
                documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
                documentkey  = dummy_documentkey ] ).
          CATCH cx_sy_itab_line_not_found.
            APPEND VALUE #(
              id           = proposal_item_detail->id
              item_id      = proposal_item_detail->item_id
              itembasis_id = proposal_item_detail->itembasis_id
              itemcalc_id  = proposal_item_detail->itemcalc_id
              documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
              documentkey  = dummy_documentkey
            ) TO gt_doc_map REFERENCE INTO document_map.
        ENDTRY.

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AR: error si P&L sin mapeo en determinacion cuentas
        IF lv_is_cs = abap_true AND lt_cs_pandl_no_map IS NOT INITIAL
                                AND lv_pandl_err_logged = abap_false.
          DATA(lv_pandl_list) = REDUCE string(
            INIT s = ``
            FOR ls_no_map IN lt_cs_pandl_no_map
            NEXT s = COND #( WHEN s IS INITIAL
                             THEN ls_no_map-idl2
                             ELSE |{ s }, { ls_no_map-idl2 }| ) ).
          add_msg_to_log(
            iv_current_item = CORRESPONDING #( proposal_item_detail->* )
            iv_dockey       = dummy_documentkey
            iv_doctype      = mv_posting_doctype
            iv_message_text = |CS AR: P&L sin cuenta asignada: { lv_pandl_list } (producto { gs_header-product }).|
          ).
          document_map->status = 'E'.
          has_error = abap_true.
          lv_pandl_err_logged = abap_true.
        ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AR: error si P&L sin mapeo

        IF recipient_item->costcenter IS INITIAL.

          add_msg_to_log(
            iv_current_item = CORRESPONDING #( proposal_item_detail->* )
            iv_dockey       = dummy_documentkey
            iv_doctype = mv_posting_doctype
            iv_message_text = |{ TEXT-001 }{ proposal_item_detail->department }| ).
          has_error = abap_true.
        ENDIF.

        IF recipient_item->glaccount IS INITIAL.
          add_msg_to_log(
            iv_current_item = CORRESPONDING #( proposal_item_detail->* )
            iv_dockey       = dummy_documentkey
            iv_doctype = mv_posting_doctype
            iv_message_text = |{ TEXT-002 } { recipient_item->tariffdescription } / { proposal_item_detail->idl3 } / { recipient_item->department }| ).
          document_map->status = 'E'.
          has_error = abap_true.
        ENDIF.

**********************************************************************
***        IF sy-uname = 'EXT_OSCUGALD'. "evita registros en cero
        IF recipient_item->amountintransactioncurrency NE 0.
          APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
          gl_item->glaccount = recipient_item->glaccount.
          gl_item->glaccountlineitem = lineitem.
          gl_item->assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                           THEN 'COST SHARING'
                                                           ELSE gs_header-productname ).
          gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
          gl_item->costcenter = recipient_item->costcenter.
          gl_item->material = COND #( WHEN lv_is_cs = abap_true
                                                THEN gs_header-product
                                                ELSE recipient_item->product ).
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AR: sociedad receptora en posiciones GL
*          IF lv_is_cs = abap_true.
          gl_item->partnercompany = recipient_item->recipientcompanycode.
*          ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AR: sociedad receptora en posiciones GL
          IF recipient_item->tarifftype <> zcl_interco_doc_glaccount=>co_tariff_type-basis.
            gl_item->quantity = recipient_item->tariffrate.
            gl_item->baseunit = base_unit.
          ENDIF.
          gl_item->taxcode = tax_code.


          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount).
          gl_item_amount->currencyrole = '00'.
          gl_item_amount->currency = recipient_item->transactioncurrency.
          gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency * -1.
          gl_item_amount->exchangerate  = exchange_rate.

          " We store the sum of those amounts so we can use it in the AR structure.
          total_in_transaction_currency += gl_item_amount->journalentryitemamount.
          total_in_global_currency += gl_item_amount->journalentryitemamount.
        ENDIF.
***        ELSE.
***
*************************************************************************
***
****          APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item). "ext_oscugald
***          APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.
***          gl_item->glaccount = recipient_item->glaccount.
***          gl_item->glaccountlineitem = lineitem.
***          gl_item->assignmentreference = gs_header-productname.
***          gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
***          gl_item->costcenter = recipient_item->costcenter.
***          gl_item->material = recipient_item->product.
***          IF recipient_item->tarifftype <> zcl_interco_doc_glaccount=>co_tariff_type-basis.
***            gl_item->quantity = recipient_item->tariffrate.
***            gl_item->baseunit = base_unit.
***          ENDIF.
***          gl_item->taxcode = tax_code.
***
***
****          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount). "ext_oscugald
***          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
***          gl_item_amount->currencyrole = '00'.
***          gl_item_amount->currency = recipient_item->transactioncurrency.
***          gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency * -1.
***          gl_item_amount->exchangerate  = exchange_rate.
***
***          " We store the sum of those amounts so we can use it in the AR structure.
***          total_in_transaction_currency += gl_item_amount->journalentryitemamount.
***          total_in_global_currency += gl_item_amount->journalentryitemamount.
***
****        IF recipient_item->recipientcountry = gs_header-providercountry.
****          CLEAR gl_item_amount->exchangerate. " Exchange rate not required here since both currencies are provided manually
****
****          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
****          gl_item_amount->currencyrole = '30'.
****          gl_item_amount->currency = recipient_item->globalcurrency.
****          gl_item_amount->journalentryitemamount = recipient_item->amountinglobalcurrency * -1.
****
****          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
****          gl_item_amount->currencyrole = '40'.
****          gl_item_amount->currency = recipient_item->globalcurrency.
****          gl_item_amount->journalentryitemamount = recipient_item->amountinglobalcurrency * -1.
****
****          total_in_global_currency += gl_item_amount->journalentryitemamount.
****        ENDIF.
***        ENDIF.
      ENDLOOP.

**********************************************************************
*Ini EXT_OSCUGALD evita registros en cero
      IF journal_entry->%param-_glitems[] IS INITIAL.
        CLEAR: gt_doc_map, journal_entries, lineitem.
        CONTINUE.
      ENDIF.
*Fin
**********************************************************************
*Ini EXT_OSCUGALD - Genova: realinear total AR con suma real de GL items
      " Para sociedades con cebe 299 (Génova), CPIB solo contiene el monto _C mientras que
      " CPBG incluye también las filas _L del split por profit center.
      " Se usa la suma real de los GL items como referencia del item AR para garantizar
      " balance FI independientemente de la consistencia entre CPIB y CPBG.
*      IF sy-uname EQ 'EXT_OSCUGALD'.
*        IF lt_genova_active IS NOT INITIAL AND recipient_company_code IN lt_genova_active.
*          total_posting_in_trans_curr = total_in_transaction_currency * -1.
*        ENDIF.
*      ENDIF.
*Fin EXT_OSCUGALD - Genova: realinear total AR con suma real de GL items
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " Rounding
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(diff) = CONV wrbtr( total_in_transaction_currency + CONV fis_ksl( total_posting_in_trans_curr ) ).
      IF ( recipient_item->recipientcountry = gs_header-providercountry ).
        " Linha AR  ->
*        DATA(diff_in_global) = CONV wrbtr( total_in_global_currency + CONV fis_ksl( total_posting_in_global_curr ) ).
        DATA(diff_in_global) = COND wrbtr(
                  WHEN exchange_rate IS INITIAL OR exchange_rate = 0
                  THEN diff
                  ELSE CONV wrbtr( diff / exchange_rate ) ).
        "  Linha AR <-
      ELSE.
        diff_in_global = diff.
      ENDIF.

      IF abs( diff_in_global ) <= tolerance.

*       Mismo país: absorber diff en la última cuenta BASE con CECO (692151)
*       sin postear cuenta de redondeo 780009/780010.
*       Distinto país: comportamiento original con cuenta de redondeo.
        IF recipient_item->recipientcountry = gs_header-providercountry
          AND gs_header-providercompanycode = 'MLA'.
*         Obtener último GL item con CECO sin LOOP anidado — READ TABLE por índice descendente
          DATA(lv_last_idx) = 0.
          DATA(lv_total_glitems) = lines( journal_entry->%param-_glitems ).
          DO lv_total_glitems TIMES.
            DATA(lv_idx) = lv_total_glitems - sy-index + 1.
            IF journal_entry->%param-_glitems[ lv_idx ]-costcenter IS NOT INITIAL.
              lv_last_idx = lv_idx.
              EXIT.
            ENDIF.
          ENDDO.
          IF lv_last_idx > 0.
            ASSIGN journal_entry->%param-_glitems[ lv_last_idx ]-_currencyamount[ 1 ]
              TO FIELD-SYMBOL(<fs_amount>).
            IF sy-subrc = 0.
              <fs_amount>-journalentryitemamount += diff * -1.
            ENDIF.
          ENDIF.

        ELSE.

*Ini --> EXT_OSCUGALD Cuenta redondeo MLA
          IF gs_header-providercompanycode EQ 'MLA'.
            FINAL(last_day) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
            DATA(round_account) = NEW zcl_interco_doc_glaccount(
              i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-exchange_difference  "RE
              i_product               = gs_header-product
              i_provider_company_code = gs_header-providercompanycode
              i_valid_at              = last_day ).

            DATA(gl_round_account) = round_account->get(
              i_recipientcompanycode = gs_header-providercompanycode
              i_department = proposal_item_detail->department ).
          ENDIF.
*Fin --> EXT_OSCUGALD Cuenta redondeo MLA

          lineitem += 1.
          APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.

*Ini --> EXT_OSCUGALD Cuenta redondeo MLA
          IF gs_header-providercompanycode EQ 'MLA'.
            gl_item->glaccount = |{ gl_round_account-glaccount1 ALPHA = IN }|.
          ELSE.
*Ini --> COA_MIGRATION: usar variable pre-cargada fuera del loop
            IF lv_round_acct_nonmla IS NOT INITIAL.
              gl_item->glaccount = lv_round_acct_nonmla.
            ELSE.
              add_msg_to_log(
                iv_current_item = CORRESPONDING #( proposal_item_detail->* )
                iv_dockey       = dummy_documentkey
                iv_doctype      = mv_posting_doctype
                iv_message_type = 'E'
                iv_message_text = |Falta parametrización TVARVC: ZWT_GLACCOUNT_REDONDEO. No se puede determinar cuenta de redondeo.|
              ).
              has_error = abap_true.
              document_map->status = zcl_proposal_bo_abs=>c_document_status-error.
              CONTINUE.
            ENDIF.
*Fin --> COA_MIGRATION
*Ini --> EXT_EMSANGEN -> Quitando hardcode
*            gl_item->glaccount = '780010'. "--
*            gl_item->glaccount = lv_round_acct_nonmla. "++
*Fin --> EXT_EMSANGEN -> Quitando hardcode
          ENDIF.

          gl_item->glaccountlineitem = lineitem.
          gl_item->assignmentreference = gs_header-productname.
          gl_item->documentitemtext =  |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
*          gl_item->costcenter = |{ '9590' }{ gs_header-internalcode }{ '999' }|.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo parametrizado via ZI_TVARVC
          gl_item->costcenter = COND #(
            WHEN lv_is_cs = abap_true
            THEN |{ lv_cs_ceco_prefix }{ gs_header-internalcode }{ lv_cs_cebe }|
            ELSE |{ '9590' }{ gs_header-internalcode }{ '999' }| ).
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
          gl_item->material = recipient_item->product.

          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
          gl_item_amount->currencyrole = '00'.
          gl_item_amount->currency = recipient_item->transactioncurrency.
          gl_item_amount->journalentryitemamount = diff * -1.
          gl_item_amount->exchangerate = exchange_rate.

        ENDIF.

      ELSE.
        add_msg_to_log(
          iv_current_item = CORRESPONDING #( proposal_item_detail->* )
          iv_dockey       = dummy_documentkey
          iv_doctype = mv_posting_doctype
          iv_message_text = |Redondeo { diff_in_global CURRENCY = recipient_item->globalcurrency  } excede la tolerancia de { tolerance CURRENCY = recipient_item->globalcurrency }| ).
      ENDIF.
*      IF abs( diff_in_global ) <= tolerance.
*
**Ini --> EXT_OSCUGALD Cuenta redondeo MLA
*        IF gs_header-providercompanycode EQ 'MLA'.
*          FINAL(last_day) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
*          DATA(round_account) = NEW zcl_interco_doc_glaccount(
*            i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-exchange_difference  "RE
*            i_product               = gs_header-product
*            i_provider_company_code = gs_header-providercompanycode
*            i_valid_at              = last_day ).
*
*          DATA(gl_round_account) = round_account->get(
*            i_recipientcompanycode = gs_header-providercompanycode
*            i_department = proposal_item_detail->department ).
*        ENDIF.
**Fin --> EXT_OSCUGALD Cuenta redondeo MLA
*
*        lineitem += 1.
*        APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.
*
**Ini --> EXT_OSCUGALD Cuenta redondeo MLA
*        IF gs_header-providercompanycode EQ 'MLA'.
*          gl_item->glaccount = |{ gl_round_account-glaccount1 ALPHA = IN }|.
*        ELSE.
*          gl_item->glaccount = '780010'.
*        ENDIF.
**Fin --> EXT_OSCUGALD Cuenta redondeo MLA
*
*        gl_item->glaccountlineitem = lineitem.
*        gl_item->assignmentreference = gs_header-productname.
*        gl_item->documentitemtext =  |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
*        gl_item->costcenter = |{ '9590' }{ gs_header-internalcode }{ '999' }|.
*        gl_item->material = recipient_item->product.
*
*        APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
*        gl_item_amount->currencyrole = '00'.
*        gl_item_amount->currency = recipient_item->transactioncurrency.
*        gl_item_amount->journalentryitemamount = diff * -1.
*        gl_item_amount->exchangerate = exchange_rate.
*
**        IF recipient_item->recipientcountry = gs_header-providercountry.
**          CLEAR gl_item_amount->exchangerate. " Exchange rate not required here since both currencies are provided manually
**          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
**          gl_item_amount->currencyrole = '30'.
**          gl_item_amount->currency = recipient_item->globalcurrency.
**          gl_item_amount->journalentryitemamount = diff_in_global * -1.
**
**          APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
**          gl_item_amount->currencyrole = '40'.
**          gl_item_amount->currency = recipient_item->globalcurrency.
**          gl_item_amount->journalentryitemamount = diff_in_global * -1.
**        ENDIF.
*      ELSE.
*        add_msg_to_log(
*          iv_current_item = CORRESPONDING #( proposal_item_detail->* )
*          iv_dockey       = dummy_documentkey
*          iv_doctype = mv_posting_doctype
*          iv_message_text = |Redondeo { diff_in_global CURRENCY = recipient_item->globalcurrency  } excede la tolerancia de { tolerance CURRENCY = recipient_item->globalcurrency }| ).
*      ENDIF.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " TAX BR (GL Item)
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      IF ( gs_header-providercountry = 'BR' AND recipient_item->recipientcountry <> 'BR' ) OR
         ( gs_header-providercountry <> 'BR' AND recipient_item->recipientcountry = 'BR' ).

        TRY.
            DATA(taxbr) = NEW zcl_interco_taxbr(
              i_doctype              = zcl_interco_taxbr=>co_doctype-sales
              i_providercompanycode  = gs_header-providercompanycode
              i_recipientcompanycode = recipient_item->recipientcompanycode
              i_product              = gs_header-product
              i_department           = recipient_item->department
              i_valid_at             = last_day_of_month
            ).

            taxbr->calculate_taxes_net(
              EXPORTING
                it_glitems = VALUE #( ( gl_item->* ) )
              IMPORTING
                et_glitems = DATA(new_glitems)
                ev_total   = DATA(total_taxbr)
                et_totals = DATA(totals_taxbr)
            ).

            APPEND LINES OF new_glitems TO journal_entry->%param-_glitems.
            TRY.
                total_in_transaction_currency += totals_taxbr[ currency = recipient_item->transactioncurrency ]-amount.
              CATCH cx_sy_itab_line_not_found.
            ENDTRY.

            TRY.
                total_in_global_currency += totals_taxbr[ currency = recipient_item->globalcurrency ]-amount.
              CATCH cx_sy_itab_line_not_found.
            ENDTRY.

            lineitem += lines( new_glitems ).
          CATCH zcx_interco_taxbr.
        ENDTRY.
      ENDIF.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " TAX_ITEMS
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      IF tax_code IS NOT INITIAL.

        DATA(calc_taxes) = zcl_calculate_taxes_net_fact=>create_instance( ).
        DATA tax_items_in TYPE zif_calculate_taxes_net=>_rtax1u38.
        DATA tax_items_out TYPE zif_calculate_taxes_net=>_rtax1u38.
        DATA: tax_errors TYPE zif_calculate_taxes_net=>_bapiret2.

        tax_items_in = VALUE #(
            ( bukrs = gs_header-providercompanycode
              waers = recipient_item->globalcurrency
              wrbtr = total_in_global_currency
              mwskz = tax_code )
            ( bukrs = gs_header-providercompanycode
              waers = recipient_item->transactioncurrency
              wrbtr = total_in_transaction_currency
              mwskz = tax_code )
              ).

        TRY.
            calc_taxes->calculate_taxes_net(
              CHANGING
               error_return = tax_errors
                tax_item_in  = tax_items_in
                tax_item_out = tax_items_out
            ).
          CATCH cx_aco_application_exception.
            "  we should handle the errors
        ENDTRY.

**** FIX Some IVA codes may return multiple lines ->
****       DATA(tax_item_o) = REF #( tax_items_out[ waers = recipient_item->transactioncurrency ] ).
***        LOOP AT tax_items_out REFERENCE INTO DATA(tax_item_o)
***          WHERE waers = recipient_item->transactioncurrency.
**** FIX Some IVA codes may return multiple lines <-
***          lineitem += 1.
***          APPEND INITIAL LINE TO journal_entry->%param-_taxitems REFERENCE INTO DATA(taxitem).
***
***          taxitem->glaccountlineitem          = lineitem.
***          taxitem->taxcode                    = tax_item_o->mwskz.
***          taxitem->taxitemclassification      = tax_item_o->ktosl.
***          taxitem->conditiontype              = tax_item_o->kschl.
***          taxitem->taxjurisdiction            = tax_item_o->txjcd.
***          taxitem->taxjurisdictionlevel       = tax_item_o->txjlv.
***          taxitem->lowestleveltaxjurisdiction = tax_item_o->txjcd_deep.
***          taxitem->taxrate                    = tax_item_o->msatz.
***          taxitem->taxdeterminationdate       = tax_item_o->txdat.
***          taxitem->taxcountry                 = tax_item_o->tax_country.
***
***          APPEND INITIAL LINE TO taxitem->_currencyamount REFERENCE INTO DATA(taxitem_currencyamount).
***          taxitem_currencyamount->journalentryitemamount = tax_item_o->fwste.
***          taxitem_currencyamount->currency               = tax_item_o->waers.
***          taxitem_currencyamount->currencyrole           = '00'.
***          taxitem_currencyamount->taxbaseamount          = tax_item_o->fwbas.
***          taxitem_currencyamount->taxamount              = tax_item_o->fwste.
***          total_posting_in_trans_curr += tax_item_o->fwste * -1.
**** FIX Some IVA codes may return multiple lines ->
***        ENDLOOP.
**** FIX Some IVA codes may return multiple lines <-

* Ini EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR
        me->map_tax_items(
                  EXPORTING
                    it_tax_out     = tax_items_out
                    iv_waers       = recipient_item->transactioncurrency
                    iv_curr_line   = lineitem
                  IMPORTING
                    et_tax_params  = DATA(lt_mapped_tax)  " Recibe las líneas de impuestos listas
                    ev_tax_total   = DATA(lv_tax_sum)     " Recibe el acumulador de impuestos
                    ev_lines_added = DATA(lv_count)       " Recibe cuántas líneas se crearon
                ).

        IF lt_mapped_tax IS NOT INITIAL.
          APPEND LINES OF lt_mapped_tax TO journal_entry->%param-_taxitems.

          total_posting_in_trans_curr += lv_tax_sum.
          lineitem                    += lv_count.
        ENDIF.
* Fin EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR

*        IF recipient_item->recipientcountry = gs_header-providercountry.
*          tax_item_o = REF #( tax_items_out[ waers = recipient_item->globalcurrency ] ).
*          APPEND INITIAL LINE TO taxitem->_currencyamount REFERENCE INTO taxitem_currencyamount.
*          taxitem_currencyamount->journalentryitemamount = tax_item_o->fwste.
*          taxitem_currencyamount->currency               = recipient_item->globalcurrency.
*          taxitem_currencyamount->currencyrole           = '30'.
*          taxitem_currencyamount->taxbaseamount          = tax_item_o->fwbas.
*          taxitem_currencyamount->taxamount              = tax_item_o->fwste.
*
*          APPEND INITIAL LINE TO taxitem->_currencyamount REFERENCE INTO taxitem_currencyamount.
*          taxitem_currencyamount->journalentryitemamount = tax_item_o->fwste.
*          taxitem_currencyamount->currency               = recipient_item->globalcurrency.
*          taxitem_currencyamount->currencyrole           = '40'.
*          taxitem_currencyamount->taxbaseamount          = tax_item_o->fwbas.
*          taxitem_currencyamount->taxamount              = tax_item_o->fwste.
*          total_posting_in_global_curr += tax_item_o->fwste * -1.
*        ENDIF.

      ENDIF.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " AR_ITEMS
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      APPEND INITIAL LINE TO journal_entry->%param-_aritems REFERENCE INTO DATA(ar_item).
      ar_item->glaccountlineitem = 1.
      ar_item->customer = recipient_item->recipientcustomer.
      ar_item->assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                   THEN 'COST SHARING'
                                                   ELSE gs_header-productname ).
      ar_item->documentitemtext =  |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.

      APPEND INITIAL LINE TO ar_item->_currencyamount REFERENCE INTO DATA(ar_item_amount).
      ar_item_amount->currency = recipient_item->transactioncurrency.
      ar_item_amount->journalentryitemamount = total_posting_in_trans_curr.
      ar_item_amount->currencyrole = '00'.
      ar_item_amount->exchangerate = exchange_rate.

*      IF recipient_item->recipientcountry = gs_header-providercountry.
*        CLEAR ar_item_amount->exchangerate. " Exchange rate not required here since both currencies are provided manually
*        APPEND INITIAL LINE TO ar_item->_currencyamount REFERENCE INTO ar_item_amount.
*        ar_item_amount->currency = recipient_item->globalcurrency.
*        ar_item_amount->currencyrole = '30'.
*        ar_item_amount->journalentryitemamount = total_posting_in_global_curr.
*
*        APPEND INITIAL LINE TO ar_item->_currencyamount REFERENCE INTO ar_item_amount.
*        ar_item_amount->currency = recipient_item->globalcurrency.
*        ar_item_amount->currencyrole = '40'.
*        ar_item_amount->journalentryitemamount = total_posting_in_global_curr.
*      ENDIF.
***      CLEAR total_in_transaction_currency. "17.10.2025

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " WITHHOLDING_TAX
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*Ini EXT_OSCUGALD 08.09.2026 - DF-522: genera un indicador WHT por cada tipo del cliente (defecto ACDOCA 8013150758)
      " PROBLEMA: el acceso de fila unica customers_withtaxes[ customer = ... companycode = ... ]
      " solo tomaba el PRIMER tipo de retencion del cliente (orden no deterministico de la
      " tabla interna) y llamaba a get_wht_code (funcion BRF+ escalar: 1 tipo -> 1 codigo)
      " una sola vez. Cuando el cliente tiene mas de un tipo de retencion vigente en su
      " maestro (I_CustomerWithTax), SAP sigue generando en el documento una linea por cada
      " tipo obligatorio, pero solo una (a veces ninguna) recibia codigo/base/importe.
      "
      " FIX: iterar TODAS las filas de customers_withtaxes para el cliente + sociedad
      " proveedora y llamar get_wht_code una vez POR TIPO, generando una linea
      " _withholdingtaxitems solo para los tipos donde BRF+ SI determina codigo para el
      " material del item (comportamiento normal: BRF+ esta parametrizada por material,
      " un cliente con 2 tipos activos puede tener solo 1 tipo valido por material -> no
      " es error, no se loguea). Solo se deja log de advertencia si NINGUN tipo del cliente
      " obtuvo codigo (ahi si el documento quedaria sin retencion asignada).
      DATA(lv_wht_codes_found) = 0.

      DATA lt_customer_withtaxes_flt LIKE customers_withtaxes.
      lt_customer_withtaxes_flt = VALUE #(
        FOR wt IN customers_withtaxes
        WHERE ( customer    = recipient_item->recipientcustomer
            AND companycode = gs_header-providercompanycode )
        ( wt ) ).

      DATA(lv_wht_rows) = lines( lt_customer_withtaxes_flt ).
      DO lv_wht_rows TIMES.
        READ TABLE lt_customer_withtaxes_flt REFERENCE INTO DATA(standard_withtax_row) INDEX sy-index.

        DATA(custom_withtaxcode) = brf_helper->get_wht_code(
          iv_doctype   = brf_helper->co_with_doctype-sales
          iv_provider  = gs_header-providercompanycode
          iv_recipient = recipient_item->recipientcompanycode
          iv_product   = recipient_item->product
          iv_whttype   = standard_withtax_row->withholdingtaxtype ).

        IF custom_withtaxcode IS INITIAL.
          " Tipo del cliente sin parametrizacion BRF+ para este material: comportamiento
          " esperado (BRF+ es 1 tipo valido por material), no se postea ni se loguea.
          CONTINUE.
        ENDIF.

        lv_wht_codes_found += 1.

        APPEND INITIAL LINE TO journal_entry->%param-_withholdingtaxitems REFERENCE INTO DATA(withholding_tax_item).
        withholding_tax_item->glaccountlineitem  = ar_item->glaccountlineitem.
        withholding_tax_item->withholdingtaxcode = custom_withtaxcode.
        withholding_tax_item->withholdingtaxtype = standard_withtax_row->withholdingtaxtype.
      ENDDO.

*      IF lv_wht_codes_found = 0 AND lines( customers_withtaxes ) > 0.
*        " Ningun tipo activo del cliente tiene codigo BRF+ para este material: aqui si
*        " es una brecha real de parametrizacion, el documento quedaria sin retencion.
*        add_msg_to_log(
*          iv_current_item = CORRESPONDING #( proposal_item_detail->* )
*          iv_dockey       = dummy_documentkey
*          iv_doctype      = mv_posting_doctype
*          iv_message_type = 'W'
*          iv_message_text = |WHT: ningun tipo del cliente { recipient_item->recipientcustomer } tiene codigo BRF+ parametrizado para material { recipient_item->product }| ).
*      ENDIF.
*Fin EXT_OSCUGALD 08.09.2026 - DF-522: genera un indicador WHT por cada tipo del cliente

      gta_je_post = journal_entries.


      IF has_error = abap_true.
        DATA current_datetime TYPE zfi_a_intrc_cpid-createdat.
        CONSTANTS: c_fields TYPE i VALUE 6. "Cantidad de campos sum
        GET TIME STAMP FIELD current_datetime.

        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-je_sales
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
                               iv_attime       = current_datetime
                     CHANGING  ct_map_id_doc   = gt_doc_map ).
*Ini EXT_OSCUGALD - Validación CECO hijo BR también cuando AR falla pre-validate
        " AR ya tiene error por CECO/glaccount vacío. Creamos el parallel solo para
        " ejecutar la validación del documento hijo BR, sin repetir el validate del AR.
*        IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ) AND
        IF  gs_header-providercountry = 'BR' AND
          recipient_item->recipientcountry = 'BR'.

          DATA(je_parallel_br_only) = NEW zcl_proposal_bo_ar_parallel(
            iv_process           = gv_process
            its_doc              = gts_doc
            it_doc_map           = gt_doc_map
            it_je_post           = gta_je_post
            iv_recipient_cc      = recipient_company_code
            iv_recipient_country = recipient_item->recipientcountry
            iv_provider_country  = gs_header-providercountry
            iv_product           = gs_header-product
            iv_department        = proposal_item_detail->department
            iv_skip_ar_validate  = abap_true ).

          APPEND je_parallel_br_only TO gtd_list_bo.
        ENDIF.
*Fin EXT_OSCUGALD
      ELSE.


*        IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ).
        IF  gs_header-providercountry = 'BR' AND
          recipient_item->recipientcountry = 'BR'.
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación
          DATA(je_ar_parallel_processing) = NEW zcl_proposal_bo_ar_parallel(
            iv_process           = gv_process
            its_doc              = gts_doc
            it_doc_map           = gt_doc_map
            it_je_post           = gta_je_post
            iv_recipient_cc      = recipient_company_code
            iv_recipient_country = recipient_item->recipientcountry
            iv_provider_country  = gs_header-providercountry
            iv_product           = gs_header-product
            iv_department        = proposal_item_detail->department ).
*Fin EXT_OSCUGALD - Validación CECOs Brasil en simulación
        ELSE.
          je_ar_parallel_processing = NEW zcl_proposal_bo_ar_parallel( iv_process = gv_process
                                                                             its_doc    = gts_doc
                                                                             it_doc_map = gt_doc_map
                                                                             it_je_post = gta_je_post ).
        ENDIF.

        APPEND je_ar_parallel_processing TO gtd_list_bo.
      ENDIF.
      CLEAR: gts_doc, gt_doc_map, gta_je_post, journal_entries, lineitem.

    ENDLOOP.

    " Burocratic stuff for ZCL_PROPOSAL_TOOLS
    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( ).

    et_doc_map = me->gt_doc_map.

    IF gt_doc_map[] IS INITIAL OR
       line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] ) OR
       line_exists( gt_doc_map[ status = abap_false ] ) OR
       line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

  ENDMETHOD.


  METHOD mapping_reverse_sec.
    DATA: ld_today  TYPE d.
    ld_today = cl_abap_context_info=>get_system_date( ).

    SORT gtd_doc BY documentkey.
    DELETE ADJACENT DUPLICATES FROM gtd_doc COMPARING documentkey.


    SELECT i_journalentry~companycode, i_journalentry~fiscalyear, i_journalentry~accountingdocument, postingdate
    FROM i_journalentry
      INNER JOIN @gtd_doc AS documents ON documents~documentkey = i_journalentry~accountingdocument
        AND documents~companycode = i_journalentry~companycode
        AND documents~fiscalyear = i_journalentry~fiscalyear
    INTO TABLE @DATA(lt_posting_date).

* Ini EXT_OSCUGALD 03.08.2026 - Bermudas MIC (SDFPSINIC-23362)
    " Flag Bermudas: se evalua UNA sola vez fuera del loop (ATC: no SELECT en loop).
    " El producto es el mismo para toda la propuesta.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
      INTO @DATA(lv_is_mic_rev).
    DATA(lv_bermudas_rev) = xsdbool( sy-subrc = 0 ).
* Fin EXT_OSCUGALD 03.08.2026 - Bermudas MIC

    CHECK gtd_doc IS NOT INITIAL.
    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
* Ini EXT_OSCUGALD 03.08.2026 - Bermudas MIC (SDFPSINIC-23362)
      " Bermudas: el AR puede estar en USA (no en provider MIC). Se lee el posting
      " date con la sociedad REAL del documento y con READ seguro (evita dump).
      " El resto de escenarios mantiene la logica original intacta.
      DATA lv_posting_date TYPE i_journalentry-postingdate.
      IF lv_bermudas_rev = abap_true.
        READ TABLE lt_posting_date INTO DATA(ls_posting_date_mic)
          WITH KEY fiscalyear         = <fs_doc>-fiscalyear
                   companycode        = <fs_doc>-companycode
                   accountingdocument = <fs_doc>-documentkey.
        IF sy-subrc = 0.
          lv_posting_date = ls_posting_date_mic-postingdate.
        ELSE.
          lv_posting_date = cl_abap_context_info=>get_system_date( ).
        ENDIF.
      ELSE.
        " Logica original sin cambios (CS / resto)
        lv_posting_date = lt_posting_date[ fiscalyear = gs_header-fiscalyear companycode = gs_header-providercompanycode accountingdocument = <fs_doc>-documentkey ]-postingdate.
      ENDIF.
* Fin EXT_OSCUGALD 03.08.2026 - Bermudas MIC

      CLEAR: gta_jr_rev,gt_doc_map.

      CHECK NOT line_exists( gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ] )
      OR gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ]-documentkey(5) EQ 'DUMMY'.

      APPEND INITIAL LINE TO gta_jr_rev ASSIGNING FIELD-SYMBOL(<jr>).

* Ini EXT_OSCUGALD 03.08.2026 - Bermudas MIC (SDFPSINIC-23362)
      " Bermudas reversa en la sociedad real del doc; resto sin cambios.
      IF lv_is_mic_rev IS NOT INITIAL.
        <jr>-companycode = <fs_doc>-companycode.
      ELSE.
        <jr>-companycode = gs_header-providercompanycode.
      ENDIF.
* Fin EXT_OSCUGALD 03.08.2026 - Bermudas MIC
      <jr>-fiscalyear = gs_header-fiscalyear.
      <jr>-accountingdocument = CONV #( <fs_doc>-documentkey ).
      <jr>-%param = VALUE #(
*                            postingdate    = ld_today
                            postingdate    = lv_posting_date
                            reversalreason = '01'
                            createdbyuser  = cl_abap_context_info=>get_user_technical_name( )
                           ).
      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.
      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-documentkey }|.
      <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_je_sales.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-anul_je_sales.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_ar_parallel( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
*                                                         iv_documentkey = <fs_doc>-Documentkey
                                                         iv_parentdockey = <fs_doc>-documentkey
                                                         its_doc        = gts_doc
                                                         it_doc_map     = gt_doc_map
                                                         it_je_rev      = gta_jr_rev ).

      APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
      <fs_list_bo> = lo_exe_bo.
      FREE gt_doc_map.
*        exe_anulation_bo_sec(
*        EXPORTING
*          iv_dockey     = <fs_doc>-Documentkey
*          it_map_id_doc = gt_doc_map ).
    ENDLOOP.
    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( )."Return the data on me->gt_doc_map
    et_doc_map = me->gt_doc_map.
    IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.
  ENDMETHOD.


  METHOD preparedata.
    mv_posting_doctype = zcl_proposal_bo_abs=>c_document_type-je_sales.
    mv_reverse_doctype = c_document_type-anul_je_sales.

    DELETE gtd_items_add WHERE interdivisional = abap_true OR with_so = abap_true.
  ENDMETHOD.


  METHOD map_tax_items.
* Ini EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR
    CLEAR: et_tax_params, ev_tax_total, ev_lines_added.


    LOOP AT it_tax_out REFERENCE INTO DATA(tax_ref)
      WHERE waers = iv_waers.

      ev_lines_added += 1.

      INSERT VALUE #(
        glaccountlineitem          = iv_curr_line + ev_lines_added
        taxcode                    = tax_ref->mwskz
        taxitemclassification      = tax_ref->ktosl
        conditiontype              = tax_ref->kschl
        taxjurisdiction            = tax_ref->txjcd
        taxjurisdictionlevel       = tax_ref->txjlv
        lowestleveltaxjurisdiction = tax_ref->txjcd_deep
        taxrate                    = tax_ref->msatz
        taxdeterminationdate       = tax_ref->txdat
        taxcountry                 = tax_ref->tax_country
        _currencyamount            = VALUE #( (
            journalentryitemamount = tax_ref->fwste
            currency               = tax_ref->waers
            currencyrole           = '00'
            taxbaseamount          = tax_ref->fwbas
            taxamount              = tax_ref->fwste
        ) )
      ) INTO TABLE et_tax_params.

      ev_tax_total += ( tax_ref->fwste * -1 ).
    ENDLOOP.
* Fin EXT_OSCUGALD 10.03.2026 - Clean Core IVA Codes BR
  ENDMETHOD.


  METHOD mapping_bo_sec_mic.
*───────────────────────────────────────────────────────────────────────────
* EXT_OSCUGALD 29.07.2026 - Bermudas MIC-USA (SDFPSINIC-23362)
* Arma el asiento AR de Ventas para Bermudas. Asiento de 2 lineas:
*   - Linea GL (cuenta de ingreso, al haber → posting key 50)
*   - Item AR (cliente interco, al debe → posting key 01)
* El AR se postea en la sociedad que corresponde a la direccion de facturacion,
* y todos los datos (cliente, texto, CeCo) se derivan de ESA sociedad.
*
* Direccion dinamica (signo de la regalia):
*   lv_amount_tc > 0 → ISAC > Upper → MIC factura a USA → AR en USA
*   lv_amount_tc < 0 → ISAC < Lower → USA factura a MIC → AR en MIC
*
* Reglas de armado (validadas contra molde productivo 8020014128, AR en USA):
*   - Cliente: recipientcustomer de la relacion donde la SOCIEDAD AR es provider
*              (AR en USA → relacion USA→MIC → IC0295).
*   - Texto:   arranca con la sociedad AR (AR en USA → "USA-MIC Royalties").
*   - CeCo:    prefijo(4) + internalcode(3) + CeBe(3); el internalcode es el de
*              la sociedad AR desde zi_intercocompanycode (MIC=295 / USA=145).
*              Ej: 9591+145+271 = 9591145271 (AR en USA).
*   - Cuentas: la determinacion (ZINT_A_MD_GLACCT) va SIEMPRE con MIC como
*              provider; usar la sociedad AR (USA) daria RW602/F5507.
*   - Clase doc IC siempre (AI queda reservada para anulaciones).
*   - Posting keys via abs(): cliente al debe (01), ingreso al haber (50),
*     sin importar el signo de la regalia.
*───────────────────────────────────────────────────────────────────────────
    DATA(proposal_items)  = gtd_items_add.
    DATA(journal_entries) = gta_je_post.

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months(
      day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

    " CeCo = prefijo(4) + internalcode(3) + CeBe(3). Prefijo y CeBe desde TVARVC
    " (no hardcode). El internalcode se resuelve por sociedad mas abajo.
    DATA lv_ceco_prefix TYPE c LENGTH 4.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_CECO_PREFIX' AND type = 'P'
      INTO @lv_ceco_prefix.
    IF sy-subrc <> 0 OR lv_ceco_prefix IS INITIAL.
      lv_ceco_prefix = '9591'.
    ENDIF.

    DATA lv_ceco_cebe TYPE c LENGTH 3.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_CEBE' AND type = 'P'
      INTO @lv_ceco_cebe.
    IF sy-subrc <> 0 OR lv_ceco_cebe IS INITIAL.
      lv_ceco_cebe = '271'.
    ENDIF.

    " Claves item_id / itembasis_id / itemcalc_id del item del CeBe destino,
    " necesarias para poblar el doc_map completo → fila en Documento generado.
    " cpic tiene itemcalc_id; cpi tiene profitcenter. Se filtra por CeBe (271).
    TYPES: BEGIN OF ty_cpic_keys,
             item_id      TYPE zde_prop_item_id,
             itembasis_id TYPE zde_prop_basis_id,
             itemcalc_id  TYPE zde_prop_calc_id,
           END OF ty_cpic_keys.
    DATA ls_cpic_keys TYPE ty_cpic_keys.

    DATA lv_cebe_mic TYPE prctr.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_CEBE' AND type = 'P'
      INTO @DATA(lv_cebe_tvarvc).
    IF sy-subrc = 0 AND lv_cebe_tvarvc IS NOT INITIAL.
      lv_cebe_mic = |{ lv_cebe_tvarvc ALPHA = IN }|.
    ENDIF.

    IF lv_cebe_mic IS NOT INITIAL.
      SELECT SINGLE cpic~item_id, cpic~itembasis_id, cpic~itemcalc_id
        FROM zfi_a_intrc_cpic AS cpic
        INNER JOIN zfi_a_intrc_cpi AS cpi
          ON  cpi~id      = cpic~id
          AND cpi~item_id = cpic~item_id
        WHERE cpic~id          = @gs_header-id
          AND cpi~profitcenter = @lv_cebe_mic
        INTO @ls_cpic_keys.
    ENDIF.
    IF sy-subrc <> 0 OR ls_cpic_keys IS INITIAL.
      SELECT SINGLE item_id, itembasis_id, itemcalc_id
        FROM zfi_a_intrc_cpic
        WHERE id = @gs_header-id
        INTO @ls_cpic_keys.
    ENDIF.

    " Relaciones interco de MIC (como provider o como recipient). Cubre ambas
    " direcciones. La vista es relacion sociedad-a-sociedad (sin product).
    " Datos TS4: relacion MIC→USA cliente IC0144; relacion USA→MIC cliente IC0295.
    DATA lt_relationships TYPE TABLE OF zi_intercorelationship WITH EMPTY KEY.
    SELECT providercompanycode, recipientcompanycode, recipientcustomer
      FROM zi_intercorelationship
      WHERE ( providercompanycode  = @gs_header-providercompanycode
           OR recipientcompanycode = @gs_header-providercompanycode )
      INTO CORRESPONDING FIELDS OF TABLE @lt_relationships.

    " Internalcodes de las sociedades de la operacion — SELECT fuera del loop.
    " JOIN con zi_intercorelationship (en vez de FOR ALL ENTRIES) para cumplir
    " ATC Clean Core. Trae el internalcode de MIC y de su contraparte (USA),
    " tanto cuando aparecen como provider como cuando aparecen como recipient.
    TYPES: BEGIN OF ty_company_ic,
             companycode  TYPE bukrs,
             internalcode TYPE paval,
           END OF ty_company_ic.
    DATA lt_company_ic TYPE STANDARD TABLE OF ty_company_ic WITH DEFAULT KEY.
    SELECT DISTINCT cc~companycode, cc~internalcode
      FROM zi_intercocompanycode AS cc
      INNER JOIN zi_intercorelationship AS rel
        ON  cc~companycode = rel~providercompanycode
         OR cc~companycode = rel~recipientcompanycode
      WHERE rel~providercompanycode  = @gs_header-providercompanycode
         OR rel~recipientcompanycode = @gs_header-providercompanycode
      INTO CORRESPONDING FIELDS OF TABLE @lt_company_ic.

    " Importe unico de la regalia agrupado por sociedad receptora.
    SELECT recipientcompanycode,
           recipientcustomer,
           recipientcountry,
           SUM( amountintrasactioncurrency ) AS amountintransactioncurrency,
           transactioncurrency
      FROM @proposal_items AS pi
      GROUP BY recipientcompanycode, recipientcustomer, recipientcountry,
               transactioncurrency
      INTO TABLE @DATA(totals_mic).

    IF totals_mic IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT totals_mic REFERENCE INTO DATA(total_mic).

      DATA(lv_amount_tc) = total_mic->amountintransactioncurrency.
      IF lv_amount_tc = 0.
        CONTINUE.
      ENDIF.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " DIRECCION DINAMICA — sociedad donde postea el AR
      "   lv_amount_tc > 0 → MIC factura a USA → AR en USA
      "   lv_amount_tc < 0 → USA factura a MIC → AR en MIC
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(lv_ar_companycode) = COND bukrs(
        WHEN lv_amount_tc > 0
        THEN total_mic->recipientcompanycode    " AR en USA
        ELSE gs_header-providercompanycode ).   " AR en MIC

      " Contraparte = la otra sociedad de la operacion (para cliente y texto).
      DATA(lv_ar_counterparty) = COND bukrs(
        WHEN lv_ar_companycode = gs_header-providercompanycode
        THEN total_mic->recipientcompanycode      " AR en MIC → contraparte USA
        ELSE gs_header-providercompanycode ).      " AR en USA → contraparte MIC

      " Cliente del AR: recipientcustomer de la relacion donde la SOCIEDAD AR
      " es provider. Molde productivo 8020014128: AR en USA → IC0295 (USA→MIC).
      DATA lv_ar_customer TYPE kunnr.
      READ TABLE lt_relationships INTO DATA(ls_rel)
        WITH KEY providercompanycode  = lv_ar_companycode
                 recipientcompanycode = lv_ar_counterparty.
      IF sy-subrc = 0.
        lv_ar_customer = ls_rel-recipientcustomer.
      ELSE.
        " Fallback: cliente que viene en los items de la propuesta.
        lv_ar_customer = total_mic->recipientcustomer.
      ENDIF.

      " CeCo dinamico: prefijo + internalcode(sociedad AR) + CeBe.
      READ TABLE lt_company_ic INTO DATA(ls_company_ic)
        WITH KEY companycode = lv_ar_companycode.
      DATA lv_ceco_mic TYPE kostl.
      IF sy-subrc = 0 AND ls_company_ic-internalcode IS NOT INITIAL.
        lv_ceco_mic = |{ lv_ceco_prefix }{ ls_company_ic-internalcode }{ lv_ceco_cebe }|.
      ELSE.
        add_msg_to_log(
          iv_current_item = VALUE #( )
          iv_dockey       = |DUMMY{ lv_ar_companycode }{ gs_header-product }|
          iv_doctype      = mv_posting_doctype
          iv_message_type = 'E'
          iv_message_text = |No se encontro internalcode para sociedad { lv_ar_companycode } en zi_intercocompanycode.| ).
        CONTINUE.
      ENDIF.

      " Determinacion de cuentas: SIEMPRE con MIC como provider.
      " ZINT_A_MD_GLACCT solo tiene configuradas las cuentas con MIC; usar la
      " sociedad AR (USA) devolveria cuenta vacia (RW602) o fuera de plan (F5507).
      DATA(account_determination) = NEW zcl_interco_doc_glaccount(
        i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-ar
        i_product               = gs_header-product
        i_provider_company_code = gs_header-providercompanycode
        i_valid_at              = last_day_of_month ).

      APPEND INITIAL LINE TO journal_entries REFERENCE INTO DATA(journal_entry).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " HEADER — clase IC siempre; sociedad = sociedad AR dinamica
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      journal_entry->%cid = lv_ar_companycode && gs_header-product && sy-datum && sy-tabix.
      journal_entry->%param-accountingdocumenttype       = 'IC'.
      journal_entry->%param-createdbyuser                = sy-uname.
      journal_entry->%param-accountingdocumentheadertext = 'Royalties'.
      journal_entry->%param-companycode                  = lv_ar_companycode.
      journal_entry->%param-documentreferenceid          = gs_header-product.
      journal_entry->%param-documentdate                 = last_day_of_month.
      journal_entry->%param-postingdate                  = last_day_of_month.

      " Texto: arranca con la sociedad AR, luego la contraparte.
      " Molde productivo: AR en USA → "USA-MIC Royalties".
      DATA(lv_doctext) = |{ lv_ar_companycode }-{ lv_ar_counterparty } Royalties { gs_header-fiscalperiod }.{ gs_header-fiscalyear }|.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " GL ITEM — cuenta de ingreso, al haber (negativo → posting key 50)
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(gl_account) = account_determination->get(
        i_tarifftype = zcl_interco_doc_glaccount=>co_tariff_type-basis
        i_department = space
        i_pandlid    = space ).

      APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
      gl_item->glaccount           = gl_account-glaccount1.
      gl_item->glaccountlineitem   = 2.
      gl_item->assignmentreference = 'REGALIAS'.
      gl_item->documentitemtext    = lv_doctext.
*Ini EXT_OSCUGALD 08.09.2026 - DF-535: CEBE faltante en linea GL del asiento IC/IR
*   Asignar profitcenter explicito (lv_cebe_mic, ya calculado en este metodo)
*   en vez de depender de derivacion indirecta via Centro de Costo, que no
*   propaga de forma confiable en TS4 (patron ya validado en RECL_COMP).
      gl_item->profitcenter = lv_cebe_mic.
*Fin EXT_OSCUGALD 08.09.2026 - DF-535: CEBE faltante en linea GL del asiento IC/IR
*Ini EXT_OSCUGALD 08.09.2026 - DF-534: cuentas prefijo "4" no llevan Centro de Costo
*   Validar el prefijo de la cuenta antes de asignar costcenter (confirmado
*   negocio: cuentas de resultado, prefijo "4", no deben llevar CeCo).
      IF gl_item->glaccount(1) <> '4'.
        gl_item->costcenter = lv_ceco_mic.
      ENDIF.
*Fin EXT_OSCUGALD 08.09.2026 - DF-534: cuentas prefijo "4" no llevan Centro de Costo
      gl_item->material            = gs_header-product.

      APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_amount).
      gl_amount->currencyrole            = '00'.
      gl_amount->currency                = total_mic->transactioncurrency.
      " abs()*-1 → siempre al haber (posting key 50), sin importar el signo.
      gl_amount->journalentryitemamount  = abs( lv_amount_tc ) * -1.
      gl_amount->exchangerate            = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " AR ITEM — cliente interco, al debe (positivo → posting key 01)
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      APPEND INITIAL LINE TO journal_entry->%param-_aritems REFERENCE INTO DATA(ar_item).
      ar_item->glaccountlineitem   = 1.
      ar_item->customer            = lv_ar_customer.
      ar_item->assignmentreference = 'REGALIAS'.
      ar_item->documentitemtext    = lv_doctext.

      APPEND INITIAL LINE TO ar_item->_currencyamount REFERENCE INTO DATA(ar_amount).
      ar_amount->currencyrole           = '00'.
      ar_amount->currency               = total_mic->transactioncurrency.
      " abs() → siempre al debe (posting key 01), igual que molde 8020014128.
      ar_amount->journalentryitemamount = abs( lv_amount_tc ).
      ar_amount->exchangerate           = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " DOC_MAP — claves completas para materializar la fila en Documento generado
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(dummy_dockey) = |DUMMY{ lv_ar_companycode }{ gs_header-product }{ gs_header-fiscalperiod }|.
      APPEND VALUE #(
        id           = gs_header-id
        item_id      = ls_cpic_keys-item_id
        itembasis_id = ls_cpic_keys-itembasis_id
        itemcalc_id  = ls_cpic_keys-itemcalc_id
        documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
        documentkey  = dummy_dockey
      ) TO gt_doc_map.

      gta_je_post = journal_entries.

      DATA(je_mic_parallel) = NEW zcl_proposal_bo_ar_parallel(
        iv_process = gv_process
        its_doc    = gts_doc
        it_doc_map = gt_doc_map
        it_je_post = gta_je_post ).
      APPEND je_mic_parallel TO gtd_list_bo.

      CLEAR: gts_doc, gt_doc_map, gta_je_post, journal_entries.
    ENDLOOP.

    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( ).
  ENDMETHOD.
ENDCLASS.
