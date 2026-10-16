CLASS zcl_proposal_bo_wt_post_par DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_serializable_object .

    TYPES:
      gtty_journalentry_post    TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
    TYPES:
      gtty_journalentry_reverse TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .

    DATA:
      gta_journalentry_post     TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post .
    DATA:
      gta_journalentry_reverse     TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse .
*    TYPES gtty_invoice_create TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create.
*    TYPES gtty_invoice_cancel TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~Cancel.
*
*    DATA gta_invoice_create     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create.
*    DATA gta_invoice_cancel     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~Cancel.
    DATA gv_documentkey_si TYPE zfi_a_intrc_cpid-documentkey .
    DATA gv_parentdockey_si TYPE zfi_a_intrc_cpid-documentkey .
    DATA gs_header_si TYPE zi_intercoproposal .
    DATA gv_action TYPE c .
    DATA gt_doc_map_si TYPE gtty_doc .
    DATA gv_doc_type TYPE zfi_a_intrc_cpd-documenttype .

    METHODS constructor
      IMPORTING
        !is_header            TYPE zi_intercoproposal OPTIONAL
        !iv_process           TYPE c
        !iv_doc_type          TYPE zfi_a_intrc_cpd-documenttype
        !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !it_doc_map           TYPE gtty_doc OPTIONAL
        !it_je_post           TYPE gtty_journalentry_post OPTIONAL
        !it_je_reverse        TYPE gtty_journalentry_reverse OPTIONAL .
    INTERFACES if_abap_parallel.

  PROTECTED SECTION.
    METHODS:   exe_bo_sec REDEFINITION.
    METHODS:   exe_anulation_bo_sec REDEFINITION.
    METHODS:      exe_simulation_anul_bo_sec REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_wt_post_par IMPLEMENTATION.


  METHOD if_abap_parallel~do.
    CASE gv_action.
      WHEN zcl_boproposal_tools=>gc_create_doc.         "Creación Factura
        exe_bo_sec( EXPORTING iv_parentdocument = gv_parentdockey_si
                    IMPORTING ev_document       = DATA(lv_documentkey)
                    CHANGING  ct_map_id_doc     = gt_doc_map_si ).
        save_log( ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.        "Reversa Factura
        exe_anulation_bo_sec( EXPORTING iv_dockey       = gv_documentkey_si
                                        iv_parentdockey = gv_parentdockey_si
                              CHANGING  ct_map_id_doc   = gt_doc_map_si ).
        save_log( ).
*      WHEN zcl_boproposal_tools=>gc_reprocess_doc.        "Reprocesa Factura
*        exe_bo_sec( EXPORTING iv_parentdocument = gv_parentdockey_SI
*                              it_map_id_doc     = gt_doc_map_si ).
*
*        save_log( ).
    ENDCASE.
    save_log( ).
  ENDMETHOD.


  METHOD constructor.

    super->constructor( is_header      = is_header
                        iv_process     = iv_process
                        iv_documentkey = iv_parentdocumentkey
                        it_doc_map     = it_doc_map ).

    gv_action       = iv_process.
    gv_doc_type     = iv_doc_type.
    gt_doc_map_si   = it_doc_map.
    gs_header_si    = is_header.

    IF iv_documentkey IS SUPPLIED.
      gv_documentkey_si = iv_documentkey.
    ENDIF.
    IF iv_parentdocumentkey IS SUPPLIED.
      gv_parentdockey_si = iv_parentdocumentkey.
    ENDIF.
    IF it_je_post IS SUPPLIED.
      gta_journalentry_post = it_je_post.
    ENDIF.
    IF it_je_reverse IS SUPPLIED.
      gta_journalentry_reverse = it_je_reverse.
    ENDIF.
  ENDMETHOD.


  METHOD exe_anulation_bo_sec.

    DATA lv_status       TYPE zfi_a_intrc_cpid-status.
    DATA lv_dockey       TYPE zfi_a_intrc_cpd-documentkey.
    DATA lv_status_doc   TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log   TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser       TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime       TYPE zfi_a_intrc_cpid-createdat.
    DATA lv_companycode  TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear   TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lt_docs        TYPE gtsty_doc.
    DATA cv_accdoctype      TYPE zfi_a_intrc_cpid-accountingdocumenttype.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.


    CHECK exe_simulation_anul_bo_sec( EXPORTING iv_dockey       = iv_dockey
                                                iv_parentdockey = iv_parentdockey
                                      CHANGING  ct_map_id_doc   = ct_map_id_doc
                                              cv_accountingdocumenttype = cv_accdoctype ) IS INITIAL.

    MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
      ENTITY journalentry
      EXECUTE reverse  FROM gta_journalentry_reverse
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
        lv_status_doc  = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey      = ls_so_final_key-accountingdocument.
        lv_companycode = ls_so_final_key-companycode.
        lv_fiscalyear = ls_so_final_key-fiscalyear.

        TRY.
            DATA(lv_parent_key)  = ct_map_id_doc[ 1 ]-parentdocumentkey.
            DATA(lv_parent_type) = ct_map_id_doc[ 1 ]-parentdocumenttype.
          CATCH cx_sy_itab_line_not_found.
        ENDTRY.

      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = gv_doc_type
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      lv_companycode = gta_journalentry_reverse[ 1 ]-companycode.
      lv_fiscalyear = gta_journalentry_reverse[ 1 ]-fiscalyear.
      lv_dockey = gta_journalentry_reverse[ 1 ]-accountingdocument.

      SELECT reversedocument, reversedocumentfiscalyear FROM i_journalentry
        FOR ALL ENTRIES IN @gta_journalentry_reverse
      WHERE companycode = @gta_journalentry_reverse-companycode
      AND fiscalyear = @gta_journalentry_reverse-fiscalyear
      AND accountingdocument = @gta_journalentry_reverse-accountingdocument
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

        IF lv_fiscalyear IS INITIAL.
          TRY.
              lv_fiscalyear = ct_map_id_doc[ 1 ]-fiscalyear.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
        ENDIF.

        IF lv_companycode IS INITIAL.
          TRY.
              lv_companycode = ct_map_id_doc[ 1 ]-companycode.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
        ENDIF.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = gv_doc_type
                                   it_reported    = ls_reported-journalentry
                         CHANGING  ct_map_id_doc  = ct_map_id_doc
                                   cv_status      = lv_status_log ).
      ENDIF.
    ENDIF.

    IF lv_parent_key IS INITIAL.
      TRY.
          lv_parent_key  = ct_map_id_doc[ 1 ]-parentdocumentkey.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_parent_type IS INITIAL.
      TRY.
          lv_parent_type = ct_map_id_doc[ 1 ]-parentdocumenttype.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_fiscalyear IS INITIAL.
      TRY.
          lv_fiscalyear = ct_map_id_doc[ 1 ]-fiscalyear.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_companycode IS INITIAL.
      TRY.
          lv_companycode = ct_map_id_doc[ 1 ]-companycode.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_dockey IS NOT INITIAL.
      MOVE-CORRESPONDING ct_map_id_doc TO lt_docs.
      IF lv_status_doc = me->c_document_status-commit.
        LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<lfs_docs>).
          <lfs_docs>-createdby = lv_byuser.
          <lfs_docs>-createdat = lv_attime.
        ENDLOOP.
      ENDIF.
    ENDIF.

* Ini EXT_OSCUGALD 14.09.2026 - eliminar registros DUMMY de DB al Anular con exito
    IF lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      DATA lt_del_cpid_anul    TYPE TABLE OF zfi_a_intrc_cpid  WITH EMPTY KEY.
      DATA lt_del_cpd_anul     TYPE TABLE OF zfi_a_intrc_cpd   WITH EMPTY KEY.
      DATA lr_documentkey_anul TYPE RANGE OF zfi_a_intrc_cpdl-documentkey.
      DATA lv_del_id_anul      TYPE zfi_a_intrc_cpdl-id.
      DATA lv_del_doctype_anul TYPE zfi_a_intrc_cpdl-documenttype.

      LOOP AT ct_map_id_doc ASSIGNING FIELD-SYMBOL(<fs_dm_anul>)
        WHERE documentkey(5) = 'DUMMY'.
        APPEND VALUE zfi_a_intrc_cpid(
          id           = <fs_dm_anul>-id
          item_id      = <fs_dm_anul>-item_id
          itembasis_id = <fs_dm_anul>-itembasis_id
          itemcalc_id  = <fs_dm_anul>-itemcalc_id
          documenttype = <fs_dm_anul>-documenttype
          documentkey  = <fs_dm_anul>-documentkey
          companycode  = <fs_dm_anul>-companycode
          fiscalyear   = <fs_dm_anul>-fiscalyear
        ) TO lt_del_cpid_anul.
        APPEND VALUE zfi_a_intrc_cpd(
          id           = <fs_dm_anul>-id
          documenttype = <fs_dm_anul>-documenttype
          documentkey  = <fs_dm_anul>-documentkey
          companycode  = <fs_dm_anul>-companycode
          fiscalyear   = <fs_dm_anul>-fiscalyear
        ) TO lt_del_cpd_anul.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_dm_anul>-documentkey ) TO lr_documentkey_anul.
        lv_del_id_anul      = <fs_dm_anul>-id.
        lv_del_doctype_anul = <fs_dm_anul>-documenttype.
      ENDLOOP.

      IF lt_del_cpid_anul IS NOT INITIAL.
        DELETE zfi_a_intrc_cpid FROM TABLE @lt_del_cpid_anul.
      ENDIF.
      IF lt_del_cpd_anul IS NOT INITIAL.
        DELETE zfi_a_intrc_cpd FROM TABLE @lt_del_cpd_anul.
      ENDIF.
      IF lr_documentkey_anul IS NOT INITIAL.
        DELETE FROM zfi_a_intrc_cpdl
          WHERE id           = @lv_del_id_anul
            AND documenttype = @lv_del_doctype_anul
            AND documentkey  IN @lr_documentkey_anul.
      ENDIF.

    ENDIF.
* Fin EXT_OSCUGALD 14.09.2026 - eliminar registros DUMMY de DB

    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_companycode   = lv_companycode
                           iv_fiscalyear    = lv_fiscalyear
                           iv_parentdockey  = lv_parent_key
                           iv_parentdoctype = lv_parent_type
                           iv_doctype       = gv_doc_type
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment  = space
                           its_doc          = lt_docs
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).


  ENDMETHOD.


  METHOD exe_bo_sec.

    DATA lv_dockey      TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status      TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_companycode TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear  TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_log  TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_status_doc  TYPE zfi_a_intrc_cpid-status.
    DATA lv_attime      TYPE zfi_a_intrc_cpid-createdat.
    DATA lv_byuser      TYPE zfi_a_intrc_cpid-createdby.
    DATA lt_docs        TYPE gtsty_doc.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
       ENTITY journalentry
       EXECUTE post FROM gta_journalentry_post
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
        lv_status_doc  = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey      = ls_so_final_key-accountingdocument.
        lv_companycode = ls_so_final_key-companycode.
        lv_fiscalyear  = ls_so_final_key-fiscalyear.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = gv_doc_type
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      ROLLBACK ENTITIES.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      TRY.
          lv_fiscalyear = ct_map_id_doc[ 1 ]-fiscalyear.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      TRY.
          lv_companycode = ct_map_id_doc[ 1 ]-companycode.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = gv_doc_type
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.

    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.

* Ini EXT_OSCUGALD 14.09.2026 - eliminar registros DUMMY de DB al Facturar con exito
    IF lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      DATA lt_del_cpid    TYPE TABLE OF zfi_a_intrc_cpid  WITH EMPTY KEY.
      DATA lt_del_cpd     TYPE TABLE OF zfi_a_intrc_cpd   WITH EMPTY KEY.
      DATA lr_documentkey TYPE RANGE OF zfi_a_intrc_cpdl-documentkey.
      DATA lv_del_id      TYPE zfi_a_intrc_cpdl-id.
      DATA lv_del_doctype TYPE zfi_a_intrc_cpdl-documenttype.

      LOOP AT ct_map_id_doc ASSIGNING FIELD-SYMBOL(<fs_dm_del>)
        WHERE documentkey(5) = 'DUMMY'.
        APPEND VALUE zfi_a_intrc_cpid(
          id           = <fs_dm_del>-id
          item_id      = <fs_dm_del>-item_id
          itembasis_id = <fs_dm_del>-itembasis_id
          itemcalc_id  = <fs_dm_del>-itemcalc_id
          documenttype = <fs_dm_del>-documenttype
          documentkey  = <fs_dm_del>-documentkey
          companycode  = <fs_dm_del>-companycode
          fiscalyear   = <fs_dm_del>-fiscalyear
        ) TO lt_del_cpid.
        APPEND VALUE zfi_a_intrc_cpd(
          id           = <fs_dm_del>-id
          documenttype = <fs_dm_del>-documenttype
          documentkey  = <fs_dm_del>-documentkey
          companycode  = <fs_dm_del>-companycode
          fiscalyear   = <fs_dm_del>-fiscalyear
        ) TO lt_del_cpd.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_dm_del>-documentkey ) TO lr_documentkey.
        lv_del_id      = <fs_dm_del>-id.
        lv_del_doctype = <fs_dm_del>-documenttype.
      ENDLOOP.

      IF lt_del_cpid IS NOT INITIAL.
        DELETE zfi_a_intrc_cpid FROM TABLE @lt_del_cpid.
      ENDIF.
      IF lt_del_cpd IS NOT INITIAL.
        DELETE zfi_a_intrc_cpd FROM TABLE @lt_del_cpd.
      ENDIF.
      IF lr_documentkey IS NOT INITIAL.
        DELETE FROM zfi_a_intrc_cpdl
          WHERE id           = @lv_del_id
            AND documenttype = @lv_del_doctype
            AND documentkey  IN @lr_documentkey.
      ENDIF.

    ENDIF.
* Fin EXT_OSCUGALD 14.09.2026 - eliminar registros DUMMY de DB

    TRY.
        DATA(lv_parent_key)  = ct_map_id_doc[ 1 ]-parentdocumentkey.
        DATA(lv_parent_type) = ct_map_id_doc[ 1 ]-parentdocumenttype.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    IF lv_fiscalyear IS INITIAL.
      TRY.
          lv_fiscalyear = ct_map_id_doc[ 1 ]-fiscalyear.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_companycode IS INITIAL.
      TRY.
          lv_companycode = ct_map_id_doc[ 1 ]-companycode.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.

    IF lv_dockey IS NOT INITIAL.
      MOVE-CORRESPONDING ct_map_id_doc TO lt_docs.
      IF lv_status_doc = me->c_document_status-commit.
        LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<lfs_docs>).
          <lfs_docs>-createdby = lv_byuser.
          <lfs_docs>-createdat = lv_attime.
        ENDLOOP.
      ENDIF.
    ENDIF.

    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_parentdockey           = lv_parent_key
                           iv_parentdoctype          = lv_parent_type
                           iv_doctype                = gv_doc_type
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_accountingdocumenttype = me->gta_journalentry_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = lt_docs
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

  ENDMETHOD.


  METHOD exe_simulation_anul_bo_sec.

    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    DATA ls_je_chk  TYPE STRUCTURE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA lt_je_chk  TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA(ls_je_rev) = gta_journalentry_reverse[ 1 ].
    DATA lt_docs        TYPE gtsty_doc.

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
                                     iv_doctype     = gv_doc_type
                                     it_reported    = ls_reported_chk-journalentry
                           CHANGING  ct_map_id_doc  = ct_map_id_doc
                                     cv_status      = lv_status_log ).


          TRY.
              DATA(lv_parent_key)  = ct_map_id_doc[ 1 ]-parentdocumentkey.
              DATA(lv_parent_type) = ct_map_id_doc[ 1 ]-parentdocumenttype.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          IF lv_status_log EQ 'E'.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          ENDIF.

*            MOVE-CORRESPONDING ct_map_id_doc TO lt_docs.

          mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                                 iv_companycode   = ls_je_rev-companycode
                                 iv_fiscalyear    = ls_je_rev-fiscalyear
                                 iv_doctype       = gv_doc_type
                                 iv_parentdockey  = lv_parent_key
                                 iv_parentdoctype = lv_parent_type
                                 iv_status        = lv_status_doc
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
                                 iv_isadjustment  = space
                                 its_doc          = lt_docs
                                 iv_byuser        = lv_byuser
                                 iv_attime        = lv_attime
                       CHANGING  ct_map_id_doc    = ct_map_id_doc ).
        ENDIF.
      ENDIF.
    ENDIF.
    rv_exist = lv_status_log.
  ENDMETHOD.
ENDCLASS.
