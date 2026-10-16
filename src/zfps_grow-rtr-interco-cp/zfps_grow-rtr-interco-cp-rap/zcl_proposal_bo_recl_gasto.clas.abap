 CLASS zcl_proposal_bo_recl_gasto DEFINITION
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



 CLASS zcl_proposal_bo_recl_gasto IMPLEMENTATION.


   METHOD preparedata.
     DELETE gtd_items_add WHERE interdivisional = abap_true OR with_expensrec = abap_true.
   ENDMETHOD.


   METHOD mapping_bo_sec.
     DATA: lv_cid          TYPE abp_behv_cid,
           lt_glitems      TYPE gsty_post-%param-_glitems,
           lv_fromglacc    TYPE saknr,
           lv_toglacc      TYPE saknr,
           lv_position_num TYPE int4.
     DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
     DATA lv_product              TYPE zfi_proposalitem_add-product.
     DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
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

     DATA(gl_item_mappings) = VALUE tt_glitem_mapping(
         ( type = 'BASE'           amount_field = 'AMOUNTINTRASACTIONCURRENCY' tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-BASIS' )
         ( type = 'MARKUP'         amount_field = 'MARKUPAMOUNT'               tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-MARKUP' )
         ( type = 'GROSSUP MARGIN' amount_field = 'GROSSINGUPMARGINAMOUNT'     tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_MARGIN' )
         ( type = 'GROSSUP BASE'   amount_field = 'GROSSINGUPBASEAMOUNT'       tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_BASIS' )
     ).


     TRY.
         FINAL(ld_lastday) = zcl_interco_utils=>rp_last_day_of_months( EXPORTING day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

* Ini EXT_OSCUGALD 01.08.2026 - Bermudas MIC (SDFPSINIC-23362)
         " Dispatch: producto MIC (Bermudas) → reclasificacion RP dedicada.
         " Solo se genera si hubo AP (preparedata ya filtro los items con doc).
         SELECT SINGLE low FROM zi_tvarvc
           WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
           INTO @DATA(lv_mic_prod_found_rp).
         IF sy-subrc = 0.
           mapping_bo_sec_mic( ).

           et_doc_map = me->gt_doc_map.

           IF gt_doc_map[] IS INITIAL OR
              line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] ) OR
              line_exists( gt_doc_map[ status = abap_false ] ) OR
              line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
             RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
           ENDIF.

           RETURN.
         ENDIF.
* Fin EXT_OSCUGALD 01.08.2026 - Bermudas MIC

         CHECK gtd_items_add IS NOT INITIAL.

         SELECT _items_add~*
         FROM zi_intercoglacctdetermination AS _glacc
         INNER JOIN @gtd_items_add AS _items_add ON _glacc~product = _items_add~product
                                                 AND _glacc~providercompanycode = _items_add~providercompanycode
          WHERE _glacc~validfrom <= @ld_lastday
            AND _glacc~validto >= @ld_lastday
            AND _glacc~providercompanycode = @gs_header-providercompanycode
            AND _glacc~doctype = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
            AND _glacc~product = @gs_header-product
            AND _glacc~isdeleted IS INITIAL
                  INTO TABLE @DATA(lt_items_recla_ap).

         DATA(account_determination) = NEW zcl_interco_doc_glaccount( i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
                                                                      i_product               = gs_header-product
                                                                      i_provider_company_code = gs_header-providercompanycode
                                                                      i_valid_at              = ld_lastday
                                                                      ).
         DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
         CHECK lt_items_recla_ap IS NOT INITIAL.
         FINAL(proposal_items) = gtd_items_add.

**********************************************************************
* Third version
**********************************************************************
         "gtd_items_add only contains position without documents generated
         "to avoid generate duplicate documents
         READ TABLE proposal_items INTO DATA(ls_proposal_items) WITH KEY profitcenter = '0000000299'.
         IF sy-subrc EQ 0.
           SELECT FROM zi_proposalitemcalcdet_mla AS proposal_items_calc_detail
        INNER JOIN @proposal_items AS proposal_item
          ON proposal_item~id = proposal_items_calc_detail~id AND
             proposal_item~item_id = proposal_items_calc_detail~item_id
       FIELDS
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
          \_proposalitem-profitcenter,
          \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
          \_proposalitem-globalcurrency,
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
*        \_proposalitem\_Relationship-recipientcustomer,
          \_proposalitem-exchangerate
       WHERE proposal_items_calc_detail~id = @gs_header-id AND tariffrate > 0
      ORDER BY proposal_items_calc_detail~product, recipientcompanycode, tarifftype
       INTO TABLE @DATA(proposal_items_details).
         ELSE.
           SELECT FROM zi_intercoproposalitemcalcdet AS proposal_items_calc_detail
        INNER JOIN @proposal_items AS proposal_item
          ON proposal_item~id = proposal_items_calc_detail~id AND
             proposal_item~item_id = proposal_items_calc_detail~item_id
       FIELDS
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
          \_proposalitem-profitcenter,
          \_proposalitem\_proposal\_providercompanycode-currency AS companycodecurrency,
          \_proposalitem-globalcurrency,
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
*        \_proposalitem\_Relationship-recipientcustomer,
          \_proposalitem-exchangerate
       WHERE proposal_items_calc_detail~id = @gs_header-id AND tariffrate > 0
      ORDER BY proposal_items_calc_detail~product, recipientcompanycode, tarifftype
       INTO TABLE @proposal_items_details.
         ENDIF.

         "Extraemos tipos de cambio tipo B
         SELECT DISTINCT sourcecurrency, targetcurrency, abs( i_exchangeraterawdata~exchangerate ) AS exchangerate
         FROM i_exchangeraterawdata
         INNER JOIN @proposal_items_details AS proposal_items_details ON
             proposal_items_details~companycodecurrency = i_exchangeraterawdata~sourcecurrency AND
             proposal_items_details~globalcurrency = i_exchangeraterawdata~targetcurrency
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

         DATA lv_cs_ceco_prefix TYPE c LENGTH 4.
         DATA lv_cs_cebe        TYPE c LENGTH 3.
*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: internalcodes disponibles tambien para no-CS
         " Motivo: el camino no-CS tambien necesita el internalcode de la sociedad receptora
         " para reconstruir el centro de costo correctamente (ver fix dentro del LOOP mas abajo).
         " Se saca del IF lv_is_cs para que este disponible en ambos casos.
*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: corregir filtro de sitecode
         " BUG REAL ENCONTRADO: el filtro original comparaba sitecode contra
         " gs_header-providercompanycode (ej. 'EBA'), pero el campo SITECODE de
         " zi_intercocompanycode NUNCA vale 'EBA' -> vale 'MLB' para EBA/IFB/MPB/SOC/MLB.
         " Para CS funcionaba de pura coincidencia porque el proveedor de CS ES 'MLB'.
         " Para ICSRV52 (proveedor EBA) el filtro devolvia 0 filas -> lt_cs_companies vacia
         " -> el fix de mas abajo (costcenter+4) nunca encontraba nada y no hacia nada.
         " FIX: comparar contra el propio sitecode de la propuesta (gs_header-sitecode),
         " no contra el codigo de la sociedad proveedora.
         SELECT companycode, internalcode
           FROM zi_intercocompanycode
           WHERE sitecode = @gs_header-sitecode
           INTO TABLE @DATA(lt_cs_companies).
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: corregir filtro de sitecode
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: internalcodes disponibles tambien para no-CS
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
**Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: internalcodes de receptoras para CeCo del doc CH
*           " El doc CH postea en la soc. receptora => CeCo usa internalcode de ESA sociedad
*           " Produccion: EBA->9590112999, IFB->9590210999, MPB->9590130999, SOC->9590219999
*           " WHERE sitecode filtra solo las sociedades del mismo pais/sitio del provider
*           SELECT companycode, internalcode
*             FROM zi_intercocompanycode
*             WHERE sitecode = @gs_header-providercompanycode
*             INTO TABLE @DATA(lt_cs_companies).
**Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
*Ini EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO: agregar glaccount1 para lookup por cuenta
           SELECT tarifftype, pandlid, glaccount1
             FROM zi_intercoglacctdetermination
             WHERE product             = @gs_header-product
               AND providercompanycode = @gs_header-providercompanycode
               AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
               AND isdeleted           = ''
             INTO TABLE @DATA(lt_cs_pandlids_rg).
*Fin EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO
         ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

         LOOP AT proposal_items_details REFERENCE INTO DATA(proposal_item_detail).
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing: CeCo fijo via ZI_TVARVC para ICSRV30/ICSRV31
           IF lv_is_cs = abap_true.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: CeCo usa internalcode de la soc. receptora
             READ TABLE lt_cs_companies INTO DATA(ls_cs_company_rg)
               WITH KEY companycode = proposal_item_detail->recipientcompanycode.
             DATA(lv_rg_internalcode) = COND #(
               WHEN sy-subrc = 0 AND ls_cs_company_rg-internalcode IS NOT INITIAL
               THEN ls_cs_company_rg-internalcode
               ELSE gs_header-internalcode ).
             proposal_item_detail->costcenter =
               |{ lv_cs_ceco_prefix }{ lv_rg_internalcode }{ lv_cs_cebe }|.
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
           ELSE.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing
             FINAL(target_costcenter) = brf_helper->get_cc_code(
               iv_product      = proposal_item_detail->product
               iv_cc_origen    = proposal_item_detail->costcenterd4 " fourth digit of the origin cost center
               iv_departamento = proposal_item_detail->department
               iv_tipo_doc     = brf_helper->co_with_doctype-exp_reclassif ).
*               iv_tipo_doc     = brf_helper->co_with_doctype-sales ).

             IF target_costcenter IS NOT INITIAL.
               lv_profitcenter_i = proposal_item_detail->ProfitCenter.
               lv_profitcenter_c = lv_profitcenter_i.
               CONDENSE lv_profitcenter_c.
               proposal_item_detail->costcenter(4) = target_costcenter.
               proposal_item_detail->costcenter+7(3) = lv_profitcenter_c.
               IF proposal_item_detail->profitcentereq IS NOT INITIAL.
                 proposal_item_detail->costcenter+7(3) = proposal_item_detail->profitcentereq.
               ENDIF.
*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: reemplazar codigo interno por el de la sociedad RECEPTORA
               " Motivo: las posiciones 5-7 del CeCo (codigo interno de sociedad) nunca se
               " reemplazaban en el camino no-CS -> quedaba el codigo interno del PROVEEDOR
               " (heredado del basis item origen, ej. '112'=EBA) -> el CeCo terminaba
               " perteneciendo a EBA en vez de a la sociedad receptora -> KI100/KI302.
               READ TABLE lt_cs_companies INTO DATA(ls_rg_company)
                 WITH KEY companycode = proposal_item_detail->recipientcompanycode.
               IF sy-subrc = 0 AND ls_rg_company-internalcode IS NOT INITIAL.
                 proposal_item_detail->costcenter+4(3) = ls_rg_company-internalcode.
               ENDIF.
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: reemplazar codigo interno por el de la sociedad RECEPTORA
             ELSE.
               CLEAR proposal_item_detail->costcenter.
             ENDIF.
*Ini EXT_OSCUGALD 26.05.2026 - Cost Sharing
           ENDIF.
*Fin EXT_OSCUGALD 26.05.2026 - Cost Sharing

           " Account determination
*Ini EXT_OSCUGALD 27.05.2026 - Cost Sharing: READ TABLE en lugar de SELECT dentro del loop (ATC clean)
           IF lv_is_cs = abap_true.
*Ini EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO: lookup por glaccount1 en lugar de tarifftype
             READ TABLE lt_cs_pandlids_rg INTO DATA(ls_cs_pandlid_rg)
               WITH KEY glaccount1 = proposal_item_detail->glaccount.
*Fin EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO
             IF sy-subrc = 0 AND ls_cs_pandlid_rg-pandlid IS NOT INITIAL.
               proposal_item_detail->idl3 = ls_cs_pandlid_rg-pandlid.
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
*Fin EXT_OSCUGALD 27.05.2026 - Cost Sharing

           IF gs_header-providercountry = proposal_item_detail->recipientcountry.
             DATA(lv_optype) = zcl_interco_doc_glaccount=>co_operation_type-local.
           ELSE.
             lv_optype = zcl_interco_doc_glaccount=>co_operation_type-foreign.
           ENDIF.
*Ini EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: account_determination usar IDL2 en vez de IDL3
           " Motivo: mismo problema que en ZCL_PROPOSAL_BO_AR/AP (ver fix 07.09.2026 en esas clases).
           " El maestro ZI_INTERCOGLACCTDETERMINATION para servicios con desglose fino por
           " P&L (ej. ICSRV52) esta parametrizado a nivel IDL2, no IDL3.
           DATA(gl_account) = account_determination->get(
             i_tarifftype    = proposal_item_detail->tarifftype
             i_department    = proposal_item_detail->department
             i_pandlid       = proposal_item_detail->idl2
*             i_pandlid       = proposal_item_detail->idl3
             i_operationtype = lv_optype
           ).
           proposal_item_detail->glaccount = gl_account-glaccount1.
*Fin EXT_OSCUGALD 07.09.2026 - Fix RECL GASTO ICSRV52: account_determination usar IDL2 en vez de IDL3
           proposal_item_detail->glaccount2 = gl_account-glaccount2.
         ENDLOOP.

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO v2: base_BRL_L2 x sharerate (espejo AP v2)
         IF lv_is_cs = abap_true.

           " 1. base_BRL agrupada por (glaccount1, glaccount2) sin filtrar por sociedad
           TYPES: BEGIN OF ty_cs_rg_base_l2,
                    glaccount1 TYPE saknr,
                    glaccount2 TYPE saknr,
                    base_brl   TYPE zint_dte_fis_ksl,
                  END OF ty_cs_rg_base_l2.

           DATA lt_cs_rg_base_l2 TYPE HASHED TABLE OF ty_cs_rg_base_l2
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
               AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
               AND det~tarifftype          = '6'
               AND det~isdeleted           = ''
             WHERE bas~providercompanycode = @gs_header-providercompanycode
               AND bas~fiscalyear          = @gs_header-fiscalyear
               AND bas~fiscalperiod        = @gs_header-fiscalperiod
               AND bas~product             = @gs_header-product
             GROUP BY det~glaccount1, det~glaccount2
             INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rg_base_l2.

           " Validar P&L IDs con importe en base pero sin mapeo en determinacion de cuentas
           TYPES: BEGIN OF ty_cs_rg_pandl_no_map,
                    idl2 TYPE zi_intercopandlhierflattened-idl2,
                  END OF ty_cs_rg_pandl_no_map.
           DATA lt_cs_rg_pandl_no_map TYPE STANDARD TABLE OF ty_cs_rg_pandl_no_map WITH EMPTY KEY.

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
                   AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
                   AND tarifftype          = '6'
                   AND isdeleted           = ''
               )
             INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rg_pandl_no_map.
           " lt_cs_rc_pandl_no_map cargada → el error se registra en el loop de recipients abajo

           " 2. sharerate por sociedad desde proposal_items
           TYPES: BEGIN OF ty_cs_rg_share,
                    recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                    sharedrate           TYPE zi_intercoproposalitem-sharedrate,
                  END OF ty_cs_rg_share.

           DATA lt_cs_rg_shares TYPE HASHED TABLE OF ty_cs_rg_share
                                WITH UNIQUE KEY recipientcompanycode.

           LOOP AT proposal_items INTO DATA(ls_pi_rg_share).
             IF ls_pi_rg_share-sharedrate <> 0 AND
                NOT line_exists( lt_cs_rg_shares[ recipientcompanycode = ls_pi_rg_share-recipientcompanycode ] ).
               INSERT VALUE #(
                 recipientcompanycode = ls_pi_rg_share-recipientcompanycode
                 sharedrate           = ls_pi_rg_share-sharedrate
               ) INTO TABLE lt_cs_rg_shares.
             ENDIF.
           ENDLOOP.

           " 3. ordenar cuentas para residuo deterministico
           DATA lt_rg_base_sorted TYPE STANDARD TABLE OF ty_cs_rg_base_l2 WITH EMPTY KEY.
           lt_rg_base_sorted = VALUE #( FOR ls_b IN lt_cs_rg_base_l2 ( ls_b ) ).
           SORT lt_rg_base_sorted BY glaccount1.
           DATA(lv_rg_rows_cuentas) = lines( lt_rg_base_sorted ).

           " 4. total BRL por sociedad desde proposal_items_details
           TYPES: BEGIN OF ty_cs_rg_brl_soc,
                    recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                    total_brl            TYPE zint_dte_fis_ksl,
                    transactioncurrency  TYPE zint_dte_fis_hwaer,
                    exchangerate         TYPE zint_dte_ukurs,
                    companycodecurrency  TYPE waers,
                    globalcurrency       TYPE waers,
                  END OF ty_cs_rg_brl_soc.

           DATA lt_cs_rg_brl_soc TYPE HASHED TABLE OF ty_cs_rg_brl_soc
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
             INTO CORRESPONDING FIELDS OF TABLE @lt_cs_rg_brl_soc.

           " 5. expandir proposal_items_details: 1 fila/sociedad → N filas/cuenta_CS
           DATA lt_pid_cs LIKE proposal_items_details.

           TYPES: BEGIN OF ty_cs_rg_procesadas,
                    recipientcompanycode TYPE zfi_a_intrc_cpi-recipientcompanycode,
                  END OF ty_cs_rg_procesadas.
           DATA lt_cs_rg_socs_proc TYPE HASHED TABLE OF ty_cs_rg_procesadas
                                   WITH UNIQUE KEY recipientcompanycode.

           LOOP AT proposal_items_details REFERENCE INTO DATA(pid_orig).
             DATA(lv_soc_rg) = pid_orig->recipientcompanycode.
             CHECK NOT line_exists( lt_cs_rg_socs_proc[ recipientcompanycode = lv_soc_rg ] ).
             INSERT VALUE #( recipientcompanycode = lv_soc_rg ) INTO TABLE lt_cs_rg_socs_proc.

             TRY.
                 DATA(ls_share_rg) = lt_cs_rg_shares[ recipientcompanycode = lv_soc_rg ].
               CATCH cx_sy_itab_line_not_found.
                 CONTINUE.
             ENDTRY.
             DATA(lv_sharerate_rg) = CONV decfloat34( ls_share_rg-sharedrate ) / 100.

             TRY.
                 DATA(ls_brl_rg) = lt_cs_rg_brl_soc[ recipientcompanycode = lv_soc_rg ].
               CATCH cx_sy_itab_line_not_found.
                 CONTINUE.
             ENDTRY.
             DATA(lv_total_brl_rg) = CONV decfloat34( ls_brl_rg-total_brl ).

             DATA(lv_sum_rg) = CONV decfloat34( 0 ).

             DO lv_rg_rows_cuentas TIMES.
               READ TABLE lt_rg_base_sorted INTO DATA(ls_base_rg) INDEX sy-index.

               DATA(ls_pid_new) = pid_orig->*.
               ls_pid_new-glaccount           = ls_base_rg-glaccount1.
               ls_pid_new-glaccount2          = ls_base_rg-glaccount2.
               ls_pid_new-transactioncurrency = ls_brl_rg-transactioncurrency.
               ls_pid_new-exchangerate        = ls_brl_rg-exchangerate.
               ls_pid_new-companycodecurrency = ls_brl_rg-companycodecurrency.
               ls_pid_new-globalcurrency      = ls_brl_rg-globalcurrency.

               DATA lv_importe_rg TYPE decfloat34.
               IF sy-index < lv_rg_rows_cuentas.
                 lv_importe_rg = ls_base_rg-base_brl * lv_sharerate_rg.
                 lv_sum_rg += lv_importe_rg.
               ELSE.
                 lv_importe_rg = lv_total_brl_rg - lv_sum_rg.
               ENDIF.

               ls_pid_new-amountintransactioncurrency = lv_importe_rg.
               APPEND ls_pid_new TO lt_pid_cs.
             ENDDO.
           ENDLOOP.
           proposal_items_details = lt_pid_cs.

         ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO v2

         " Prepare the data to be posted as GL items in the financial documents.
         SELECT
            id,
            product,
            recipientcompanycode,
            recipientcountry,
*            recipientcustomer,
            profitcenter,
            tarifftype,
            tariffdescription,
            tariffrate,
            costcenter,
            glaccount,
            glaccount2,
            SUM( amountintransactioncurrency ) AS amountintransactioncurrency,
            transactioncurrency,
            companycodecurrency,
            globalcurrency,
            exchangerate
         FROM @proposal_items_details AS proposal_items_calc_detail
         GROUP BY
           id,
           product,
           recipientcompanycode,
           recipientcountry,
*           recipientcustomer,
           profitcenter,
           tarifftype,
           tariffdescription,
           tariffrate,
           costcenter,
           glaccount,
            glaccount2,
           transactioncurrency,
           companycodecurrency,
           globalcurrency,
           exchangerate
         INTO TABLE @DATA(recipient_glitems).

         IF recipient_glitems IS INITIAL.
           RETURN.
         ENDIF.
         DATA lv_rg_err_datetime TYPE zfi_a_intrc_cpid-createdat.

         LOOP AT recipient_glitems REFERENCE INTO FINAL(item_recla_ap)
                     GROUP BY item_recla_ap->recipientcompanycode INTO FINAL(recipient_company_code).

*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO: error si P&L sin mapeo (una vez por sociedad)
           IF lv_is_cs = abap_true AND lt_cs_rg_pandl_no_map IS NOT INITIAL.
             DATA(lv_rg_pandl_list) = REDUCE string(
               INIT s = ``
               FOR ls_no_map IN lt_cs_rg_pandl_no_map
               NEXT s = COND #( WHEN s IS INITIAL
                                THEN ls_no_map-idl2
                                ELSE |{ s }, { ls_no_map-idl2 }| ) ).
             DATA(lv_rg_err_dockey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }{ recipient_company_code }|.
             DATA(lv_rg_err_detail) = VALUE #( proposal_items_details[ recipientcompanycode = recipient_company_code ] OPTIONAL ).
             APPEND VALUE #(
               id           = lv_rg_err_detail-id
               item_id      = lv_rg_err_detail-item_id
               documenttype = zcl_proposal_bo_abs=>c_document_type-expensreclassif
               documentkey  = lv_rg_err_dockey
             ) TO gt_doc_map.
             add_msg_to_log(
               iv_current_item = CORRESPONDING #( lv_rg_err_detail )
               iv_dockey       = lv_rg_err_dockey
               iv_doctype      = mv_posting_doctype
               iv_message_text = |CS RECL GASTO: P&L sin cuenta asignada: { lv_rg_pandl_list } (producto { gs_header-product }).|
             ).
             GET TIME STAMP FIELD lv_rg_err_datetime.
             mapping_doc(
               EXPORTING
                 iv_doctype      = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                 iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                 iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                 iv_isadjustment = space
                 its_doc         = gts_doc
                 iv_byuser       = CONV #( cl_abap_context_info=>get_user_technical_name( ) )
                 iv_attime       = lv_rg_err_datetime
               CHANGING
                 ct_map_id_doc   = gt_doc_map ).
             CLEAR: gt_doc_map, gta_je_post.
             CONTINUE.
           ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO: error si P&L sin mapeo

           APPEND INITIAL LINE TO gta_je_post REFERENCE INTO DATA(journal_entry).
           """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
           " HEADER
           """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
           journal_entry->%cid = |{ zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap }{ sy-datum }{ sy-tabix }|.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: usar group key (evita DATREF en contexto paralelo)
           " item_recla_ap->recipientcompanycode y recipient_company_code son el mismo valor.
           " Para CS se usa recipient_company_code (VALUE type) para evitar NULL ref en RFC paralelo.
***           journal_entry->%param-companycode = COND #( WHEN lv_is_cs = abap_true
***                                                       THEN recipient_company_code
***                                                       ELSE item_recla_ap->recipientcompanycode ).
           journal_entry->%param-companycode = recipient_company_code.  "correcion dump ICSRV52
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
           journal_entry->%param-documentdate = ld_lastday.
           journal_entry->%param-postingdate = ld_lastday.
           journal_entry->%param-accountingdocumenttype = 'CH'.
           journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient_company_code } { gs_header-productname }|.
*Ini EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO: codigo material en referencia cabecera
           IF lv_is_cs = abap_true.
             journal_entry->%param-documentreferenceid = gs_header-product.
           ENDIF.
*Fin EXT_OSCUGALD 24.06.2026 - CS Fix RECL GASTO: codigo material en referencia cabecera
           journal_entry->%param-createdbyuser = cl_abap_context_info=>get_user_technical_name( ).
*Ini EXT_OSCUGALD DD.MM.2026 - Fix RECL GASTO fusion: ledger group 0LL1 para no-CS (Bermudas va por mapping_bo_sec_mic)
           IF lv_is_cs = abap_true.
             journal_entry->%param-ledgergroup = 'L2L3'.
           ELSE.
             journal_entry->%param-ledgergroup = '0LL1'.
           ENDIF.
*Fin EXT_OSCUGALD DD.MM.2026 - Fix RECL GASTO fusion: ledger group 0LL1 para no-CS
*            journal_entry->%param-ledgergroup = 'L2L3'.

           CLEAR lv_position_num.
           LOOP AT GROUP recipient_company_code REFERENCE INTO FINAL(recipient_item).
             CHECK recipient_item->amountintransactioncurrency IS NOT INITIAL.

             APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
             lv_position_num += 1.
             gl_item->glaccountlineitem = lv_position_num.
             gl_item->glaccount = recipient_item->glaccount.
             gl_item->partnercompany = recipient_item->recipientcompanycode.
             gl_item->documentitemtext = |{ gs_header-ProviderCompanyCode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
             gl_item->material = gs_header-product.
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: assignment = 'COST SHARING'
             gl_item->assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                                 THEN 'COST SHARING'
                                                                 ELSE gs_header-productname ).
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing
             gl_item->costcenter = recipient_item->costcenter.

*             READ TABLE proposal_items INTO DATA(ls_proposal_items) WITH KEY id      = recipient_item->id
*                                                                             item_id = proposal_item_detail->item_id
*                                                                             product = gs_header-Product.

             APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount).
             gl_item_amount->currency = recipient_item->transactioncurrency.
*             gl_item_amount->currency = ls_proposal_items-transactioncurrency.
             gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency.
             gl_item_amount->currencyrole = '00'.
             IF exchange_rates[] IS NOT INITIAL.
               DATA(exchange_rate) = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency
                                                     targetcurrency = recipient_item->globalcurrency ]-exchangerate.
             ENDIF.
             gl_item_amount->exchangerate = exchange_rate.

             APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.
             lv_position_num += 1.
             gl_item->glaccountlineitem = lv_position_num.
*Ini EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO: pos 2 usa glaccount2 (693002) para CS
*             gl_item->glaccount = COND #(
*               WHEN lv_is_cs = abap_true AND recipient_item->glaccount2 IS NOT INITIAL
*               THEN recipient_item->glaccount2
*               ELSE recipient_item->glaccount ).
*Fin EXT_OSCUGALD 22.06.2026 - CS Fix RECL GASTO
*Ini EXT_OSCUGALD 13.10.2026 - Fix RECL GASTO ICSRV5x: pos 2 usa glaccount2 tambien para no-CS
             " Motivo: la condicion anterior solo usaba glaccount2 si lv_is_cs = abap_true.
             " Los ICSRV5x (reemplazo de Cost Sharing) corren por el camino no-CS, por lo que la
             " linea 2 se posteaba con glaccount (igual a la linea 1) y el documento 70 se anulaba
             " a si mismo, sin llegar nunca a la cuenta glaccount2 configurada en Determinacion
             " de Cuentas (ej. ICSRV54: 5408010006). Si glaccount2 viene vacio se mantiene el
             " comportamiento anterior (glaccount). Para Cost Sharing el resultado no cambia.
             gl_item->glaccount = COND #(
               WHEN recipient_item->glaccount2 IS NOT INITIAL
               THEN recipient_item->glaccount2
               ELSE recipient_item->glaccount ).
*Fin EXT_OSCUGALD 13.10.2026 - Fix RECL GASTO ICSRV5x: pos 2 usa glaccount2 tambien para no-CS
*             gl_item->glaccount = recipient_item->glaccount.
             gl_item->partnercompany = recipient_item->recipientcompanycode.
             gl_item->documentitemtext = |{ gs_header-ProviderCompanyCode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
             gl_item->material = gs_header-product.
             gl_item->assignmentreference = COND #( WHEN lv_is_cs = abap_true
                                                                 THEN 'COST SHARING'
                                                                 ELSE gs_header-productname ).
             gl_item->costcenter = recipient_item->costcenter.
             APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
             gl_item_amount->currency = recipient_item->transactioncurrency.
*             gl_item_amount->currency = ls_proposal_items-transactioncurrency.
             gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency * -1.
             gl_item_amount->currencyrole = '00'.
             IF exchange_rates[] IS NOT INITIAL.
               exchange_rate = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency
                                               targetcurrency = recipient_item->globalcurrency ]-exchangerate.
             ENDIF.
             gl_item_amount->exchangerate = exchange_rate.

           ENDLOOP.

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
             doc_map->documenttype       = zcl_proposal_bo_abs=>c_document_type-expensreclassif.
             doc_map->documentkey        = |DUMMY{ proposal_item->documentkey }{ gs_header-providercompanycode }{ gs_header-product }{ proposal_item->recipientcompanycode }|.
           ENDDO.

           DATA(lo_list_bo) = NEW zcl_proposal_bo_recl_gasto_par( iv_process = gv_process
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
           RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
         ENDIF.
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

* Ini EXT_OSCUGALD 03.08.2026 - Bermudas MIC (SDFPSINIC-23362)
     " Flag Bermudas: se evalua UNA sola vez fuera del loop (ATC: no SELECT en loop).
     SELECT SINGLE low FROM zi_tvarvc
       WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
       INTO @DATA(lv_is_mic_rev_rp).
     DATA(lv_bermudas_rev) = xsdbool( sy-subrc = 0 ).
* Fin EXT_OSCUGALD 03.08.2026 - Bermudas MIC
     CHECK gtd_doc IS NOT INITIAL.
     LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
*       DATA(lv_posting_date) = lt_posting_date[ fiscalyear = gs_header-fiscalyear companycode = <fs_doc>-companycode accountingdocument = <fs_doc>-documentkey ].
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

* Ini EXT_OSCUGALD 03.08.2026 - Bermudas MIC (SDFPSINIC-23362)
       " Bermudas reversa en la sociedad real del doc; resto sin cambios.
*Ini EXT_OSCUGALD 08.09.2026 - Fix anulacion RECL GASTO: reversar en sociedad RECEPTORA
       " BUG REAL ENCONTRADO: este bloque (copiado igual en AR/RECL_COMP/RECL_GASTO) asume
       " que el documento a revertir vive en la sociedad PROVEEDORA (correcto para AR y
       " RECL_COMP, que postean bajo gs_header-providercompanycode). Pero RECL_GASTO postea
       " el documento original bajo la sociedad RECEPTORA (ver fix 07.09.2026 en
       " mapping_bo_sec) -> forzar providercompanycode aca pedia revertir el documento en
       " la sociedad equivocada -> error de objeto de imputacion de otra sociedad.
       " FIX: usar siempre <fs_doc>-companycode (la sociedad real del documento), igual
       " que ya hace ZCL_PROPOSAL_BO_AP.
       <jr>-companycode = <fs_doc>-companycode.
*       IF lv_bermudas_rev = abap_true.
*         <jr>-companycode = <fs_doc>-companycode.
*       ELSE.
*         <jr>-companycode = gs_header-providercompanycode.
*       ENDIF.
*Fin EXT_OSCUGALD 08.09.2026 - Fix anulacion RECL GASTO: reversar en sociedad RECEPTORA
* Fin EXT_OSCUGALD 03.08.2026 - Bermudas MIC
       <jr>-fiscalyear = gs_header-fiscalyear.
       <jr>-accountingdocument = CONV #( <fs_doc>-documentkey ).
       <jr>-%param = VALUE #(
*                             postingdate    = ld_today
                             PostingDate    = lv_posting_date
                             reversalreason = '01'
                             createdbyuser  = cl_abap_context_info=>get_user_technical_name( )
                            ).
       APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
       <fs_doc_map> = <fs_doc>.
       <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-documentkey }|.
       <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_expensrec.
       <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
       <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-expensreclassif.


       DATA(lo_exe_bo) = NEW zcl_proposal_bo_recl_gasto_par( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
*                                                             iv_documentkey = <fs_doc>-Documentkey
                                                             iv_parentdockey = <fs_doc>-documentkey
                                                             its_doc        = gts_doc
                                                             it_doc_map     = gt_doc_map
                                                             it_je_rev      = gta_jr_rev ).

       APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
       <fs_list_bo> = lo_exe_bo.

*       exe_anulation_bo_sec( EXPORTING iv_dockey     = <fs_doc>-Documentkey
*                             CHANGING  ct_map_id_doc = gt_doc_map ).
     ENDLOOP.
     CHECK gtd_list_bo IS NOT INITIAL.
     exe_bo( )."Return the data on me->gt_doc_map
     et_doc_map = me->gt_doc_map.
     IF gt_doc_map[] IS INITIAL OR
         line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
         OR line_exists( gt_doc_map[ status = abap_false ] ).
       RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
     ENDIF.
   ENDMETHOD.


   METHOD exe_bo.
     DATA lv_debug TYPE abap_boolean.
     DATA lo_recl_gasto_par   TYPE REF TO zcl_proposal_bo_recl_gasto_par.
     DATA lv_status_log TYPE c.
     DATA lt_expensrecl TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.
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
         lo_recl_gasto_par ?= <l_out>-inst.
       ELSE.
         lo_recl_gasto_par ?= gtd_list_bo[ <l_out>-index ].
         lt_expensrecl = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                        number   = '022'
                                                        severity = if_abap_behv_message=>severity-error ) ) ).

         mapping_doc_log(
           EXPORTING
*            iv_dockey     =
             iv_doctype    = zcl_proposal_bo_abs=>c_document_type-expensreclassif
             it_reported   = lt_expensrecl
           CHANGING
             ct_map_id_doc = lo_recl_gasto_par->gt_doc_map_rg
             cv_status     = lv_status_log
         ).
         mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                                iv_doctype      = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                                iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                                iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-reclasification
                                iv_isadjustment = space
                                its_doc         = gts_doc
                                iv_byuser       = lv_byuser
                                iv_attime       = lv_attime
                      CHANGING  ct_map_id_doc   = lo_recl_gasto_par->gt_doc_map_rg ).
       ENDIF.
       APPEND LINES OF lo_recl_gasto_par->gt_doc_map_rg TO me->gt_doc_map.
     ENDLOOP.
   ENDMETHOD.

   METHOD mapping_bo_sec_mic.
*───────────────────────────────────────────────────────────────────────────
* EXT_OSCUGALD 01.08.2026 - Bermudas MIC-USA (SDFPSINIC-23362)
* Reclasificacion de Gastos (RP) para Bermudas. Espejo del RR (recl_comp).
* Asiento de 2 lineas en el ledger de gestion L2L3, dentro de la MISMA
* sociedad que el AP:
*   - Linea GL cuenta base recl (693001 = glaccount1) al debe → positivo
*   - Linea GL cuenta costo (598000 = glaccount2) al haber → negativo
* Cuentas desde ZINT_A_MD_GLACCT doctype RP (glaccount1/glaccount2).
* Solo se genera si hubo AP.
*
* Direccion (igual que AP): RP sigue la sociedad del AP (contraria al AR).
*   lv_amount_tc > 0 → MIC factura a USA → AP/RP en MIC
*   lv_amount_tc < 0 → USA factura a MIC → AP/RP en USA
* Reglas (validadas con molde produccion RP y con RR ya probado en TS4):
*   - CeCo dinamico SOLO en la cuenta base recl (693001), no en la de costo.
*   - VBUND (trading partner) = contraparte, en ambas lineas.
*   - Ledger L2L3. Clase doc CH. Cuentas: determinacion SIEMPRE con MIC.
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

     DATA lv_cebe_prctr TYPE prctr.
     lv_cebe_prctr = |{ lv_ceco_cebe ALPHA = IN }|.

     " Relaciones interco de MIC (para derivar contraparte / internalcodes).
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

     " Determinacion de cuentas RP: SIEMPRE con MIC como provider.
     DATA(account_determination) = NEW zcl_interco_doc_glaccount(
       i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-reclassification_ap
       i_product               = gs_header-product
       i_provider_company_code = gs_header-providercompanycode
       i_valid_at              = ld_lastday ).

     " Cuentas RP: glaccount1 = base recl (693001), glaccount2 = costo (598000).
     DATA(gl_account) = account_determination->get(
       i_tarifftype = zcl_interco_doc_glaccount=>co_tariff_type-basis
       i_department = space
       i_pandlid    = space ).

     LOOP AT totals_mic REFERENCE INTO DATA(total_mic).

       DATA(lv_amount_tc) = total_mic->amountintransactioncurrency.
       IF lv_amount_tc = 0.
         CONTINUE.
       ENDIF.

       " Direccion (igual que AP): RP en la sociedad del AP (contraria al AR).
       DATA(lv_rp_companycode) = COND bukrs(
         WHEN lv_amount_tc > 0
         THEN gs_header-providercompanycode       " RP en MIC
         ELSE total_mic->recipientcompanycode ).  " RP en USA

       DATA(lv_rp_counterparty) = COND bukrs(
         WHEN lv_rp_companycode = gs_header-providercompanycode
         THEN total_mic->recipientcompanycode
         ELSE gs_header-providercompanycode ).

       " CeCo dinamico: prefijo + internalcode(sociedad RP) + CeBe.
       READ TABLE lt_company_ic INTO DATA(ls_company_ic)
         WITH KEY companycode = lv_rp_companycode.
       DATA lv_ceco_mic TYPE kostl.
       IF sy-subrc = 0 AND ls_company_ic-internalcode IS NOT INITIAL.
         lv_ceco_mic = |{ lv_ceco_prefix }{ ls_company_ic-internalcode }{ lv_ceco_cebe }|.
       ELSE.
         add_msg_to_log(
           iv_current_item = VALUE #( )
           iv_dockey       = |DUMMYRP{ lv_rp_companycode }{ gs_header-product }|
           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-expensreclassif
           iv_message_type = 'E'
           iv_message_text = |No se encontro internalcode para sociedad { lv_rp_companycode } en zi_intercocompanycode.| ).
         CONTINUE.
       ENDIF.

       DATA(lv_doctext) = |{ lv_rp_counterparty }-{ lv_rp_companycode } Royalties { gs_header-fiscalperiod }.{ gs_header-fiscalyear }|.

       APPEND INITIAL LINE TO gta_je_post REFERENCE INTO DATA(journal_entry).

       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       " HEADER — clase CH (reclasificacion), ledger L2L3, sociedad RP
       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       journal_entry->%cid = |RP{ lv_rp_companycode }{ gs_header-product }{ sy-tabix }|.
       journal_entry->%param-companycode                  = lv_rp_companycode.
       journal_entry->%param-documentdate                 = ld_lastday.
       journal_entry->%param-postingdate                  = ld_lastday.
       journal_entry->%param-accountingdocumenttype       = 'CH'.
       journal_entry->%param-accountingdocumentheadertext = 'Royalties'.
       journal_entry->%param-createdbyuser                = cl_abap_context_info=>get_user_technical_name( ).
       journal_entry->%param-ledgergroup                  = 'L2L3'.

       " LINEA 1 — cuenta costo (glaccount2 = 598000) al haber (negativo).
       " Molde produccion RP: posicion 1 = 598000 al haber, CON CeCo.
       " (Las cuentas de costo exigen imputacion CO, a diferencia del ingreso del RR.)
       APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item1).
       gl_item1->glaccount           = gl_account-glaccount2.
       gl_item1->glaccountlineitem   = 1.
       gl_item1->assignmentreference = 'REGALIAS'.
       gl_item1->documentitemtext    = lv_doctext.
       gl_item1->material            = gs_header-product.
       " Cuenta de costo: solo CeCo (SAP deriva el profitcenter del CeCo, igual
       " que el AP que postea OK). Setear profitcenter manual causa el error CO.
       gl_item1->costcenter          = lv_ceco_mic.
       gl_item1->partnercompany      = lv_rp_counterparty.

       APPEND INITIAL LINE TO gl_item1->_currencyamount REFERENCE INTO DATA(gl_amount1).
       gl_amount1->currencyrole           = '00'.
       gl_amount1->currency               = total_mic->transactioncurrency.
       gl_amount1->journalentryitemamount = abs( lv_amount_tc ) * -1.
       gl_amount1->exchangerate           = 1.

       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       " LINEA 2 — cuenta base recl (glaccount1 = 693001) al debe (positivo).
       " Molde produccion RP: posicion 2 = 693001 al debe, CON CeCo.
       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item2).
       gl_item2->glaccount           = gl_account-glaccount1.
       gl_item2->glaccountlineitem   = 2.
       gl_item2->assignmentreference = 'REGALIAS'.
       gl_item2->documentitemtext    = lv_doctext.
       gl_item2->material            = gs_header-product.
       gl_item2->costcenter          = lv_ceco_mic.
       gl_item2->partnercompany      = lv_rp_counterparty.

       APPEND INITIAL LINE TO gl_item2->_currencyamount REFERENCE INTO DATA(gl_amount2).
       gl_amount2->currencyrole           = '00'.
       gl_amount2->currency               = total_mic->transactioncurrency.
       gl_amount2->journalentryitemamount = abs( lv_amount_tc ).
       gl_amount2->exchangerate           = 1.

       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       " DOC_MAP — claves completas por item (VALUE con FOR/WHERE, sin loop anidado)
       """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
       DATA(lv_rp_dockey) = |DUMMYRP{ lv_rp_companycode }{ gs_header-product }{ gs_header-fiscalperiod }|.
       gt_doc_map = VALUE #( BASE gt_doc_map
         FOR prop_item IN gtd_items_add
         WHERE ( recipientcompanycode = total_mic->recipientcompanycode )
         ( id           = prop_item-id
           item_id      = prop_item-item_id
           itembasis_id = prop_item-itembasis_id
           itemcalc_id  = prop_item-itemcalc_id
           companycode  = lv_rp_companycode
           documenttype = zcl_proposal_bo_abs=>c_document_type-expensreclassif
           documentkey  = lv_rp_dockey ) ).

       DATA(lo_list_bo) = NEW zcl_proposal_bo_recl_gasto_par(
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
