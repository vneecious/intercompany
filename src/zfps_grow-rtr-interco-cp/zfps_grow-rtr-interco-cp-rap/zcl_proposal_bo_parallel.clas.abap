CLASS zcl_proposal_bo_parallel DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: ty_reverse_journal_entries TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse.
    TYPES: ty_post_journal_entries TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.

    DATA: mt_reverse TYPE TABLE FOR ACTION IMPORT i_journalentrytp~reverse.
    DATA: mt_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.
    DATA: mt_docs    TYPE zcl_proposal_bo_abs=>gtsty_doc, " _docs
          mt_docmaps TYPE zcl_proposal_bo_abs=>gtty_doc. " gt_doc_map

    DATA: mv_process         TYPE c READ-ONLY,
          mv_doc_type        TYPE zfi_a_intrc_cpid-documenttype READ-ONLY,
          mv_doc_key         TYPE zfi_a_intrc_cpid-documentkey READ-ONLY, " gv_documentkey
          mv_parent_doc_type TYPE zfi_a_intrc_cpid-parentdocumenttype READ-ONLY,
          mv_parent_doc_key  TYPE zfi_a_intrc_cpid-documentkey READ-ONLY. " gv_parentdockey

    METHODS constructor
      IMPORTING !iv_process        TYPE c
                !iv_documentkey    TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_documenttype   TYPE zfi_a_intrc_cpid-documenttype OPTIONAL
                !iv_parent_dockey  TYPE zfi_a_intrc_cpid-parentdocumentkey OPTIONAL
                !iv_parent_doctype TYPE zfi_a_intrc_cpid-parentdocumentkey OPTIONAL
                !it_doc            TYPE zcl_proposal_bo_abs=>gtsty_doc OPTIONAL
                !it_doc_map        TYPE zcl_proposal_bo_abs=>gtty_doc OPTIONAL
                !it_reverse        TYPE ty_reverse_journal_entries OPTIONAL
                !it_post           TYPE ty_post_journal_entries OPTIONAL.

    INTERFACES if_abap_parallel.

  PROTECTED SECTION.
    METHODS:
      exe_anulation_bo_sec REDEFINITION,
      exe_bo_sec REDEFINITION,
      exe_simulation_bo_sec REDEFINITION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_proposal_bo_parallel IMPLEMENTATION.


  METHOD constructor.
    super->constructor( iv_process           = iv_process
                        iv_documentkey       = iv_documentkey
                        iv_parentdocumentkey = iv_parent_dockey
                        its_doc              = it_doc
                        it_doc_map           = it_doc_map ).
    mv_process = me->gv_process.
    mv_doc_key = iv_documentkey.
    mv_parent_doc_type = iv_parent_doctype.
    mv_parent_doc_key = iv_parent_dockey.
    mv_doc_type = iv_documenttype.

    mt_reverse = it_reverse.
    mt_post = it_post.
    mt_docmaps = it_doc_map.
    mt_docs = it_doc.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE mv_process.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( EXPORTING iv_parentdocument = me->mv_parent_doc_key
                    CHANGING  ct_map_id_doc     = me->mt_docmaps ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_dockey       = me->mv_doc_key
                                        iv_parentdockey = me->mv_parent_doc_key
                              CHANGING  ct_map_id_doc   = me->mt_docmaps ).
      WHEN zcl_boproposal_tools=>gc_simulate_doc.
*        simulate(  ).
    ENDCASE.
    save_log( ).
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
       EXECUTE post FROM mt_post
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
                                 iv_doctype     = mv_doc_type
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      ROLLBACK ENTITIES.
      lv_companycode = me->mt_post[ 1 ]-%param-companycode.
      lv_fiscalyear = me->mt_post[ 1 ]-%param-documentdate(4).
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = mv_doc_type
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.

    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.

    TRY.
        DATA(lv_parent_key)  = ct_map_id_doc[ 1 ]-parentdocumentkey.
        DATA(lv_parent_type) = ct_map_id_doc[ 1 ]-parentdocumenttype.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

*Ini EXT fix: eliminar registros DUMMY de DB cuando el reproceso es exitoso
    IF lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      DATA lt_del_cpid  TYPE TABLE OF zfi_a_intrc_cpid  WITH EMPTY KEY.
      DATA lt_del_cpd   TYPE TABLE OF zfi_a_intrc_cpd   WITH EMPTY KEY.
      DATA lr_documentkey TYPE RANGE OF zfi_a_intrc_cpdl-documentkey.
      DATA lv_del_id      TYPE zfi_a_intrc_cpdl-id.
      DATA lv_del_doctype TYPE zfi_a_intrc_cpdl-documenttype.

      " Acumular claves DUMMY fuera del loop (ATC: evitar DB OP in loop)
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
*        APPEND VALUE zfi_a_intrc_cpdl(
*          id           = <fs_dm_del>-id
*          documenttype = <fs_dm_del>-documenttype
*          documentkey  = <fs_dm_del>-documentkey
*          companycode  = <fs_dm_del>-companycode
*          fiscalyear   = <fs_dm_del>-fiscalyear
*        ) TO lt_del_cpdl.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_dm_del>-documentkey ) TO lr_documentkey.
        lv_del_id      = <fs_dm_del>-id.
        lv_del_doctype = <fs_dm_del>-documenttype.
      ENDLOOP.

      " DELETE fuera del loop — ATC compliant
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
*Fin EXT fix: eliminar registros DUMMY de DB cuando el reproceso es exitoso

    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_parentdockey           = lv_parent_key
                           iv_parentdoctype          = lv_parent_type
                           iv_doctype                = mv_doc_type
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = me->mt_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = lt_docs
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

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

    CHECK exe_simulation_anul_bo_sec( EXPORTING iv_dockey       = iv_dockey
                                              iv_parentdockey = iv_parentdockey
                                    CHANGING  ct_map_id_doc   = ct_map_id_doc
                                              cv_accountingdocumenttype = cv_accdoctype ) IS INITIAL.

    MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
      ENTITY journalentry
      EXECUTE reverse  FROM mt_reverse
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
                                 iv_doctype     = mv_doc_type
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      lv_companycode = mt_reverse[ 1 ]-companycode.
      lv_fiscalyear = mt_reverse[ 1 ]-fiscalyear.
      lv_dockey = mt_reverse[ 1 ]-accountingdocument.

      SELECT reversedocument, reversedocumentfiscalyear FROM i_journalentry
        FOR ALL ENTRIES IN @mt_reverse
      WHERE companycode = @mt_reverse-companycode
      AND fiscalyear = @mt_reverse-fiscalyear
      AND accountingdocument = @mt_reverse-accountingdocument
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
        lv_companycode = me->mt_reverse[ 1 ]-companycode.
        lv_fiscalyear = me->mt_reverse[ 1 ]-fiscalyear.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = mv_doc_type
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

    mt_docs[] = ct_map_id_doc[].
    LOOP AT mt_docs ASSIGNING FIELD-SYMBOL(<lfs_docs>).
      <lfs_docs>-createdby = lv_byuser.
      <lfs_docs>-createdat = lv_attime.
    ENDLOOP.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_companycode   = lv_companycode
                           iv_fiscalyear    = lv_fiscalyear
                           iv_doctype       = mv_doc_type
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = mv_parent_doc_type
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment  = space
                           its_doc          = me->mt_docs
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
  ENDMETHOD.


  METHOD exe_simulation_bo_sec.

    DATA lv_dockey       TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_companycode  TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear   TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    DATA: lt_journalentry_val     TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    DATA lt_docs        TYPE gtsty_doc.


    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    lt_journalentry_val = CORRESPONDING #( mt_post ).

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

    lv_companycode = me->mt_post[ 1 ]-%param-companycode.
    lv_fiscalyear = me->mt_post[ 1 ]-%param-documentdate(4).

    mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                               iv_companycode = lv_companycode
                               iv_fiscalyear  = lv_fiscalyear
                               iv_doctype     = mv_doc_type
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
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-je_sales
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = me->mt_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = lt_docs
*                           its_doc                   = me->gts_doc
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

  ENDMETHOD.
ENDCLASS.
