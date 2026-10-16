CLASS zcl_proposal_bo_pi DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post .
    TYPES:
      gsty_glitems TYPE LINE OF gsty_post-%param-_glitems .

    DATA:
      gta_je_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
    DATA:
      gta_jr_rev  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .
    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .
  PROTECTED SECTION.
    METHODS:
      preparedata REDEFINITION,
      exe_bo REDEFINITION,
      mapping_bo_sec REDEFINITION,
      mapping_reverse_sec REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_pi IMPLEMENTATION.


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
    TYPES ty_r_bukrs TYPE RANGE OF bukrs.
    DATA lr_recip TYPE ty_r_bukrs.
    DATA: lv_profitcenter_i TYPE i,
          lv_profitcenter_c TYPE c LENGTH 10.

    DATA: lv_profitcenter_conv TYPE c LENGTH 10.

    FIELD-SYMBOLS <tariff_type> TYPE zint_tariff_type.
    TYPES:
      BEGIN OF ty_glitem_mapping,
        type         TYPE string,
        amount_field TYPE string,
        tariff_type  TYPE string,
      END OF ty_glitem_mapping,
      tt_glitem_mapping TYPE TABLE OF ty_glitem_mapping WITH KEY type.

    IF gv_process <> zcl_boproposal_tools=>gc_create_doc.
      RETURN.
    ENDIF.

    TRY.
        DATA(ld_lastday) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
        SORT gtd_items_add BY providercompanycode product recipientcompanycode.

        SELECT _items_add~*
        FROM zi_intercoglacctdetermination AS _glacc
        INNER JOIN @gtd_items_add AS _items_add ON _glacc~product = _items_add~product
                                                AND _glacc~recipientcompanycode = _items_add~recipientcompanycode
         WHERE _glacc~validfrom <= @ld_lastday
           AND _glacc~validto >= @ld_lastday
           AND _glacc~doctype = @zcl_interco_doc_glaccount=>co_doc_type-accural_pi
           AND _glacc~product = @gs_header-product
           AND _glacc~isdeleted IS INITIAL
                 INTO TABLE @DATA(lt_items_pi).

        DATA(gl_item_mappings) = VALUE tt_glitem_mapping(
                 ( type = 'BASE'           amount_field = 'AMOUNTINTRASACTIONCURRENCY' tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-BASIS' )
                 ( type = 'MARKUP'         amount_field = 'MARKUPAMOUNT'               tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-MARKUP' )
                 ( type = 'GROSSUP MARGIN' amount_field = 'GROSSINGUPMARGINAMOUNT'     tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_MARGIN' )
                 ( type = 'GROSSUP BASE'   amount_field = 'GROSSINGUPBASEAMOUNT'       tariff_type = 'ZCL_INTERCO_DOC_GLACCOUNT=>CO_TARIFF_TYPE-GROSSUP_BASIS' )
        ).
        DATA(account_determination) = NEW zcl_interco_doc_glaccount( i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-accural_pi
                                                                     i_product               = gs_header-product
                                                                     i_provider_company_code = space
                                                                     i_valid_at              = ld_lastday
                                                                     ).
        DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
        CHECK lt_items_pi IS NOT INITIAL.
        FINAL(proposal_items) = lt_items_pi.

**********************************************************************
* Third version
**********************************************************************
        "gtd_items_add only contains position without documents generated
        "to avoid generate duplicate documents
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
    WHERE proposal_items_calc_detail~id = @gs_header-id
        AND tariffrate > 0
*    ORDER BY proposal_items_calc_detail~product, recipientcompanycode, tarifftype
    INTO TABLE @DATA(proposal_items_details).

        SELECT DISTINCT sourcecurrency, targetcurrency, abs( i_exchangeraterawdata~exchangerate ) AS exchangerate FROM i_exchangeraterawdata
        INNER JOIN @proposal_items_details AS proposal_items_details ON
            proposal_items_details~companycodecurrency = i_exchangeraterawdata~sourcecurrency AND
            proposal_items_details~globalcurrency = i_exchangeraterawdata~targetcurrency
          WHERE exchangeratetype = 'B'
            AND validitystartdate = @ld_lastday
          INTO TABLE @DATA(exchange_rates).

        LOOP AT proposal_items_details REFERENCE INTO DATA(proposal_item_detail).
          " Cost Center Determination
          FINAL(target_costcenter) = brf_helper->get_cc_code(
            iv_product      = proposal_item_detail->product
            iv_cc_origen    = proposal_item_detail->costcenterd4 " fourth digit of the origin cost center
            iv_departamento = proposal_item_detail->department
            iv_tipo_doc     = brf_helper->co_with_doctype-purchase ).

          IF target_costcenter IS NOT INITIAL.
            lv_profitcenter_i = proposal_item_detail->ProfitCenter.
            lv_profitcenter_c = lv_profitcenter_i.
            CONDENSE lv_profitcenter_c.
            proposal_item_detail->costcenter(4) = target_costcenter.
            proposal_item_detail->costcenter+7(3) = lv_profitcenter_c.
            IF proposal_item_detail->profitcentereq IS NOT INITIAL.
              proposal_item_detail->costcenter+7(3) = proposal_item_detail->profitcentereq.
              proposal_item_detail->profitcenter+7(3) = proposal_item_detail->profitcentereq.   "cuenta 1 cebe padre.
            ENDIF.
          ELSE.
            CLEAR proposal_item_detail->costcenter.
          ENDIF.

          " Account determination
          IF gs_header-providercountry = proposal_item_detail->recipientcountry.
            DATA(lv_optype) = zcl_interco_doc_glaccount=>co_operation_type-local.
          ELSE.
            lv_optype = zcl_interco_doc_glaccount=>co_operation_type-foreign.
          ENDIF.

          DATA(gl_account) = account_determination->get(
            i_tarifftype    = proposal_item_detail->tarifftype
            i_department    = proposal_item_detail->department
            i_pandlid       = proposal_item_detail->idl3
            i_operationtype = lv_optype
          ).
          proposal_item_detail->glaccount = gl_account-glaccount1.
          proposal_item_detail->glaccount2 = gl_account-glaccount2.
        ENDLOOP.

        " Prepare the data to be posted as GL items in the financial documents.
        SELECT
           id,
           product,
           recipientcompanycode,
           recipientcountry,
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

        " Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C20e: precargar BLART de previsión
        DATA(lo_blart_pi) = NEW zcl_interco_doc_blart(
          i_valid_at              = ld_lastday
          i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-accural_pi
          i_provider_company_code = gs_header-providercompanycode ).
        " Fin EXT_OSCUGALD 14.10.2026 - C20e

        LOOP AT recipient_glitems REFERENCE INTO FINAL(item_recla_ar)
            GROUP BY item_recla_ar->recipientcompanycode INTO FINAL(recipient_company_code).

          APPEND INITIAL LINE TO gta_je_post REFERENCE INTO DATA(journal_entry).
          """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          " HEADER
          """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          journal_entry->%cid = |{ zcl_interco_doc_glaccount=>co_doc_type-reclassification_ar }{ sy-datum }{ sy-tabix }|.
          journal_entry->%param-companycode = gs_header-providercompanycode.
          journal_entry->%param-documentdate = ld_lastday.
          journal_entry->%param-postingdate = ld_lastday.
          " Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C20e: resolver BLART de previsión
***          journal_entry->%param-accountingdocumenttype = 'CH'.

          DATA(lv_amount_pi) = REDUCE fis_wsl(
            INIT total = CONV fis_wsl( 0 )
            FOR item_pi IN GROUP recipient_company_code
            NEXT total = total + item_pi-amountintransactioncurrency ).

          DATA(lv_blart_pi) = lo_blart_pi->get(
            i_recipientcompanycode = recipient_company_code
            i_paymenttype          = gs_header-paymenttype
            i_amount               = lv_amount_pi ).

          journal_entry->%param-accountingdocumenttype = COND #(
            WHEN lv_blart_pi IS NOT INITIAL THEN lv_blart_pi
            ELSE 'CH' ).
          " Fin EXT_OSCUGALD 14.10.2026 - C20e
          journal_entry->%param-accountingdocumentheadertext = 'Prevision Incobrables'.
*          journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient_company_code } { gs_header-ProductName }|.
          journal_entry->%param-createdbyuser = cl_abap_context_info=>get_user_technical_name( ).

          CLEAR lv_position_num.
          LOOP AT GROUP recipient_company_code REFERENCE INTO FINAL(recipient_item).
            CHECK recipient_item->amountintransactioncurrency IS NOT INITIAL.

            APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
            lv_position_num += 1.
            gl_item->glaccount = recipient_item->glaccount2.
            gl_item->glaccountlineitem = lv_position_num.
            gl_item->partnercompany = recipient_item->recipientcompanycode.
            gl_item->assignmentreference = gs_header-productname.
            gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
            gl_item->material = gs_header-product.
            gl_item->profitcenter = recipient_item->profitcenter.
            APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount).
            gl_item_amount->currency = recipient_item->transactioncurrency.
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
            gl_item->assignmentreference = gs_header-productname.
            gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_item->recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
            gl_item->material = gs_header-product.
            gl_item->costcenter = recipient_item->costcenter.
            APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
            gl_item_amount->currency = recipient_item->transactioncurrency.
            gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency.
            gl_item_amount->currencyrole = '00'.
            IF exchange_rates[] IS NOT INITIAL.
              exchange_rate = exchange_rates[ sourcecurrency = recipient_item->companycodecurrency
                                              targetcurrency = recipient_item->globalcurrency ]-exchangerate.
            ENDIF.
            gl_item_amount->exchangerate = exchange_rate.
          ENDLOOP.

          "Evita ejecucion sino existen registros de cuentas gl en pos (posibles montos en ceros).
          IF journal_entry->%param-_glitems[] IS INITIAL.
            CLEAR: gt_doc_map, gta_je_post, lv_position_num.
            CONTINUE.
          ENDIF.

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
            doc_map->documenttype       = zcl_proposal_bo_abs=>c_document_type-debtprovision.  "Previsión de Incobrables
            doc_map->documentkey        = |DUMMY{ proposal_item->documentkey }{ gs_header-providercompanycode }{ gs_header-product }{ proposal_item->recipientcompanycode }|.
          ENDDO.
          DATA(lo_list_bo) = NEW zcl_proposal_bo_pi_parallel( iv_process = zcl_boproposal_tools=>gc_create_doc
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
        OR line_exists( gt_doc_map[ status = abap_false ] ).
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
      READ TABLE lt_posting_date WITH KEY fiscalyear = gs_header-fiscalyear
                                 companycode = gs_header-providercompanycode
                                 accountingdocument = <fs_doc>-documentkey
                                 INTO DATA(ls_posting_date_line).
      IF sy-subrc = 0.
        DATA(lv_posting_date) = ls_posting_date_line-postingdate.
      ENDIF.
      CLEAR: gta_jr_rev,gt_doc_map.

      CHECK NOT line_exists( gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ] )
      OR gtd_anul_doc[ parentdocumentkey = <fs_doc>-documentkey ]-documentkey(5) EQ 'DUMMY'.

      APPEND INITIAL LINE TO gta_jr_rev ASSIGNING FIELD-SYMBOL(<jr>).

      <jr>-companycode = gs_header-providercompanycode.
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
      <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_debtprovision.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-debtprovision.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_pi_parallel( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
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
    DATA lo_baddebtprovision   TYPE REF TO zcl_proposal_bo_pi_parallel.
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
        lo_baddebtprovision ?= <l_out>-inst.
      ELSE.
        lo_baddebtprovision ?= gtd_list_bo[ <l_out>-index ].
        lt_incomrecl = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                      number   = '022'
                                                      severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-debtprovision
            it_reported   = lt_incomrecl
          CHANGING
            ct_map_id_doc = lo_baddebtprovision->gt_doc_map_pi
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-debtprovision
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-reclasification
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = lv_byuser
                               iv_attime       = lv_attime
                     CHANGING  ct_map_id_doc   = lo_baddebtprovision->gt_doc_map_pi ).
      ENDIF.
      APPEND LINES OF lo_baddebtprovision->gt_doc_map_pi TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
