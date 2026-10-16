CLASS zcl_proposal_bo_interdiv DEFINITION
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
ENDCLASS.



CLASS zcl_proposal_bo_interdiv IMPLEMENTATION.


  METHOD preparedata.
    mv_posting_doctype = c_document_type-interdiv.
    mv_reverse_doctype = c_document_type-anul_interdiv.

    DELETE gtd_items_add WHERE interdivisional = abap_false OR with_interdiv = abap_true.
  ENDMETHOD.


  METHOD mapping_bo_sec.
    TYPES ty_lineitem TYPE n LENGTH 6.

    TYPES:
      BEGIN OF ty_proposal_items_details.
        INCLUDE TYPE zcl_interco_proposal_data=>ty_items_details.
    TYPES: glaccount1  TYPE saknr,
        glaccount2  TYPE saknr,
        costcenter1 TYPE kostl,
        costcenter2 TYPE kostl.
    TYPES: END OF ty_proposal_items_details.
    TYPES tt_proposal_items_details TYPE TABLE OF ty_proposal_items_details WITH DEFAULT KEY.

    zcl_interco_utils=>unit_code_outbound( EXPORTING im_value = '%'
                                           IMPORTING ex_value = FINAL(base_unit) ).

    " just to get a better naming
    DATA(journal_entries) = gta_je_post.
    DATA(proposal_items) = gtd_items_add.
*    DATA target_costcenter TYPE zde_cc_code.
    DATA(proposal_items_details) = CORRESPONDING tt_proposal_items_details( mo_data->get_for_journalentry( CORRESPONDING #( proposal_items ) ) ).

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

    " Replace the original GL account and Cost Center with their target values
    " determined by business rules:
    "   - Cost Center: obtained from BRF+ determination logic
    "   - GL Account: obtained from a custom account determination class
    DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
    DATA(account_determination) = NEW zcl_interco_doc_glaccount(
                                i_doctype = zcl_interco_doc_glaccount=>co_doc_type-interdivisinoal
                                i_product = gs_header-product
                                i_provider_company_code = gs_header-providercompanycode
                                i_valid_at = last_day_of_month ).
    DELETE proposal_items_details WHERE tarifftype <> account_determination->co_tariff_type-basis.

    SELECT DISTINCT sourcecurrency, targetcurrency, abs( i_exchangeraterawdata~exchangerate ) AS exchangerate FROM i_exchangeraterawdata
    INNER JOIN @proposal_items_details AS proposal_items_details ON proposal_items_details~companycodecurrency = i_exchangeraterawdata~sourcecurrency AND proposal_items_details~globalcurrency = i_exchangeraterawdata~targetcurrency
      WHERE exchangeratetype = 'B'
        AND validitystartdate = @last_day_of_month
      INTO TABLE @DATA(exchange_rates).

    LOOP AT proposal_items_details REFERENCE INTO DATA(proposal_item_detail).

      " Account determination
      DATA(gl_account) = account_determination->get(
                       i_tarifftype = proposal_item_detail->tarifftype
                       i_department = proposal_item_detail->department
                       i_pandlid    = proposal_item_detail->idl3
                     ).

      proposal_item_detail->glaccount1 = gl_account-glaccount1.
      proposal_item_detail->glaccount2 = gl_account-glaccount2.

*      " Cost Center Determination 1
      proposal_item_detail->costcenter1 = proposal_item_detail->costcenter.
      DATA(target_costcenter)   = brf_helper->get_cc_code(
          iv_product      = proposal_item_detail->product
          iv_cuenta       = gl_account-glaccount1
          iv_cc_origen    = proposal_item_detail->costcenterd4 " fourth digit of the origin cost center
          iv_departamento = proposal_item_detail->department
          iv_tipo_doc     = brf_helper->co_with_doctype-interdivisional ).
      IF target_costcenter IS NOT INITIAL.
        proposal_item_detail->costcenter1(4) = target_costcenter.
        IF proposal_item_detail->profitcentereq IS NOT INITIAL.
          proposal_item_detail->costcenter1+7(3) = proposal_item_detail->profitcentereq.
        ENDIF.
      ELSE.
        CLEAR proposal_item_detail->costcenter1.
      ENDIF.

*      " Cost Center Determination 2
      proposal_item_detail->costcenter2 = proposal_item_detail->costcenter.
      target_costcenter   = brf_helper->get_cc_code(
          iv_product      = proposal_item_detail->product
          iv_cuenta       = gl_account-glaccount2
          iv_cc_origen    = proposal_item_detail->costcenterd4 " fourth digit of the origin cost center
          iv_departamento = proposal_item_detail->department
          iv_tipo_doc     = brf_helper->co_with_doctype-interdivisional ).
      IF target_costcenter IS NOT INITIAL.
        proposal_item_detail->costcenter2(4) = target_costcenter.
        IF proposal_item_detail->profitcentereq IS NOT INITIAL.
          proposal_item_detail->costcenter2+7(3) = proposal_item_detail->profitcentereq.
        ENDIF.
      ELSE.
        CLEAR proposal_item_detail->costcenter2.
      ENDIF.

    ENDLOOP.

    " Prepare the data to be posted as GL items in the financial documents.
    SELECT
       id,
       providercompanycode,
       product,
       recipientcompanycode,
       recipientcountry,
       recipientcustomer,
       department,
*       MAX( idl3 ) AS idl3,
       tarifftype,
       tariffdescription,
       tariffrate,
       profitcenter,
       costcenterd4,
       glaccount1,
       glaccount2,
       costcenter1,
       costcenter2,
      SUM( amountintransactioncurrency ) AS amountintransactioncurrency,
       transactioncurrency,
       globalcurrency,
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
*       idl3,
      tarifftype,
      tariffdescription,
      tariffrate,
      profitcenter,
*      costcenter,
      costcenterd4,
      glaccount1,
      glaccount2,
      costcenter1,
      costcenter2,
      transactioncurrency,
      globalcurrency,
      exchangerate
    INTO TABLE @DATA(recipient_glitems).

    IF recipient_glitems IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE SUM( recipient_glitems~amountintransactioncurrency ) AS total
      FROM @recipient_glitems AS recipient_glitems
      INTO @DATA(total).

    "  Build Journal Entries
    LOOP AT recipient_glitems REFERENCE INTO DATA(recipient_glitem)
        GROUP BY recipient_glitem->recipientcompanycode INTO FINAL(recipient_company_code).

      APPEND INITIAL LINE TO journal_entries REFERENCE INTO DATA(journal_entry).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " HEADER
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      journal_entry->%cid = gs_header-providercompanycode && gs_header-product && sy-datum && sy-index.
      journal_entry->%param-accountingdocumenttype = 'CH'.
      journal_entry->%param-createdbyuser = sy-uname.
      journal_entry->%param-accountingdocumentheadertext = |{ gs_header-providercompanycode } { recipient_company_code } { gs_header-productname }|.
      journal_entry->%param-companycode = gs_header-providercompanycode.
      journal_entry->%param-documentreferenceid = gs_header-product.
      journal_entry->%param-documentdate = last_day_of_month.
      journal_entry->%param-postingdate = last_day_of_month.

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      " GL_ITEMS
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA(lineitem) = CONV ty_lineitem( 1 ).
      LOOP AT GROUP recipient_company_code REFERENCE INTO FINAL(recipient_item).

        DATA(debig_glaccount) = COND #( WHEN total >= 0 THEN recipient_item->glaccount1 ELSE recipient_item->glaccount2 ).
        DATA(credit_glaccount) = COND #( WHEN total >= 0 THEN recipient_item->glaccount2 ELSE recipient_item->glaccount1 ).

        proposal_item_detail = REF #( proposal_items_details[ recipientcompanycode = recipient_item->recipientcompanycode profitcenter = recipient_item->profitcenter ] ).

        " generate a dummy document key for logging purporses in case anything fails
        DATA(dummy_documentkey) = |DUMMY{ gs_header-providercompanycode }{ gs_header-product }{ proposal_item_detail->recipientcompanycode }|.

        " This is required to map the exact ProposalItem so we can log it correctly
        IF NOT line_exists( gt_doc_map[
            id           = proposal_item_detail->id
            item_id      = proposal_item_detail->item_id
            documenttype = zcl_proposal_bo_abs=>c_document_type-interdiv
            documentkey  = dummy_documentkey ] ).

          APPEND VALUE #(
            id           = proposal_item_detail->id
            item_id      = proposal_item_detail->item_id
            itembasis_id = proposal_item_detail->itembasis_id
            itemcalc_id  = proposal_item_detail->itemcalc_id
            documenttype = zcl_proposal_bo_abs=>c_document_type-interdiv
            documentkey  = dummy_documentkey
          ) TO gt_doc_map REFERENCE INTO DATA(document_map).
        ENDIF.

        IF recipient_item->costcenter1 IS INITIAL.
          add_msg_to_log(
            iv_current_item = CORRESPONDING #( proposal_item_detail->* )
            iv_doctype = mv_posting_doctype
            iv_dockey = dummy_documentkey
            iv_message_text = |{ TEXT-001 }{ proposal_item_detail->department }| ).
          document_map->status = 'E'.
        ENDIF.


        IF recipient_item->glaccount1 IS INITIAL.
          add_msg_to_log(
          iv_doctype = mv_posting_doctype
              iv_current_item = CORRESPONDING #( proposal_item_detail->* )
              iv_dockey = dummy_documentkey
*            iv_message_text = |{ TEXT-002 } { recipient_item->tariffdescription } / { recipient_item->idl3 } / { recipient_item->department }| ).
            iv_message_text = |{ TEXT-002 } { recipient_item->tariffdescription } / { recipient_item->department }| ).
          document_map->status = 'E'.
        ENDIF.

        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " GLACCOUNT 1
        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        debig_glaccount = |{ debig_glaccount ALPHA = IN }|.

        lineitem += 1.
        APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO DATA(gl_item).
        gl_item->glaccount = recipient_item->glaccount1.
        gl_item->glaccountlineitem = lineitem.
        gl_item->partnercompany = gs_header-providercompanycode.
        gl_item->assignmentreference = gs_header-productname.
        gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
        gl_item->costcenter = recipient_item->costcenter1.
        gl_item->material = recipient_item->product.
        IF recipient_item->tarifftype <> zcl_interco_doc_glaccount=>co_tariff_type-basis.
          gl_item->quantity = recipient_item->tariffrate.
          gl_item->baseunit = base_unit.
        ENDIF.

        READ TABLE proposal_items INTO DATA(ls_proposal_items) WITH KEY id      = recipient_item->id
                                                                        item_id = proposal_item_detail->item_id
                                                                        product = gs_header-product.

        APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO DATA(gl_item_amount).
        gl_item_amount->currency = recipient_item->transactioncurrency.
        gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency.
        IF exchange_rates[] IS NOT INITIAL.
          DATA(exchange_rate) = exchange_rates[ sourcecurrency = ls_proposal_items-transactioncurrency  targetcurrency = recipient_item->globalcurrency ]-exchangerate.
        ENDIF.
        gl_item_amount->exchangerate = exchange_rate.
*        gl_item_amount->exchangerate = recipient_item->exchangerate.
        " We store the sum of those amounts so we can use it in the AR structure.
        total += gl_item_amount->journalentryitemamount.

        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " GLACCOUNT 2
        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        credit_glaccount = |{ credit_glaccount ALPHA = IN }|.

        lineitem += 1.
        APPEND INITIAL LINE TO journal_entry->%param-_glitems REFERENCE INTO gl_item.
        gl_item->glaccount = recipient_item->glaccount2.
        gl_item->glaccountlineitem = lineitem.
        gl_item->partnercompany = gs_header-providercompanycode.
        gl_item->assignmentreference = gs_header-productname.
        gl_item->documentitemtext = |{ gs_header-providercompanycode }-{ recipient_company_code }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
        gl_item->costcenter = recipient_item->costcenter2.
        gl_item->material = recipient_item->product.
        IF recipient_item->tarifftype <> zcl_interco_doc_glaccount=>co_tariff_type-basis.
          gl_item->quantity = recipient_item->tariffrate.
          gl_item->baseunit = base_unit.
        ENDIF.

        APPEND INITIAL LINE TO gl_item->_currencyamount REFERENCE INTO gl_item_amount.
        gl_item_amount->currency = recipient_item->transactioncurrency.
        gl_item_amount->journalentryitemamount = recipient_item->amountintransactioncurrency * -1.
        IF exchange_rates[] IS NOT INITIAL.
          exchange_rate = exchange_rates[ sourcecurrency = ls_proposal_items-transactioncurrency  targetcurrency = recipient_item->globalcurrency ]-exchangerate.
        ENDIF.
        gl_item_amount->exchangerate = exchange_rate.
*        gl_item_amount->exchangerate = recipient_item->exchangerate.
        " We store the sum of those amounts so we can use it in the AR structure.
        total += gl_item_amount->journalentryitemamount.

      ENDLOOP.

      gta_je_post = journal_entries.

      DATA(je_parallel_processing) = NEW zcl_proposal_bo_int_paralel( iv_process    = gv_process
                                                                         its_doc    = gts_doc
                                                                         it_doc_map = gt_doc_map
                                                                         it_je_post = gta_je_post ).
      APPEND je_parallel_processing TO gtd_list_bo.
      CLEAR: gts_doc, gt_doc_map, gta_je_post, journal_entries.
      CLEAR lineitem.
    ENDLOOP.

    " Borocratic stuff for ZCL_PROPOSAL_TOOLS
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
                            postingdate    = lv_posting_date
                            reversalreason = '01'
                            createdbyuser  = cl_abap_context_info=>get_user_technical_name( )
                           ).
      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.
      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-documentkey }|.
      <fs_doc_map>-documenttype = zcl_proposal_bo_abs=>c_document_type-anul_interdiv.
      <fs_doc_map>-parentdocumentkey = <fs_doc>-documentkey.
      <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-interdiv.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_int_paralel( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
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


  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_interdiv_parallel   TYPE REF TO zcl_proposal_bo_int_paralel.
    DATA lv_status_log TYPE c.
    DATA lt_journalentry TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry.
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

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>)." WHERE inst IS NOT INITIAL.
      IF <l_out>-inst IS NOT INITIAL.
        lo_interdiv_parallel ?= <l_out>-inst.
      ELSE.
        lo_interdiv_parallel ?= gtd_list_bo[ <l_out>-index ].
        lt_journalentry = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                         number   = '022'
                                                         severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-interdiv
            it_reported   = lt_journalentry
          CHANGING
            ct_map_id_doc = lo_interdiv_parallel->gt_doc_map_interdiv
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-interdiv
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-interdivision
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = lv_byuser
                               iv_attime       = lv_attime
                     CHANGING  ct_map_id_doc   = lo_interdiv_parallel->gt_doc_map_interdiv ).
      ENDIF.
      APPEND LINES OF lo_interdiv_parallel->gt_doc_map_interdiv TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
