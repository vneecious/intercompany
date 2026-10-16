CLASS zcl_proposal_bo_ar_parallel DEFINITION
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
          gv_process_ar      TYPE c,
          gv_documentkey_ar  TYPE zfi_a_intrc_cpid-documentkey,
          gv_parentdockey_ar TYPE zfi_a_intrc_cpid-documentkey,
          gts_doc_ar         TYPE gtsty_doc,
          gt_doc_map_ar      TYPE gtty_doc.
    METHODS constructor
      IMPORTING !iv_process           TYPE c
                !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_parentdockey      TYPE zfi_a_intrc_cpid-parentdocumentkey OPTIONAL
                !its_doc              TYPE gtsty_doc OPTIONAL
                !it_doc_map           TYPE gtty_doc OPTIONAL
                !it_je_post           TYPE gtty_post OPTIONAL
                !it_je_rev            TYPE gtty_rev OPTIONAL
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación
                !iv_recipient_cc      TYPE bukrs OPTIONAL
                !iv_recipient_country TYPE land1  OPTIONAL
                !iv_provider_country  TYPE land1  OPTIONAL
                !iv_product           TYPE matnr        OPTIONAL
                !iv_department        TYPE zint_depto   OPTIONAL
                !iv_skip_ar_validate  TYPE abap_bool    OPTIONAL.
*Fin EXT_OSCUGALD
    INTERFACES if_abap_parallel.


  PROTECTED SECTION.
    METHODS:
      exe_bo_sec REDEFINITION,
      exe_anulation_bo_sec REDEFINITION,
      exe_simulation_anul_bo_sec REDEFINITION,
      exe_simulation_bo_sec REDEFINITION.
  PRIVATE SECTION.

*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación
    DATA: gv_recipient_cc      TYPE bukrs,
          gv_recipient_country TYPE land1,
          gv_provider_country  TYPE land1,
          gv_product           TYPE matnr,
          gv_department        TYPE zint_depto,
          gv_skip_ar_validate  TYPE abap_bool.
*Fin EXT_OSCUGALD

ENDCLASS.



CLASS zcl_proposal_bo_ar_parallel IMPLEMENTATION.


  METHOD constructor.
    super->constructor( iv_process           = iv_process
                        iv_documentkey       = iv_documentkey
                        iv_parentdocumentkey = iv_parentdockey
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map ).
    gv_process_ar = me->gv_process.
    gts_doc_ar = me->gts_doc.
    gt_doc_map_ar = me->gt_doc_map.
    IF iv_documentkey IS SUPPLIED.
      gv_documentkey_ar = iv_documentkey.
    ENDIF.
    IF iv_parentdockey IS SUPPLIED.
      gv_parentdockey_ar = iv_parentdockey.
    ENDIF.
    IF it_je_post IS SUPPLIED.
      gta_je_post = it_je_post.
    ENDIF.
    IF it_je_rev IS SUPPLIED.
      gta_je_rev = it_je_rev.
    ENDIF.
*    IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ).
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación
    IF iv_recipient_cc IS SUPPLIED.
      gv_recipient_cc = iv_recipient_cc.
    ENDIF.
    IF iv_recipient_country IS SUPPLIED.
      gv_recipient_country = iv_recipient_country.
    ENDIF.
    IF iv_provider_country IS SUPPLIED.
      gv_provider_country = iv_provider_country.
    ENDIF.
    IF iv_product IS SUPPLIED.
      gv_product = iv_product.
    ENDIF.
    IF iv_department IS SUPPLIED.
      gv_department = iv_department.
    ENDIF.
    IF iv_skip_ar_validate IS SUPPLIED.
      gv_skip_ar_validate = iv_skip_ar_validate.
    ENDIF.
*Fin EXT_OSCUGALD
*    ENDIF.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE me->gv_process_ar.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_ar ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_dockey       = me->gv_documentkey_ar
                                        iv_parentdockey = gv_parentdockey_ar
                              CHANGING  ct_map_id_doc   = me->gt_doc_map_ar ).
      WHEN zcl_boproposal_tools=>gc_simulate_doc.
        exe_simulation_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_ar ).
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
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
        lv_companycode = me->gta_je_rev[ 1 ]-companycode.
        lv_fiscalyear = me->gta_je_rev[ 1 ]-fiscalyear.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
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

    gts_doc_ar[] = ct_map_id_doc[].
    LOOP AT gts_doc_ar ASSIGNING FIELD-SYMBOL(<lfs_docs>).
      <lfs_docs>-createdby = lv_byuser.
      <lfs_docs>-createdat = lv_attime.
    ENDLOOP.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_companycode   = lv_companycode
                           iv_fiscalyear    = lv_fiscalyear
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-je_sales
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_ar
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

    MODIFY ENTITIES OF  i_journalentrytp PRIVILEGED
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_sales
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

      COMMIT ENTITIES END.

    ELSE.
      ROLLBACK ENTITIES.
      lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
      lv_fiscalyear = me->gta_je_post[ 1 ]-%param-documentdate(4).
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_sales
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
*    IF gts_doc_ar IS INITIAL.
*      gts_doc_ar[] = ct_map_id_doc[].
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
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-je_sales
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_ar
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

    READ ENTITIES OF i_journalentrytp PRIVILEGED
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
                                     iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                                     it_reported    = ls_reported_chk-journalentry
                           CHANGING  ct_map_id_doc  = ct_map_id_doc
                                     cv_status      = lv_status_log ).

          IF lv_status_log EQ 'E'.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          ENDIF.
*          IF gts_doc_AR IS INITIAL.
          gts_doc_ar[] = ct_map_id_doc[].
*          ENDIF.
          mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                                 iv_companycode   = ls_je_rev-companycode
                                 iv_fiscalyear    = ls_je_rev-fiscalyear
                                 iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                                 iv_parentdockey  = iv_parentdockey
                                 iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-je_sales
                                 iv_status        = lv_status_doc
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-financial
                                 iv_isadjustment  = space
                                 its_doc          = me->gts_doc_ar
                                 iv_byuser        = lv_byuser
                                 iv_attime        = lv_attime
                       CHANGING  ct_map_id_doc    = ct_map_id_doc ).
        ENDIF.
      ENDIF.
    ENDIF.
    rv_exist = lv_status_log.
  ENDMETHOD.


  METHOD exe_simulation_bo_sec.
* INI_MOD EXT_FRGALLEG 14.08.2026
    CONSTANTS lc_tvar_round TYPE zi_tvarvc-name VALUE 'ZWT_GLACCOUNT_REDONDEO'.
    DATA lv_round_acct TYPE hkont.
* FIN_MOD EXT_FRGALLEG 14.08.2026
    DATA lv_dockey       TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_companycode  TYPE zfi_a_intrc_cpid-companycode.
    DATA lv_fiscalyear   TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    DATA: lt_journalentry_val     TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    " --- Validación del AR ---
*    IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ) AND gv_skip_ar_validate = abap_true.
    IF gv_skip_ar_validate = abap_true.
*Ini EXT_OSCUGALD - Skip AR validate: el error pre-validate ya fue registrado en mapping_bo_sec
      " El AR ya tiene status 'E' por CECO/glaccount vacío. No repetir validate para evitar
      " sobrescribir ese status. Solo ejecutamos la validación del documento hijo BR.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_error.
      lv_status_log = zcl_proposal_bo_abs=>c_document_status-simulated_error.
*Fin EXT_OSCUGALD
    ELSE.

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

      lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
      lv_fiscalyear = me->gta_je_post[ 1 ]-%param-documentdate(4).

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_sales
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
    ENDIF.
*    IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ).
*Ini EXT_OSCUGALD - Validación anticipada de CECOs Brasil en simulación
    " Aplica INDEPENDIENTEMENTE del resultado AR (condición simulated_ok eliminada).
    " Replica la lógica exacta de ZCL_PROPOSAL_BO_AR_TAXBR.MAPPING_BO_SEC:
    "   1. calculate_taxes_net con los GL items del AR → obtiene GL items de impuesto con glaccount
    "   2. get_cc_code(sales_tax, iv_cuenta=glaccount) por cada ítem → mismo CECO que TAXBR real
    "   3. validate del JE sintético en la sociedad receptora
    " Se validan TAXBR (contingency=false) y TAXBRC (contingency=true) por separado.
    IF gv_recipient_cc IS NOT INITIAL AND
       gv_provider_country = 'BR'     AND gv_recipient_country = 'BR' AND
       gv_product IS NOT INITIAL.

      DATA(lv_postingdate) = me->gta_je_post[ 1 ]-%param-postingdate.
      DATA(lv_docdate)     = me->gta_je_post[ 1 ]-%param-documentdate.
      DATA(lt_ar_glitems)  = me->gta_je_post[ 1 ]-%param-_glitems.
      DATA(lo_brf_br)      = NEW zcl_interco_brf_wht( ).

      " Iterar sobre los dos escenarios: TAXBR y TAXBRC
      TYPES: BEGIN OF ty_br_scenario,
               contingency TYPE abap_bool,
               doctype     TYPE zfi_a_intrc_cpid-documenttype,
             END OF ty_br_scenario.
      DATA lt_scenarios TYPE TABLE OF ty_br_scenario WITH EMPTY KEY.
      lt_scenarios = VALUE #(
        ( contingency = abap_false
          doctype     = zcl_proposal_bo_abs=>c_document_type-taxbr_sales )
        ( contingency = abap_true
          doctype     = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_contingency ) ).

      DATA lv_br_doc_status TYPE zfi_a_intrc_cpid-status.
      DATA lt_map_id_doc_br LIKE ct_map_id_doc.
      DATA lv_dummy_key_br  TYPE zfi_a_intrc_cpid-documentkey.

* INI_MOD EXT_FRGALLEG 14.08.2026
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = @lc_tvar_round
        INTO @lv_round_acct.
* FIN_MOD EXT_FRGALLEG 14.08.2026
      LOOP AT lt_scenarios INTO DATA(ls_scenario).

        " 1. Instanciar zcl_interco_taxbr — idéntico a ZCL_PROPOSAL_BO_AR_TAXBR.MAPPING_BO_SEC
        TRY.
            DATA(lo_taxbr) = NEW zcl_interco_taxbr(
              i_doctype              = zcl_interco_taxbr=>co_doctype-sales
              i_providercompanycode  = lv_companycode
              i_recipientcompanycode = gv_recipient_cc
              i_product              = gv_product
              i_department           = gv_department
              i_valid_at             = lv_postingdate
              i_contingency          = ls_scenario-contingency ).

            " 2. Calcular GL items de impuesto — misma entrada que usaría TAXBR real
            lo_taxbr->calculate_taxes_net(
              EXPORTING it_glitems = lt_ar_glitems
              IMPORTING et_glitems = DATA(lt_tax_glitems) ).

          CATCH zcx_interco_taxbr.
            CONTINUE.   " Sin configuración para este escenario → saltar
        ENDTRY.

        CHECK lt_tax_glitems IS NOT INITIAL.
* INI_MOD EXT_FRGALLEG 14.08.2026
*        DELETE lt_tax_glitems WHERE glaccount = '780010'
*                                   OR glaccount = '0000780010'.
        IF lv_round_acct IS NOT INITIAL.
          DELETE lt_tax_glitems WHERE glaccount = lv_round_acct.
        ENDIF.
* FIN_MOD EXT_FRGALLEG 14.08.2026
        " 3. Determinar CECO por cada GL item — igual que TAXBR.MAPPING_BO_SEC
        " DO...TIMES en lugar de LOOP AT para evitar finding ATC de loop anidado
        DO lines( lt_tax_glitems ) TIMES.
          DATA(lr_tax_gl) = REF #( lt_tax_glitems[ sy-index ] ).
          DATA(lv_tax_cc) = lo_brf_br->get_cc_code(
            iv_tipo_doc = lo_brf_br->co_with_doctype-sales_tax
            iv_cuenta   = lr_tax_gl->glaccount ).
          IF lv_tax_cc IS NOT INITIAL.
            DATA(lv_tax_cc_len) = strlen( lv_tax_cc ).
            lr_tax_gl->costcenter(lv_tax_cc_len) = lv_tax_cc.
          ELSE.
            CLEAR lr_tax_gl->costcenter.
          ENDIF.
        ENDDO.

* Ini EXT_OSCUGALD 03.09.2026 - Fix F5727: agrupamiento previo a validate en simulación (paridad con MAPPING_BO_SEC)
        IF zcl_interco_taxbr=>use_new_aggregation( ) = abap_true.
          zcl_interco_taxbr=>aggregate_glitems( CHANGING ct_glitems = lt_tax_glitems ).
        ENDIF.
* Fin EXT_OSCUGALD 03.09.2026 - Fix F5727: agrupamiento previo a validate en simulación (paridad con MAPPING_BO_SEC)

        " 4. Construir JE sintético en la sociedad receptora (Brasil)
        DATA lt_br_je_val TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
        APPEND INITIAL LINE TO lt_br_je_val REFERENCE INTO DATA(lr_br_je).
        lr_br_je->%param-companycode            = lv_companycode.
        lr_br_je->%param-accountingdocumenttype = 'CH'.
        lr_br_je->%param-postingdate            = lv_postingdate.
        lr_br_je->%param-documentdate           = lv_docdate.
        lr_br_je->%param-createdbyuser          = sy-uname.
        lr_br_je->%param-_glitems              = lt_tax_glitems.

        " 5. Ejecutar validate — misma mecánica que la validación del AR
        READ ENTITIES OF i_journalentrytp
          ENTITY journalentry
          EXECUTE validate FROM lt_br_je_val
          RESULT DATA(lt_br_result)
          FAILED DATA(ls_br_failed)
          REPORTED DATA(ls_br_reported).

        " 6. Si hay errores de CECO Brasil, reportarlos con el doctype correcto (TAXBR o TAXBRC)
        IF ls_br_failed-journalentry IS NOT INITIAL.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_error.
          DATA(lv_br_status_log) = zcl_proposal_bo_abs=>c_document_status-simulated_error.

          mapping_doc_log(
            EXPORTING
              iv_dockey      = lv_dockey
              iv_companycode = lv_companycode
              iv_fiscalyear  = lv_fiscalyear
              iv_doctype     = ls_scenario-doctype   " taxbr_sales o taxbr_sales_contingency
              it_reported    = ls_br_reported-journalentry
            CHANGING
              ct_map_id_doc  = ct_map_id_doc
              cv_status      = lv_br_status_log ).
        ENDIF.

*Ini EXT_OSCUGALD - Registrar documento Brasil en CPID/CPD
        " Determinar status final del documento Brasil
        IF ls_br_failed-journalentry IS NOT INITIAL.
          lv_br_doc_status = zcl_proposal_bo_abs=>c_document_status-simulated_error.
        ELSE.
          lv_br_doc_status = zcl_proposal_bo_abs=>c_document_status-simulated_ok.
        ENDIF.

        " Clave DUMMY específica Brasil: misma convención que TAXBR real
        lv_dummy_key_br = |DUMMY{ lv_companycode }{ gv_product }{ ls_scenario-doctype }|.

        " Construir doc_map para el documento Brasil (sin LOOP anidado)
        lt_map_id_doc_br = VALUE #( FOR ls_map_ar_br IN ct_map_id_doc
                             ( id                 = ls_map_ar_br-id
                               item_id            = ls_map_ar_br-item_id
                               itembasis_id       = ls_map_ar_br-itembasis_id
                               itemcalc_id        = ls_map_ar_br-itemcalc_id
                               documenttype       = ls_scenario-doctype
                               documentkey        = lv_dummy_key_br
                               companycode        = gv_recipient_cc
                               fiscalyear         = lv_fiscalyear
                               parentdocumentkey  = ls_map_ar_br-documentkey
                               parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
                               parentcompanycode  = lv_companycode
                               parentfiscalyear   = lv_fiscalyear ) ).

        " Registrar el documento Brasil en CPID/CPD
        mapping_doc(
          EXPORTING
            iv_dockey                 = lv_dummy_key_br
            iv_companycode            = gv_recipient_cc
            iv_fiscalyear             = lv_fiscalyear
            iv_doctype                = ls_scenario-doctype
            iv_status                 = lv_br_doc_status
            iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
            iv_accountingdocumenttype = 'CH'
            iv_isadjustment           = space
            iv_byuser                 = lv_byuser
            iv_attime                 = lv_attime
          CHANGING
            ct_map_id_doc             = lt_map_id_doc_br ).
*Fin EXT_OSCUGALD - Registrar documento Brasil en CPID/CPD

        CLEAR: lt_tax_glitems, lt_br_je_val.
      ENDLOOP.

    ENDIF.
*Fin EXT_OSCUGALD - Validación anticipada de CECOs Brasil en simulación
*    ENDIF.

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
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_ar
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

  ENDMETHOD.
ENDCLASS.
