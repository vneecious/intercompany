CLASS lsc_zi_intercoproposal DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_intercoproposal IMPLEMENTATION.

  METHOD save_modified.
    DATA: lt_proposal TYPE STANDARD TABLE OF zi_intercoproposal.

    IF update-zi_intercoproposal IS NOT INITIAL.
      lt_proposal = CORRESPONDING #( update-zi_intercoproposal ).
      READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

      "Call Event - Background Process"
      IF ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-invoicing_started
      OR ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_started
      OR ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-test_invoicing.
        RAISE ENTITY EVENT zi_intercoproposal~commited
           FROM VALUE #( ( id = ls_proposal->id ) ).

      ELSEIF ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-anulation_started
      OR ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-test_anulation.
        RAISE ENTITY EVENT zi_intercoproposal~reversed
           FROM VALUE #( ( id = ls_proposal->id ) ).
*      ELSEIF ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-test_invoicing.
*        RAISE ENTITY EVENT zi_intercoproposal~testing
*           FROM VALUE #( ( id = ls_proposal->id ) ).
*      ELSEIF ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-anulation_started.
*        RAISE ENTITY EVENT zi_intercoproposal~reversed
*         FROM VALUE #( ( id = ls_proposal->id ) ).
      ENDIF.

      IF ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_started.

        RAISE ENTITY EVENT zi_intercoproposal~simulated
        FROM VALUE #( ( id = ls_proposal->id ) ).

      ENDIF.

      IF ls_proposal->isdeleted = abap_true OR ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-anulated.
        RAISE ENTITY EVENT zi_intercoproposal~deleted
         FROM VALUE #( ( id = ls_proposal->id ) ).
      ENDIF.

      IF ( ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoiced OR
           ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-anulated )
           AND ls_proposal->isdeleted IS INITIAL.
        RAISE ENTITY EVENT zi_intercoproposal~finished
          FROM VALUE #( ( id = ls_proposal->id ) ).
      ENDIF.

    ENDIF.
  ENDMETHOD.

ENDCLASS.

*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
CLASS lhc_zi_intercoproposal DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: gtty_proposal_items_basis     TYPE STANDARD TABLE OF zfi_a_intrc_cpib WITH DEFAULT KEY,
           gtty_proposal_items_baogl     TYPE TABLE FOR READ RESULT zi_intercoproposalitembaoglac,
           gtty_proposal                 TYPE STANDARD TABLE OF zfi_a_intrc_cph WITH DEFAULT KEY,
           gtty_proposal_upd             TYPE TABLE FOR UPDATE zi_intercoproposal,
           gtty_proposal_items           TYPE STANDARD TABLE OF zfi_a_intrc_cpi WITH DEFAULT KEY,
           gtty_proposal_items_upd       TYPE TABLE FOR UPDATE zi_intercoproposalitem,
           gtty_proposal_items_basis_upd TYPE TABLE FOR UPDATE zi_intercoproposalitembasis,
           gtty_proposal_items_baogl_upd TYPE TABLE FOR UPDATE zi_intercoproposalitembaoglac,
           gtty_proposal_read            TYPE STRUCTURE FOR READ RESULT zi_intercoproposal,
           gty_proposal_item_gl          TYPE zi_intercoproposalitemorglacct,
           gtty_roposalitembycebe        TYPE STANDARD TABLE OF zi_intercoproposalitembycebe,
           gtty_proposal_item_gl         TYPE STANDARD TABLE OF gty_proposal_item_gl  WITH DEFAULT KEY.
    TYPES lty_failed_proposal TYPE RESPONSE FOR FAILED EARLY zi_intercoproposal.
    TYPES lty_reported_proposal TYPE RESPONSE FOR REPORTED EARLY zi_intercoproposal.


    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercoproposal RESULT result.
    METHODS invoice FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~invoice.

    METHODS simulate FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~simulate.

    METHODS setdelete FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~setdelete.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_intercoproposal RESULT result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE zi_intercoproposal.

    METHODS applymetric FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~applymetric RESULT result.
    METHODS calculate FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~calculate RESULT result.
    METHODS check FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~check RESULT result.
    METHODS commit FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~commit RESULT result.
    METHODS setappliedmetric FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~setappliedmetric RESULT result.

    METHODS committest FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~committest RESULT result.
    METHODS reverse FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~reverse RESULT result.
    METHODS anulatetest FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~anulatetest RESULT result.
    METHODS reverseitem FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposalitem~reverseitem RESULT result.
    METHODS getdocumentflow FOR READ
      IMPORTING keys FOR FUNCTION zi_intercoproposal~getdocumentflow RESULT result.
    METHODS callevent FOR READ
      IMPORTING keys FOR FUNCTION zi_intercoproposal~callevent RESULT result.
    METHODS get_instance_authorizations_1 FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercoproposalitem RESULT result.
    METHODS simulation FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercoproposal~simulation RESULT result.

*    METHODS getregionalmetrics FOR READ
*      IMPORTING keys FOR FUNCTION zi_intercoproposal~getregionalmetrics RESULT result.
    METHODS getavailablemetrics FOR READ
      IMPORTING keys FOR FUNCTION zi_intercoproposal~GetAvailableMetrics RESULT result.
    METHODS applyexchangerate
      IMPORTING it_proposal_items_basis        TYPE gtty_proposal_items_basis
                is_proposal                    TYPE REF TO gtty_proposal_read
      CHANGING  cs_failed                      TYPE lty_failed_proposal
                cs_reported                    TYPE lty_reported_proposal
      RETURNING VALUE(rt_proposal_items_basis) TYPE gtty_proposal_items_basis.

    METHODS prepareproposaltoupd
      IMPORTING it_proposal        TYPE gtty_proposal
                iv_proposal_status TYPE zint_dte_cph_status
      RETURNING VALUE(rt_proposal) TYPE gtty_proposal_upd.

    METHODS prepareproposalitemstoupd_cebe
      IMPORTING it_proposal_items        TYPE gtty_proposal_items
                it_cebe_items            TYPE gtty_roposalitembycebe
      RETURNING VALUE(rt_proposal_items) TYPE gtty_proposal_items_upd.

    METHODS prepareproposalitemstoupd
      IMPORTING it_proposal_items        TYPE gtty_proposal_items
      RETURNING VALUE(rt_proposal_items) TYPE gtty_proposal_items_upd.

    METHODS prepareproposalitemsbasistoupd
      IMPORTING it_proposal_item_basis        TYPE gtty_proposal_items_basis
      RETURNING VALUE(rt_proposal_item_basis) TYPE gtty_proposal_items_basis_upd.

    METHODS prepare_pibglaccupd
      IMPORTING it_proposal_item_baoglacc        TYPE gtty_proposal_items_baogl
      RETURNING VALUE(rt_proposal_item_baoglacc) TYPE gtty_proposal_items_baogl_upd.

    METHODS cleanproposalitembasis
      IMPORTING iv_proposalid     TYPE uuid
                it_proposal_items TYPE gtty_proposal_items_upd.
    METHODS get_proposal_item_gl
      IMPORTING
        it_proposal_items_basis    TYPE gtty_proposal_items_basis
      RETURNING
        VALUE(rt_proposal_item_gl) TYPE gtty_proposal_item_gl.

*Ini EXT_OSCUGALD 05.02.2026 - Genova MLA
    METHODS get_proposal_item_gl_genova
      IMPORTING
        it_proposal_items_basis    TYPE gtty_proposal_items_basis
        it_proposal_item           TYPE ANY TABLE
      RETURNING
        VALUE(rt_proposal_item_gl) TYPE gtty_proposal_item_gl.
*Fin EXT_OSCUGALD 05.02.2026 - Genova MLA
    "--- Nuevo TYPE a agregar en PRIVATE SECTION junto a los demás: ---
    TYPES: gtty_companies       TYPE STANDARD TABLE OF zi_intercocompanycode WITH DEFAULT KEY,
           gtty_items_basis_upd TYPE TABLE FOR CREATE zi_intercoproposalitem\_proposalitemsbasis,
           gtty_items_bg_upd    TYPE TABLE FOR CREATE zi_intercoproposalitembasis\_proposalitemsbaoglac.

    TYPES: gtty_proposal_item_read TYPE TABLE FOR READ RESULT zi_intercoproposalitem.
    METHODS apply_local_metric
      IMPORTING
        is_proposal             TYPE REF TO gtty_proposal_read
        it_proposal_item        TYPE gtty_proposal_item_read
        iv_product_metric       TYPE matkl
        iv_param                TYPE zstr_metric_param
      CHANGING
        ct_proposal_items_basis TYPE gtty_proposal_items_basis
        ct_proposal_items_upd   TYPE gtty_proposal_items_upd
        ct_proposal_upd         TYPE gtty_proposal_upd
        ct_items_basis_upd      TYPE gtty_items_basis_upd
        ct_items_bg_upd         TYPE gtty_items_bg_upd
        cs_failed               TYPE lty_failed_proposal
        cs_reported             TYPE lty_reported_proposal.

*Ini EXT_OSCUGALD - Bermudas MIC-USA (SDFPSINIC-23362)
    "── Motor de cálculo: Operating Income → ISAC NCP → dirección / regalía ────
    METHODS apply_mic_metric
      IMPORTING is_proposal             TYPE REF TO gtty_proposal_read
                it_proposal_item        TYPE gtty_proposal_item_read
                iv_param                TYPE zstr_metric_param
      CHANGING  ct_proposal_items_basis TYPE gtty_proposal_items_basis
                ct_proposal_items_upd   TYPE gtty_proposal_items_upd
                ct_proposal_upd         TYPE gtty_proposal_upd
                ct_items_basis_upd      TYPE gtty_items_basis_upd
                cs_failed               TYPE lty_failed_proposal
                cs_reported             TYPE lty_reported_proposal.
*Fin EXT_OSCUGALD - Bermudas MIC-USA
ENDCLASS.

CLASS lhc_zi_intercoproposal IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.

    CONSTANTS:
      BEGIN OF c_status,
        pending          TYPE zi_intercoproposal-status VALUE ' ',
        metric_applied   TYPE zi_intercoproposal-status VALUE 'V',
        calculated       TYPE zi_intercoproposal-status VALUE 'C',
        invoice_finished TYPE zi_intercoproposal-status VALUE 'I',
        invoice_error    TYPE zi_intercoproposal-status VALUE 'E',
      END OF c_status.

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
        FIELDS ( status isdeleted )
        WITH CORRESPONDING #( keys )
        RESULT DATA(current_proposals).


    LOOP AT current_proposals REFERENCE INTO DATA(current_proposal).
      DATA(can_applymetric) = COND #( WHEN current_proposal->isdeleted IS INITIAL
                                           AND current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-pending
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled ).
*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
*   Excluir status Concluido (G) de Calculate: propuesta sin basis ni docs.
*   La constante c_proposal_status-concluded puede valer '' en esta versión
*   de la clase abs, por eso se compara contra el literal 'G' como resguardo.
      DATA(can_calculate) = COND #( WHEN current_proposal->isdeleted IS INITIAL
                                         AND current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-verified
                                         AND current_proposal->status <> 'G'
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled ).
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
      DATA(can_commit) = COND #( WHEN current_proposal->isdeleted IS INITIAL
                                    AND (    current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-calculated
                                          OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoicing_error
                                          OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_error
                                          OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_ok
                                          OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_error )
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).
      DATA(can_reverse) = COND #( WHEN current_proposal->isdeleted IS INITIAL AND
                                       (    current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoiced
                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoicing_error
                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-reinvoiced
                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_error
*                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_ok  "
*                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_error
                                         OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-anulation_error )
                                  THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
*      DATA(can_setdelete) = COND #( WHEN current_proposal->isdeleted IS INITIAL AND
*                                         (    current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-pending
*                                           OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-verified
*                                           OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-calculated )
*                                    THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      DATA(can_setdelete) = if_abap_behv=>fc-o-enabled.
      DATA(can_simulate) = COND #(  WHEN current_proposal->isdeleted IS INITIAL AND current_proposal->status = c_status-calculated THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
*      DATA(can_delete) = COND #( WHEN current_proposal->isdeleted = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      DATA(can_delete) = COND #( WHEN current_proposal->isdeleted IS NOT INITIAL AND
                                               (    current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-pending
                                                 OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-verified
                                                 OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_ok  "
                                                 OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_error
                                                 OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-calculated
*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
                                                 OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-concluded )
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      DATA(can_simulation) = COND #( WHEN current_proposal->isdeleted IS INITIAL
                                       AND (    current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-calculated
                                             OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_ok
                                             OR current_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-simulation_error )
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled ).

      IF sy-uname CS 'EXT_'.
        DATA(can_committest) = if_abap_behv=>fc-o-enabled.
        DATA(can_anulatetest) = if_abap_behv=>fc-o-enabled.
      ELSE.
        can_committest = if_abap_behv=>fc-o-disabled.
        can_anulatetest = if_abap_behv=>fc-o-disabled.
      ENDIF.

      APPEND VALUE #(
       %tky                = current_proposal->%tky
       %key                = current_proposal->%key
       %pky                = current_proposal->%pky
       %action-applymetric = can_applymetric
       %action-commit      = can_commit
       %action-setdelete   = can_setdelete
       %action-calculate   = can_calculate
       %action-reverse     = can_reverse
       %action-simulate    = can_simulate
       %action-committest  = can_committest
       %action-anulatetest = can_anulatetest
       %action-simulation  = can_simulation
       %delete             = can_delete ) TO result.

    ENDLOOP.


  ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
       ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys )
       RESULT DATA(lt_proposal).

    LOOP AT lt_proposal INTO DATA(ls_proposal).
      IF ls_proposal-isdeleted = abap_false.
        APPEND VALUE #( %key = ls_proposal-%key ) TO failed-zi_intercoproposal.
        APPEND VALUE #( %key = ls_proposal-%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '020' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setdelete.

    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
            UPDATE FIELDS ( isdeleted )
                WITH VALUE #( FOR key IN keys ( %tky = key-%tky isdeleted = abap_true ) )
        FAILED failed
        REPORTED reported.

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal ALL FIELDS
            WITH CORRESPONDING #( keys )
                RESULT DATA(lt_proposal).

    DELETE lt_proposal WHERE isdeleted IS INITIAL.

  ENDMETHOD.

  METHOD simulate.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
              ENTITY zi_intercoproposal
              FIELDS ( status )
              WITH CORRESPONDING #( keys )
           RESULT DATA(lt_proposal)
           FAILED DATA(lt_proposal_failed).

    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

    IF ls_proposal->status NE '' AND ls_proposal->status NE 'S'.
      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '003' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
    ELSE.

    ENDIF.
  ENDMETHOD.

  METHOD applymetric.
    TYPES: BEGIN OF ty_itemorglacct_aux,
             id               TYPE uuid,
             itemid           TYPE zde_prop_item_id,
             glaccount        TYPE hkont,
             costcenter       TYPE kostl,
             globalcurrency_c TYPE zint_dte_fis_ksl,
             globalcurrency_h TYPE zint_dte_fis_ksl,
             globalcurrency_l TYPE zint_dte_fis_ksl,
             percentoftotal   TYPE zde_per_from_total,
             costcenterd4     TYPE n LENGTH 1,
           END OF ty_itemorglacct_aux.
    DATA: lt_itemorglacct_aux TYPE STANDARD TABLE OF ty_itemorglacct_aux,
          ls_itemorglacct_aux TYPE ty_itemorglacct_aux.

    DATA: lt_metric_items_calc        TYPE zcl_interco_btp_cap_metric_api=>tt_item_calculated,
          ls_metric_item_calc         TYPE zcl_interco_btp_cap_metric_api=>ty_item_calculated,
          lt_proposal_items_basis     TYPE STANDARD TABLE OF zfi_a_intrc_cpib,
          lt_proposal_items_basis_aux TYPE STANDARD TABLE OF zfi_a_intrc_cpib,
          lt_proposal_items_basis_upd TYPE TABLE FOR CREATE zi_intercoproposalitem\_proposalitemsbasis,
          lt_proposal_items_bg_upd    TYPE TABLE FOR CREATE zi_intercoproposalitembasis\_proposalitemsbaoglac,
          lt_items_org_gl_create      TYPE TABLE FOR CREATE zi_intercoproposalitem\_proposalitemsdetails, "EXT_OSCUGALD -  Genova MLA
          lv_itembasis_id             TYPE int8 VALUE 0,
          ls_proposalitem             TYPE ZI_IntercoProposalItem,
          lt_items_to_create          TYPE TABLE FOR CREATE zi_intercoproposal\_items,  "EXT_OSCUGALD -  Genova MLA
          lt_proposal_items_upd       TYPE gtty_proposal_items_upd,   "← agregar
          lt_proposal_upd             TYPE gtty_proposal_upd.         "← agregar

    " Vinicius - TODO - El usuario podra ejecutar masivamente ->
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).
    DATA(ls_param) = <fs_key>-%param.  "regional metric

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         ENTITY zi_intercoproposal BY \_items  ALL FIELDS WITH VALUE #( ( %key-id = <fs_key>-id ) ) RESULT FINAL(lt_proposal_item_ref)
         FAILED DATA(lt_proposal_failed).

    "   Declaramos una tabla interna modificable con el mismo tipo
    DATA: lt_proposal_item     LIKE lt_proposal_item_ref,
          ls_proposal_item_aux LIKE LINE OF lt_proposal_item.
    DATA(lv_new_299) = abap_false.
    lt_proposal_item = lt_proposal_item_ref.

    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

    SELECT Id, ProfitCenter, Baseamountprofitcenter, BaseamountprofitcenterH, BaseamountprofitcenterL
            FROM zi_intercoproposalitembycebe
            FOR ALL ENTRIES IN @lt_proposal_item
            WHERE id = @lt_proposal_item-id
            INTO TABLE @DATA(lt_cebe_items).

    SELECT companycode, currency FROM zi_intercocompanycode
          FOR ALL ENTRIES IN @lt_proposal_item
          WHERE companycode = @lt_proposal_item-recipientcompanycode
          INTO TABLE @DATA(lt_companies).

*Ini EXT_OSCUGALD 04.02.2026 - Genova MLA
    READ TABLE lt_proposal_item_ref INTO DATA(ls_proposal_item_ref) WITH KEY cebe_aux = '299'.
    IF sy-subrc NE 0.
      READ TABLE lt_cebe_items INTO DATA(ls_cebes) WITH KEY profitcenter = '0000000299'.
      IF sy-subrc EQ 0.
        SELECT Id, ItemId, RecipientCompanyCode, Cebe_Aux
        FROM ZI_IntercoProposalItemAux
        WHERE Id = @ls_proposal->Id
          AND Cebe_Aux = '299'
          INTO TABLE @DATA(lt_proposalitemaux).

        SORT lt_proposalitemaux BY itemid RecipientCompanyCode ASCENDING.
        DELETE ADJACENT DUPLICATES FROM lt_proposalitemaux COMPARING ALL FIELDS.

        " Determinamos el punto de partida para los nuevos IDs
        DATA(lv_next_item_id) = lines( lt_proposal_item_ref ).
        DATA lv_company_curr TYPE waers.
        lv_new_299 = abap_true.
        LOOP AT lt_proposalitemaux INTO DATA(ls_proposalitemaux).
          " Incrementamos el ID para cada nuevo registro
          lv_next_item_id += 1.

          " Construimos el registro para CREACIÓN
          APPEND INITIAL LINE TO lt_items_to_create ASSIGNING FIELD-SYMBOL(<ls_create_root>).
          <ls_create_root>-id = ls_proposal->Id.

          APPEND INITIAL LINE TO <ls_create_root>-%target ASSIGNING FIELD-SYMBOL(<ls_new_item>).

          " --- AJUSTE CLAVE: %cid basado en el nuevo item_id ---
          <ls_new_item>-%cid = |NEW_ITEM_299_{ lv_next_item_id }|.
          <ls_new_item>-Id = ls_proposal->Id.
          <ls_new_item>-item_id = lv_next_item_id.
          " ----------------------------------------------------

          <ls_new_item>-recipientcompanycode = ls_proposalitemaux-RecipientCompanyCode.
          <ls_new_item>-profitcenter = '0000000299'.
          <ls_new_item>-basecurrencyprofitcenter = 'USD'.
          <ls_new_item>-baseamountprofitcenterc = ls_cebes-Baseamountprofitcenter.
          <ls_new_item>-baseamountprofitcenterh = ls_cebes-BaseamountprofitcenterH.
          <ls_new_item>-baseamountprofitcenterl = ls_cebes-BaseamountprofitcenterL.
          <ls_new_item>-baseamountprofitcenter = <ls_new_item>-baseamountprofitcenterc + <ls_new_item>-baseamountprofitcenterh + <ls_new_item>-baseamountprofitcenterl.

          IF ls_proposalitemaux-RecipientCompanyCode EQ 'MLA'.
            <ls_new_item>-interdivisional = abap_true.
          ENDIF.

          ls_proposal_item_aux-Id = ls_proposal->Id.
          ls_proposal_item_aux-Item_Id = lv_next_item_id.
          ls_proposal_item_aux-ProviderCompanyCode = ls_proposal->providercompanycode.
          ls_proposal_item_aux-recipientcompanycode = ls_proposalitemaux-RecipientCompanyCode.
          ls_proposal_item_aux-profitcenter = '0000000299'.
          ls_proposal_item_aux-cebe_aux = '299'.
          APPEND ls_proposal_item_aux TO lt_proposal_item.

        ENDLOOP.
      ENDIF.
    ENDIF.
*Fin EXT_OSCUGALD 04.02.2026 - Genova MLA

*    SELECT companycode, currency FROM zi_intercocompanycode
*          FOR ALL ENTRIES IN @lt_proposal_item
*          WHERE companycode = @lt_proposal_item-recipientcompanycode
*          INTO TABLE @DATA(lt_companies).

    SELECT SINGLE zi_intercoproduct~metric
      FROM zi_intercoproduct
      WHERE product EQ @ls_proposal->product
      INTO @DATA(lv_product_metric).

    IF lv_product_metric IS INITIAL.
      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '014' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
      RETURN.
    ENDIF.

    " IC = CX (Customer Experience), CS = Generales → ambos usan métrica local
    DATA lv_is_local TYPE abap_boolean VALUE abap_false.
    IF lv_product_metric = 'IC' OR lv_product_metric = 'CS'.
      lv_is_local = abap_true.
    ENDIF.

*Ini EXT_OSCUGALD - Bermudas MIC-USA (SDFPSINIC-23362)
*  Dispatch por iniciativa: SM tiene flujo propio (ISAC NCP + dirección
*  dinámica + status Concluido). Sale por su método dedicado y NO recorre
*  el flujo clásico de abajo (TF / local IC-CS / regional / Genova).
    IF lv_product_metric = 'SM'.
      DATA lt_basis_mic     TYPE gtty_proposal_items_basis.
      DATA lt_item_upd_mic  TYPE gtty_proposal_items_upd.
      DATA lt_prop_upd_mic  TYPE gtty_proposal_upd.
      DATA lt_basis_upd_mic TYPE gtty_items_basis_upd.

      me->apply_mic_metric(
        EXPORTING
          is_proposal             = ls_proposal
          it_proposal_item        = CORRESPONDING #( lt_proposal_item[] )
          iv_param                = ls_param
        CHANGING
          ct_proposal_items_basis = lt_basis_mic
          ct_proposal_items_upd   = lt_item_upd_mic
          ct_proposal_upd         = lt_prop_upd_mic
          ct_items_basis_upd      = lt_basis_upd_mic
          cs_failed               = failed
          cs_reported             = reported ).

      IF failed-zi_intercoproposal IS NOT INITIAL.
*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
*   Leer la entidad desde el buffer RAP para que el result incluya el status
*   actualizado (G). Esto fuerza a Fiori Elements a refrescar los permisos
*   en pantalla sin necesidad de F5.
        READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
          ENTITY zi_intercoproposal ALL FIELDS
          WITH CORRESPONDING #( keys )
          RESULT DATA(lt_concl_result).
        result = VALUE #( FOR r IN lt_concl_result ( %tky = r-%tky %param = r ) ).
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
        RETURN.
      ENDIF.

      " Status "Concluido": solo cabecera, sin basis ni asientos.
      IF lt_basis_mic IS INITIAL.
        " IMPORTANTE: en este behavior managed, un UPDATE de SOLO la cabecera no
        " se persiste; el framework solo materializa el cambio del root cuando va
        " acompañado de un UPDATE/CREATE de una entidad hija (patron del flujo
        " clasico: siempre UPDATE cabecera + CREATE/UPDATE items/basis). Como
        " Concluido no genera basis, se acompaña con un UPDATE (no-op) del item
        " existente para forzar la materializacion del status. Se hace IN LOCAL
        " MODE igual que el resto de ramales que persisten OK.
        DATA lt_item_noop_mic TYPE gtty_proposal_items_upd.
        lt_item_noop_mic = CORRESPONDING #( lt_proposal_item[] ).
        LOOP AT lt_item_noop_mic ASSIGNING FIELD-SYMBOL(<fs_noop>).
          <fs_noop>-%control-recipientcompanycode = if_abap_behv=>mk-on.
        ENDLOOP.

        MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
          ENTITY zi_intercoproposal
            UPDATE FROM lt_prop_upd_mic
          ENTITY zi_intercoproposalitem
            UPDATE FROM lt_item_noop_mic
          REPORTED DATA(lt_rep_concl)
          FAILED   DATA(lt_fail_concl).
        IF lt_fail_concl-zi_intercoproposal IS NOT INITIAL.
          LOOP AT lt_fail_concl-zi_intercoproposal INTO DATA(ls_fail_concl).
            APPEND VALUE #( %tky = ls_fail_concl-%tky ) TO failed-zi_intercoproposal.
          ENDLOOP.
          LOOP AT lt_rep_concl-zi_intercoproposal INTO DATA(ls_rep_concl).
            APPEND ls_rep_concl TO reported-zi_intercoproposal.
          ENDLOOP.
        ENDIF.
        result = VALUE #( FOR p IN lt_prop_upd_mic ( %tky = p-%tky %param = CORRESPONDING #( p ) ) ).
        RETURN.
      ENDIF.

      " Dirección MIC↔USA: header + item + basis (importe único)
      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
          UPDATE FROM lt_prop_upd_mic
        ENTITY zi_intercoproposalitem
          UPDATE FROM lt_item_upd_mic
          CREATE BY \_proposalitemsbasis AUTO FILL CID
            FIELDS ( id item_id itembasis_id sharedrate globalcurrency
                     amountinglobalcurrency amountinglobalcurrency_c
                     companycodecurrency createdat createdby )
            WITH lt_basis_upd_mic
        MAPPED   DATA(lt_mapped_mic)
        REPORTED DATA(lt_reported_mic)
        FAILED   DATA(lt_failed_mic).

      result = VALUE #( FOR p IN lt_prop_upd_mic ( %tky = p-%tky %param = CORRESPONDING #( p ) ) ).
      RETURN.
    ENDIF.
*Fin EXT_OSCUGALD - Bermudas MIC-USA

    IF lv_product_metric EQ 'TF'. "TODO - Buscar da TVARV

      "TODO - buscar o rate da ZC_IntercoCompanyRelProdRate - IC02F
      SELECT *
          FROM zc_intercocompanyrelprodrate
          FOR ALL ENTRIES IN @lt_proposal_item
          WHERE product = @lt_proposal_item-product
            AND providercompanycode = @lt_proposal_item-providercompanycode
            AND recipientcompanycode = @lt_proposal_item-recipientcompanycode
            AND validfrom  >= @sy-datum AND validto <= @sy-datum
          INTO TABLE @DATA(lv_product_rate).

      IF lv_product_rate IS NOT INITIAL.
        LOOP AT lt_proposal_item INTO DATA(ls_proposal_item).
          READ TABLE lv_product_rate INTO DATA(ls_product_rate) WITH KEY
                                                              product = ls_proposal->product
                                                              providercompanycode = ls_proposal->providercompanycode
                                                              recipientcompanycode = ls_proposal_item-recipientcompanycode.
          IF ls_product_rate IS NOT INITIAL.
            DATA: lv_global_amount_r    TYPE p DECIMALS 6,
                  lv_company_currency_r TYPE waers.

            lv_global_amount_r = ls_proposal_item-baseamountprofitcenter * ( ls_product_rate-fixedrate / 100 ).
            lv_itembasis_id += 1.

            READ TABLE lt_companies INTO DATA(lv_company) WITH KEY companycode = ls_proposal_item-recipientcompanycode.
            lv_company_currency_r = COND #( WHEN lv_company IS NOT INITIAL THEN lv_company-currency ELSE ls_proposal_item-basecurrencyprofitcenter ).

            APPEND VALUE #( id                     = ls_proposal->id
                            item_id                = ls_proposal_item-item_id
                            itembasis_id           = lv_itembasis_id
                            sharedrate             = ls_metric_item_calc-sharerate
                            globalcurrency         = ls_proposal->globalcurrency
                            amountinglobalcurrency = lv_global_amount_r
                            companycodecurrency    = lv_company_currency_r
            ) TO lt_proposal_items_basis.

          ENDIF.
        ENDLOOP.
      ENDIF.

    ELSEIF lv_is_local = abap_true.
      " Si la métrica es local, se llama a la función de cálculo local
      " La función de cálculo local se encargará de llenar las tablas de actualización correspondientes
      " según la lógica específica de cada métrica local (IS, CS,

      me->apply_local_metric(
        EXPORTING
          is_proposal             = ls_proposal
          it_proposal_item        = CORRESPONDING #( lt_proposal_item[] )
*          it_cebe_items           = lt_cebe_items
*          it_companies            = lt_companies
          iv_product_metric       = lv_product_metric
          iv_param                = ls_param
        CHANGING
          ct_proposal_items_basis = lt_proposal_items_basis
          ct_proposal_items_upd   = lt_proposal_items_upd
          ct_proposal_upd         = lt_proposal_upd
          ct_items_basis_upd      = lt_proposal_items_basis_upd
          ct_items_bg_upd         = lt_proposal_items_bg_upd
          cs_failed               = failed
          cs_reported             = reported ).

    ELSE.

      DATA(lo_cap_api) = zcl_interco_btp_cap_metric_api=>get_instance(  ).

      DATA(lt_regional_metric) = lo_cap_api->get_regional_metric( EXPORTING iv_fiscal_period = ls_proposal->fiscalperiod
                                                                            iv_fiscal_year   = ls_proposal->fiscalyear
                                                                            iv_metric_code   = CONV #( lv_product_metric ) ).
      IF lt_regional_metric IS INITIAL.
        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
        APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                                     number   = '011'
                                                                     severity = if_abap_behv_message=>severity-warning
                                                                     v1       = lv_product_metric
                                                                     v2       = ls_proposal->fiscalperiod+1(2)
                                                                     v3       = ls_proposal->fiscalyear ) ) TO reported-zi_intercoproposal.
        RETURN.
      ENDIF.

* >>> Lectura Versiones regional metric -
      SHIFT ls_param-version LEFT DELETING LEADING '0'.
      IF lines( lt_regional_metric ) > 1.
        " 1. Leer el parámetro de acción enviado por el frontend
        DATA: lv_metric  TYPE string,
              lv_version TYPE string.
        lv_metric  = ls_param-metric.
        lv_version = ls_param-version.

        READ TABLE lt_regional_metric INTO DATA(ls_regional_metric) WITH KEY metric       = lv_metric
                                                                             version      = lv_version.

      ELSE.

        "No es necesario la selección del usuario, version unica de la metrica.
        READ TABLE lt_regional_metric INTO ls_regional_metric INDEX 1.
      ENDIF.
* <<< Versiones regional metric

      IF ls_regional_metric-isreleased EQ ''. "metric version
        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
        IF sy-sysid EQ 'TS4'."for testing purposes only
          APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '005' severity = if_abap_behv_message=>severity-warning ) ) TO reported-zi_intercoproposal.
        ELSE.
          APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '005' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
        ENDIF.
        RETURN.
      ENDIF. "metric version

      lt_metric_items_calc = lo_cap_api->get_regional_metric_items_calc( EXPORTING iv_fiscal_period = ls_proposal->fiscalperiod
                                                                                   iv_fiscal_year   = ls_proposal->fiscalyear
                                                                                   iv_metric_code   = CONV #( lv_product_metric )
                                                                                   iv_product       = CONV #( ls_proposal->product )
                                                                                   iv_provide_code  = CONV #( ls_proposal->providercompanycode ) ).
      IF lt_metric_items_calc IS INITIAL.
        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
        APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '006' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
        RETURN.
      ENDIF.

      IF lt_proposal_item IS NOT INITIAL.
        CLEAR: lv_itembasis_id.

        " #### Changing request by Nicolas Minguillon - Gabriel Ribeiro ####
        "Lucho havia solicitado para calcular o Item Basis pela somatória do do ProfitCenter
        "Porem nicolas informou que o valor gravado para cada Item já é a somatoria do profitcenter do IC05.
        "--------------------------------------------------------------------------------------------
        "SELECT * FROM ZI_IntercoProposalItemPCAmount
        "  WHERE Id EQ @ls_proposal->Id
        "  INTO TABLE @DATA(lt_ProposalIemProfitcenterSum).
        "--------------------------------------------------------------------------------------------
        SORT lt_metric_items_calc BY to_header_version ASCENDING profitcenter ASCENDING.
        LOOP AT lt_proposal_item ASSIGNING FIELD-SYMBOL(<fs_proposal_item>).
          CLEAR: ls_metric_item_calc.

          DATA(lv_profitcenter) = <fs_proposal_item>-profitcenter.
          SHIFT lv_profitcenter LEFT DELETING LEADING '0'.

          READ TABLE lt_metric_items_calc INTO ls_metric_item_calc WITH KEY
                                                                  product = ls_proposal->product
                                                                  providercompanycode = ls_proposal->providercompanycode
                                                                  recipientcompanycode = <fs_proposal_item>-recipientcompanycode
                                                                  profitcenter = lv_profitcenter
                                                                  to_header_version = ls_param-version.  "metric version
*          IF sy-uname = 'EXT_OSCUGALD'.
*Ini EXT_OSCUGALD 16.03.2026 - Ajuste Genova Realiza 2da verificación, sino existe metrica 200 revisamos que exista una 299
          IF sy-subrc <> 0 AND lv_profitcenter = '200'.
            READ TABLE lt_metric_items_calc INTO ls_metric_item_calc
              WITH KEY product             = ls_proposal->product
                       providercompanycode = ls_proposal->providercompanycode
                       recipientcompanycode = <fs_proposal_item>-recipientcompanycode
                       profitcenter        = '299'  " Buscamos métrica del hermano
                       to_header_version   = ls_param-version.

          ENDIF.
*Fin EXT_OSCUGALD 16.03.2026 - Ajuste Genova Realiza 2da verificación, sino existe metrica 200 revisamos que exista una 299
*          ENDIF.

          IF ls_metric_item_calc IS INITIAL.
            CLEAR ls_metric_item_calc.
***            IF sy-sysid NE 'PS4'."Message type Warning for DS4 and TS4
            DATA(lv_severity) = if_abap_behv_message=>severity-warning.
***            ELSE. "Message type Error for PS4
***              APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
***              lv_severity = if_abap_behv_message=>severity-error.
***            ENDIF.
            " Vinicius - replace by transaction key ->
*            APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
            APPEND VALUE #( %tky = ls_proposal->%tky %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
            "  Vinicius - replace by transction key <-
                                                                         number   = '017'
                                                                         severity = lv_severity
                                                                         v1       = lv_product_metric
                                                                         v2       = |{ ls_proposal->fiscalperiod+1(2) }/{ ls_proposal->fiscalyear }|
                                                                         v3       = <fs_proposal_item>-recipientcompanycode
                                                                         v4       = lv_profitcenter
*                                                                           v4       = |{ ls_proposal_item-profitcenter }, { TEXT-001 }:{ ls_proposal_item-Item_Id }|
                            ) ) TO reported-zi_intercoproposal.
          ELSE.
            DATA: lv_profitcenter_amount TYPE p DECIMALS 6,
                  lv_global_amount       TYPE p DECIMALS 6,
                  lv_global_amount_h     TYPE p DECIMALS 6,
                  lv_global_amount_l     TYPE p DECIMALS 6,
                  lv_company_amount      TYPE p DECIMALS 6,
                  lv_company_currency    TYPE waers.

            " #### Changing request by Nicolas Minguillon - Gabriel Ribeiro ####
            "READ TABLE lt_ProposalIemProfitcenterSum INTO DATA(lv_ProfitCenterTotal) WITH KEY ProfitCenter = ls_proposal_item-ProfitCenter.
            "lv_profitcenter_amount = COND #( WHEN lv_ProfitCenterTotal IS NOT INITIAL THEN lv_ProfitCenterTotal-TotalAmountProfitCenter ELSE ls_proposal_item-baseamountprofitcenter ).
            "lv_global_amount = lv_profitcenter_amount * ( ls_metric_item_calc-sharerate / 100 ).
            "--------------------------------------------------------------------------------------------

            " Lectura y mapeo para importes base corp + hispanos
            READ TABLE lt_cebe_items INTO DATA(ls_cebe_items) WITH KEY profitcenter = <fs_proposal_item>-profitcenter.
            IF sy-subrc EQ 0. "Genova MLA
              IF ls_cebe_items-baseamountprofitcenter IS NOT INITIAL.
                lv_global_amount = ls_cebe_items-baseamountprofitcenter * ( ls_metric_item_calc-sharerate / 100 ).
              ENDIF.
              IF ls_cebe_items-baseamountprofitcenterh IS NOT INITIAL. "Hispano
                lv_global_amount_h  = ls_cebe_items-baseamountprofitcenterh * ( ls_metric_item_calc-sharerateh / 100 ).
              ENDIF.
              IF ls_cebe_items-BaseamountprofitcenterL IS NOT INITIAL. "Locales
                lv_global_amount_l  = ls_cebe_items-BaseamountprofitcenterL * ( ls_metric_item_calc-shareratelocal / 100 ).
              ENDIF.
            ENDIF.
***            lv_global_amount = ls_proposal_item-baseamountprofitcenter * ( ls_metric_item_calc-sharerate / 100 ).
***            lv_global_amount_h  = ls_proposal_item-baseamountprofitcenter * ( ls_metric_item_calc-sharerateh / 100 ).   "Hispano

*            lv_itembasis_id += 1.

            READ TABLE lt_companies INTO lv_company WITH KEY companycode = <fs_proposal_item>-recipientcompanycode.
            lv_company_currency = COND #( WHEN lv_company IS NOT INITIAL THEN lv_company-currency ELSE <fs_proposal_item>-basecurrencyprofitcenter ).

            GET TIME STAMP FIELD DATA(lv_tsmt).

            APPEND VALUE #( id                      = ls_proposal->id
                            item_id                 = <fs_proposal_item>-item_id
                            itembasis_id            = <fs_proposal_item>-itembasis_id + 1
                            sharedrate              = ls_metric_item_calc-sharerate      "Sharedrate Corp
                            sharedrate_h            = ls_metric_item_calc-sharerateh     "Sharedrate Hispano
                            sharedrate_l            = ls_metric_item_calc-shareratelocal "Sharedrate Local
                            globalcurrency          = ls_proposal->globalcurrency
                            amountinglobalcurrency_c = lv_global_amount                  "Amount Corp
                            amountinglobalcurrency_h = lv_global_amount_h                "Amount Hispano
                            amountinglobalcurrency_l = lv_global_amount_l                "Amount Local
                            amountinglobalcurrency  = lv_global_amount + lv_global_amount_h + lv_global_amount_l
*                            amountinglobalcurrency  = lv_global_amount + lv_global_amount_h
                            amountincompanycodecurrency  = ( lv_global_amount + lv_global_amount_h + lv_global_amount_l ) * <fs_proposal_item>-exchangerate
*                            amountincompanycodecurrency  = ( lv_global_amount + lv_global_amount_h ) * <fs_proposal_item>-exchangerate
                            companycodecurrency     = lv_company_currency
                            createdat               = lv_tsmt
                            createdby               = cl_abap_context_info=>get_user_technical_name( )
            ) TO lt_proposal_items_basis.
            CLEAR: lv_global_amount, lv_global_amount_h, lv_global_amount_l.
          ENDIF.
        ENDLOOP.

*Ini EXT_OSCUGALD 05.02.2026 - Genova MLA
        IF ls_proposal->providercompanycode = 'MLA' AND line_exists( lt_proposal_item[ cebe_aux = '299' ] ) AND lv_new_299 = abap_true.
          DELETE lt_proposal_item WHERE cebe_aux = '299'.
        ENDIF.
*Fin EXT_OSCUGALD 05.02.2026 - Genova MLA

        IF failed-zi_intercoproposal IS NOT INITIAL.
          RETURN.
        ENDIF.
        IF lt_proposal_items_basis IS INITIAL.
          APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
          APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '015' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
          RETURN.
        ELSE.
*          DATA(lt_proposal_items_upd) = me->prepareproposalitemstoupd( CORRESPONDING #( lt_proposal_item[] ) ).
*          DATA(lt_proposal_items_upd) = me->prepareproposalitemstoupd_cebe(
          lt_proposal_items_upd = me->prepareproposalitemstoupd_cebe(
             it_proposal_items = CORRESPONDING #( lt_proposal_item[] )
             it_cebe_items     = CORRESPONDING #( lt_cebe_items )
           ).

          me->cleanproposalitembasis( EXPORTING iv_proposalid = ls_proposal->id it_proposal_items = lt_proposal_items_upd ).

          lt_proposal_items_basis = me->applyexchangerate( EXPORTING it_proposal_items_basis = lt_proposal_items_basis
                                                                     is_proposal             = ls_proposal
                                                           CHANGING  cs_failed               = failed
                                                                     cs_reported             = reported ).

          IF reported-zi_intercoproposal[] IS INITIAL.
*            DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-verified ).
            lt_proposal_upd = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-verified ).
          ELSE.
            lt_proposal_upd = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-pending ).
          ENDIF.

*Ini EXT_OSCUGALD 05.02.2026 - Genova MLA
          DATA lt_proposal_items_gl TYPE gtty_proposal_item_gl.

          IF ls_proposal->providercompanycode = 'MLA'.
            " Para MLA aplicamos la lógica de duplicación (200 + 299)
            " Pasamos lt_proposal_items_basis (los calculados) y lt_proposal_item (la foto completa de la memoria/DB)
            lt_proposal_items_gl = me->get_proposal_item_gl_genova(
                it_proposal_items_basis = lt_proposal_items_basis
                it_proposal_item        = lt_proposal_item
            ).
            SORT lt_proposal_items_gl BY itemid.
            IF lv_new_299 = abap_true.
              LOOP AT lt_proposal_items_gl INTO DATA(ls_gl_item) WHERE cebe_aux = '299'.

                DATA(lv_d4) = COND #( WHEN ls_gl_item-costcenterd4 IS NOT INITIAL
                                       THEN ls_gl_item-costcenterd4
                                       ELSE ls_gl_item-costcenter+3(1) ).

                DATA(lv_amt)   = SWITCH #( lv_d4 WHEN '1' THEN ls_gl_item-amountinglobalcurrency ELSE 0 ).
                DATA(lv_amt_h) = SWITCH #( lv_d4 WHEN '3' THEN ls_gl_item-amountinglobalcurrency ELSE 0 ).
                DATA(lv_amt_l) = SWITCH #( lv_d4 WHEN '0' THEN ls_gl_item-amountinglobalcurrency ELSE 0 ).

                APPEND VALUE #(
                    %cid_ref = |NEW_ITEM_299_{ ls_gl_item-itemid }|
                    %target  = VALUE #( (
                        %cid                    = |ORG_299_{ ls_gl_item-itemid }_{ sy-tabix }|
                        id                      = ls_gl_item-Id
                        itemid                  = ls_gl_item-ItemId
                        GlAccount               = |{ ls_gl_item-glaccount  ALPHA = IN }|
                        CostCenter              = |{ ls_gl_item-costcenter ALPHA = IN }|
                        Department              = ls_gl_item-Department
                        PercentOfTotal          = ls_gl_item-percentoftotal
                        GlobalCurrency          = ls_proposal->globalcurrency
                        AmountInGlobalCurrency  = lv_amt
                        AmountInGlobalCurrencyH = lv_amt_h
                        AmountInGlobalCurrencyL = lv_amt_l
                        cebe_aux                = '299'
                        RecipientCompanyCode    = ls_proposalitemaux-RecipientCompanyCode )
                        )
                ) TO lt_items_org_gl_create.

              ENDLOOP.
            ENDIF.
          ELSE.
            " Para el resto de sociedades mantenemos el flujo original
            lt_proposal_items_gl = me->get_proposal_item_gl( lt_proposal_items_basis ).
          ENDIF.
*Fin EXT_OSCUGALD 05.02.2026 - Genova MLA
          LOOP AT lt_proposal_items_gl INTO DATA(ls_proposal_items_gl).
            MOVE-CORRESPONDING ls_proposal_items_gl TO ls_itemorglacct_aux.
            CASE ls_proposal_items_gl-costcenterd4.
              WHEN '1'.
                ls_itemorglacct_aux-globalcurrency_c = ls_proposal_items_gl-amountinglobalcurrency.
              WHEN '3'.
                ls_itemorglacct_aux-globalcurrency_h = ls_proposal_items_gl-amountinglobalcurrency.
              WHEN '0'.
                ls_itemorglacct_aux-globalcurrency_l = ls_proposal_items_gl-amountinglobalcurrency.
            ENDCASE.
            APPEND ls_itemorglacct_aux TO lt_itemorglacct_aux.
            CLEAR ls_itemorglacct_aux.
          ENDLOOP.

          LOOP AT lt_proposal_items_basis INTO DATA(ls_proposal_items_basis).
*Ini EXT_OSCUGALD 05.02.2026 - Genova MLA
            " --- DETERMINACIÓN DE ESCENARIO ---
            " Buscamos en la tabla de resultados de GL si este item_id corresponde al nuevo cebe_aux '299'
            DATA(lv_is_new_299) = abap_false.
            " Si la sociedad es MLA, verificamos si este item_id fue el asignado al bloque 299
            IF ls_proposal->providercompanycode = 'MLA'.
              IF line_exists( lt_proposal_items_gl[ itemid = ls_proposal_items_basis-item_id cebe_aux = '299' ] ) AND lv_new_299 = abap_true.
                lv_is_new_299 = abap_true.
              ENDIF.
            ENDIF.

            IF lv_is_new_299 = abap_true.

              " 1. Mapeo a lt_proposal_items_basis_upd (Item -> Basis)
              APPEND VALUE #( id       = ls_proposal->id
                              item_id  = ls_proposal_items_basis-item_id
                              " IMPORTANTE: Enlace al %cid del ítem padre creado en lt_items_to_create
                              %cid_ref = |NEW_ITEM_299_{ ls_proposal_items_basis-item_id }|
                              %target  = VALUE #( FOR item_basis IN lt_proposal_items_basis
                                                  WHERE ( item_id = ls_proposal_items_basis-item_id )
                                                  ( %cid                        = |B{ sy-tabix }|
                                                    id                          = item_basis-id
                                                    item_id                     = item_basis-item_id
                                                    itembasis_id                = item_basis-itembasis_id
                                                    metric_id                   = item_basis-metric_id
                                                    sharedrate                  = item_basis-sharedrate
                                                    sharedrate_h                = item_basis-sharedrate_h
                                                    sharedrate_l                = item_basis-sharedrate_l
                                                    exchangerate                = item_basis-exchangerate
                                                    exchangefactor              = item_basis-exchangefactor
                                                    globalcurrency              = item_basis-globalcurrency
                                                    amountinglobalcurrency_c    = item_basis-amountinglobalcurrency_c
                                                    amountinglobalcurrency_h    = item_basis-amountinglobalcurrency_h
                                                    amountinglobalcurrency_l    = item_basis-amountinglobalcurrency_l
                                                    amountinglobalcurrency      = item_basis-amountinglobalcurrency_c +
                                                                                  item_basis-amountinglobalcurrency_h +
                                                                                  item_basis-amountinglobalcurrency_l
                                                    companycodecurrency         = item_basis-companycodecurrency
                                                    amountincompanycodecurrency = item_basis-amountincompanycodecurrency
                                                    createdat                   = item_basis-createdat
                                                    createdby                   = item_basis-createdby )
                                                )
              ) TO lt_proposal_items_basis_upd.

            ELSE.
*Fin EXT_OSCUGALD 05.02.2026 - Genova MLA
              APPEND VALUE #( id      = ls_proposal->id
                              item_id = ls_proposal_items_basis-item_id
                              %target = VALUE #( FOR item_basis IN lt_proposal_items_basis WHERE ( item_id                     = ls_proposal_items_basis-item_id )
*                                               ( CORRESPONDING #( item_basis )  )
                                                                                                 ( %cid                        = |B{ sy-tabix }|
                                                                                                   id                          = item_basis-id
                                                                                                   item_id                     = item_basis-item_id
                                                                                                   itembasis_id                = item_basis-itembasis_id
                                                                                                   metric_id                   = item_basis-metric_id
                                                                                                   sharedrate                  = item_basis-sharedrate
                                                                                                   sharedrate_h                = item_basis-sharedrate_h
                                                                                                   sharedrate_l                = item_basis-sharedrate_l
                                                                                                   exchangerate                = item_basis-exchangerate
                                                                                                   exchangefactor              = item_basis-exchangefactor
                                                                                                   globalcurrency              = item_basis-globalcurrency
                                                                                                   amountinglobalcurrency_c    = item_basis-amountinglobalcurrency_c
                                                                                                   amountinglobalcurrency_h    = item_basis-amountinglobalcurrency_h
                                                                                                   amountinglobalcurrency_l    = item_basis-amountinglobalcurrency_l
                                                                                                   amountinglobalcurrency      = item_basis-amountinglobalcurrency_c + item_basis-amountinglobalcurrency_h + item_basis-amountinglobalcurrency_l
                                                                                                   companycodecurrency         = item_basis-companycodecurrency
                                                                                                   amountincompanycodecurrency = item_basis-amountincompanycodecurrency
                                                                                                   createdat                   = item_basis-createdat
                                                                                                   createdby                   = item_basis-createdby )
                                                 )
              ) TO lt_proposal_items_basis_upd.
            ENDIF.

            GET TIME STAMP FIELD lv_tsmt.
            APPEND VALUE #(
               %cid_ref     = |B{ sy-tabix }|
               id           = ls_proposal->id
               item_id      = ls_proposal_items_basis-item_id
               itembasis_id = ls_proposal_items_basis-itembasis_id
               %target      = VALUE #(
                               FOR items_gl IN lt_itemorglacct_aux
                               WHERE ( id     = ls_proposal_items_basis-id
                                    AND itemid = ls_proposal_items_basis-item_id )
                               ( id                           = ls_proposal_items_basis-id
                                 item_id                      = ls_proposal_items_basis-item_id
                                 itembasis_id                 = ls_proposal_items_basis-itembasis_id
                                 glaccount                    = |{ items_gl-glaccount  ALPHA = IN }|        "Ajuste para busqueda a traves de vistas
                                 costcenter                   = |{ items_gl-costcenter ALPHA = IN }|
                                 sharedrateh                  = ls_proposal_items_basis-sharedrate_h
                                 "  Amounts in Global Currency
                                 amountinglobalcurrencyc      = items_gl-globalcurrency_c
                                                               * ( ls_proposal_items_basis-sharedrate   / 100 )
                                 amountinglobalcurrencyh      = items_gl-globalcurrency_h
                                                               * ( ls_proposal_items_basis-sharedrate_h / 100 )
                                 amountinglobalcurrencyl      = items_gl-globalcurrency_l
                                                               * ( ls_proposal_items_basis-sharedrate_l / 100 )
                                 amountinglobalcurrency       = ( items_gl-globalcurrency_c
                                                                 * ( ls_proposal_items_basis-sharedrate   / 100 ) )
                                                               + ( items_gl-globalcurrency_h
                                                                 * ( ls_proposal_items_basis-sharedrate_h / 100 ) )
                                                               + ( items_gl-globalcurrency_l
                                                                 * ( ls_proposal_items_basis-sharedrate_l / 100 ) )

                                 globalcurrency               = ls_proposal_items_basis-globalcurrency
                                 "  Amounts in Company Code Currency
                                 amountincompanycodecurrencyc = items_gl-globalcurrency_c
                                                               * ( ls_proposal_items_basis-sharedrate   / 100 )
                                                               *   ls_proposal_items_basis-exchangerate "* ls_proposal_items_basis-exchangefactor
                                 amountincompanycodecurrencyh = items_gl-globalcurrency_h
                                                               * ( ls_proposal_items_basis-sharedrate_h / 100 )
                                                               *   ls_proposal_items_basis-exchangerate "* ls_proposal_items_basis-exchangefactor
                                 amountincompanycodecurrencyl = items_gl-globalcurrency_l
                                                               * ( ls_proposal_items_basis-sharedrate_l / 100 )
                                                               *   ls_proposal_items_basis-exchangerate "* ls_proposal_items_basis-exchangefactor
                                 amountincompanycodecurrency  = ( items_gl-globalcurrency_c
                                                                 * ( ls_proposal_items_basis-sharedrate   / 100 )
                                                                 *   ls_proposal_items_basis-exchangerate )" * ls_proposal_items_basis-exchangefactor )
                                                               + ( items_gl-globalcurrency_h
                                                                 * ( ls_proposal_items_basis-sharedrate_h / 100 )
                                                                 *   ls_proposal_items_basis-exchangerate )"* ls_proposal_items_basis-exchangefactor )
                                                               + ( items_gl-globalcurrency_l
                                                                 * ( ls_proposal_items_basis-sharedrate_l / 100 )
                                                                 *   ls_proposal_items_basis-exchangerate )"* ls_proposal_items_basis-exchangefactor )
                                 companycodecurrency          = ls_proposal_items_basis-companycodecurrency
                                 createdat                    = lv_tsmt
                                 createdby                    = cl_abap_context_info=>get_user_technical_name( )
                               )
                             )
             ) TO lt_proposal_items_bg_upd.

          ENDLOOP.

*Ini EXT_OSCUGALD 05.02.2026 - Genova MLA
          " --- ESCENARIO PARA SOCIEDAD MLA CON CEBE 299 ---
          IF ls_proposal->providercompanycode = 'MLA' AND line_exists( lt_proposal_items_gl[ cebe_aux = '299' ] ) AND lv_new_299 = abap_true.

            MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
                  ENTITY zi_intercoproposal
                    UPDATE FROM lt_proposal_upd
                    CREATE BY \_items
                    FIELDS ( id item_id recipientcompanycode profitcenter Interdivisional BaseCurrencyProfitCenter baseamountprofitcenter BaseAmountProfitCenterC BaseAmountProfitCenterH BaseAmountProfitCenterL )
                    WITH lt_items_to_create

                  ENTITY zi_intercoproposalitem
                      UPDATE FROM lt_proposal_items_upd
                      CREATE BY \_proposalitemsdetails
                      FIELDS ( Id ItemId GlAccount CostCenter Department GlobalCurrency AmountInGlobalCurrency AmountInGlobalCurrencyH AmountInGlobalCurrencyL PercentOfTotal cebe_aux RecipientCompanyCode )
                      WITH lt_items_org_gl_create

                      CREATE BY \_proposalitemsbasis AUTO FILL CID
                      FIELDS ( id item_id itembasis_id metric_id sharedrate sharedrate_h sharedrate_l exchangerate globalcurrency amountinglobalcurrency amountinglobalcurrency_c amountinglobalcurrency_h
                                  amountinglobalcurrency_l companycodecurrency amountincompanycodecurrency createdat createdby )
                      WITH lt_proposal_items_basis_upd

                  ENTITY zi_intercoproposalitembasis
                      CREATE BY \_proposalitemsbaoglac AUTO FILL CID
                      FIELDS (  id item_id itembasis_id glaccount costcenter sharedrateh sharedratel amountinglobalcurrencyc amountinglobalcurrencyh amountinglobalcurrencyl amountinglobalcurrency globalcurrency amountincompanycodecurrencyc
                            amountincompanycodecurrency amountincompanycodecurrencyh amountincompanycodecurrencyl companycodecurrency createdby createdat )
                      WITH lt_proposal_items_bg_upd
                      MAPPED DATA(lt_mapped_mla)
                      REPORTED DATA(lt_reported_mla)
                      FAILED DATA(lt_failed_mla).

          ELSE.
*Fin  EXT_OSCUGALD 05.02.2026 - Genova MLA
            MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
               ENTITY zi_intercoproposal
                  UPDATE FROM lt_proposal_upd
               ENTITY zi_intercoproposalitem
                  UPDATE FROM lt_proposal_items_upd
*                UPDATE FIELDS ( baseamountprofitcenter baseamountprofitcenterc baseamountprofitcenterh ) WITH lt_proposal_items_upd
                  CREATE BY \_proposalitemsbasis AUTO FILL CID
                      FIELDS ( id item_id itembasis_id metric_id sharedrate sharedrate_h sharedrate_l exchangerate globalcurrency amountinglobalcurrency amountinglobalcurrency_c amountinglobalcurrency_h
                                  amountinglobalcurrency_l companycodecurrency amountincompanycodecurrency createdat createdby )
                      WITH lt_proposal_items_basis_upd[]
               ENTITY zi_intercoproposalitembasis
               CREATE BY \_proposalitemsbaoglac AUTO FILL CID
               FIELDS (  id item_id itembasis_id glaccount costcenter sharedrateh sharedratel amountinglobalcurrencyc amountinglobalcurrencyh amountinglobalcurrencyl amountinglobalcurrency globalcurrency amountincompanycodecurrencyc
                            amountincompanycodecurrency amountincompanycodecurrencyh amountincompanycodecurrencyl companycodecurrency createdby createdat )
               WITH lt_proposal_items_bg_upd
               MAPPED DATA(lt_mapped)
               REPORTED DATA(lt_reported)
               FAILED DATA(lt_failed).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

* Vinicius - UPDATE - El resultado actualizado ya esta ->
*    read entities of zi_intercoproposal in local mode
*    entity zi_intercoproposal all fields with corresponding #( keys ) result data(lt_result) .
*
*    result = value #( for <fs> in lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
    result = VALUE #( FOR p IN lt_proposal_upd ( %tky = p-%tky %param = CORRESPONDING #( p ) ) ).
* Vinicius - UPDATE <-

  ENDMETHOD.

  METHOD calculate.
************ TEMP ****************->
    IF sy-uname = 'EXT_VINBARRI' AND sy-sysid = 'DS4'.
      READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(current_proposals) .

      LOOP AT current_proposals REFERENCE INTO DATA(current_proposal).
        current_proposal->status = 'C'.
      ENDLOOP.

      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
            UPDATE FIELDS ( status ) WITH CORRESPONDING #( current_proposals ).

      result = VALUE #( FOR cr IN current_proposals ( %tky   = cr-%tky
                                                      %param = cr ) ).
      RETURN.
    ENDIF.
************ TEMP **************** <-

    DATA: lt_proposal_items_calc     TYPE STANDARD TABLE OF  zfi_a_intrc_cpic,
          lt_proposal_items_calc_upd TYPE TABLE FOR CREATE zi_intercoproposalitembasis\_itemscalc,
          "lt_proposal_items_basis_upd TYPE TABLE FOR UPDATE ZI_IntercoProposalItemBasis,
          "lt_proposal_items_upd       TYPE TABLE FOR UPDATE ZI_IntercoProposalItem,
          "lt_proposal_upd             TYPE TABLE FOR UPDATE ZI_IntercoProposal,
          lv_itemcalc_id             TYPE int8 VALUE 0.

    " Vinicius - TODO - El usuario podra ejecutar masivamente ->
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
           ENTITY zi_intercoproposal BY \_items  ALL FIELDS WITH VALUE #( ( %key-id = <fs_key>-id ) ) RESULT FINAL(lt_proposal_item) LINK FINAL(link_items)
        FAILED DATA(lt_proposal_failed).
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposalitem BY \_proposalitemsbasis  ALL FIELDS WITH VALUE #( FOR lwa_link_items IN link_items
                                                                                           ( %key-id      = lwa_link_items-target-id
                                                                                             %key-item_id = lwa_link_items-target-item_id ) ) LINK FINAL(link_basis)
        FAILED lt_proposal_failed.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposalitembasis BY \_proposalitemsbaoglac  ALL FIELDS WITH VALUE #( FOR lwa_link_basis IN link_basis
                                                                                                  ( %key-id           = lwa_link_basis-target-id
                                                                                                    %key-item_id      = lwa_link_basis-target-item_id
                                                                                                    %key-itembasis_id = lwa_link_basis-target-itembasis_id ) ) RESULT FINAL(lt_proposal_baoglacc)
        FAILED lt_proposal_failed.
    " Vinicius - TODO - El usuario podra ejecutar masivamente ->
    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

*Ini EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
*   Calculate para Bermudas (Metric=SM): el metodo estandar busca tarifas
*   en zi_intercocompanyrelprodrate (markup/grossingup/etc), tabla que
*   Bermudas NUNCA usa porque el importe ya viene calculado por ISAC NCP
*   en apply_mic_metric. Se agrega ramal dedicado que puebla zfi_a_intrc_cpic
*   con todos los conceptos en cero (consistencia de tablas para que
*   Simulation/Commit reusen el flujo estandar de BO_AR/BO_AP sin romper
*   el patron de datos), sin consultar la tabla de tarifas.
    SELECT SINGLE metric FROM zi_intercoproduct
      WHERE product = @ls_proposal->product
      INTO @DATA(lv_mic_metric_calc).

    IF lv_mic_metric_calc = 'SM'.
      SELECT * FROM zfi_a_intrc_cpib
        WHERE id = @ls_proposal->id
        INTO TABLE @DATA(lt_basis_mic_calc).

      IF lt_basis_mic_calc IS INITIAL.
        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
        APPEND VALUE #( %key = ls_proposal->%key
          %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '009'
                              severity = if_abap_behv_message=>severity-error ) )
          TO reported-zi_intercoproposal.
        RETURN.
      ENDIF.

      DATA lt_calc_mic TYPE STANDARD TABLE OF zfi_a_intrc_cpic.
      DATA lt_calc_mic_upd TYPE TABLE FOR CREATE zi_intercoproposalitembasis\_itemscalc.
      GET TIME STAMP FIELD DATA(lv_tsmt_calc_mic).

      LOOP AT lt_basis_mic_calc INTO DATA(ls_basis_mic_calc).
        APPEND VALUE #(
          id                             = ls_proposal->id
          item_id                        = ls_basis_mic_calc-item_id
          itembasis_id                   = ls_basis_mic_calc-itembasis_id
          itemcalc_id                    = 1
          commitstatus                   = ''
          markup                         = 0
          grossingupbase                 = 0
          grossingupmargin               = 0
          latepaymentinterest            = 0
          providergrossingup             = 0
          markupamount                   = 0
          grossingupbaseamount           = 0
          grossingupmarginamount         = 0
          latepaymentinterestamount      = 0
          providergrossingupamount       = 0
          markupamntinlocal              = 0
          grossingupbaseamntinlocal      = 0
          grossingupmarginamntinlocal    = 0
          latepaymentinterestamntinlocal = 0
          providergrossingupamntinlocal  = 0
          createdat                      = lv_tsmt_calc_mic
          createdby                      = cl_abap_context_info=>get_user_technical_name( )
        ) TO lt_calc_mic.
      ENDLOOP.

      LOOP AT lt_calc_mic INTO DATA(ls_calc_mic).
        APPEND VALUE #(
          id           = ls_proposal->id
          item_id      = ls_calc_mic-item_id
          itembasis_id = ls_calc_mic-itembasis_id
          %target      = VALUE #( ( CORRESPONDING #( ls_calc_mic ) ) )
        ) TO lt_calc_mic_upd.
      ENDLOOP.

      DATA(lt_prop_upd_calc_mic) = me->prepareproposaltoupd(
        EXPORTING it_proposal        = CORRESPONDING #( lt_proposal[] )
                  iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-calculated ).

      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
          UPDATE FROM lt_prop_upd_calc_mic
        ENTITY zi_intercoproposalitembasis
          CREATE BY \_itemscalc AUTO FILL CID
          FIELDS ( id item_id itembasis_id itemcalc_id commitstatus markup grossingupbase
                   grossingupmargin latepaymentinterest providergrossingup markupamount
                   grossingupbaseamount grossingupmarginamount latepaymentinterestamount
                   providergrossingupamount markupamntinlocal grossingupbaseamntinlocal
                   grossingupmarginamntinlocal latepaymentinterestamntinlocal
                   providergrossingupamntinlocal createdat createdby )
          WITH lt_calc_mic_upd
        REPORTED DATA(lt_reported_calc_mic)
        FAILED   DATA(lt_failed_calc_mic).

      result = VALUE #( FOR p IN lt_prop_upd_calc_mic ( %tky = p-%tky %param = CORRESPONDING #( p ) ) ).
      RETURN.
    ENDIF.
*Fin EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)

* Vinicius - DELETE #1 Eso ya es garantizado por las features ->
*      if ls_proposal->Status ne 'V' and ls_proposal->Status ne 'C'.
*        append value #( %key = ls_proposal->%key ) to failed-zi_intercoproposal.
*        append value #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '002' severity = if_abap_behv_message=>severity-error ) ) to reported-zi_intercoproposal.
*        return.
*      endif.
* Vinicius - DELETE #1 <-

    "      SELECT * FROM ZI_IntercoProposalItemBasisRat
    "        WHERE id =  @ls_proposal->Id
    "        INTO TABLE @DATA(lt_PropItemBasisRateApplyed).
    "
    "      IF lt_PropItemBasisRateApplyed IS INITIAL.
    "        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
    "        APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '007' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
    "      ELSE.
    "        DATA: lv_rate_applyed_error TYPE abap_boolean,
    "              lv_rate_applyed       TYPE p DECIMALS 4.
    "        LOOP AT lt_PropItemBasisRateApplyed INTO DATA(ls_PropItemBasisRateApplyed).
    "          lv_rate_applyed = CONV #( ls_PropItemBasisRateApplyed-totalRateApplyed ).
    "          IF lv_rate_applyed < 100.
    "            APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
    "            APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
    "                                                                         number   = '008'
    "                                                                         severity = if_abap_behv_message=>severity-error
    "                                                                         v1       = ls_PropItemBasisRateApplyed-ProviderCompanyCode
    "                                                                         v2       = ls_PropItemBasisRateApplyed-ProfitCenter ) ) TO reported-zi_intercoproposal.
    "            lv_rate_applyed_error = abap_true.
    "          ENDIF.
    "        ENDLOOP.
    "        IF lv_rate_applyed_error EQ abap_true.
    "          RETURN.
    "        ENDIF.
    "      ENDIF.

    SELECT *
*      FROM ZI_IntercoProposalItemBasis
      FROM zfi_a_intrc_cpib
      WHERE id = @ls_proposal->id
      INTO TABLE @DATA(lt_proposal_item_basis).

    IF lt_proposal_item_basis IS NOT INITIAL.
      DATA lv_validfrom TYPE d.
      lv_validfrom = |{ ls_proposal->fiscalyear }{ ls_proposal->fiscalperiod+1 }01|.
      DATA(lv_validto) = zcl_interco_utils=>rp_last_day_of_months( day_in = lv_validfrom ).
*    CATCH cx_sy_conversion_no_date.
      SELECT *
          FROM zi_intercocompanyrelprodrate
          FOR ALL ENTRIES IN @lt_proposal_item
          WHERE providercompanycode = @ls_proposal->providercompanycode
            AND recipientcompanycode = @lt_proposal_item-recipientcompanycode
            AND product = @ls_proposal->product
*            AND ( validfrom <= @sy-datum AND  validto >= @sy-datum )
            AND ( validfrom <= @lv_validfrom AND validto >= @lv_validto )
         INTO TABLE @DATA(lt_company_relprod_rate).

      IF lt_company_relprod_rate IS INITIAL.
        APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
        APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '012' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
        RETURN.
      ENDIF.

*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
      DATA: lv_res_mup_global TYPE decfloat34,
            lv_res_gub_global TYPE decfloat34,
            lv_res_gum_global TYPE decfloat34,
            lv_res_lpi_global TYPE decfloat34,
            lv_res_pgu_global TYPE decfloat34,
            lv_res_mup_local  TYPE decfloat34,
            lv_res_gub_local  TYPE decfloat34,
            lv_res_gum_local  TYPE decfloat34,
            lv_res_lpi_local  TYPE decfloat34,
            lv_res_pgu_local  TYPE decfloat34,
            lv_soc            TYPE bukrs.
*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
      lv_soc = 'MLA'.
      LOOP AT lt_proposal_item_basis INTO DATA(ls_proposal_item_basis).

*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
        " 1. LEER CON FIELD-SYMBOL PARA PODER MODIFICAR LA TABLA ORIGINAL
        READ TABLE lt_proposal_item ASSIGNING FIELD-SYMBOL(<fs_item_to_upd>)
          WITH KEY item_id = ls_proposal_item_basis-item_id.

        READ TABLE lt_company_relprod_rate INTO DATA(ls_company_relprod_rate)
                  WITH KEY product              = <fs_item_to_upd>-product
                           providercompanycode  = <fs_item_to_upd>-providercompanycode
                           recipientcompanycode = <fs_item_to_upd>-recipientcompanycode.
*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
*        READ TABLE lt_proposal_item INTO DATA(ls_proposal_item) WITH KEY item_id = ls_proposal_item_basis-item_id.

*        READ TABLE lt_company_relprod_rate INTO DATA(ls_company_relprod_rate) WITH KEY
*                                                                                product = ls_proposal_item-product
*                                                                                providercompanycode = ls_proposal_item-providercompanycode
*                                                                                recipientcompanycode = ls_proposal_item-recipientcompanycode.
        IF sy-subrc NE 0.
*          APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*          APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
*                                                                       number   = '013'
*                                                                       severity = if_abap_behv_message=>severity-error
*                                                                       v1       = ls_proposal_item-recipientcompanycode
*                                                                       v2       = ls_proposal_item-product
*                                                                       v3       = ls_proposal_item-item_id
*                          ) ) TO reported-zi_intercoproposal.
          IF NOT line_exists( failed-zi_intercoproposalitemcalc[ id           = ls_proposal_item_basis-id
                          item_id      = ls_proposal_item_basis-item_id
                          itembasis_id = ls_proposal_item_basis-itembasis_id
                          itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1 ] ).
*                          itemcalc_id  = ls_proposal_item-itemcalc_id + 1 ] ).
            APPEND VALUE #( %key         = ls_proposal->%key
                            id           = ls_proposal_item_basis-id
                            item_id      = ls_proposal_item_basis-item_id
                            itembasis_id = ls_proposal_item_basis-itembasis_id
                            itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1 ) TO failed-zi_intercoproposalitemcalc.
*                            itemcalc_id  = ls_proposal_item-itemcalc_id + 1 ) TO failed-zi_intercoproposalitemcalc.
            APPEND VALUE #( %key         = ls_proposal->%key
                            id           = ls_proposal_item_basis-id
                            item_id      = ls_proposal_item_basis-item_id
                            itembasis_id = ls_proposal_item_basis-itembasis_id
                            itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1
*                            itemcalc_id  = ls_proposal_item-itemcalc_id + 1
                            %msg         = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                        number   = '013'
                                                        severity = if_abap_behv_message=>severity-error
                                                        v1       = <fs_item_to_upd>-recipientcompanycode
                                                        v2       = <fs_item_to_upd>-product
                                                        v3       = <fs_item_to_upd>-item_id
                            ) ) TO reported-zi_intercoproposalitemcalc.
          ENDIF.
        ELSE.
          DATA: lv_markup                   TYPE zfi_a_intrc_cpic-markupamount,
                lv_grossingupbase           TYPE zfi_a_intrc_cpic-grossingupbaseamount,
                lv_grossingupmargin         TYPE zfi_a_intrc_cpic-grossingupmarginamount,
                lv_total                    LIKE ls_proposal_item_basis-amountinglobalcurrency,
                lv_latepaymentinterest      TYPE zfi_a_intrc_cpic-latepaymentinterestamount,
                lv_providergrossingup       TYPE zfi_a_intrc_cpic-providergrossingupamount,
                lv_markuplocal              TYPE zfi_a_intrc_cpic-markupamount,
                lv_grossingupbaselocal      TYPE zfi_a_intrc_cpic-grossingupbaseamount,
                lv_grossingupmarginlocal    TYPE zfi_a_intrc_cpic-grossingupmarginamount,
                lv_totallocal               LIKE ls_proposal_item_basis-amountinglobalcurrency,
                lv_latepaymentinterestlocal TYPE zfi_a_intrc_cpic-latepaymentinterestamount,
                lv_providergrossinguplocal  TYPE zfi_a_intrc_cpic-providergrossingupamount.

          CLEAR: lv_markup, lv_grossingupbase, lv_grossingupmargin, lv_total,
                           lv_latepaymentinterest, lv_providergrossingup, lv_markuplocal,
                           lv_grossingupbaselocal, lv_grossingupmarginlocal, lv_totallocal,
                           lv_latepaymentinterestlocal, lv_providergrossinguplocal.


          IF lv_soc = 'MLA'.
*          IF ls_proposal->providercompanycode = 'MLA'.
*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
            " --- CÁLCULOS LOCAL CURRENCY ---

            " 1. Markup Local
            DATA(lv_calc_mup_l) = ( ls_proposal_item_basis-amountincompanycodecurrency * ( ls_company_relprod_rate-markup / 100 ) ) + lv_res_mup_local.
            lv_markuplocal = round( val = lv_calc_mup_l dec = 2 mode = cl_abap_math=>round_half_up ).
            lv_res_mup_local = lv_calc_mup_l - lv_markuplocal.

            " 2. Grossing Up Base Local (Solución definitiva al error del Divisor = 1)
            " Forzamos que el cálculo sea DECFLOAT34 desde el inicio
            DATA(lv_rate_decimal) = CONV decfloat34( ls_company_relprod_rate-grossingupbase / 100 ).
            DATA(lv_div_exact)    = CONV decfloat34( 1 - lv_rate_decimal ).

            IF lv_div_exact <> 1 AND lv_div_exact <> 0.
              DATA(lv_calc_gub_l) = ( ls_proposal_item_basis-amountincompanycodecurrency / lv_div_exact -
                                      ls_proposal_item_basis-amountincompanycodecurrency ) + lv_res_gub_local.

              lv_grossingupbaselocal = round( val = lv_calc_gub_l dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_gub_local = lv_calc_gub_l - lv_grossingupbaselocal.
            ELSE.
              lv_grossingupbaselocal = 0.
              lv_res_gub_local = 0.
            ENDIF.

            " 3. Grossing Up Margin Local (Ajustado para evitar división entera)
            DATA(lv_rate_gum_l) = CONV decfloat34( ls_company_relprod_rate-grossingupmargin / 100 ).
            DATA(lv_div_gum_l)  = CONV decfloat34( 1 - lv_rate_gum_l ).

            IF lv_div_gum_l <> 1 AND lv_div_gum_l <> 0.
              DATA(lv_calc_gum_l) = ( lv_markuplocal / lv_div_gum_l - lv_markuplocal ) + lv_res_gum_local.
              lv_grossingupmarginlocal = round( val = lv_calc_gum_l dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_gum_local = lv_calc_gum_l - lv_grossingupmarginlocal.
            ELSE.
              lv_grossingupmarginlocal = 0.
              lv_res_gum_local = 0.
            ENDIF.

            " Total Local (Suma de componentes redondeados)
            lv_totallocal = ls_proposal_item_basis-amountincompanycodecurrency + lv_markuplocal + lv_grossingupbaselocal + lv_grossingupmarginlocal.

            " 4. Late Payment Interest Local
            IF ls_company_relprod_rate-latepaymentinterest <> 0.
              DATA(lv_rate_lpi_l) = CONV decfloat34( ls_company_relprod_rate-latepaymentinterest / 100 ).
              DATA(lv_calc_lpi_l) = ( lv_totallocal * lv_rate_lpi_l ) + lv_res_lpi_local.
              lv_latepaymentinterestlocal = round( val = lv_calc_lpi_l dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_lpi_local = lv_calc_lpi_l - lv_latepaymentinterestlocal.
            ELSE.
              lv_latepaymentinterestlocal = 0.
              lv_res_lpi_local = 0.
            ENDIF.

            " 5. Provider Grossing Up Local
            IF ls_company_relprod_rate-providergrossingup <> 0.
              DATA(lv_rate_pgu_l) = CONV decfloat34( ls_company_relprod_rate-providergrossingup / 100 ).
              DATA(lv_calc_pgu_l) = ( lv_totallocal * lv_rate_pgu_l ) + lv_res_pgu_local.
              lv_providergrossinguplocal = round( val = lv_calc_pgu_l dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_pgu_local = lv_calc_pgu_l - lv_providergrossinguplocal.
            ELSE.
              lv_providergrossinguplocal = 0.
              lv_res_pgu_local = 0.
            ENDIF.
            " --- CÁLCULOS GLOBAL CURRENCY (MLA) ---

            " 1. Markup Global
            DATA(lv_rate_mup_g) = CONV decfloat34( ls_company_relprod_rate-markup / 100 ).
            DATA(lv_calc_mup_g) = ( ls_proposal_item_basis-amountinglobalcurrency * lv_rate_mup_g ) + lv_res_mup_global.
            lv_markup = round( val = lv_calc_mup_g dec = 2 mode = cl_abap_math=>round_half_up ).
            lv_res_mup_global = lv_calc_mup_g - lv_markup.

            " 2. Grossing Up Base Global
            DATA(lv_rate_gub_g) = CONV decfloat34( ls_company_relprod_rate-grossingupbase / 100 ).
            DATA(lv_div_gub_g)  = CONV decfloat34( 1 - lv_rate_gub_g ).

            IF lv_div_gub_g <> 1 AND lv_div_gub_g <> 0.
              DATA(lv_calc_gub_g) = ( ls_proposal_item_basis-amountinglobalcurrency / lv_div_gub_g - ls_proposal_item_basis-amountinglobalcurrency ) + lv_res_gub_global.
              lv_grossingupbase = round( val = lv_calc_gub_g dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_gub_global = lv_calc_gub_g - lv_grossingupbase.
            ELSE.
              lv_grossingupbase = 0.
              lv_res_gub_global = 0.
            ENDIF.

            " 3. Grossing Up Margin Global
            DATA(lv_rate_gum_g) = CONV decfloat34( ls_company_relprod_rate-grossingupmargin / 100 ).
            DATA(lv_div_gum_g)  = CONV decfloat34( 1 - lv_rate_gum_g ).

            IF lv_div_gum_g <> 1 AND lv_div_gum_g <> 0.
              DATA(lv_calc_gum_g) = ( lv_markup / lv_div_gum_g - lv_markup ) + lv_res_gum_global.
              lv_grossingupmargin = round( val = lv_calc_gum_g dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_gum_global = lv_calc_gum_g - lv_grossingupmargin.
            ELSE.
              lv_grossingupmargin = 0.
              lv_res_gum_global = 0.
            ENDIF.

            " Total Global
            lv_total = ls_proposal_item_basis-amountinglobalcurrency + lv_markup + lv_grossingupbase + lv_grossingupmargin.

            " 4. Late Payment Interest Global
            IF ls_company_relprod_rate-latepaymentinterest <> 0.
              DATA(lv_rate_lpi_g) = CONV decfloat34( ls_company_relprod_rate-latepaymentinterest / 100 ).
              DATA(lv_calc_lpi_g) = ( lv_total * lv_rate_lpi_g ) + lv_res_lpi_global.
              lv_latepaymentinterest = round( val = lv_calc_lpi_g dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_lpi_global = lv_calc_lpi_g - lv_latepaymentinterest.
            ELSE.
              lv_latepaymentinterest = 0.
              lv_res_lpi_global = 0.
            ENDIF.

            " 5. Provider Grossing Up Global
            IF ls_company_relprod_rate-providergrossingup <> 0.
              DATA(lv_rate_pgu_g) = CONV decfloat34( ls_company_relprod_rate-providergrossingup / 100 ).
              DATA(lv_calc_pgu_g) = ( lv_total * lv_rate_pgu_g ) + lv_res_pgu_global.
              lv_providergrossingup = round( val = lv_calc_pgu_g dec = 2 mode = cl_abap_math=>round_half_up ).
              lv_res_pgu_global = lv_calc_pgu_g - lv_providergrossingup.
            ELSE.
              lv_providergrossingup = 0.
              lv_res_pgu_global = 0.
            ENDIF.

*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
          ELSE.
            lv_markuplocal               = ls_proposal_item_basis-amountincompanycodecurrency * ( ls_company_relprod_rate-markup / 100 ).
            lv_grossingupbaselocal       = ( ls_proposal_item_basis-amountincompanycodecurrency / ( 1 - ( ls_company_relprod_rate-grossingupbase / 100 ) ) ) - ls_proposal_item_basis-amountincompanycodecurrency.
            lv_grossingupmarginlocal     = ( lv_markuplocal / ( 1 - ( ls_company_relprod_rate-grossingupmargin / 100 ) ) ) - lv_markuplocal.
            lv_totallocal                = ls_proposal_item_basis-amountincompanycodecurrency + lv_markuplocal + lv_grossingupbaselocal + lv_grossingupmarginlocal.
            lv_latepaymentinterestlocal  = lv_totallocal * ( ls_company_relprod_rate-latepaymentinterest / 100 ).
            lv_providergrossinguplocal   = lv_totallocal * ( ls_company_relprod_rate-providergrossingup / 100 ).

            lv_markup               = ls_proposal_item_basis-amountinglobalcurrency * ( ls_company_relprod_rate-markup / 100 ).
            lv_grossingupbase       = ( ls_proposal_item_basis-amountinglobalcurrency / ( 1 - ( ls_company_relprod_rate-grossingupbase / 100 ) ) ) - ls_proposal_item_basis-amountinglobalcurrency.
            lv_grossingupmargin     = ( lv_markup / ( 1 - ( ls_company_relprod_rate-grossingupmargin / 100 ) ) ) - lv_markup.
            lv_total                = ls_proposal_item_basis-amountinglobalcurrency + lv_markup + lv_grossingupbase + lv_grossingupmargin.
            lv_latepaymentinterest  = lv_total * ( ls_company_relprod_rate-latepaymentinterest / 100 ).
            lv_providergrossingup   = lv_total * ( ls_company_relprod_rate-providergrossingup / 100 ).
          ENDIF.


*          lv_itemcalc_id = lv_itemcalc_id + 1.
          GET TIME STAMP FIELD DATA(lv_tmst).
          APPEND VALUE #(
              id                             = ls_proposal->id
              item_id                        = ls_proposal_item_basis-item_id
              itembasis_id                   = ls_proposal_item_basis-itembasis_id
              itemcalc_id                    = <fs_item_to_upd>-itemcalc_id + 1
*              itemcalc_id                    = ls_proposal_item-itemcalc_id + 1
              commitstatus                   = ''
              markup                         = ls_company_relprod_rate-markup
              grossingupbase                 = ls_company_relprod_rate-grossingupbase
              grossingupmargin               = ls_company_relprod_rate-grossingupmargin
              latepaymentinterest            = ls_company_relprod_rate-latepaymentinterest
              providergrossingup             = ls_company_relprod_rate-providergrossingup
              markupamount                   = lv_markup
              grossingupbaseamount           = lv_grossingupbase
              grossingupmarginamount         = lv_grossingupmargin
              latepaymentinterestamount      = lv_latepaymentinterest
              providergrossingupamount       = lv_providergrossingup
              markupamntinlocal              = lv_markuplocal
              grossingupbaseamntinlocal      = lv_grossingupbaselocal
              grossingupmarginamntinlocal    = lv_grossingupmarginlocal
              latepaymentinterestamntinlocal = lv_latepaymentinterestlocal
              providergrossingupamntinlocal  = lv_providergrossinguplocal
              createdat                      = lv_tmst
              createdby                      = cl_abap_context_info=>get_user_technical_name( )
          ) TO lt_proposal_items_calc.

        ENDIF.
      ENDLOOP.

*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
      " Reiniciar acumuladores para el desglose G/L
      CLEAR: lv_res_mup_global,
             lv_res_gub_global,
             lv_res_gum_global,
             lv_res_lpi_global,
             lv_res_pgu_global,
             lv_res_mup_local,
             lv_res_gub_local,
             lv_res_gum_local,
             lv_res_lpi_local,
             lv_res_pgu_local.
      DATA: lv_last_item TYPE zfi_a_intrc_cpib-item_id.
*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo

      DATA(lt_proposal_items_baogl_upd) = me->prepare_pibglaccupd( CORRESPONDING #( lt_proposal_baoglacc[] ) ).
      LOOP AT lt_proposal_items_baogl_upd ASSIGNING FIELD-SYMBOL(<fs_proposal_baoglacc>).
*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
        " --- CORRECCIÓN 1: Reiniciar residuos al cambiar de Ítem ---
        IF lv_last_item <> <fs_proposal_baoglacc>-item_id.
          CLEAR: lv_res_mup_global, lv_res_gub_global, lv_res_gum_global, lv_res_lpi_global, lv_res_pgu_global,
                 lv_res_mup_local,  lv_res_gub_local,  lv_res_gum_local,  lv_res_lpi_local,  lv_res_pgu_local.
          lv_last_item = <fs_proposal_baoglacc>-item_id.
        ENDIF.
*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
        TRY.

            ASSIGN lt_proposal_item[ item_id = <fs_proposal_baoglacc>-item_id ] TO <fs_item_to_upd>.
*            <fs_item_to_upd> = lt_proposal_item[ item_id = <fs_proposal_baoglacc>-item_id ].
*            ls_proposal_item = lt_proposal_item[ item_id = <fs_proposal_baoglacc>-item_id ].
            ls_company_relprod_rate = lt_company_relprod_rate[ product              = <fs_item_to_upd>-product
                                                                     providercompanycode  = <fs_item_to_upd>-providercompanycode
                                                                     recipientcompanycode = <fs_item_to_upd>-recipientcompanycode ].
*        IF sy-subrc NE 0.
*          APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*          APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
*                                                                       number   = '013'
*                                                                       severity = if_abap_behv_message=>severity-error
*                                                                       v1       = ls_proposal_item-recipientcompanycode
*                                                                       v2       = ls_proposal_item-product
*                                                                       v3       = ls_proposal_item-item_id
*                          ) ) TO reported-zi_intercoproposal.
*        ELSE.

*Ini EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
            " --- CÁLCULOS DENTRO DEL LOOP BAOGL PARA MLA ---
            IF lv_soc = 'MLA'.
*            IF ls_proposal->providercompanycode = 'MLA'.

              " 0. Asignación obligatoria de tasas al Field-Symbol
              <fs_proposal_baoglacc>-markup              = ls_company_relprod_rate-markup.
              <fs_proposal_baoglacc>-grossingupbase      = ls_company_relprod_rate-grossingupbase.
              <fs_proposal_baoglacc>-grossingupmargin    = ls_company_relprod_rate-grossingupmargin.
              <fs_proposal_baoglacc>-latepaymentinterest = ls_company_relprod_rate-latepaymentinterest.
              <fs_proposal_baoglacc>-providergrossingup  = ls_company_relprod_rate-providergrossingup.

              " --- 1. CÁLCULOS MONEDA LOCAL (MLA) ---
              IF <fs_proposal_baoglacc>-amountincompanycodecurrency = 0.
                <fs_proposal_baoglacc>-markupamntinlocal           = 0.
                <fs_proposal_baoglacc>-grossingupbaseamntinlocal     = 0.
                <fs_proposal_baoglacc>-grossingupmarginamntinlocal   = 0.
                <fs_proposal_baoglacc>-latepaymentinterestamntinlocal = 0.
                <fs_proposal_baoglacc>-providergrossingupamntinlocal  = 0.
              ELSE.
                " Markup Local
                DATA(lv_rate_mup_baogl_l) = CONV decfloat34( ls_company_relprod_rate-markup / 100 ).
                DATA(lv_calc_mup_baogl_l) = ( <fs_proposal_baoglacc>-amountincompanycodecurrency * lv_rate_mup_baogl_l ) + lv_res_mup_local.
                <fs_proposal_baoglacc>-markupamntinlocal = round( val = lv_calc_mup_baogl_l dec = 2 mode = cl_abap_math=>round_half_up ).
                lv_res_mup_local = lv_calc_mup_baogl_l - <fs_proposal_baoglacc>-markupamntinlocal.

                " Grossing Up Base Local
                DATA(lv_rate_gub_baogl_l) = CONV decfloat34( ls_company_relprod_rate-grossingupbase / 100 ).
                DATA(lv_div_gub_baogl_l)  = CONV decfloat34( 1 - lv_rate_gub_baogl_l ).
                IF lv_div_gub_baogl_l <> 1 AND lv_div_gub_baogl_l <> 0.
                  DATA(lv_calc_gub_baogl_l) = ( <fs_proposal_baoglacc>-amountincompanycodecurrency / lv_div_gub_baogl_l - <fs_proposal_baoglacc>-amountincompanycodecurrency ) + lv_res_gub_local.
                  <fs_proposal_baoglacc>-grossingupbaseamntinlocal = round( val = lv_calc_gub_baogl_l dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_gub_local = lv_calc_gub_baogl_l - <fs_proposal_baoglacc>-grossingupbaseamntinlocal.
                ELSE.
                  <fs_proposal_baoglacc>-grossingupbaseamntinlocal = 0.
                  lv_res_gub_local = 0.
                ENDIF.

                " Grossing Up Margin Local
                DATA(lv_rate_gum_baogl_l) = CONV decfloat34( ls_company_relprod_rate-grossingupmargin / 100 ).
                DATA(lv_div_gum_baogl_l)  = CONV decfloat34( 1 - lv_rate_gum_baogl_l ).
                IF lv_div_gum_baogl_l <> 1 AND lv_div_gum_baogl_l <> 0.
                  DATA(lv_calc_gum_baogl_l) = ( <fs_proposal_baoglacc>-markupamntinlocal / lv_div_gum_baogl_l - <fs_proposal_baoglacc>-markupamntinlocal ) + lv_res_gum_local.
                  <fs_proposal_baoglacc>-grossingupmarginamntinlocal = round( val = lv_calc_gum_baogl_l dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_gum_local = lv_calc_gum_baogl_l - <fs_proposal_baoglacc>-grossingupmarginamntinlocal.
                ELSE.
                  <fs_proposal_baoglacc>-grossingupmarginamntinlocal = 0.
                  lv_res_gum_local = 0.
                ENDIF.

                " Total intermedio para intereses y recargo proveedor (Moneda Local)
                lv_totallocal = <fs_proposal_baoglacc>-amountincompanycodecurrency + <fs_proposal_baoglacc>-markupamntinlocal +
                               <fs_proposal_baoglacc>-grossingupbaseamntinlocal + <fs_proposal_baoglacc>-grossingupmarginamntinlocal.

                " Late Payment Interest Local
                IF ls_company_relprod_rate-latepaymentinterest <> 0.
                  DATA(lv_rate_lpi_baogl_l) = CONV decfloat34( ls_company_relprod_rate-latepaymentinterest / 100 ).
                  DATA(lv_calc_lpi_baogl_l) = ( lv_totallocal * lv_rate_lpi_baogl_l ) + lv_res_lpi_local.
                  <fs_proposal_baoglacc>-latepaymentinterestamntinlocal = round( val = lv_calc_lpi_baogl_l dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_lpi_local = lv_calc_lpi_baogl_l - <fs_proposal_baoglacc>-latepaymentinterestamntinlocal.
                ELSE.
                  <fs_proposal_baoglacc>-latepaymentinterestamntinlocal = 0.
                  lv_res_lpi_local = 0.
                ENDIF.

                " Provider Grossing Up Local (Variable faltante agregada)
                IF ls_company_relprod_rate-providergrossingup <> 0.
                  DATA(lv_rate_pgu_baogl_l) = CONV decfloat34( ls_company_relprod_rate-providergrossingup / 100 ).
                  DATA(lv_calc_pgu_baogl_l) = ( lv_totallocal * lv_rate_pgu_baogl_l ) + lv_res_pgu_local.
                  <fs_proposal_baoglacc>-providergrossingupamntinlocal = round( val = lv_calc_pgu_baogl_l dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_pgu_local = lv_calc_pgu_baogl_l - <fs_proposal_baoglacc>-providergrossingupamntinlocal.
                ELSE.
                  <fs_proposal_baoglacc>-providergrossingupamntinlocal = 0.
                  lv_res_pgu_local = 0.
                ENDIF.
              ENDIF.


              " --- 2. CÁLCULOS MONEDA GLOBAL (MLA) ---
              IF <fs_proposal_baoglacc>-amountinglobalcurrency = 0.
                <fs_proposal_baoglacc>-markupamount            = 0.
                <fs_proposal_baoglacc>-grossingupbaseamount      = 0.
                <fs_proposal_baoglacc>-grossingupmarginamount    = 0.
                <fs_proposal_baoglacc>-latepaymentinterestamount = 0.
                <fs_proposal_baoglacc>-providergrossingupamount  = 0.
              ELSE.
                " Markup Global
                DATA(lv_rate_mup_baogl_g) = CONV decfloat34( ls_company_relprod_rate-markup / 100 ).
                DATA(lv_calc_mup_baogl_g) = ( <fs_proposal_baoglacc>-amountinglobalcurrency * lv_rate_mup_baogl_g ) + lv_res_mup_global.
                <fs_proposal_baoglacc>-markupamount = round( val = lv_calc_mup_baogl_g dec = 2 mode = cl_abap_math=>round_half_up ).
                lv_res_mup_global = lv_calc_mup_baogl_g - <fs_proposal_baoglacc>-markupamount.

                " Grossing Up Base Global
                DATA(lv_rate_gub_baogl_g) = CONV decfloat34( ls_company_relprod_rate-grossingupbase / 100 ).
                DATA(lv_div_gub_baogl_g)  = CONV decfloat34( 1 - lv_rate_gub_baogl_g ).
                IF lv_div_gub_baogl_g <> 1 AND lv_div_gub_baogl_g <> 0.
                  DATA(lv_calc_gub_baogl_g) = ( <fs_proposal_baoglacc>-amountinglobalcurrency / lv_div_gub_baogl_g - <fs_proposal_baoglacc>-amountinglobalcurrency ) + lv_res_gub_global.
                  <fs_proposal_baoglacc>-grossingupbaseamount = round( val = lv_calc_gub_baogl_g dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_gub_global = lv_calc_gub_baogl_g - <fs_proposal_baoglacc>-grossingupbaseamount.
                ELSE.
                  <fs_proposal_baoglacc>-grossingupbaseamount = 0.
                  lv_res_gub_global = 0.
                ENDIF.

                " Grossing Up Margin Global
                DATA(lv_rate_gum_baogl_g) = CONV decfloat34( ls_company_relprod_rate-grossingupmargin / 100 ).
                DATA(lv_div_gum_baogl_g)  = CONV decfloat34( 1 - lv_rate_gum_baogl_g ).
                IF lv_div_gum_baogl_g <> 1 AND lv_div_gum_baogl_g <> 0.
                  DATA(lv_calc_gum_baogl_g) = ( <fs_proposal_baoglacc>-markupamount / lv_div_gum_baogl_g - <fs_proposal_baoglacc>-markupamount ) + lv_res_gum_global.
                  <fs_proposal_baoglacc>-grossingupmarginamount = round( val = lv_calc_gum_baogl_g dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_gum_global = lv_calc_gum_baogl_g - <fs_proposal_baoglacc>-grossingupmarginamount.
                ELSE.
                  <fs_proposal_baoglacc>-grossingupmarginamount = 0.
                  lv_res_gum_global = 0.
                ENDIF.

                " Total intermedio para intereses y recargo proveedor (Moneda Global)
                lv_total = <fs_proposal_baoglacc>-amountinglobalcurrency + <fs_proposal_baoglacc>-markupamount +
                           <fs_proposal_baoglacc>-grossingupbaseamount + <fs_proposal_baoglacc>-grossingupmarginamount.

                " Late Payment Interest Global
                IF ls_company_relprod_rate-latepaymentinterest <> 0.
                  DATA(lv_rate_lpi_baogl_g) = CONV decfloat34( ls_company_relprod_rate-latepaymentinterest / 100 ).
                  DATA(lv_calc_lpi_baogl_g) = ( lv_total * lv_rate_lpi_baogl_g ) + lv_res_lpi_global.
                  <fs_proposal_baoglacc>-latepaymentinterestamount = round( val = lv_calc_lpi_baogl_g dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_lpi_global = lv_calc_lpi_baogl_g - <fs_proposal_baoglacc>-latepaymentinterestamount.
                ELSE.
                  <fs_proposal_baoglacc>-latepaymentinterestamount = 0.
                  lv_res_lpi_global = 0.
                ENDIF.

                " Provider Grossing Up Global (Variable faltante agregada)
                IF ls_company_relprod_rate-providergrossingup <> 0.
                  DATA(lv_rate_pgu_baogl_g) = CONV decfloat34( ls_company_relprod_rate-providergrossingup / 100 ).
                  DATA(lv_calc_pgu_baogl_g) = ( lv_total * lv_rate_pgu_baogl_g ) + lv_res_pgu_global.
                  <fs_proposal_baoglacc>-providergrossingupamount = round( val = lv_calc_pgu_baogl_g dec = 2 mode = cl_abap_math=>round_half_up ).
                  lv_res_pgu_global = lv_calc_pgu_baogl_g - <fs_proposal_baoglacc>-providergrossingupamount.
                ELSE.
                  <fs_proposal_baoglacc>-providergrossingupamount = 0.
                  lv_res_pgu_global = 0.
                ENDIF.
              ENDIF.

*Fin EXT_OSCUGALD 09.02.2026 - Ajuste decimales redondeo
            ELSE.
              <fs_proposal_baoglacc>-markup                    = ls_company_relprod_rate-markup.
              <fs_proposal_baoglacc>-grossingupbase            = ls_company_relprod_rate-grossingupbase.
              <fs_proposal_baoglacc>-grossingupmargin          = ls_company_relprod_rate-grossingupmargin.
              <fs_proposal_baoglacc>-latepaymentinterest       = ls_company_relprod_rate-latepaymentinterest.
              <fs_proposal_baoglacc>-providergrossingup        = ls_company_relprod_rate-providergrossingup.

              <fs_proposal_baoglacc>-markupamntinlocal              = <fs_proposal_baoglacc>-amountincompanycodecurrency * ( ls_company_relprod_rate-markup / 100 ).
              <fs_proposal_baoglacc>-grossingupbaseamntinlocal      = ( <fs_proposal_baoglacc>-amountincompanycodecurrency / ( 1 - ( ls_company_relprod_rate-grossingupbase / 100 ) ) ) - <fs_proposal_baoglacc>-amountincompanycodecurrency.
              <fs_proposal_baoglacc>-grossingupmarginamntinlocal    = ( <fs_proposal_baoglacc>-markupamntinlocal / (  1 - ( ls_company_relprod_rate-grossingupmargin / 100 ) ) ) - <fs_proposal_baoglacc>-markupamntinlocal.
              lv_total = <fs_proposal_baoglacc>-amountincompanycodecurrency + <fs_proposal_baoglacc>-markupamntinlocal + <fs_proposal_baoglacc>-grossingupbaseamntinlocal + <fs_proposal_baoglacc>-grossingupmarginamntinlocal.
              <fs_proposal_baoglacc>-latepaymentinterestamntinlocal = lv_total * ( ls_company_relprod_rate-latepaymentinterest / 100 ).
              <fs_proposal_baoglacc>-providergrossingupamntinlocal  = lv_total * ( ls_company_relprod_rate-providergrossingup / 100 ).

              <fs_proposal_baoglacc>-markupamount              = <fs_proposal_baoglacc>-amountinglobalcurrency * ( ls_company_relprod_rate-markup / 100 ).
              <fs_proposal_baoglacc>-grossingupbaseamount      = ( <fs_proposal_baoglacc>-amountinglobalcurrency / ( 1 - ( ls_company_relprod_rate-grossingupbase / 100 ) ) ) - <fs_proposal_baoglacc>-amountinglobalcurrency.
              <fs_proposal_baoglacc>-grossingupmarginamount    = ( <fs_proposal_baoglacc>-markupamount / (  1 - ( ls_company_relprod_rate-grossingupmargin / 100 ) ) ) - <fs_proposal_baoglacc>-markupamount.
              lv_total = <fs_proposal_baoglacc>-amountinglobalcurrency + <fs_proposal_baoglacc>-markupamount + <fs_proposal_baoglacc>-grossingupbaseamount + <fs_proposal_baoglacc>-grossingupmarginamount.
              <fs_proposal_baoglacc>-latepaymentinterestamount = lv_total * ( ls_company_relprod_rate-latepaymentinterest / 100 ).
              <fs_proposal_baoglacc>-providergrossingupamount  = lv_total * ( ls_company_relprod_rate-providergrossingup / 100 ).
            ENDIF.


*        ENDIF.
          CATCH cx_sy_itab_line_not_found.
            IF NOT line_exists( failed-zi_intercoproposalitemcalc[ id           = ls_proposal_item_basis-id
                            item_id      = ls_proposal_item_basis-item_id
                            itembasis_id = ls_proposal_item_basis-itembasis_id
                            itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1 ] ).
              APPEND VALUE #( %key         = ls_proposal->%key
                              id           = ls_proposal_item_basis-id
                              item_id      = ls_proposal_item_basis-item_id
                              itembasis_id = ls_proposal_item_basis-itembasis_id
                              itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1 ) TO failed-zi_intercoproposalitemcalc.
              APPEND VALUE #( %key         = ls_proposal->%key
                              id           = ls_proposal_item_basis-id
                              item_id      = ls_proposal_item_basis-item_id
                              itembasis_id = ls_proposal_item_basis-itembasis_id
                              itemcalc_id  = <fs_item_to_upd>-itemcalc_id + 1
                              %msg         = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                          number   = '013'
                                                          severity = if_abap_behv_message=>severity-error
                                                          v1       = <fs_item_to_upd>-recipientcompanycode
                                                          v2       = <fs_item_to_upd>-product
                                                          v3       = <fs_item_to_upd>-item_id
                              ) ) TO reported-zi_intercoproposalitemcalc.
            ENDIF.
        ENDTRY.
      ENDLOOP.
*      SORT failed-zi_intercoproposalitemcalc BY id item_id itembasis_id itemcalc_id.
*      SORT reported-zi_intercoproposalitemcalc BY id item_id itembasis_id itemcalc_id.
*      DELETE ADJACENT DUPLICATES FROM failed-zi_intercoproposalitemcalc COMPARING id item_id itembasis_id itemcalc_id.
*      DELETE ADJACENT DUPLICATES FROM reported-zi_intercoproposalitemcalc COMPARING id item_id itembasis_id itemcalc_id.


      IF lt_proposal_items_calc IS NOT INITIAL.

        DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-calculated ).
        DATA(lt_proposal_items_upd) = me->prepareproposalitemstoupd( CORRESPONDING #( lt_proposal_item[] ) ).
        DATA(lt_proposal_items_basis_upd) = me->prepareproposalitemsbasistoupd( CORRESPONDING #( lt_proposal_item_basis[] ) ).
*        DATA(lt_proposal_items_baogl_upd) = me->prepare_pibglaccupd( CORRESPONDING #( lt_proposal_baoglacc[] ) ).

        LOOP AT lt_proposal_items_calc INTO DATA(ls_proposal_items_calc).
          APPEND VALUE #( id           = ls_proposal->id
                          item_id      = ls_proposal_items_calc-item_id
                          itembasis_id = ls_proposal_items_calc-itembasis_id
                          %target      = VALUE #( FOR item_calc IN lt_proposal_items_calc WHERE ( item_id = ls_proposal_items_calc-item_id AND itembasis_id = ls_proposal_items_calc-itembasis_id )
                                             ( CORRESPONDING #( item_calc ) )
                        ) ) TO lt_proposal_items_calc_upd.
        ENDLOOP.

        MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           ENTITY zi_intercoproposalitem UPDATE FROM lt_proposal_items_upd
           ENTITY zi_intercoproposalitembasis UPDATE FROM lt_proposal_items_basis_upd
           CREATE BY \_itemscalc AUTO FILL CID
           FIELDS ( id item_id itembasis_id itemcalc_id commitstatus markup grossingupbase grossingupmargin latepaymentinterest providergrossingup markupamount grossingupbaseamount
                    grossingupmarginamount latepaymentinterestamount providergrossingupamount markupamntinlocal grossingupbaseamntinlocal grossingupmarginamntinlocal
                    latepaymentinterestamntinlocal providergrossingupamntinlocal createdat createdby )
           WITH lt_proposal_items_calc_upd[]
           ENTITY zi_intercoproposalitembaoglac UPDATE FROM lt_proposal_items_baogl_upd
           MAPPED DATA(lt_mapped)
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).
      ENDIF.
    ENDIF.

* Vinicius - UPDATE - El resultado ya esta ->
*    read entities of zi_intercoproposal in local mode
*    entity zi_intercoproposal all fields with corresponding #( keys ) result data(lt_result) .
*
*    result = value #( for <fs> in lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
    result = VALUE #( FOR p IN lt_proposal_upd ( %tky = p-%tky %param = CORRESPONDING #( p ) ) ).
* Vinicius - UPDATE <-


  ENDMETHOD.

  METHOD invoice.

  ENDMETHOD.


  METHOD check.


    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
*          ENTITY ZI_IntercoProposalItem BY \_ProposalItemsBasis ALL FIELDS  WITH CORRESPONDING #( kEYS ) RESULT FINAL(lt_proposal_item_basis)
*          ENTITY ZI_IntercoProposalItemBasis BY \_ItemsCalc ALL FIELDS  WITH CORRESPONDING #( kEYS ) RESULT FINAL(lt_proposal_item_calc)
        FAILED DATA(lt_proposal_failed).

    READ TABLE lt_proposal INTO DATA(ls_proposal) INDEX 1.

    SELECT * FROM zfi_a_intrc_cpib WHERE id = @ls_proposal-id INTO TABLE @DATA(lt_proposal_item_basis).
    SELECT * FROM zfi_a_intrc_cpic WHERE id = @ls_proposal-id INTO TABLE @DATA(lt_proposal_item_calc).

    IF lt_proposal_item_calc IS INITIAL.
      APPEND VALUE #( %key = ls_proposal-%key ) TO failed-zi_intercoproposal.
      APPEND VALUE #( %key = ls_proposal-%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '010' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
    ENDIF.

    IF lt_proposal_item_basis IS INITIAL.
      APPEND VALUE #( %key = ls_proposal-%key ) TO failed-zi_intercoproposal.
      APPEND VALUE #( %key = ls_proposal-%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '009' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
      "    ELSE.
      "      SELECT * FROM ZI_IntercoProposalItemBasisRat
      "        WHERE id =  @ls_proposal-Id
      "        INTO TABLE @DATA(lt_PropItemBasisRateApplyed).
      "
      "      IF lt_PropItemBasisRateApplyed IS NOT INITIAL.
      "        DATA: lv_rate_applyed       TYPE p DECIMALS 4.
      "        LOOP AT lt_PropItemBasisRateApplyed INTO DATA(ls_PropItemBasisRateApplyed).
      "          lv_rate_applyed = CONV #( ls_PropItemBasisRateApplyed-totalRateApplyed ).
      "          IF lv_rate_applyed < 100.
      "            APPEND VALUE #( %key = ls_proposal-%key ) TO failed-zi_intercoproposal.
      "            APPEND VALUE #( %key = ls_proposal-%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
      "                                                                        number   = '008'
      "                                                                        severity = if_abap_behv_message=>severity-error
      "                                                                        v1       = ls_PropItemBasisRateApplyed-ProviderCompanyCode
      "                                                                        v2       = ls_PropItemBasisRateApplyed-ProfitCenter ) ) TO reported-zi_intercoproposal.
      "          ENDIF.
      "        ENDLOOP.
      "      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD applyexchangerate.
    DATA ld_lastday TYPE d.

    ld_lastday = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ is_proposal->fiscalyear }{ is_proposal->fiscalperiod+1 }01| ).

    rt_proposal_items_basis[] = it_proposal_items_basis[].
    DATA(lt_proposal_basis) = it_proposal_items_basis[].
    SORT lt_proposal_basis BY companycodecurrency globalcurrency.
    DELETE ADJACENT DUPLICATES FROM lt_proposal_basis COMPARING companycodecurrency globalcurrency.

    SELECT sourcecurrency, targetcurrency, exchangerateeffectivedate, exchangerate FROM zi_exchangerate
                FOR ALL ENTRIES IN @lt_proposal_basis
                WHERE exchangeratetype = 'B'
                  AND sourcecurrency = @lt_proposal_basis-companycodecurrency
                  AND targetcurrency = @lt_proposal_basis-globalcurrency
                  AND exchangerateeffectivedate EQ @ld_lastday "12/05 - GERSON: Fecha de conversión deberia ser la del periodo de la propuesta
                INTO TABLE @DATA(lt_exchange_rate).
*    SORT lt_exchange_rate BY exchangerateeffectivedate DESCENDING.
*    DELETE ADJACENT DUPLICATES FROM lt_exchange_rate COMPARING sourcecurrency targetcurrency.

* Ini EXT_OSCUGALD 03/02/2026 - Tipo de cambio USD - USD = 1- tcurr
    READ TABLE lt_exchange_rate INTO DATA(ls_exchange_rate) WITH KEY sourcecurrency            = 'USD'
                                                                     targetcurrency            = 'USD'
                                                                     exchangerateeffectivedate = ld_lastday.
    IF sy-subrc NE 0.
      ls_exchange_rate-SourceCurrency = 'USD'.
      ls_exchange_rate-TargetCurrency = 'USD'.
      ls_exchange_rate-ExchangeRateEffectiveDate = ld_lastday.
      ls_exchange_rate-ExchangeRate = -1.
      APPEND ls_exchange_rate TO lt_exchange_rate.
    ENDIF.
    SORT lt_exchange_rate BY exchangerateeffectivedate DESCENDING.
*Fin EXT_OSCUGALD 03/02/2026 - Tipo de cambio USD - USD = 1- tcurr


    SELECT sourcecurrency, targetcurrency, validitystartdate, numberofsourcecurrencyunits FROM i_exchangeratefactorsrawdata WITH PRIVILEGED ACCESS
    FOR ALL ENTRIES IN @lt_proposal_basis
    WHERE exchangeratetype = 'B'
    AND sourcecurrency = @lt_proposal_basis-companycodecurrency
    AND targetcurrency = @lt_proposal_basis-globalcurrency
    INTO TABLE @DATA(lt_exchange_rate_factors).
    SORT lt_exchange_rate_factors BY validitystartdate DESCENDING.

    LOOP AT rt_proposal_items_basis ASSIGNING FIELD-SYMBOL(<fs_item_basis>).
      "EXT_OSCUGALD 29.08.2025 Redefinición de obtención tipo de cambio promedio para todas las sociedades
      "Se comenta código que límita la obtención del exchangerate para todos los casos. ***

***      IF <fs_item_basis>-companycodecurrency = <fs_item_basis>-globalcurrency.
***        <fs_item_basis>-amountincompanycodecurrency = <fs_item_basis>-amountinglobalcurrency.
***      ELSE.
*        IF lt_exchange_rate IS NOT INITIAL.
      READ TABLE lt_exchange_rate INTO ls_exchange_rate WITH KEY
                                                        sourcecurrency = <fs_item_basis>-companycodecurrency
                                                        targetcurrency = <fs_item_basis>-globalcurrency
                                                        exchangerateeffectivedate = ld_lastday.
      IF sy-subrc NE 0.
        CHECK NOT line_exists( lt_proposal_basis[ companycodecurrency = <fs_item_basis>-companycodecurrency
                                              globalcurrency = <fs_item_basis>-globalcurrency
                                              createdby = abap_true
                                              ] ).
        APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
        APPEND VALUE #( %key = is_proposal->%key %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                                     number   = '020'
                                                                     severity = if_abap_behv_message=>severity-error
                                                                     v1       = <fs_item_basis>-companycodecurrency
                                                                     v2       = <fs_item_basis>-globalcurrency
                                                                     v3       = |{ ld_lastday DATE = USER }| ) ) TO cs_reported-zi_intercoproposal.
        lt_proposal_basis[ companycodecurrency = <fs_item_basis>-companycodecurrency
                                                 globalcurrency = <fs_item_basis>-globalcurrency
                                                 ]-createdby = abap_true.
      ELSE." ls_exchange_rate-exchangerate IS NOT INITIAL.
        <fs_item_basis>-amountincompanycodecurrency = <fs_item_basis>-amountinglobalcurrency * ( ls_exchange_rate-exchangerate * -1 ).
        <fs_item_basis>-exchangerate = ls_exchange_rate-exchangerate * -1.
      ENDIF.
*        ENDIF.
***      ENDIF.

      "  Exchange Rate Factor
      IF <fs_item_basis>-companycodecurrency = 'VES'. " todo: move to parameters table
        DATA(exchange_rate) = <fs_item_basis>-exchangerate.
        TRY.
            DATA(ls_exchange_rate_factor) = REF #( lt_exchange_rate_factors[ sourcecurrency = <fs_item_basis>-companycodecurrency targetcurrency = <fs_item_basis>-globalcurrency ] ).
            <fs_item_basis>-exchangerate = <fs_item_basis>-exchangerate * ls_exchange_rate_factor->numberofsourcecurrencyunits.
          CATCH cx_sy_itab_line_not_found.
            " nothing to do
          CATCH cx_sy_arithmetic_overflow.
            <fs_item_basis>-exchangerate = exchange_rate.
        ENDTRY.
        <fs_item_basis>-exchangefactor = COND #( WHEN ls_exchange_rate_factor->numberofsourcecurrencyunits IS NOT INITIAL THEN ls_exchange_rate_factor->numberofsourcecurrencyunits ELSE 1 ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD prepareproposalitemstoupd.
    rt_proposal_items[] = CORRESPONDING #( it_proposal_items[] ).
    LOOP AT rt_proposal_items ASSIGNING FIELD-SYMBOL(<fs_item>).
      <fs_item>-%control-interdivisional = '01'.
    ENDLOOP.
  ENDMETHOD.

  METHOD prepareproposalitemstoupd_cebe.
    rt_proposal_items[] = CORRESPONDING #( it_proposal_items[] ).
    LOOP AT rt_proposal_items ASSIGNING FIELD-SYMBOL(<fs_item>).
      <fs_item>-%control-interdivisional = '01'.
      <fs_item>-%control-baseamountprofitcenter = '01'.
      <fs_item>-%control-baseamountprofitcenterc = '01'.
      <fs_item>-%control-baseamountprofitcenterh = '01'.
      <fs_item>-%control-baseamountprofitcenterl = '01'.

      READ TABLE it_cebe_items INTO DATA(ls_cebe_items) WITH KEY profitcenter = <fs_item>-profitcenter.
      IF sy-subrc EQ 0.
        "Split importe base y gran total
        <fs_item>-baseamountprofitcenterc = ls_cebe_items-baseamountprofitcenter.
        <fs_item>-baseamountprofitcenterh = ls_cebe_items-baseamountprofitcenterh.
        <fs_item>-BaseAmountProfitCenterL = ls_cebe_items-BaseamountprofitcenterL.
        <fs_item>-baseamountprofitcenter  = ls_cebe_items-baseamountprofitcenter + ls_cebe_items-baseamountprofitcenterh + ls_cebe_items-BaseamountprofitcenterL.
      ELSE.
        CLEAR: <fs_item>-baseamountprofitcenterc, <fs_item>-baseamountprofitcenterh, <fs_item>-BaseAmountProfitCenterL, <fs_item>-baseamountprofitcenter.  "Genova
      ENDIF.
    ENDLOOP.
*    rt_proposal_items[] = CORRESPONDING #( it_proposal_items[] ).
*    LOOP AT rt_proposal_items ASSIGNING FIELD-SYMBOL(<fs_item>).
*      <fs_item>-%control-interdivisional = '01'.
*      <fs_item>-%control-baseamountprofitcenter = '01'.
*      <fs_item>-%control-baseamountprofitcenterc = '01'.
*      <fs_item>-%control-baseamountprofitcenterh = '01'.
*      <fs_item>-%control-baseamountprofitcenterl = '01'.
*      " ── NUEVO ──────────────────────────────────────────────────────────────
*      <fs_item>-%control-CpiCompanyCodeCurrency       = '01'.
*      <fs_item>-%control-AmountInCompanyCodeCurrency  = '01'.
*      <fs_item>-%control-AmountInCompanyCodeCurrencyC = '01'.
*      <fs_item>-%control-AmountInCompanyCodeCurrencyH = '01'.
*      <fs_item>-%control-AmountInCompanyCodeCurrencyL = '01'.
*      " ───────────────────────────────────────────────────────────────────────
*
*      READ TABLE it_cebe_items INTO DATA(ls_cebe_items) WITH KEY profitcenter = <fs_item>-profitcenter.
*      IF sy-subrc EQ 0.
*        "Split importe base y gran total
*        <fs_item>-baseamountprofitcenterc = ls_cebe_items-baseamountprofitcenter.
*        <fs_item>-baseamountprofitcenterh = ls_cebe_items-baseamountprofitcenterh.
*        <fs_item>-BaseAmountProfitCenterL = ls_cebe_items-BaseamountprofitcenterL.
*        <fs_item>-baseamountprofitcenter  = ls_cebe_items-baseamountprofitcenter + ls_cebe_items-baseamountprofitcenterh + ls_cebe_items-BaseamountprofitcenterL.
*        " ── NUEVO: leer moneda/monto local desde CPH ─────────────────────────
*        SELECT SINGLE companycodecurrency, amountincompanycodecurrency
*          FROM zfi_a_intrc_cph
*          WHERE id = @<fs_item>-id
*          INTO @DATA(ls_cph_local).
*        IF sy-subrc EQ 0.
*          <fs_item>-CpiCompanyCodeCurrency       = ls_cph_local-companycodecurrency.
*          <fs_item>-AmountInCompanyCodeCurrency  = ls_cph_local-amountincompanycodecurrency.
*          <fs_item>-AmountInCompanyCodeCurrencyC = ls_cph_local-amountincompanycodecurrency.
*          <fs_item>-AmountInCompanyCodeCurrencyH = 0.
*          <fs_item>-AmountInCompanyCodeCurrencyL = 0.
*        ENDIF.
*        " ─────────────────────────────────────────────────────────────────────
*      ELSE.
*        CLEAR: <fs_item>-baseamountprofitcenterc, <fs_item>-baseamountprofitcenterh, <fs_item>-BaseAmountProfitCenterL, <fs_item>-baseamountprofitcenter.  "Genova
*        " ── NUEVO ─────────────────────────────────────────────────────────────
*        CLEAR: <fs_item>-CpiCompanyCodeCurrency, <fs_item>-AmountInCompanyCodeCurrency,
*               <fs_item>-AmountInCompanyCodeCurrencyC, <fs_item>-AmountInCompanyCodeCurrencyH,
*               <fs_item>-AmountInCompanyCodeCurrencyL.
*        " ─────────────────────────────────────────────────────────────────────
*      ENDIF.
*    ENDLOOP.
  ENDMETHOD.

  METHOD prepareproposaltoupd.
    rt_proposal[] = CORRESPONDING #( it_proposal[] ).
    LOOP AT rt_proposal ASSIGNING FIELD-SYMBOL(<fs_proposal>).
      <fs_proposal>-status = iv_proposal_status.
      <fs_proposal>-%control-status = '01'.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanproposalitembasis.
    SELECT * FROM zfi_a_intrc_cpib WHERE id = @iv_proposalid INTO TABLE @DATA(lt_item_basis).

    IF lt_item_basis IS NOT INITIAL.

      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposalitem UPDATE FROM it_proposal_items
         ENTITY zi_intercoproposalitembasis
         DELETE FROM VALUE #( FOR item_basis IN lt_item_basis
                              ( id           = iv_proposalid
                                item_id      = item_basis-item_id
                                itembasis_id = item_basis-itembasis_id ) )
         MAPPED DATA(lt_mapped2)
         REPORTED DATA(lt_reported2)
         FAILED DATA(lt_failed2).

      "COMMIT ENTITIES.
    ENDIF.

  ENDMETHOD.

  METHOD prepareproposalitemsbasistoupd.
    rt_proposal_item_basis[] = CORRESPONDING #( it_proposal_item_basis[] ).
    LOOP AT rt_proposal_item_basis ASSIGNING FIELD-SYMBOL(<fs_basis>).
      <fs_basis>-%control-metric_id = '01'.
    ENDLOOP.
  ENDMETHOD.

  METHOD commit.


************ TEMP ****************->
    IF sy-uname = 'EXT_VINBARRI' AND sy-sysid = 'DS4'.
      READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(current_proposals) .

      LOOP AT current_proposals REFERENCE INTO DATA(current_proposal).
        current_proposal->status = 'I'.
      ENDLOOP.

      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
            UPDATE FIELDS ( status ) WITH CORRESPONDING #( current_proposals ).

      result = VALUE #( FOR cr IN current_proposals ( %tky   = cr-%tky
                                                      %param = cr ) ).
      RETURN.
    ENDIF.
************ TEMP **************** <-

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         FAILED DATA(header_fail).

* Vinicius - eso ya es garantizado por las features ->
*    read table lt_proposal reference into data(ls_proposal) index 1.
*    if ls_proposal->Status ne 'C' and ls_proposal->Status ne 'S'.
*      append value #( %key = ls_proposal->%key ) to failed-zi_intercoproposal.
*      append value #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '016' severity = if_abap_behv_message=>severity-error ) ) to reported-zi_intercoproposal.
*return.
*    endif.
* vinicius <-
    DATA(lv_status) = lt_proposal[ 1 ]-status.
    IF lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-calculated
    OR lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-simulation_error
    OR lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-simulation_ok.
      DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-invoicing_started ).
    ELSEIF lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-invoicing_error
           OR lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_error.
      lt_proposal_upd = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_started ).
    ENDIF.
    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).

* Vinicius - el resultado ya esta ->
*    read entities of zi_intercoproposal in local mode
*      entity zi_intercoproposal all fields with corresponding #( keys ) result data(lt_result) .

*    result = value #( for <fs> in lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
    result = VALUE #( FOR r IN lt_proposal_upd ( %tky = r-%tky %param = CORRESPONDING #( r ) ) ).
* Vinicius <-

  ENDMETHOD.

  METHOD committest.

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         FAILED DATA(header_fail).

*    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

*    IF ls_proposal->status EQ zcl_proposal_bo_abs=>c_proposal_status-calculated
*       OR ls_proposal->status NE zcl_proposal_bo_abs=>c_proposal_status-invoicing_error"Para reprocesar
*       OR ls_proposal->status NE zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_error."Para reprocesar
    DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-test_invoicing ).

    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).
*    ELSE.
*
*      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '016' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
*
*    ENDIF.

    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
      ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result) .

    result = VALUE #( FOR <fs> IN lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .

  ENDMETHOD.

  METHOD getdocumentflow.
    TYPES: ltty_docher TYPE TABLE FOR FUNCTION RESULT zi_intercoproposal~getdocumentflow,
           ltys_docher TYPE STRUCTURE FOR FUNCTION RESULT zi_intercoproposal~getdocumentflow,
           ltty_child  TYPE ltys_docher-%param-_child,
           ltys_child  TYPE LINE OF ltys_docher-%param-_child.
    DATA: lt_docher TYPE ltty_docher,
          ls_docher TYPE ltys_docher,
          lt_child  TYPE ltty_child,
          ls_child  TYPE ltys_child.
    DATA: lv_guid TYPE zi_intercoproposal-id.
    lv_guid = keys[ 1 ]-id.

*    select id, documenttype, documentkey, documentname, parentdocumenttype, parentdocumentkey, parentdocumentname, category_id, isadjustment, status, createdby, createdat
*    from zi_intercoproposalflow
*    where id eq @lv_guid
*    order by parentdocumentkey ascending, documentkey descending
*    into table @data(lt_docflow).
*
*    loop at lt_docflow assigning field-symbol(<fs_proposal_d>).
*      if <fs_proposal_d>-parentdocumentkey is initial.
*        ls_docher-id = lv_guid.
*        move-corresponding <fs_proposal_d> to ls_docher-%param.
*        append ls_docher to result.
*      else.
*        assign result[ %param-documentkey = <fs_proposal_d>-parentdocumentkey ] to field-symbol(<fs_docher>).
*        move-corresponding <fs_proposal_d> to ls_child.
*        append ls_child to <fs_docher>-%param-_child.
*      endif.
*    endloop.

  ENDMETHOD.

  METHOD callevent.


  ENDMETHOD.

  METHOD reverse.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         FAILED DATA(header_fail).

*    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.
*    IF ls_proposal->status NE 'C' AND ls_proposal->status NE 'S' AND ls_proposal->status NE 'P'
*        AND ls_proposal->status NE 'E' AND ls_proposal->status NE 'T' AND ls_proposal->status NE 'N'
*        AND ls_proposal->status NE 'O' AND ls_proposal->status NE 'B' AND ls_proposal->status NE 'D'
*        AND ls_proposal->status NE 'F'..
*      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '016' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
*    ELSE.

    DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-anulation_started ).

    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).
*    ENDIF.

*    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
*      ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result) .
*
*    result = VALUE #( FOR <fs> IN lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
    result = VALUE #( FOR <fs> IN lt_proposal_upd ( %tky = <fs>-%tky %param = CORRESPONDING #( <fs> ) ) ).

  ENDMETHOD.

  METHOD anulatetest.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         FAILED DATA(header_fail).

*    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.
*    IF    ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoiced
*       OR ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-invoicing_error
*       OR ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-reinvoiced
*       OR ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-reinvoicing_error
*       OR ls_proposal->status = zcl_proposal_bo_abs=>c_proposal_status-anulation_error.
    DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-test_anulation ).

    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).
*    ELSE.
*      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '016' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
*
*    ENDIF.

*    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
*      ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result) .
*
*    result = VALUE #( FOR <fs> IN lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
    result = VALUE #( FOR <fs> IN lt_proposal_upd ( %tky = <fs>-%tky %param = CORRESPONDING #( <fs> ) ) ).

  ENDMETHOD.

  METHOD reverseitem.
*    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
*         ENTITY ZI_IntercoProposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
*         FAILED DATA(header_fail).
*
*    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.
*    IF ls_proposal->Status NE 'C' AND ls_proposal->Status NE 'S' AND ls_proposal->Status NE 'T'.
*      APPEND VALUE #( %key = ls_proposal->%key ) TO failed-zi_intercoproposal.
*      APPEND VALUE #( %key = ls_proposal->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '016' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercoproposal.
*    ELSE.
*
*      DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = 'A' ).
*
*      MODIFY ENTITIES OF ZI_IntercoProposal IN LOCAL MODE
*             ENTITY ZI_IntercoProposal UPDATE FROM lt_proposal_upd
*             REPORTED DATA(lt_reported)
*             FAILED DATA(lt_failed).
*    ENDIF.
*
*    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
*      ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result) .
*
**    result = VALUE #( FOR <fs> IN lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .

  ENDMETHOD.
  METHOD get_instance_authorizations_1.
  ENDMETHOD.


  METHOD get_proposal_item_gl.

    SELECT id, itemid, glaccount, costcenter, globalcurrency, amountinglobalcurrency, percentoftotal, costcenterd4
    FROM zi_intercoproposalitemorglacct
    FOR ALL ENTRIES IN @it_proposal_items_basis
    WHERE id = @it_proposal_items_basis-id
      AND itemid = @it_proposal_items_basis-item_id

    INTO CORRESPONDING FIELDS OF TABLE @rt_proposal_item_gl.

  ENDMETHOD.

  METHOD setappliedmetric.
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
             ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys )
             RESULT DATA(lt_proposal)
             FAILED DATA(lt_proposal_failed).

    DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-verified ).

    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).

    result = VALUE #( FOR <fs> IN lt_proposal_upd ( %tky = <fs>-%tky %param = CORRESPONDING #( <fs> ) ) ).
  ENDMETHOD.

  METHOD prepare_pibglaccupd.
    rt_proposal_item_baoglacc[] = CORRESPONDING #( it_proposal_item_baoglacc[] ).
    LOOP AT rt_proposal_item_baoglacc ASSIGNING FIELD-SYMBOL(<fs_baogl>).
      <fs_baogl>-%control-markup                    = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupbase            = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupmargin          = if_abap_behv=>mk-on.
      <fs_baogl>-%control-latepaymentinterest       = if_abap_behv=>mk-on.
      <fs_baogl>-%control-providergrossingup        = if_abap_behv=>mk-on.
      <fs_baogl>-%control-markupamount              = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupbaseamount      = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupmarginamount    = if_abap_behv=>mk-on.
      <fs_baogl>-%control-latepaymentinterestamount = if_abap_behv=>mk-on.
      <fs_baogl>-%control-providergrossingupamount  = if_abap_behv=>mk-on.
      <fs_baogl>-%control-markupamntinlocal              = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupbaseamntinlocal      = if_abap_behv=>mk-on.
      <fs_baogl>-%control-grossingupmarginamntinlocal    = if_abap_behv=>mk-on.
      <fs_baogl>-%control-latepaymentinterestamntinlocal = if_abap_behv=>mk-on.
      <fs_baogl>-%control-providergrossingupamntinlocal  = if_abap_behv=>mk-on.
    ENDLOOP.
  ENDMETHOD.

  METHOD simulation.


    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal)
         FAILED DATA(header_fail).

    DATA(lv_status) = lt_proposal[ 1 ]-status.
    IF lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-calculated OR lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-simulation_ok OR lv_status EQ zcl_proposal_bo_abs=>c_proposal_status-simulation_error.
      DATA(lt_proposal_upd) = me->prepareproposaltoupd( EXPORTING it_proposal = CORRESPONDING #( lt_proposal[] ) iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-simulation_started ).
    ENDIF.
    MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
           ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
           REPORTED DATA(lt_reported)
           FAILED DATA(lt_failed).

    result = VALUE #( FOR r IN lt_proposal_upd ( %tky = r-%tky %param = CORRESPONDING #( r ) ) ).

  ENDMETHOD.

  METHOD GetAvailableMetrics.
    " Declaración de variables locales para la función
*    DATA: lt_regional_metric_api TYPE zcl_interco_btp_cap_metric_api=>tt_metric_header.
    DATA: lt_metric_api    TYPE zcl_interco_btp_cap_metric_api=>tt_metric_header.
    " Declaración de la tabla de resultados del tipo esperado
    DATA lt_result_params LIKE result.
    DATA ls_result_param LIKE LINE OF result.

    " 1. Lectura de la entidad raíz y lógica de negocio
    READ ENTITIES OF zi_intercoproposal IN LOCAL MODE
         ENTITY zi_intercoproposal ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_proposal).
    READ TABLE lt_proposal REFERENCE INTO DATA(ls_proposal) INDEX 1.

    " 1.1 Obtener el código de métrica asociado al producto
    SELECT SINGLE zi_intercoproduct~metric
      FROM zi_intercoproduct
      WHERE product EQ @ls_proposal->product
      INTO @DATA(lv_product_metric).

    IF lv_product_metric IS INITIAL.
      RETURN.
    ENDIF.

    " 1.2 Ramificación — mismo criterio que applymetric
    DATA(lo_cap_api) = zcl_interco_btp_cap_metric_api=>get_instance( ).

*Ini EXT_OSCUGALD 28.07.2026 - Bermudas MIC (SDFPSINIC-23362)
*  SM no usa CAP API BTP (lee de zfi_a_intrc_cpig). Se devuelve una fila
*  sintética "aplicable" para que el frontend habilite el botón ApplyMetric.
*  SM no maneja versiones: version fija '01', isreleased = 'X'.
    IF lv_product_metric = 'SM'.
      APPEND VALUE #(
        %key                = keys[ 1 ]-%key
        %param-metric       = lv_product_metric
        %param-fiscalyear   = ls_proposal->fiscalyear
        %param-fiscalperiod = ls_proposal->fiscalperiod
        %param-version      = '01'
        %param-isreleased   = 'X'
        %param-createdby    = cl_abap_context_info=>get_user_technical_name( )
      ) TO result.
      RETURN.
    ENDIF.
*Fin EXT_OSCUGALD 28.07.2026 - Bermudas MIC

    IF lv_product_metric = 'IC' OR lv_product_metric = 'CS'.
      " Métrica local: CS = Generales, IC = Customer Experience
      lt_metric_api = lo_cap_api->get_local_metric(
          EXPORTING iv_fiscal_period = ls_proposal->fiscalperiod
                    iv_fiscal_year   = ls_proposal->fiscalyear
                    iv_metric_code   = CONV #( lv_product_metric ) ).
    ELSE.
      " Métrica regional
      lt_metric_api = lo_cap_api->get_regional_metric(
          EXPORTING iv_fiscal_period = ls_proposal->fiscalperiod
                    iv_fiscal_year   = ls_proposal->fiscalyear
                    iv_metric_code   = CONV #( lv_product_metric ) ).
    ENDIF.

    " 2. Mapeo EXPLICITO y Conversión de Tipos
    LOOP AT lt_metric_api INTO DATA(ls_api_metric).

*      MOVE-CORRESPONDING lt_regional_metric_api TO result.
      " Limpiar la estructura de destino antes de mapear
      CLEAR ls_result_param.

      " 2.1 Asignación y Conversión:
      " FiscalYear y FiscalPeriod vienen como STRING y deben ir a sus tipos de DDIC (e.g., FIS_GJAHR_NO_CONV, FINS_FISCALPERIOD)
      ls_result_param-%key                = keys[ 1 ]-%key.
      ls_result_param-%param-metric       = CONV #( ls_api_metric-metric ).
      ls_result_param-%param-fiscalyear   = CONV #( ls_api_metric-fiscalyear ).
      ls_result_param-%param-fiscalperiod = CONV #( ls_api_metric-fiscalperiod ).
      ls_result_param-%param-version      = CONV #( ls_api_metric-version ).
      ls_result_param-%param-isreleased   = CONV #( ls_api_metric-isreleased ).
      ls_result_param-%param-createdby    = CONV #( ls_api_metric-createdby ).
      ls_result_param-%param-releasedat   = ls_api_metric-releasedat.
      ls_result_param-%param-releasedby   = CONV #( ls_api_metric-releasedby ).

      APPEND ls_result_param TO lt_result_params.

    ENDLOOP.

    " 3. Asignar el resultado mapeado a la variable 'result' del framework
    result = lt_result_params.

  ENDMETHOD.

  METHOD get_proposal_item_gl_genova.

    TYPES: BEGIN OF ty_id_map,
             original_id TYPE zde_prop_item_id,
             new_id      TYPE zde_prop_item_id,
           END OF ty_id_map.
    DATA lt_id_mapping TYPE HASHED TABLE OF ty_id_map WITH UNIQUE KEY original_id.

    " 1. Carga de constantes TVARVC (Filtros Genova)
    SELECT name, low FROM zi_tvarvc
      WHERE name IN ('Z_GENOVA_PROVIDER', 'Z_GENOVA_PRODUCT', 'Z_GENOVA_HIER')
      INTO TABLE @DATA(lt_constants).

    " 2. Lectura de datos base
    SELECT
        source~id,
        source~itemid,
        source~glaccount,
        source~costcenter,
        source~department,
        source~amountinglobalcurrency,
        source~AmountInGlobalCurrencyH,
        source~AmountInGlobalCurrencyL,
        source~percentoftotal,
        source~costcenterd4,
        source~cebe_aux,
        source~costcenterstdhierarea,
        header~providercompanycode,
        header~product
      FROM zi_intercoproposalitemorglacct AS source
      INNER JOIN zi_intercoproposal AS header ON source~id = header~id
      FOR ALL ENTRIES IN @it_proposal_items_basis
      WHERE source~id     = @it_proposal_items_basis-id
        AND source~itemid = @it_proposal_items_basis-item_id
      INTO TABLE @DATA(lt_raw_data).

    " --- CAMBIO CLAVE: Determinar el ID máximo global sobre it_proposal_item ---
    " it_proposal_item contiene la foto completa (registros existentes)
    " Si it_proposal_item tiene IDs del 1 al 9, lv_global_max_id empezará en 9.
    DATA(lv_global_max_id) = 0.
    LOOP AT it_proposal_item ASSIGNING FIELD-SYMBOL(<fs_full_list>).
      " Acceso dinámico por si el campo es Item_Id o itemid según el tipo de tabla
      ASSIGN COMPONENT 'ITEM_ID' OF STRUCTURE <fs_full_list> TO FIELD-SYMBOL(<lv_curr_id>).
      IF sy-subrc <> 0.
        ASSIGN COMPONENT 'ITEMID' OF STRUCTURE <fs_full_list> TO <lv_curr_id>.
      ENDIF.

      IF sy-subrc = 0 AND <lv_curr_id> > lv_global_max_id.
        lv_global_max_id = <lv_curr_id>.
      ENDIF.
    ENDLOOP.

*    " 1. Determinamos el ID máximo global inicial para no colisionar con lo existente
*    " Si lt_raw_data tiene IDs del 1 al 9, lv_global_max_id empezará en 9.
*    DATA(lv_global_max_id) = 0.
*    LOOP AT lt_raw_data INTO DATA(ls_max_check).
*      IF ls_max_check-itemid > lv_global_max_id.
*        lv_global_max_id = ls_max_check-itemid.
*      ENDIF.
*    ENDLOOP.

    LOOP AT lt_raw_data ASSIGNING FIELD-SYMBOL(<ls_raw>).
      " --- REGISTRO ORIGINAL (MANTENER CEBE 200) ---
      APPEND CORRESPONDING #( <ls_raw> ) TO rt_proposal_item_gl.

      " --- LÓGICA DE DUPLICACIÓN (AGREGAR CEBE 299) ---
      " Verificamos si cumple condiciones Genova para generar el hijo
      IF <ls_raw>-cebe_aux = '200' AND
         line_exists( lt_constants[ name = 'Z_GENOVA_PROVIDER' low = <ls_raw>-providercompanycode ] ) AND
         line_exists( lt_constants[ name = 'Z_GENOVA_PRODUCT'  low = <ls_raw>-product ] ) AND
         line_exists( lt_constants[ name = 'Z_GENOVA_HIER'     low = <ls_raw>-costcenterstdhierarea ] ).

        " Buscamos si ya hemos generado un nuevo ID para este bloque original
        READ TABLE lt_id_mapping ASSIGNING FIELD-SYMBOL(<ls_map>)
             WITH TABLE KEY original_id = <ls_raw>-itemid.
        IF sy-subrc <> 0.
          lv_global_max_id += 1.
          INSERT VALUE #( original_id = <ls_raw>-itemid new_id = lv_global_max_id )
                 INTO TABLE lt_id_mapping ASSIGNING <ls_map>.
        ENDIF.
        APPEND INITIAL LINE TO rt_proposal_item_gl ASSIGNING FIELD-SYMBOL(<ls_new>).
        <ls_new> = CORRESPONDING #( <ls_raw> ).

        <ls_new>-CostCenterD4 = <ls_new>-CostCenter+3(1).

        " Modificamos los campos para el nuevo registro
        <ls_new>-itemid   = <ls_map>-new_id.
        <ls_new>-cebe_aux = '299'.
        <ls_new>-CostCenterStdHierArea = 'IT0722'.


      ENDIF.
    ENDLOOP.

  ENDMETHOD.
  METHOD apply_local_metric.

    " ── Tipos locales ─────────────────────────────────────────────────────────
    TYPES: BEGIN OF ty_itemorglacct_aux,
             id               TYPE uuid,
             itemid           TYPE zde_prop_item_id,
             glaccount        TYPE hkont,
             costcenter       TYPE kostl,
             globalcurrency_c TYPE zint_dte_fis_ksl,
             globalcurrency_h TYPE zint_dte_fis_ksl,
             globalcurrency_l TYPE zint_dte_fis_ksl,
             percentoftotal   TYPE zde_per_from_total,
             costcenterd4     TYPE n LENGTH 1,
           END OF ty_itemorglacct_aux.

    TYPES: BEGIN OF ty_cpig_item,
             item_id    TYPE zde_prop_item_id,
             baseamount TYPE decfloat34,
           END OF ty_cpig_item.

    TYPES: BEGIN OF ty_basis_glacct,
             id                          TYPE uuid,
             item_id                     TYPE zde_prop_item_id,
             itembasis_id                TYPE zde_prop_basis_id,
             globalcurrency              TYPE zint_dte_fis_rkcur,
             amountinglobalcurrency      TYPE zint_dte_fis_ksl,
             amountinglobalcurrency_l    TYPE zint_dte_fis_ksl,
             companycodecurrency         TYPE zint_dte_fis_hwaer,
             amountincompanycodecurrency TYPE zint_dte_fis_hsl,
             glaccount1                  TYPE saknr,
           END OF ty_basis_glacct.

    TYPES: BEGIN OF ty_basis_idx,
             item_id      TYPE zde_prop_item_id,
             itembasis_id TYPE zde_prop_basis_id,
             cid          TYPE string,
           END OF ty_basis_idx.

    TYPES: BEGIN OF ty_brl_by_soc,
             recipientcompanycode TYPE bukrs,
             brl_total            TYPE decfloat34,
             brl_acum             TYPE decfloat34,
             item_count           TYPE i,
             item_index           TYPE i,
           END OF ty_brl_by_soc.

    DATA: lt_itemorglacct_aux  TYPE STANDARD TABLE OF ty_itemorglacct_aux,
          ls_itemorglacct_aux  TYPE ty_itemorglacct_aux,
          ls_metric_item_calc  TYPE zcl_interco_btp_cap_metric_api=>ty_item_calculated,
          lt_metric_items_calc TYPE zcl_interco_btp_cap_metric_api=>tt_item_calculated.

    DATA lt_brl_by_soc TYPE HASHED TABLE OF ty_brl_by_soc
                       WITH UNIQUE KEY recipientcompanycode.

    " ── 0. Carga inicial de datos de referencia ────────────────────────────────
    SELECT item_id,
           SUM( amount_in_global_currency ) AS baseamount
      FROM zfi_a_intrc_cpig
      WHERE id = @is_proposal->id
      GROUP BY item_id
      INTO TABLE @DATA(lt_cpig_by_item).

    SELECT companycode, currency FROM zi_intercocompanycode
      FOR ALL ENTRIES IN @it_proposal_item
      WHERE companycode = @it_proposal_item-recipientcompanycode
      INTO TABLE @DATA(lt_companies).

*    " ── TC implícito IC05: BRL/USD = monto_local / monto_global ──────────────
*    DATA(lv_tc_ic05) = COND decfloat34(
*      WHEN is_proposal->amountinglobalcurrency IS NOT INITIAL
*       AND CONV decfloat34( is_proposal->amountinglobalcurrency ) <> 0
*      THEN CONV decfloat34( is_proposal->amountincompanycodecurrency )
*           / CONV decfloat34( is_proposal->amountinglobalcurrency )
*      ELSE 0 ).

    DATA(lv_company_currency_ic05) = is_proposal->companycodecurrency.

    DATA(lv_total_brl)   = CONV decfloat34( is_proposal->amountincompanycodecurrency ).
    DATA(lv_acum_brl)    = CONV decfloat34( 0 ).
    DATA(lv_items_count) = lines( it_proposal_item ).
    DATA(lv_item_index)  = 0.

    " ── Parámetros Cost Sharing desde TVARVC ──────────────────────────────────
*Ini EXT_OSCUGALD 27.05.2026 - Cost Sharing: lectura de parámetros TVARVC para cpbg
    DATA lv_cs_ceco_bg TYPE c LENGTH 4.
    DATA lv_cs_cebe_bg TYPE c LENGTH 3.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_CS_CECO_PREFIX' AND type = 'P'
      INTO @lv_cs_ceco_bg.
    IF sy-subrc <> 0. lv_cs_ceco_bg = '9590'. ENDIF.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_CS_CEBE' AND type = 'P'
      INTO @lv_cs_cebe_bg.
    IF sy-subrc <> 0. lv_cs_cebe_bg = '999'. ENDIF.

    DATA(lv_ceco_bg) =
      |{ lv_cs_ceco_bg }{ is_proposal->internalcode }{ lv_cs_cebe_bg }|.
*Fin EXT_OSCUGALD 27.05.2026 - Cost Sharing

    " ── 1. Obtener header de métrica local desde BTP CAP ─────────────────────
    DATA(lo_cap_api) = zcl_interco_btp_cap_metric_api=>get_instance( ).

    DATA(lt_local_metric) = lo_cap_api->get_local_metric(
      EXPORTING iv_fiscal_period = is_proposal->fiscalperiod
                iv_fiscal_year   = is_proposal->fiscalyear
                iv_metric_code   = CONV #( iv_product_metric ) ).

    IF lt_local_metric IS INITIAL.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      APPEND VALUE #( %key = is_proposal->%key
        %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                            number   = '011'
                            severity = if_abap_behv_message=>severity-warning
                            v1       = iv_product_metric
                            v2       = is_proposal->fiscalperiod+1(2)
                            v3       = is_proposal->fiscalyear ) ) TO cs_reported-zi_intercoproposal.
      RETURN.
    ENDIF.

    " ── 2. Selección de versión de métrica ────────────────────────────────────
    DATA ls_local_metric LIKE LINE OF lt_local_metric.

    DATA(lv_param_version) = iv_param-version.
    SHIFT lv_param_version LEFT DELETING LEADING '0'.

    IF lines( lt_local_metric ) > 1.
      DATA(lv_metric)  = CONV string( iv_param-metric ).
      DATA(lv_version) = CONV string( lv_param_version ).
      READ TABLE lt_local_metric INTO ls_local_metric
        WITH KEY metric  = lv_metric
                 version = lv_version.
    ELSE.
      READ TABLE lt_local_metric INTO ls_local_metric INDEX 1.
    ENDIF.

    IF ls_local_metric-isreleased EQ ''.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      IF sy-sysid EQ 'TS4'.
        APPEND VALUE #( %key = is_proposal->%key
          %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                              number   = '005'
                              severity = if_abap_behv_message=>severity-warning ) ) TO cs_reported-zi_intercoproposal.
      ELSE.
        APPEND VALUE #( %key = is_proposal->%key
          %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                              number   = '005'
                              severity = if_abap_behv_message=>severity-error ) ) TO cs_reported-zi_intercoproposal.
      ENDIF.
      RETURN.
    ENDIF.

    " ── 3. Obtener ítems calculados de la métrica local desde BTP CAP ─────────
    lt_metric_items_calc = lo_cap_api->get_local_metric_items_calc(
      EXPORTING iv_fiscal_period = is_proposal->fiscalperiod
                iv_fiscal_year   = is_proposal->fiscalyear
                iv_metric_code   = CONV #( iv_product_metric )
                iv_product       = CONV #( is_proposal->product )
                iv_provide_code  = CONV #( is_proposal->providercompanycode ) ).

    IF lt_metric_items_calc IS INITIAL.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      APPEND VALUE #( %key = is_proposal->%key
        %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                            number   = '006'
                            severity = if_abap_behv_message=>severity-error ) ) TO cs_reported-zi_intercoproposal.
      RETURN.
    ENDIF.

    " ── Pre-calcular BRL por sociedad (lt_metric_items_calc ya está llena) ────
    LOOP AT it_proposal_item ASSIGNING FIELD-SYMBOL(<fs_pi_pre>).
      READ TABLE lt_metric_items_calc INTO DATA(ls_mic_pre)
        WITH KEY product              = is_proposal->product
                 providercompanycode  = is_proposal->providercompanycode
                 recipientcompanycode = <fs_pi_pre>-recipientcompanycode
                 to_header_version    = lv_param_version.
      IF sy-subrc = 0.
        READ TABLE lt_brl_by_soc WITH TABLE KEY
          recipientcompanycode = <fs_pi_pre>-recipientcompanycode
          TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          INSERT VALUE #(
            recipientcompanycode = <fs_pi_pre>-recipientcompanycode
            brl_total  = 0
            brl_acum   = 0
            item_count = REDUCE i( INIT c = 0
                           FOR ls_c IN it_proposal_item
                           WHERE ( recipientcompanycode = <fs_pi_pre>-recipientcompanycode )
                           NEXT c = c + 1 )
            item_index = 0
          ) INTO TABLE lt_brl_by_soc.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " ── Determinar última sociedad con métrica (absorberá el residuo) ─────────
    DATA(lv_last_soc_key) = VALUE bukrs( ).
    LOOP AT it_proposal_item ASSIGNING FIELD-SYMBOL(<fs_pi_last>).
      READ TABLE lt_metric_items_calc TRANSPORTING NO FIELDS
        WITH KEY product              = is_proposal->product
                 providercompanycode  = is_proposal->providercompanycode
                 recipientcompanycode = <fs_pi_last>-recipientcompanycode
                 to_header_version    = lv_param_version.
      IF sy-subrc = 0.
        lv_last_soc_key = <fs_pi_last>-recipientcompanycode.
      ENDIF.
    ENDLOOP.

    " ── Asignar brl_total por sociedad; última absorbe residuo ───────────────
*Ini EXT_OSCUGALD 20.06.2026 - Bug HASHED TABLE: orden de iteración indefinido
    " HASHED TABLE itera en orden no determinístico → lv_last_soc_key (SOC) puede ser
    " procesado PRIMERO con lv_acum_soc=0, recibiendo lv_total_brl completo en lugar
    " del residuo correcto (-585 BRL). Debug confirmó: SOC recibía 5.85B en vez de -585 BRL.
    " Fix: dos pasadas separadas para garantizar que el residuo se calcula DESPUÉS.
    " Pasada 1: todos los receptores EXCEPTO el último (orden HASHED no importa)
    DATA(lv_acum_soc) = CONV decfloat34( 0 ).
    LOOP AT lt_brl_by_soc ASSIGNING FIELD-SYMBOL(<fs_brl_soc_init>).
      IF <fs_brl_soc_init>-recipientcompanycode = lv_last_soc_key.
        CONTINUE.
      ENDIF.
      READ TABLE lt_metric_items_calc INTO DATA(ls_mic_init)
        WITH KEY product              = is_proposal->product
                 providercompanycode  = is_proposal->providercompanycode
                 recipientcompanycode = <fs_brl_soc_init>-recipientcompanycode
                 to_header_version    = lv_param_version.
      IF sy-subrc = 0.
        <fs_brl_soc_init>-brl_total = lv_total_brl
                                     * ( CONV decfloat34( ls_mic_init-sharerate ) / 100 ).
        lv_acum_soc += <fs_brl_soc_init>-brl_total.
      ENDIF.
    ENDLOOP.
    " Pasada 2: asignar residuo al último receptor DESPUÉS de acumular los demás
    ASSIGN lt_brl_by_soc[ recipientcompanycode = lv_last_soc_key ]
           TO FIELD-SYMBOL(<fs_last_soc>).
    IF sy-subrc = 0.
      <fs_last_soc>-brl_total = lv_total_brl - lv_acum_soc.
    ENDIF.
*Fin EXT_OSCUGALD 20.06.2026 - Bug HASHED TABLE

    " ── 4. Cálculo de importes por ítem (sharerate × base IC05) ──────────────
    IF it_proposal_item IS NOT INITIAL.

      SORT lt_metric_items_calc BY to_header_version ASCENDING recipientcompanycode ASCENDING.

*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
*Ini EXT_OSCUGALD 19.06.2026 - Cost Sharing: pre-cargar TC BRL/USD para exchangerate
      " apply_local_metric no llama applyexchangerate → exchangerate queda 0 en basis e item
      " Se lee TC BRL/USD explícitamente SIN alterar amountincompanycodecurrency (ya en BRL directo)
      DATA(ld_lastday_er) = zcl_interco_utils=>rp_last_day_of_months(
        day_in = |{ is_proposal->fiscalyear }{ is_proposal->fiscalperiod+1 }01| ).
      DATA lv_cs_exchangerate TYPE zint_dte_ukurs.
      SELECT SINGLE exchangerate FROM zi_exchangerate
        WHERE exchangeratetype          = 'B'
          AND sourcecurrency            = @is_proposal->companycodecurrency
          AND targetcurrency            = @is_proposal->globalcurrency
          AND exchangerateeffectivedate = @ld_lastday_er
        INTO @lv_cs_exchangerate.
      IF sy-subrc = 0.
        lv_cs_exchangerate = lv_cs_exchangerate * -1.
      ENDIF.
*Fin EXT_OSCUGALD 19.06.2026 - Cost Sharing
*<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

      LOOP AT it_proposal_item ASSIGNING FIELD-SYMBOL(<fs_proposal_item>).
        lv_item_index += 1.
        CLEAR ls_metric_item_calc.

        READ TABLE lt_metric_items_calc INTO ls_metric_item_calc
          WITH KEY product              = is_proposal->product
                   providercompanycode  = is_proposal->providercompanycode
                   recipientcompanycode = <fs_proposal_item>-recipientcompanycode
                   to_header_version    = lv_param_version.

        IF ls_metric_item_calc IS INITIAL.
          DATA(lv_severity) = if_abap_behv_message=>severity-warning.
          APPEND VALUE #( %tky = is_proposal->%tky
            %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                number   = '017'
                                severity = lv_severity
                                v1       = iv_product_metric
                                v2       = |{ is_proposal->fiscalperiod+1(2) }/{ is_proposal->fiscalyear }|
                                v3       = <fs_proposal_item>-recipientcompanycode
                                v4       = '' ) ) TO cs_reported-zi_intercoproposal.
        ELSE.
          DATA: lv_global_amount    TYPE decfloat34,
                lv_global_amount_h  TYPE decfloat34,
                lv_global_amount_l  TYPE decfloat34,
                lv_company_currency TYPE waers.

          READ TABLE lt_cpig_by_item INTO DATA(ls_cpig)
            WITH KEY item_id = <fs_proposal_item>-item_id.

          lv_global_amount   = 0.
          lv_global_amount_h = 0.
          lv_global_amount_l = COND decfloat34(
            WHEN sy-subrc EQ 0
            THEN CONV decfloat34( ls_cpig-baseamount )
                 * ( CONV decfloat34( ls_metric_item_calc-sharerate ) / 100 )
            ELSE 0 ).

          READ TABLE lt_brl_by_soc
            WITH TABLE KEY recipientcompanycode = <fs_proposal_item>-recipientcompanycode
            ASSIGNING FIELD-SYMBOL(<fs_brl_soc>).
          IF sy-subrc = 0.
            <fs_brl_soc>-item_index += 1.
            DATA(lv_brl_item) = COND decfloat34(
              WHEN <fs_brl_soc>-item_index < <fs_brl_soc>-item_count
              THEN <fs_brl_soc>-brl_total * <fs_brl_soc>-item_index
                   / <fs_brl_soc>-item_count
                   - <fs_brl_soc>-brl_acum
              ELSE <fs_brl_soc>-brl_total - <fs_brl_soc>-brl_acum ).
            <fs_brl_soc>-brl_acum += lv_brl_item.
          ELSE.
            lv_brl_item = 0.
          ENDIF.
          lv_acum_brl += lv_brl_item.

          READ TABLE lt_companies INTO DATA(lv_company)
            WITH KEY companycode = <fs_proposal_item>-recipientcompanycode.
          lv_company_currency = COND #( WHEN lv_company IS NOT INITIAL
                                        THEN lv_company-currency
                                        ELSE <fs_proposal_item>-basecurrencyprofitcenter ).

          GET TIME STAMP FIELD DATA(lv_tsmt).

          APPEND VALUE #(
            id                           = is_proposal->id
            item_id                      = <fs_proposal_item>-item_id
            itembasis_id                 = <fs_proposal_item>-itembasis_id + 1
            sharedrate                   = ls_metric_item_calc-sharerate
            sharedrate_h                 = '0'
            sharedrate_l                 = '0'
            globalcurrency               = is_proposal->globalcurrency
            amountinglobalcurrency_c     = 0
            amountinglobalcurrency_h     = 0
            amountinglobalcurrency_l     = lv_global_amount_l
            amountinglobalcurrency       = lv_global_amount_l
            amountincompanycodecurrency  = lv_brl_item
            companycodecurrency          = lv_company_currency_ic05
            createdat                    = lv_tsmt
            createdby                    = cl_abap_context_info=>get_user_technical_name( )
          ) TO ct_proposal_items_basis.

          CLEAR: lv_global_amount, lv_global_amount_h, lv_global_amount_l.
        ENDIF.
      ENDLOOP.
*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
*Ini EXT_OSCUGALD 19.06.2026 - Cost Sharing: setear exchangerate en basis
      " amountincompanycodecurrency ya es correcto (lv_brl_item directo)
      " Solo se asigna exchangerate sin tocarlo
      LOOP AT ct_proposal_items_basis ASSIGNING FIELD-SYMBOL(<fs_cs_basis_er>).
        <fs_cs_basis_er>-exchangerate = lv_cs_exchangerate.
      ENDLOOP.
*Fin EXT_OSCUGALD 19.06.2026 - Cost Sharing
*<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

      " ── 5. Validaciones ───────────────────────────────────────────────────────
      IF cs_failed-zi_intercoproposal IS NOT INITIAL.
        RETURN.
      ENDIF.

      IF ct_proposal_items_basis IS INITIAL.
        APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
        APPEND VALUE #( %key = is_proposal->%key
          %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                              number   = '015'
                              severity = if_abap_behv_message=>severity-error ) ) TO cs_reported-zi_intercoproposal.
        RETURN.
      ENDIF.

      " ── 6. Limpiar basis anterior ──────────────────────────────────────────
      DATA lt_upd_clean TYPE gtty_proposal_items_upd.
      lt_upd_clean = CORRESPONDING #( it_proposal_item[] ).
      me->cleanproposalitembasis(
        EXPORTING iv_proposalid     = is_proposal->id
                  it_proposal_items = lt_upd_clean ).

      " ── 7. Preparar ítems para actualizar ─────────────────────────────────
      ct_proposal_items_upd = CORRESPONDING #( it_proposal_item[] ).
      LOOP AT ct_proposal_items_upd ASSIGNING FIELD-SYMBOL(<fs_upd>).
        <fs_upd>-%control-interdivisional              = '01'.
        <fs_upd>-%control-baseamountprofitcenter       = '01'.
        <fs_upd>-%control-baseamountprofitcenterc      = '01'.
        <fs_upd>-%control-baseamountprofitcenterh      = '01'.
        <fs_upd>-%control-baseamountprofitcenterl      = '01'.
        <fs_upd>-%control-CpiCompanyCodeCurrency       = '01'.
        <fs_upd>-%control-AmountInCompanyCodeCurrency  = '01'.
        <fs_upd>-%control-AmountInCompanyCodeCurrencyC = '01'.
        <fs_upd>-%control-AmountInCompanyCodeCurrencyH = '01'.
        <fs_upd>-%control-AmountInCompanyCodeCurrencyL = '01'.
*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
*Ini EXT_OSCUGALD 19.06.2026 - Cost Sharing: activar control de exchangerate en el UPDATE
        <fs_upd>-%control-exchangerate                 = '01'.
*Fin EXT_OSCUGALD 19.06.2026 - Cost Sharing
*<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

        READ TABLE ct_proposal_items_basis INTO DATA(ls_basis_upd)
          WITH KEY item_id = <fs_upd>-item_id.
        IF sy-subrc EQ 0.
          <fs_upd>-baseamountprofitcenterc      = 0.
          <fs_upd>-baseamountprofitcenterh      = 0.
          <fs_upd>-BaseAmountProfitCenterL      = ls_basis_upd-amountinglobalcurrency_l.
          <fs_upd>-baseamountprofitcenter       = ls_basis_upd-amountinglobalcurrency_l.
          <fs_upd>-CpiCompanyCodeCurrency       = ls_basis_upd-companycodecurrency.
          <fs_upd>-AmountInCompanyCodeCurrency  = ls_basis_upd-amountincompanycodecurrency.
          <fs_upd>-AmountInCompanyCodeCurrencyC = 0.
          <fs_upd>-AmountInCompanyCodeCurrencyH = 0.
          <fs_upd>-AmountInCompanyCodeCurrencyL = ls_basis_upd-amountincompanycodecurrency.
*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
*Ini EXT_OSCUGALD 19.06.2026 - Cost Sharing: setear exchangerate en ZI_INTERCOPROPOSALITEM
          <fs_upd>-exchangerate                 = lv_cs_exchangerate.
*Fin EXT_OSCUGALD 19.06.2026 - Cost Sharing
*<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        ENDIF.
      ENDLOOP.

      " ── 8. Status de la propuesta ──────────────────────────────────────────
      DATA lt_proposal_aux TYPE gtty_proposal.
      APPEND CORRESPONDING #( is_proposal->* ) TO lt_proposal_aux.

      IF cs_reported-zi_intercoproposal[] IS INITIAL.
        ct_proposal_upd = me->prepareproposaltoupd(
          EXPORTING it_proposal        = lt_proposal_aux
                    iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-verified ).
      ELSE.
        ct_proposal_upd = me->prepareproposaltoupd(
          EXPORTING it_proposal        = lt_proposal_aux
                    iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-pending ).
      ENDIF.

      " ── 9. Armar ct_items_basis_upd con %cid ──────────────────────────────
      DATA lv_basis_idx TYPE i VALUE 0.
      LOOP AT ct_proposal_items_basis INTO DATA(ls_proposal_items_basis).
        lv_basis_idx += 1.
        APPEND VALUE #(
          id      = is_proposal->id
          item_id = ls_proposal_items_basis-item_id
          %target = VALUE #(
            FOR item_basis IN ct_proposal_items_basis
            WHERE ( item_id = ls_proposal_items_basis-item_id )
            ( %cid                        = |B{ lv_basis_idx }|
              id                          = item_basis-id
              item_id                     = item_basis-item_id
              itembasis_id                = item_basis-itembasis_id
              metric_id                   = item_basis-metric_id
              sharedrate                  = item_basis-sharedrate
              sharedrate_h                = item_basis-sharedrate_h
              sharedrate_l                = item_basis-sharedrate_l
              exchangerate                = item_basis-exchangerate
              exchangefactor              = item_basis-exchangefactor
              globalcurrency              = item_basis-globalcurrency
              amountinglobalcurrency_c    = item_basis-amountinglobalcurrency_c
              amountinglobalcurrency_h    = item_basis-amountinglobalcurrency_h
              amountinglobalcurrency_l    = item_basis-amountinglobalcurrency_l
              amountinglobalcurrency      = item_basis-amountinglobalcurrency_c +
                                            item_basis-amountinglobalcurrency_h +
                                            item_basis-amountinglobalcurrency_l
              companycodecurrency         = item_basis-companycodecurrency
              amountincompanycodecurrency = item_basis-amountincompanycodecurrency
              createdat                   = item_basis-createdat
              createdby                   = item_basis-createdby )
          )
        ) TO ct_items_basis_upd.
      ENDLOOP.

*      " ── 10. Poblar cpbg con glaccount_CS correcta por item (Cost Sharing) ──
**Ini EXT_OSCUGALD 22.06.2026 - Cost Sharing: cuenta CS correcta via pandlid (fix SELECT SINGLE)
*      " PROBLEMA: SELECT SINGLE sin pandlid = siempre 690005CS para todos los items.
*      " SOLUCIÓN: resolver glaccount_CS por item via JOIN orglacct+pandlflat+det.
*      " Los montos se copian 1:1 desde cpib — no hay prorrateo.
*      " ATC clean: 1 SELECT DB + 1 SELECT SINGLE fallback + 1 LOOP sin anidado.
*
*      " 10a. Resolver item_id -> glaccount_CS via pandlid dominante
*      TYPES: BEGIN OF ty_item_glacct_cs,
*               item_id    TYPE zde_prop_item_id,
*               glaccount1 TYPE saknr,
*             END OF ty_item_glacct_cs.
*      DATA lt_item_glacct_cs TYPE SORTED TABLE OF ty_item_glacct_cs
*                             WITH NON-UNIQUE KEY item_id.
*
*      SELECT DISTINCT orgl~itemid AS item_id, det~glaccount1
*        FROM zi_intercoproposalitemorglacct AS orgl
*        INNER JOIN zi_intercopandlhierflattened AS pand
*          ON pand~id = orgl~pandll5id
*        INNER JOIN zi_intercoglacctdetermination AS det
*          ON  det~pandlid             = pand~idl2
*          AND det~product             = @is_proposal->product
*          AND det~providercompanycode = @is_proposal->providercompanycode
*          AND det~doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
*          AND det~tarifftype          = '6'
*          AND det~isdeleted           = ''
*        WHERE orgl~id = @is_proposal->id
*        INTO CORRESPONDING FIELDS OF TABLE @lt_item_glacct_cs.
*
*      " 10b. Fallback: primera cuenta CS si el JOIN no resuelve algún item
*      DATA lv_cs_glaccount_fb TYPE saknr.
*      SELECT SINGLE glaccount1 FROM zi_intercoglacctdetermination
*        WHERE product             = @is_proposal->product
*          AND providercompanycode = @is_proposal->providercompanycode
*          AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
*          AND tarifftype          = '6'
*          AND isdeleted           = ''
*        INTO @lv_cs_glaccount_fb.
*
*      " 10c. Construir lt_basis_glacct: montos de cpib 1:1, cuenta CS por pandlid
*      DATA lt_basis_glacct TYPE STANDARD TABLE OF ty_basis_glacct WITH DEFAULT KEY.
*      LOOP AT ct_proposal_items_basis INTO DATA(ls_basis_bg).
*        READ TABLE lt_item_glacct_cs INTO DATA(ls_item_cs)
*          WITH TABLE KEY item_id = ls_basis_bg-item_id.
*        APPEND VALUE #(
*          id                          = ls_basis_bg-id
*          item_id                     = ls_basis_bg-item_id
*          itembasis_id                = ls_basis_bg-itembasis_id
*          globalcurrency              = ls_basis_bg-globalcurrency
*          amountinglobalcurrency      = ls_basis_bg-amountinglobalcurrency
*          amountinglobalcurrency_l    = ls_basis_bg-amountinglobalcurrency_l
*          companycodecurrency         = ls_basis_bg-companycodecurrency
*          amountincompanycodecurrency = ls_basis_bg-amountincompanycodecurrency
*          glaccount1                  = COND #(
*            WHEN sy-subrc = 0 AND ls_item_cs-glaccount1 IS NOT INITIAL
*            THEN ls_item_cs-glaccount1
*            ELSE lv_cs_glaccount_fb )
*        ) TO lt_basis_glacct.
*      ENDLOOP.
**Fin EXT_OSCUGALD 22.06.2026 - Cost Sharing cuenta CS correcta por pandlid
*
*      DATA lt_basis_idx TYPE HASHED TABLE OF ty_basis_idx
*                        WITH UNIQUE KEY item_id itembasis_id.
*      DATA lv_idx_counter TYPE i VALUE 0.
*      DATA lv_bg_idx      TYPE i VALUE 0.
*      DATA lv_cid_bg      TYPE string.
*
*      LOOP AT ct_proposal_items_basis INTO DATA(ls_idx_basis).
*        lv_idx_counter += 1.
*        INSERT VALUE #(
*          item_id      = ls_idx_basis-item_id
*          itembasis_id = ls_idx_basis-itembasis_id
*          cid          = |B{ lv_idx_counter }| ) INTO TABLE lt_basis_idx.
*      ENDLOOP.
*
*      LOOP AT lt_basis_glacct INTO DATA(ls_bg).
*        lv_bg_idx += 1.
*        GET TIME STAMP FIELD lv_tsmt.
*        READ TABLE lt_basis_idx INTO DATA(ls_idx_bg)
*          WITH TABLE KEY item_id      = ls_bg-item_id
*                         itembasis_id = ls_bg-itembasis_id.
*        IF sy-subrc = 0.
*          lv_cid_bg = ls_idx_bg-cid.
*        ELSE.
*          lv_cid_bg = space.
*        ENDIF.
*        APPEND VALUE #(
*          %cid_ref     = lv_cid_bg
*          id           = is_proposal->id
*          item_id      = ls_bg-item_id
*          itembasis_id = ls_bg-itembasis_id
*          %target      = VALUE #(
*            ( %cid                         = |BG{ lv_bg_idx }|
*              id                           = ls_bg-id
*              item_id                      = ls_bg-item_id
*              itembasis_id                 = ls_bg-itembasis_id
*              GlAccount                    = ls_bg-glaccount1
*              costcenter                   = lv_ceco_bg
*              globalcurrency               = ls_bg-globalcurrency
*              amountinglobalcurrency       = ls_bg-amountinglobalcurrency
*              amountinglobalcurrencyc      = 0
*              amountinglobalcurrencyh      = 0
*              amountinglobalcurrencyl      = ls_bg-amountinglobalcurrency_l
*              companycodecurrency          = ls_bg-companycodecurrency
*              amountincompanycodecurrency  = ls_bg-amountincompanycodecurrency
*              amountincompanycodecurrencyc = 0
*              amountincompanycodecurrencyh = 0
*              amountincompanycodecurrencyl = ls_bg-amountincompanycodecurrency
*              createdat                    = lv_tsmt
*              createdby                    = cl_abap_context_info=>get_user_technical_name( ) )
*          )
*        ) TO ct_items_bg_upd.
*      ENDLOOP.

      " ── 10. Poblar cpbg con 1 GL account real por basis (Cost Sharing) ────
*Ini EXT_OSCUGALD 28.05.2026 - Cost Sharing: 1 fila cpbg por basis via SELECT SINGLE doctype=AR
      " cpbg: 1 fila por item, 1 GL account. Produccion confirma 1 linea AR por item.
      " SELECT SINGLE doctype=AR + tarifftype=6 evita CROSS JOIN (16 filas => error 4x).

      DATA lt_basis_glacct TYPE STANDARD TABLE OF ty_basis_glacct WITH DEFAULT KEY.
      DATA lv_cs_glaccount TYPE saknr.

      SELECT SINGLE glaccount1 FROM zi_intercoglacctdetermination
        WHERE product             = @is_proposal->product
          AND providercompanycode = @is_proposal->providercompanycode
          AND doctype             = @zcl_interco_doc_glaccount=>co_doc_type-ar
          AND tarifftype          = '6'
          AND isdeleted           = ''
        INTO @lv_cs_glaccount.

      IF sy-subrc = 0.
        LOOP AT ct_proposal_items_basis INTO DATA(ls_basis_bg).
          APPEND VALUE #(
            id                          = ls_basis_bg-id
            item_id                     = ls_basis_bg-item_id
            itembasis_id                = ls_basis_bg-itembasis_id
            globalcurrency              = ls_basis_bg-globalcurrency
            amountinglobalcurrency      = ls_basis_bg-amountinglobalcurrency
            amountinglobalcurrency_l    = ls_basis_bg-amountinglobalcurrency_l
            companycodecurrency         = ls_basis_bg-companycodecurrency
            amountincompanycodecurrency = ls_basis_bg-amountincompanycodecurrency
            glaccount1                  = lv_cs_glaccount
          ) TO lt_basis_glacct.
        ENDLOOP.
      ENDIF.

      DATA lt_basis_idx TYPE HASHED TABLE OF ty_basis_idx
                        WITH UNIQUE KEY item_id itembasis_id.
      DATA lv_idx_counter TYPE i VALUE 0.
      DATA lv_bg_idx      TYPE i VALUE 0.
      DATA lv_cid_bg      TYPE string.

      LOOP AT ct_proposal_items_basis INTO DATA(ls_idx_basis).
        lv_idx_counter += 1.
        INSERT VALUE #(
          item_id      = ls_idx_basis-item_id
          itembasis_id = ls_idx_basis-itembasis_id
          cid          = |B{ lv_idx_counter }| ) INTO TABLE lt_basis_idx.
      ENDLOOP.

      LOOP AT lt_basis_glacct INTO DATA(ls_bg).
        lv_bg_idx += 1.
        GET TIME STAMP FIELD lv_tsmt.
        READ TABLE lt_basis_idx INTO DATA(ls_idx_bg)
          WITH TABLE KEY item_id      = ls_bg-item_id
                         itembasis_id = ls_bg-itembasis_id.
        IF sy-subrc = 0.
          lv_cid_bg = ls_idx_bg-cid.
        ELSE.
          lv_cid_bg = space.
        ENDIF.
        APPEND VALUE #(
          %cid_ref     = lv_cid_bg
          id           = is_proposal->id
          item_id      = ls_bg-item_id
          itembasis_id = ls_bg-itembasis_id
          %target      = VALUE #(
            ( %cid                         = |BG{ lv_bg_idx }|
              id                           = ls_bg-id
              item_id                      = ls_bg-item_id
              itembasis_id                 = ls_bg-itembasis_id
              GlAccount                    = ls_bg-glaccount1
              costcenter                   = lv_ceco_bg
              globalcurrency               = ls_bg-globalcurrency
              amountinglobalcurrency       = ls_bg-amountinglobalcurrency
              amountinglobalcurrencyc      = 0
              amountinglobalcurrencyh      = 0
              amountinglobalcurrencyl      = ls_bg-amountinglobalcurrency_l
              companycodecurrency          = ls_bg-companycodecurrency
              amountincompanycodecurrency  = ls_bg-amountincompanycodecurrency
              amountincompanycodecurrencyc = 0
              amountincompanycodecurrencyh = 0
              amountincompanycodecurrencyl = ls_bg-amountincompanycodecurrency
              createdat                    = lv_tsmt
              createdby                    = cl_abap_context_info=>get_user_technical_name( ) )
          )
        ) TO ct_items_bg_upd.
      ENDLOOP.
*Fin EXT_OSCUGALD 28.05.2026 - Cost Sharing

      " ── 11. MODIFY ENTITIES ────────────────────────────────────────────────
      MODIFY ENTITIES OF zi_intercoproposal IN LOCAL MODE
        ENTITY zi_intercoproposal
          UPDATE FROM ct_proposal_upd
        ENTITY zi_intercoproposalitem
          UPDATE FROM ct_proposal_items_upd
          CREATE BY \_proposalitemsbasis AUTO FILL CID
            FIELDS ( id item_id itembasis_id metric_id sharedrate sharedrate_h sharedrate_l
                     exchangerate globalcurrency amountinglobalcurrency amountinglobalcurrency_c
                     amountinglobalcurrency_h amountinglobalcurrency_l companycodecurrency
                     amountincompanycodecurrency createdat createdby )
            WITH ct_items_basis_upd
        ENTITY zi_intercoproposalitembasis
          CREATE BY \_proposalitemsbaoglac AUTO FILL CID
            FIELDS ( id item_id itembasis_id GlAccount costcenter sharedrateh sharedratel
                     amountinglobalcurrencyc amountinglobalcurrencyh amountinglobalcurrencyl
                     amountinglobalcurrency globalcurrency amountincompanycodecurrencyc
                     amountincompanycodecurrency amountincompanycodecurrencyh amountincompanycodecurrencyl
                     companycodecurrency createdby createdat )
            WITH ct_items_bg_upd
        MAPPED DATA(lt_mapped)
        REPORTED DATA(lt_reported)
        FAILED DATA(lt_failed).

    ENDIF.

  ENDMETHOD.

  METHOD apply_mic_metric.
*── 1. P&L L0 desde la CDS (única fuente con la categoría) ─────────────────
    SELECT pandl~idl0 AS idl0,
           SUM( orgl~amountinglobalcurrency ) AS amount
      FROM zi_intercoproposalitemorglacct AS orgl
      INNER JOIN zi_intercopandlhierflattened AS pandl
        ON pandl~id = orgl~pandll5id
      WHERE orgl~id = @is_proposal->id
      GROUP BY pandl~idl0
      INTO TABLE @DATA(lt_pandl).

    IF lt_pandl IS INITIAL.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      APPEND VALUE #( %key = is_proposal->%key
        %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '015'
                            severity = if_abap_behv_message=>severity-error ) )
        TO cs_reported-zi_intercoproposal.
      RETURN.
    ENDIF.

*── 2. Clasificar por categoría L0 ─────────────────────────────────────────
    DATA: lv_net_revenue TYPE decfloat34,
          lv_expenses    TYPE decfloat34,
          lv_cogs        TYPE decfloat34,
          lv_tax         TYPE decfloat34.

    LOOP AT lt_pandl INTO DATA(ls_pandl).
      CASE ls_pandl-idl0.
*Ini EXT_OSCUGALD 2026-09-03 - Bermudas MIC (SDFPSINIC-23362)
*   Net Revenue debe tratarse como magnitud positiva antes de restar Expenses
*   en el Operating Income (definicion de negocio confirmada 03.09.2026).
*   El valor crudo de ACDOCA trae credito natural (negativo); sin abs(), el
*   OI resultaba mas negativo de lo real, invirtiendo el umbral que cruza
*   el ISAC NCP (Lower en vez de Upper) y por lo tanto la direccion completa
*   de facturacion y el monto de la regalia. Ver hallazgo DF-532 e informe
*   tecnico "Analisis_Signo_NetRevenue_ISAC_NCP_Bermudas.md".
        WHEN '0PL_L0_01'. lv_net_revenue = abs( ls_pandl-amount ).
*Fin EXT_OSCUGALD 2026-09-03 - Bermudas MIC (SDFPSINIC-23362)
        WHEN '0PL_L0_02'. lv_cogs        = ls_pandl-amount.
        WHEN '0PL_L0_03'. lv_expenses    = ls_pandl-amount.
        WHEN '0PL_L0_11'. lv_tax         = ls_pandl-amount.
      ENDCASE.
    ENDLOOP.

*── 3. Operating Income + guarda división por cero (CP-06) ─────────────────
    DATA(lv_operating_income) = lv_net_revenue - lv_expenses.

    IF lv_expenses = 0.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      APPEND VALUE #( %key = is_proposal->%key
        %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '015'
                            severity = if_abap_behv_message=>severity-error ) )
        TO cs_reported-zi_intercoproposal.
      RETURN.
    ENDIF.

    DATA(lv_isac_ncp) = lv_operating_income / lv_expenses.

*── 4. Upper / Lower Target desde TVARVC (nunca hardcode) ──────────────────
*  Los valores en TVARVC están en formato porcentaje (10.80 / 2.10).
*  El ISAC NCP es un cociente (0.108), por eso se divide por 100 al leer.
    DATA lv_upper TYPE decfloat34.
    DATA lv_lower TYPE decfloat34.
    DATA lv_tvar  TYPE c LENGTH 20.

    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_UPPER_TARGET' AND type = 'P' INTO @lv_tvar.
    IF sy-subrc = 0. lv_upper = CONV decfloat34( lv_tvar ) / 100. ELSE. lv_upper = '10.80' / 100. ENDIF.

    CLEAR lv_tvar.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_LOWER_TARGET' AND type = 'P' INTO @lv_tvar.
    IF sy-subrc = 0. lv_lower = CONV decfloat34( lv_tvar ) / 100. ELSE. lv_lower = '2.10' / 100. ENDIF.

*── 5. Dirección / Concluido ───────────────────────────────────────────────
*  Confirmado funcional (Agustín 28.07.2026): límites > / < ESTRICTOS;
*  borde exacto → Concluido. Upper aplica a MIC→USA, Lower a USA→MIC.
*  La regalía negativa en USA→MIC es correcta (el signo define quién paga).
    DATA lv_param_tvarvc TYPE decfloat34.
    DATA(lv_concluded)   = abap_false.

    IF lv_isac_ncp > lv_upper.
      lv_param_tvarvc = lv_upper.       " MIC→USA (AR en MIC, AP en USA)
    ELSEIF lv_isac_ncp < lv_lower.
      lv_param_tvarvc = lv_lower.       " USA→MIC (AR en USA, AP en MIC)
    ELSE.
      lv_concluded = abap_true.
    ENDIF.

*Ini EXT_OSCUGALD 2026-08-14 - Bermudas MIC (SDFPSINIC-23362)
*   Mensaje informativo con el ISAC NCP calculado. severity-information evita
*   duplicar el mensaje "Correcto" que genera Fiori Elements automáticamente.
    DATA(lv_ncp_pct)    = lv_isac_ncp * 100.
    DATA(lv_ncp_string) = |{ lv_ncp_pct DECIMALS = 2 }|.
    APPEND VALUE #( %key = is_proposal->%key
          %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                              number   = '032'
                              severity = if_abap_behv_message=>severity-success
                              v1       = lv_ncp_string ) )
          TO cs_reported-zi_intercoproposal.
*Fin EXT_OSCUGALD 2026-08-14 - Bermudas MIC (SDFPSINIC-23362)

    DATA lt_proposal_aux TYPE gtty_proposal.
    APPEND CORRESPONDING #( is_proposal->* ) TO lt_proposal_aux.

*── 6. Concluido: status G, sin basis ──────────────────────────────────────
    IF lv_concluded = abap_true.
      ct_proposal_upd = me->prepareproposaltoupd(
        EXPORTING it_proposal        = lt_proposal_aux
                  iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-concluded ).
      RETURN.
    ENDIF.

*── 7. Regalía = OI − (Expenses × parámetro TVARVC) ────────────────────────
    DATA(lv_regalia) = lv_operating_income - ( lv_expenses * lv_param_tvarvc ).

*── 8. Basis: regalía en el item del CeBe destino; los demás en cero ───────
*  Confirmado funcional (Agustín 30.07): la regalía (importe único) se graba
*  en el item cuyo CeBe = destino (271, via TVARVC ZINTERCO_MIC_CEBE). Los
*  otros items quedan en cero. La suma NO coincide con el header (esperado).
    GET TIME STAMP FIELD DATA(lv_tsmt).

    " CeBe destino desde TVARVC (no hardcode)
    DATA lv_cebe_mic TYPE c LENGTH 3.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_MIC_CEBE' AND type = 'P'
      INTO @lv_cebe_mic.
    IF sy-subrc <> 0 OR lv_cebe_mic IS INITIAL.
      APPEND VALUE #( %key = is_proposal->%key ) TO cs_failed-zi_intercoproposal.
      APPEND VALUE #( %key = is_proposal->%key
        %msg = new_message( id = 'ZINT_MSG_INTERCO_CP' number = '015'
                            severity = if_abap_behv_message=>severity-error ) )
        TO cs_reported-zi_intercoproposal.
      RETURN.
    ENDIF.

    " profitcenter viene con ceros a la izquierda (0000000271); comparar por los ult. 3
    DATA(lv_found_dest) = abap_false.
    LOOP AT it_proposal_item INTO DATA(ls_item_mic).
      DATA(lv_cebe_item) = ls_item_mic-profitcenter+7(3).
      DATA(lv_amount_dest) = COND #( WHEN lv_cebe_item = lv_cebe_mic
                                     THEN lv_regalia ELSE 0 ).
      IF lv_cebe_item = lv_cebe_mic.
        lv_found_dest = abap_true.
      ENDIF.

      APPEND VALUE #(
        id                          = is_proposal->id
        item_id                     = ls_item_mic-item_id
        itembasis_id                = ls_item_mic-itembasis_id + 1
        sharedrate                  = 100
        globalcurrency              = is_proposal->globalcurrency
        amountinglobalcurrency_c    = lv_amount_dest
        amountinglobalcurrency      = lv_amount_dest
        companycodecurrency         = is_proposal->companycodecurrency
        amountincompanycodecurrency = lv_amount_dest
        exchangerate                = -1
        createdat                   = lv_tsmt
        createdby                   = cl_abap_context_info=>get_user_technical_name( )
      ) TO ct_proposal_items_basis.
    ENDLOOP.

*Ini EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)
*   Si ningún ítem tiene CeBe destino, grabar la regalía en el
*   primer ítem disponible. El posteo FI (BO_AR/BO_AP) siempre usa TVARVC
*   para el CeCo → CeBe 271 independientemente del contenido del basis.
*   Riesgo residual: doc_map usa fallback al primer ítem (solo trazabilidad).
    IF lv_found_dest = abap_false.
      ASSIGN ct_proposal_items_basis[ 1 ] TO FIELD-SYMBOL(<fs_first_basis>).
      IF sy-subrc = 0.
        <fs_first_basis>-amountinglobalcurrency_c    = lv_regalia.
        <fs_first_basis>-amountinglobalcurrency      = lv_regalia.
        <fs_first_basis>-amountincompanycodecurrency = lv_regalia.
      ENDIF.
    ENDIF.
*Fin EXT_OSCUGALD 2026-08-11 - Bermudas MIC (SDFPSINIC-23362)

*── 9. Limpiar basis anterior + preparar items upd ─────────────────────────
    DATA lt_upd_clean TYPE gtty_proposal_items_upd.
    lt_upd_clean = CORRESPONDING #( it_proposal_item[] ).
    me->cleanproposalitembasis(
      EXPORTING iv_proposalid = is_proposal->id it_proposal_items = lt_upd_clean ).

    ct_proposal_items_upd = CORRESPONDING #( it_proposal_item[] ).
    LOOP AT ct_proposal_items_upd ASSIGNING FIELD-SYMBOL(<fs_upd>).
      <fs_upd>-%control-baseamountprofitcenter  = '01'.
      <fs_upd>-%control-baseamountprofitcenterc = '01'.
      READ TABLE ct_proposal_items_basis INTO DATA(ls_basis_upd)
        WITH KEY item_id = <fs_upd>-item_id.
      IF sy-subrc = 0.
        <fs_upd>-baseamountprofitcenter  = ls_basis_upd-amountinglobalcurrency.
        <fs_upd>-baseamountprofitcenterc = ls_basis_upd-amountinglobalcurrency.
      ENDIF.
    ENDLOOP.

*── 10. Status → Verificado ────────────────────────────────────────────────
    ct_proposal_upd = me->prepareproposaltoupd(
      EXPORTING it_proposal        = lt_proposal_aux
                iv_proposal_status = zcl_proposal_bo_abs=>c_proposal_status-verified ).

*── 11. ct_items_basis_upd con %cid ────────────────────────────────────────
    DATA lv_basis_idx TYPE i VALUE 0.
    LOOP AT ct_proposal_items_basis INTO DATA(ls_basis).
      lv_basis_idx += 1.
      APPEND VALUE #(
        id      = is_proposal->id
        item_id = ls_basis-item_id
        %target = VALUE #(
          ( %cid                        = |BMIC{ lv_basis_idx }|
            id                          = ls_basis-id
            item_id                     = ls_basis-item_id
            itembasis_id                = ls_basis-itembasis_id
            sharedrate                  = ls_basis-sharedrate
            globalcurrency              = ls_basis-globalcurrency
            amountinglobalcurrency_c    = ls_basis-amountinglobalcurrency_c
            amountinglobalcurrency      = ls_basis-amountinglobalcurrency
            companycodecurrency         = ls_basis-companycodecurrency
            amountincompanycodecurrency = ls_basis-amountincompanycodecurrency
            exchangerate                = ls_basis-exchangerate
            createdat                   = ls_basis-createdat
            createdby                   = ls_basis-createdby ) )
      ) TO ct_items_basis_upd.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
