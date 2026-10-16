CLASS zcl_proposal_bo_ap_parallel DEFINITION
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
          gv_process_ap      TYPE c,
          gv_documentkey_ap  TYPE zfi_a_intrc_cpid-documentkey,
          gv_parentdockey_ap TYPE zfi_a_intrc_cpid-documentkey,
          gts_doc_ap         TYPE gtsty_doc,
          gt_doc_map_ap      TYPE gtty_doc.
    METHODS constructor
      IMPORTING !iv_process           TYPE c
                !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_parentdockey      TYPE zfi_a_intrc_cpid-parentdocumentkey OPTIONAL
                !its_doc              TYPE gtsty_doc OPTIONAL
                !it_doc_map           TYPE gtty_doc OPTIONAL
                !it_je_post           TYPE gtty_post OPTIONAL
                !it_je_rev            TYPE gtty_rev OPTIONAL
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación AP
                !iv_provider_cc       TYPE bukrs      OPTIONAL
                !iv_provider_country  TYPE land1      OPTIONAL
                !iv_recipient_country TYPE land1     OPTIONAL
                !iv_product           TYPE matnr      OPTIONAL
                !iv_department        TYPE zint_depto OPTIONAL.
*Fin EXT_OSCUGALD

    INTERFACES if_abap_parallel.
  PROTECTED     SECTION.
    METHODS:
      exe_bo_sec REDEFINITION,
      exe_anulation_bo_sec REDEFINITION,
      exe_simulation_anul_bo_sec REDEFINITION,
      exe_simulation_bo_sec REDEFINITION.
  PRIVATE SECTION.
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación AP
    DATA: gv_provider_cc       TYPE bukrs,
          gv_provider_country  TYPE land1,
          gv_recipient_country TYPE land1,
          gv_product           TYPE matnr,
          gv_department        TYPE zint_depto.
*Fin EXT_OSCUGALD
ENDCLASS.



CLASS zcl_proposal_bo_ap_parallel IMPLEMENTATION.


  METHOD constructor.
    super->constructor( iv_process           = iv_process
                        iv_documentkey       = iv_documentkey
                        iv_parentdocumentkey = iv_parentdockey
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map ).
    gv_process_ap = me->gv_process.
    gts_doc_ap = me->gts_doc.
    gt_doc_map_ap = me->gt_doc_map.
    IF iv_documentkey IS SUPPLIED.
      gv_documentkey_ap = iv_documentkey.
    ENDIF.
    IF iv_parentdockey IS SUPPLIED.
      gv_parentdockey_ap = iv_parentdockey.
    ENDIF.
    IF it_je_post IS SUPPLIED.
      gta_je_post = it_je_post.
    ENDIF.
    IF it_je_rev IS SUPPLIED.
      gta_je_rev = it_je_rev.
    ENDIF.
*    IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ).
*Ini EXT_OSCUGALD - Validación CECOs Brasil en simulación AP
    IF iv_provider_cc IS SUPPLIED.
      gv_provider_cc = iv_provider_cc.
    ENDIF.
    IF iv_provider_country IS SUPPLIED.
      gv_provider_country = iv_provider_country.
    ENDIF.
    IF iv_recipient_country IS SUPPLIED.
      gv_recipient_country = iv_recipient_country.
    ENDIF.
    IF iv_product IS SUPPLIED.
      gv_product = iv_product.
    ENDIF.
    IF iv_department IS SUPPLIED.
      gv_department = iv_department.
    ENDIF.
*Fin EXT_OSCUGALD
*    ENDIF.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE me->gv_process_ap.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_ap ).
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_dockey       = me->gv_documentkey_ap
                                        iv_parentdockey = gv_parentdockey_ap
                              CHANGING  ct_map_id_doc   = me->gt_doc_map_ap ).
      WHEN zcl_boproposal_tools=>gc_simulate_doc.
        exe_simulation_bo_sec( CHANGING ct_map_id_doc = me->gt_doc_map_ap ).
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                                 it_reported    = ls_save_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
      COMMIT ENTITIES END.

    ELSE.
      ROLLBACK ENTITIES.
      lv_companycode = me->gta_je_rev[ 1 ]-companycode.
      lv_fiscalyear = me->gta_je_rev[ 1 ]-fiscalyear.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).
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

    gts_doc_ap[] = gt_doc_map_ap[].
    LOOP AT gts_doc_ap ASSIGNING FIELD-SYMBOL(<lfs_docs>).
      <lfs_docs>-createdby = lv_byuser.
      <lfs_docs>-createdat = lv_attime.
    ENDLOOP.
    mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                           iv_companycode            = lv_companycode
                           iv_fiscalyear             = lv_fiscalyear
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                           iv_parentdockey           = iv_parentdockey
                           iv_parentdoctype          = zcl_proposal_bo_abs=>c_document_type-je_purchase
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = cv_accdoctype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_ap
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.
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

    MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_purchase
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
                                 iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                 it_reported    = ls_reported-journalentry
                       CHANGING  ct_map_id_doc  = ct_map_id_doc
                                 cv_status      = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
*    IF gts_doc_AP IS INITIAL.
*      gts_doc_AP[] = gt_doc_map_ap[].
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
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-je_purchase
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_ap
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

          SELECT reversedocument, reversedocumentfiscalyear FROM i_journalentry
            FOR ALL ENTRIES IN @gta_je_rev
              WHERE companycode = @gta_je_rev-companycode
              AND fiscalyear = @gta_je_rev-fiscalyear
              AND accountingdocument = @gta_je_rev-accountingdocument
              AND reversedocument IS NOT INITIAL
              INTO TABLE @DATA(lt_manual_reversed_documents).

          IF sy-subrc = 0.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
            ls_reported-journalentry = VALUE #( ( %msg = new_message_with_text(
                                                        severity = if_abap_behv_message=>severity-success
                                                        text     = 'Documento anulado manualmente'
                                                      ) ) ).
            mapping_doc_log( EXPORTING iv_dockey      = CONV #( ls_je_rev-accountingdocument )
                                       iv_companycode = ls_je_rev-companycode
                                       iv_fiscalyear  = ls_je_rev-fiscalyear
                                       iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_sales
                                       it_reported    = ls_reported-journalentry
                             CHANGING  ct_map_id_doc  = ct_map_id_doc
                                       cv_status      = lv_status_log ).
          ELSE.
            mapping_doc_log( EXPORTING "iv_dockey     = CONV #( ls_je_rev-accountingdocument )
                                       iv_companycode = ls_je_rev-companycode
                                       iv_fiscalyear  = ls_je_rev-fiscalyear
                                       iv_doctype     = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                                       it_reported    = ls_reported_chk-journalentry
                             CHANGING  ct_map_id_doc  = ct_map_id_doc
                                       cv_status      = lv_status_log ).
          ENDIF.

          IF lv_status_log EQ 'E'.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          ENDIF.
*          IF gts_doc_AP IS INITIAL.
          gts_doc_ap[] = gt_doc_map_ap[].
*          ENDIF.
          mapping_doc( EXPORTING "iv_dockey        = CONV #( ls_je_rev-accountingdocument )
                                 iv_companycode   = ls_je_rev-companycode
                                 iv_fiscalyear    = ls_je_rev-fiscalyear
                                 iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                                 iv_parentdockey  = iv_parentdockey
                                 iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                 iv_status        = lv_status_doc
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-financial
                                 iv_isadjustment  = space
                                 its_doc          = me->gts_doc_ap
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
    DATA lv_status_doc   TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log   TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser       TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime       TYPE zfi_a_intrc_cpid-createdat.
    DATA: lt_journalentry_val TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    lv_companycode = me->gta_je_post[ 1 ]-%param-companycode.
    lv_fiscalyear  = me->gta_je_post[ 1 ]-%param-documentdate(4).

    IF me->gt_intrc_cpid IS NOT INITIAL. "EXT_OSCUGALD
      lv_dockey = me->gt_intrc_cpid[ 1 ]-documentkey.
    ENDIF.

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
                               iv_doctype     = zcl_proposal_bo_abs=>c_document_type-je_purchase
                               it_reported    = ls_reported-journalentry
                     CHANGING  ct_map_id_doc  = ct_map_id_doc
                               cv_status      = lv_status_log ).

*    IF ( sy-uname = 'EXT_OSCUGALD' OR sy-uname = 'EXT_NIMINGUI' ).
*Ini EXT_OSCUGALD - Validación anticipada de CECOs Brasil en simulación AP
    " Replica la lógica de ZCL_PROPOSAL_BO_AP_TAXBR.MAPPING_BO_SEC:
    "   1. calculate_taxes_net con los GL items del AP → GL items de impuesto
    "   2. get_cc_code(purchases_tax, glaccount) → mismo CECO que TAXBR real
    "   3. validate JE sintético en la sociedad del AP (= recipient = comprador)
    " Se validan TAXBR_PURCHASES (405) y TAXBRC_PURCHASES (406) por separado.
    IF gv_provider_cc IS NOT INITIAL AND
       gv_provider_country = 'BR' AND gv_recipient_country = 'BR' AND
       gv_product IS NOT INITIAL.

      DATA(lv_postingdate_ap) = me->gta_je_post[ 1 ]-%param-postingdate.
      DATA(lv_docdate_ap)     = me->gta_je_post[ 1 ]-%param-documentdate.
      DATA(lt_ap_glitems)     = me->gta_je_post[ 1 ]-%param-_glitems.
      DATA(lo_brf_br)         = NEW zcl_interco_brf_wht( ).

      " Iterar sobre los dos escenarios: TAXBR_PURCHASES y TAXBRC_PURCHASES
      TYPES: BEGIN OF ty_br_scenario_ap,
               contingency TYPE abap_bool,
               doctype     TYPE zfi_a_intrc_cpid-documenttype,
             END OF ty_br_scenario_ap.
      DATA lt_scenarios_ap TYPE TABLE OF ty_br_scenario_ap WITH EMPTY KEY.
      lt_scenarios_ap = VALUE #(
        ( contingency = abap_false
          doctype     = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases )
        ( contingency = abap_true
          doctype     = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_contingency ) ).

      DATA lv_br_doc_status_ap TYPE zfi_a_intrc_cpid-status.
      DATA lt_map_id_doc_br_ap LIKE ct_map_id_doc.
      DATA lv_dummy_key_br_ap  TYPE zfi_a_intrc_cpid-documentkey.

* INI_MOD EXT_FRGALLEG 14.08.2026
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = @lc_tvar_round
        INTO @lv_round_acct.
* FIN_MOD EXT_FRGALLEG 14.08.2026

      LOOP AT lt_scenarios_ap INTO DATA(ls_scenario_ap).

        " 1. Instanciar zcl_interco_taxbr — igual que ZCL_PROPOSAL_BO_AP_TAXBR.MAPPING_BO_SEC
        "    En AP: lv_companycode = AP JE company = recipient (comprador)
        "           gv_provider_cc = proveedor (vendedor), pasado desde mapping_bo_sec
        TRY.
            DATA(lo_taxbr_ap) = NEW zcl_interco_taxbr(
              i_doctype              = zcl_interco_taxbr=>co_doctype-purchase
              i_providercompanycode  = gv_provider_cc
              i_recipientcompanycode = lv_companycode
              i_product              = gv_product
              i_department           = gv_department
              i_valid_at             = lv_postingdate_ap
              i_skip_glaccount2      = abap_true
              i_contingency          = ls_scenario_ap-contingency ).

*              2. sin iv_cuenta — alineado con ZCL_PROPOSAL_BO_AP_TAXBR.MAPPING_BO_SEC
            DATA lt_ap_glitems_cc LIKE lt_ap_glitems.
            lt_ap_glitems_cc = lt_ap_glitems.
* INI_MOD EXT_FRGALLEG 14.08.2026
*            DELETE lt_ap_glitems_cc WHERE glaccount = '780010'
*                                       OR glaccount = '0000780010'.
            IF lv_round_acct IS INITIAL.
              DELETE lt_ap_glitems_cc WHERE glaccount = lv_round_acct.
            ENDIF.
* FIN_MOD EXT_FRGALLEG 14.08.2026
*Ini FIX EXT_OSCUGALD - Alinear partnercompany con ZCL_PROPOSAL_BO_AP_TAXBR.mapping_bo_sec
            DO lines( lt_ap_glitems_cc ) TIMES.
              DATA(lr_fix_pc) = REF #( lt_ap_glitems_cc[ sy-index ] ).
              IF lr_fix_pc->partnercompany IS INITIAL.
                lr_fix_pc->partnercompany = gv_provider_cc.
              ENDIF.
            ENDDO.
*Fin FIX EXT_OSCUGALD
            DO lines( lt_ap_glitems_cc ) TIMES.
              DATA(lr_ap_gl_cc) = REF #( lt_ap_glitems_cc[ sy-index ] ).
              DATA(lv_ap_cc) = lo_brf_br->get_cc_code( iv_tipo_doc = lo_brf_br->co_with_doctype-purchases_tax ).
              IF lv_ap_cc IS NOT INITIAL.
                DATA(lv_ap_cc_len) = strlen( lv_ap_cc ).
                lr_ap_gl_cc->costcenter(lv_ap_cc_len) = lv_ap_cc.
              ELSE.
                CLEAR lr_ap_gl_cc->costcenter.
              ENDIF.
            ENDDO.

            lo_taxbr_ap->calculate_taxes_net(
              EXPORTING
                it_glitems = lt_ap_glitems_cc
              IMPORTING
                et_glitems = DATA(lt_tax_glitems_ap) ).


          CATCH zcx_interco_taxbr.
            CONTINUE.
        ENDTRY.

        CHECK lt_tax_glitems_ap IS NOT INITIAL.

* Ini EXT_OSCUGALD 03.09.2026 - Fix F5727: agrupamiento previo a validate en simulación (paridad con MAPPING_BO_SEC)
        IF zcl_interco_taxbr=>use_new_aggregation( ) = abap_true.
          zcl_interco_taxbr=>aggregate_glitems( CHANGING ct_glitems = lt_tax_glitems_ap ).
        ENDIF.
* Fin EXT_OSCUGALD 03.09.2026 - Fix F5727: agrupamiento previo a validate en simulación (paridad con MAPPING_BO_SEC)

        " 3. Construir JE sintético en la sociedad del AP (recipient = comprador)
        DATA lt_br_je_val_ap TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
        APPEND INITIAL LINE TO lt_br_je_val_ap REFERENCE INTO DATA(lr_br_je_ap).
        lr_br_je_ap->%param-companycode            = lv_companycode.
        lr_br_je_ap->%param-accountingdocumenttype = 'CH'.
        lr_br_je_ap->%param-postingdate            = lv_postingdate_ap.
        lr_br_je_ap->%param-documentdate           = lv_docdate_ap.
        lr_br_je_ap->%param-createdbyuser          = sy-uname.
        lr_br_je_ap->%param-_glitems               = lt_tax_glitems_ap.

        " 4. Ejecutar validate
        READ ENTITIES OF i_journalentrytp
          ENTITY journalentry
          EXECUTE validate FROM lt_br_je_val_ap
          RESULT DATA(lt_br_result_ap)
          FAILED DATA(ls_br_failed_ap)
          REPORTED DATA(ls_br_reported_ap).

        " 5. Si hay errores de CECO Brasil, reportarlos con el doctype correcto
        IF ls_br_failed_ap-journalentry IS NOT INITIAL.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-simulated_error.
          DATA(lv_br_status_log_ap) = zcl_proposal_bo_abs=>c_document_status-simulated_error.

          mapping_doc_log(
            EXPORTING
              iv_dockey      = lv_dockey
              iv_companycode = lv_companycode
              iv_fiscalyear  = lv_fiscalyear
              iv_doctype     = ls_scenario_ap-doctype
              it_reported    = ls_br_reported_ap-journalentry
            CHANGING
              ct_map_id_doc  = ct_map_id_doc
              cv_status      = lv_br_status_log_ap ).
        ENDIF.

*Ini EXT_OSCUGALD - Registrar documento Brasil en CPID/CPD
        " En AP: TAXBR_PURCHASES vive en la misma sociedad que el AP journal (lv_companycode)
        IF ls_br_failed_ap-journalentry IS NOT INITIAL.
          lv_br_doc_status_ap = zcl_proposal_bo_abs=>c_document_status-simulated_error.
        ELSE.
          lv_br_doc_status_ap = zcl_proposal_bo_abs=>c_document_status-simulated_ok.
        ENDIF.

        lv_dummy_key_br_ap = |DUMMY{ lv_companycode }{ gv_product }{ ls_scenario_ap-doctype }|.

        lt_map_id_doc_br_ap = VALUE #( FOR ls_map_ap_br IN ct_map_id_doc
                               ( id                 = ls_map_ap_br-id
                                 item_id            = ls_map_ap_br-item_id
                                 itembasis_id       = ls_map_ap_br-itembasis_id
                                 itemcalc_id        = ls_map_ap_br-itemcalc_id
                                 documenttype       = ls_scenario_ap-doctype
                                 documentkey        = lv_dummy_key_br_ap
                                 companycode        = lv_companycode
                                 fiscalyear         = lv_fiscalyear
                                 parentdocumentkey  = ls_map_ap_br-documentkey
                                 parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                 parentcompanycode  = lv_companycode
                                 parentfiscalyear   = lv_fiscalyear ) ).

        mapping_doc(
          EXPORTING
            iv_dockey                 = lv_dummy_key_br_ap
            iv_companycode            = lv_companycode
            iv_fiscalyear             = lv_fiscalyear
            iv_doctype                = ls_scenario_ap-doctype
            iv_status                 = lv_br_doc_status_ap
            iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
            iv_accountingdocumenttype = 'CH'
            iv_isadjustment           = space
            iv_byuser                 = lv_byuser
            iv_attime                 = lv_attime
          CHANGING
            ct_map_id_doc             = lt_map_id_doc_br_ap ).

        APPEND LINES OF lt_map_id_doc_br_ap TO ct_map_id_doc.

*Fin EXT_OSCUGALD - Registrar documento Brasil en CPID/CPD

        CLEAR: lt_tax_glitems_ap, lt_br_je_val_ap.
      ENDLOOP.
    ENDIF.
*    ENDIF.
*Fin EXT_OSCUGALD - Validación anticipada de CECOs Brasil en simulación AP

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
                           iv_doctype                = zcl_proposal_bo_abs=>c_document_type-je_purchase
                           iv_status                 = lv_status_doc
                           iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                           iv_accountingdocumenttype = me->gta_je_post[ 1 ]-%param-accountingdocumenttype
                           iv_isadjustment           = space
                           its_doc                   = me->gts_doc_ap
                           iv_byuser                 = lv_byuser
                           iv_attime                 = lv_attime
                 CHANGING  ct_map_id_doc             = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

  ENDMETHOD.
ENDCLASS.
