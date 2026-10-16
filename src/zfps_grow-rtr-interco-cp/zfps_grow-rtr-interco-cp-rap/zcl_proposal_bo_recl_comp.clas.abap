CLASS zcl_proposal_bo_recl_comp DEFINITION
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
  PROTECTED SECTION.
    METHODS:
      preparedata REDEFINITION,
      exe_bo REDEFINITION,
      mapping_bo_sec REDEFINITION,
      mapping_reverse_sec REDEFINITION.
  PRIVATE SECTION.
* Ini EXT_OSCUGALD 01.08.2026 - Bermudas MIC (SDFPSINIC-23362)
    METHODS mapping_bo_sec_mic.
* Fin EXT_OSCUGALD 01.08.2026 - Bermudas MIC
ENDCLASS.



CLASS zcl_proposal_bo_recl_comp IMPLEMENTATION.


  METHOD preparedata.
    DELETE gtd_items_add WHERE interdivisional = abap_true OR with_incomerec = abap_true.
  ENDMETHOD.


  METHOD mapping_bo_sec.
    DATA: lt_glitems         TYPE gsty_post-%param-_glitems,
          lv_differentiation TYPE zi_transactiontypestdglacct-glacctdetndifferentiation,
          lv_position_num    TYPE int4.
    DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
    DATA lv_product              TYPE zfi_proposalitem_add-product.
    DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
    DATA lv_jecid TYPE n LENGTH 5.
    DATA: lv_profitcenter_i TYPE i,

          lv_profitcenter_c TYPE c LENGTH 10.

    FIELD-SYMBOLS <tariff_type> TYPE zint_tariff_type.
    TYPES:
      BEGIN OF ty_glitem_mapping,
        type         TYPE string,
        amount_field TYPE string,
        tariff_type  TYPE string,
      END OF ty_glitem_mapping,
      tt_glitem_mapping TYPE TABLE OF ty_glitem_mapping WITH KEY type.
    TRY.
        DATA(ld_lastday) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

* Ini EXT_OSCUGALD 01.08.2026 - Bermudas MIC (SDFPSINIC-23362)
        " Dispatch: producto MIC (Bermudas) → reclasificacion RR dedicada.
        " Solo se genera si hubo AR (preparedata ya filtro los items con doc).
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
          INTO @DATA(lv_mic_prod_found_rr).
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
* Fin EXT_OSCUGALD 01.08.2026 - Bermudas MIC

        SORT gtd_items_add BY providercompanycode product recipientcompanycode.

        DATA(gl_item_mappings) = VALUE tt_glitem_mapping(
                 ( type = 'BASE'           amount_field = 'AMOUNTINTRASACTIONCURRENCY' tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-BASIS' )
                 ( type = 'MARKUP'         amount_field = 'MARKUPAMOUNT'               tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-MARKUP' )
                 ( type = 'GROSSUP MARGIN' amount_field = 'GROSSINGUPMARGINAMOUNT'     tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_MARGIN' )
                 ( type = 'GROSSUP BASE'   amount_field = 'GROSSINGUPBASEAMOUNT'       tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_BASIS' )
        ).
        DATA(account_determination) = NEW zcl_interco_doc_glaccount( i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
                                                                     i_product               = gs_header-product
                                                                     i_provider_company_code = gs_header-providercompanycode
                                                                     i_valid_at              = ld_lastday
                                                                     ).
        DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
        CHECK gtd_items_add IS NOT INITIAL.
        FINAL(proposal_items) = gtd_items_add.
**********************************************************************
* Third version
**********************************************************************
        "gtd_items_add only contains position without documents generated
        "to avoid generate duplicate documents

*Ini EXT_OSCUGALD 18.02.2026 - Genova MLA
        READ TABLE proposal_items INTO DATA(ls_proposal_items) WITH KEY profitcenter = '0000000299'.
        IF sy-subrc EQ 0.
          SELECT FROM zi_proposalitemcalcdet_mla AS proposal_items_calc_detail
        INNER JOIN @proposal_items AS proposal_item
          ON proposal_item~id = proposal_items_calc_detail~id AND
             proposal_item~item_id = proposal_items_calc_detail~item_id AND
             proposal_item~b_amountinglobalcurrency NE 0  "
      FIELDS DISTINCT
         proposal_items_calc_detail~id,
         proposal_items_calc_detail~product,
         proposal_items_calc_detail~item_id,
         tarifftype,
         tariffdescription,
         tariffrate,
         glaccount,
         glaccount AS glaccount2,
         costcenter,
         costcenterd4,
         department,
         \_proposalitem-recipientcompanycode,
         \_proposalitem-recipientcountry,
         \_proposalitem-profitcentereq,
         \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
         \_proposalitem-globalcurrency,
         \_proposalitem-profitcenter,
         \_pandlflat-idl3,
         \_pandlflat-idl2,
                CASE WHEN \_proposalitem-recipientcountry = @gs_header-providercountry
                  THEN proposal_items_calc_detail~amountincompanycodecurrency
                  ELSE proposal_items_calc_detail~amountinglobalcurrency
                END AS amountintransactioncurrency,
                CASE WHEN \_proposalitem-recipientcountry = @gs_header-providercountry
                  THEN proposal_items_calc_detail~companycodecurrency
                  ELSE proposal_items_calc_detail~globalcurrency
                END AS transactioncurrency,
*       \_proposalitem\_Relationship-RecipientCustomer,
         \_proposalitem-exchangerate
      WHERE proposal_items_calc_detail~id = @gs_header-id AND tariffrate > 0
*    ORDER BY proposal_items_calc_detail~product, recipientcompanycode, tarifftype
      INTO TABLE @DATA(proposal_items_details).
        ELSE.
*Fin EXT_OSCUGALD 18.02.2026 - Genova MLA
          SELECT FROM zi_intercoproposalitemcalcdet AS proposal_items_calc_detail
        INNER JOIN @proposal_items AS proposal_item
          ON proposal_item~id = proposal_items_calc_detail~id AND
             proposal_item~item_id = proposal_items_calc_detail~item_id
      FIELDS DISTINCT
         proposal_items_calc_detail~id,
         proposal_items_calc_detail~product,
         proposal_items_calc_detail~item_id,
         tarifftype,
         tariffdescription,
         tariffrate,
         glaccount,
         glaccount AS glaccount2,
         costcenter,
         costcenterd4,
         department,
         \_proposalitem-recipientcompanycode,
         \_proposalitem-recipientcountry,
         \_proposalitem-profitcentereq,
         \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
         \_proposalitem-globalcurrency,
         \_proposalitem-profitcenter,
         \_pandlflat-idl3,
         \_pandlflat-idl2,
                CASE WHEN \_proposalitem-recipientcountry = @gs_header-providercountry
                  THEN proposal_items_calc_detail~amountincompanycodecurrency
                  ELSE proposal_items_calc_detail~amountinglobalcurrency
                END AS amountintransactioncurrency,
                CASE WHEN \_proposalitem-recipientcountry = @gs_header-providercountry
                  THEN proposal_items_calc_detail~companycodecurrency
                  ELSE proposal_items_calc_detail~globalcurrency
                END AS transactioncurrency,
*       \_proposalitem\_Relationship-RecipientCustomer,
         \_proposalitem-exchangerate
      WHERE proposal_items_calc_detail~id = @gs_header-id AND tariffrate > 0
*    ORDER BY proposal_items_calc_detail~product, recipientcompanycode, tarifftype
      INTO TABLE @proposal_items_details.
        ENDIF.

        SELECT DISTINCT sourcecurrency, targetcurrency, abs( i_exchangeraterawdata~exchangerate ) AS exchangerate FROM i_exchangeraterawdata
        INNER JOIN @proposal_items_details AS proposal_items_details ON proposal_items_details~companycodecurrency = i_exchangeraterawdata~sourcecurrency AND proposal_items_details~globalcurrency = i_exchangeraterawdata~targetcurrency
          WHERE exchangeratetype = 'B'
            AND validitystartdate = @ld_lastday
          INTO TABLE @DATA(exchange_rates).

*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
        " Detectar si la propuesta es Cost Sharing leyendo products desde ZI_TVARVC
        SELECT SINGLE low FROM zi_tvarvc
                  WHERE name = 'ZINTERCO_CS_PRODUCT'
                    AND type = 'S'
                    AND low  = @gs_header-product
                  INTO @DATA(lv_cs_prod_found).
        DATA(lv_is_cs) = xsdbool( sy-subrc = 0 ).
*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL COMP: CeCo en glaccount2 tambien para Brasil (REVERTIDO)
        " Motivo original (07.09.2026): glaccount2 normalmente es cuenta de ingreso, no
        " requiere CeCo (funciona hoy en MX, MLA, etc.). Cost Sharing (MLB) y los productos
        " que lo reemplazan en el proceso normal (ej. ICSRV52, sociedades EBA/IFB/MPB/SOC)
        " son siempre Brasil -> glaccount2 puede ser CO-relevante ahi -> requiere CeCo o
        " falla con KI235.
*        DATA(lv_needs_ceco_glacc2) = xsdbool( gs_header-providercountry = 'BR' ).
* Se revierte (09.09.2026): el criterio por pais resulto demasiado amplio y rompio
* ICSRV53 (glaccount2 = cuenta de ingreso, categoria CO '11', no necesita CeCo) con
* KI261. Reemplazado por un chequeo dinamico POR CUENTA contra el maestro CO real
* (ver Ini EXT_OSCUGALD 09.09.2026 mas abajo, en el loop de recipient items).
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL COMP: CeCo en glaccount2 tambien para Brasil (REVERTIDO)

*Ini EXT_OSCUGALD 09.09.2026 - Fix RECL COMP ICSRV53: resolver KOKRS UNA vez, fuera del loop
* Motivo: ZCL_INTERCO_COSTELEM_READER->is_ceco_relevant() necesita el area de CO de
* gs_header-providercompanycode. Como ese CompanyCode es siempre el mismo dentro de
* esta ejecucion, se resuelve aca UNA sola vez (mismo patron que lt_cs_pandlids_rc
* mas abajo: "SELECT fuera del LOOP para evitar NonLocal Nested Reading DB OP").
* TKA02 esta clasificada 'notToBeReleased' (Clean Core) -> se usa su sucesor
* liberado I_CompanyCode (nivel A).
        SELECT SINGLE controllingarea
          FROM i_companycode
          WHERE companycode = @gs_header-providercompanycode
          INTO @DATA(lv_ceco_kokrs).
        IF sy-subrc <> 0.
          CLEAR lv_ceco_kokrs.
        ENDIF.
*Fin EXT_OSCUGALD 09.09.2026 - Fix RECL COMP ICSRV53: resolver KOKRS UNA vez, fuera del loop

        DATA lv_cs_ceco_prefix TYPE c LENGTH 4.
        DATA lv_cs_cebe        TYPE c LENGTH 3.
        IF lv_is_cs = abap_true.
          SELECT SINGLE low
            FROM zi_tvarvc
            WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
            INTO @lv_cs_ceco_prefix.
          IF sy-subrc <> 0. lv_cs_ceco_prefix = '9590'. ENDIF.

          SELECT SINGLE low
            FROM zi_tvarvc
            WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
            INTO @lv_cs_cebe.
          IF sy-subrc <> 0. lv_cs_cebe = '999'. ENDIF.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: internalcodes de receptoras para CeCo del doc CH
          " El doc CH postea en la soc. receptora => CeCo usa internalcode de ESA sociedad
          " Produccion: EBA->9590112999, IFB->9590210999, MPB->9590130999, SOC->9590219999
          " WHERE sitecode filtra solo las sociedades del mismo pais/sitio del provider
          SELECT companycode, internalcode
            FROM zi_intercocompanycode
            WHERE sitecode = @gs_header-providercompanycode
            INTO TABLE @DATA(lt_cs_companies).
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
*Ini EXT_OSCUGALD 27.05.2026 - Cost Sharing: pre-cargar pandlids fuera del loop (ATC clean)
          " SELECT fuera del LOOP para evitar NonLocal Nested Reading DB OP
          SELECT tarifftype, pandlid
            FROM zi_intercoglacctdetermination
            WHERE product             = @gs_header-product
              AND providercompanycode = @gs_header-providercompanycode
              AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
              AND isdeleted           = ''
            INTO TABLE @DATA(lt_cs_pandlids_rc).
*Fin EXT_OSCUGALD 27.05.2026 - Cost Sharing
        ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

        LOOP AT proposal_items_details REFERENCE INTO DATA(proposal_item_detail).
          " Cost Center Determination
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
          " Para CS: CeCo = prefijo TVARVC (9590) + internalcode + CeBe TVARVC (999)
          " No llama BRF+ para no impactar otros paises/productos
          IF lv_is_cs = abap_true.
*Ini EXT_OSCUGALD 23.06.2026 - CS Fix RECL COMP: CeCo usa internalcode del PROVEEDOR (MLB)
            " ANTES: CeCo usaba internalcode de la receptora → falla en MLB (doc ahora en MLB).
            " FIX: CeCo usa gs_header-internalcode (proveedor MLB = 9590123999).
            proposal_item_detail->costcenter =
              |{ lv_cs_ceco_prefix }{ gs_header-internalcode }{ lv_cs_cebe }|.
*Fin EXT_OSCUGALD 23.06.2026 - CS Fix RECL COMP
          ELSE.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
            FINAL(target_costcenter) = brf_helper->get_cc_code(
              iv_product      = proposal_item_detail->product
              iv_cc_origen    = proposal_item_detail->costcenterd4 " fourth digit of the origin cost center
              iv_departamento = proposal_item_detail->department
              iv_tipo_doc     = brf_helper->co_with_doctype-inc_reclassif ).
*              iv_tipo_doc     = brf_helper->co_with_doctype-purchase ).

            IF target_costcenter IS NOT INITIAL.
              lv_profitcenter_i = proposal_item_detail->ProfitCenter.
              lv_profitcenter_c = lv_profitcenter_i.
              CONDENSE lv_profitcenter_c.
              proposal_item_detail->costcenter(4) = target_costcenter.
              proposal_item_detail->costcenter+7(3) = lv_profitcenter_c.
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
          IF lv_is_cs = abap_true.
            READ TABLE lt_cs_pandlids_rc INTO DATA(ls_cs_pandlid_rc)
              WITH KEY tarifftype = proposal_item_detail->tarifftype.
            IF sy-subrc = 0 AND ls_cs_pandlid_rc-pandlid IS NOT INITIAL.
              proposal_item_detail->idl3 = ls_cs_pandlid_rc-pandlid.
            ENDIF.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: fix currencies vacias por JOIN faltante en CalcDet
            " Produccion confirma: moneda doc RECL = BRL (companycodecurrency del provider).
            IF proposal_item_detail->transactioncurrency IS INITIAL.
              proposal_item_detail->transactioncurrency = gs_header-companycodecurrency.
            ENDIF.
            IF proposal_item_detail->companycodecurrency IS INITIAL.
              proposal_item_detail->companycodecurrency = gs_header-companycodecurrency.
            ENDIF.
            IF proposal_item_detail->globalcurrency IS INITIAL.
              proposal_item_detail->globalcurrency = gs_header-globalcurrency.
            ENDIF.
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
          ENDIF.

          IF gs_header-providercountry = proposal_item_detail->recipientcountry.
            DATA(lv_optype) = zcl_interco_doc_glaccount=>co_operation_type-local.
          ELSE.
            lv_optype = zcl_interco_doc_glaccount=>co_operation_type-foreign.
          ENDIF.

*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL COMP ICSRV52: account_determination usar IDL2 en vez de IDL3
          " Motivo: mismo problema que en ZCL_PROPOSAL_BO_AR/AP (ver fix 07.09.2026 en esas clases).
          " El maestro ZI_INTERCOGLACCTDETERMINATION para servicios con desglose fino por
          " P&L (ej. ICSRV52) esta parametrizado a nivel IDL2, no IDL3.
          DATA(gl_account) = account_determination->get(
            i_tarifftype    = proposal_item_detail->tarifftype
            i_department    = proposal_item_detail->department
            i_pandlid       = proposal_item_detail->idl2
*            i_pandlid       = proposal_item_detail->idl3
            i_operationtype = lv_optype
          ).
          proposal_item_detail->glaccount = gl_account-glaccount1.
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL COMP ICSRV52: account_determination usar IDL2 en vez de IDL3
          proposal_item_detail->glaccount2 = gl_account-glaccount2.
        ENDLOOP.

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP v2: base_BRL_L2 x sharerate (espejo AR v2)
        IF lv_is_cs = abap_true.

          " 1. base_BRL agrupada por (glaccount1, glaccount2) sin filtrar por sociedad
          TYPES: BEGIN OF ty_cs_rc_base_l2,
                   glaccount1 TYPE saknr,
                   glaccount2 TYPE saknr,
                   base_brl   TYPE zint_dte_fis_ksl,
                 END OF ty_cs_rc_base_l2.

          DATA lt_cs_rc_base_l2 TYPE HASHED TABLE OF ty_cs_rc_base_l2
                                 WITH UNIQUE KEY glaccount1 glaccount2.

          SELECT det~glaccount1,
                 det~glaccount2,
                 SUM( bas~amountincompanycodecurrency ) AS base_brl
            FROM zi_intercobasisitem AS bas
            INNER JOIN zi_intercopandlhierflattened AS pand
              ON pand~id = bas~pandll5id
            INNER JOIN zi_intercoglacctdetermination AS det
              ON  det~pandlid             = pand~idl2
              AND det~product             = @gs_header-product
              AND det~providercompanycode = @gs_header-providercompanycode
              AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
              AND det~tarifftype          = '6'
              AND det~isdeleted           = ''
            WHERE bas~providercompanycode = @gs_header-providercompanycode
              AND bas~fiscalyear          = @gs_header-fiscalyear
              AND bas~fiscalperiod        = @gs_header-fiscalperiod
              AND bas~product             = @gs_header-product
            GROUP BY det~glaccount1, det~glaccount2
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rc_base_l2.

          " Validar P&L IDs con importe en base pero sin mapeo en determinacion de cuentas
          TYPES: BEGIN OF ty_cs_rc_pandl_no_map,
                   idl2 TYPE zi_intercopandlhierflattened-idl2,
                 END OF ty_cs_rc_pandl_no_map.
          DATA lt_cs_rc_pandl_no_map TYPE STANDARD TABLE OF ty_cs_rc_pandl_no_map WITH EMPTY KEY.

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
                  AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
                  AND tarifftype          = '6'
                  AND isdeleted           = ''
              )
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rc_pandl_no_map.
          " lt_cs_rc_pandl_no_map cargada → el error se registra en el loop de recipients abajo

          " 2. sharerate por sociedad desde proposal_items
          TYPES: BEGIN OF ty_cs_rc_share,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                   sharedrate           TYPE zi_intercoproposalitem-sharedrate,
                 END OF ty_cs_rc_share.

          DATA lt_cs_rc_shares TYPE HASHED TABLE OF ty_cs_rc_share
                               WITH UNIQUE KEY recipientcompanycode.

          LOOP AT proposal_items INTO DATA(ls_pi_rc_share).
            IF ls_pi_rc_share-sharedrate <> 0 AND
               NOT line_exists( lt_cs_rc_shares[ recipientcompanycode = ls_pi_rc_share-recipientcompanycode ] ).
              INSERT VALUE #(
                recipientcompanycode = ls_pi_rc_share-recipientcompanycode
                sharedrate           = ls_pi_rc_share-sharedrate
              ) INTO TABLE lt_cs_rc_shares.
            ENDIF.
          ENDLOOP.

          " 3. ordenar cuentas para residuo deterministico
          DATA lt_rc_base_sorted TYPE STANDARD TABLE OF ty_cs_rc_base_l2 WITH EMPTY KEY.
          lt_rc_base_sorted = VALUE #( FOR ls_b IN lt_cs_rc_base_l2 ( ls_b ) ).
          SORT lt_rc_base_sorted BY glaccount1.
          DATA(lv_rc_rows_cuentas) = lines( lt_rc_base_sorted ).

          " 4. total BRL por sociedad desde proposal_items_details
          TYPES: BEGIN OF ty_cs_rc_brl_soc,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                   total_brl            TYPE zint_dte_fis_ksl,
                   transactioncurrency  TYPE zint_dte_fis_hwaer,
                   exchangerate         TYPE zint_dte_ukurs,
                   companycodecurrency  TYPE waers,
                   globalcurrency       TYPE waers,
                 END OF ty_cs_rc_brl_soc.

          DATA lt_cs_rc_brl_soc TYPE HASHED TABLE OF ty_cs_rc_brl_soc
                                WITH UNIQUE KEY recipientcompanycode.

          SELECT recipientcompanycode,
                 SUM( amountintransactioncurrency ) AS total_brl,
                 transactioncurrency,
                 exchangerate,
                 companycodecurrency,
                 globalcurrency
            FROM @proposal_items_details AS t
            GROUP BY recipientcompanycode, transactioncurrency, exchangerate,
                     companycodecurrency, globalcurrency
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rc_brl_soc.

          " 5. expandir proposal_items_details: 1 fila/sociedad → N filas/cuenta_CS
          DATA lt_pid_cs_rc LIKE proposal_items_details.

          TYPES: BEGIN OF ty_cs_rc_procesadas,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                 END OF ty_cs_rc_procesadas.
          DATA lt_cs_rc_socs_proc TYPE HASHED TABLE OF ty_cs_rc_procesadas
                                  WITH UNIQUE KEY recipientcompanycode.

          LOOP AT proposal_items_details REFERENCE INTO DATA(pid_orig_rc).
            DATA(lv_soc_rc) = pid_orig_rc->recipientcompanycode.
            CHECK NOT line_exists( lt_cs_rc_socs_proc[ recipientcompanycode = lv_soc_rc ] ).
            INSERT VALUE #( recipientcompanycode = lv_soc_rc ) INTO TABLE lt_cs_rc_socs_proc.

            TRY.
                DATA(ls_share_rc) = lt_cs_rc_shares[ recipientcompanycode = lv_soc_rc ].
              CATCH cx_sy_itab_line_not_found.
                CONTINUE.
            ENDTRY.
            DATA(lv_sharerate_rc) = CONV decfloat34( ls_share_rc-sharedrate ) / 100.

            TRY.
                DATA(ls_brl_rc) = lt_cs_rc_brl_soc[ recipientcompanycode = lv_soc_rc ].
              CATCH cx_sy_itab_line_not_found.
                CONTINUE.
            ENDTRY.
            DATA(lv_total_brl_rc) = CONV decfloat34( ls_brl_rc-total_brl ).

            DATA(lv_sum_rc) = CONV decfloat34( 0 ).

            DO lv_rc_rows_cuentas TIMES.
              READ TABLE lt_rc_base_sorted INTO DATA(ls_base_rc) INDEX sy-index.

              DATA(ls_pid_new_rc) = pid_orig_rc->*.
              ls_pid_new_rc-glaccount           = ls_base_rc-glaccount1.
              ls_pid_new_rc-glaccount2          = ls_base_rc-glaccount2.
              ls_pid_new_rc-transactioncurrency = ls_brl_rc-transactioncurrency.
              ls_pid_new_rc-exchangerate        = ls_brl_rc-exchangerate.
              ls_pid_new_rc-companycodecurrency = ls_brl_rc-companycodecurrency.
              ls_pid_new_rc-globalcurrency      = ls_brl_rc-globalcurrency.

              DATA lv_importe_rc TYPE decfloat34.
              IF sy-index < lv_rc_rows_cuentas.
                lv_importe_rc = ls_base_rc-base_brl * lv_sharerate_rc.
                lv_sum_rc += lv_importe_rc.
              ELSE.
                lv_importe_rc = lv_total_brl_rc - lv_sum_rc.
              ENDIF.

              ls_pid_new_rc-amountintransactioncurrency = lv_importe_rc.
              APPEND ls_pid_new_rc TO lt_pid_cs_rc.
            ENDDO.
          ENDLOOP.
          proposal_items_details = lt_pid_cs_rc.

        ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP v2

        " Prepare the data to be posted as GL items in the financial documents.
        SELECT
           id,
           product,
           recipientcompanycode,
           recipientcountry,
*           recipientcustomer,
           profitcenter,
           profitcentereq,
           tarifftype,
           tariffdescription,
           tariffrate,
           costcenter,
           glaccount,
           glaccount2,
           SUM( amountintransactioncurrency ) AS amountintransactioncurrency,
           transactioncurrency,
           exchangerate,
      companycodecurrency,
      globalcurrency
        FROM @proposal_items_details AS proposal_items_calc_detail
        GROUP BY
          id,
          product,
          recipientcompanycode,
          recipientcountry,
*          recipientcustomer,
          profitcenter,
          profitcentereq,
          tarifftype,
          tariffdescription,
          tariffrate,
          costcenter,
          glaccount,
           glaccount2,
          transactioncurrency,
          exchangerate,
      companycodecurrency,
      globalcurrency
        INTO TABLE @DATA(recipient_glitems).

        IF recipient_glitems IS INITIAL.
          RETURN.
        ENDIF.

        DATA lv_rc_err_datetime TYPE zfi_a_intrc_cpid-createdat.

        " Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C20f: precargar BLART de reclasificación
        DATA(lo_blart_rc) = NEW zcl_interco_doc_blart(
          i_valid_at              = ld_lastday
          i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
          i_provider_company_code = gs_header-providercompanycode ).
        " Fin EXT_OSCUGALD 14.10.2026 - C20f

        LOOP AT recipient_glitems REFERENCE INTO FINAL(item_recla_ar)
            GROUP BY item_recla_ar->recipientcompanycode INTO FINAL(recipient_company_code).

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP: error si P&L sin mapeo (una vez por sociedad)
          IF lv_is_cs = abap_true AND lt_cs_rc_pandl_no_map IS NOT INITIAL.
            DATA(lv_rc_pandl_list) = REDUCE string(
              INIT s = ``
              FOR ls_no_map IN lt_cs_rc_pandl_no_map
              NEXT s = COND #( WHEN s IS INITIAL
                               THEN ls_no_map-idl2
                               ELSE |{ s }, { ls_no_map-idl2 }| ) ).
            DATA(lv_rc_err_dockey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }{ recipient_company_code }|.
            DATA(lv_rc_err_detail) = VALUE #( proposal_items_details[ recipientcompanycode = recipient_company_code ] OPTIONAL ).
            APPEND VALUE #(
              id           = lv_rc_err_detail-id
              item_id      = lv_rc_err_detail-item_id
              documenttype = zcl_proposal_bo_abs=>c_document_type-incomereclassif
              documentkey  = lv_rc_err_dockey
            ) TO gt_doc_map.
            add_msg_to_log(
              iv_current_item = CORRESPONDING #( lv_rc_err_detail )
              iv_dockey       = lv_rc_err_dockey
              iv_doctype      = mv_posting_doctype
              iv_message_text = |CS RECL COMP: P&L sin cuenta asignada: { lv_rc_pandl_list } (producto { gs_header-product }).|
            ).
            GET TIME STAMP FIELD lv_rc_err_datetime.
            mapping_doc(
              EXPORTING
                iv_doctype      = zcl_proposal_bo_abs=>c_document_type-incomereclassif
                iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                iv_isadjustment = space
                its_doc         = gts_doc
                iv_byuser       = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
                iv_attime       = lv_rc_err_datetime
              CHANGING
                ct_map_id_doc   = gt_doc_map ).
            CLEAR: gt_doc_map, gta_je_post.
            CONTINUE.
          ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP: error si P&L sin mapeo

          APPEND INITIAL LINE TO gta_je_post REFERENCE INTO DATA(journal_entry).
          """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          " HEADER
          """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          journal_entry->%cid = |{ zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar }{ sy-datum }{ sy-tabix }|.
*Ini EXT_OSCUGALD 23.06.2026 - CS Fix RECL COMP: doc se postea en soc. proveedora (MLB)
          " ANTES: para CS usaba recipient_company_code → doc se grababa en DAB/EBA/etc.
          " FIX: para CS usar providercompanycode = MLB (igual que no-CS).
          journal_entry->%param-companycode = gs_header-providercompanycode.
*Fin EXT_OSCUGALD 23.06.2026 - CS Fix RECL COMP
          journal_entry->%param-documentdate = ld_lastday.
          journal_entry->%param-postingdate = ld_lastday.
          " Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C20f: resolver BLART por receptora
***          journal_entry->%param-accountingdocumenttype = 'CH'.

          DATA(lv_amount_rc) = REDUCE fis_wsl(
            INIT total = CONV fis_wsl( 0 )
            FOR item_rc IN GROUP recipient_company_code
            NEXT total = total + item_rc-amountintransactioncurrency ).

          DATA(lv_blart_rc) = lo_blart_rc->get(
            i_recipientcompanycode = recipient_company_code
            i_paymenttype          = gs_header-paymenttype
            i_amount               = lv_amount_rc ).

          journal_entry->%param-accountingdocumenttype = COND #(
            WHEN lv_blart_rc IS NOT INITIAL THEN lv_blart_rc
            ELSE 'CH' ).
          " Fin EXT_OSCUGALD 14.10.2026 - C20f
          journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient_company_code } { gs_header-productname }|.
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP: codigo material en referencia cabecera
          IF lv_is_cs = abap_true.
            journal_entry->%param-documentreferenceid = gs_header-product.
          ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL COMP: codigo material en referencia cabecera
          journal_entry->%param-createdbyuser = cl_abap_context_info=>get_user_technical_name( ).
          IF lv_is_cs = abap_true.
            journal_entry->%param-ledgergroup = 'L2L3'.
          ELSE.
            journal_entry->%param-ledgergroup = '0LL1'.
          ENDIF.

          CLEAR lv_position_num.
          LOOP AT GROUP recipient_company_code REFERENCE INTO FINAL(recipient_item).
            CHECK recipient_item->amountintransactioncurrency IS NOT INITIAL.

            APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
            lv_position_num += 1.
            gl_item->glaccount = recipient_item->glaccount2.
            gl_item->glaccountlineitem = lv_position_num.
            gl_item->partnercompany = recipient_item->recipientcompanycode.
            gl_item->assignmentreference = COND #(
                                      WHEN lv_is_cs = abap_true THEN 'COST SHARING'
                                      ELSE gs_header-productname ).
            gl_item->documentitemtext = |{ gs_header-ProviderCompanyCode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
            gl_item->material = gs_header-product.
            gl_item->profitcenter = recipient_item->profitcenter.
            IF recipient_item->profitcentereq IS NOT INITIAL.
*              DATA(lv_profitcenter) = |{ recipient_item->profitcentereq WIDTH = 10 PAD = '0' }|.
*              gl_item->profitcenter = lv_profitcenter.
              gl_item->profitcenter = recipient_item->profitcentereq.
            ENDIF.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: glaccount2 tambien requiere CeCo en soc. receptora
*Ini EXT_OSCUGALD 09.09.2026 - Fix RECL COMP ICSRV53: CeCo en glaccount2 via CO real, no por pais
            " Motivo: el fix del 07.09.2026 (providercountry = 'BR') era demasiado amplio y
            " rompio ICSRV53 (glaccount2 = cuenta de ingreso normal, categoria CO '11', NO
            " necesita CeCo) con KI261. El criterio correcto es la categoria de cost element
            " de la cuenta PUNTUAL (glaccount2) en el area de CO de la sociedad proveedora:
            " categoria '01' (costes primarios) => requiere CeCo; cualquier otra (ej. '11'
            " ingresos) => no requiere. Ver ZCL_INTERCO_COSTELEM_READER (wrapper sobre
            " BAPI_COSTELEM_GETLIST, unica via liberada para este dato; I_CostElement/CSKB
            " estan bloqueadas por Clean Core - ver analisis 09.09.2026). KOKRS resuelto
            " una sola vez antes de este loop (lv_ceco_kokrs) para no repetir el SELECT
            " por item (ver Ini EXT_OSCUGALD 09.09.2026 mas arriba).
*            IF lv_is_cs = abap_true OR lv_needs_ceco_glacc2 = abap_true.
            IF lv_is_cs = abap_true
            OR zcl_interco_costelem_reader=>get_instance( )->is_ceco_relevant(
                 iv_kokrs = lv_ceco_kokrs
                 iv_saknr = recipient_item->glaccount2 ) = abap_true.
              gl_item->costcenter = recipient_item->costcenter.
            ENDIF.
*Fin EXT_OSCUGALD 09.09.2026 - Fix RECL COMP ICSRV53: CeCo en glaccount2 via CO real, no por pais
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
*            READ TABLE proposal_items INTO DATA(ls_proposal_items) WITH KEY id      = recipient_item->id
*                                                                            item_id = proposal_item_detail->item_id
*                                                                            product = gs_header-Product.

            APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount).
            gl_item_amount->currency = recipient_item->transactioncurrency.
*            gl_item_amount->currency = ls_proposal_items-transactioncurrency.
            gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency * -1.
            gl_item_amount->currencyrole = '00'.
            IF exchange_rates[] IS NOT INITIAL.
              DATA(exchange_rate) = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency
                                                    targetcurrency = recipient_item->globalcurrency ]-exchangerate.
            ENDIF.
            gl_item_amount->exchangerate = exchange_rate.

            APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.
            lv_position_num += 1.
            gl_item->glaccount = recipient_item->glaccount.
            gl_item->glaccountlineitem = lv_position_num.
            gl_item->partnercompany = recipient_item->recipientcompanycode.
            gl_item->assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                               THEN 'COST SHARING'
                                                               ELSE gs_header-productname ).
            gl_item->documentitemtext = |{ gs_header-ProviderCompanyCode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
            gl_item->material = gs_header-product.
            gl_item->costcenter = recipient_item->costcenter.
            APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
            gl_item_amount->currency = recipient_item->transactioncurrency.
*            gl_item_amount->currency = ls_proposal_items-transactioncurrency.
            gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency.
            gl_item_amount->currencyrole = '00'.
            IF exchange_rates[] IS NOT INITIAL.
              exchange_rate = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency
                                              targetcurrency = recipient_item->globalcurrency ]-exchangerate.
            ENDIF.
            gl_item_amount->exchangerate = exchange_rate.

          ENDLOOP.

          "Evita crear documento si no existen montos en cuantas GL
          IF journal_entry->%param-_glitems IS INITIAL.
            DELETE gta_je_post INDEX lines( gta_je_post ).
            CONTINUE.
          ENDIF.
          "Evita crear documento si no existen montos en cuantas GL

          " Borocratic stuff for ZCL_PROPOSAL_TOOLS
          DATA(proposal_items_by_recipient) = gtd_items_add.
          DELETE proposal_items_by_recipient WHERE recipientcompanycode <> recipient_company_code.
          DO lines( proposal_items_by_recipient ) TIMES.
            DATA(proposal_item) = REF #( proposal_items_by_recipient[ sy-index ] ).
            APPEND INITIAL LINE TO gt_doc_map REFERENCE INTO DATA(doc_map).
            doc_map->id                 = proposal_item->id.
            doc_map->item_id            = proposal_item->item_id.
            doc_map->itembasis_id       = proposal_item->itembasis_id.
            doc_map->itemcalc_id        = proposal_item->itemcalc_id.
            doc_map->documenttype       = zcl_proposal_bo_abs=>c_document_type-incomereclassif.
            doc_map->documentkey        = |DUMMY{ proposal_item->documentkey }{ gs_header-providercompanycode }{ gs_header-product }{ proposal_item->recipientcompanycode }|.
          ENDDO.
          DATA(lo_list_bo) = NEW zcl_proposal_bo_recl_comp_par( iv_process = gv_process
                                                                its_doc    = gts_doc
                                                                it_doc_map = gt_doc_map
                                                                it_je_post = gta_je_post ).
          APPEND lo_list_bo TO gtd_list_bo.
          CLEAR: gt_doc_map, gta_je_post.

          CLEAR lv_position_num.
        ENDLOOP.

        CHECK gtd_list_bo IS NOT INITIAL.
        exe_bo( )."Return the data on me->gt_doc_map
        et_doc_map = me->gt_doc_map.
        IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ) OR
           Line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
*    save_log( ).
      CATCH cx_sy_conversion_no_date INTO DATA(exc).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      CATCH cx_sy_itab_line_not_found INTO DATA(cx_line_not_found).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDTRY.
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

    CHECK gtd_doc IS NOT INITIAL.
    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
*      DATA(lv_posting_date) = lt_posting_date[ fiscalyear = gs_header-fiscalyear companycode = gs_header-providercompanycode accountingdocument = <fs_doc>-documentkey ].
*Ini EXT_OSCUGALD 15.06.2026 - Cost Sharing: usar companycode del doc (receptor) no del provider
*READ TABLE lt_posting_date WITH KEY fiscalyear = gs_header-fiscalyear
*                                 companycode = gs_header-providercompanycode
*                                 accountingdocument = <fs_doc>-documentkey
*                                 INTO DATA(ls_posting_date_line).
      READ TABLE lt_posting_date WITH KEY fiscalyear         = gs_header-fiscalyear
                                          companycode        = <fs_doc>-companycode
                                          accountingdocument = <fs_doc>-documentkey
                                 INTO DATA(ls_posting_date_line).
*Fin EXT_OSCUGALD 15.06.2026 - Cost Sharing
      IF sy-subrc = 0.
        DATA(lv_posting_date) = ls_posting_date_line-postingdate.
      ENDIF.
      CLEAR: gta_jr_rev,gt_doc_map.

      CHECK NOT line_exists( gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ] )
      OR gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ]-documentkey(5) EQ 'DUMMY'.

      APPEND INITIAL LINE TO gta_jr_rev ASSIGNING FIELD-SYMBOL(<jr>).


*Ini EXT_OSCUGALD 15.06.2026 - Cost Sharing: revertir en la sociedad donde se posteó el doc
      " CS: docs 60 posteados en sociedad receptora (EBA/IFB/MPB/SOC) no en provider (MLB)
      " Non-CS: <fs_doc>-companycode = gs_header-providercompanycode → sin impacto
*      <jr>-companycode = gs_header-providercompanycode.
      <jr>-companycode = <fs_doc>-companycode.
*Fin EXT_OSCUGALD 15.06.2026 - Cost Sharing
      <jr>-fiscalyear = gs_header-fiscalyear.
      <jr>-accountingdocument = CONV #( <fs_doc>-documentkey ).
      <jr>-%param = VALUE #(
*                            postingdate    = ld_today
                            PostingDate    = lv_posting_date
                            reversalreason = '01'
                            createdbyuser  = cl_abap_context_info=>get_user_technical_name( )
                           ).
      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.
      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-documentkey }|.
      <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_incomerec.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-incomereclassif.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_recl_comp_par( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
*                                                           iv_documentkey = <fs_doc>-Documentkey
                                                           iv_parentdockey = <fs_doc>-documentkey
                                                           its_doc        = gts_doc
                                                           it_doc_map     = gt_doc_map
                                                           it_je_rev      = gta_jr_rev ).

      APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
      <fs_list_bo> = lo_exe_bo.

*      exe_anulation_bo_sec( EXPORTING iv_dockey     = <fs_doc>-Documentkey
*                            CHANGING  ct_map_id_doc = gt_doc_map ).
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


  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_recl_comp_par   TYPE REF TO zcl_proposal_bo_recl_comp_par.
    DATA lv_status_log TYPE c.
    DATA lt_incomrecl TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst(
      EXPORTING
        p_in_tab  = gtd_list_bo
        p_debug   = lv_debug
      IMPORTING
        p_out_tab = DATA(l_out_tab)
    ).
    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>) WHERE inst IS NOT INITIAL.
      IF <l_out>-inst IS NOT INITIAL.
        lo_recl_comp_par ?= <l_out>-inst.
      ELSE.
        lo_recl_comp_par ?= gtd_list_bo[ <l_out>-index ].
        lt_incomrecl = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                      number   = '022'
                                                      severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-incomereclassif
            it_reported   = lt_incomrecl
          CHANGING
            ct_map_id_doc = lo_recl_comp_par->gt_doc_map_rc
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-incomereclassif
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-reclasification
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = lv_byuser
                               iv_attime       = lv_attime
                     CHANGING  ct_map_id_doc   = lo_recl_comp_par->gt_doc_map_rc ).
      ENDIF.
      APPEND LINES OF lo_recl_comp_par->gt_doc_map_rc TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.

  METHOD mapping_bo_sec_mic.
*───────────────────────────────────────────────────────────────────────────
* EXT_OSCUGALD 01.08.2026 - Bermudas MIC-USA (SDFPSINIC-23362)
* Reclasificacion de Ventas (RR) para Bermudas. Asiento de 2 lineas en el
* ledger de gestion L2L3, dentro de la MISMA sociedad que el AR:
*   - Linea GL cuenta base recl (692001) al haber → importe negativo
*   - Linea GL cuenta ingreso (469002) al debe → importe positivo
* Ambas cuentas salen de ZINT_A_MD_GLACCT doctype RR (glaccount1/glaccount2).
* Solo se genera si hubo AR (preparedata filtra items con doc; ademas el
* importe de la regalia debe existir en el basis).
*
* Direccion (igual que AR): RR sigue la sociedad del AR.
*   lv_amount_tc > 0 → MIC factura a USA → AR/RR en USA
*   lv_amount_tc < 0 → USA factura a MIC → AR/RR en MIC
* CeCo dinamico: prefijo + internalcode(sociedad RR) + CeBe. Ledger L2L3.
* Cuentas: determinacion SIEMPRE con MIC como provider.
*───────────────────────────────────────────────────────────────────────────
    FINAL(ld_lastday) = zcl_interco_utils=>rp_last_day_of_months(
      day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

    CHECK gtd_items_add IS NOT INITIAL.

    " CeCo = prefijo(4) + internalcode(3) + CeBe(3). Prefijo y CeBe desde TVARVC.
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

    " Importe de la regalia desde el basis (cpib), item del CeBe destino.
    " Se agrupa por sociedad receptora igual que en AR.
    DATA lv_cebe_prctr TYPE prctr.
    lv_cebe_prctr = |{ lv_ceco_cebe ALPHA = IN }|.

    " Relaciones interco de MIC (para derivar la contraparte / internalcodes).
    DATA lt_relationships TYPE TABLE OF zi_intercorelationship WITH EMPTY KEY.
    SELECT providercompanycode, recipientcompanycode, recipientcustomer
      FROM zi_intercorelationship
      WHERE ( providercompanycode  = @gs_header-providercompanycode
           OR recipientcompanycode = @gs_header-providercompanycode )
      INTO CORRESPONDING FIELDS OF TABLE @lt_relationships.

    " Internalcodes por sociedad — JOIN con relaciones (ATC Clean Core).
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
    " gtd_items_add es el driver (ya filtrado por preparedata: solo items con AR).
    DATA(proposal_items) = gtd_items_add.
    SELECT recipientcompanycode,
           SUM( amountintrasactioncurrency ) AS amountintransactioncurrency,
           transactioncurrency
      FROM @proposal_items AS pi
      GROUP BY recipientcompanycode, transactioncurrency
      INTO TABLE @DATA(totals_mic).

    IF totals_mic IS INITIAL.
      RETURN.
    ENDIF.

    " Determinacion de cuentas RR: SIEMPRE con MIC como provider.
    DATA(account_determination) = NEW zcl_interco_doc_glaccount(
      i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar
      i_product               = gs_header-product
      i_provider_company_code = gs_header-providercompanycode
      i_valid_at              = ld_lastday ).

    " Cuentas RR: glaccount1 = base recl (692001), glaccount2 = ingreso (469002).
    DATA(gl_account) = account_determination->get(
      i_tarifftype = zcl_interco_doc_glaccount=>co_tariff_type-basis
      i_department = space
      i_pandlid    = space ).

    LOOP AT totals_mic REFERENCE INTO DATA(total_mic).

      DATA(lv_amount_tc) = total_mic->amountintransactioncurrency.
      IF lv_amount_tc = 0.
        CONTINUE.
      ENDIF.

      " Direccion (igual que AR): RR en la sociedad del AR.
      DATA(lv_rr_companycode) = COND bukrs(
        WHEN lv_amount_tc > 0
        THEN total_mic->recipientcompanycode    " RR en USA
        ELSE gs_header-providercompanycode ).   " RR en MIC

      DATA(lv_rr_counterparty) = COND bukrs(
        WHEN lv_rr_companycode = gs_header-providercompanycode
        THEN total_mic->recipientcompanycode
        ELSE gs_header-providercompanycode ).

      " CeCo dinamico: prefijo + internalcode(sociedad RR) + CeBe.
      READ TABLE lt_company_ic INTO DATA(ls_company_ic)
        WITH KEY companycode = lv_rr_companycode.
      DATA lv_ceco_mic TYPE kostl.
      IF sy-subrc = 0 AND ls_company_ic-internalcode IS NOT INITIAL.
        lv_ceco_mic = |{ lv_ceco_prefix }{ ls_company_ic-internalcode }{ lv_ceco_cebe }|.
      ELSE.
        add_msg_to_log(
          iv_current_item = VALUE #( )
          iv_dockey       = |DUMMYRR{ lv_rr_companycode }{ gs_header-product }|
          iv_doctype      = zcl_proposal_bo_abs=>c_document_type-incomereclassif
          iv_message_type = 'E'
          iv_message_text = |No se encontro internalcode para sociedad { lv_rr_companycode } en zi_intercocompanycode.| ).
        CONTINUE.
      ENDIF.

      DATA(lv_doctext) = |{ lv_rr_companycode }-{ lv_rr_counterparty } Royalties { gs_header-fiscalperiod }.{ gs_header-fiscalyear }|.

      APPEND INITIAL LINE TO gta_je_post REFERENCE INTO DATA(journal_entry).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " HEADER — clase CH (reclasificacion), ledger L2L3, sociedad RR
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      journal_entry->%cid = |RR{ lv_rr_companycode }{ gs_header-product }{ sy-tabix }|.
      journal_entry->%param-companycode                  = lv_rr_companycode.
      journal_entry->%param-documentdate                 = ld_lastday.
      journal_entry->%param-postingdate                  = ld_lastday.
      journal_entry->%param-accountingdocumenttype       = 'CH'.
      journal_entry->%param-accountingdocumentheadertext = 'Royalties'.
      journal_entry->%param-createdbyuser                = cl_abap_context_info=>get_user_technical_name( ).
      journal_entry->%param-ledgergroup                  = 'L2L3'.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " LINEA 1 — cuenta base recl (glaccount1 = 692001) al haber (negativo)
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " LINEA 1 — cuenta base recl (glaccount1 = 692001) al haber (negativo).
      " Esta linea SI lleva CeCo (molde: 692001 con 9591145271).
      APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item1).
      gl_item1->glaccount           = gl_account-glaccount1.
      gl_item1->glaccountlineitem   = 1.
      gl_item1->assignmentreference = 'REGALIAS'.
      gl_item1->documentitemtext    = lv_doctext.
      gl_item1->material            = gs_header-product.
      gl_item1->profitcenter        = lv_cebe_prctr.
      gl_item1->costcenter          = lv_ceco_mic.
      " Sociedad GL (trading partner) = contraparte (MIC). Obligatoria interco.
      gl_item1->partnercompany      = lv_rr_counterparty.

      APPEND INITIAL LINE TO gl_item1->_currencyamount REFERENCE INTO DATA(gl_amount1).
      gl_amount1->currencyrole           = '00'.
      gl_amount1->currency               = total_mic->transactioncurrency.
      gl_amount1->journalentryitemamount = abs( lv_amount_tc ) * -1.
      gl_amount1->exchangerate           = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " LINEA 2 — cuenta ingreso (glaccount2 = 469002) al debe (positivo).
      " Esta linea NO lleva CeCo (molde: 469002 sin centro de coste).
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item2).
      gl_item2->glaccount           = gl_account-glaccount2.
      gl_item2->glaccountlineitem   = 2.
      gl_item2->assignmentreference = 'REGALIAS'.
      gl_item2->documentitemtext    = lv_doctext.
      gl_item2->material            = gs_header-product.
      gl_item2->profitcenter        = lv_cebe_prctr.
      " Sociedad GL (trading partner) = contraparte (MIC). Obligatoria interco.
      gl_item2->partnercompany      = lv_rr_counterparty.

      APPEND INITIAL LINE TO gl_item2->_currencyamount REFERENCE INTO DATA(gl_amount2).
      gl_amount2->currencyrole           = '00'.
      gl_amount2->currency               = total_mic->transactioncurrency.
      gl_amount2->journalentryitemamount = abs( lv_amount_tc ).
      gl_amount2->exchangerate           = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " DOC_MAP — claves completas por cada item de la propuesta (recipient).
      " Se usa VALUE con FOR/WHERE (no LOOP anidado) para cumplir ATC Clean Core.
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(lv_rr_dockey) = |DUMMYRR{ lv_rr_companycode }{ gs_header-product }{ gs_header-fiscalperiod }|.
      gt_doc_map = VALUE #( BASE gt_doc_map
        FOR prop_item IN gtd_items_add
        WHERE ( recipientcompanycode = total_mic->recipientcompanycode )
        ( id           = prop_item-id
          item_id      = prop_item-item_id
          itembasis_id = prop_item-itembasis_id
          itemcalc_id  = prop_item-itemcalc_id
          companycode  = lv_rr_companycode
          documenttype = zcl_proposal_bo_abs=>c_document_type-incomereclassif
          documentkey  = lv_rr_dockey ) ).

      DATA(lo_list_bo) = NEW zcl_proposal_bo_recl_comp_par(
        iv_process = gv_process
        its_doc    = gts_doc
        it_doc_map = gt_doc_map
        it_je_post = gta_je_post ).
      APPEND lo_list_bo TO gtd_list_bo.

      CLEAR: gt_doc_map, gta_je_post.
    ENDLOOP.

    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( ).
  ENDMETHOD.
ENDCLASS.
