CLASS zcl_proposal_bo_billingdoc DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gtty_cpid TYPE STANDARD TABLE OF zfi_a_intrc_cpid.
    TYPES: gsty_bd_create TYPE STRUCTURE FOR ACTION IMPORT I_BillingDocumentTP~CreateFromSDDocument.
    TYPES: gsty_bd_create_ref TYPE LINE OF gsty_bd_create-%param-_reference.
    TYPES: gsty_bd_CancelDoc TYPE STRUCTURE FOR ACTION IMPORT I_BillingDocumentTP~CreateCancellationDocument.
    TYPES: gsty_bd_CancelDoc_revreason TYPE gsty_bd_CancelDoc-%param-ReversalReason.

    DATA gta_BDFromSD    TYPE TABLE FOR ACTION IMPORT I_BillingDocumentTP~CreateFromSDDocument.
    DATA gta_BDCancelDoc    TYPE TABLE FOR ACTION IMPORT I_BillingDocumentTP~CreateCancellationDocument.
    DATA gtd_doc_bd     TYPE gtty_doc.
    DATA gts_doc_bd     TYPE gtsty_doc.
    DATA gt_doc_map_so  TYPE gtty_doc.
    DATA gt_doc_map_bd  TYPE gtty_doc.
    DATA gtd_documentkey TYPE gtty_parentkey.
    DATA gtd_list_bo      TYPE cl_abap_parallel=>t_in_inst_tab.
    DATA gv_process_bd TYPE c.

    CONSTANTS gc_ReversalReason TYPE gsty_bd_CancelDoc_revreason VALUE '01'.

    METHODS constructor
      IMPORTING is_header      TYPE zi_intercoproposal           OPTIONAL
                it_items       TYPE ztt_proposalitem_add         OPTIONAL
                it_bases       TYPE gtty_bases                   OPTIONAL
                it_calc        TYPE gtty_calc                    OPTIONAL
                it_doc         TYPE gtty_doc                     OPTIONAL
                it_anul_doc    TYPE gtty_doc                     OPTIONAL
                its_bases      TYPE gtsty_bases                  OPTIONAL
                its_calc       TYPE gtsty_calc                   OPTIONAL
                its_doc        TYPE gtsty_doc                    OPTIONAL
                it_GLAccount   TYPE ztt_proposal_reclassif       OPTIONAL
                iv_process     TYPE c                            OPTIONAL
                iv_documentkey TYPE zfi_a_intrc_cpid-DocumentKey OPTIONAL
                it_doc_map     TYPE gtty_doc                     OPTIONAL.
*                it_cpid        TYPE gtty_cpid OPTIONAL
*                it_cpdf        TYPE gtty_cpdf OPTIONAL.

  PROTECTED SECTION.
    METHODS:
      preparedata REDEFINITION,
      mapping_bo REDEFINITION,
      exe_bo REDEFINITION,
      mapping_bo_sec REDEFINITION,
      exe_bo_sec REDEFINITION.
    METHODS mapping_reverse_sec REDEFINITION.
    METHODS exe_anulation_bo_sec REDEFINITION.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_proposal_bo_billingdoc IMPLEMENTATION.
  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_bd_parallel TYPE REF TO zcl_proposal_bo_bd_parallel.
    DATA lv_status_log TYPE c.
    DATA lt_billdoc TYPE TABLE FOR REPORTED EARLY i_billingdocumenttp\\billingdocument.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

*    CHECK gtd_list_bo IS NOT INITIAL.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst( EXPORTING p_in_tab  = gtd_list_bo
                               p_debug   = lv_debug
                     IMPORTING p_out_tab = DATA(L_out_tab) ).

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>)." WHERE inst IS NOT INITIAL.
      IF <l_out>-inst IS NOT INITIAL.
        lo_bd_parallel ?= <l_out>-inst.
      ELSE.
        lo_bd_parallel ?= gtd_list_bo[ <l_out>-index ].
        lt_billdoc = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                    number   = '022'
                                                    severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
            it_reported   = lt_billdoc
          CHANGING
            ct_map_id_doc = lo_bd_parallel->gt_doc_map_bd
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype       = zcl_proposal_bo_abs=>c_document_type-billingdocument
                               iv_status        = zcl_proposal_bo_abs=>c_document_status-error
                               iv_parentdockey  = lo_bd_parallel->gt_doc_map_bd[ 1 ]-ParentDocumentKey
                               iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
                               iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                               iv_isadjustment  = space
                               its_doc          = gts_doc
                               iv_byuser        = lv_byuser
                               iv_attime        = lv_attime
                     CHANGING  ct_map_id_doc    = lo_bd_parallel->gt_doc_map_bd ).
      ENDIF.
      APPEND LINES OF lo_bd_parallel->gt_doc_map_bd TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.

  METHOD preparedata.
    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>).
      DATA(ls_doc_bd) = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                             item_id       = <fs_items>-item_id
                                             Itembasis_Id  = <fs_items>-itembasis_id
                                             Itemcalc_Id   = <fs_items>-itemcalc_id
                                             Documenttype = zcl_proposal_bo_abs=>c_document_type-billingdocument ] OPTIONAL ).
      IF ls_doc_bd IS INITIAL."Si no tiene factura a reprocesar se tiene que buscar la orden
        ls_doc_bd = VALUE #( gtd_doc_bd[ id           = <fs_items>-id
                                         item_id       = <fs_items>-item_id
                                         Itembasis_Id  = <fs_items>-itembasis_id
                                         Itemcalc_Id   = <fs_items>-itemcalc_id
                                         Documenttype = zcl_proposal_bo_abs=>c_document_type-salesorder ] OPTIONAL ).
        IF ls_doc_bd IS NOT INITIAL."Si encuentra orden de venta
          APPEND INITIAL LINE TO gt_doc_map_so ASSIGNING FIELD-SYMBOL(<fs_doc_map_so>).
          <fs_doc_map_so>-id          = <fs_items>-id.
          <fs_doc_map_so>-item_id      = <fs_items>-item_id.
          <fs_doc_map_so>-Itembasis_Id = <fs_items>-itembasis_id.
          <fs_doc_map_so>-Itemcalc_Id  = <fs_items>-itemcalc_id.
          <fs_doc_map_so>-Documentkey = ls_doc_bd-Documentkey.
          <fs_doc_map_so>-Documenttype  = ls_doc_bd-Documenttype.
        ENDIF.
      ELSEIF ls_doc_bd-Documentkey(5) = 'DUMMY'."Si existe una factura a reprocesar (creada pero no facturada) se tiene que validar que sea una factura DUMMY
        APPEND INITIAL LINE TO gt_doc_map_so ASSIGNING <fs_doc_map_so>.
        <fs_doc_map_so>-id          = <fs_items>-id.
        <fs_doc_map_so>-item_id      = <fs_items>-item_id.
        <fs_doc_map_so>-Itembasis_Id = <fs_items>-itembasis_id.
        <fs_doc_map_so>-Itemcalc_Id  = <fs_items>-itemcalc_id.
        <fs_doc_map_so>-Documentkey = ls_doc_bd-Documentkey.
        <fs_doc_map_so>-Documenttype  = ls_doc_bd-Documenttype.
      ENDIF.
    ENDLOOP.
*    APPEND LINES OF gtd_doc_bd TO gt_doc_map_so.
  ENDMETHOD.
  METHOD mapping_bo.
    DATA ls_doc_bd TYPE LINE OF gtty_doc.
    DATA lv_line_exists TYPE c.
    DATA lv_prevdockey TYPE zfi_a_intrc_cpid-documentkey.

    CHECK gt_doc_map_so IS NOT INITIAL.
    LOOP AT gt_doc_map_so ASSIGNING FIELD-SYMBOL(<fs_doc_map_so>).
      CLEAR lv_line_exists.
      IF <fs_doc_map_so>-Documentkey(5) EQ 'DUMMY'
       AND <fs_doc_map_so>-Documenttype = zcl_proposal_bo_abs=>c_document_type-salesorder.
        CONTINUE.
      ENDIF.
      IF <fs_doc_map_so>-Documenttype = zcl_proposal_bo_abs=>c_document_type-billingdocument.
        ls_doc_bd-Documentkey = |DUMMY{ <fs_doc_map_so>-ParentDocumentkey }|.
        ls_doc_bd-ParentDocumentKey  = <fs_doc_map_so>-ParentDocumentkey.
        DATA(lv_so) = CONV gsty_bd_create_ref-SDDocument( <fs_doc_map_so>-ParentDocumentkey ).
        IF line_exists( gt_doc_map_bd[ documentkey = lv_so ] ).
          lv_line_exists = abap_true.
        ENDIF.
      ELSE.
        ls_doc_bd-Documentkey = |DUMMY{ <fs_doc_map_so>-Documentkey }|.
        ls_doc_bd-ParentDocumentKey  = <fs_doc_map_so>-Documentkey.
        lv_so = CONV gsty_bd_create_ref-SDDocument( <fs_doc_map_so>-Documentkey ).
        IF line_exists( gt_doc_map_bd[ ParentDocumentKey = lv_so ] ).
          lv_line_exists = abap_true.
        ENDIF.
      ENDIF.

      IF lv_line_exists EQ abap_false.
        IF gta_bdfromsd[] IS NOT INITIAL.
          DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_bd_parallel(
            it_doc          = gtd_doc_bd
            its_doc         = gts_doc_bd
            it_doc_map      = gt_doc_map_bd
            iv_parentdockey = lv_prevdockey
            ita_bdfromsd    = gta_bdfromsd
            iv_process      = gv_process_bd ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

          FREE: gta_bdfromsd.
        ENDIF.
        gta_bdfromsd = VALUE #(
                        ( %cid   = |SD{ sy-tabix }|
                          %param = VALUE #( _reference = VALUE #( ( SDDocument = lv_so
                                                                    %control   = VALUE #( SDDocument = if_abap_behv=>mk-on ) ) )
                                            %control   = VALUE #( _reference = if_abap_behv=>mk-on ) ) ) ).
        FREE: gt_doc_map_bd.
        lv_prevdockey = lv_so.
      ENDIF.

      ls_doc_bd-id          = <fs_doc_map_so>-id.
      ls_doc_bd-item_id      = <fs_doc_map_so>-item_id.
      ls_doc_bd-Itembasis_Id = <fs_doc_map_so>-Itembasis_Id.
      ls_doc_bd-Itemcalc_Id  = <fs_doc_map_so>-Itemcalc_Id.
      ls_doc_bd-Documenttype  = zcl_proposal_bo_abs=>c_document_type-billingdocument.
      ls_doc_bd-ParentDocumentType  = zcl_proposal_bo_abs=>c_document_type-salesorder.
      APPEND ls_Doc_bd TO gt_doc_map_bd.

    ENDLOOP.
    IF gta_bdfromsd[] IS NOT INITIAL.
      lo_proposal_paralel = NEW zcl_proposal_bo_bd_parallel(
        it_doc          = gtd_doc_bd
        its_doc         = gts_doc_bd
        it_doc_map      = gt_doc_map_bd
        iv_parentdockey = ls_doc_bd-ParentDocumentKey
        ita_bdfromsd    = gta_bdfromsd
        iv_process      = gv_process_bd ).

      INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

      FREE: gta_bdfromsd,
            gt_doc_map_bd.
    ENDIF.
    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( )."Return the data on me->gt_doc_map
    et_doc_map = me->gt_doc_map.
    IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.
  ENDMETHOD.

  METHOD constructor.
    super->constructor( is_header      = is_header
                        it_items       = it_items
                        it_bases       = it_bases
                        it_calc        = it_calc
                        it_doc         = it_doc
                        it_anul_doc    = it_anul_doc
                        its_doc        = its_doc
                        it_doc_map     = it_doc_map
                        iv_process     = iv_process
                        iv_documentkey = iv_documentkey ).
    gtd_doc_bd    = it_doc.
    gts_doc_bd    = its_doc.
    gt_doc_map_so = it_doc_map.
    gv_process_bd = iv_process.
  ENDMETHOD.

  METHOD exe_bo_sec.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-DocumentKey.
    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
*    DATA lt_msg    TYPE TABLE FOR REPORTED LATE I_BillingDocumentTP\\BillingDocument.

    MODIFY ENTITIES OF I_BillingDocumentTP
           ENTITY BillingDocument
           EXECUTE CreateFromSDDocument FROM gta_bdfromsd
           RESULT DATA(lt_result_modify)
           FAILED DATA(ls_failed)
           REPORTED DATA(ls_reported).

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES BEGIN
             RESPONSE OF I_BillingDocumentTP
             FAILED DATA(ls_save_failed)
             REPORTED DATA(ls_save_reported).
      LOOP AT lt_result_modify ASSIGNING FIELD-SYMBOL(<fs_BillingDoc>).
        CONVERT KEY OF I_BillingDocumentTP FROM <fs_BillingDoc>-%param-%pid TO DATA(ls_so_final_key).
        <fs_BillingDoc>-%param-BillingDocument = ls_so_final_key-BillingDocument.
        IF ls_save_failed-BillingDocument IS NOT INITIAL.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
          CLEAR lv_dockey.
        ELSE.
          lv_status_doc = zcl_proposal_bo_abs=>c_document_status-commit.
          lv_dockey = ls_so_final_key.
        ENDIF.
*        APPEND LINES OF ls_save_reported-BillingDocument TO lt_msg.

      ENDLOOP.
      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                 it_reported   = ls_save_reported-BillingDocument
                       CHANGING  ct_map_id_doc = ct_map_id_doc
                                 cv_status     = lv_status_log ).
      COMMIT ENTITIES END.
    ELSE.
      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey     = lv_dockey
                                 iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                 it_reported   = ls_reported-BillingDocument
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
                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
    ev_document = lv_dockey.
  ENDMETHOD.

  METHOD mapping_bo_sec.
*    DATA lv_doc TYPE gsty_bd_create_ref-SDDocument.

    LOOP AT it_parentdocument ASSIGNING FIELD-SYMBOL(<fS_PARENT>).
*     loop at gt_doc_map_bd ASSIGNING FIELD-SYMBOL(<fS_PARENT>).

*      lv_doc = <fS_PARENT>.
      DATA(lv_doc) = CONV gsty_bd_create_ref-SDDocument( <fS_PARENT> ).
      IF lv_doc IS NOT INITIAL.
        gta_bdfromsd = VALUE #(
            ( %cid   = |SD{ sy-tabix }|
              %param = VALUE #( _reference = VALUE #( ( SDDocument = lv_doc
                                                        %control   = VALUE #( SDDocument = if_abap_behv=>mk-on ) ) )
                                %control   = VALUE #( _reference = if_abap_behv=>mk-on ) ) ) ).
      ENDIF.
    ENDLOOP.

    me->exe_bo_sec( IMPORTING et_document   = gtd_documentkey
                    CHANGING  ct_map_id_doc = gt_doc_map_bd ).
*    save_log( ).
  ENDMETHOD.

  METHOD mapping_reverse_sec.
    DATA ls_doc_bd TYPE LINE OF gtty_doc.
    DATA lv_prevdockey TYPE zfi_a_intrc_cpid-documentkey.

    CHECK gtd_doc_bd IS NOT INITIAL.
    "TODOS LOS DOCUMENTOS YA DEBEN VENIR FILTRADOS (NO DUMMY)
    LOOP AT gtd_doc_bd ASSIGNING FIELD-SYMBOL(<fs_doc_bd>).
*      FREE: gta_bdcanceldoc, gt_doc_map_bd.
      CHECK NOT line_exists( gtd_anul_doc[ ParentDocumentKey = <fs_doc_bd>-Documentkey ] )
      OR gtd_anul_doc[ ParentDocumentKey = <fs_doc_bd>-Documentkey ]-Documentkey(5) EQ 'DUMMY'.

      IF NOT line_exists( gt_doc_map_bd[ ParentDocumentKey = <fs_doc_bd>-Documentkey ] ).
        IF gta_BDCancelDoc[] IS NOT INITIAL.
          DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_bd_parallel(
            it_doc          = gtd_doc_bd
            its_doc         = gts_doc_bd
            it_doc_map      = gt_doc_map_bd
            iv_parentdockey = lv_prevdockey
            ita_BDCancelDoc = gta_BDCancelDoc
            iv_process      = gv_process_bd ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

          FREE: gta_BDCancelDoc.
        ENDIF.
        gta_BDCancelDoc = VALUE #(
                        ( %cid                  = |BD{ sy-tabix }|
                          BillingDocument       = <fs_doc_bd>-Documentkey
                          %param-ReversalReason = me->gc_reversalreason ) ).
        FREE: gt_doc_map_bd.
        lv_prevdockey = <fs_doc_bd>-Documentkey.
      ENDIF.
      ls_doc_bd-id          = <fs_doc_bd>-id.
      ls_doc_bd-item_id      = <fs_doc_bd>-item_id.
      ls_doc_bd-Itembasis_Id = <fs_doc_bd>-Itembasis_Id.
      ls_doc_bd-Itemcalc_Id  = <fs_doc_bd>-Itemcalc_Id.
      ls_doc_bd-Documenttype  = zcl_proposal_bo_abs=>c_document_type-anul_billdoc.
      ls_doc_bd-ParentDocumentType  = zcl_proposal_bo_abs=>c_document_type-billingdocument.
      ls_doc_bd-Documentkey = |DUMMY{ <fs_doc_bd>-Documentkey }|.
      ls_doc_bd-ParentDocumentKey  = <fs_doc_bd>-Documentkey.
      APPEND ls_Doc_bd TO gt_doc_map_bd.
    ENDLOOP.
    IF gta_BDCancelDoc[] IS NOT INITIAL.
      lo_proposal_paralel = NEW zcl_proposal_bo_bd_parallel(
        it_doc          = gtd_doc_bd
        its_doc         = gts_doc_bd
        it_doc_map      = gt_doc_map_bd
        iv_parentdockey = ls_doc_bd-ParentDocumentKey
        ita_BDCancelDoc = gta_BDCancelDoc
        iv_process      = gv_process_bd ).

      INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

      FREE: gta_BDCancelDoc,
            gt_doc_map_bd.
    ENDIF.
    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( )."Return the data on me->gt_doc_map
    et_doc_map = me->gt_doc_map.
    IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.
*    gta_BDCancelDoc = VALUE #( FOR lwa IN gtd_doc_bd
*                               ( BillingDocument       = lwa-Documentkey
*                                 %param-ReversalReason = me->gc_reversalreason )
*                             ).
*    exe_anulation_bo_sec( CHANGING ct_map_id_doc = gt_doc_map_bd ).
*
*    et_doc_map = me->gt_doc_map_bd.
  ENDMETHOD.

  METHOD exe_anulation_bo_sec.
*    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
*    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
*
*    MODIFY ENTITY I_BillingDocumentTP
*           EXECUTE CreateCancellationDocument AUTO FILL CID
*           WITH gta_BDCancelDoc
*           FAILED DATA(ls_failed)
*           REPORTED DATA(ls_reported)
*           MAPPED DATA(ls_mapped).
*
*    IF ls_failed IS NOT INITIAL.
*      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
*      IF ls_reported-billingdocument IS NOT INITIAL.
**      LOOP AT ls_reported-billingdocument INTO DATA(ls_billdoc).
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported-billingdocument
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
**      ENDLOOP.
*      ENDIF.
*      IF ls_reported-billingdocumentitem IS NOT INITIAL.
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported-billingdocumentitem
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
*      ENDIF.
*      RETURN.
*    ELSE.
*      " The below method saves the billing documents.
*      COMMIT ENTITIES
*             RESPONSE OF I_BillingDocumentTP
*             " TODO: variable is assigned but never used (ABAP cleaner)
*             REPORTED DATA(ls_reported_commit).
*
*      IF sy-subrc <> 0.
*        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
*
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported_commit-billingdocument
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
*      ELSE.
*        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-anulated.
*
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported_commit-billingdocument
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
*      ENDIF.
*
*    ENDIF.
*    IF lv_status_log EQ 'E'.
*      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error.
*    ENDIF.
*
*    mapping_doc( EXPORTING iv_doctype       = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
*                           iv_status        = lv_status_doc
*                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
*                           iv_isadjustment  = space
*                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
  ENDMETHOD.

ENDCLASS.
