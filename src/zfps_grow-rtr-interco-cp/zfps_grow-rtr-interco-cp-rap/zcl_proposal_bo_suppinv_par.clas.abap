CLASS zcl_proposal_bo_suppinv_par DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES gtty_invoice_create TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create.
    TYPES gtty_invoice_cancel TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~cancel.

    DATA gta_invoice_create     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create.
    DATA gta_invoice_cancel     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~cancel.
    DATA gv_documentkey_si      TYPE zfi_a_intrc_cpid-documentkey.
    DATA gv_fiscalyear_si      TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA gv_parentdockey_si   TYPE zfi_a_intrc_cpid-documentkey.
    DATA gv_parentfiscalyear_si   TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA gs_header_si           TYPE zi_intercoproposal .
    DATA gv_action              TYPE c .
    DATA gt_doc_map_si          TYPE gtty_doc.
    DATA gts_doc_si     TYPE gtsty_doc.

    METHODS constructor
      IMPORTING !is_header            TYPE zi_intercoproposal OPTIONAL
                !iv_process           TYPE c
                !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_parentfiscalyear  TYPE zfi_a_intrc_cpid-fiscalyear OPTIONAL
                !iv_documentkey       TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !iv_fiscalyear        TYPE zfi_a_intrc_cpid-fiscalyear OPTIONAL
                !its_doc              TYPE gtsty_doc     OPTIONAL
                !it_doc_map           TYPE gtty_doc OPTIONAL
                !ita_invoice_create   TYPE gtty_invoice_create OPTIONAL
                !ita_invoice_cancel   TYPE gtty_invoice_cancel OPTIONAL.
    INTERFACES if_abap_parallel.
  PROTECTED SECTION.
    METHODS:   exe_bo_sec REDEFINITION.
    METHODS:   exe_anulation_bo_sec REDEFINITION.
    METHODS set_journalentry
      IMPORTING iv_orrefdoc       TYPE i_journalentrytp-originalreferencedocument
                iv_doctype        TYPE zfi_a_intrc_cpid-documenttype
                iv_parentorrefdoc TYPE i_journalentrytp-originalreferencedocument
                iv_parentdoctype  TYPE zfi_a_intrc_cpid-parentdocumenttype
                iv_byuser         TYPE zfi_a_intrc_cpid-createdby
                iv_attime         TYPE zfi_a_intrc_cpid-createdat
      CHANGING  ct_map_id_doc     TYPE gtty_doc.
  PRIVATE SECTION.
    METHODS:
      fi_wt_post
        IMPORTING
          !iv_parentdocument TYPE zfi_a_intrc_cpd-documentkey OPTIONAL.
ENDCLASS.



CLASS zcl_proposal_bo_suppinv_par IMPLEMENTATION.
  METHOD if_abap_parallel~do.
    CASE gv_action.
      WHEN zcl_boproposal_tools=>gc_create_doc.         "Creación Factura
        exe_bo_sec( EXPORTING iv_parentdocument = gv_parentdockey_si
                    IMPORTING ev_document       = DATA(lv_documentkey)
                    CHANGING  ct_map_id_doc     = gt_doc_map_si ).
        IF lv_documentkey IS NOT INITIAL.
          fi_wt_post( ).
        ENDIF.
        CLEAR gv_parentdockey_si.
      WHEN zcl_boproposal_tools=>gc_reverse_doc.        "Reversa Factura
        exe_anulation_bo_sec( EXPORTING iv_dockey       = gv_documentkey_si
                                        iv_parentdockey = gv_parentdockey_si
                              CHANGING  ct_map_id_doc   = gt_doc_map_si ).
*        CLEAR gv_documentkey_si.
    ENDCASE.
    save_log( ).
  ENDMETHOD.

  METHOD constructor.

    super->constructor( is_header      = is_header
                        iv_process     = iv_process
                        iv_documentkey = iv_parentdocumentkey
                        its_doc        = its_doc
                        it_doc_map     = it_doc_map ).

    gv_action       = iv_process.
    gts_doc_si    = its_doc.
    gt_doc_map_si   = it_doc_map.
    gs_header_si    = is_header.
    IF iv_documentkey IS SUPPLIED.
      gv_documentkey_si = iv_documentkey.
    ENDIF.
    gv_fiscalyear_si = iv_fiscalyear.
    IF iv_parentdocumentkey IS SUPPLIED.
      gv_parentdockey_si = iv_parentdocumentkey.
    ENDIF.
    gv_parentfiscalyear_si = iv_parentfiscalyear.
    IF ita_invoice_create IS SUPPLIED.
      gta_invoice_create = ita_invoice_create.
    ENDIF.
    IF ita_invoice_cancel IS SUPPLIED.
      gta_invoice_cancel = ita_invoice_cancel.
    ENDIF.
  ENDMETHOD.

  METHOD exe_anulation_bo_sec.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_fiscalyear TYPE i_journalentrytp-fiscalyear.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    "Realiza la cancelación de la factura de compras
    "Register the action
    MODIFY ENTITIES OF i_supplierinvoicetp
    ENTITY supplierinvoice
    EXECUTE cancel FROM gta_invoice_cancel
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported)
    MAPPED DATA(ls_mapped).

    IF ls_failed-supplierinvoice IS INITIAL.
      "Execution the action
      COMMIT ENTITIES
        RESPONSE OF i_supplierinvoicetp
        FAILED DATA(ls_failed_commit)
        REPORTED DATA(ls_commit_reported).
      IF ls_failed_commit IS NOT INITIAL.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      ELSE.
        DATA(ls_so_final_key) = ls_commit_reported-supplierinvoice[ 1 ].
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = ls_so_final_key-supplierinvoice.
        lv_fiscalyear = ls_so_final_key-supplierinvoicefiscalyear.
      ENDIF.
      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_fiscalyear = lv_fiscalyear
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                                 it_reported   = ls_commit_reported-supplierinvoice
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

    ELSE.
      ROLLBACK ENTITIES.
      "Error.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_fiscalyear = lv_fiscalyear
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                                 it_reported   = ls_reported-supplierinvoice
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

*      RETURN.
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
*    DATA(ls_parent_key) = ls_mapped-supplierinvoice[ 1 ].
    mapping_doc( EXPORTING iv_dockey           = lv_dockey
                           iv_fiscalyear       = lv_fiscalyear
                           iv_doctype          = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                           iv_parentdockey     = CONV #( gv_documentkey_si )
                           iv_parentfiscalyear = gv_fiscalyear_si
                           iv_parentdoctype    = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                           iv_status           = lv_status_doc
                           iv_cat_id           = zcl_proposal_bo_abs=>c_document_category-invoicing
                           iv_isadjustment     = space
                           iv_byuser           = lv_byuser
                           iv_attime           = lv_attime
                           its_doc             = me->gts_doc_si
                           iv_process          = gv_action
                 CHANGING  ct_map_id_doc       = ct_map_id_doc ).

    mapping_doc( EXPORTING iv_dockey           = CONV #( gv_documentkey_si )
                           iv_parentfiscalyear = gv_fiscalyear_si
                           iv_doctype          = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
*                           iv_parentdockey     = iv_parentdockey
*                           iv_parentdoctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                           iv_status           = lv_status_doc
                           iv_cat_id           = zcl_proposal_bo_abs=>c_document_category-invoicing
                           iv_isadjustment     = space
                           iv_isdeleted        = abap_true
                           its_doc             = me->gts_doc_si
                           iv_byuser           = lv_byuser
                           iv_attime           = lv_attime
                 CHANGING  ct_map_id_doc       = ct_map_id_doc ).

    IF lv_dockey IS NOT INITIAL.
      set_journalentry( EXPORTING iv_orrefdoc = CONV #( |{ ls_so_final_key-supplierinvoice }{ ls_so_final_key-supplierinvoicefiscalyear }| )
                                  iv_doctype = zcl_proposal_bo_abs=>c_document_type-anul_je_purch
                                  iv_parentorrefdoc   = CONV #( |{ gv_documentkey_si }{ gv_fiscalyear_si }| )
                                  iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                                  iv_byuser = lv_byuser
                                  iv_attime = lv_attime
                        CHANGING ct_map_id_doc = ct_map_id_doc ).
    ENDIF.
    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true AND documentkey(5) EQ 'DUMMY'.
  ENDMETHOD.

  METHOD exe_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_fiscalyear TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    "Register the action
    MODIFY ENTITIES OF i_supplierinvoicetp
    ENTITY supplierinvoice
    EXECUTE create FROM gta_invoice_create
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported)
    MAPPED DATA(ls_mapped).

    IF ls_failed-supplierinvoice IS INITIAL.

      "Execution the action
      COMMIT ENTITIES BEGIN
       RESPONSE OF i_supplierinvoicetp
       FAILED DATA(ls_save_failed)
       REPORTED DATA(ls_save_reported).

      IF ls_save_failed-supplierinvoice IS INITIAL.
        "Success
        LOOP AT ls_save_reported-supplierinvoice ASSIGNING FIELD-SYMBOL(<fs_suppl>).
          CONVERT KEY OF i_supplierinvoicetp FROM <fs_suppl>-%pid TO DATA(ls_so_final_key).
          <fs_suppl>-supplierinvoice = ls_so_final_key-supplierinvoice.
          <fs_suppl>-supplierinvoicefiscalyear = ls_so_final_key-supplierinvoicefiscalyear.

          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
          lv_dockey = ls_so_final_key-supplierinvoice.
          lv_fiscalyear = ls_so_final_key-supplierinvoicefiscalyear.

        ENDLOOP.

      ELSE.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_fiscalyear = lv_fiscalyear
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                 it_reported   = ls_save_reported-supplierinvoice
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      COMMIT ENTITIES END.
    ELSE.
      ROLLBACK ENTITIES.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_fiscalyear = lv_fiscalyear
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                 it_reported   = ls_reported-supplierinvoice
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ELSE.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey        = lv_dockey
                           iv_fiscalyear    = lv_fiscalyear
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                           iv_parentdockey  = iv_parentdocument
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                           iv_isadjustment  = space
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                           iv_process       = gv_action
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ev_document = lv_dockey.

    IF lv_dockey IS NOT INITIAL.
      set_journalentry( EXPORTING iv_orrefdoc = CONV #( ls_so_final_key )
                                  iv_doctype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                  iv_parentorrefdoc   = CONV #( iv_parentdocument )
                                  iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                  iv_byuser = lv_byuser
                                  iv_attime = lv_attime
                        CHANGING ct_map_id_doc = ct_map_id_doc ).
    ENDIF.

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true OR documentkey(5) EQ 'DUMMY'.
  ENDMETHOD.

  METHOD fi_wt_post.
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Documentos fi para tratamiento posterior de retenciones
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    DATA(lo_fi_wt_post) = NEW zcl_proposal_bo_wt_post( is_header            = gs_header_po
*                                                      iv_parentdocumentkey = iv_parentdocument
*                                                      it_doc_map           = gtc_doc_po
*                                                      it_purchaseorder     = gtc_purchaseorder
*                                                      it_poitem            = gtc_poitem ).
*
*    lo_fi_wt_post->process_bo_sec( ).
  ENDMETHOD.

  METHOD set_journalentry.
    DATA lt_suppinv TYPE TABLE FOR REPORTED EARLY i_supplierinvoicetp\\supplierinvoice.
    DATA lv_companycode TYPE i_journalentrytp-companycode.
    DATA lv_fiscalyear TYPE i_journalentrytp-fiscalyear.
    DATA lv_accdoc TYPE i_journalentrytp-accountingdocument.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.

*      lv_orrefdoc = ls_so_final_key.
    SELECT SINGLE companycode, fiscalyear, accountingdocument FROM i_journalentrytp
    WHERE originalreferencedocument EQ @iv_orrefdoc
    INTO (@lv_companycode, @lv_fiscalyear, @lv_accdoc).
    IF sy-subrc EQ 0.
      lt_suppinv = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                  number   = '021'
                                                  severity = if_abap_behv_message=>severity-success
                                                  v1       = lv_accdoc ) ) ).
      mapping_doc_log( EXPORTING iv_dockey     = CONV #( lv_accdoc )
                                 iv_companycode   = lv_companycode
                                 iv_fiscalyear    = lv_fiscalyear
                                 iv_doctype    = iv_doctype
                                 it_reported   = lt_suppinv
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.

      mapping_doc( EXPORTING iv_dockey        = CONV #( lv_accdoc )
                             iv_companycode   = lv_companycode
                             iv_fiscalyear    = lv_fiscalyear
                             iv_doctype       = iv_doctype
                             iv_parentdockey  = CONV #( iv_orrefdoc(10) )
                             iv_parentfiscalyear  = CONV #( iv_orrefdoc+10(4) )
                             iv_parentdoctype = iv_parentdoctype
                             iv_status        = lv_status_doc
                             iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                             iv_isadjustment  = space
                             its_doc          = me->gts_doc_si
                             iv_byuser        = iv_byuser
                             iv_attime        = iv_attime
                             iv_process       = gv_action
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
                             iv_doctype       = zcl_proposal_bo_abs=>c_document_type-je_purchase
                             iv_parentdockey  = CONV #( iv_orrefdoc(10) )
                             iv_parentfiscalyear  = CONV #( iv_orrefdoc+10(4) )
                             iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                             iv_status        = lv_status_doc
                             iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                             iv_isadjustment  = space
                             iv_isdeleted     = abap_true
                             its_doc          = me->gts_doc_si
                             iv_byuser        = iv_byuser
                             iv_attime        = iv_attime
                   CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
