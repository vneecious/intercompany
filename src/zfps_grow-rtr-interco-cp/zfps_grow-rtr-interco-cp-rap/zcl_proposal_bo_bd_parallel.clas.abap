CLASS zcl_proposal_bo_bd_parallel DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gtty_cpid TYPE STANDARD TABLE OF zfi_a_intrc_cpid.
    TYPES: gtty_bdfromsd TYPE TABLE FOR ACTION IMPORT i_billingdocumenttp~createfromsddocument.
    TYPES: gsty_bd_create TYPE STRUCTURE FOR ACTION IMPORT i_billingdocumenttp~createfromsddocument.
    TYPES: gsty_bd_create_ref TYPE LINE OF gsty_bd_create-%param-_reference.
    TYPES: gtty_bd_canceldoc TYPE TABLE FOR ACTION IMPORT i_billingdocumenttp~createcancellationdocument.
    TYPES: gsty_bd_canceldoc TYPE STRUCTURE FOR ACTION IMPORT i_billingdocumenttp~createcancellationdocument.
    TYPES: gsty_bd_canceldoc_revreason TYPE gsty_bd_canceldoc-%param-reversalreason.

    DATA gta_bdfromsd    TYPE TABLE FOR ACTION IMPORT i_billingdocumenttp~createfromsddocument.
    DATA gta_bdcanceldoc    TYPE TABLE FOR ACTION IMPORT i_billingdocumenttp~createcancellationdocument.
    DATA gtd_doc_bd     TYPE gtty_doc.
    DATA gts_doc_bd     TYPE gtsty_doc.
    DATA gt_doc_map_so  TYPE gtty_doc.
    DATA gt_doc_map_bd  TYPE gtty_doc.
    DATA gtd_documentkey TYPE gtty_parentkey.
    DATA gv_dockey_bd    TYPE zfi_a_intrc_cpd-documentkey.
    DATA gv_parentdockey_bd    TYPE zfi_a_intrc_cpd-parentdocumentkey.
    DATA gtd_list_bo      TYPE cl_abap_parallel=>t_in_inst_tab.
    DATA gv_process_bd TYPE c.

    METHODS constructor
      IMPORTING
        it_doc          TYPE gtty_doc      OPTIONAL
        its_doc         TYPE gtsty_doc     OPTIONAL
        it_doc_map      TYPE gtty_doc      OPTIONAL
        ita_bdfromsd    TYPE gtty_bdfromsd OPTIONAL
        ita_bdcanceldoc TYPE gtty_bd_canceldoc OPTIONAL
        iv_parentdockey TYPE zfi_a_intrc_cpd-parentdocumentkey OPTIONAL
        iv_process      TYPE c             OPTIONAL.

    INTERFACES if_abap_parallel.

  PROTECTED SECTION.
    METHODS exe_bo_sec REDEFINITION.
    METHODS exe_anulation_bo_sec REDEFINITION.
    METHODS exe_simulation_anul_bo_sec REDEFINITION.
    METHODS set_journalentry
      IMPORTING iv_orrefdoc       TYPE i_journalentrytp-originalreferencedocument
                iv_doctype        TYPE zfi_a_intrc_cpid-documenttype
                iv_parentorrefdoc TYPE i_journalentrytp-originalreferencedocument
                iv_parentdoctype  TYPE zfi_a_intrc_cpid-parentdocumenttype
                iv_byuser         TYPE zfi_a_intrc_cpid-createdby
                iv_attime         TYPE zfi_a_intrc_cpid-createdat
      CHANGING  ct_map_id_doc     TYPE gtty_doc.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_bd_parallel IMPLEMENTATION.
  METHOD constructor.
    super->constructor( it_doc               = it_doc
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map
                        iv_parentdocumentkey = iv_parentdockey
                        iv_process           = iv_process ).
    gtd_doc_bd    = it_doc.
    gts_doc_bd    = its_doc.
    gt_doc_map_bd = it_doc_map.
*    gv_parentdockey_bd = iv_parentdockey.
    gv_parentdockey_bd = iv_parentdockey.
    gv_process_bd = iv_process.
    gta_bdfromsd  = ita_bdfromsd.
    gta_bdcanceldoc  = ita_bdcanceldoc.
  ENDMETHOD.

  METHOD if_abap_parallel~do.
    CASE me->gv_process_bd.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( EXPORTING iv_parentdocument = me->gv_parentdockey_bd
                    CHANGING  ct_map_id_doc     = me->gt_doc_map_bd ).
*        save_log( ).
        CLEAR gv_parentdockey_bd.
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_parentdockey = me->gv_parentdockey_bd
                              CHANGING  ct_map_id_doc   = me->gt_doc_map_bd ).
*        save_log( ).
    ENDCASE.
    save_log( ).
  ENDMETHOD.

  METHOD exe_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    MODIFY ENTITIES OF i_billingdocumenttp
           ENTITY billingdocument
           EXECUTE createfromsddocument FROM gta_bdfromsd
           RESULT DATA(lt_result_modify)
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES BEGIN
             RESPONSE OF i_billingdocumenttp
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_save_reported).
      LOOP AT lt_result_modify ASSIGNING FIELD-SYMBOL(<fs_billingdoc>).
        CONVERT KEY OF i_billingdocumenttp FROM <fs_billingdoc>-%param-%pid TO DATA(ls_so_final_key).
        <fs_billingdoc>-%param-billingdocument = ls_so_final_key-billingdocument.
        IF ls_save_failed-billingdocument IS NOT INITIAL.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          CLEAR lv_dockey.
        ELSE.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
          lv_dockey = ls_so_final_key-billingdocument.
        ENDIF.
*        APPEND LINES OF ls_save_reported-BillingDocument TO lt_msg.

      ENDLOOP.
      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                 it_reported   = ls_save_reported-billingdocument
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).
      COMMIT ENTITIES END.
    ELSE.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                 it_reported   = ls_reported-billingdocument
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-billingdocument
                           iv_parentdockey  = iv_parentdocument
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_bd
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ev_document = lv_dockey.
    IF lv_dockey IS NOT INITIAL.
      set_journalentry( EXPORTING iv_orrefdoc    = CONV #( ls_so_final_key )
                                  iv_doctype    = zcl_proposal_bo_abs=>c_document_type-je_sales
                                  iv_parentorrefdoc   = CONV #( iv_parentdocument )
                                  iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                  iv_byuser     = lv_byuser
                                  iv_attime     = lv_attime
                        CHANGING  ct_map_id_doc = ct_map_id_doc ).
    ENDIF.

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true OR documentkey(5) EQ 'DUMMY'.

    FREE: lt_result_modify, ls_failed, ls_reported, ls_save_failed, ls_save_reported.
  ENDMETHOD.

  METHOD exe_anulation_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    CHECK exe_simulation_anul_bo_sec( EXPORTING iv_dockey       = iv_dockey
                                                  iv_parentdockey = iv_parentdockey
                                        CHANGING  ct_map_id_doc   = ct_map_id_doc ) IS INITIAL.
*    " Reversal reason is: wrong prices and conditions.
*    DATA(lv_revreason) = '01'.

    MODIFY ENTITY i_billingdocumenttp
           EXECUTE createcancellationdocument
*           AUTO FILL CID
*           WITH VALUE #( FOR ls_key IN ct_map_id_doc
*                         ( BillingDocument       = ls_key-Documentkey
*                           %param-ReversalReason = lv_revreason ) )
           FROM gta_bdcanceldoc
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported)
           MAPPED DATA(ls_mapped).

    IF ls_failed IS NOT INITIAL.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      IF ls_reported-billingdocument IS NOT INITIAL.
        mapping_doc_log( EXPORTING "iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                   it_reported   = ls_reported-billingdocument
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-billingdocumentitem IS NOT INITIAL.
        mapping_doc_log( EXPORTING "iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                   it_reported   = ls_reported-billingdocumentitem
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
*      RETURN.
    ELSE.
      COMMIT ENTITIES BEGIN
       RESPONSE OF i_billingdocumenttp
       FAILED DATA(ls_failed_commit)
       REPORTED DATA(ls_reported_commit).

      IF ls_failed_commit IS NOT INITIAL.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      ELSE.
        CONVERT KEY OF i_billingdocumenttp FROM ls_mapped-billingdocument[ 1 ]-%pid TO DATA(ls_cancellationbillingdocument).
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = ls_cancellationbillingdocument-billingdocument.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                 it_reported   = ls_reported_commit-billingdocument
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                 it_reported   = ls_reported_commit-billingdocumentitem
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      COMMIT ENTITIES END.
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-billingdocument
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_bd
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).

    mapping_doc( EXPORTING iv_dockey       = iv_parentdockey
                           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                           iv_parentdockey  = iv_parentdockey
*                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status       = lv_status_doc
                           iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment = space
                           iv_isdeleted    = abap_true
                           its_doc         = me->gts_doc_bd
                           iv_byuser       = lv_byuser
                           iv_attime       = lv_attime
                 CHANGING  ct_map_id_doc   = ct_map_id_doc ).

    IF lv_dockey IS NOT INITIAL.
      set_journalentry( EXPORTING iv_orrefdoc    = CONV #( ls_cancellationbillingdocument )
                                  iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                                  iv_parentorrefdoc   = CONV #( iv_parentdockey )
                                  iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                  iv_byuser     = lv_byuser
                                  iv_attime     = lv_attime
                        CHANGING  ct_map_id_doc = ct_map_id_doc ).
    ENDIF.
    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
  ENDMETHOD.
  METHOD exe_simulation_anul_bo_sec.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    DATA ls_je_chk  TYPE STRUCTURE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA lt_je_chk  TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA lt_billdoc TYPE TABLE FOR REPORTED EARLY i_billingdocumenttp\\billingdocument.
*    DATA(ls_je_rev) = gta_BDCancelDoc[ 1 ].

    READ ENTITIES OF i_billingdocumenttp PRIVILEGED
     ENTITY billingdocument
     FIELDS ( billingdocument overallbillingstatus cancelledbillingdocument billingdocumentiscancelled accountingtransferstatus invoiceliststatus )
     WITH CORRESPONDING #( gta_bdcanceldoc )
     RESULT DATA(lt_reverse_result)
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported).

    READ TABLE lt_reverse_result INTO DATA(ls_reverse_bd) INDEX 1.
    IF sy-subrc = 0.
      IF ls_reverse_bd-billingdocumentiscancelled IS NOT INITIAL.
        lt_billdoc = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                    number   = '021'
                                                    severity = if_abap_behv_message=>severity-error
                                                    v1       = ls_reverse_bd-billingdocument ) ) ).
        mapping_doc_log( EXPORTING "iv_dockey     = CONV #( ls_je_rev-accountingdocument )
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                   it_reported   = lt_billdoc
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).

        IF lv_status_log EQ 'E'.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        ENDIF.
        mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                               iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                               iv_parentdockey  = iv_parentdockey
                               iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-billingdocument
                               iv_status        = lv_status_doc
                               iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                               iv_isadjustment  = space
                               its_doc          = me->gts_doc_bd
                               iv_byuser        = lv_byuser
                               iv_attime        = lv_attime
                     CHANGING  ct_map_id_doc    = ct_map_id_doc ).
      ENDIF.
    ENDIF.
    rv_exist = lv_status_log.
  ENDMETHOD.

  METHOD set_journalentry.
    DATA lt_billdoc TYPE TABLE FOR REPORTED EARLY i_billingdocumenttp\\billingdocument.
    DATA lv_companycode TYPE i_journalentrytp-companycode.
    DATA lv_fiscalyear TYPE i_journalentrytp-fiscalyear.
    DATA lv_accdoc TYPE i_journalentrytp-accountingdocument.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.

*      lv_orrefdoc = ls_so_final_key.
    SELECT SINGLE companycode, fiscalyear, accountingdocument FROM i_journalentrytp
    WHERE originalreferencedocument EQ @iv_orrefdoc
    INTO (@lv_companycode, @lv_fiscalyear, @lv_accdoc).
    IF sy-subrc = 0.
      lt_billdoc = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                  number   = '021'
                                                  severity = if_abap_behv_message=>severity-success
                                                  v1       = lv_accdoc ) ) ).
      mapping_doc_log( EXPORTING iv_dockey     = CONV #( lv_accdoc )
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype    = iv_doctype
                                 it_reported   = lt_billdoc
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      mapping_doc( EXPORTING iv_dockey        = CONV #( lv_accdoc )
                             iv_companycode   = lv_companycode
                             iv_fiscalyear    = lv_fiscalyear
                             iv_doctype       = iv_doctype
                             iv_parentdockey  = CONV #( iv_orrefdoc )
                             iv_parentdoctype = iv_parentdoctype
                             iv_status        = lv_status_doc
                             iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                             iv_isadjustment  = space
                             its_doc          = me->gts_doc_bd
                             iv_byuser        = iv_byuser
                             iv_attime        = iv_attime
                   CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ENDIF.
    "Delete de parent FI
    SELECT SINGLE companycode, fiscalyear, accountingdocument FROM i_journalentrytp
    WHERE originalreferencedocument EQ @iv_parentorrefdoc
    INTO (@lv_companycode, @lv_fiscalyear, @lv_accdoc).
    IF sy-subrc = 0.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      mapping_doc( EXPORTING iv_dockey        = CONV #( lv_accdoc )
                             iv_companycode   = lv_companycode
                             iv_fiscalyear    = lv_fiscalyear
                             iv_doctype       = zcl_proposal_bo_abs=>c_document_type-je_sales
                             iv_parentdockey  = CONV #( iv_orrefdoc )
                             iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-billingdocument
                             iv_status        = lv_status_doc
                             iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                             iv_isadjustment  = space
                             iv_isdeleted     = abap_true
                             its_doc          = me->gts_doc_bd
                             iv_byuser        = iv_byuser
                             iv_attime        = iv_attime
                   CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
