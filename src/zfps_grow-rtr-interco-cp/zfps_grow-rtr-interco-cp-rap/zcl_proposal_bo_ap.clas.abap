CLASS zcl_proposal_bo_ap DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_items_calc,
             id                          TYPE zi_intercoproposalitemcalcdet-id,
             product                     TYPE zi_intercoproposalitemcalcdet-product,
             item_id                     TYPE zi_intercoproposalitemcalcdet-item_id,
*             costcenter                  TYPE zi_intercoproposalitemcalcdet-costcenter,
             profitcentereq              TYPE zi_intercoproposalitem-profitcentereq,
             companycodecurrency         TYPE zi_intercoproposalitem-companycodecurrency,
             globalcurrency              TYPE zi_intercoproposalitem-globalcurrency,
             amountintransactioncurrency TYPE zi_intercoproposalitemcalcdet-amountincompanycodecurrency,
             transactioncurrency         TYPE zi_intercoproposalitemcalcdet-companycodecurrency,
*         exchangerate              TYPE I_ProposalItem-ExchangeRate,
           END OF ty_items_calc.
    TYPES: tt_items_calc TYPE STANDARD TABLE OF ty_items_calc WITH EMPTY KEY.
    TYPES:
      gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post .
    TYPES:
      gsty_apitems TYPE LINE OF gsty_post-%param-_apitems .
    TYPES: gtty_apitems TYPE STANDARD TABLE OF gsty_apitems WITH EMPTY KEY.

    TYPES: gsty_glitems TYPE LINE OF gsty_post-%param-_glitems .
    TYPES: gsty_taxitems TYPE LINE OF gsty_post-%param-_taxitems.
    TYPES: gsty_wht TYPE LINE OF gsty_post-%param-_withholdingtaxitems .

    TYPES: gtty_glitems TYPE STANDARD TABLE OF gsty_glitems WITH EMPTY KEY.
    TYPES: gtty_taxitems TYPE STANDARD TABLE OF gsty_taxitems WITH EMPTY KEY.
    TYPES: gtty_wht TYPE STANDARD TABLE OF gsty_wht WITH EMPTY KEY.

    TYPES: BEGIN OF ty_wht_aux,
             primary_key        TYPE string,
             withholdingtaxtype TYPE zde_witht,
             withholdingtaxcode TYPE zde_wt_withcd,
             documentcurrency   TYPE waers,
           END OF ty_wht_aux.
    TYPES: tt_wht_aux TYPE STANDARD TABLE OF ty_wht_aux WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_wht,
        supplier           TYPE lifnr,
        companycode        TYPE bukrs,
        withholdingtaxtype TYPE zde_witht,
        withholdingtaxcode TYPE zde_wt_withcd,
      END OF ty_wht .
    TYPES:
      ty_t_wht TYPE STANDARD TABLE OF ty_wht WITH EMPTY KEY .
*    TYPES:
*      lty_items   TYPE STRUCTURE FOR ACTION IMPORT i_supplierinvoicetp~create,
*      tt_wht_code TYPE gsty_wht-%param-_withholdingtaxes.
    DATA: gs_glitems TYPE gsty_glitems.
    DATA:
      gta_je_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
    DATA:
      gta_jr_rev  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .
    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .

    TYPES: BEGIN OF ty_cccode_summary,
             cc_code         TYPE n LENGTH 10,
             global_sum      TYPE zint_dte_fis_ksl,
             markup_sum      TYPE zde_markup_amount,
             grossbase_sum   TYPE zde_grup_amount,
             grossmargin_sum TYPE zde_grupmargin_amount,
           END OF ty_cccode_summary.
    TYPES: gtty_cccode TYPE STANDARD TABLE OF ty_cccode_summary WITH EMPTY KEY.

    TYPES: BEGIN OF ty_exchange_rate,
             sourcecurrency TYPE waers,           "CUKY(5) — released Clean Core A
             targetcurrency TYPE waers,           "CUKY(5) — released Clean Core A
             exchangerate   TYPE zint_dte_ukurs,  "DEC 9,5 — tipo propio del proyecto
           END OF ty_exchange_rate.
    TYPES: tt_exchange_rates TYPE STANDARD TABLE OF ty_exchange_rate
             WITH KEY sourcecurrency targetcurrency.

  PROTECTED     SECTION.
    METHODS:
      preparedata REDEFINITION,
      exe_bo REDEFINITION,
      mapping_bo_sec REDEFINITION,
      mapping_reverse_sec REDEFINITION.
  PRIVATE SECTION.

    DATA: v_tolerance TYPE wrbtr VALUE '1.50'.

*Ini EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026
*   tt_cpic: tipo de la tabla CPIC leída en mapping_bo_sec fuera del loop
*   Se pasa como parámetro para evitar SELECTs dentro del método
*   → elimina findings ATC NonLocal Nested DB OP sin necesidad de exemptions.
    TYPES: BEGIN OF ty_cpic_row,
             id                          TYPE uuid,
             item_id                     TYPE zde_prop_item_id,
             glaccount                   TYPE saknr,
             costcenter                  TYPE kostl,
             tarifftype                  TYPE zint_tariff_type,
             profitcenter                TYPE prctr,
             recipientcompanycode        TYPE bukrs,
             amountincompanycodecurrency TYPE wrbtr,
             amountinglobalcurrency      TYPE wrbtr,
             companycodecurrency         TYPE waers,
             globalcurrency              TYPE waers,
*Ini EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS] 17.06.2026
             department                  TYPE zint_depto,
*Fin EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS] 17.06.2026
           END OF ty_cpic_row.
    TYPES: tt_cpic TYPE STANDARD TABLE OF ty_cpic_row WITH DEFAULT KEY.

    METHODS process_baogl_for_company_ars
      IMPORTING
        !iv_recipient      TYPE bukrs
        !iv_totalamount    TYPE wrbtr
        !iv_currentitem    LIKE LINE OF gtd_items_add OPTIONAL
        !iv_account        TYPE hkont
        !it_exchange_rates TYPE tt_exchange_rates OPTIONAL
        !it_cpic           TYPE tt_cpic OPTIONAL
        !it_ceco_map       TYPE ANY TABLE OPTIONAL
      EXPORTING
        ev_totalimp        TYPE wrbtr
        et_glitems         TYPE gtty_glitems
        et_taxitems        TYPE gtty_taxitems
        et_itemscalc       TYPE tt_items_calc
      CHANGING
        ct_baogl           TYPE gtty_baogl.
*Fin EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026

    METHODS process_baogl_for_company
      IMPORTING
        !iv_recipient   TYPE bukrs
        !iv_totalamount TYPE wrbtr
        !iv_currentitem LIKE LINE OF gtd_items_add OPTIONAL
        !iv_account     TYPE hkont
*        !it_exchange_rates TYPE tt_exchange_rates OPTIONAL
      EXPORTING
        ev_totalimp     TYPE wrbtr
        et_glitems      TYPE gtty_glitems
        et_taxitems     TYPE gtty_taxitems
        et_itemscalc    TYPE tt_items_calc
      CHANGING
        !ct_baogl       TYPE gtty_baogl.

* Ini EXT_OSCUGALD 01.08.2026 - Bermudas MIC (SDFPSINIC-23362)
    METHODS mapping_bo_sec_mic.
* Fin EXT_OSCUGALD 01.08.2026 - Bermudas MIC

    METHODS get_wht_codes_brf
      IMPORTING
        !iv_aplineitem     TYPE docln6
        !iv_cid_invoice    TYPE string
        !iv_supplier       TYPE zbu_partner
        !iv_companycode    TYPE bukrs
        !iv_provider       TYPE zfi_proposalitem_add-providercompanycode
        !iv_recipient      TYPE zfi_proposalitem_add-recipientcompanycode
        !iv_product        TYPE zfi_proposalitem_add-product
        !iv_currency       TYPE zint_dte_fis_rkcur
        !it_wht            TYPE ty_t_wht
      RETURNING
        VALUE(rt_wht_code) TYPE gtty_wht.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: atributos para evitar SELECTs en loops
    DATA mv_is_cs          TYPE abap_boolean.
    DATA mv_cs_ceco_prefix TYPE c LENGTH 4.
    DATA mv_cs_cebe        TYPE c LENGTH 3.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: tabla internalcodes pre-cargados para CeCo AP
    TYPES: BEGIN OF ty_cs_company,
             companycode  TYPE bukrs,
             internalcode TYPE paval,
           END OF ty_cs_company.
    DATA mt_cs_companies   TYPE STANDARD TABLE OF ty_cs_company WITH DEFAULT KEY.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
ENDCLASS.



CLASS ZCL_PROPOSAL_BO_AP IMPLEMENTATION.


  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_ap_parallel   TYPE REF TO zcl_proposal_bo_ap_parallel.
    DATA lv_status_log TYPE c.
    DATA lt_journalentry TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    CONSTANTS: c_fields TYPE i VALUE 6. "Cantidad de campos sum
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

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>)." WHERE inst IS NOT INITIAL.
      IF <l_out>-inst IS NOT INITIAL.
        lo_ap_parallel ?= <l_out>-inst.
      ELSE.
        lo_ap_parallel ?= gtd_list_bo[ <l_out>-index ].
        lt_journalentry = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                         number   = '022'
                                                         severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-je_purchase
            it_reported   = lt_journalentry
          CHANGING
            ct_map_id_doc = lo_ap_parallel->gt_doc_map_ap
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-je_purchase
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = lv_byuser
                               iv_attime       = lv_attime
                     CHANGING  ct_map_id_doc   = lo_ap_parallel->gt_doc_map_ap ).
      ENDIF.
      APPEND LINES OF lo_ap_parallel->gt_doc_map_ap TO me->gt_doc_map.

    ENDLOOP.
  ENDMETHOD.


  METHOD get_wht_codes_brf.

    DATA: ls_target TYPE LINE OF gsty_post-%param-_withholdingtaxitems.
    DATA: lt_filtered TYPE ty_t_wht.
    DATA: lt_wht_input TYPE tt_wht_aux.
    DATA: lv_line_id TYPE n LENGTH 6.

    CLEAR rt_wht_code.
    lv_line_id = iv_aplineitem.

    LOOP AT it_wht INTO DATA(ls_wht)
      WHERE supplier = iv_supplier AND companycode = iv_companycode.
      APPEND ls_wht TO lt_filtered.
    ENDLOOP.

    IF lt_filtered IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_brf_helper) = NEW zcl_interco_brf_wht( ).
    LOOP AT lt_filtered INTO DATA(ls_filt).
      DATA(lv_tax_code) = lo_brf_helper->get_wht_code(
        iv_provider  = iv_provider
        iv_recipient = iv_recipient
        iv_product   = iv_product
        iv_whttype   = ls_filt-withholdingtaxtype ).
* Incluimos todos los tipos de retención, aunque no tengan indicador (código vacío),
* según especificación funcional.
      APPEND VALUE #(
        glaccountlineitem  = lv_line_id
        withholdingtaxcode = lv_tax_code
        withholdingtaxtype = ls_filt-withholdingtaxtype
      ) TO rt_wht_code.

    ENDLOOP.

  ENDMETHOD.


  METHOD mapping_bo_sec.
    DATA lt_glitems TYPE gsty_post-%param-_glitems.
    DATA lt_taxitems TYPE gsty_post-%param-_taxitems.
    DATA lt_apitems TYPE gsty_post-%param-_apitems.
    DATA gv_baseunit TYPE gsty_glitems-baseunit.
    TYPES: BEGIN OF ty_key,
             supplier    TYPE zbu_partner,
             companycode TYPE bukrs,
           END OF ty_key.

    DATA: lt_keys TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

    TYPES: BEGIN OF ty_group_summary,
*             id                   TYPE uuid,
             recipientcompanycode TYPE bukrs,
             total_amount         TYPE zint_dte_fis_ksl,
             doc_type             TYPE c LENGTH 2, " IR o AJ
           END OF ty_group_summary.
    DATA: lt_group_summary TYPE SORTED TABLE OF ty_group_summary WITH UNIQUE KEY recipientcompanycode.

    TYPES: BEGIN OF ty_glitem_mapping,
             type         TYPE string,
             amount_field TYPE string,
           END OF ty_glitem_mapping,
           tt_glitem_mapping TYPE TABLE OF ty_glitem_mapping WITH KEY type.
    TYPES: BEGIN OF ty_wht,
             supplier           TYPE lifnr,
             companycode        TYPE bukrs,
             withholdingtaxtype TYPE zde_witht,
             withholdingtaxcode TYPE zde_wt_withcd,
           END OF ty_wht.
    TYPES: ty_t_wht TYPE STANDARD TABLE OF ty_wht WITH EMPTY KEY.

    DATA: lt_wht TYPE ty_t_wht.
    DATA: lv_totalamount TYPE zint_dte_fis_ksl.
    DATA: lv_totalimp    TYPE wrbtr.
    DATA: lv_cont TYPE n LENGTH 6.
    DATA: lv_account TYPE hkont.
    TYPES: rs_t_range_bukrs TYPE RANGE OF bukrs.

    TRY.

        DATA(lt_items)        = gtd_items_add[].
        DATA(lt_baogl)        = gtd_baogl[].
        DATA(lt_baogl_mla)    = gtd_baogl_mla[].  "MLA Genova
        DATA(journal_entries) = gta_je_post.

        FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

* Ini EXT_OSCUGALD 01.08.2026 - Bermudas MIC (SDFPSINIC-23362)
        " Dispatch: producto MIC (Bermudas) → asiento AP dedicado (2 lineas,
        " importe unico). Espejo del AR. Aisla del flujo clasico con RETURN.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
          INTO @DATA(lv_mic_prod_found_ap).
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

        zcl_interco_utils=>unit_code_outbound( EXPORTING im_value = '%'
                                               IMPORTING ex_value = FINAL(base_unit) ).

        IF lt_items IS INITIAL.
          RETURN.
        ENDIF.

        SORT lt_items BY providercompanycode
                         product
                         recipientcompanycode
                         flow.

        SORT lt_baogl BY recipientcompanycode
                         item_id.

*        SELECT SINGLE low FROM zi_tvarvc
*        WHERE name = 'ZWT_GLACCOUNT_REDONDEO'
*        INTO @DATA(glround).
*        IF sy-subrc = 0.
*          lv_account = glround.
*        ELSE.
*          lv_account = '780010'.
*        ENDIF.
*Ini --> EXT_OSCUGALD --> COA_MIGRATION Cuenta redondeo TVARVC
        DATA lv_tvarvc_low TYPE zi_tvarvc-low.
        SELECT SINGLE low FROM zi_tvarvc
                  WHERE name = 'ZWT_GLACCOUNT_REDONDEO'
                  INTO @lv_tvarvc_low.
        IF sy-subrc = 0 AND lv_tvarvc_low IS NOT INITIAL.
          lv_account = |{ lv_tvarvc_low ALPHA = IN }|.
        ELSE.
          READ TABLE lt_items INDEX 1 INTO DATA(ls_item_log).
          DATA(lv_tvarvc_err_dockey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }|.
          APPEND VALUE #(
            id           = ls_item_log-id
            item_id      = ls_item_log-item_id
            itembasis_id = ls_item_log-itembasis_id
            itemcalc_id  = ls_item_log-itemcalc_id
            documenttype = mv_posting_doctype
            documentkey  = lv_tvarvc_err_dockey
            companycode  = ls_item_log-recipientcompanycode
            status       = zcl_proposal_bo_abs=>c_document_status-error
          ) TO gt_doc_map.
          add_msg_to_log(
            iv_current_item = CORRESPONDING #( ls_item_log )
            iv_dockey       = lv_tvarvc_err_dockey
            iv_doctype      = mv_posting_doctype
            iv_message_type = 'E'
            iv_message_text = |Falta parametrización TVARVC: ZWT_GLACCOUNT_REDONDEO. No se puede determinar cuenta de redondeo.|
          ).
          DATA lv_tvarvc_err_ts TYPE abp_creation_tstmpl.
          GET TIME STAMP FIELD lv_tvarvc_err_ts.
          mapping_doc(
            EXPORTING
              iv_doctype                = mv_posting_doctype
              iv_status                 = zcl_proposal_bo_abs=>c_document_status-error
              iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
              iv_accountingdocumenttype = 'IR'
              iv_isadjustment           = space
              its_doc                   = gts_doc
              iv_byuser                 = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
              iv_attime                 = lv_tvarvc_err_ts
            CHANGING
              ct_map_id_doc             = gt_doc_map ).
          et_doc_map = gt_doc_map.
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit
            EXPORTING
              textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
*Fin --> EXT_OSCUGALD --> COA_MIGRATION

*       Génova detection + limpieza de profitcenter 200 redundantes
        IF lt_baogl_mla IS NOT INITIAL.

          SORT lt_baogl_mla BY recipientcompanycode
                               item_id.

          DATA(lt_genova_active) = VALUE rs_t_range_bukrs(
              FOR item IN lt_baogl_mla WHERE ( profitcenter = '0000000299' )
              ( sign = 'I' option = 'EQ' low = item-recipientcompanycode ) ).

          IF lt_genova_active IS NOT INITIAL.
            DELETE lt_baogl_mla WHERE ( profitcenter = '0000000200' AND recipientcompanycode IN lt_genova_active ).
          ENDIF.

          lt_baogl[] = lt_baogl_mla[].

        ENDIF.

*       items_calc: two-step sin hint.
*       Paso 1: extraer item_ids únicos de lt_baogl en tabla auxiliar.
*       Paso 2: JOIN con tabla auxiliar — CDS resuelve asociaciones normalmente.
        DATA items_calc TYPE tt_items_calc.
        DATA lv_rows_keys TYPE i.
        DATA lv_rows_baogl TYPE i.

        TYPES: BEGIN OF ty_baogl_key,
                 id      TYPE uuid,
                 item_id TYPE zde_prop_item_id,
               END OF ty_baogl_key.
        DATA lt_baogl_keys TYPE STANDARD TABLE OF ty_baogl_key
          WITH EMPTY KEY.

        lv_rows_baogl = lines( lt_baogl ).

        lt_baogl_keys = VALUE #(
          FOR b IN lt_baogl
          ( id      = b-id
            item_id = b-item_id ) ).

        SORT lt_baogl_keys BY id item_id.
        DELETE ADJACENT DUPLICATES FROM lt_baogl_keys
          COMPARING id item_id.

        lv_rows_keys = lines( lt_baogl_keys ).

        IF lt_baogl_mla IS NOT INITIAL.
          SELECT
                 proposal_items_calc_detail~id,
                 proposal_items_calc_detail~product,
                 proposal_items_calc_detail~item_id,
                 \_proposalitem-profitcentereq     AS profitcentereq,
                 \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
                 \_proposalitem-globalcurrency      AS globalcurrency,
                 \_proposalitem-recipientcountry    AS recipientcountry,
                 proposal_items_calc_detail~amountincompanycodecurrency,
                 proposal_items_calc_detail~amountinglobalcurrency
            FROM zi_proposalitemcalcdet_mla AS proposal_items_calc_detail
            INNER JOIN @lt_baogl_keys AS _keys
              ON _keys~id      = proposal_items_calc_detail~id
             AND _keys~item_id = proposal_items_calc_detail~item_id
            WHERE proposal_items_calc_detail~id = @gs_header-id
              AND tariffrate > 0
            INTO TABLE @DATA(lt_calc_raw).
        ELSE.
          SELECT
                 proposal_items_calc_detail~id,
                 proposal_items_calc_detail~product,
                 proposal_items_calc_detail~item_id,
                 \_proposalitem-profitcentereq     AS profitcentereq,
                 \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
                 \_proposalitem-globalcurrency      AS globalcurrency,
                 \_proposalitem-recipientcountry    AS recipientcountry,
                 proposal_items_calc_detail~amountincompanycodecurrency,
                 proposal_items_calc_detail~amountinglobalcurrency
            FROM zi_intercoproposalitemcalcdet AS proposal_items_calc_detail
            INNER JOIN @lt_baogl_keys AS _keys
              ON _keys~id      = proposal_items_calc_detail~id
             AND _keys~item_id = proposal_items_calc_detail~item_id
            WHERE proposal_items_calc_detail~id = @gs_header-id
              AND tariffrate > 0
            INTO TABLE @lt_calc_raw.
        ENDIF.

*       Resolver CASE en ABAP
        items_calc = VALUE tt_items_calc(
          FOR r IN lt_calc_raw
          ( id                          = r-id
            product                     = r-product
            item_id                     = r-item_id
            profitcentereq              = r-profitcentereq
            companycodecurrency         = r-companycodecurrency
            globalcurrency              = r-globalcurrency
            amountintransactioncurrency = COND #(
              WHEN r-recipientcountry = gs_header-providercountry
              THEN r-amountincompanycodecurrency
              ELSE r-amountinglobalcurrency )
            transactioncurrency         = COND #(
              WHEN r-recipientcountry = gs_header-providercountry
              THEN r-companycodecurrency
              ELSE r-globalcurrency ) ) ).

*       Eliminar duplicados equivalente al DISTINCT del SELECT original
        SORT items_calc BY id product item_id profitcentereq
                           companycodecurrency globalcurrency
                           amountintransactioncurrency transactioncurrency.
        DELETE ADJACENT DUPLICATES FROM items_calc
          COMPARING id product item_id profitcentereq
                    companycodecurrency globalcurrency
                    amountintransactioncurrency transactioncurrency.

*Ini EXT_OSCUGALD 29.04.2026 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        DATA lt_exchange_rates TYPE tt_exchange_rates.
*        IF sy-uname EQ 'EXT_OSCUGALD'.
        IF gs_header-providercompanycode = 'MLA'.
*[AJUSTE-1] Obtener el tipo de cambio
*[AJUSTE-1] Obtener el tipo de cambio desde i_exchangeraterawdata con abs() — igual que lo hace ZCL_PROPOSAL_BO_AR.
*El AR hace este SELECT por companycodecurrency/globalcurrency. Aquí lo hacemos por el primer ítem de lt_items para obtener
*las monedas de la sociedad proveedora. Este exchange_rate_unified se usa en el AP-item (ver más abajo)
* en lugar del exchangerate que viene de ct_baogl.
          SELECT DISTINCT
                 sourcecurrency,
                 targetcurrency,
                 abs( i_exchangeraterawdata~exchangerate ) AS exchangerate
            FROM i_exchangeraterawdata
            INNER JOIN @lt_items AS lt_items
                ON lt_items~companycodecurrency = i_exchangeraterawdata~sourcecurrency
               AND lt_items~globalcurrency      = i_exchangeraterawdata~targetcurrency
            WHERE exchangeratetype    = 'B'
              AND validitystartdate   = @last_day_of_month
            INTO TABLE @lt_exchange_rates.
        ENDIF.
*Fin EXT_OSCUGALD 29.04.2026 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

        "Arma tabla auxiliar para rutina tipos de retención
        LOOP AT lt_items INTO DATA(ls_item).
          APPEND VALUE #( supplier    = ls_item-providervendor
                          companycode = ls_item-recipientcompanycode ) TO lt_keys.
          APPEND VALUE #( supplier    = ls_item-recipientcustomer
                          companycode = ls_item-providercompanycode ) TO lt_keys.
        ENDLOOP.

        SORT lt_keys BY supplier companycode.
        DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING ALL FIELDS.
        "Obtiene tipos de retención
        SELECT supplier,
               companycode,
               withholdingtaxtype,
               withholdingtaxcode
          FROM i_supplierwithholdingtax
          WITH PRIVILEGED ACCESS
          FOR ALL ENTRIES IN @lt_keys
               WHERE supplier = @lt_keys-supplier
                 AND companycode = @lt_keys-companycode
          INTO TABLE @lt_wht.

*Ini EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026
*   Pre-leer CPIC fuera del loop de journal entries.
*   Para escenario Génova: usar zi_proposalitemcalcdet_mla (misma vista que AR)
*   que tiene item_id por recipient → permite discriminar MLA (8,13) de MSP (18).
*   Para resto: usar zi_intercoproposalitemcalcdet estándar.
        DATA lt_cpic_ars TYPE tt_cpic.
***        IF sy-uname = 'EXT_OSCUGALD'.
***          IF lt_baogl_mla IS NOT INITIAL.
        IF gs_header-providercompanycode = 'MLA'.
          IF lt_baogl_mla IS NOT INITIAL.
*           Génova: mismo JOIN que AR/get_for_journalentry.
*           Driver: lt_items via zi_proposalitem_mla (tiene item_id CPIC con profitcenter 299).
*           zi_proposalitemcalcdet_mla tiene item_id=5 para MSP (profitcenter 299).
            DATA lt_items_mla LIKE lt_items.
            SELECT DISTINCT id, item_id, itembasis_id, itemcalc_id
              FROM zi_proposalitem_mla
              FOR ALL ENTRIES IN @lt_items
              WHERE id                       = @lt_items-id
                AND profitcenter             = '0000000299'
                AND b_amountinglobalcurrency <> 0
              INTO CORRESPONDING FIELDS OF TABLE @lt_items_mla.
            SELECT
              _cpic~id,
              _cpic~item_id,
              _cpic~glaccount,
              _cpic~costcenter,
              _cpic~tarifftype,
              \_proposalitem-profitcenter         AS profitcenter,
              \_proposalitem-recipientcompanycode AS recipientcompanycode,
              SUM( _cpic~amountincompanycodecurrency ) AS amountincompanycodecurrency,
              SUM( _cpic~amountinglobalcurrency )      AS amountinglobalcurrency,
              \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
              \_proposalitem-globalcurrency             AS globalcurrency,
              _cpic~department
            FROM zi_proposalitemcalcdet_mla AS _cpic
            INNER JOIN @lt_items_mla AS _items
              ON _items~id      = _cpic~id
             AND _items~item_id = _cpic~item_id
            WHERE _cpic~id       = @gs_header-id
              AND _cpic~tariffrate > 0
            GROUP BY
              _cpic~id, _cpic~item_id, _cpic~glaccount, _cpic~costcenter,
              _cpic~tarifftype,
              \_proposalitem-profitcenter,
              \_proposalitem-recipientcompanycode,
              \_proposalitem\_proposal\_providercompanycode-currency,
              \_proposalitem-globalcurrency,
              _cpic~department
            HAVING SUM( _cpic~amountincompanycodecurrency ) <> 0
            INTO CORRESPONDING FIELDS OF TABLE @lt_cpic_ars.
          ELSE.
*Ini EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS] 17.06.2026
*   Se agrega department al SELECT y GROUP BY para que cada ítem CPIC
*   lleve su propio department (ej. 15) en lugar de depender del
*   department del primer baogl del recipient (ej. 13).
*   Esto permite que process_baogl_for_company_ars use el department
*   correcto en doc_account->get() → cuenta 693141/693142 para depto 15.
            SELECT
              id,
              item_id,
              glaccount,
              costcenter,
              tarifftype,
              profitcenter,
              SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
              SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
              companycodecurrency,
              globalcurrency,
              department
            FROM zi_intercoproposalitemcalcdet
            WHERE id              = @gs_header-id
              AND tariffrate      > 0
              AND companycodecurrency = 'ARS'
            GROUP BY
              id, item_id, glaccount, costcenter, tarifftype, profitcenter,
              companycodecurrency, globalcurrency, department
            HAVING SUM( amountincompanycodecurrency ) <> 0
            INTO CORRESPONDING FIELDS OF TABLE @lt_cpic_ars.
*Fin EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS] 17.06.2026
          ENDIF.
        ENDIF.
*Fin EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026
*Ini EXT_OSCUGALD [AJUSTE-CECO-BAOGL] 04.05.2026
*   Pre-calcular costcenters en lt_baogl via BRF+ solo para filas ARS,
*   exactamente igual que el LOOP inicial de process_baogl_for_company.
*   Garantiza que ct_baogl llegue con costcenters correctos al método
*   (para Génova 299: costcenterd4='' → BRF+ vacío → CLEAR costcenter).
***        IF sy-uname = 'EXT_OSCUGALD'
***          AND ( lt_baogl_mla IS NOT INITIAL
***             OR line_exists( lt_baogl[ companycodecurrency = 'ARS' ] ) ).
        IF gs_header-providercompanycode = 'MLA'
                  AND ( lt_baogl_mla IS NOT INITIAL
                     OR line_exists( lt_baogl[ companycodecurrency = 'ARS' ] ) ).
          LOOP AT lt_baogl ASSIGNING FIELD-SYMBOL(<ls_baogl_pre>)
                      WHERE companycodecurrency = 'ARS'.
            DATA(lo_brf_pre) = NEW zcl_interco_brf_wht( ).
            DATA(lv_cccode_pre) = lo_brf_pre->get_cc_code(
              iv_product      = <ls_baogl_pre>-product
              iv_cc_origen    = <ls_baogl_pre>-costcenterd4
              iv_departamento = <ls_baogl_pre>-department
              iv_tipo_doc     = zcl_interco_doc_glaccount=>co_doc_type-ap ).
            IF lv_cccode_pre IS NOT INITIAL.
              <ls_baogl_pre>-costcenter =
                |{ lv_cccode_pre }{ <ls_baogl_pre>-internalcode }{ <ls_baogl_pre>-profitcenter ALPHA = OUT }|.
              READ TABLE items_calc INTO DATA(ls_pc_pre)
                WITH KEY id      = <ls_baogl_pre>-id
                         item_id = <ls_baogl_pre>-item_id
                         product = <ls_baogl_pre>-product.
              IF ls_pc_pre-profitcentereq IS NOT INITIAL.
                <ls_baogl_pre>-costcenter =
                  |{ lv_cccode_pre }{ <ls_baogl_pre>-internalcode }{ ls_pc_pre-profitcentereq ALPHA = OUT }|.
                <ls_baogl_pre>-costcenter+7(3) = ls_pc_pre-profitcentereq.
              ENDIF.
            ELSE.
              CLEAR <ls_baogl_pre>-costcenter.
            ENDIF.
          ENDLOOP.
        ENDIF.
*Fin EXT_OSCUGALD [AJUSTE-CECO-BAOGL] 04.05.2026
*Ini EXT_OSCUGALD [AJUSTE-CPIC-BYRECIP]
*   lt_cpic_by_recip eliminado — la distribución por recipient se hace
*   directamente en el dispatch filtrando lt_cpic_ars por profitcenter.
*   item_id en BAOGL (Genova split) difiere del item_id en CPIC (provider),
*   profitcenter es el campo correcto para correlacionar ambas fuentes.
*Fin EXT_OSCUGALD [AJUSTE-CPIC-BYRECIP]
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
        " Pre-cargar detección CS en atributos de clase antes del loop
        " Evita SELECTs dentro de loops — resuelve ATC NonLocal Nested DB OP
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_CS_PRODUCT'
            AND type = 'S'
            AND low  = @gs_header-product
          INTO @DATA(lv_cs_prod_found).
        mv_is_cs = xsdbool( sy-subrc = 0 ).

        IF mv_is_cs = abap_true.
          SELECT SINGLE low FROM zi_tvarvc
            WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
            INTO @mv_cs_ceco_prefix.
          IF sy-subrc <> 0. mv_cs_ceco_prefix = '9590'. ENDIF.

          SELECT SINGLE low FROM zi_tvarvc
            WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
            INTO @mv_cs_cebe.
          IF sy-subrc <> 0. mv_cs_cebe = '999'. ENDIF.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: pre-cargar internalcodes para CeCo AP (ATC clean)
          " SELECT fuera del LOOP en mapping_bo_sec → evita NonLocal Nested DB OP en ATC
          " process_baogl_for_company usa READ TABLE mt_cs_companies sin SELECT
          SELECT companycode, internalcode
            FROM zi_intercocompanycode
            WHERE sitecode = @gs_header-providercompanycode
            INTO CORRESPONDING FIELDS OF TABLE @mt_cs_companies.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
        ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AP v2: base_BRL_L2 x sharerate (espejo exacto de AR v2)
        IF mv_is_cs = abap_true.

          " 1. base_BRL agrupada por glaccount1 (100%, sin filtrar por sociedad)
          TYPES: BEGIN OF ty_cs_ap_base_l2,
                   glaccount1 TYPE saknr,
                   base_brl   TYPE zint_dte_fis_ksl,
                 END OF ty_cs_ap_base_l2.

          DATA lt_cs_ap_base_l2 TYPE HASHED TABLE OF ty_cs_ap_base_l2
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
              AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ap
              AND det~tarifftype          = '6'
              AND det~isdeleted           = ''
            WHERE bas~providercompanycode = @gs_header-providercompanycode
              AND bas~fiscalyear          = @gs_header-fiscalyear
              AND bas~fiscalperiod        = @gs_header-fiscalperiod
              AND bas~product             = @gs_header-product
            GROUP BY det~glaccount1
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_ap_base_l2.

          " Validar P&L IDs con importe en base pero sin mapeo en determinacion de cuentas
          TYPES: BEGIN OF ty_cs_ap_pandl_no_map,
                   idl2 TYPE zi_intercopandlhierflattened-idl2,
                 END OF ty_cs_ap_pandl_no_map.
          DATA lt_cs_ap_pandl_no_map TYPE STANDARD TABLE OF ty_cs_ap_pandl_no_map WITH EMPTY KEY.

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
                  AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ap
                  AND tarifftype          = '6'
                  AND isdeleted           = ''
              )
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_ap_pandl_no_map.
          " lt_cs_ap_pandl_no_map cargada → el error se registra en el loop de recipients abajo

          " 2. sharerate por sociedad desde lt_items
          TYPES: BEGIN OF ty_cs_ap_share,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                   sharedrate           TYPE zi_intercoproposalitem-sharedrate,
                 END OF ty_cs_ap_share.

          DATA lt_cs_ap_shares TYPE HASHED TABLE OF ty_cs_ap_share
                               WITH UNIQUE KEY recipientcompanycode.

          LOOP AT lt_items INTO DATA(ls_pi_ap_share).
            IF ls_pi_ap_share-sharedrate <> 0 AND
               NOT line_exists( lt_cs_ap_shares[ recipientcompanycode = ls_pi_ap_share-recipientcompanycode ] ).
              INSERT VALUE #(
                recipientcompanycode = ls_pi_ap_share-recipientcompanycode
                sharedrate           = ls_pi_ap_share-sharedrate
              ) INTO TABLE lt_cs_ap_shares.
            ENDIF.
          ENDLOOP.

          " 3. ordenar cuentas para residuo deterministico
          DATA lt_ap_base_sorted TYPE STANDARD TABLE OF ty_cs_ap_base_l2 WITH EMPTY KEY.
          lt_ap_base_sorted = VALUE #( FOR ls_b IN lt_cs_ap_base_l2 ( ls_b ) ).
          SORT lt_ap_base_sorted BY glaccount1.
          DATA(lv_ap_rows_cuentas) = lines( lt_ap_base_sorted ).

          " 4. total BRL por sociedad desde lt_baogl (para residuo en ultima cuenta)
          TYPES: BEGIN OF ty_cs_ap_brl_soc,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                   total_brl            TYPE zint_dte_fis_ksl,
                   transactioncurrency  TYPE zint_dte_fis_hwaer,
                   exchangerate         TYPE zint_dte_ukurs,
                 END OF ty_cs_ap_brl_soc.

          DATA lt_cs_ap_brl_soc TYPE HASHED TABLE OF ty_cs_ap_brl_soc
                                WITH UNIQUE KEY recipientcompanycode.

          SELECT recipientcompanycode,
                 SUM( amountintcurr ) AS total_brl,
                 transactioncurrency,
                 exchangerate
            FROM @lt_baogl AS b
            GROUP BY recipientcompanycode, transactioncurrency, exchangerate
            INTO CORRESPONDING FIELDS OF TABLE @lt_cs_ap_brl_soc.

          " 5. expandir lt_baogl: 1 fila/sociedad → N filas/cuenta_CS
          DATA lt_baogl_cs LIKE lt_baogl.

          TYPES: BEGIN OF ty_cs_ap_procesadas,
                   recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                 END OF ty_cs_ap_procesadas.
          DATA lt_socs_ap_procesadas TYPE HASHED TABLE OF ty_cs_ap_procesadas
                                     WITH UNIQUE KEY recipientcompanycode.

          LOOP AT lt_baogl INTO DATA(ls_baogl_orig).
            DATA(lv_soc_ap) = ls_baogl_orig-recipientcompanycode.
            CHECK NOT line_exists( lt_socs_ap_procesadas[ recipientcompanycode = lv_soc_ap ] ).
            INSERT VALUE #( recipientcompanycode = lv_soc_ap ) INTO TABLE lt_socs_ap_procesadas.

            TRY.
                DATA(ls_share_ap) = lt_cs_ap_shares[ recipientcompanycode = lv_soc_ap ].
              CATCH cx_sy_itab_line_not_found.
                CONTINUE.
            ENDTRY.
            DATA(lv_sharerate_ap) = CONV decfloat34( ls_share_ap-sharedrate ) / 100.

            TRY.
                DATA(ls_brl_ap) = lt_cs_ap_brl_soc[ recipientcompanycode = lv_soc_ap ].
              CATCH cx_sy_itab_line_not_found.
                CONTINUE.
            ENDTRY.
            DATA(lv_total_brl_ap) = CONV decfloat34( ls_brl_ap-total_brl ).

            DATA(lv_sum_ap) = CONV decfloat34( 0 ).

            DO lv_ap_rows_cuentas TIMES.
              READ TABLE lt_ap_base_sorted INTO DATA(ls_base_ap) INDEX sy-index.

              DATA(ls_new_ap) = ls_baogl_orig.
              ls_new_ap-base_gl             = ls_base_ap-glaccount1.
              ls_new_ap-transactioncurrency = ls_brl_ap-transactioncurrency.
              ls_new_ap-exchangerate        = ls_brl_ap-exchangerate.

              DATA lv_importe_ap TYPE decfloat34.
              IF sy-index < lv_ap_rows_cuentas.
                " formula: base_BRL_L2 x sharerate
                lv_importe_ap = ls_base_ap-base_brl * lv_sharerate_ap.
                lv_sum_ap += lv_importe_ap.
              ELSE.
                " ultima cuenta: absorbe residuo para total exacto
                lv_importe_ap = lv_total_brl_ap - lv_sum_ap.
              ENDIF.

              ls_new_ap-amountintcurr = lv_importe_ap.

              APPEND ls_new_ap TO lt_baogl_cs.
            ENDDO.

          ENDLOOP.
          lt_baogl = lt_baogl_cs.

        ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AP v2

        DATA lv_ap_err_datetime TYPE zfi_a_intrc_cpid-createdat.
        DATA lv_ap_err_ts       TYPE zfi_a_intrc_cpid-createdat.

        "Deja solo aquellos registros diferentes a cero.
        DELETE lt_items WHERE b_amountinglobalcurrency EQ 0.

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AP: salida anticipada si P&L sin mapeo
        IF mv_is_cs = abap_true AND lt_cs_ap_pandl_no_map IS NOT INITIAL.
          DATA(lv_ap_pandl_list) = REDUCE string(
            INIT s = ``
            FOR ls_no_map IN lt_cs_ap_pandl_no_map
            NEXT s = COND #( WHEN s IS INITIAL
                             THEN ls_no_map-idl2
                             ELSE |{ s }, { ls_no_map-idl2 }| ) ).
          LOOP AT lt_items INTO DATA(ls_ap_err_item_pre)
               GROUP BY ls_ap_err_item_pre-recipientcompanycode INTO DATA(lv_recipient_err).
            READ TABLE lt_items INTO DATA(ls_ap_err_item) WITH KEY recipientcompanycode = lv_recipient_err.
            DATA(lv_ap_err_dockey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }{ lv_recipient_err }|.
            APPEND VALUE #(
              id                     = ls_ap_err_item-id
              item_id                = ls_ap_err_item-item_id
              itembasis_id           = ls_ap_err_item-itembasis_id
              itemcalc_id            = ls_ap_err_item-itemcalc_id
              documenttype           = zcl_proposal_bo_abs=>c_document_type-je_purchase
              documentkey            = lv_ap_err_dockey
              companycode            = lv_recipient_err
              status                 = zcl_proposal_bo_abs=>c_document_status-error
            ) TO gt_doc_map.
            add_msg_to_log(
              iv_current_item = CORRESPONDING #( ls_ap_err_item )
              iv_dockey       = lv_ap_err_dockey
              iv_doctype      = mv_posting_doctype
              iv_message_type = 'E'
              iv_message_text = |CS AP: P&L sin cuenta asignada: { lv_ap_pandl_list } (producto { gs_header-product }).|
            ).
          ENDLOOP.
          GET TIME STAMP FIELD lv_ap_err_ts.
          mapping_doc(
            EXPORTING
              iv_doctype                = zcl_proposal_bo_abs=>c_document_type-je_purchase
              iv_status                 = zcl_proposal_bo_abs=>c_document_status-error
              iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
              iv_accountingdocumenttype = 'IR'
              iv_isadjustment           = space
              its_doc                   = gts_doc
              iv_byuser                 = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
              iv_attime                 = lv_ap_err_ts
            CHANGING
              ct_map_id_doc             = gt_doc_map ).
          et_doc_map = gt_doc_map.
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit
            EXPORTING
              textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AP: salida anticipada si P&L sin mapeo

        "1. Agrupa por recipientcompanycode y realiza sumatoria.
        LOOP AT lt_items INTO DATA(ls_items)
             GROUP BY ls_items-recipientcompanycode INTO DATA(recipient).

          APPEND INITIAL LINE TO journal_entries REFERENCE INTO DATA(journal_entry).
          journal_entry->%cid = |AP{ sy-tabix }|.

          DATA(lv_baseamount) = REDUCE wrbtr(
                                INIT acc = VALUE #( )
                                FOR row IN GROUP recipient
                                NEXT acc = acc + row-amountintrasactioncurrency ).

          DATA(lv_markupamount) = REDUCE wrbtr(
                                 INIT acc = VALUE #( )
                                 FOR row IN GROUP recipient
                                 NEXT acc = acc + row-mkupamntintcurr ).

          DATA(lv_grossamount) = REDUCE wrbtr(
                                 INIT acc = VALUE #( )
                                 FOR row IN GROUP recipient
                                 NEXT acc = acc + row-gupmamntintcurr ).

          DATA(lv_grossbaseamount) = REDUCE wrbtr(
                                 INIT acc = VALUE #( )
                                 FOR row IN GROUP recipient
                                 NEXT acc = acc + row-gupbamntintcurr ).

          DATA(lv_paymentamount) = REDUCE wrbtr(
                                 INIT acc = VALUE #( )
                                 FOR row IN GROUP recipient
                                 NEXT acc = acc + row-intmamntintcurr ).

          DATA(lv_provideramount) = REDUCE wrbtr(
                                 INIT acc = VALUE #( )
                                 FOR row IN GROUP recipient
                                 NEXT acc = acc + row-guppamntintcurr ).

          lv_totalamount = lv_baseamount + lv_markupamount + lv_grossamount + lv_grossbaseamount + lv_paymentamount + lv_provideramount.
          IF lv_totalamount >= 0.
            DATA(lv_doctype) = 'IR'.
          ELSE.
            lv_doctype = 'AJ'.
          ENDIF.

          journal_entry->%param-accountingdocumenttype = lv_doctype.
          journal_entry->%param-createdbyuser = sy-uname.
          journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient } { gs_header-productname }|.
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AP: codigo material en referencia cabecera
          IF mv_is_cs = abap_true.
            journal_entry->%param-documentreferenceid = gs_header-product.
          ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AP: codigo material en referencia cabecera
          journal_entry->%param-businesstransactiontype = 'RFBU'.
          journal_entry->%param-documentdate = last_day_of_month.
          journal_entry->%param-postingdate = last_day_of_month.

          lv_totalamount = lv_totalamount * -1.

*Ini EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026
*   Para MLA/ARS: usar método dedicado con CPIC como fuente de montos ARS
*   (misma fuente que ZCL_PROPOSAL_BO_AR) → IC0122 = IC0213 exacto.
*   Para el resto: mantener process_baogl_for_company sin cambios.
          READ TABLE lt_baogl INTO DATA(ls_baogl_curr_ars)
                                WITH KEY recipientcompanycode = recipient.
***          IF sy-uname = 'EXT_OSCUGALD'
***            AND sy-subrc = 0
***            AND ls_baogl_curr_ars-companycodecurrency = 'ARS'.
          IF gs_header-providercompanycode = 'MLA'
                      AND sy-subrc = 0
                      AND gs_header-providercountry = ls_baogl_curr_ars-recipientcountry.
            " Filtrar lt_cpic_ars por profitcenter del recipient
            " item_id en BAOGL (Genova split) difiere del item_id en CPIC (provider)
            " profitcenter es el campo correcto para correlacionar ambas fuentes
            DATA lt_cpic_recipient TYPE tt_cpic.
            CLEAR lt_cpic_recipient.

            IF lt_baogl_mla IS NOT INITIAL.
*             Génova: lt_cpic_ars tiene recipientcompanycode → filtro directo sin ambigüedad.
              lt_cpic_recipient = VALUE tt_cpic(
                FOR cpic IN lt_cpic_ars
                WHERE ( recipientcompanycode = recipient )
                ( cpic ) ).
            ELSE.
*             No Génova: filtrar por item_id de lt_baogl para este recipient.
              DATA lt_ids_recip TYPE RANGE OF zde_prop_item_id.
              lt_ids_recip = VALUE #(
                FOR b IN lt_baogl
                WHERE ( recipientcompanycode = recipient )
                ( sign = 'I' option = 'EQ' low = b-item_id ) ).
              DELETE ADJACENT DUPLICATES FROM lt_ids_recip COMPARING low.
              lt_cpic_recipient = VALUE tt_cpic(
                FOR cpic IN lt_cpic_ars
                WHERE ( item_id IN lt_ids_recip )
                ( cpic ) ).
              CLEAR lt_ids_recip.
            ENDIF.

            CALL METHOD me->process_baogl_for_company_ars
              EXPORTING
                iv_currentitem    = ls_item
                iv_recipient      = recipient
                iv_totalamount    = lv_totalamount
                iv_account        = lv_account
                it_exchange_rates = lt_exchange_rates
                it_cpic           = lt_cpic_recipient
              IMPORTING
                ev_totalimp       = lv_totalimp
                et_glitems        = lt_glitems
                et_taxitems       = lt_taxitems
                et_itemscalc      = items_calc
              CHANGING
                ct_baogl          = lt_baogl.

          ELSE.
            "Proceso determinación de cuentas y cecos a imputar. Armado estructuras _GLITEMS, _TAXITEMS
            CALL METHOD me->process_baogl_for_company
              EXPORTING
                iv_currentitem = ls_item
                iv_recipient   = recipient
                iv_totalamount = lv_totalamount
                iv_account     = lv_account
*               it_exchange_rates = lt_exchange_rates
              IMPORTING
                ev_totalimp    = lv_totalimp
                et_glitems     = lt_glitems
                et_taxitems    = lt_taxitems
                et_itemscalc   = items_calc
              CHANGING
                ct_baogl       = lt_baogl.
          ENDIF.
*Fin EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026

          journal_entry->%param-_glitems  = lt_glitems.
          journal_entry->%param-_taxitems = lt_taxitems.

          "Sino existe glitems no es necesario crear el doc.
          IF lt_glitems[] IS INITIAL.
            CLEAR journal_entries.
            CONTINUE.
          ENDIF.

          "2. Por cada item_id de la propuesta busca sus tarifas y cecos a imputar
          DATA(is_first) = abap_true.
          LOOP AT GROUP recipient REFERENCE INTO FINAL(grouped_item).

            IF is_first = abap_true.

              "CompanyCode
              IF grouped_item->flow EQ gc_outflow.
                DATA(lv_companycode) = recipient.
                DATA(lv_supplier) = grouped_item->providervendor.
              ELSEIF grouped_item->flow EQ gc_inflow.
                lv_companycode = gs_header-providercompanycode.
                lv_supplier = grouped_item->recipientcustomer.
              ENDIF.
              journal_entry->%param-companycode = lv_companycode.

              "Llena estructura de Proveedor _APItems
              APPEND INITIAL LINE TO journal_entry->%param-_apitems REFERENCE INTO DATA(ap_item).
              DATA(lv_count_gl) = lines( lt_glitems ).
              DATA(lv_count_tax) = lines( lt_taxitems ).
              ap_item->glaccountlineitem = lv_count_gl + lv_count_tax + 1.
              ap_item->supplier = grouped_item->providercustomer.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: assignment = 'COST SHARING' (Z00077)
              ap_item->assignmentreference = COND #( WHEN mv_is_cs = abap_true
                                                                   THEN 'COST SHARING'
                                                                   ELSE gs_header-productname ).
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
              ap_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.

              APPEND INITIAL LINE TO ap_item->_currencyamount REFERENCE INTO DATA(ap_item_amount).
              ap_item_amount->currency = grouped_item->transactioncurrency.
              ap_item_amount->journalentryitemamount = lv_totalimp.
**Ini EXT_OSCUGALD 29.04.2026 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
**[AJUSTE-1] Usar el tipo de cambio obtenido desde i_exchangeraterawdata con abs() en lugar del campo
**exchangerate de grouped_item (que viene de ct_baogl y puede tener diferente precisión de redondeo).
**Esto elimina la diferencia de 0.01 en KSL observada entre AR y AP.
**ANTES: ap_item_amount->exchangerate = grouped_item->exchangerate.
***              IF sy-uname EQ 'EXT_OSCUGALD'.
              IF gs_header-providercompanycode = 'MLA'.
                TRY.
*                   Buscar por companycodecurrency (= sourcecurrency del JOIN en lt_exchange_rates)
*                   igual que el AR usa companycodecurrency/globalcurrency en su lookup.
*                   ANTES: sourcecurrency = transactioncurrency → fallaba para USD receivers
*                   AHORA: sourcecurrency = companycodecurrency → siempre ARS/BRL/MXN/etc.
                    DATA(lv_ap_exchange_rate) = lt_exchange_rates[
                      sourcecurrency = grouped_item->companycodecurrency    "◄◄◄ CAMBIAR
                      targetcurrency = grouped_item->globalcurrency ]-exchangerate.
                  CATCH cx_sy_itab_line_not_found.
                    lv_ap_exchange_rate = grouped_item->exchangerate. " fallback: valor original
                ENDTRY.
                ap_item_amount->exchangerate = lv_ap_exchange_rate.   "[AJUSTE-1]
              ELSE.
                ap_item_amount->exchangerate = grouped_item->exchangerate.
              ENDIF.
**Fin EXT_OSCUGALD 29.04.2026 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
              ap_item_amount->currencyrole = '00'.

              "Determinación de impuesto de retención BRF+
              DATA(lt_wht_code) = me->get_wht_codes_brf(
                iv_aplineitem  = ap_item->glaccountlineitem
                iv_cid_invoice = journal_entry->%cid
                iv_supplier    = lv_supplier
                iv_companycode = lv_companycode
                iv_provider    = grouped_item->providercompanycode
                iv_recipient   = grouped_item->recipientcompanycode
                iv_product     = gs_header-product
                iv_currency    = grouped_item->transactioncurrency
                it_wht         = lt_wht ).

              journal_entry->%param-_withholdingtaxitems = lt_wht_code.

              is_first = abap_false.
            ENDIF.

            APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc>).
            <fs_doc>-id = grouped_item->id.
            <fs_doc>-item_id = grouped_item->item_id.
            <fs_doc>-itembasis_id = grouped_item->itembasis_id.
            <fs_doc>-itemcalc_id = grouped_item->itemcalc_id.
            <fs_doc>-documentkey = |DUMMY{ grouped_item->documentkey }{ grouped_item->providercompanycode }{ grouped_item->product }{ grouped_item->recipientcompanycode }|.
            <fs_doc>-documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase.

          ENDLOOP.
          gta_je_post = journal_entries.

          IF  gs_header-providercountry = 'BR' AND
            grouped_item->recipientcountry = 'BR'.
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación AP
            DATA(lo_ap_je) = NEW zcl_proposal_bo_ap_parallel(
              iv_process           = gv_process
              its_doc              = gts_doc
              it_doc_map           = gt_doc_map
              it_je_post           = gta_je_post
              iv_provider_cc       = gs_header-providercompanycode
              iv_provider_country  = gs_header-providercountry
              iv_recipient_country = grouped_item->recipientcountry
              iv_product           = gs_header-product ).
*Fin EXT_OSCUGALD - Validación CECOs Brasil en simulación AP
          ELSE.
            lo_ap_je = NEW zcl_proposal_bo_ap_parallel( iv_process = gv_process
                                                        its_doc    = gts_doc
                                                        it_doc_map = gt_doc_map
                                                        it_je_post = gta_je_post ).
          ENDIF.
          INSERT lo_ap_je INTO TABLE gtd_list_bo.
          CLEAR: gts_doc, gt_doc_map, gta_je_post, journal_entries, lt_glitems, lt_taxitems.

          FREE: gt_doc_map.
          CLEAR: lv_baseamount, lv_markupamount, lv_grossamount, lv_grossbaseamount, lv_paymentamount, lv_provideramount, lv_totalamount, lv_totalimp.
        ENDLOOP.

        CHECK gtd_list_bo IS NOT INITIAL.
        exe_bo( ). "Return the data on me->gt_doc_map
        et_doc_map = me->gt_doc_map.

        IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ) OR
           line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
      CATCH:
            cx_sy_conversion_no_date INTO DATA(cx_date),
            cx_sy_itab_line_not_found INTO DATA(cx_line_not_found).
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
*      DATA(lv_posting_date) = lt_posting_date[ fiscalyear = gs_header-fiscalyear companycode = <fs_doc>-companycode accountingdocument = <fs_doc>-documentkey ].
      READ TABLE lt_posting_date WITH KEY fiscalyear = gs_header-fiscalyear
                                       companycode = <fs_doc>-companycode
                                       accountingdocument = <fs_doc>-documentkey
                                       INTO DATA(ls_posting_date_line).
      IF sy-subrc = 0.
        DATA(lv_posting_date) = ls_posting_date_line-postingdate.
      ENDIF.
      CLEAR: gta_jr_rev,gt_doc_map.

      CHECK NOT line_exists( gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ] )
      OR gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ]-documentkey(5) EQ 'DUMMY'.

      APPEND INITIAL LINE TO gta_jr_rev ASSIGNING FIELD-SYMBOL(<jr>).

      <jr>-companycode = <fs_doc>-companycode.
      <jr>-fiscalyear  = gs_header-fiscalyear.
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
      <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_je_purch.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_ap_parallel( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
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
    DELETE gtd_items_add WHERE interdivisional = abap_true OR with_po = abap_true.

    SELECT SINGLE low FROM zi_tvarvc
  WHERE name = 'ZINTERCO_ROUNDING_TOLERANCE'
  INTO @DATA(param_tolerance).
    IF sy-subrc = 0.
      v_tolerance = param_tolerance.
    ENDIF.
  ENDMETHOD.


  METHOD process_baogl_for_company.
    TYPES: BEGIN OF ty_cccode,
             id                        TYPE uuid,
             item_id                   TYPE zde_prop_item_id,
             recipientcompanycode      TYPE bukrs,
             recipientcountry          TYPE land1,
             cc_code                   TYPE n LENGTH 10,
             profitcenter              TYPE prctr,
             exchangerate              TYPE zint_dte_ukurs,
             transactioncurrency       TYPE zint_dte_fis_hwaer,
             amountinglobalcurrency    TYPE zint_dte_fis_ksl,
             base                      TYPE zde_markup_rate,
             markup                    TYPE zde_markup_rate,
             grossingupbase            TYPE zde_grup_rate,
             grossingupmargin          TYPE zde_grupmargin_rate,
             latepaymentinterest       TYPE zde_lpin_rate,
             providergrossingup        TYPE zde_pgup_rate,
             markupamount              TYPE zde_markup_amount,
             grossingupbaseamount      TYPE zde_grup_amount,
             grossingupmarginamount    TYPE zde_grupmargin_amount,
             latepaymentinterestamount TYPE zint_dte_fis_ksl,
             providergrossingupamount  TYPE zint_dte_fis_ksl,
             base_gl                   TYPE saknr,
             mkup_gl                   TYPE saknr,
             gupk_gl                   TYPE saknr,
             gupb_gl                   TYPE saknr,
             intm_gl                   TYPE saknr,
             gupp_gl                   TYPE saknr,
           END OF ty_cccode.
    DATA: lt_cc_code TYPE STANDARD TABLE OF ty_cccode WITH EMPTY KEY,
          ls_cc_code TYPE ty_cccode.

    TYPES: ty_item_id_tab TYPE STANDARD TABLE OF zde_prop_item_id WITH EMPTY KEY.

    TYPES: BEGIN OF ty_cccode_summary,
             id                  TYPE uuid,
             item_id             TYPE zde_prop_item_id,
             recipientcountry    TYPE land1,
             cc_code             TYPE n LENGTH 10,
             profitcenter        TYPE prctr,
             exchangerate        TYPE zint_dte_ukurs,
*             item_ids          TYPE ty_item_id_tab,
             base                TYPE zde_markup_rate,
             markup              TYPE zde_markup_rate,
             grossingupbase      TYPE zde_grup_rate,
             grossingupmargin    TYPE zde_grupmargin_rate,
             latepaymentinterest TYPE zde_lpin_rate,
             providergrossingup  TYPE zde_pgup_rate,
             transactioncurrency TYPE zint_dte_fis_hwaer,
             global_sum          TYPE zint_dte_fis_ksl,
             markup_sum          TYPE zde_markup_amount,
             grossbase_sum       TYPE zde_grup_amount,
             grossmargin_sum     TYPE zde_grupmargin_amount,
             latepayment_sum     TYPE zint_dte_fis_ksl,
             providergross_sum   TYPE zint_dte_fis_ksl,
             base_gl             TYPE saknr,
             mkup_gl             TYPE saknr,
             gupk_gl             TYPE saknr,
             gupb_gl             TYPE saknr,
             intm_gl             TYPE saknr,
             gupp_gl             TYPE saknr,
           END OF ty_cccode_summary.

    TYPES: BEGIN OF ty_baogl_summary,
             id      TYPE uuid,
             item_id TYPE zde_prop_item_id,

           END OF ty_baogl_summary.
    TYPES:
      BEGIN OF ty_glitem_mapping,
        tariffrate   TYPE string,
        amount_field TYPE string,
        gl_account   TYPE string,
      END OF ty_glitem_mapping,
      tt_glitem_mapping TYPE TABLE OF ty_glitem_mapping WITH KEY tariffrate.
    CONSTANTS: c_fields TYPE i VALUE 6. "Cantidad de posibles cuentas de mayor

    DATA: lt_cccode_summary TYPE STANDARD TABLE OF ty_cccode_summary WITH EMPTY KEY.
    DATA: ls_cccode_summary TYPE ty_cccode_summary.
    DATA: lt_glitems TYPE gsty_post-%param-_glitems.
    DATA: lt_taxitems TYPE gsty_post-%param-_taxitems.
    DATA lv_totalbaoamount TYPE wrbtr.
    DATA lv_totalimpuesto TYPE wrbtr.
    DATA(calc_taxes) = zcl_calculate_taxes_net_fact=>create_instance( ).
    DATA tax_items_in TYPE zif_calculate_taxes_net=>_rtax1u38.
    DATA tax_items_out TYPE zif_calculate_taxes_net=>_rtax1u38.
    DATA error_return TYPE zif_calculate_taxes_net=>_bapiret2.

    DATA(gl_item_mappings) = VALUE tt_glitem_mapping(
                     ( tariffrate = 'BASE'                amount_field = 'GLOBAL_SUM'        gl_account = 'BASE_GL' )
                     ( tariffrate = 'MARKUP'              amount_field = 'MARKUP_SUM'        gl_account = 'MKUP_GL' )
                     ( tariffrate = 'GROSSINGUPMARGIN'    amount_field = 'MARGIN_SUM'        gl_account = 'GUPK_GL' )
                     ( tariffrate = 'GROSSINGUPBASE'      amount_field = 'BASE_SUM'          gl_account = 'GUPB_GL' )
                     ( tariffrate = 'LATEPAYMENTINTEREST' amount_field = 'LATEPAYMENT_SUM'   gl_account = 'INTM_GL' )
                     ( tariffrate = 'PROVIDERGROSSINGUP'  amount_field = 'PROVIDERGROSS_SUM' gl_account = 'GUPP_GL' )
    ).
    "Ajustes modelo contable (new requirement Ago2025)
    FINAL(valid_at) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
    DATA(doc_account) = NEW zcl_interco_doc_glaccount(
      i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-ap
      i_product               = gs_header-product
      i_provider_company_code = gs_header-providercompanycode
      i_valid_at              = valid_at ).

*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via atributos de clase
    " Valores precargados en mapping_bo_sec antes del loop principal
    " para evitar SELECTs anidados en loops — resuelve ATC NonLocal Nested DB OP
    DATA(lv_is_cs)          = mv_is_cs.
    DATA(lv_cs_ceco_prefix) = mv_cs_ceco_prefix.
    DATA(lv_cs_cebe)        = mv_cs_cebe.
    DATA lv_internalcode    TYPE c LENGTH 3.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

    "1. Consultar BRF+ Ceco a imputar y complementa tabla auxiliar.
    LOOP AT ct_baogl ASSIGNING FIELD-SYMBOL(<ls_baogl>) WHERE recipientcompanycode = iv_recipient.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
      IF lv_is_cs = abap_true.
*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: CeCo usa internalcode de soc. RECEPTORA
        " AP postea en la soc. receptora => CeCo debe ser de ESA sociedad
        " KI100/KI302 si se usa internalcode del provider (MLB=123 en soc. EBA/IFB/MPB/SOC)
        READ TABLE mt_cs_companies INTO DATA(ls_cs_company_ap)
                  WITH KEY companycode = <ls_baogl>-recipientcompanycode.
        lv_internalcode = COND #(
          WHEN sy-subrc = 0 AND ls_cs_company_ap-internalcode IS NOT INITIAL
          THEN ls_cs_company_ap-internalcode
          ELSE <ls_baogl>-internalcode ).
        <ls_baogl>-costcenter =
          |{ lv_cs_ceco_prefix }{ lv_internalcode }{ lv_cs_cebe }|.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
      ELSE.

        DATA(lo_brf_helper) = NEW zcl_interco_brf_wht( ).
        DATA(lv_cccode) = lo_brf_helper->get_cc_code(
          iv_product      = <ls_baogl>-product
          iv_cc_origen    = <ls_baogl>-costcenterd4
          iv_departamento = <ls_baogl>-department
          iv_tipo_doc     = zcl_interco_doc_glaccount=>co_doc_type-ap
        ).
        IF lv_cccode IS NOT INITIAL.
          "Se obtiene CeCo Destino
*          DATA(lv_internalcode) = <ls_baogl>-internalcode.
          lv_internalcode = <ls_baogl>-internalcode.
          <ls_baogl>-costcenter = |{ lv_cccode }{ <ls_baogl>-internalcode }{ <ls_baogl>-profitcenter ALPHA = OUT }|.
          READ TABLE et_itemscalc INTO DATA(ls_profit_center) WITH KEY id = <ls_baogl>-id
                                                                       item_id = <ls_baogl>-item_id
                                                                       product = <ls_baogl>-product.
          IF ls_profit_center-profitcentereq IS NOT INITIAL.
            <ls_baogl>-costcenter = |{ lv_cccode }{ <ls_baogl>-internalcode }{ ls_profit_center-profitcentereq ALPHA = OUT }|.
            <ls_baogl>-costcenter+7(3) = ls_profit_center-profitcentereq.
          ENDIF.
        ELSE.
          CLEAR <ls_baogl>-costcenter.
        ENDIF.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing
      ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

      "Obtiene cuenta GL" Account determination
      IF gs_header-providercountry = <ls_baogl>-recipientcountry.
        DATA(lv_optype) = zcl_interco_doc_glaccount=>co_operation_type-local.
      ELSE.
        lv_optype = zcl_interco_doc_glaccount=>co_operation_type-foreign.
      ENDIF.
*Ini EXT_OSCUGALD 07.09.2026 - Fix AP ICSRV52: account_determination usar IDL2 en vez de IDL3
      " Motivo: mismo problema que en ZCL_PROPOSAL_BO_AR (ver fix 07.09.2026 en esa clase).
      " El maestro ZI_INTERCOGLACCTDETERMINATION para servicios con desglose fino por
      " P&L (ej. ICSRV52) esta parametrizado a nivel IDL2, no IDL3.
      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-basis "06 basis
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_basis_gl)
      ).

      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-markup "01 markup
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_markup_gl)
      ).

      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-grossup_basis "02 grossup_basis
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_gupb_gl)
      ).

      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-grossup_margin "03 grossup_margin
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_gupk_gl)
      ).

      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-late_payment_intereset  "04 late_payment_intereset
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_intm_gl)
      ).

      doc_account->get(
        EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-provider_grossup  "05 provider_grossup
                  i_department    = <ls_baogl>-department
                  i_pandlid       = <ls_baogl>-idl2
*                    i_pandlid       = <ls_baogl>-idl3
                  i_operationtype = lv_optype
        RECEIVING result          = DATA(ls_gupp_gl)
      ).
*Fin EXT_OSCUGALD 07.09.2026 - Fix AP ICSRV52: account_determination usar IDL2 en vez de IDL3
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix AP: preservar base_gl correcto desde lt_baogl_cs
      IF lv_is_cs = abap_true.
        <ls_baogl>-base_gl = <ls_baogl>-base_gl.
      ELSE.
        <ls_baogl>-base_gl = ls_basis_gl-glaccount1.
      ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix AP
      <ls_baogl>-mkup_gl = ls_markup_gl-glaccount1.
      <ls_baogl>-gupb_gl = ls_gupb_gl-glaccount1.
      <ls_baogl>-gupk_gl = ls_gupk_gl-glaccount1.
      <ls_baogl>-intm_gl = ls_intm_gl-glaccount1.
      <ls_baogl>-gupp_gl = ls_gupp_gl-glaccount1.

      "Modify tariff rates to be used in percentage
      <ls_baogl>-markup               = <ls_baogl>-markup / 100.
      <ls_baogl>-grossingupbase       = <ls_baogl>-grossingupbase / 100.
      <ls_baogl>-grossingupmargin     = <ls_baogl>-grossingupmargin / 100.
      <ls_baogl>-latepaymentinterest  = <ls_baogl>-latepaymentinterest / 100.
      <ls_baogl>-providergrossingup   = <ls_baogl>-providergrossingup / 100.
    ENDLOOP.

**********************************************************************
    "2. Hacer cortes por ceco a imputar / cuenta base para armar el asiento, realizar sumatoria
    SELECT
       id,
       item_id,
       recipientcompanycode,
       recipientcountry,
       department,
       base,
       markup,
       grossingupbase,
       grossingupmargin,
       latepaymentinterest,
       providergrossingup,
       profitcenter,
       costcenter,
       base_gl,
       mkup_gl,
       gupb_gl,
       gupk_gl,
       intm_gl,
       gupp_gl,
       SUM( amountintcurr ) AS global_sum,
       SUM( markupamount ) AS markup_sum,
       SUM( grossingupbaseamount ) AS base_sum,
       SUM( grossingupmarginamount ) AS margin_sum,
       SUM( latepaymentinterestamount ) AS latepayment_sum,
       SUM( providergrossingupamount ) AS providergross_sum,
       transactioncurrency,
       exchangerate,
       product
    FROM @ct_baogl AS _baogl
    WHERE recipientcompanycode EQ @iv_recipient
    GROUP BY
      id,
      item_id,
      recipientcompanycode,
      recipientcountry,
      department,
       base,
       markup,
       grossingupbase,
       grossingupmargin,
       latepaymentinterest,
       providergrossingup,
       profitcenter,
       costcenter,
       base_gl,
       mkup_gl,
       gupb_gl,
       gupk_gl,
       intm_gl,
       gupp_gl,
      transactioncurrency,
      exchangerate,
      product
    HAVING ( SUM( amountintcurr ) +
           SUM( markupamount ) +
           SUM( grossingupbaseamount ) +
           SUM( grossingupmarginamount ) +
           SUM( latepaymentinterestamount ) +
           SUM( providergrossingupamount ) ) <> 0  "evita valores en ceros
    INTO TABLE @DATA(lt_baogl_summary).

    SELECT SUM( global_sum + markup_sum + base_sum + margin_sum + latepayment_sum + providergross_sum )
    AS lv_totalbaoamount
    FROM @lt_baogl_summary AS _total_baogl
    INTO @lv_totalbaoamount.

**********************************************************************
***    IF sy-uname = 'EXT_OSCUGALD'.
    "evita valores en ceros
    IF lv_totalbaoamount = 0.
      RETURN.
    ENDIF.
    "evita valores en ceros
***    ENDIF.
**********************************************************************

    "Consulta BRF+ Impuestos
    lo_brf_helper = NEW zcl_interco_brf_wht( ).
    DATA lv_tax_code TYPE c LENGTH 2.
    lo_brf_helper->get_tax_code(
      EXPORTING
        iv_provider   = gs_header-providercompanycode
        iv_recipient  = iv_recipient
        iv_product    = gs_header-product
      IMPORTING
        ev_taxcode_ap = lv_tax_code
    ).

    zcl_interco_utils=>unit_code_outbound( EXPORTING im_value = '%'
                                           IMPORTING ex_value = FINAL(base_unit) ).

    DATA lv_line_id TYPE n LENGTH 6 VALUE 1. "Contador global para GLAccountLineItem
    DATA lv_fwbas TYPE fwbas.
    DATA lv_profitcenter TYPE c LENGTH 10.

    "Arma una posición por cada combinación de cuenta base-tarifas-centro de costo
    "Si es el caso agrega impuesto
    LOOP AT lt_baogl_summary INTO DATA(ls_cccode_sumary).
      CLEAR lv_profitcenter.
      DO lines( gl_item_mappings ) TIMES.
        FINAL(gl_item_mapping) = REF #( gl_item_mappings[ sy-index ] ).

        ASSIGN COMPONENT gl_item_mapping->amount_field OF STRUCTURE ls_cccode_sumary TO FIELD-SYMBOL(<amount_field>).
        IF <amount_field> IS ASSIGNED AND <amount_field> = 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT gl_item_mapping->gl_account OF STRUCTURE ls_cccode_sumary TO FIELD-SYMBOL(<gl_account_field>).
        IF <gl_account_field> IS ASSIGNED AND <gl_account_field> EQ space.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT gl_item_mapping->tariffrate OF STRUCTURE ls_cccode_sumary TO FIELD-SYMBOL(<tariffrate_field>).
        IF <tariffrate_field> IS ASSIGNED AND <tariffrate_field> IS INITIAL.
          CONTINUE.
        ENDIF.
        IF <amount_field> = 0.
          CONTINUE.
        ENDIF.
        READ TABLE et_itemscalc INTO ls_profit_center WITH KEY id = ls_cccode_sumary-id
                                                          item_id = ls_cccode_sumary-item_id
                                                          product = ls_cccode_sumary-product.
        IF ls_profit_center-profitcentereq IS NOT INITIAL.
*          lv_profitcenter = |{ ls_profit_center-profitcentereq WIDTH = 10 PAD = '0' }|.
          lv_profitcenter = ls_profit_center-profitcentereq.
        ELSE.
          lv_profitcenter = ls_cccode_sumary-profitcenter.
        ENDIF.

        DATA(ls_glitems) = VALUE gsty_glitems( glaccountlineitem   = lv_line_id
                                               glaccount           = <gl_account_field>
*                                               profitcenter        = ls_cccode_sumary-profitcenter
                                               profitcenter        = lv_profitcenter
                                               costcenter          = ls_cccode_sumary-costcenter
                                               documentitemtext    = |{ gs_header-providercompanycode }-{ ls_cccode_sumary-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|
                                               material            = gs_header-product
                                               assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                                             THEN 'COST SHARING'
                                                                             ELSE gs_header-productname )
                                               taxcode             = lv_tax_code "Indicador de impuestos BRF+
                                             ).
        IF gl_item_mapping->tariffrate <> 'BASE'.
          ls_glitems-quantity = <tariffrate_field>.
          ls_glitems-baseunit = base_unit.
        ENDIF.
        APPEND VALUE #(
          journalentryitemamount = <amount_field>
          currency               = ls_cccode_sumary-transactioncurrency
          exchangerate           = ls_cccode_sumary-exchangerate
*            currencyrole           = '00'
        ) TO ls_glitems-_currencyamount.

        lv_line_id += 1. "Incrementa el contador global

        "  Agrega impuestos BR si aplica
        IF   ( gs_header-providercountry    = 'BR' AND ls_cccode_sumary-recipientcountry <> 'BR' )
          OR ( gs_header-providercountry    <> 'BR' AND ls_cccode_sumary-recipientcountry =  'BR' ).

          FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
          TRY.
              DATA(taxbr) = NEW zcl_interco_taxbr(
                i_providercompanycode  = gs_header-providercompanycode
                i_recipientcompanycode = ls_cccode_sumary-recipientcompanycode
                i_product              = gs_header-product
                i_department = ls_cccode_sumary-department
                i_valid_at             = last_day_of_month
              ).

              taxbr->calculate_taxes_net(
                EXPORTING
                  it_glitems = VALUE #( ( ls_glitems ) )
                IMPORTING
                  et_glitems = DATA(new_glitems)
                  ev_total   = DATA(total_taxbr)
              ).

              APPEND LINES OF new_glitems TO lt_glitems.
              lv_totalimpuesto += total_taxbr.
              lv_line_id += lines( new_glitems ).
            CATCH zcx_interco_taxbr.
          ENDTRY.
        ENDIF.


        IF lv_tax_code IS NOT INITIAL.
          "Agrega impuestos si aplica
          tax_items_in = VALUE #(
                                  (
                                  bukrs = iv_recipient
                                  waers = ls_cccode_sumary-transactioncurrency
                                  wrbtr = <amount_field>
                                  mwskz = lv_tax_code )
          ).

          calc_taxes->calculate_taxes_net(
            CHANGING
              error_return = error_return
              tax_item_in  = tax_items_in
              tax_item_out = tax_items_out
          ).

          IF error_return IS INITIAL.
*Ini - Fix ajuste IVA Codes
*            DATA(tax_item_o) = REF #( tax_items_out[ 1 ] ).
            LOOP AT tax_items_out REFERENCE INTO DATA(tax_item_o)
              WHERE waers = ls_cccode_sumary-transactioncurrency.
*Fin - Fix ajuste IVA Codes
              DATA(ls_taxitems) = VALUE gsty_taxitems( glaccountlineitem          = lv_line_id
                                                       taxcode                    = tax_item_o->mwskz
                                                       taxitemclassification      = tax_item_o->ktosl
                                                       conditiontype              = tax_item_o->kschl
                                                       taxjurisdiction            = tax_item_o->txjcd
                                                       taxjurisdictionlevel       = tax_item_o->txjlv
                                                       lowestleveltaxjurisdiction = tax_item_o->txjcd_deep
                                                       taxrate                    = tax_item_o->msatz
                                                       taxdeterminationdate       = tax_item_o->txdat
                                                       taxcountry                 = tax_item_o->tax_country
                                                       taxitemacctgdocitemref     = ls_glitems-glaccountlineitem
                                                     ).
              APPEND VALUE #(
                  journalentryitemamount = tax_item_o->fwste
                  currency               = tax_item_o->waers
                  currencyrole           = '00'
                  taxbaseamount          = tax_item_o->fwbas
                  taxamount              = tax_item_o->fwste
              ) TO ls_taxitems-_currencyamount.
              APPEND ls_taxitems TO lt_taxitems.

              lv_totalimpuesto += tax_item_o->fwste.

              ls_glitems-taxitemacctgdocitemref = ls_taxitems-glaccountlineitem.
              lv_line_id += 1.
*Ini - Fix ajuste IVA Codes
            ENDLOOP.
*Fin - Fix ajuste IVA Codes
          ENDIF.
        ENDIF.
        FREE: error_return, tax_items_in, tax_items_out, lv_fwbas.
        APPEND ls_glitems TO lt_glitems.
      ENDDO.
    ENDLOOP.


    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    DATA: lv_diff TYPE wrbtr.
    DATA: lv_account TYPE hkont.


**Ini EXT_OSCUGALD - Genova: usar suma real de GL items como referencia AP
*    " Para el escenario Génova (cebe 299), iv_totalamount viene de CPIB que solo incluye
*    " montos _C. lv_totalbaoamount viene de CPBG e incluye los _L del split.
*    " Se usa lv_totalbaoamount como referencia para garantizar balance FI.
*    IF iv_is_genova = abap_true AND sy-uname EQ 'EXT_OSCUGALD'.
*      DATA(lv_ap_reference) = lv_totalbaoamount * -1.
*      lv_diff = lv_ap_reference + lv_totalbaoamount.   " = 0 siempre balanceado
*    ELSE.
    lv_diff = iv_totalamount + lv_totalbaoamount.
*    ENDIF.
**Fin EXT_OSCUGALD - Genova: usar suma real de GL items como referencia AP

    "Tolerance 1 USD
    IF gs_header-providercountry EQ ls_cccode_sumary-recipientcountry.
      DATA(lv_diff_ex) = COND wrbtr(
        WHEN ls_cccode_sumary-exchangerate IS INITIAL OR ls_cccode_sumary-exchangerate = 0
        THEN lv_diff
        ELSE CONV wrbtr( lv_diff / ls_cccode_sumary-exchangerate ) ).
    ELSE.
      lv_diff_ex = lv_diff.
    ENDIF.
    IF abs( lv_diff_ex ) <= v_tolerance.
      " Dentro del rango permitido -1,00 y 1,00

      lv_diff = lv_diff * -1.
      ls_glitems = VALUE gsty_glitems( glaccountlineitem   = lv_line_id
                                             material            = gs_header-product
                                             assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                                           THEN 'COST SHARING'
                                                                           ELSE gs_header-productname )
                                             documentitemtext    = |{ gs_header-providercompanycode }-{ ls_cccode_sumary-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|
                                             GLAccount           = iv_account   "EXT_OSCUGALD TVARVC
*                                       costcenter          = |{ '9590' }{ lv_internalcode }{ '999' }|
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo parametrizado via ZI_TVARVC
                                             costcenter          = COND #(
                                               WHEN lv_is_cs = abap_true
                                               THEN |{ lv_cs_ceco_prefix }{ lv_internalcode }{ lv_cs_cebe }|
                                               ELSE |{ '9590' }{ lv_internalcode }{ '999' }| )
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
                                           ).
      APPEND VALUE #(
        journalentryitemamount = lv_diff
        currency               = ls_cccode_sumary-transactioncurrency
        exchangerate           = ls_cccode_sumary-exchangerate
*        currencyrole           = '00'
      ) TO ls_glitems-_currencyamount.
      APPEND ls_glitems TO lt_glitems.

      CLEAR: lv_diff, lv_totalbaoamount.
    ELSE.
      add_msg_to_log(
               iv_current_item = CORRESPONDING #( iv_currentitem )
               iv_dockey       = |DUMMY{ iv_currentitem-providercompanycode }{ iv_currentitem-product }{ iv_currentitem-recipientcompanycode }|
               iv_doctype = zcl_proposal_bo_abs=>c_document_type-je_purchase
               iv_message_text = |Redondeo { lv_diff CURRENCY = 'USD'  } excede la tolerancia de { v_tolerance CURRENCY = 'USD' }| ).
    ENDIF.

    lv_totalimpuesto = lv_totalimpuesto * -1.

**Ini EXT_OSCUGALD - Genova: AP item = suma real GL items + impuestos
*    IF iv_is_genova = abap_true AND sy-uname EQ 'EXT_OSCUGALD'.
*      ev_totalimp = lv_ap_reference + lv_totalimpuesto.
*    ELSE.
    ev_totalimp = iv_totalamount + lv_totalimpuesto.
*    ENDIF.
**Fin EXT_OSCUGALD - Genova: AP item = suma real GL items + impuestos

    et_glitems = lt_glitems.
    et_taxitems = lt_taxitems.

  ENDMETHOD.


  METHOD process_baogl_for_company_ars.
*"*------------------------------------------------------------------*
*"* EXT_OSCUGALD [AJUSTE-CPIC-ARS] 04.05.2026
*"* [AJUSTE-MIRROR-ARS-V2] 08.05.2026
*"* [AJUSTE-CECO-CPIC] 08.05.2026
*"* [FIX-IVA-TOTAL] 08.05.2026
*"*------------------------------------------------------------------*

*   ── Constantes tarifftype ─────────────────────────────────────────
    CONSTANTS: c_base   TYPE zint_tariff_type VALUE '06',
               c_markup TYPE zint_tariff_type VALUE '01',
               c_gupb   TYPE zint_tariff_type VALUE '02',
               c_gupk   TYPE zint_tariff_type VALUE '03',
               c_intm   TYPE zint_tariff_type VALUE '04',
               c_gupp   TYPE zint_tariff_type VALUE '05'.

*   ── Variables locales ─────────────────────────────────────────────
    DATA: lt_glitems    TYPE gsty_post-%param-_glitems,
          lt_taxitems   TYPE gsty_post-%param-_taxitems,
          lv_totalgl    TYPE wrbtr,
          lv_totalimpto TYPE wrbtr,
          lv_line_id    TYPE n LENGTH 6 VALUE 1.

    DATA lv_tax_items_added TYPE abap_bool VALUE abap_false.

    DATA(calc_taxes)   = zcl_calculate_taxes_net_fact=>create_instance( ).
    DATA tax_items_in  TYPE zif_calculate_taxes_net=>_rtax1u38.
    DATA tax_items_out TYPE zif_calculate_taxes_net=>_rtax1u38.
    DATA error_return  TYPE zif_calculate_taxes_net=>_bapiret2.

*   ── Validar entradas ──────────────────────────────────────────────
    IF it_cpic IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE ct_baogl INTO DATA(ls_first_baogl)
      WITH KEY recipientcompanycode = iv_recipient.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   ── TC type B — idéntico al que usa AR ───────────────────────────
    DATA lv_gl_exchange_rate LIKE ls_first_baogl-exchangerate.
    TRY.
        lv_gl_exchange_rate = it_exchange_rates[
          sourcecurrency = ls_first_baogl-companycodecurrency
          targetcurrency = ls_first_baogl-globalcurrency ]-exchangerate.
      CATCH cx_sy_itab_line_not_found.
        lv_gl_exchange_rate = ls_first_baogl-exchangerate.
    ENDTRY.

*   ── Tax code BRF+ ────────────────────────────────────────────────
    DATA(lo_brf) = NEW zcl_interco_brf_wht( ).
    DATA lv_tax_code TYPE c LENGTH 2.
    lo_brf->get_tax_code(
      EXPORTING
        iv_provider   = gs_header-providercompanycode
        iv_recipient  = iv_recipient
        iv_product    = gs_header-product
      IMPORTING
        ev_taxcode_ap = lv_tax_code ).

    zcl_interco_utils=>unit_code_outbound(
      EXPORTING im_value = '%'
      IMPORTING ex_value = FINAL(base_unit) ).

*   ── Account determination ─────────────────────────────────────────
    FINAL(valid_at) = zcl_interco_utils=>rp_last_day_of_months(
                        day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
    DATA(doc_account) = NEW zcl_interco_doc_glaccount(
      i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-ap
      i_product               = gs_header-product
      i_provider_company_code = gs_header-providercompanycode
      i_valid_at              = valid_at ).

    IF gs_header-providercountry = ls_first_baogl-recipientcountry.
      DATA(lv_optype) = zcl_interco_doc_glaccount=>co_operation_type-local.
    ELSE.
      lv_optype = zcl_interco_doc_glaccount=>co_operation_type-foreign.
    ENDIF.

*   ── Paso 0: mapear costcenter MLA → MSP en it_cpic via BRF+ ──────
    DATA lt_cpic_mapped TYPE tt_cpic.
    DATA(lo_brf_cc) = NEW zcl_interco_brf_wht( ).

    LOOP AT it_cpic INTO DATA(ls_cpic_raw).
      DATA(ls_cpic_mapped) = ls_cpic_raw.

      DATA(lv_cc_origen) = ls_cpic_raw-costcenter+3(1).

*Ini EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS-CECO] 18.06.2026
*   ANTES: iv_departamento = ls_first_baogl-department → siempre dept=13
*          BRF+ mapeaba el costcenter usando dept del primer BAOGL para
*          todos los ítems CPIC, incluyendo los de dept=15.
*          Resultado: ítems dept=15 obtenían costcenter incorrecto o vacío
*          → CLEAR costcenter → ítem descartado → nunca genera 693141/693142.
*   AHORA: iv_departamento = ls_cpic_raw-department → dept real del ítem
*          BRF+ mapea correctamente el costcenter por dept → ítem dept=15
*          llega al Paso 1 con costcenter correcto → genera 693141/693142.
      DATA(lv_cccode_cpic) = lo_brf_cc->get_cc_code(
        iv_product      = gs_header-product
        iv_cc_origen    = lv_cc_origen
        iv_departamento = ls_cpic_raw-department
        iv_tipo_doc     = zcl_interco_doc_glaccount=>co_doc_type-ap ).
*Fin EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS-CECO] 18.06.2026

      IF lv_cccode_cpic IS NOT INITIAL.
        ls_cpic_mapped-costcenter =
          |{ lv_cccode_cpic }{ ls_first_baogl-internalcode }{ ls_cpic_raw-profitcenter ALPHA = OUT }|.
        READ TABLE et_itemscalc INTO DATA(ls_pc_cpic)
          WITH KEY id      = ls_cpic_raw-id
                   item_id = ls_cpic_raw-item_id
                   product = gs_header-product.
        IF ls_pc_cpic-profitcentereq IS NOT INITIAL.
          ls_cpic_mapped-costcenter+7(3) = ls_pc_cpic-profitcentereq.
        ENDIF.
      ELSE.
        CLEAR ls_cpic_mapped-costcenter.
      ENDIF.

      APPEND ls_cpic_mapped TO lt_cpic_mapped.
    ENDLOOP.

*   ── Paso 1: consolidar lt_cpic_mapped por costcenter × tarifftype ─
    TYPES: BEGIN OF ty_ceco_tariff,
             costcenter   TYPE kostl,
             profitcenter TYPE prctr,
             tarifftype   TYPE zint_tariff_type,
             glaccount    TYPE saknr,
             amount       TYPE wrbtr,
             department   LIKE ls_first_baogl-department,
             idl3         LIKE ls_first_baogl-idl3,
           END OF ty_ceco_tariff.
    DATA lt_ceco_tariff TYPE SORTED TABLE OF ty_ceco_tariff
      WITH UNIQUE KEY costcenter tarifftype glaccount.  "se agrego glaccount 18.06.2026

    TYPES: BEGIN OF ty_ceco_dept,
             costcenter TYPE kostl,
             department LIKE ls_first_baogl-department,
             idl3       LIKE ls_first_baogl-idl3,
           END OF ty_ceco_dept.
    DATA lt_ceco_dept TYPE SORTED TABLE OF ty_ceco_dept
      WITH UNIQUE KEY costcenter.

    LOOP AT ct_baogl INTO DATA(ls_baogl_dept)
      WHERE recipientcompanycode = iv_recipient.
      IF ls_baogl_dept-costcenter IS INITIAL. CONTINUE. ENDIF.
      READ TABLE lt_ceco_dept WITH KEY costcenter = ls_baogl_dept-costcenter
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        INSERT VALUE ty_ceco_dept(
          costcenter = ls_baogl_dept-costcenter
          department = ls_baogl_dept-department
          idl3       = ls_baogl_dept-idl3 )
          INTO TABLE lt_ceco_dept.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_cpic_mapped INTO DATA(ls_cpic).
      IF ls_cpic-amountincompanycodecurrency = 0. CONTINUE. ENDIF.

*Ini EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS-V2] 18.06.2026
*   PROBLEMA CONFIRMADO EN DEBUG:
*   lt_ceco_dept tiene UNIQUE KEY costcenter → una sola fila por ceco.
*   Para ceco=9541171630 guarda dept=13. Cuando llegan los 2 ítems CPIC
*   con dept=15 (tariff=01 y tariff=06), el READ sy-subrc=0 → lv_department=13
*   → el ELSE del fix anterior nunca ejecuta → doc_account->get() retorna
*   693112/693111 en lugar de 693142/693141.
*   SOLUCIÓN: usar SIEMPRE ls_cpic-department para lv_department.
*   Para idl3: usar lt_ceco_dept como fuente si el costcenter coincide,
*   fallback a ls_first_baogl-idl3.
      DATA lv_department LIKE ls_first_baogl-department.
      DATA lv_idl3       LIKE ls_first_baogl-idl3.
      READ TABLE lt_ceco_dept INTO DATA(ls_dept)
              WITH KEY costcenter = ls_cpic-costcenter.
      IF sy-subrc = 0.
        lv_idl3 = ls_dept-idl3.
      ELSE.
        lv_idl3 = ls_first_baogl-idl3.
      ENDIF.
      IF ls_cpic-department IS NOT INITIAL.
        lv_department = ls_cpic-department.
      ELSE.
        lv_department = ls_first_baogl-department.
      ENDIF.
*Fin EXT_OSCUGALD [FIX-DEPTO-CPIC-ARS-V2] 18.06.2026

      DATA lv_profitcenter TYPE prctr.
      READ TABLE et_itemscalc INTO DATA(ls_pc)
        WITH KEY id      = ls_cpic-id
                 item_id = ls_cpic-item_id
                 product = gs_header-product.
      IF ls_pc-profitcentereq IS NOT INITIAL.
        lv_profitcenter = ls_pc-profitcentereq.
      ELSE.
        lv_profitcenter = ls_cpic-profitcenter.
      ENDIF.

      DATA lv_glaccount TYPE saknr.
      CASE ls_cpic-tarifftype.
        WHEN c_base.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-basis
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = DATA(ls_gl_acc) ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN c_markup.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-markup
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = ls_gl_acc ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN c_gupb.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-grossup_basis
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = ls_gl_acc ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN c_gupk.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-grossup_margin
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = ls_gl_acc ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN c_intm.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-late_payment_intereset
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = ls_gl_acc ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN c_gupp.
          doc_account->get(
            EXPORTING i_tarifftype    = zcl_interco_doc_glaccount=>co_tariff_type-provider_grossup
                      i_department    = lv_department
                      i_pandlid       = lv_idl3
                      i_operationtype = lv_optype
            RECEIVING result          = ls_gl_acc ).
          lv_glaccount = ls_gl_acc-glaccount1.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      IF lv_glaccount IS INITIAL. CONTINUE. ENDIF.

      READ TABLE lt_ceco_tariff WITH KEY
        costcenter = ls_cpic-costcenter
        tarifftype = ls_cpic-tarifftype
        glaccount  = lv_glaccount
        REFERENCE INTO DATA(lr_ct).
      IF sy-subrc = 0.
        lr_ct->amount += ls_cpic-amountincompanycodecurrency.
      ELSE.
        INSERT VALUE ty_ceco_tariff(
          costcenter   = ls_cpic-costcenter
          profitcenter = lv_profitcenter
          tarifftype   = ls_cpic-tarifftype
          glaccount    = lv_glaccount
          amount       = ls_cpic-amountincompanycodecurrency
          department   = lv_department
          idl3         = lv_idl3 )
          INTO TABLE lt_ceco_tariff.
      ENDIF.
    ENDLOOP.

    IF lt_ceco_tariff IS INITIAL.
      RETURN.
    ENDIF.

*   ── Paso 2: IVA una sola vez sobre total base — igual que AR ─────
*   [FIX-IVA-TOTAL] 1 llamada a calc_taxes sobre suma total de líneas
*   base → mismo TAXBASEAMOUNT que AR (545,442,050.92) → IVA exacto.
*   costcenter = space para que el Paso 3 lo agregue solo una vez.
    TYPES: BEGIN OF ty_tax_pre,
             tarifftype  TYPE zint_tariff_type,
             costcenter  TYPE kostl,
             condidx     TYPE i,
             amount_base TYPE wrbtr,
             amount_tax  TYPE wrbtr,
             mwskz       TYPE mwskz,
             ktosl       TYPE ktosl,
             kschl       TYPE kscha,
             txjcd       TYPE txjcd,
             txjlv       TYPE txjcd_level,
             txjcd_deep  TYPE txjcd,
             msatz       TYPE p LENGTH 7 DECIMALS 4,
             txdat       TYPE txdat,
             tax_country TYPE land1,
           END OF ty_tax_pre.
    DATA lt_tax_pre TYPE STANDARD TABLE OF ty_tax_pre WITH EMPTY KEY.

    IF lv_tax_code IS NOT INITIAL.
*     Base IVA = suma de TODAS las líneas GL (igual que AR usa
*     total_in_transaction_currency que acumula todos los GL items)
      DATA lv_tax_base TYPE wrbtr.
      LOOP AT lt_ceco_tariff INTO DATA(ls_ct_b).
        lv_tax_base += ls_ct_b-amount.
      ENDLOOP.

      tax_items_in = VALUE #( ( bukrs = iv_recipient
                                waers = ls_first_baogl-companycodecurrency
                                wrbtr = lv_tax_base
                                mwskz = lv_tax_code ) ).
      calc_taxes->calculate_taxes_net(
        CHANGING error_return = error_return
                 tax_item_in  = tax_items_in
                 tax_item_out = tax_items_out ).
      IF error_return IS INITIAL.
        DATA lv_condidx TYPE i VALUE 0.
        DO lines( tax_items_out ) TIMES.
          DATA(tax_item_pre) = REF #( tax_items_out[ sy-index ] ).
          IF tax_item_pre->waers <> ls_first_baogl-companycodecurrency.
            CONTINUE.
          ENDIF.
          lv_condidx += 1.
          APPEND VALUE ty_tax_pre(
            tarifftype  = c_base
            costcenter  = space
            condidx     = lv_condidx
            amount_base = tax_item_pre->fwbas
            amount_tax  = tax_item_pre->fwste
            mwskz       = tax_item_pre->mwskz
            ktosl       = tax_item_pre->ktosl
            kschl       = tax_item_pre->kschl
            txjcd       = tax_item_pre->txjcd
            txjlv       = tax_item_pre->txjlv
            txjcd_deep  = tax_item_pre->txjcd_deep
            msatz       = tax_item_pre->msatz
            txdat       = tax_item_pre->txdat
            tax_country = tax_item_pre->tax_country )
            TO lt_tax_pre.
        ENDDO.
        CLEAR lv_condidx.
      ENDIF.
      FREE: error_return, tax_items_in, tax_items_out.
    ENDIF.

*   ── Paso 3: armar GL items + tax items ───────────────────────────
*   GL item se agrega ANTES de sus tax items → fix FS210.
*   Tax items se agregan UNA SOLA VEZ en primera línea c_base
*   (lv_tax_items_added) buscando costcenter = space.
*   Pre-acumular lv_totalimpto desde lt_tax_pre (IVA ya calculado)
    LOOP AT lt_tax_pre INTO DATA(ls_pre_total).
      lv_totalimpto += ls_pre_total-amount_tax.
    ENDLOOP.
    LOOP AT lt_ceco_tariff INTO DATA(ls_ceco_tf).

      DATA(ls_glitem) = VALUE gsty_glitems(
        glaccountlineitem   = lv_line_id
        glaccount           = ls_ceco_tf-glaccount
        profitcenter        = ls_ceco_tf-profitcenter
        costcenter          = ls_ceco_tf-costcenter
        documentitemtext    = |{ gs_header-providercompanycode }-{ iv_recipient }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|
        material            = gs_header-product
        assignmentreference = gs_header-productname
        taxcode             = lv_tax_code ).

      IF ls_ceco_tf-tarifftype <> c_base.
        ls_glitem-quantity = CONV #( ls_ceco_tf-tarifftype ).
        ls_glitem-baseunit = base_unit.
      ENDIF.

      APPEND VALUE #(
        journalentryitemamount = ls_ceco_tf-amount
        currency               = ls_first_baogl-companycodecurrency
        exchangerate           = lv_gl_exchange_rate
      ) TO ls_glitem-_currencyamount.

      lv_totalgl += ls_ceco_tf-amount.
      lv_line_id += 1.

      APPEND ls_glitem TO lt_glitems.  "← GL item ANTES de tax items

*     Tax items: una sola vez en primera línea c_base
      IF ls_ceco_tf-tarifftype = c_base AND lv_tax_items_added = abap_false.
        DATA lv_max_condidx TYPE i.
        lv_max_condidx = REDUCE i( INIT m = 0
                                   FOR tx IN lt_tax_pre
                                   WHERE ( tarifftype = c_base
                                       AND costcenter = space )
                                   NEXT m = nmax( val1 = m val2 = tx-condidx ) ).
        DO lv_max_condidx TIMES.
          READ TABLE lt_tax_pre INTO DATA(ls_tax_pre)
            WITH KEY tarifftype = c_base
                     costcenter = space
                     condidx    = sy-index.
          IF sy-subrc <> 0 OR ls_tax_pre-amount_tax = 0. CONTINUE. ENDIF.
          DATA(ls_taxitem) = VALUE gsty_taxitems(
            glaccountlineitem          = lv_line_id
            taxcode                    = ls_tax_pre-mwskz
            taxitemclassification      = ls_tax_pre-ktosl
            conditiontype              = ls_tax_pre-kschl
            taxjurisdiction            = ls_tax_pre-txjcd
            taxjurisdictionlevel       = ls_tax_pre-txjlv
            lowestleveltaxjurisdiction = ls_tax_pre-txjcd_deep
            taxrate                    = ls_tax_pre-msatz
            taxdeterminationdate       = ls_tax_pre-txdat
            taxcountry                 = ls_tax_pre-tax_country ).
*            taxitemacctgdocitemref     = ls_glitem-glaccountlineitem ).
          APPEND VALUE #(
            journalentryitemamount = ls_tax_pre-amount_tax
            currency               = ls_first_baogl-companycodecurrency
            currencyrole           = '00'
            taxbaseamount          = ls_tax_pre-amount_base
            taxamount              = ls_tax_pre-amount_tax
          ) TO ls_taxitem-_currencyamount.
          APPEND ls_taxitem TO lt_taxitems.
*          ls_glitem-taxitemacctgdocitemref = ls_taxitem-glaccountlineitem.
*          lv_totalimpto += ls_tax_pre-amount_tax.
          lv_line_id += 1.
        ENDDO.
        CLEAR lv_max_condidx.
        lv_tax_items_added = abap_true.
      ENDIF.

    ENDLOOP.

*   ── Paso 4: redondeo ─────────────────────────────────────────────
    DATA lv_diff TYPE wrbtr.
    DATA lv_diff_ex TYPE wrbtr.

    lv_diff = iv_totalamount + lv_totalgl.

    IF lv_gl_exchange_rate <> 0.
      lv_diff_ex = CONV wrbtr( lv_diff / lv_gl_exchange_rate ).
    ELSE.
      lv_diff_ex = lv_diff.
    ENDIF.

    IF gs_header-providercountry = ls_first_baogl-recipientcountry.
*     Mismo país: absorber diff en cuenta base con CECO de MAYOR monto
      IF abs( lv_diff_ex ) <= v_tolerance.
        lv_diff = lv_diff * -1.
*       Absorber en línea de MENOR monto con CECO — igual que AR
        DATA lv_idx_max_gl  TYPE i VALUE 0.
        DATA lv_best_gl_amt TYPE wrbtr VALUE 0.
        DATA lv_first_found TYPE abap_bool VALUE abap_false.
*       Absorber en línea de menor monto de cuenta base (c_base)
        DATA lv_glaccount_base TYPE saknr.
        LOOP AT lt_ceco_tariff INTO DATA(ls_ct_base).
          IF ls_ct_base-tarifftype = c_base.
            lv_glaccount_base = ls_ct_base-glaccount.
            EXIT.
          ENDIF.
        ENDLOOP.
*        DATA lv_idx_max_gl  TYPE i VALUE 0.
*        DATA lv_best_gl_amt TYPE wrbtr VALUE 0.
        LOOP AT lt_glitems INTO DATA(ls_gl_scan)
          WHERE costcenter IS NOT INITIAL
            AND glaccount  = lv_glaccount_base.
          IF abs( ls_gl_scan-_currencyamount[ 1 ]-journalentryitemamount )
             > abs( lv_best_gl_amt ).
            lv_best_gl_amt = ls_gl_scan-_currencyamount[ 1 ]-journalentryitemamount.
            lv_idx_max_gl  = sy-tabix.
          ENDIF.
        ENDLOOP.
        IF lv_idx_max_gl > 0.
          ASSIGN lt_glitems[ lv_idx_max_gl ] TO FIELD-SYMBOL(<fs_gl_max>).
          IF <fs_gl_max> IS ASSIGNED.
            <fs_gl_max>-_currencyamount[ 1 ]-journalentryitemamount += lv_diff.
            lv_totalgl += lv_diff.
          ENDIF.
        ENDIF.
      ELSE.
        add_msg_to_log(
          iv_current_item = CORRESPONDING #( iv_currentitem )
          iv_dockey       = |DUMMY{ iv_currentitem-providercompanycode }{ iv_currentitem-product }{ iv_currentitem-recipientcompanycode }|
          iv_doctype      = zcl_proposal_bo_abs=>c_document_type-je_purchase
          iv_message_text = |Redondeo { lv_diff CURRENCY = 'ARS' } excede tolerancia { v_tolerance CURRENCY = 'ARS' }| ).
      ENDIF.
    ELSE.
*     Distinto país: cuenta de redondeo original
      IF abs( lv_diff_ex ) <= v_tolerance.
        lv_diff = lv_diff * -1.
        APPEND VALUE gsty_glitems(
          glaccountlineitem   = lv_line_id
          material            = gs_header-product
          assignmentreference = gs_header-productname
          documentitemtext    = |{ gs_header-providercompanycode }-{ iv_recipient }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|
          glaccount           = iv_account
          costcenter          = |{ '9590' }{ ls_first_baogl-internalcode }{ '999' }|
          _currencyamount     = VALUE #( (
            journalentryitemamount = lv_diff
            currency               = ls_first_baogl-companycodecurrency
            exchangerate           = lv_gl_exchange_rate ) )
        ) TO lt_glitems.
        lv_totalgl += lv_diff.
      ELSE.
        add_msg_to_log(
          iv_current_item = CORRESPONDING #( iv_currentitem )
          iv_dockey       = |DUMMY{ iv_currentitem-providercompanycode }{ iv_currentitem-product }{ iv_currentitem-recipientcompanycode }|
          iv_doctype      = zcl_proposal_bo_abs=>c_document_type-je_purchase
          iv_message_text = |Redondeo { lv_diff CURRENCY = 'ARS' } excede tolerancia { v_tolerance CURRENCY = 'ARS' }| ).
      ENDIF.
    ENDIF.

*   ── Exportar ─────────────────────────────────────────────────────
    lv_totalimpto = lv_totalimpto * -1.
    ev_totalimp   = iv_totalamount + lv_totalimpto.
    et_glitems    = lt_glitems.
    et_taxitems   = lt_taxitems.

  ENDMETHOD.


  METHOD mapping_bo_sec_mic.
*───────────────────────────────────────────────────────────────────────────
* EXT_OSCUGALD 01.08.2026 - Bermudas MIC-USA (SDFPSINIC-23362)
* Arma el asiento AP de Compras para Bermudas. Espejo del AR (mapping_bo_sec_mic
* de ZCL_PROPOSAL_BO_AR). Asiento de 2 lineas con UN importe unico de regalia:
*   - Linea GL (cuenta de costo/gasto, al debe → positivo, posting key 40)
*   - Item AP (proveedor interco, al haber → negativo, posting key 31)
*
* El AP se postea en la sociedad CONTRARIA al AR (quien recibe la factura y
* registra la compra). Direccion por signo de la regalia:
*   lv_amount_tc > 0 → MIC factura a USA → AR en USA / AP en MIC
*   lv_amount_tc < 0 → USA factura a MIC → AR en MIC / AP en USA
*
* Reglas de armado (validadas contra molde productivo 8020000145, AP en MIC):
*   - Proveedor: TVARVC ZINTERCO_MIC_AP_VENDOR (IC0145). Fijo mientras se da
*     mantenimiento a zi_intercorelationship (confirmado negocio 01.08).
*   - CeCo: prefijo(4) + internalcode(3) + CeBe(3); internalcode de la sociedad
*     AP desde zi_intercocompanycode (MIC=295 / USA=145). Va en la linea de costo.
*   - Cuentas: determinacion (ZINT_A_MD_GLACCT) SIEMPRE con MIC como provider.
*   - Clase doc IC siempre (AI queda reservada para anulaciones).
*   - Posting keys via abs(): costo al debe (40), proveedor al haber (31).
*───────────────────────────────────────────────────────────────────────────
    DATA(proposal_items)  = gtd_items_add.
    DATA(journal_entries) = gta_je_post.

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months(
      day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

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

    " Proveedor del AP desde TVARVC (fijo IC0145 mientras se mantiene la vista
    " de relaciones). Sin hardcode.
    DATA lv_ap_vendor TYPE lifnr.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_AP_VENDOR' AND type = 'P'
      INTO @lv_ap_vendor.
    IF sy-subrc <> 0 OR lv_ap_vendor IS INITIAL.
      add_msg_to_log(
        iv_current_item = VALUE #( )
        iv_dockey       = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }|
        iv_doctype      = mv_posting_doctype
        iv_message_type = 'E'
        iv_message_text = |Falta parametrizacion TVARVC ZINTERCO_MIC_AP_VENDOR para Bermudas.| ).
      RETURN.
    ENDIF.
*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
*   Pre-cargar vendor USA→MIC fuera del loop para cumplir ATC Clean Core
*   (no SELECT dentro de LOOP). El valor es constante por propuesta.
    DATA lv_ap_vendor_usa TYPE lifnr.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_AP_VENDOR_USA' AND type = 'P'
      INTO @lv_ap_vendor_usa.
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)

    " Claves item_id / itembasis_id / itemcalc_id del item del CeBe destino,
    " necesarias para poblar el doc_map completo → fila en Documento generado.
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

    " Relaciones interco de MIC (para derivar la contraparte). Vista sociedad-a-
    " sociedad (sin product).
    DATA lt_relationships TYPE TABLE OF zi_intercorelationship WITH EMPTY KEY.
    SELECT providercompanycode, recipientcompanycode, recipientcustomer
      FROM zi_intercorelationship
      WHERE ( providercompanycode  = @gs_header-providercompanycode
           OR recipientcompanycode = @gs_header-providercompanycode )
      INTO CORRESPONDING FIELDS OF TABLE @lt_relationships.

    " Internalcodes de las sociedades de la operacion — JOIN con relaciones
    " (evita FOR ALL ENTRIES y SELECT sin WHERE → ATC Clean Core).
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
           recipientcountry,
           SUM( amountintrasactioncurrency ) AS amountintransactioncurrency,
           transactioncurrency
      FROM @proposal_items AS pi
      GROUP BY recipientcompanycode, recipientcountry, transactioncurrency
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
      " DIRECCION DINAMICA — AP en la sociedad CONTRARIA al AR.
      "   lv_amount_tc > 0 → MIC factura a USA → AR en USA / AP en MIC
      "   lv_amount_tc < 0 → USA factura a MIC → AR en MIC / AP en USA
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(lv_ap_companycode) = COND bukrs(
        WHEN lv_amount_tc > 0
        THEN gs_header-providercompanycode       " AP en MIC
        ELSE total_mic->recipientcompanycode ).  " AP en USA

      " Contraparte del AP (la otra sociedad, para el texto).
      DATA(lv_ap_counterparty) = COND bukrs(
        WHEN lv_ap_companycode = gs_header-providercompanycode
        THEN total_mic->recipientcompanycode      " AP en MIC → contraparte USA
        ELSE gs_header-providercompanycode ).      " AP en USA → contraparte MIC

      " CeCo dinamico: prefijo + internalcode(sociedad AP) + CeBe.
      READ TABLE lt_company_ic INTO DATA(ls_company_ic)
        WITH KEY companycode = lv_ap_companycode.
      DATA lv_ceco_mic TYPE kostl.
      IF sy-subrc = 0 AND ls_company_ic-internalcode IS NOT INITIAL.
        lv_ceco_mic = |{ lv_ceco_prefix }{ ls_company_ic-internalcode }{ lv_ceco_cebe }|.
      ELSE.
        add_msg_to_log(
          iv_current_item = VALUE #( )
          iv_dockey       = |DUMMY{ lv_ap_companycode }{ gs_header-product }|
          iv_doctype      = mv_posting_doctype
          iv_message_type = 'E'
          iv_message_text = |No se encontro internalcode para sociedad { lv_ap_companycode } en zi_intercocompanycode.| ).
        CONTINUE.
      ENDIF.

      " Determinacion de cuentas: SIEMPRE con MIC como provider.
      DATA(account_determination) = NEW zcl_interco_doc_glaccount(
        i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-ap
        i_product               = gs_header-product
        i_provider_company_code = gs_header-providercompanycode
        i_valid_at              = last_day_of_month ).

      APPEND INITIAL LINE TO journal_entries REFERENCE INTO DATA(journal_entry).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " HEADER — clase IC siempre; sociedad = sociedad AP dinamica
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      journal_entry->%cid = |AP{ lv_ap_companycode }{ gs_header-product }{ sy-tabix }|.
      journal_entry->%param-accountingdocumenttype       = 'IR'.
      journal_entry->%param-createdbyuser                = sy-uname.
      journal_entry->%param-accountingdocumentheadertext = 'Royalties'.
      journal_entry->%param-companycode                  = lv_ap_companycode.
      journal_entry->%param-documentreferenceid          = gs_header-product.
      journal_entry->%param-businesstransactiontype      = 'RFBU'.
      journal_entry->%param-documentdate                 = last_day_of_month.
      journal_entry->%param-postingdate                  = last_day_of_month.

      " Texto: arranca con la sociedad AP, luego la contraparte.
      " Molde productivo: AP en MIC (caso USA→MIC) → "USA-MIC Royalties".
      " Se mantiene el mismo texto que el AR (perspectiva de la operacion).
      DATA(lv_doctext) = |{ lv_ap_counterparty }-{ lv_ap_companycode } Royalties { gs_header-fiscalperiod }.{ gs_header-fiscalyear }|.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " GL ITEM — cuenta de costo/gasto, al debe (positivo → posting key 40)
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
      " abs() → siempre al debe (posting key 40, costo), sin importar el signo.
      gl_amount->journalentryitemamount  = abs( lv_amount_tc ).
      gl_amount->exchangerate            = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " AP ITEM — proveedor interco, al haber (negativo → posting key 31)
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
*   Vendor dinámico por dirección de facturación:
*   AP en MIC (amount > 0, MIC→USA) → proveedor de USA en MIC = TVARVC ZINTERCO_MIC_AP_VENDOR (IC0144)
*   AP en USA (amount < 0, USA→MIC) → proveedor de MIC en USA = TVARVC ZINTERCO_MIC_AP_VENDOR_USA (IC0295)
      DATA lv_ap_vendor_dir TYPE lifnr.
      IF lv_ap_companycode = gs_header-providercompanycode.
        " AP en MIC → vendor fijo desde TVARVC ZINTERCO_MIC_AP_VENDOR
        lv_ap_vendor_dir = lv_ap_vendor.
      ELSE.
        " AP en USA → vendor de MIC en USA pre-cargado desde TVARVC (fuera del loop)
        lv_ap_vendor_dir = lv_ap_vendor_usa.
        IF lv_ap_vendor_dir IS INITIAL.
          add_msg_to_log(
            iv_current_item = VALUE #( )
            iv_dockey       = |DUMMY{ lv_ap_companycode }{ gs_header-product }|
            iv_doctype      = mv_posting_doctype
            iv_message_type = 'E'
            iv_message_text = |Bermudas AP: falta TVARVC ZINTERCO_MIC_AP_VENDOR_USA para AP en USA (IC0295).|
          ).
          CONTINUE.
        ENDIF.
      ENDIF.
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
      APPEND INITIAL LINE TO journal_entry->%param-_apitems REFERENCE INTO DATA(ap_item).
      ap_item->glaccountlineitem   = 1.
      ap_item->supplier            = lv_ap_vendor_dir.
      ap_item->assignmentreference = 'REGALIAS'.
      ap_item->documentitemtext    = lv_doctext.

      APPEND INITIAL LINE TO ap_item->_currencyamount REFERENCE INTO DATA(ap_amount).
      ap_amount->currencyrole           = '00'.
      ap_amount->currency               = total_mic->transactioncurrency.
      " abs()*-1 → siempre al haber (posting key 31, proveedor).
      ap_amount->journalentryitemamount = abs( lv_amount_tc ) * -1.
      ap_amount->exchangerate           = 1.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " DOC_MAP — claves completas para materializar la fila en Documento generado
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(dummy_dockey) = |DUMMYAP{ lv_ap_companycode }{ gs_header-product }{ gs_header-fiscalperiod }|.
      APPEND VALUE #(
        id           = gs_header-id
        item_id      = ls_cpic_keys-item_id
        itembasis_id = ls_cpic_keys-itembasis_id
        itemcalc_id  = ls_cpic_keys-itemcalc_id
        companycode  = lv_ap_companycode
        documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
        documentkey  = dummy_dockey
      ) TO gt_doc_map.

      gta_je_post = journal_entries.

      DATA(je_mic_parallel) = NEW zcl_proposal_bo_ap_parallel(
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
