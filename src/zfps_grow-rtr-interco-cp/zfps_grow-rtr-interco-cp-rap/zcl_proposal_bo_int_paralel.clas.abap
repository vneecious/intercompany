CLASS zcl_proposal_bo_int_paralel DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gtty_post    TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
           gtty_rev     TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
           gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           gsty_glitems TYPE LINE OF gsty_post-%param-_glitems.

    DATA: gta_je_post              TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          gta_je_rev               TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          gv_process_interdiv      TYPE c,
          gv_documentkey_interdiv  TYPE zfi_a_intrc_cpid-documentkey,
          gv_parentdockey_interdiv TYPE zfi_a_intrc_cpid-documentkey,
          gts_doc_interdiv         TYPE gtsty_doc,
          gt_doc_map_interdiv      TYPE gtty_doc.
    METHODS constructor
      IMPORTING !iv_process      TYPE c
                !iv_documentkey  TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_parentdockey TYPE zfi_a_intrc_cpid-parentdocumentkey OPTIONAL
                !its_doc         TYPE gtsty_doc OPTIONAL
                !it_doc_map      TYPE gtty_doc OPTIONAL
                !it_je_post      TYPE gtty_post OPTIONAL
                !it_je_rev       TYPE gtty_rev OPTIONAL.
    INTERFACES if_abap_parallel.

  PROTECTED     SECTION.
    METHODS:
      exe_bo_sec REDEFINITION,
      exe_anulation_bo_sec REDEFINITION,
      exe_simulation_anul_bo_sec REDEFINITION,
      exe_simulation_bo_sec REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_int_paralel IMPLEMENTATION.


  METHOD constructor.
    super->constructor( iv_process           = iv_process
                        iv_documentkey       = iv_documentkey
                        iv_parentdocumentkey = iv_parentdockey
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map ).
    gv_process_interdiv = me->gv_process.
    gts_doc_interdiv = me->gts_doc.
    gt_doc_map_interdiv = me->gt_doc_map.
    IF iv_documentkey IS SUPPLIED.
      gv_documentkey_interdiv = iv_documentkey.
    ENDIF.
    IF iv_parentdockey IS SUPPLIED.
      gv_parentdockey_interdiv = iv_parentdockey.
    ENDIF.
    IF it_je_post IS SUPPLIED.
      gta_je_post = it_je_post.
    ENDIF.
    IF it_je_rev IS SUPPLIED.
      gta_je_rev = it_je_rev.
    ENDIF.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE me->gv_process_interdiv.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_interdiv ).
      WHEN zcl_boproposal_tools=>gc_simulate_doc.
        exe_simulation_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_interdiv ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_dockey       = me->gv_documentkey_interdiv
                                        iv_parentdockey = gv_parentdockey_interdiv
                              CHANGING  ct_map_id_doc   = me->gt_doc_map_interdiv ).
    ENDCASE.
    save_log( ).
  ENDMETHOD.


  METHOD exe_anulation_bo_sec.
    DATA: lv_dockey     TYPE zfi_a_intrc_cpid-documentkey,
          lv_status_doc TYPE zfi_a_intrc_cpid-status,
          lv_status_log TYPE zfi_a_intrc_cpdl-msgty,
          lv_byuser     TYPE zfi_a_intrc_cpid-createdby,
          lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    DATA lv_companycode      TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear      TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA cv_accdoctype      TYPE zfi_a_intrc_cpid-accountingdocumenttype.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    lv_companycode = me->gta_je_rev[ 1 ]-companycode.
    lv_fiscalyear = me->gta_je_rev[ 1 ]-fiscalyear.

    CHECK exe_simulation_anul_bo_sec( EXPORTING iv_dockey       = iv_dockey
                                              iv_parentdockey = iv_parentdockey
                                    CHANGING  ct_map_id_doc   = ct_map_id_doc
                                    cv_accountingdocumenttype = cv_accdoctype ) IS INITIAL.

    MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
      ENTITY journalentry
      EXECUTE reverse  FROM gta_je_rev
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported)
        MAPPED DATA(ls_mapped).

    IF ls_failed-journalentry IS INITIAL.

      COMMIT ENTITIES BEGIN
        RESPONSE OF i_journalentrytp
        FAILED DATA(ls_save_failed)
        REPORTED DATA(ls_save_reported).

      IF ls_save_failed-journalentry IS NOT INITIAL.
        ROLLBACK ENTITIES.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
      ELSE.
        CONVERT KEY OF i_journalentrytp FROM ls_mapped-journalentry[ 1 ]-%pid TO DATA(ls_so_final_key).
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = ls_so_final_key-accountingdocument.
        lv_companycode = ls_so_final_key-companycode.
        lv_fiscalyear = ls_so_final_key-fiscalyear.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_interdiv
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      lv_companycode = gta_je_rev[ 1 ]-companycode.
      lv_fiscalyear = gta_je_rev[ 1 ]-fiscalyear.
      lv_dockey = gta_je_rev[ 1 ]-accountingdocument.

      SELECT reversedocument, reversedocumentfiscalyear FROM i_journalentry
        FOR ALL ENTRIES IN @gta_je_rev
      WHERE companycode = @gta_je_rev-companycode
      AND fiscalyear = @gta_je_rev-fiscalyear
      AND accountingdocument = @gta_je_rev-accountingdocument
      AND reversedocument IS NOT INITIAL
      INTO TABLE @DATA(lt_manual_reversed_documents).

      IF sy-subrc = 0.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        ls_save_reported-journalentry = VALUE #( ( %msg = new_message_with_text(
                                                    severity = if_abap_behv_message=>severity-success
                                                    text     = 'Documento anulado manualmente'
                                                  ) ) ).

        lv_fiscalyear = lt_manual_reversed_documents[ 1 ]-reversedocumentfiscalyear.
        lv_dockey = lt_manual_reversed_documents[ 1 ]-reversedocument.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                                   it_reported    = ls_save_reported-journalentry
                         CHANGING  ct_map_id_doc  = ct_map_id_doc
                                   cv_status      = lv_status_log ).
      ELSE.
        ROLLBACK ENTITIES.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_interdiv
                                   it_reported    = ls_reported-journalentry
                         CHANGING  ct_map_id_doc  = ct_map_id_doc
                                   cv_status      = lv_status_log ).
      ENDIF.
    ENDIF.

    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.

    gts_doc_interdiv[] = gt_doc_map_interdiv[].

    LOOP AT gts_doc_interdiv ASSIGNING FIELD-SYMBOL(<lfs_docs>).
      <lfs_docs>-createdby = lv_byuser.
      <lfs_docs>-createdat = lv_attime.
    ENDLOOP.

    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_companycode   = lv_companycode
                           iv_fiscalyear    = lv_fiscalyear
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_interdiv
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-interdiv
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-interdivision
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_interdiv
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
  ENDMETHOD.


  METHOD exe_bo_sec.
    DATA lv_dockey     TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_companycode      TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear      TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.
    lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
    lv_fiscalyear = me->gta_je_post[ 1 ]-%param-documentdate(4).

    MODIFY ENTITIES OF i_journalentrytp
        ENTITY journalentry
        EXECUTE post FROM me->gta_je_post
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported)
        MAPPED DATA(ls_mapped).

    IF ls_failed-journalentry IS INITIAL.

      COMMIT ENTITIES BEGIN
      RESPONSE OF i_journalentrytp
      FAILED DATA(ls_save_failed)
      REPORTED DATA(ls_save_reported).

      IF ls_save_failed-journalentry IS NOT INITIAL.
        ROLLBACK ENTITIES.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
      ELSE.
        CONVERT KEY OF i_journalentrytp FROM ls_mapped-journalentry[ 1 ]-%pid TO DATA(ls_so_final_key).
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = ls_so_final_key-accountingdocument.
        lv_companycode = ls_so_final_key-companycode.
        lv_fiscalyear = ls_so_final_key-fiscalyear.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-interdiv
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

      COMMIT ENTITIES END.

    ELSE.
      ROLLBACK ENTITIES.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-interdiv
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-interdiv
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-interdivision
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_interdiv
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.
  ENDMETHOD.


  METHOD exe_simulation_anul_bo_sec.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    DATA ls_je_chk  TYPE STRUCTURE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA lt_je_chk  TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA(ls_je_rev) = gta_je_rev[ 1 ].
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    READ ENTITIES OF i_journalentrytp
          ENTITY journalentry
          FROM VALUE #( ( accountingdocument = ls_je_rev-accountingdocument
                          companycode        = ls_je_rev-companycode
                          fiscalyear         = ls_je_rev-fiscalyear ) )
            RESULT DATA(lt_reverse_result)
            FAILED DATA(ls_failed)
            REPORTED DATA(ls_reported).

    READ TABLE lt_reverse_result INTO DATA(ls_reverse_je) INDEX 1.
    IF sy-subrc = 0.
      ls_je_chk-%param-createdbyuser = ls_je_rev-%param-createdbyuser.
      ls_je_chk-%param-reversalreason = ls_je_rev-%param-reversalreason.
      ls_je_chk-%param-postingdate = ls_je_rev-%param-postingdate.
      ls_je_chk-%param-reversalreferencedocumentkey = ls_reverse_je-originalreferencedocument.
      ls_je_chk-%param-companycode = ls_reverse_je-companycode.
      ls_je_chk-%param-businesstransactiontype = ls_reverse_je-businesstransactiontype.
      ls_je_chk-%param-accountingdocument = ls_reverse_je-accountingdocument.
      cv_accountingdocumenttype = ls_reverse_je-accountingdocumenttype.

      IF ls_je_chk-%param-reversalreason IS NOT INITIAL.
        APPEND ls_je_chk TO lt_je_chk.

        READ ENTITIES OF i_journalentrytp
        ENTITY journalentry
        EXECUTE validate FROM lt_je_chk
          RESULT DATA(lt_check_result)
          FAILED DATA(ls_failed_chk)
          REPORTED DATA(ls_reported_chk).
        IF ls_failed_chk-journalentry IS NOT INITIAL.
          mapping_doc_log( EXPORTING "iv_dockey     = CONV #( ls_je_rev-accountingdocument )
                                     iv_companycode = ls_je_rev-companycode
                                     iv_fiscalyear  = ls_je_rev-fiscalyear
                                     iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_interdiv
                                     it_reported    = ls_reported_chk-journalentry
                           CHANGING  ct_map_id_doc  = ct_map_id_doc
                                     cv_status      = lv_status_log ).

          IF lv_status_log EQ 'E'.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          ENDIF.
          gts_doc_interdiv[] = gt_doc_map_interdiv[].
          mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                                 iv_companycode   = ls_je_rev-companycode
                                 iv_fiscalyear    = ls_je_rev-fiscalyear
                                 iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_interdiv
                                 iv_parentdockey  = iv_parentdockey
                                 iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-interdiv
                                 iv_status        = lv_status_doc
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-financial
                                 iv_isadjustment  = space
                                 its_doc          = me->gts_doc_interdiv
                                 iv_byuser        = lv_byuser
                                 iv_attime        = lv_attime
                       CHANGING  ct_map_id_doc    = ct_map_id_doc ).
        ENDIF.
      ENDIF.
    ENDIF.
    rv_exist = lv_status_log.
  ENDMETHOD.


  METHOD exe_simulation_bo_sec.

    DATA lv_dockey     TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_companycode      TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear      TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.

    DATA:
    lt_journalentry_val     TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.
    lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
    lv_fiscalyear  = me->gta_je_post[ 1 ]-%param-documentdate(4).

    lt_journalentry_val = CORRESPONDING #( gta_je_post ).

    READ ENTITIES OF i_journalentrytp
    ENTITY journalentry
    EXECUTE validate FROM lt_journalentry_val
    RESULT DATA(lt_check_result)
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported).

    IF ls_failed-journalentry IS NOT INITIAL.

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_error.
      lv_status_log = zcl_proposal_bo_abs=>c_document_status-simulated_error.

    ELSE.

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_ok.
      lv_status_log = zcl_proposal_bo_abs=>c_document_status-simulated_ok.

    ENDIF.


    mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                               iv_companycode = lv_companycode
                               iv_fiscalyear  = lv_fiscalyear
                               iv_doctype     = zcl_proposal_bo_abs=>c_document_type-interdiv
                               it_reported    = ls_reported-journalentry
                     CHANGING  ct_map_id_doc  = ct_map_id_doc
                               cv_status      = lv_status_log ).

    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-interdiv
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-interdivision
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_interdiv
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

  ENDMETHOD.
ENDCLASS.
