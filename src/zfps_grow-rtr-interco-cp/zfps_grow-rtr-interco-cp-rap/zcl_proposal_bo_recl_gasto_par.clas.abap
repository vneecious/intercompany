CLASS zcl_proposal_bo_recl_gasto_par DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gtty_post    TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
           gtty_rev     TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
           gsty_post    TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post,
           gsty_glitems TYPE LINE OF gsty_post-%param-_glitems.

    DATA: gta_je_post        TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,
          gta_je_rev         TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse,
          gv_process_rg      TYPE c,
          gv_dockey_rg       TYPE zfi_a_intrc_cpid-documentkey,
          gv_parentdockey_rg TYPE zfi_a_intrc_cpd-parentdocumentkey,
          gts_doc_rg         TYPE gtsty_doc,
          gt_doc_map_rg      TYPE gtty_doc.
    METHODS constructor
      IMPORTING !iv_process      TYPE c
                !iv_documentkey  TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_parentdockey TYPE zfi_a_intrc_cpd-parentdocumentkey OPTIONAL
                !its_doc         TYPE gtsty_doc OPTIONAL
                !it_doc_map      TYPE gtty_doc
                !it_je_post      TYPE gtty_post OPTIONAL
                !it_je_rev       TYPE gtty_rev OPTIONAL.
    INTERFACES if_abap_parallel.
  PROTECTED SECTION.
    METHODS:
      exe_bo_sec REDEFINITION,
      exe_anulation_bo_sec REDEFINITION,
      exe_simulation_anul_bo_sec REDEFINITION,
      exe_simulation_bo_sec REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_recl_gasto_par IMPLEMENTATION.


  METHOD constructor.
    super->constructor( iv_process           = iv_process
                        iv_documentkey       = iv_documentkey
                        iv_parentdocumentkey = iv_parentdockey
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map ).
    gv_process_rg = iv_process.
    gts_doc_rg = me->gts_doc.
    gt_doc_map_rg = it_doc_map.
    IF iv_documentkey IS SUPPLIED.
      gv_dockey_rg = iv_documentkey.
    ENDIF.
    IF iv_parentdockey IS SUPPLIED.
      gv_parentdockey_rg = iv_parentdockey.
    ENDIF.
    IF it_je_post IS SUPPLIED.
      gta_je_post = it_je_post.
    ENDIF.
    IF it_je_rev IS SUPPLIED.
      gta_je_rev = it_je_rev.
    ENDIF.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE gv_process_rg.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( CHANGING ct_map_id_doc = gt_doc_map_rg ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_dockey       = gv_dockey_rg
                                        iv_parentdockey = gv_parentdockey_rg
                              CHANGING  ct_map_id_doc   = gt_doc_map_rg ).
      WHEN zcl_boproposal_tools=>gc_simulate_doc.
        exe_simulation_bo_sec( CHANGING ct_map_id_doc = gt_doc_map_rg ).
    ENDCASE.
    save_log( ).
  ENDMETHOD.


  METHOD exe_anulation_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpd-documentkey.
    DATA: lv_status_doc TYPE zfi_a_intrc_cpid-status,
          lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_expensrec
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
                                   iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_expensrec
                                   it_reported    = ls_reported-journalentry
                         CHANGING  ct_map_id_doc  = ct_map_id_doc
                                   cv_status      = lv_status_log ).
      ENDIF.
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
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

    gts_doc_rg[] = ct_map_id_doc[].
    LOOP AT gts_doc_rg ASSIGNING FIELD-SYMBOL(<lfs_docs>).
      <lfs_docs>-createdby = lv_byuser.
      <lfs_docs>-createdat = lv_attime.
    ENDLOOP.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_companycode   = lv_companycode
                           iv_fiscalyear    = lv_fiscalyear
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_expensrec
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_rg
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
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.
    lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
    lv_fiscalyear = me->gta_je_post[ 1 ]-%param-documentdate(4).

    MODIFY ENTITIES OF i_journalentrytp
        ENTITY journalentry
        EXECUTE post FROM gta_je_post
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-expensreclassif
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
*    IF gts_doc_rg IS INITIAL.
*      gts_doc_rg[] = ct_map_id_doc[].
*    ENDIF.

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

    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_rg
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
                                     iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_expensrec
                                     it_reported    = ls_reported_chk-journalentry
                           CHANGING  ct_map_id_doc  = ct_map_id_doc
                                     cv_status      = lv_status_log ).

          IF lv_status_log EQ 'E'.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          ENDIF.
*          IF gts_doc_rg IS INITIAL.
          gts_doc_rg[] = ct_map_id_doc[].
*          ENDIF.
          mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                                 iv_companycode   = ls_je_rev-companycode
                                 iv_fiscalyear    = ls_je_rev-fiscalyear
                                 iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_expensrec
                                 iv_parentdockey  = iv_parentdockey
                                 iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                                 iv_status        = lv_status_doc
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-reclasification
                                 iv_isadjustment  = space
                                 its_doc          = me->gts_doc_rg
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
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    DATA lt_journalentry_val     TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
    lv_fiscalyear = me->gta_je_post[ 1 ]-%param-documentdate(4).

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
                               iv_doctype     = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                               it_reported    = ls_reported-journalentry
                     CHANGING  ct_map_id_doc  = ct_map_id_doc
                               cv_status      = lv_status_log ).

* Ini EXT_OSCUGALD 14.09.2026 - eliminar mensajes DUMMY de log al Simular OK
    IF lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_ok.

      DATA lr_documentkey_sim TYPE RANGE OF zfi_a_intrc_cpdl-documentkey.
      DATA lv_del_id_sim      TYPE zfi_a_intrc_cpdl-id.
      DATA lv_del_doctype_sim TYPE zfi_a_intrc_cpdl-documenttype.

      LOOP AT ct_map_id_doc ASSIGNING FIELD-SYMBOL(<fs_dm_sim>)
        WHERE documentkey(5) = 'DUMMY'.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_dm_sim>-documentkey ) TO lr_documentkey_sim.
        lv_del_id_sim      = <fs_dm_sim>-id.
        lv_del_doctype_sim = <fs_dm_sim>-documenttype.
      ENDLOOP.

      IF lr_documentkey_sim IS NOT INITIAL.
        DELETE FROM zfi_a_intrc_cpdl
          WHERE id           = @lv_del_id_sim
            AND documenttype = @lv_del_doctype_sim
            AND documentkey  IN @lr_documentkey_sim.
      ENDIF.

    ENDIF.
* Fin EXT_OSCUGALD 14.09.2026 - eliminar mensajes DUMMY de log

    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-reclasification
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_rg
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

  ENDMETHOD.
ENDCLASS.
