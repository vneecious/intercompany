CLASS zcl_proposal_bo_so_paralel DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES gtty_soheader     TYPE TABLE FOR CREATE i_salesordertp.
    TYPES gtty_soitemcba    TYPE TABLE FOR CREATE i_salesordertp\_item.
    TYPES gtty_sopricingcba TYPE TABLE FOR CREATE i_salesorderitemtp\_itempricingelement.
    TYPES gtty_cpid         TYPE STANDARD TABLE OF zfi_a_intrc_cpid.

*    CONSTANTS gc_disable TYPE  if_abap_behv=>t_fail_cause.

    DATA gtc_salesorder   TYPE TABLE FOR CREATE i_salesordertp.
    DATA gtc_soitemcba    TYPE TABLE FOR CREATE i_salesordertp\_item.
    DATA gtc_sopricingcba TYPE TABLE FOR CREATE i_salesorderitemtp\_itempricingelement.
    DATA gtd_documents    TYPE STANDARD TABLE OF i_salesordertp-salesorder.
    DATA gtd_documentkey  TYPE STANDARD TABLE OF zfi_a_intrc_cpid-documentkey.

    DATA gs_header_so     TYPE zi_intercoproposal.
    DATA gtd_items_add_so TYPE ztt_proposalitem_add.
    DATA gtd_bases_so     TYPE gtty_bases.
    DATA gtd_calc_so      TYPE gtty_calc.
    DATA gtd_doc_so       TYPE gtty_doc.
    DATA gts_doc_so       TYPE gtsty_doc.
    DATA gt_doc_map_so    TYPE gtty_doc.
    DATA gt_doc_map_bd    TYPE gtty_doc.
    DATA gv_parentdockey_so  TYPE zfi_a_intrc_cpid-documentkey.
    DATA gtd_glaccount_so TYPE ztt_proposal_reclassif.
    DATA gv_process_so    TYPE c.

    METHODS constructor
      IMPORTING !is_header            TYPE zi_intercoproposal     OPTIONAL
                !it_items             TYPE ztt_proposalitem_add   OPTIONAL
                !it_bases             TYPE gtty_bases             OPTIONAL
                !it_calc              TYPE gtty_calc              OPTIONAL
                !it_doc               TYPE gtty_doc               OPTIONAL
                !it_glaccount         TYPE ztt_proposal_reclassif OPTIONAL
                !its_bases            TYPE gtsty_bases            OPTIONAL
                !its_calc             TYPE gtsty_calc             OPTIONAL
                !its_doc              TYPE gtsty_doc              OPTIONAL
                !its_glaccount        TYPE gtsty_glaccount        OPTIONAL
                !iv_parentdocumentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
                !it_doc_map           TYPE gtty_doc               OPTIONAL
                !it_soheader          TYPE gtty_soheader          OPTIONAL
                !it_soitems           TYPE gtty_soitemcba         OPTIONAL
                !it_sopricing         TYPE gtty_sopricingcba      OPTIONAL
                !iv_process           TYPE c                      OPTIONAL.

    INTERFACES if_abap_parallel.

  PROTECTED SECTION.
    METHODS exe_bo_sec      REDEFINITION.
    METHODS exe_anulation_bo_sec REDEFINITION.
    METHODS billing_doc REDEFINITION.
*    METHODS save_log    REDEFINITION.
ENDCLASS.



CLASS zcl_proposal_bo_so_paralel IMPLEMENTATION.
  METHOD billing_doc.
**    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
**    "Factura de Venta
**    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    DATA(lo_billing) = NEW zcl_proposal_bo_billingdoc( is_header  = gs_header_so
*                                                       it_items   = gtd_items_add_so
*                                                       it_bases   = gtd_bases_so
*                                                       it_calc    = gtd_calc_so
*                                                       it_doc     = gtd_doc_so
*                                                       its_doc    = gts_doc_so
*                                                       it_doc_map = gt_doc_map_so
*                                                       iv_process = gv_process_so ).
*
*    lo_billing->process_bo_sec( IMPORTING et_doc_map        = gt_doc_map_bd
*                                CHANGING  ct_parentdocument = gtd_documentkey ).
*    APPEND LINES OF gt_doc_map_bd TO gt_doc_map_so.
  ENDMETHOD.

  METHOD if_abap_parallel~do.
    CASE me->gv_process_so.
      WHEN zcl_boproposal_tools=>gc_create_doc.
        exe_bo_sec( IMPORTING et_document   = gtd_documentkey
                    CHANGING  ct_map_id_doc = gt_doc_map_so ). " Creación Doc. Ventas

      WHEN zcl_boproposal_tools=>gc_reverse_doc.
        exe_anulation_bo_sec( EXPORTING iv_parentdockey = gv_parentdockey_so
                              CHANGING ct_map_id_doc = gt_doc_map_so ).

    ENDCASE.
    save_log( ).
  ENDMETHOD.

  METHOD constructor.
    super->constructor( is_header            = is_header
                        it_items             = it_items
                        it_bases             = it_bases
                        it_calc              = it_calc
                        it_doc               = it_doc
                        its_doc              = its_doc
                        it_doc_map           = it_doc_map
                        it_glaccount         = it_glaccount
                        iv_parentdocumentkey = iv_parentdocumentkey
                        iv_process           = iv_process ).

    TRY.
        gs_header_so = me->gs_header.
        gtd_items_add_so = me->gtd_items_add.
        gtd_bases_so = me->gtd_bases.
        gtd_calc_so  = me->gtd_calc.
        gtd_doc_so   = me->gtd_doc.
        gts_doc_so   = me->gts_doc.
        gt_doc_map_so = me->gt_doc_map.
        gtd_glaccount_so = me->gtd_glaccount.
        gv_parentdockey_so = me->gv_parentdocumentkey.
        gtc_salesorder   = it_soheader.
        gtc_soitemcba    = it_soitems.
        gtc_sopricingcba = it_sopricing.
        gv_process_so    = me->gv_process.
      CATCH cx_sy_create_data_error
            cx_sy_assign_cast_illegal_cast
            cx_sy_assign_cast_unknown_type
            cx_sy_assign_out_of_range INTO DATA(lref_dynamic_cx). " TODO: variable is assigned but never used (ABAP cleaner)
    ENDTRY.
  ENDMETHOD.

  METHOD exe_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    MODIFY ENTITIES OF i_salesordertp
           ENTITY salesorder CREATE FROM gtc_salesorder
           CREATE BY \_item FROM gtc_soitemcba
           ENTITY salesorderitem
           CREATE BY \_itempricingelement FROM gtc_sopricingcba
           MAPPED DATA(ls_mapped)
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported).
    IF ls_failed-salesorder IS INITIAL.

      COMMIT ENTITIES BEGIN
             RESPONSE OF i_salesordertp
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_save_reported).
      IF ls_save_failed-salesorder IS INITIAL.

        LOOP AT ls_mapped-salesorder ASSIGNING FIELD-SYMBOL(<fs_salesorder>).
          CONVERT KEY OF i_salesordertp FROM <fs_salesorder>-%pid TO DATA(ls_so_final_key).
          <fs_salesorder>-salesorder = ls_so_final_key-salesorder.

          IF ls_save_failed-salesorder IS NOT INITIAL.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
            CLEAR lv_dockey.
          ELSE.
            lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
            lv_dockey = ls_so_final_key-salesorder.
          ENDIF.

          IF ls_save_reported-salesorder IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                       it_reported   = ls_save_reported-salesorder
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-salesorderitem IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                       it_reported   = ls_save_reported-salesorderitem
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
          IF ls_save_reported-salesorderitempricingelement IS NOT INITIAL.
            mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                       iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                       it_reported   = ls_save_reported-salesorderitempricingelement
                             CHANGING  ct_map_id_doc = ct_map_id_doc
                                       cv_status     = lv_status_log ).
          ENDIF.
        ENDLOOP.

      ELSE.

        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
        CLEAR lv_dockey.
        IF ls_save_reported-salesorder IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                     it_reported   = ls_save_reported-salesorder
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
        IF ls_save_reported-salesorderitem IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                     it_reported   = ls_save_reported-salesorderitem
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
        IF ls_save_reported-salesorderitempricingelement IS NOT INITIAL.
          mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                     iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                     it_reported   = ls_save_reported-salesorderitempricingelement
                           CHANGING  ct_map_id_doc = ct_map_id_doc
                                     cv_status     = lv_status_log ).
        ENDIF.
      ENDIF.
      COMMIT ENTITIES END.
    ELSE.

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.
      IF ls_reported-salesorder IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                   it_reported   = ls_reported-salesorder
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-salesorderitem IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                   it_reported   = ls_reported-salesorderitem
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
      IF ls_reported-salesorderitempricingelement IS NOT INITIAL.
        mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                   iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
                                   it_reported   = ls_reported-salesorderitempricingelement
                         CHANGING  ct_map_id_doc = ct_map_id_doc
                                   cv_status     = lv_status_log ).
      ENDIF.
    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey       = lv_dockey
                           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status       = lv_status_doc
                           iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment = space
                           its_doc         = me->gts_doc_so
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

  METHOD exe_anulation_bo_sec.
    DATA lt_soitem TYPE TABLE FOR REPORTED EARLY i_salesordertp\\salesorderitem.
    DATA lv_dockey TYPE zfi_a_intrc_cpd-documentkey.
    DATA mv_salesorder TYPE i_salesorderitem-salesorder.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
    DATA lv_byuser TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    DATA(lv_rjcnreason) = '10'.

*    DATA(lv_dockey) = ct_map_id_doc[ 1 ]-Documentkey.
    mv_salesorder = ct_map_id_doc[ 1 ]-parentdocumentkey.

    SELECT salesorder FROM i_salesorder
    WHERE salesorder EQ @mv_salesorder
    INTO TABLE @DATA(lt_so_h).

    SELECT salesorder, salesorderitem FROM i_salesorderitem
    WHERE salesorder EQ @mv_salesorder
    INTO TABLE @DATA(lt_so_item).

    MODIFY ENTITIES OF i_salesordertp
           ENTITY salesorder
           UPDATE FIELDS ( sddocumentreason )
           WITH VALUE #( FOR ls_key IN lt_so_h ( sddocumentreason        = 'Z1P'
                                                 %key-salesorder         = ls_key-salesorder ) )
           ENTITY salesorderitem
           UPDATE
           FIELDS ( salesdocumentrjcnreason )
           WITH VALUE #( FOR ls_key_item IN lt_so_item
                                               ( salesdocumentrjcnreason = lv_rjcnreason
                                                 %key-salesorder         = ls_key_item-salesorder
                                                 %key-salesorderitem     = ls_key_item-salesorderitem ) )
*           DELETE FROM VALUE #( FOR ls_row IN lt_so_item
*                                ( %key-SalesOrder     = ls_row-SalesOrder
*                                  %key-SalesOrderItem = ls_row-SalesOrderItem ) )
           FAILED   DATA(lt_failed)
           REPORTED DATA(lt_reported)
           MAPPED DATA(ls_mapped).
    IF lt_failed IS INITIAL.

      COMMIT ENTITIES BEGIN
             RESPONSE OF i_salesordertp
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_save_reported).
      IF ls_save_failed IS NOT INITIAL.

*        IF ls_save_failed-salesorder IS NOT INITIAL.
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      ELSE.
*        CONVERT KEY OF i_salesordertp FROM ls_mapped-salesorderitem[ 1 ]-%pid TO DATA(ls_deletedSalesOrderItem).
        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = mv_salesorder.
      ENDIF.

      mapping_doc_log( EXPORTING iv_dockey     = iv_parentdockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_salesorder
                                 it_reported   = ls_save_reported-salesorder
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      mapping_doc_log( EXPORTING iv_dockey     = iv_parentdockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_salesorder
                                 it_reported   = ls_save_reported-salesorderitem
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

      COMMIT ENTITIES END.
    ELSE.

      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.
      TRY.
          DATA(ls_items_failed) = lt_failed-salesorderitem[ 1 ].
          IF ls_items_failed-%fail-cause EQ if_abap_behv=>cause-disabled
          AND ls_items_failed-%delete EQ  if_abap_behv=>fc-o-disabled.
            lt_soitem = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                       number   = '023'
                                                       severity = if_abap_behv_message=>severity-error ) ) ).
          ENDIF.
      ENDTRY.
      mapping_doc_log( EXPORTING iv_dockey     = iv_parentdockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-anul_salesorder
                                 it_reported   = lt_soitem
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).

    ENDIF.
    IF lv_status_log EQ 'E'.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
    ENDIF.
    mapping_doc( EXPORTING iv_dockey        = iv_parentdockey
                           iv_doctype       = zcl_proposal_bo_abs=>c_document_type-anul_salesorder
                           iv_parentdockey  = iv_parentdockey
                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status        = lv_status_doc
                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment  = space
                           its_doc          = me->gts_doc_so
                           iv_byuser        = lv_byuser
                           iv_attime        = lv_attime
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).

    mapping_doc( EXPORTING iv_dockey       = iv_parentdockey
                           iv_doctype      = zcl_proposal_bo_abs=>c_document_type-salesorder
*                           iv_parentdockey  = iv_parentdockey
*                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                           iv_status       = lv_status_doc
                           iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                           iv_isadjustment = space
                           iv_isdeleted    = abap_true
                           its_doc         = me->gts_doc_so
                           iv_byuser       = lv_byuser
                           iv_attime       = lv_attime
                 CHANGING  ct_map_id_doc   = ct_map_id_doc ).
    MOVE-CORRESPONDING gt_intrc_cpid TO ct_map_id_doc.
  ENDMETHOD.

ENDCLASS.
