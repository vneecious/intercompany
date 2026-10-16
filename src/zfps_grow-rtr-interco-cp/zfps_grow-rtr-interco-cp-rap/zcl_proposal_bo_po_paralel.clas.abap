CLASS zcl_proposal_bo_po_paralel DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_serializable_object .

    TYPES:      gtty_poheader     TYPE TABLE FOR CREATE i_purchaseordertp_2 .
    TYPES:      gtty_poitem       TYPE TABLE FOR CREATE i_purchaseordertp_2\_purchaseorderitem .
    TYPES:      gtty_poitemacc    TYPE TABLE FOR CREATE i_purchaseorderitemtp_2\_purordaccountassignment .
    TYPES:      gtty_poitempri    TYPE TABLE FOR CREATE i_purchaseorderitemtp_2\_purordpricingelement .
    TYPES:      gtty_cpid         TYPE STANDARD TABLE OF zfi_a_intrc_cpid .

    DATA:      gtc_purchaseorder   TYPE TABLE FOR CREATE i_purchaseordertp_2 .
    DATA:      gtc_poitem          TYPE TABLE FOR CREATE i_purchaseordertp_2\_purchaseorderitem .
    DATA:      gtc_poitem_accassig TYPE TABLE FOR CREATE i_purchaseorderitemtp_2\_purordaccountassignment .
    DATA:      gtc_poitem_pricelem TYPE TABLE FOR CREATE i_purchaseorderitemtp_2\_purordpricingelement .
    DATA:      gtd_documentkey     TYPE TABLE OF zfi_a_intrc_cpid-documentkey .
    DATA:      gt_cancelinvoice    TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~cancel.
    DATA:      gs_header_po        TYPE zi_intercoproposal .
    DATA:      gtc_doc_po          TYPE gtty_doc .
    DATA gts_doc_po       TYPE gtsty_doc.
    DATA       gt_doc_map_po    TYPE gtty_doc.
    DATA:      gv_action           TYPE c .
    DATA gv_parentdockey_po  TYPE zfi_a_intrc_cpid-documentkey.

    METHODS constructor
      IMPORTING
        !is_header            TYPE zi_intercoproposal OPTIONAL
        !it_items             TYPE ztt_proposalitem_add OPTIONAL
        !it_bases             TYPE gtty_bases OPTIONAL
        !it_calc              TYPE gtty_calc OPTIONAL
        !it_doc               TYPE gtty_doc OPTIONAL
        !its_bases            TYPE gtsty_bases OPTIONAL
        !its_calc             TYPE gtsty_calc OPTIONAL
        !its_doc              TYPE gtsty_doc OPTIONAL
        !it_doc_map           TYPE gtty_doc OPTIONAL
        !it_glaccount         TYPE ztt_proposal_reclassif OPTIONAL
        !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !it_poheader          TYPE gtty_poheader OPTIONAL
        !it_poitems           TYPE gtty_poitem OPTIONAL
        !it_poaccount         TYPE gtty_poitemacc OPTIONAL
        !it_popricing         TYPE gtty_poitempri OPTIONAL
        !iv_process           TYPE c OPTIONAL
        !it_docs              TYPE gtty_cpid OPTIONAL .

    INTERFACES if_abap_parallel.

  PROTECTED SECTION.
    METHODS exe_bo_sec           REDEFINITION.
    METHODS exe_anulation_bo_sec REDEFINITION.
    METHODS supplier_inv         REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_po_paralel IMPLEMENTATION.


  METHOD constructor.
    super->constructor( is_header            = is_header
                        it_doc               = it_doc
                        it_doc_map           = it_doc_map
                        it_glaccount         = it_glaccount
                        iv_parentdocumentkey = iv_parentdocumentkey
                        iv_process           = iv_process ).

    TRY.
        gs_header_po         = is_header.
        gtc_doc_po           = it_doc.
        gts_doc_po           = its_doc.
        gt_doc_map_po        = it_doc_map.
        gtc_purchaseorder    = it_poheader.
        gtc_poitem           = it_poitems.
        gtc_poitem_accassig  = it_poaccount.
        gtc_poitem_pricelem  = it_popricing.
        gv_action            = iv_process.
        gv_parentdockey_po   = iv_parentdocumentkey.
      CATCH cx_sy_create_data_error
            cx_sy_assign_cast_illegal_cast
            cx_sy_assign_cast_unknown_type
            cx_sy_assign_out_of_range INTO DATA(lref_dynamic_cx). " TODO: variable is assigned but never used (ABAP cleaner)
    ENDTRY.
  ENDMETHOD.


  METHOD exe_anulation_bo_sec.

    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.


    "Marca indicador de borrado a posiciones del pedido de compra
    TYPES: lty_po_del TYPE TABLE FOR DELETE i_purchaseordertp_2.
    DATA: lt_po_del TYPE lty_po_del.
    DATA: ls_po_del LIKE LINE OF lt_po_del.

    TYPES: BEGIN OF tcs_head,
             BEGIN OF structure,
               key         TYPE STRUCTURE FOR KEY OF  i_purchaseordertp_2,
               read_import TYPE STRUCTURE FOR READ IMPORT  i_purchaseordertp_2,
             END OF structure,
           END OF tcs_head.

    DATA lv_po TYPE tcs_head-structure-read_import-%key-purchaseorder.

    lv_dockey = iv_parentdockey."ct_map_id_doc[ 1 ]-Documentkey.
    lv_po = iv_parentdockey."ct_map_id_doc[ 1 ]-Documentkey.

    ls_po_del-%key-purchaseorder = lv_po.
    APPEND ls_po_del TO lt_po_del.

    MODIFY ENTITIES OF i_purchaseordertp_2
            ENTITY purchaseorder
            DELETE FROM lt_po_del
            FAILED   DATA(ls_failed_po)
            MAPPED   DATA(ls_mapped_po)
            REPORTED DATA(ls_reported_po).

    IF ls_failed_po-purchaseorder IS INITIAL.
      COMMIT ENTITIES
             RESPONSE OF i_purchaseordertp_2
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_reported_commit).

      IF ls_save_failed-purchaseorder IS INITIAL.
*        LOOP AT ls_mapped_po-PurchaseOrder ASSIGNING FIELD-SYMBOL(<fs_po_mapped>).
*          CONVERT KEY OF I_PurchaseOrderTP_2 FROM <fs_po_mapped>-%pid TO DATA(ls_so_final_key).
*          <fs_po_mapped>-PurchaseOrder = ls_so_final_key-PurchaseOrder.

        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
*          lv_dockey = ls_so_final_key.

*        ENDLOOP.
        IF ls_reported_commit-purchaseorder IS INITIAL.
          ls_reported_commit-purchaseorder = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                           number   = '024'
                                                           severity = if_abap_behv_message=>severity-success
                                                           v1 = iv_parentdockey ) ) ).
        ENDIF.
      ELSE.
        ROLLBACK ENTITIES.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey     = iv_parentdockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_purchorder
                                 it_reported   = ls_reported_commit-purchaseorder
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).
    ELSE.
      ROLLBACK ENTITIES.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.
      mapping_doc_log( EXPORTING iv_dockey     = iv_parentdockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_purchorder
                                 it_reported   = ls_reported_po-purchaseorderitem
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey        = iv_parentdockey
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_purchorder
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_po
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    mapping_doc( EXPORTING iv_dockey       = iv_parentdockey
                           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-purchaseorder
*                           iv_parentdockey  = iv_parentdockey
*                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status       = lv_status_doc
                           iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment = space
                           iv_isdeleted    = abap_true
                           its_doc         = me->gts_doc_po
                           iv_byuser       = lv_byuser
                           iv_attime       = lv_attime
                 CHANGING  ct_map_id_doc   = ct_map_id_doc ).
    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
  ENDMETHOD.


  METHOD exe_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    DATA ls_intrc_cpdl  TYPE zfi_a_intrc_cpdl.
    DATA: lv_text TYPE string.
    DATA lt_reported TYPE TABLE FOR REPORTED LATE i_purchaseordertp_2\\purchaseorder.

    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.


    MODIFY ENTITIES OF i_purchaseordertp_2
           ENTITY purchaseorder CREATE FROM gtc_purchaseorder
           CREATE BY \_purchaseorderitem FROM gtc_poitem
           ENTITY purchaseorderitem
           CREATE BY \_purordaccountassignment FROM gtc_poitem_accassig
           CREATE BY \_purordpricingelement FROM gtc_poitem_pricelem
           REPORTED DATA(ls_reported)
           FAILED   DATA(ls_failed)
           MAPPED   DATA(ls_mapped).

    IF ls_failed-purchaseorder IS INITIAL.

      COMMIT ENTITIES BEGIN RESPONSE OF i_purchaseordertp_2
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_save_reported).

      IF ls_save_failed-purchaseorder IS INITIAL.
        " Special processing for Late numbering to determine the generated document number.
        LOOP AT ls_mapped-purchaseorder ASSIGNING FIELD-SYMBOL(<fs_po_mapped>).
          CONVERT KEY OF i_purchaseordertp_2 FROM <fs_po_mapped>-%pid TO DATA(ls_so_final_key).
          <fs_po_mapped>-purchaseorder = ls_so_final_key-purchaseorder.

          IF ls_save_failed-purchaseorder IS NOT INITIAL.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
            CLEAR lv_dockey.
          ELSE.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
            lv_dockey = ls_so_final_key.
          ENDIF.
          IF ls_save_reported-purchaseorder IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                       it_reported   = ls_save_reported-purchaseorder
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-purchaseorderitem IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                       it_reported   = ls_save_reported-purchaseorderitem
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-purchaseorderaccountassignment IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                       it_reported   = ls_save_reported-purchaseorderaccountassignment
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-purorderitempricingelement IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                       it_reported   = ls_save_reported-purorderitempricingelement
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-purchaseorder IS INITIAL AND
             ls_save_reported-purchaseorderitem IS INITIAL AND
             ls_save_reported-purchaseorderaccountassignment IS INITIAL AND
             ls_save_reported-purorderitempricingelement IS INITIAL.

            "El documento se ha contabilizado correctamente
            IF ls_save_reported-purchaseorder IS INITIAL.
              ls_save_reported-purchaseorder = VALUE #( ( %msg = new_message( id = 'ZINT_MSG_INTERCO_CP'
                                                        number = '021'
                                                      severity = if_abap_behv_message=>severity-success
                                                            v1 = lv_dockey ) ) ).
            ENDIF.

            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                       it_reported   = ls_save_reported-purchaseorder
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
        ENDLOOP.
      ELSE.
*        ROLLBACK ENTITIES.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
        IF ls_save_reported-purchaseorder IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                     it_reported   = ls_save_reported-purchaseorder
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
        IF ls_save_reported-purchaseorderitem IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                     it_reported   = ls_save_reported-purchaseorderitem
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
        IF ls_save_reported-purchaseorderaccountassignment IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                     it_reported   = ls_save_reported-purchaseorderaccountassignment
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
        IF ls_save_reported-purorderitempricingelement IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                     it_reported   = ls_save_reported-purorderitempricingelement
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
      ENDIF.
      COMMIT ENTITIES END.
    ELSE.

      ROLLBACK ENTITIES.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      IF ls_reported-purchaseorder IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                   it_reported   = ls_reported-purchaseorder
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-purchaseorderitem IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                   it_reported   = ls_reported-purchaseorderitem
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-purchaseorderaccountassignment IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                   it_reported   = ls_reported-purchaseorderaccountassignment
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-purorderitempricingelement IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                   it_reported   = ls_reported-purorderitempricingelement
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ELSE.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey       = lv_dockey
                           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                           iv_status       = lv_status_doc
                           iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment = space
                           iv_byuser       = lv_byuser
                           iv_attime       = lv_attime
                 CHANGING  ct_map_id_doc   = ct_map_id_doc ).

    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
    DELETE ct_map_id_doc WHERE isdeleted EQ abap_true.

    ev_document = lv_dockey.
    IF lv_dockey IS NOT INITIAL.
      APPEND INITIAL LINE TO et_document ASSIGNING FIELD-SYMBOL(<fs_doc>).
      <fs_doc> = lv_dockey.
      UNASSIGN <fs_doc>.
    ENDIF.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    CASE gv_action.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( IMPORTING ev_document   = gv_documentkey
                              et_document   = gtd_documentkey
                    CHANGING  ct_map_id_doc = gt_doc_map_po ).                " Creación Doc. Compras.
***        IF sy-uname NE 'EXT_OSCUGALD'.
***          IF gtd_documentkey[] IS NOT INITIAL.
***            supplier_inv( EXPORTING iv_parentdocument = gv_documentkey
***                                    it_parentdocument = gtd_documentkey ).   " Genera Factura
****          save_log( ).
***          ENDIF.
***        ENDIF.
      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_parentdockey = gv_parentdockey_po
                              CHANGING  ct_map_id_doc   = gt_doc_map_po ).       " Indicador de borrado en Doc. Compras
    ENDCASE.
    save_log( ).

  ENDMETHOD.


  METHOD supplier_inv.
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Nota de credito
    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    DATA(lo_suppl) = NEW zcl_proposal_bo_supplierinv( is_header            = gs_header_po
**                                                      iv_parentdocumentkey = iv_parentdocument
*                                                      it_doc_map           = gt_doc_map_po
*                                                      it_purchaseorder     = gtc_purchaseorder
*                                                      it_poitem            = gtc_poitem ).
*
*    lo_suppl->process_bo_sec( ).


  ENDMETHOD.
ENDCLASS.
