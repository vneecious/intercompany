CLASS zcl_proposal_bo_recl_gross DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

***    TYPES:
***      gtty_journalentry_post    TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
***    TYPES:
***      gtty_journalentry_reverse TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .
***
***    DATA gta_journalentry_post TYPE gtty_journalentry_post .
***    DATA gta_journalentry_reverse TYPE gtty_journalentry_reverse .
***    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .
***    DATA gs_header_si TYPE zi_intercoproposal .
***    DATA gtd_doc_wt TYPE gtty_doc .
***    DATA gt_doc_map_wt TYPE gtty_doc .
***    DATA gv_proposal_type TYPE zfi_a_intrc_cpd-documenttype .
***    DATA gt_doc_map_db TYPE gtty_doc .
***
    METHODS constructor
      IMPORTING
        !iv_doctype           TYPE zfi_a_intrc_cpid-documenttype OPTIONAL
        !is_header            TYPE zi_intercoproposal OPTIONAL
        !it_items             TYPE ztt_proposalitem_add OPTIONAL
        !it_bases             TYPE gtty_bases OPTIONAL
        !it_calc              TYPE gtty_calc OPTIONAL
        !it_doc               TYPE gtty_doc OPTIONAL
        !it_anul_doc          TYPE gtty_doc OPTIONAL
        !its_bases            TYPE gtsty_bases OPTIONAL
        !its_calc             TYPE gtsty_calc OPTIONAL
        !its_doc              TYPE gtsty_doc OPTIONAL
        !it_glaccount         TYPE ztt_proposal_reclassif OPTIONAL
        !its_glaccount        TYPE gtsty_glaccount OPTIONAL
        !iv_process           TYPE c OPTIONAL
        !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !it_doc_map           TYPE gtty_doc OPTIONAL
        !it_baogl             TYPE gtty_baogl OPTIONAL
        !its_baogl            TYPE gtsty_baogl OPTIONAL
        !iv_proposal_type     TYPE zfi_a_intrc_cpd-documenttype OPTIONAL.
  PROTECTED SECTION.
    METHODS preparedata REDEFINITION.
    METHODS exe_bo REDEFINITION .
    METHODS mapping_bo_sec REDEFINITION .
    METHODS mapping_reverse_sec REDEFINITION.
    METHODS preparedata_reverse REDEFINITION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF gty_total_item,
        id           TYPE zi_intercoproposalitem-id,
        itemid       TYPE zi_intercoproposalitem-item_id,
        costcenterd4 TYPE zi_intercoproposalitemorglacct-costcenterd4,
        total        TYPE zi_intercoproposalitemorglacct-amountinglobalcurrency.
    TYPES: END OF gty_total_item .
    TYPES:
      BEGIN OF gty_item_sum,
        id             TYPE zi_intercoproposalitemorglacct-id,
        item_id        TYPE zi_intercoproposalitemorglacct-itemid,
        department     TYPE zi_intercoproposalitemorglacct-department,
        costcenterd4   TYPE zi_intercoproposalitemorglacct-costcenterd4,
        costcenter     TYPE zi_intercoproposalitemorglacct-costcenter,
        profitcenter   TYPE zi_intercoproposalitem-profitcenter,
        profitcentereq TYPE zi_intercoproposalitem-profitcentereq,
        percentoftotal TYPE p LENGTH 16 DECIMALS 8.
    TYPES: END OF gty_item_sum .
    TYPES:
      gtty_item_glacct TYPE STANDARD TABLE OF zi_intercoproposalitemorglacct .
    TYPES:
      gtty_total_item TYPE STANDARD TABLE OF gty_total_item .
    TYPES:
      gtty_item_sum TYPE STANDARD TABLE OF gty_item_sum .
    TYPES:
      gtty_glaccount TYPE RANGE OF i_journalentryitem-glaccount .
    TYPES:
      BEGIN OF gty_total_je,
        accountingdocument          TYPE i_journalentryitem-accountingdocument,
        companycode                 TYPE i_journalentryitem-companycode,
        fiscalyear                  TYPE i_journalentryitem-fiscalyear,
        glaccount                   TYPE i_journalentryitem-glaccount,
        profitcenter                TYPE i_journalentryitem-profitcenter,
        amountintransactioncurrency TYPE i_journalentryitem-amountintransactioncurrency,
        transactioncurrency         TYPE i_journalentryitem-transactioncurrency,
        amountinglobalcurrency      TYPE i_journalentryitem-amountinglobalcurrency,
        globalcurrency              TYPE i_journalentryitem-globalcurrency.
    TYPES END OF gty_total_je .

    TYPES:
      BEGIN OF gty_je_his,
        accountingdocument          TYPE i_journalentryitem-accountingdocument,
        companycode                 TYPE i_journalentryitem-companycode,
        fiscalyear                  TYPE i_journalentryitem-fiscalyear,
        glaccount                   TYPE i_journalentryitem-glaccount,
        profitcenter                TYPE i_journalentryitem-profitcenter,
        costcenter                  TYPE i_journalentryitem-costcenter,
        costcenterd4                TYPE zi_intercoproposalitemorglacct-costcenterd4,
        amountintransactioncurrency TYPE i_journalentryitem-amountintransactioncurrency,
        transactioncurrency         TYPE i_journalentryitem-transactioncurrency,
        amountinglobalcurrency      TYPE i_journalentryitem-amountinglobalcurrency,
        globalcurrency              TYPE i_journalentryitem-globalcurrency,
        partnercompany              TYPE i_journalentryitem-partnercompany,
        partnercountry              TYPE i_companycode-country,
        companycountry              TYPE i_companycode-country.
    TYPES END OF gty_je_his .

    TYPES:
      gtty_je_his TYPE STANDARD TABLE OF gty_je_his.


    TYPES:
      gtty_total_je TYPE STANDARD TABLE OF gty_total_je .
    TYPES:
      BEGIN OF gty_tvarvc_data,
        tarifftype_item_1   TYPE zint_a_md_glacct-tariff_type,
        tarifftype_item_2n  TYPE zint_a_md_glacct-tariff_type,
        glaccount_redondeo  TYPE i_withholdingtaxitem-glaccount,
        costcenter_redondeo TYPE zi_intercoproposalitemorglacct-costcenter,
        blart               TYPE i_journalentry-accountingdocumenttype,
        doctype             TYPE  zint_a_md_glacct-doc_type,
        glaccount_je        TYPE gtty_glaccount.
    TYPES: END OF gty_tvarvc_data .
    TYPES:
      BEGIN OF gty_percent_je,
        accountingdocument TYPE i_journalentryitem-accountingdocument,
        companycode        TYPE i_journalentryitem-companycode,
        fiscalyear         TYPE i_journalentryitem-fiscalyear,
        glaccount          TYPE i_journalentryitem-glaccount,
        profitcenter       TYPE i_journalentryitem-profitcenter,
        percent            TYPE p LENGTH 16 DECIMALS 8.
    TYPES END OF gty_percent_je .
    TYPES:
      BEGIN OF gty_percent_his,
        accountingdocument TYPE i_journalentryitem-accountingdocument,
        companycode        TYPE i_journalentryitem-companycode,
        fiscalyear         TYPE i_journalentryitem-fiscalyear,
        glaccount          TYPE i_journalentryitem-glaccount,
        profitcenter       TYPE i_journalentryitem-profitcenter,
        costcenterd4       TYPE zi_intercoproposalitemorglacct-costcenterd4,
        percent            TYPE p LENGTH 16 DECIMALS 8.
    TYPES END OF gty_percent_his .
    TYPES:
      gtty_percent_je TYPE STANDARD TABLE OF gty_percent_je .
    TYPES:
      gtty_percent_his TYPE STANDARD TABLE OF gty_percent_his .

    CONSTANTS gc_tarifftype_item_1 TYPE zi_tvarvc-name VALUE 'ZWT_TARIFFTYPE_ITEM_1' ##NO_TEXT.
    CONSTANTS gc_tarifftype_item_2n TYPE zi_tvarvc-name VALUE 'ZWT_TARIFFTYPE_ITEM_2N' ##NO_TEXT.
    CONSTANTS gc_glaccount_redondeo TYPE zi_tvarvc-name VALUE 'ZWT_GLACCOUNT_REDONDEO' ##NO_TEXT.
    CONSTANTS gc_costcenter_redondeo TYPE zi_tvarvc-name VALUE 'ZWT_COSTCENTER_REDONDEO' ##NO_TEXT.
    CONSTANTS gc_blart TYPE zi_tvarvc-name VALUE 'ZWT_BLART' ##NO_TEXT.
    CONSTANTS gc_doctype TYPE zi_tvarvc-name VALUE 'ZWT_DOCTYPE' ##NO_TEXT.
    CONSTANTS gc_glaccount_je TYPE zi_tvarvc-name VALUE 'ZWT_GLACCONT_JE' ##NO_TEXT.

    METHODS get_tvarvc
      EXPORTING
        !iv_tvarvc_data TYPE gty_tvarvc_data .
    METHODS map_error
      IMPORTING
        !iv_id       TYPE symsgid
        !iv_number   TYPE symsgno
        !iv_severity TYPE if_abap_behv_message=>t_severity
        !iv_doc_key  TYPE zfi_a_intrc_cpd-documentkey
        !iv_doc_map  TYPE zi_intercoproposalitemdoc .
    METHODS get_percent_of_total
      CHANGING
        !ch_item_sum TYPE gtty_item_sum .
    METHODS get_percent_je
      IMPORTING
        !iv_doc_map_si   TYPE gtty_doc
        !iv_glaccount_je TYPE gtty_glaccount
      CHANGING
        !ch_percent_je   TYPE gtty_percent_je .
    METHODS get_percent_his
      IMPORTING
        !iv_doc_map_si  TYPE gtty_doc
      CHANGING
        !ch_percent_his TYPE gtty_percent_his .
ENDCLASS.

CLASS zcl_proposal_bo_recl_gross IMPLEMENTATION.


  METHOD exe_bo.
***    DATA lv_debug TYPE abap_boolean.
***    DATA lo_parallel TYPE REF TO zcl_proposal_bo_wt_post_par.
***
***    CHECK gtd_list_bo IS NOT INITIAL.
***
***    DATA(l_ref) = NEW cl_abap_parallel( ).
***    l_ref->run_inst(
***      EXPORTING
***        p_in_tab  = gtd_list_bo
***        p_debug   = lv_debug
***      IMPORTING
***        p_out_tab = DATA(l_out_tab) ).
***
***    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>).
***
***      IF <l_out>-inst IS NOT INITIAL.
***        lo_parallel ?= <l_out>-inst.
***        APPEND LINES OF lo_parallel->gt_doc_map_si TO me->gt_doc_map_wt.
***      ENDIF.
***
***    ENDLOOP.

  ENDMETHOD.


  METHOD mapping_reverse_sec.
***    DATA: ld_today  TYPE d.
***
***    IF gt_doc_map_wt IS INITIAL.
***      RETURN.
***    ENDIF.
***
***    SORT gt_doc_map_wt BY documentkey companycode fiscalyear.
***    DELETE ADJACENT DUPLICATES FROM gt_doc_map_wt COMPARING documentkey companycode fiscalyear.
***
***    SELECT i_journalentry~accountingdocument ,
***           i_journalentry~companycode,
***           i_journalentry~fiscalyear,
***           postingdate
***    FROM i_journalentry
***    INNER JOIN @gt_doc_map_wt AS documents
***    ON  documents~documentkey  = i_journalentry~accountingdocument
***    AND documents~companycode  = i_journalentry~companycode
***    AND documents~fiscalyear   = i_journalentry~fiscalyear
***   INTO TABLE @DATA(lt_posting_date).
***    IF sy-subrc = 0.
***      SORT lt_posting_date BY accountingdocument companycode fiscalyear.
***    ENDIF.
***
***    LOOP AT gt_doc_map_wt ASSIGNING FIELD-SYMBOL(<fs_doc>).
***
***      TRY.
***          DATA(ls_posting_date) = lt_posting_date[ accountingdocument = <fs_doc>-documentkey
***                                                   fiscalyear         = <fs_doc>-fiscalyear
***                                                   companycode        = <fs_doc>-companycode  ].
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      APPEND INITIAL LINE TO gta_journalentry_reverse ASSIGNING FIELD-SYMBOL(<jr>).
***      <jr>-companycode = <fs_doc>-companycode.
***      <jr>-fiscalyear  = <fs_doc>-fiscalyear.
***      <jr>-accountingdocument = <fs_doc>-documentkey(10).
***      <jr>-%param = VALUE #(  postingdate    = ls_posting_date-postingdate
***                              reversalreason = '01'
***                              createdbyuser  = cl_abap_context_info=>get_user_technical_name( )   ).
***
***      APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
***      <fs_doc_map> = <fs_doc>.
***
***      <fs_doc_map>-documentkey = |DUMMY{ <fs_doc>-companycode }{ <fs_doc>-documentkey(10) }{ <fs_doc>-fiscalyear }|.
***      <fs_doc_map>-parentdocumentkey  = <fs_doc>-documentkey.
***      <fs_doc_map>-parentdocumenttype = <fs_doc>-documenttype.
***      <fs_doc_map>-documenttype       = gv_proposal_type.
***
***      DATA(lo_exe_bo) = NEW zcl_proposal_bo_wt_post_par( iv_process     = zcl_boproposal_tools=>gc_reverse_doc
***                                                         iv_doc_type    = gv_proposal_type
***                                                         iv_documentkey = <fs_doc>-documentkey
***                                                         it_doc_map     = gt_doc_map_db
***                                                         it_je_reverse  = gta_journalentry_reverse ).
***      APPEND lo_exe_bo TO gtd_list_bo.
***
***      CLEAR: gt_doc_map_db, gta_journalentry_reverse.
***    ENDLOOP.
***
***    IF gtd_list_bo IS NOT INITIAL.
***      exe_bo( ).
****      et_doc_map = me->gt_doc_map_db.  "ext_oscugald
***      save_log( ).
***      IF gt_doc_map_db[] IS INITIAL OR
***          line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
***          OR line_exists( gt_doc_map_db[ status = abap_false ] ).
***        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
***      ENDIF.
***    ENDIF.

  ENDMETHOD.


  METHOD mapping_bo_sec.

***    TYPES: lsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
***           lsty_glitems TYPE LINE OF lsty_post-%param-_glitems.
***
***    DATA:
***      lt_doc_map_log         TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
***      lv_totalpos_amt_doc    TYPE i_journalentryitem-amountinglobalcurrency,
***      lv_totalpos_amt_cocode TYPE i_journalentryitem-amountincompanycodecurrency,
***      lv_amt_doc             TYPE i_journalentryitem-amountinglobalcurrency,
***      lv_amt_max             TYPE i_journalentryitem-amountinglobalcurrency,
***      lv_amt_cocode          TYPE i_journalentryitem-amountincompanycodecurrency,
****      lv_ali_grossup         TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
***      lv_ali_grossup         TYPE p LENGTH 7 DECIMALS 6,
****      lv_perc_wth            TYPE i_extendedwhldgtaxcode-withholdingtaxpercent,
***      lv_perc_wth            TYPE p LENGTH 7 DECIMALS 6,
***      lv_part_to_wth         TYPE i_extendedwhldgtaxcode-whldgtaxrelevantpercent,
***      lv_costcenter          TYPE zi_intercoproposalitemorglacct-costcenter,
***      lv_doc_key             TYPE zfi_a_intrc_cpd-documentkey,
***      lv_company_item        TYPE i_journalentry-companycode,
***      lt_glitems             TYPE lsty_post-%param-_glitems,
***      lv_status_log          TYPE zfi_a_intrc_cpdl-msgty,
***      lv_perc_no_comp        TYPE zi_intercocompanyrelprodrate-taxcredit,
***      lt_item_sum            TYPE gtty_item_sum,
***      lv_cc_code             TYPE zde_cc_code,
***      lv_error               TYPE abap_bool,
***      lv_cid                 TYPE abp_behv_cid,
***      lv_firstday            TYPE datum,
***      lv_position_num        TYPE int4,
***      lv_item_text           TYPE sgtxt,
***      ls_tvarvc_data         TYPE gty_tvarvc_data,
***      lt_percent_je          TYPE gtty_percent_je,
***      lt_percent_his         TYPE gtty_percent_his,
***      lv_tabix               TYPE sy-tabix,
***      lv_index_mayor         TYPE sy-tabix.
***
***    IF gv_process <> zcl_boproposal_tools=>gc_create_doc.
***      RETURN.
***    ENDIF.
***
***    lv_firstday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01|.
***
***    TRY.
***        DATA(lv_lastday) = zcl_interco_utils=>rp_last_day_of_months(
***          EXPORTING
***            day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
***      CATCH cx_sy_conversion_no_date INTO DATA(exc).
***        lv_lastday = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod }31|.
***    ENDTRY.
***
***    SELECT
***    providercompanycode,
***    recipientcompanycode,
***    product,
***    taxcredit
***    FROM zi_intercocompanyrelprodrate
***    FOR ALL ENTRIES IN @gtd_items_add
***    WHERE providercompanycode  = @gtd_items_add-providercompanycode
***      AND recipientcompanycode = @gtd_items_add-recipientcompanycode
***      AND product              = @gtd_items_add-product
***      AND validfrom <= @lv_firstday
***      AND validto   >= @lv_lastday
***      AND isdeleted = @space
***    INTO TABLE @DATA(lt_relprodrate).
***    IF sy-subrc <> 0.
***      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
***    ENDIF.
***
***    me->get_tvarvc( IMPORTING iv_tvarvc_data = ls_tvarvc_data ).
***
***    IF gt_doc_map_wt IS NOT INITIAL.
***
***      SELECT je~companycode,
***             je~fiscalyear,
***             je~accountingdocument,
***             je~originalreferencedocument,
***             je~postingdate,
***             je~documentdate,
****             je~exchangerate,
***             je~absoluteexchangerate,
***             wt~withholdingtaxcode,
***             wt~whldgtaxbaseamtincocodecrcy,
***             wt~whldgtaxbaseamtintransaccrcy,
***             wt~companycodecurrency,
***             wt~documentcurrency,
***             ext~whldgtaxrelevantpercent,
***             ext~withholdingtaxpercent,
***             ext~withholdingtaxpostingrule
***        FROM i_journalentry              WITH PRIVILEGED ACCESS AS je
***        INNER JOIN i_withholdingtaxitem  WITH PRIVILEGED ACCESS AS wt
***        ON je~companycode         = wt~companycode
***        AND je~accountingdocument = wt~accountingdocument
***        AND je~fiscalyear         = wt~fiscalyear
***        INNER JOIN i_extendedwhldgtaxcode WITH PRIVILEGED ACCESS AS ext
***        ON  ext~country             = wt~country
***        AND ext~withholdingtaxtype  = wt~withholdingtaxtype
***        AND ext~withholdingtaxcode  = wt~withholdingtaxcode
***        FOR ALL ENTRIES IN @gt_doc_map_wt
***        WHERE je~companycode        = @gt_doc_map_wt-companycode
***        AND   je~fiscalyear         = @gt_doc_map_wt-fiscalyear
***        AND   je~accountingdocument = @gt_doc_map_wt-documentkey(10)
***        INTO TABLE @DATA(lt_with_item).
***      IF sy-subrc = 0.
***
***        IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***          DELETE lt_with_item WHERE withholdingtaxpostingrule = '1'.
***        ENDIF.
***
***        IF lt_with_item IS NOT INITIAL.
***
***          SORT lt_with_item BY companycode fiscalyear accountingdocument.
***
***          me->get_percent_of_total( CHANGING ch_item_sum = lt_item_sum ).
***
***          me->get_percent_je( EXPORTING iv_doc_map_si   = gt_doc_map_wt
***                                        iv_glaccount_je = ls_tvarvc_data-glaccount_je
***                              CHANGING  ch_percent_je   = lt_percent_je ).
***
***          me->get_percent_his( EXPORTING iv_doc_map_si  = gt_doc_map_wt
***                               CHANGING  ch_percent_his = lt_percent_his ).
***
***          DATA(doc_account) = NEW zcl_interco_doc_glaccount(
***            i_doctype               = ls_tvarvc_data-doctype
***            i_product               = gs_header-product
***            i_provider_company_code = gs_header-providercompanycode
***            i_valid_at              = lv_lastday ).
***
***        ENDIF.
***
***      ENDIF.
***
***      SELECT companycode,
***             internalcode
***      FROM zi_intercocompanycode
***      FOR ALL ENTRIES IN  @gt_doc_map_wt
***      WHERE companycode = @gt_doc_map_wt-companycode
***      INTO TABLE @DATA(lt_sitecode).
***      IF sy-subrc = 0.
***        SORT lt_sitecode BY companycode.
***      ENDIF.
***
***    ENDIF.
***
***    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
***
***    SORT gt_doc_map_wt BY documentkey.
***    SORT gtd_items_add BY id item_id itembasis_id itemcalc_id.
***
***    LOOP AT gt_doc_map_wt INTO DATA(ls_doc_map) GROUP BY ls_doc_map-documentkey.
***
***      TRY.
***          DATA(ls_item_1) = gtd_items_add[ id           = ls_doc_map-id
***                                           item_id      = ls_doc_map-item_id
***                                           itembasis_id = ls_doc_map-itembasis_id
***                                           itemcalc_id  = ls_doc_map-itemcalc_id ] .
***
***          DATA(ls_relprodrate) = VALUE #( lt_relprodrate[ providercompanycode  = ls_item_1-providercompanycode
***                                                          recipientcompanycode = ls_item_1-recipientcompanycode
***                                                          product              = ls_item_1-product ] OPTIONAL ).
***
***          IF ls_relprodrate-taxcredit = 100.
***
***            lt_doc_map_log = VALUE #( ( %msg = new_message( id         = 'ZINT_MSG_INTERCO_CP'
***                                                            number     = '026'
***                                                            severity   = if_abap_behv_message=>severity-information
***                                                            v1         = ls_doc_map-documentkey ) ) ).
***
***            lv_doc_key = ls_doc_map-documentkey(10).
***
***            mapping_doc_log( EXPORTING iv_dockey      = lv_doc_key
***                                       iv_companycode = ls_doc_map-companycode
***                                       iv_fiscalyear  = ls_doc_map-fiscalyear
***                                       iv_doctype     = ls_doc_map-documenttype
***                                       it_reported    = lt_doc_map_log
***                             CHANGING  ct_map_id_doc  = gt_doc_map_wt
***                                       cv_status      = lv_status_log ).
***
***            CLEAR: lt_doc_map_log, lv_doc_key, ls_relprodrate.
***            CONTINUE.
***
***          ENDIF.
***
***          lv_perc_no_comp = 100 - ls_relprodrate-taxcredit.
***          lv_perc_no_comp = lv_perc_no_comp / 100.
***
***          LOOP AT lt_with_item ASSIGNING FIELD-SYMBOL(<lfs_with_item>) WHERE  companycode        = ls_doc_map-companycode
***                                                                       AND    fiscalyear         = ls_doc_map-fiscalyear
***                                                                       AND    accountingdocument = ls_doc_map-documentkey(10).
***
***            DATA lv_wth_amt_cocode LIKE <lfs_with_item>-whldgtaxbaseamtincocodecrcy.
***            DATA lv_wth_amt_doc    LIKE <lfs_with_item>-whldgtaxbaseamtintransaccrcy.
***
***            <lfs_with_item>-withholdingtaxpercent   = <lfs_with_item>-withholdingtaxpercent   / 100.
***            <lfs_with_item>-whldgtaxrelevantpercent = <lfs_with_item>-whldgtaxrelevantpercent / 100.
***
***            lv_ali_grossup   = <lfs_with_item>-withholdingtaxpercent / ( 1 - <lfs_with_item>-withholdingtaxpercent ).
***            lv_part_to_wth   = <lfs_with_item>-whldgtaxrelevantpercent.
***
***            IF <lfs_with_item>-withholdingtaxpostingrule = '2'.
***              lv_perc_wth = lv_ali_grossup.
***            ELSE.
***              lv_perc_wth = <lfs_with_item>-withholdingtaxpercent.
***            ENDIF.
***
***            lv_wth_amt_cocode  += <lfs_with_item>-whldgtaxbaseamtincocodecrcy  * lv_part_to_wth * lv_perc_wth * lv_perc_no_comp.
***            lv_wth_amt_doc     += <lfs_with_item>-whldgtaxbaseamtintransaccrcy * lv_part_to_wth * lv_perc_wth * lv_perc_no_comp.
***
***            DATA(lv_company)      = <lfs_with_item>-companycode.
****            DATA(lv_exchangerate) = <lfs_with_item>-exchangerate.
***            DATA(lv_exchangerate) = <lfs_with_item>-AbsoluteExchangeRate.
***            DATA(lv_flag) = abap_true.
***
***          ENDLOOP.
***
***          IF lv_flag = abap_false.
***
***            lt_doc_map_log = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
***                                                            number   = '025'
***                                                            severity = if_abap_behv_message=>severity-information
***                                                            v1       = ls_doc_map-documentkey ) ) ).
***
***            lv_doc_key = ls_doc_map-documentkey(10).
***
***            mapping_doc_log( EXPORTING iv_dockey      = lv_doc_key
***                                       iv_companycode = ls_doc_map-companycode
***                                       iv_fiscalyear  = ls_doc_map-fiscalyear
***                                       iv_doctype     = ls_doc_map-documenttype
***                                       it_reported    = lt_doc_map_log
***                             CHANGING  ct_map_id_doc  = gt_doc_map_wt
***                                       cv_status      = lv_status_log ).
***
***            CLEAR: lt_doc_map_log, lv_doc_key, ls_relprodrate, lv_perc_no_comp, lv_flag.
***            CONTINUE.
***
***          ENDIF.
***
***          DATA(ls_sitecode) = VALUE #( lt_sitecode[ companycode  = lv_company ] OPTIONAL ).
***          IF ls_sitecode-internalcode IS INITIAL.
***
***            lv_doc_key  = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
***            me->map_error(
***              iv_id       = 'ZINT_MSG_INTERCO_CP'
***              iv_number   = '27'
***              iv_severity = if_abap_behv_message=>severity-error
***              iv_doc_key  = lv_doc_key
***              iv_doc_map  = ls_doc_map ).
***
***            lv_error = abap_true.
***            CONTINUE.
***
***          ENDIF.
***
***          DATA(ls_item_dept) = VALUE #( lt_item_sum[ id       = ls_doc_map-id
***                                                     item_id  = ls_doc_map-item_id ] OPTIONAL ).
***
***          doc_account->get( EXPORTING i_tarifftype = ls_tvarvc_data-tarifftype_item_1
***                                      i_department = ls_item_dept-department
***                            RECEIVING result       = DATA(ls_glaccount_1) ).
***
***          CASE gv_proposal_type.
***            WHEN zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***              lv_company_item = ls_item_1-providercompanycode.
***            WHEN zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
***              lv_company_item = ls_item_1-recipientcompanycode.
***          ENDCASE.
***
***          lv_item_text = |{ gs_header-providercompanycode }-{ ls_item_1-recipientcompanycode }-{ gs_header-productname }-{ gs_header-fiscalperiod }/{ gs_header-fiscalyear }|.
***
***          "item 1
***          lv_position_num += 1.
***          DATA(ls_glitems) = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
***                                                 partnercompany      = lv_company_item
***                                                 glaccount           = |{ ls_glaccount_1-glaccount1 ALPHA = IN }|
***                                                 documentitemtext    = lv_item_text
***                                                 assignmentreference = gs_header-productname
***                                                 material            = gs_header-product
***                                                 _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                   THEN lv_wth_amt_cocode * -1
***                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                   THEN lv_wth_amt_cocode )
***                                                                                  currency               = <lfs_with_item>-companycodecurrency
***                                                                                  exchangerate           = lv_exchangerate
***                                                                                  currencyrole           = '10'   )
***                                                                                ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                   THEN lv_wth_amt_doc * -1
***                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                   THEN lv_wth_amt_doc )
***                                                                                  currency               = <lfs_with_item>-documentcurrency
***                                                                                  exchangerate           = lv_exchangerate
***                                                                                  currencyrole           = '00'   ) )  ).
***
***          APPEND ls_glitems TO lt_glitems.
***          CLEAR ls_glitems.
***
***          lv_totalpos_amt_doc    = lv_wth_amt_doc    * -1.
***          lv_totalpos_amt_cocode = lv_wth_amt_cocode * -1.
***
***          CLEAR: lv_tabix, lv_amt_max, lv_index_mayor.
***          lv_tabix = 1.
***
***          LOOP AT GROUP ls_doc_map INTO DATA(ls_group).
***
****  Items 2 to N
***            LOOP AT lt_item_sum INTO DATA(ls_item_sum)  WHERE id      = ls_group-id
***                                                        AND   item_id = ls_group-item_id.
***
***              lv_tabix = lv_tabix + 1.
***
***              DATA(lo_brf_cost) = NEW zcl_interco_brf_wht( ).
***              lo_brf_cost->get_cc_code( EXPORTING iv_product      = gs_header-product
***                                                  iv_cc_origen    = ls_item_sum-costcenterd4
***                                                  iv_departamento = ls_item_sum-department
***                                                  iv_tipo_doc     = ls_tvarvc_data-doctype
***                                        RECEIVING rv_cc_code      = lv_cc_code ).
***
***              IF lv_cc_code IS INITIAL.
***
***                lv_doc_key  = |DUMMY{ ls_doc_map-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
***                me->map_error(
***                  iv_id       = 'ZINT_MSG_INTERCO_CP'
***                  iv_number   = '28'
***                  iv_severity = if_abap_behv_message=>severity-error
***                  iv_doc_key  = lv_doc_key
***                  iv_doc_map  = ls_doc_map ).
***
***                lv_error = abap_true.
***                EXIT.
***
***              ENDIF.
***
***              doc_account->get( EXPORTING i_tarifftype = ls_tvarvc_data-tarifftype_item_2n
***                                          i_department = ls_item_sum-department
***                                RECEIVING result       = DATA(ls_glaccount_2) ).
***
***              TRY.
***                  DATA(ls_percent_je) = VALUE #( lt_percent_je[ accountingdocument  = ls_group-documentkey(10)
***                                                                 companycode        = ls_group-companycode
***                                                                 fiscalyear         = ls_group-fiscalyear
***                                                                 profitcenter       = ls_item_sum-profitcenter ] ).
***                CATCH cx_sy_itab_line_not_found.
***                  CONTINUE.
***              ENDTRY.
***
***              DATA(ls_percent_his) = VALUE #( lt_percent_his[ accountingdocument  = ls_group-documentkey(10)
***                                                               companycode        = ls_group-companycode
***                                                               fiscalyear         = ls_group-fiscalyear
***                                                               profitcenter       = ls_item_sum-profitcenter
***                                                               costcenterd4       = ls_item_sum-costcenterd4 ] OPTIONAL ).
***
***
***              lv_amt_cocode = ( ( lv_wth_amt_cocode * ls_percent_je-percent ) / 100000  * ( ls_item_sum-percentoftotal / 100000 ) ).
***              lv_amt_doc    = ( ( lv_wth_amt_doc    * ls_percent_je-percent ) / 100000  * ( ls_item_sum-percentoftotal / 100000 ) ).
***
***              IF ls_percent_his IS NOT INITIAL.
***                lv_amt_cocode = lv_amt_cocode * ( ls_percent_his-percent / 100000 ).
***                lv_amt_doc    = lv_amt_doc    * ( ls_percent_his-percent / 100000 ).
***              ENDIF.
***
***              lv_position_num += 1.
***              ls_glitems = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
***                                               partnercompany      = lv_company_item
***                                               glaccount           = |{ ls_glaccount_2-glaccount1 ALPHA = IN }|
***                                               documentitemtext    = lv_item_text
***                                               assignmentreference = gs_header-productname
***                                               material            = gs_header-product
***                                               _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                 THEN lv_amt_cocode
***                                                                                                                 WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                 THEN lv_amt_cocode * -1 )
***                                                                                currency               = <lfs_with_item>-companycodecurrency
***                                                                                exchangerate           = lv_exchangerate
***                                                                                currencyrole           = '10'  )
***                                                                              ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                 THEN lv_amt_doc
***                                                                                                                 WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                 THEN lv_amt_doc * -1 )
***                                                                                currency               = <lfs_with_item>-documentcurrency
***                                                                                exchangerate           = lv_exchangerate
***                                                                                currencyrole           = '00'   ) )
***                                               costcenter          =   |{ lv_cc_code }{ ls_sitecode-internalcode }{ ls_item_sum-profitcenter ALPHA = OUT }| ).
***
***              APPEND ls_glitems TO lt_glitems.
***              CLEAR ls_glitems.
***
***              IF lv_amt_doc > lv_amt_max.
***                lv_amt_max = lv_amt_doc.
***                lv_index_mayor = lv_tabix.
***              ENDIF.
***
***              lv_totalpos_amt_doc    = lv_totalpos_amt_doc    + lv_amt_doc.
***              lv_totalpos_amt_cocode = lv_totalpos_amt_cocode + lv_amt_cocode.
***
***              CLEAR: lv_amt_doc, lv_amt_cocode, ls_percent_je, ls_percent_his.
***
***            ENDLOOP.
***
***            APPEND INITIAL LINE TO gt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
***            <fs_doc_map>-id                 = ls_group-id.
***            <fs_doc_map>-item_id            = ls_group-item_id.
***            <fs_doc_map>-itembasis_id       = ls_group-itembasis_id.
***            <fs_doc_map>-itemcalc_id        = ls_group-itemcalc_id.
***            <fs_doc_map>-documentkey        = |DUMMY{ ls_group-documentkey }{ ls_item_1-providercompanycode }{ ls_item_1-product }{ ls_item_1-recipientcompanycode }|.
***            <fs_doc_map>-parentdocumentkey  = ls_group-documentkey(10).
***            <fs_doc_map>-fiscalyear         = ls_group-fiscalyear.
***            <fs_doc_map>-companycode        = ls_group-companycode.
***            <fs_doc_map>-documenttype       = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.
***            <fs_doc_map>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***
***
***          ENDLOOP.
***
****       Redondeo en donde las monedas quedan en distinto signo, se le descuentan de la posición con mayor valor.
***          IF ( lv_totalpos_amt_doc < 0 AND lv_totalpos_amt_cocode > 0 ) OR ( lv_totalpos_amt_doc > 0 AND lv_totalpos_amt_cocode < 0 ).
***
***            ASSIGN lt_glitems[ lv_index_mayor ] TO FIELD-SYMBOL(<lfs_line>).
***            IF sy-subrc = 0.
***
***              ASSIGN <lfs_line>-_currencyamount[ currency = <lfs_with_item>-companycodecurrency ] TO FIELD-SYMBOL(<lfs_cocode>).
***              IF sy-subrc = 0.
***
***                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
***                  <lfs_cocode>-journalentryitemamount = <lfs_cocode>-journalentryitemamount - lv_totalpos_amt_cocode.
***                ENDIF.
***
***                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***                  <lfs_cocode>-journalentryitemamount = <lfs_cocode>-journalentryitemamount - ( lv_totalpos_amt_cocode * -1 ).
***                ENDIF.
***
***              ENDIF.
***
***              ASSIGN <lfs_line>-_currencyamount[ currency = <lfs_with_item>-documentcurrency ] TO FIELD-SYMBOL(<lfs_doc>).
***              IF sy-subrc = 0.
***
***                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post.
***                  <lfs_doc>-journalentryitemamount = <lfs_doc>-journalentryitemamount - lv_totalpos_amt_doc.
***                ENDIF.
***
***                IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***                  <lfs_doc>-journalentryitemamount = <lfs_doc>-journalentryitemamount - ( lv_totalpos_amt_doc ) * -1.
***                ENDIF.
***
***              ENDIF.
***
***            ENDIF.
***
****           Posición de redondeo
***          ELSEIF ( lv_totalpos_amt_doc    <> 0 AND lv_totalpos_amt_doc    >= -1 AND lv_totalpos_amt_doc    <= 1 ) OR
***                 ( lv_totalpos_amt_cocode <> 0 AND lv_totalpos_amt_cocode >= -1 AND lv_totalpos_amt_cocode <= 1 ).
***
***            ls_sitecode = VALUE #( lt_sitecode[ companycode  = lv_company ] OPTIONAL ).
***            lv_costcenter = ls_tvarvc_data-costcenter_redondeo.
***            REPLACE ALL OCCURRENCES OF '*' IN lv_costcenter WITH ls_sitecode-internalcode.
***            CONDENSE lv_costcenter.
***
***            lv_position_num += 1.
***            ls_glitems = VALUE lsty_glitems( glaccountlineitem   = lv_position_num
***                                             partnercompany      = lv_company_item
***                                             glaccount           = |{ ls_tvarvc_data-glaccount_redondeo ALPHA = IN }|
***                                             documentitemtext    = lv_item_text
***                                             assignmentreference = gs_header-productname
***                                             material            = gs_header-product
***                                             _currencyamount     = VALUE #( ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                   THEN lv_totalpos_amt_cocode * -1
***                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                   THEN lv_totalpos_amt_cocode )
***                                                                              currency               = <lfs_with_item>-companycodecurrency
***                                                                              exchangerate           = lv_exchangerate
***                                                                              currencyrole           = '10'  )
***                                                                            ( journalentryitemamount = COND #( WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
***                                                                                                                   THEN lv_totalpos_amt_doc * -1
***                                                                                                                   WHEN gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
***                                                                                                                   THEN lv_totalpos_amt_doc )
***                                                                              currency               = <lfs_with_item>-documentcurrency
***                                                                              exchangerate           = lv_exchangerate
***                                                                              currencyrole           = '00'   ) )
***                                             costcenter          =  lv_costcenter ).
***
***            APPEND ls_glitems TO lt_glitems.
***            CLEAR: ls_glitems, lv_totalpos_amt_doc, lv_totalpos_amt_cocode, lv_costcenter.
***
***          ENDIF.
***
***          IF lv_error = abap_false.
***            "Header plus items
***            APPEND INITIAL LINE TO gta_journalentry_post ASSIGNING FIELD-SYMBOL(<je_deep>).
***            <je_deep>-%cid = |INT{ sy-tabix }|.
***            <je_deep>-%param = VALUE #(  companycode                  = lv_company
***                                         documentdate                 = <lfs_with_item>-documentdate
***                                         postingdate                  = <lfs_with_item>-postingdate
***                                         accountingdocumenttype       = ls_tvarvc_data-blart
***                                         accountingdocumentheadertext = |{ ls_item_1-providercompanycode } { ls_item_1-recipientcompanycode  } { gs_header-productname }|
***                                         createdbyuser                = cl_abap_context_info=>get_user_technical_name( )
***                                        _glitems                      = lt_glitems  ).
***
***            DATA(lo_exe_bo) = NEW zcl_proposal_bo_wt_post_par( iv_process  = zcl_boproposal_tools=>gc_create_doc
***                                                               iv_doc_type = gv_proposal_type
***                                                               it_doc_map  = gt_doc_map_db
***                                                               it_je_post  = gta_journalentry_post ).
***
***            APPEND lo_exe_bo TO gtd_list_bo.
***
***          ENDIF.
***
***          CLEAR: gt_doc_map_db, gta_journalentry_post, lt_glitems, ls_relprodrate, lv_company, lv_totalpos_amt_doc, lv_totalpos_amt_cocode,
***                 lv_position_num, lv_wth_amt_cocode, lv_wth_amt_doc, lv_perc_no_comp, ls_relprodrate, lv_costcenter, lv_cc_code,
***                 ls_sitecode, ls_glaccount_1, ls_glaccount_2, ls_item_dept, ls_item_1, lv_flag, lv_company_item.
***
***        CATCH cx_sy_itab_line_not_found.
***          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
***      ENDTRY.
***
***    ENDLOOP.
***
***    IF lv_error = abap_true.
***      save_log( ).
***      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
***    ENDIF.
***
***    IF gtd_list_bo IS NOT INITIAL.
***      exe_bo( ).
***      et_doc_map = me->gt_doc_map_db.
***      save_log( ).
***      IF gt_doc_map_db[] IS INITIAL OR
***          line_exists( gt_doc_map_db[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
***          OR line_exists( gt_doc_map_db[ status = abap_false ] ).
***        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
***      ENDIF.
***    ENDIF.

  ENDMETHOD.


  METHOD constructor.

    super->constructor(
      iv_doctype = iv_doctype
      is_header  = is_header
      it_items   = it_items
      its_doc    = its_doc
      it_doc     = it_doc
      it_doc_map = it_doc_map ).

***    gtd_doc_wt        = it_doc.
***    gv_proposal_type  = iv_proposal_type.
***    gt_doc_map_wt     = it_doc_map.
***    gv_process        = iv_process.

  ENDMETHOD.


  METHOD preparedata.

***    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>).
***
***      DATA(ls_doc_bd) = VALUE #( gtd_doc_wt[ id           = <fs_items>-id
***                                             item_id      = <fs_items>-item_id
***                                             itembasis_id = <fs_items>-itembasis_id
***                                             itemcalc_id  = <fs_items>-itemcalc_id
***                                             documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif ] OPTIONAL ).
***      IF ls_doc_bd IS INITIAL.
***        ls_doc_bd = VALUE #( gtd_doc_wt[ id           = <fs_items>-id
***                                         item_id      = <fs_items>-item_id
***                                         itembasis_id = <fs_items>-itembasis_id
***                                         itemcalc_id  = <fs_items>-itemcalc_id
***                                         documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post ] OPTIONAL ).
***        IF ls_doc_bd IS NOT INITIAL.
***          APPEND INITIAL LINE TO gt_doc_map_wt ASSIGNING FIELD-SYMBOL(<fs_doc_map_wt>).
***          <fs_doc_map_wt>-id            = <fs_items>-id.
***          <fs_doc_map_wt>-item_id       = <fs_items>-item_id.
***          <fs_doc_map_wt>-itembasis_id  = <fs_items>-itembasis_id.
***          <fs_doc_map_wt>-itemcalc_id   = <fs_items>-itemcalc_id.
***          <fs_doc_map_wt>-documentkey   = ls_doc_bd-documentkey.
***          <fs_doc_map_wt>-documenttype  = ls_doc_bd-documenttype.
***          <fs_doc_map_wt>-fiscalyear    = ls_doc_bd-fiscalyear.
***          <fs_doc_map_wt>-companycode   = ls_doc_bd-companycode.
***        ENDIF.
***      ELSEIF ls_doc_bd-documentkey(5) = 'DUMMY'.
***        APPEND INITIAL LINE TO gt_doc_map_wt ASSIGNING <fs_doc_map_wt>.
***        <fs_doc_map_wt>-id                = <fs_items>-id.
***        <fs_doc_map_wt>-item_id           = <fs_items>-item_id.
***        <fs_doc_map_wt>-itembasis_id      = <fs_items>-itembasis_id.
***        <fs_doc_map_wt>-itemcalc_id       = <fs_items>-itemcalc_id.
***        <fs_doc_map_wt>-documentkey       = ls_doc_bd-documentkey+5(10).
***        <fs_doc_map_wt>-documenttype      = ls_doc_bd-documenttype.
***        <fs_doc_map_wt>-parentdocumentkey = ls_doc_bd-parentdocumentkey.
***        <fs_doc_map_wt>-fiscalyear        = ls_doc_bd-fiscalyear.
***        <fs_doc_map_wt>-companycode       = <fs_items>-recipientcompanycode.
***      ENDIF.
***
***      CLEAR ls_doc_bd.
***
***    ENDLOOP.
***
***    DELETE gt_doc_map_wt WHERE documenttype <> zcl_proposal_bo_abs=>c_document_type-grossingupreclassif AND
***                               documenttype <> zcl_proposal_bo_abs=>c_document_type-si_withholding_post.

  ENDMETHOD.

  METHOD preparedata_reverse.

***    LOOP AT gtd_doc_wt ASSIGNING FIELD-SYMBOL(<fs_items_wt>).
***      IF <fs_items_wt>-documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif.
***
***        DATA(ls_doc_si) = VALUE #( gtd_doc_wt[ id                = <fs_items_wt>-id
***                                               parentdocumentkey = <fs_items_wt>-documentkey
***                                               companycode       = <fs_items_wt>-companycode
***                                               documenttype      = zcl_proposal_bo_abs=>c_document_type-anul_grossingup_reclassif ] OPTIONAL ).
***
***        IF ls_doc_si IS INITIAL OR ls_doc_si-documentkey(5) = 'DUMMY'.
***          APPEND <fs_items_wt> TO gt_doc_map_wt.
***        ENDIF.
***      ENDIF.
***    ENDLOOP.

  ENDMETHOD.


  METHOD get_tvarvc.

***    DATA lv_low TYPE zi_tvarvc-low.
***
***    SELECT name,
***           sign,
***           opti,
***           low,
***           high
***    FROM zi_tvarvc
***    WHERE name = @gc_doctype             OR
***          name = @gc_tarifftype_item_1   OR
***          name = @gc_tarifftype_item_2n  OR
***          name = @gc_glaccount_redondeo  OR
***          name = @gc_costcenter_redondeo OR
***          name = @gc_blart               OR
***          name = @gc_glaccount_je        ORDER BY name
***    INTO TABLE @DATA(lt_tvarvc).
***    IF sy-subrc = 0.
***
***      TRY.
***          DATA(ls_tvarvc) = lt_tvarvc[ name = gc_tarifftype_item_1  ] .
***          iv_tvarvc_data-tarifftype_item_1 = ls_tvarvc-low.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      TRY.
***          ls_tvarvc = lt_tvarvc[ name = gc_tarifftype_item_2n  ].
***          iv_tvarvc_data-tarifftype_item_2n = ls_tvarvc-low.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      TRY.
***          ls_tvarvc = lt_tvarvc[ name = gc_glaccount_redondeo  ].
***          iv_tvarvc_data-glaccount_redondeo = ls_tvarvc-low.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      TRY.
***          ls_tvarvc = lt_tvarvc[ name = gc_costcenter_redondeo ].
***          iv_tvarvc_data-costcenter_redondeo = ls_tvarvc-low.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      lv_low = gv_proposal_type.
***      CONDENSE lv_low.
***
***      TRY.
***          ls_tvarvc = lt_tvarvc[ name = gc_doctype low = lv_low ].
***          iv_tvarvc_data-doctype = ls_tvarvc-high.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      TRY.
***          ls_tvarvc = lt_tvarvc[ name = gc_blart low = lv_low ].
***          iv_tvarvc_data-blart = ls_tvarvc-high.
***        CATCH cx_sy_itab_line_not_found.
***      ENDTRY.
***
***      iv_tvarvc_data-glaccount_je = VALUE #( FOR ls_tvarvc_value IN lt_tvarvc WHERE ( name = gc_glaccount_je )
***                                                                 ( sign   = ls_tvarvc_value-sign
***                                                                   option = ls_tvarvc_value-opti
***                                                                   low    = ls_tvarvc_value-low
***                                                                   high   = ls_tvarvc_value-high ) ).
***
***    ENDIF.

  ENDMETHOD.


  METHOD map_error.

***    DATA: lt_doc_map_log TYPE TABLE FOR REPORTED EARLY i_journalentrytp\\journalentry,
***          lt_doc_map_db  TYPE gtty_doc,
***          lv_status_log  TYPE zfi_a_intrc_cpdl-msgty,
***          lv_attime      TYPE zfi_a_intrc_cpid-createdat,
***          lv_byuser      TYPE zfi_a_intrc_cpid-createdby.
***
***    lt_doc_map_log = VALUE #( ( %msg = new_message( id       = iv_id
***                                                    number   = iv_number
***                                                    severity = iv_severity
***                                                    v1       = iv_doc_map-documentkey ) ) ).
***
***    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
***    GET TIME STAMP FIELD lv_attime.
***
***    mapping_doc_log( EXPORTING iv_dockey      = iv_doc_key
***                               iv_companycode = iv_doc_map-companycode
***                               iv_fiscalyear  = iv_doc_map-fiscalyear
***                               iv_doctype     = gv_proposal_type
***                               it_reported    = lt_doc_map_log
***                     CHANGING  ct_map_id_doc  = gt_doc_map_wt
***                               cv_status      = lv_status_log ).
***
***    APPEND INITIAL LINE TO lt_doc_map_db ASSIGNING FIELD-SYMBOL(<fs_doc_map_log>).
***    <fs_doc_map_log>-id             = iv_doc_map-id.
***    <fs_doc_map_log>-item_id        = iv_doc_map-item_id.
***    <fs_doc_map_log>-itembasis_id   = iv_doc_map-itembasis_id.
***    <fs_doc_map_log>-itemcalc_id    = iv_doc_map-itemcalc_id.
***    <fs_doc_map_log>-documentkey    = iv_doc_key.
***
***    mapping_doc( EXPORTING iv_dockey        = iv_doc_key
***                           iv_companycode   = iv_doc_map-companycode
***                           iv_fiscalyear    = iv_doc_map-fiscalyear
***                           iv_parentdockey  = iv_doc_map-documentkey
***                           iv_parentdoctype = iv_doc_map-documenttype
***                           iv_doctype       = gv_proposal_type
***                           iv_status        = me->c_document_status-error
***                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
***                           iv_isadjustment  = space
***                           iv_byuser        = lv_byuser
***                           iv_attime        = lv_attime
***                 CHANGING  ct_map_id_doc    = lt_doc_map_db ).

  ENDMETHOD.


  METHOD get_percent_of_total.

***    DATA: ls_total_item       TYPE gty_total_item,
***          lt_total_item       TYPE gtty_total_item,
***          ls_item_sum         TYPE gty_item_sum,
***          lv_dif              TYPE gty_item_sum-percentoftotal,
***          lv_total_aux        TYPE gty_item_sum-percentoftotal,
***          lv_profitcenter_aux TYPE zi_intercoproposalitem-profitcenter.
***
***    IF gtd_items_add IS INITIAL.
***      RETURN.
***    ENDIF.
***
***    SELECT zi_intercoproposalitemorglacct~id,
***           zi_intercoproposalitemorglacct~itemid,
***           zi_intercoproposalitemorglacct~department,
***           zi_intercoproposalitemorglacct~costcenter,
***           zi_intercoproposalitemorglacct~costcenterd4,
***           zi_intercoproposalitemorglacct~\_item-profitcenter,
***           zi_intercoproposalitemorglacct~\_item-profitcentereq,
***           zi_intercoproposalitemorglacct~amountinglobalcurrency,
***           zi_intercoproposalitemorglacct~\_item-providercountry,
***           zi_intercoproposalitemorglacct~\_item-recipientcountry
***    FROM  zi_intercoproposalitemorglacct
***    INNER JOIN @gtd_items_add AS items
***    ON    zi_intercoproposalitemorglacct~id      = items~id
***    AND   zi_intercoproposalitemorglacct~itemid  = items~item_id
***    INTO TABLE @DATA(lt_itemorglacct).
***    IF sy-subrc <> 0.
***      RETURN.
***    ENDIF.
***
***    "Se reeplaza item con profitcenter eq por correpondiente donde profitcenter  = profitcentereq
***    LOOP AT lt_itemorglacct ASSIGNING FIELD-SYMBOL(<lfs_item>).
***
***      IF <lfs_item>-profitcentereq IS NOT INITIAL.
***
***        lv_profitcenter_aux = |{ <lfs_item>-profitcentereq ALPHA = IN }|.
***
***        TRY.
***            DATA(ls_aux) = lt_itemorglacct[ profitcenter      = lv_profitcenter_aux
***                                            recipientcountry  = <lfs_item>-recipientcountry ].
***
***          CATCH cx_sy_itab_line_not_found.
***
******* INICIO  CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10
***            <lfs_item>-profitcenter = <lfs_item>-profitcentereq.
***            <lfs_item>-profitcenter  = |{ <lfs_item>-profitcenter ALPHA = IN  }|.
******* INICIO  CAMBIO JERARQUIA DE CEBE EQUIVALENTE 30/10
***            CONTINUE.
***        ENDTRY.
***
***        <lfs_item>-profitcenter  = lv_profitcenter_aux.
***        <lfs_item>-itemid        = ls_aux-itemid.
***
***        CLEAR: <lfs_item>-profitcentereq.
***        CLEAR: lv_profitcenter_aux.
***
***      ENDIF.
***
***      "Se excluyen los registros de CECOS LOCALES.
***      IF <lfs_item>-providercountry <> <lfs_item>-recipientcountry AND <lfs_item>-costcenterd4 = 0.
***        DELETE lt_itemorglacct INDEX sy-tabix.
***      ENDIF.
***
***    ENDLOOP.
***
***    "Se excluyen los registros HISPANOS/BRAZIL
***    DELETE lt_itemorglacct WHERE providercountry <> 'BR' AND recipientcountry = 'BR' AND costcenterd4 = 3.
***
***    SORT lt_itemorglacct BY id itemid costcenterd4.
***
***    LOOP AT lt_itemorglacct INTO DATA(ls_item) GROUP BY  ( id           = ls_item-id
***                                                           itemid       = ls_item-itemid
***                                                           costcenterd4 = ls_item-costcenterd4 ).
***
***      LOOP AT GROUP ls_item INTO DATA(ls_item_group).
***
***        ls_total_item-total = ls_total_item-total + ls_item_group-amountinglobalcurrency.
***
***      ENDLOOP.
***
***      IF ls_total_item IS NOT INITIAL.
***
***        ls_total_item-id           = ls_item-id.
***        ls_total_item-itemid       = ls_item-itemid.
***        ls_total_item-costcenterd4 = ls_item-costcenterd4.
***
***        APPEND ls_total_item TO lt_total_item.
***        CLEAR ls_total_item.
***
***      ENDIF.
***
***    ENDLOOP.
***
***    SORT lt_itemorglacct BY id itemid department costcenterd4 profitcenter.
***
***    LOOP AT lt_itemorglacct INTO DATA(ls_item_prop) GROUP BY ( id            = ls_item_prop-id
***                                                               itemid        = ls_item_prop-itemid
***                                                               department    = ls_item_prop-department
***                                                               costcenterd4  = ls_item_prop-costcenterd4
***                                                               profitcenter  = ls_item_prop-profitcenter ).
***      LOOP AT GROUP ls_item_prop INTO DATA(ls_group_prop).
***        ls_item_sum-id              = ls_group_prop-id.
***        ls_item_sum-item_id         = ls_group_prop-itemid.
***        ls_item_sum-department      = ls_group_prop-department.
***        ls_item_sum-costcenterd4    = ls_group_prop-costcenterd4.
***        ls_item_sum-costcenter      = ls_group_prop-costcenter.
***        ls_item_sum-profitcenter    = ls_group_prop-profitcenter.
***        ls_item_sum-profitcentereq  = ls_group_prop-profitcentereq.
***
***        TRY.
***            DATA(ls_total) = lt_total_item[ id           = ls_item_prop-id
***                                            itemid       = ls_item_prop-itemid
***                                            costcenterd4 = ls_item_prop-costcenterd4 ].
***
***            lv_total_aux = ( ls_group_prop-amountinglobalcurrency / ls_total-total ) * 100000.
***            ls_item_sum-percentoftotal =   ls_item_sum-percentoftotal + lv_total_aux.
***            CLEAR lv_total_aux.
***
***          CATCH cx_sy_itab_line_not_found.
***            CONTINUE.
***        ENDTRY.
***
***      ENDLOOP.
***
***      IF ls_item_sum IS NOT INITIAL.
***        APPEND ls_item_sum TO ch_item_sum.
***        CLEAR ls_item_sum.
***      ENDIF.
***
***    ENDLOOP.
***
***
***    SORT ch_item_sum BY id item_id costcenterd4 percentoftotal DESCENDING.
***
***    LOOP AT ch_item_sum ASSIGNING FIELD-SYMBOL(<lfs_aux>) GROUP BY ( id            = <lfs_aux>-id
***                                                                     itemid        = <lfs_aux>-item_id
***                                                                     costcenterd4  = <lfs_aux>-costcenterd4 ).
***
***      CLEAR: lv_total_aux, lv_dif.
***
***      LOOP AT GROUP <lfs_aux> ASSIGNING FIELD-SYMBOL(<lfs_group>).
***
***        lv_total_aux = lv_total_aux + <lfs_group>-percentoftotal.
***
***      ENDLOOP.
***
***      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
***      lv_dif = 100000 - lv_total_aux.
***      <lfs_aux>-percentoftotal = <lfs_aux>-percentoftotal + lv_dif.
***
***    ENDLOOP.


  ENDMETHOD.


  METHOD get_percent_je.

***    DATA: ls_total_je   TYPE gty_total_je,
***          lt_total_je   TYPE gtty_total_je,
***          ls_percent_je TYPE gty_percent_je,
***          lv_dif        TYPE gty_item_sum-percentoftotal,
***          lv_total_aux  TYPE gty_item_sum-percentoftotal.
***
***    CONSTANTS lc_profitcenter_redondeo TYPE i_journalentryitem-profitcenter VALUE '0000000999'.
***
***    IF iv_doc_map_si IS INITIAL.
***      RETURN.
***    ENDIF.
***
***    SELECT accountingdocument,
***           companycode,
***           fiscalyear,
***           glaccount,
***           profitcenter,
***           amountintransactioncurrency,
***           transactioncurrency,
***           amountinglobalcurrency,
***           globalcurrency
***           FROM i_journalentryitem WITH PRIVILEGED ACCESS
***    FOR ALL ENTRIES IN @iv_doc_map_si
***    WHERE accountingdocument = @iv_doc_map_si-documentkey(10)
***    AND   companycode        = @iv_doc_map_si-companycode
***    AND   fiscalyear         = @iv_doc_map_si-fiscalyear
***    AND   glaccount   IN @iv_glaccount_je
***    AND   sourceledger = '0L'
***    INTO TABLE @DATA(lt_je).
***    IF sy-subrc = 0.
***
***      SORT lt_je BY accountingdocument companycode fiscalyear.
***
***      LOOP AT lt_je INTO DATA(ls_je) GROUP BY ( accountingdocument = ls_je-accountingdocument
***                                                companycode        = ls_je-companycode
***                                                fiscalyear         = ls_je-fiscalyear ).
***
***        LOOP AT GROUP ls_je INTO DATA(ls_group_je).
***
***          ls_total_je-accountingdocument          = ls_group_je-accountingdocument.
***          ls_total_je-companycode                 = ls_group_je-companycode.
***          ls_total_je-fiscalyear                  = ls_group_je-fiscalyear.
***          ls_total_je-glaccount                   = ls_group_je-glaccount.
***          ls_total_je-profitcenter                = ls_group_je-profitcenter.
***          ls_total_je-amountintransactioncurrency = ls_total_je-amountintransactioncurrency + ls_group_je-amountintransactioncurrency.
***          ls_total_je-transactioncurrency         = ls_group_je-transactioncurrency.
***          ls_total_je-amountinglobalcurrency      = ls_total_je-amountinglobalcurrency + ls_group_je-amountinglobalcurrency.
***          ls_total_je-globalcurrency              = ls_group_je-globalcurrency.
***
***        ENDLOOP.
***
***        IF ls_total_je IS NOT INITIAL.
***          APPEND ls_total_je TO lt_total_je.
***          CLEAR ls_total_je.
***        ENDIF.
***
***      ENDLOOP.
***
***      LOOP AT lt_je INTO DATA(ls_je_aux).
***
***        TRY.
***            DATA(ls_total) = lt_total_je[ accountingdocument = ls_je_aux-accountingdocument
***                                          companycode        = ls_je_aux-companycode
***                                          fiscalyear         = ls_je_aux-fiscalyear ].
***          CATCH cx_sy_itab_line_not_found.
***            CONTINUE.
***        ENDTRY.
***
***        ls_percent_je-accountingdocument          = ls_je_aux-accountingdocument.
***        ls_percent_je-companycode                 = ls_je_aux-companycode.
***        ls_percent_je-fiscalyear                  = ls_je_aux-fiscalyear.
***        ls_percent_je-glaccount                   = ls_je_aux-glaccount.
***        ls_percent_je-profitcenter                = ls_je_aux-profitcenter.
***
***        IF ls_total-amountinglobalcurrency <> 0.
***          ls_percent_je-percent  =  ( ls_je_aux-amountinglobalcurrency / ls_total-amountinglobalcurrency ) * 100000.
***        ENDIF.
***
***        IF ls_percent_je-percent = 0.
***          CONTINUE.
***        ENDIF.
***
***        APPEND ls_percent_je TO ch_percent_je.
***        CLEAR ls_percent_je.
***
***      ENDLOOP.
***
***    ENDIF.
***
***    SORT ch_percent_je BY accountingdocument companycode fiscalyear percent DESCENDING.
***
***    LOOP AT ch_percent_je ASSIGNING FIELD-SYMBOL(<lfs_percent>)  GROUP BY ( accountingdocument = <lfs_percent>-accountingdocument
***                                                                            companycode        = <lfs_percent>-companycode
***                                                                            fiscalyear         = <lfs_percent>-fiscalyear ).
***
***      LOOP AT GROUP <lfs_percent> ASSIGNING FIELD-SYMBOL(<lfs_group>).
***        lv_total_aux = lv_total_aux + <lfs_group>-percent.
***      ENDLOOP.
***
***      DATA(ls_aux) = VALUE #( ch_percent_je[ accountingdocument = <lfs_percent>-accountingdocument
***                                             companycode        = <lfs_percent>-companycode
***                                             fiscalyear         = <lfs_percent>-fiscalyear
***                                             profitcenter       = lc_profitcenter_redondeo ] OPTIONAL ).
***
***      "Se suma el porcentaje de profit center de redondeo a la linea con mayor porcentaje.
***      <lfs_percent>-percent =   <lfs_percent>-percent + ls_aux-percent.
***
***      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
***      lv_dif = 100000 - lv_total_aux.
***      <lfs_percent>-percent = <lfs_percent>-percent + lv_dif.
***
***      CLEAR: lv_total_aux, lv_dif, ls_aux.
***
***    ENDLOOP.
***
***    DELETE ch_percent_je WHERE profitcenter = lc_profitcenter_redondeo.

  ENDMETHOD.


  METHOD get_percent_his.

***    DATA: ls_total_je    TYPE gty_total_je,
***          lt_total_je    TYPE gtty_total_je,
***          ls_percent_his TYPE gty_percent_his,
***          lv_dif         TYPE gty_item_sum-percentoftotal,
***          lv_total_aux   TYPE gty_item_sum-percentoftotal,
***          lt_je          TYPE gtty_je_his.
***
***    IF iv_doc_map_si IS INITIAL.
***      RETURN.
***    ENDIF.
***
***    SELECT i_journalentryitem~accountingdocument,
***           i_journalentryitem~companycode,
***           i_journalentryitem~fiscalyear,
***           i_journalentryitem~glaccount,
***           i_journalentryitem~profitcenter,
***           i_journalentryitem~costcenter,
***           i_journalentryitem~amountintransactioncurrency,
***           i_journalentryitem~transactioncurrency,
***           i_journalentryitem~amountinglobalcurrency,
***           i_journalentryitem~globalcurrency,
***           i_journalentryitem~partnercompany,
***           partner~country  AS partnercountry,
***           comp~country     AS companycountry
***           FROM i_journalentryitem  WITH PRIVILEGED ACCESS
***           INNER JOIN i_companycode WITH PRIVILEGED ACCESS AS comp
***           ON i_journalentryitem~companycode    = comp~companycode
***           INNER JOIN i_companycode WITH PRIVILEGED ACCESS AS partner
***           ON i_journalentryitem~partnercompany = partner~companycode
***           FOR ALL ENTRIES IN @iv_doc_map_si
***           WHERE i_journalentryitem~accountingdocument = @iv_doc_map_si-documentkey(10)
***           AND   i_journalentryitem~companycode        = @iv_doc_map_si-companycode
***           AND   i_journalentryitem~fiscalyear         = @iv_doc_map_si-fiscalyear
****           AND   offsettingaccounttype = 'D'
***           AND   sourceledger = '0L'
***           AND   ( glaccounttype = 'P' OR glaccounttype = 'N' )
***          INTO CORRESPONDING FIELDS OF TABLE @lt_je.
***    IF sy-subrc = 0.
***
***      SORT lt_je BY accountingdocument companycode fiscalyear profitcenter.
***
***      LOOP AT lt_je  ASSIGNING FIELD-SYMBOL(<lfs_je>) GROUP BY ( accountingdocument = <lfs_je>-accountingdocument
***                                                                 companycode        = <lfs_je>-companycode
***                                                                 fiscalyear         = <lfs_je>-fiscalyear
***                                                                 profitcenter       = <lfs_je>-profitcenter ).
***
***        LOOP AT GROUP <lfs_je> ASSIGNING FIELD-SYMBOL(<lfs_group>).
***
***          IF gv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post.
***
***            IF <lfs_group>-partnercountry <> <lfs_group>-companycountry AND <lfs_group>-costcenter+3(1) = 0.
***              <lfs_group>-costcenterd4 = 1.
***            ELSE.
***              <lfs_group>-costcenterd4 = <lfs_group>-costcenter+3(1).
***            ENDIF.
***
***          ELSE.
***            <lfs_group>-costcenterd4 = <lfs_group>-costcenter+3(1).
***          ENDIF.
***
***          ls_total_je-accountingdocument          = <lfs_group>-accountingdocument.
***          ls_total_je-companycode                 = <lfs_group>-companycode.
***          ls_total_je-fiscalyear                  = <lfs_group>-fiscalyear.
***          ls_total_je-glaccount                   = <lfs_group>-glaccount.
***          ls_total_je-profitcenter                = <lfs_group>-profitcenter.
***          ls_total_je-amountintransactioncurrency = ls_total_je-amountintransactioncurrency + <lfs_group>-amountintransactioncurrency.
***          ls_total_je-transactioncurrency         = <lfs_group>-transactioncurrency.
***          ls_total_je-amountinglobalcurrency      = ls_total_je-amountinglobalcurrency + <lfs_group>-amountinglobalcurrency.
***          ls_total_je-globalcurrency              = <lfs_group>-globalcurrency.
***
***        ENDLOOP.
***
***        IF ls_total_je IS NOT INITIAL.
***          APPEND ls_total_je TO lt_total_je.
***          CLEAR ls_total_je.
***        ENDIF.
***
***      ENDLOOP.
***
***      SORT lt_je BY accountingdocument companycode fiscalyear profitcenter costcenterd4.
***
***      LOOP AT lt_je INTO DATA(ls_je_aux) GROUP BY ( accountingdocument = ls_je_aux-accountingdocument
***                                                    companycode        = ls_je_aux-companycode
***                                                    fiscalyear         = ls_je_aux-fiscalyear
***                                                    profitcenter       = ls_je_aux-profitcenter
***                                                    costcenterd4       = ls_je_aux-costcenterd4 ).
***
***        LOOP AT GROUP ls_je_aux INTO DATA(ls_group_aux).
***
***          TRY.
***              DATA(ls_total) = lt_total_je[ accountingdocument = ls_group_aux-accountingdocument
***                                            companycode        = ls_group_aux-companycode
***                                            fiscalyear         = ls_group_aux-fiscalyear
***                                            profitcenter       = ls_group_aux-profitcenter  ].
***            CATCH cx_sy_itab_line_not_found.
***              CONTINUE.
***          ENDTRY.
***
***          ls_percent_his-accountingdocument          = ls_group_aux-accountingdocument.
***          ls_percent_his-companycode                 = ls_group_aux-companycode.
***          ls_percent_his-fiscalyear                  = ls_group_aux-fiscalyear.
***          ls_percent_his-glaccount                   = ls_group_aux-glaccount.
***          ls_percent_his-profitcenter                = ls_group_aux-profitcenter.
***          ls_percent_his-costcenterd4                = ls_group_aux-costcenterd4.
***
***          IF ls_total-amountinglobalcurrency <> 0.
***            ls_percent_his-percent  =  ls_percent_his-percent + ( ls_group_aux-amountinglobalcurrency / ls_total-amountinglobalcurrency ) * 100000.
***          ENDIF.
***
***        ENDLOOP.
***
***        IF ls_percent_his IS NOT INITIAL.
***          APPEND ls_percent_his TO ch_percent_his.
***          CLEAR ls_percent_his.
***        ENDIF.
***
***      ENDLOOP.
***
***    ENDIF.
***
***
***    SORT ch_percent_his BY accountingdocument companycode profitcenter costcenterd4 fiscalyear percent DESCENDING.
***
***    LOOP AT ch_percent_his ASSIGNING FIELD-SYMBOL(<lfs_percent>)  GROUP BY ( accountingdocument = <lfs_percent>-accountingdocument
***                                                                             companycode        = <lfs_percent>-companycode
***                                                                             fiscalyear         = <lfs_percent>-fiscalyear
***                                                                             profitcenter       = <lfs_percent>-profitcenter ).
***      " costcenterd4       = <lfs_percent>-costcenterd4
***
***      LOOP AT GROUP <lfs_percent> ASSIGNING FIELD-SYMBOL(<lfs_group_p>).
***        lv_total_aux = lv_total_aux + <lfs_group_p>-percent.
***      ENDLOOP.
***
***      "Se le suma la diferencia por redondeo a la posición con mayor porcentaje.
***      lv_dif = 100000 - lv_total_aux.
***      <lfs_percent>-percent = <lfs_percent>-percent + lv_dif.
***
***      CLEAR: lv_total_aux.
***
***    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
