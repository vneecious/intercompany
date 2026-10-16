*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)     *
* Requirement N° : SDFPSINIC-23362                                    *
* Change ID      : V001                                               *
* Date           : 18.06.2026                                         *
* Description    : Reintegros ME — Fixes V001 (FX-XLS Plantilla Excel)*
* Transport      : DS4K9B5VNA                                         *
* Reference      : 5000047741                                         *
*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)     *
* Requirement N° : SDFPSINIC-23362                                    *
* Change ID      : V001                                               *
* Date           : 12.06.2026                                         *
* Description    : Fix editability for LIBD/ENVI and GRAV->RASO       *
* Transport      : DS4K9B5O8U                                         *
* Reference      : SDFPSINIC-23362                                    *
*----------------------------------------------------------------------*
* NOTE: This file contains the CCIMP section (local class implementations)
*       of class ZBP_REINGMEHEADER — include CCIMPZZBP_REINGMEHEADER=========CP.
*----------------------------------------------------------------------*
*CLASS ltc_reingme_item_validation DEFINITION DEFERRED FOR TESTING.

* Begin Insert V002 (10.09.2026 | EXT_GONZALCA)
* Carrier for the headers released by the Liberar action (interaction phase)
* over to lsc_zi_reingmeheader (save phase). A static attribute is the only
* way across: in a behavior pool FRIENDS is accepted against test classes
* only, so handler and saver cannot reach each other's private state.
CLASS lcl_reing_me_refresh_buffer DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES ty_mehid_tab TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    CLASS-DATA gt_released TYPE ty_mehid_tab.
    CLASS-METHODS reset.
ENDCLASS.

CLASS lcl_reing_me_refresh_buffer IMPLEMENTATION.
  METHOD reset.
    CLEAR gt_released.
  ENDMETHOD.
ENDCLASS.
* End Insert V002 (10.09.2026 | EXT_GONZALCA)

CLASS lhc_zi_reingmeheader DEFINITION INHERITING FROM cl_abap_behavior_handler.
*  FRIENDS ltc_reingme_item_validation.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_reingmeheader RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_reingmeheader RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingmeheader RESULT result.

    METHODS validateheader FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmeheader~validateheader.

    METHODS setloadversion FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmeheader~setloadversion.

    METHODS derivemetfromctmatnr FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmeheader~derivemetfromctmatnr.

    METHODS derivectextnum FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmeheader~derivectextnum.

    METHODS setreleasemetadata FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmeheader~setreleasemetadata.

    METHODS calcularshare FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~calcularshare RESULT result.

    METHODS enviar FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~enviar RESULT result.

    METHODS devolver FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~devolver RESULT result.

    METHODS liberar FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~liberar RESULT result.

    METHODS reabrir FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~reabrir RESULT result.

    METHODS novaversaocarga FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~novaversaocarga RESULT result.

    "Begin Insert V001 (CC) - FX-XLS - static export action handler (Plantilla Excel backend)
    METHODS exporttemplate FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmeheader~exporttemplate RESULT result.

    " Begin Insert V001 (CC) — ME-17 (Delta v2)
    METHODS upload FOR MODIFY
  IMPORTING keys FOR ACTION zi_reingmeheader~upload RESULT result.
    " End Insert V001 (CC) — ME-17 (Delta v2)
    "End Insert V001 (CC) - FX-XLS

    "Begin Insert V001 (CC) — AJ-01 — constant for active prev status (T-1/T-2 source)
    CONSTANTS c_status_prev_active TYPE zreing_me_h_a-me_status VALUE 'LIBD'.
    "End Insert V001 (CC) — AJ-01
    "Begin Insert V001 (CC) — V005 — re-check ValidateHeader/ValidateItem rules before Enviar
    TYPES ty_mehid_tab TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    TYPES: BEGIN OF ty_v5_error,
             mehid TYPE sysuuid_x16,
             msg   TYPE string,
           END OF ty_v5_error.
    TYPES ty_v5_error_tab TYPE STANDARD TABLE OF ty_v5_error WITH EMPTY KEY.

    METHODS check_business_rules
      IMPORTING it_mehids        TYPE ty_mehid_tab
      RETURNING VALUE(rt_errors) TYPE ty_v5_error_tab.
    "End Insert V001 (CC) — V005

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    " refresh_next_periods now lives in lsc_zi_reingmeheader (save phase). RAP
    " rejects a MODIFY on instances outside the action scope, so the refresh can
    " only run where direct DB writes are legal.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)

ENDCLASS.

CLASS lhc_zi_reingmeitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
*  FRIENDS ltc_reingme_item_validation.
  PRIVATE SECTION.

    METHODS validateitem FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmeitem~validateitem.

    METHODS setstatusonvaluechange FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmeitem~setstatusonvaluechange.

    METHODS setprevvalues FOR DETERMINE ON SAVE
      IMPORTING keys FOR zi_reingmeitem~setprevvalues.

    "Begin Insert V001 (CC) — FX14 — item inherits read-only state from header status
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingmeitem RESULT result.
    "End Insert V001 (CC) — FX14

    "Begin Mod V001 (CC) — FX15 removed: method no longer needed
    "METHODS SetStatusOnValueChangeOnSave FOR DETERMINE ON SAVE
    "  IMPORTING keys FOR zi_reingmeitem~SetStatusOnValueChangeOnSave.
    "End Mod V001 (CC)

ENDCLASS.

CLASS lhc_zi_reingmeheader IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
    result = VALUE #(
      FOR key IN keys
      ( %tky                    = key-%tky
        %update                 = if_abap_behv=>auth-allowed
        %delete                 = if_abap_behv=>auth-allowed
        %action-calcularshare   = if_abap_behv=>auth-allowed
        %action-enviar          = if_abap_behv=>auth-allowed
        %action-devolver        = if_abap_behv=>auth-allowed
        %action-liberar         = if_abap_behv=>auth-allowed
        %action-reabrir         = if_abap_behv=>auth-allowed
        %action-novaversaocarga = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    " Draft status: drives action availability (reflects CalcularShare->GRAV without requiring activation)
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me_draft).

    "Begin Mod V001 (CC) — FX14/FX12 fix: read ACTIVE entity status for edit/field-level control.
    " MeStatus is field(readonly); when draft action Edit creates the draft it may not copy this
    " field to the draft table, causing features to always return enabled for LIBD/ENVI records.
    " Active status is the authoritative source for edit-blocking (update/field features).
    " Draft status remains the source for action features (enables Enviar immediately after CalcularShare).

    " Deduplicar MeHId antes del READ activo — evita CX_CSP_ACT_RESPONSE
    " cuando keys contiene múltiples drafts del mismo header (ej. varios ítems).
    DATA lt_unique_hdr_keys TYPE SORTED TABLE OF sysuuid_x16
                             WITH UNIQUE KEY table_line.
    LOOP AT keys INTO DATA(ls_dedup).
      INSERT ls_dedup-mehid INTO TABLE lt_unique_hdr_keys.
    ENDLOOP.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH VALUE #( FOR lv_id IN lt_unique_hdr_keys
                      ( %is_draft = if_abap_behv=>mk-off
                        mehid     = lv_id ) )
      RESULT DATA(lt_me_act).

    TYPES: BEGIN OF ty_act_st,
             me_h_id   TYPE zreing_me_h_a-me_h_id,
             me_status TYPE zreing_me_h_a-me_status,
           END OF ty_act_st.
    DATA lt_act_idx TYPE SORTED TABLE OF ty_act_st WITH UNIQUE KEY me_h_id.
    LOOP AT lt_me_act INTO DATA(ls_act_raw).
      INSERT VALUE #( me_h_id   = ls_act_raw-mehid
                      me_status = ls_act_raw-mestatus )
        INTO TABLE lt_act_idx.
    ENDLOOP.
    "End Mod V001 (CC)

    LOOP AT lt_me_draft INTO DATA(ls).
      DATA(lv_st_draft) = ls-%data-mestatus.
      "Begin Mod V001 (CC) — use active status for edit-blocking and field-freeze
      READ TABLE lt_act_idx INTO DATA(ls_act_row) WITH KEY me_h_id = ls-mehid.
      DATA(lv_act_st) = COND zreing_me_h_a-me_status(
        WHEN sy-subrc = 0 THEN ls_act_row-me_status
        ELSE space ).
      "Begin Mod V001 (CC) — FX18 — key fields always read-only (cannot be changed after creation)
      " Begin Mod 02.09.2026 EXT_AGFAGINA — el bloqueo se aplica DESPUES del alta, no durante.
      " FX18 dejaba lv_key_ro fijo en read_only, sin distinguir creacion de modificacion, asi
      " que al usar "Crear Cabecera" los campos Contrato / Material / Periodo salian grisados
      " y no se podia dar de alta nada a mano.
      " lv_act_st viene vacio cuando la cabecera todavia no existe como instancia activa, que
      " es exactamente el caso de un registro nuevo: ahi los campos deben poder cargarse.
      " Una vez persistida, se mantiene el comportamiento que buscaba FX18.
      DATA(lv_key_ro) = COND #( WHEN lv_act_st IS INITIAL
                                THEN if_abap_behv=>fc-f-unrestricted
                                ELSE if_abap_behv=>fc-f-read_only ).
      " End Mod 02.09.2026 EXT_AGFAGINA
      "End Mod V001 (CC) — FX18
      "End Mod V001 (CC)
      APPEND VALUE #(
        %tky                    = ls-%tky
        "Begin Mod V001 (CC) — FX14 fix: use ACTIVE status for %features-%update
        %features-%update       = COND #( WHEN lv_act_st = 'ENVI' OR lv_act_st = 'LIBD' OR lv_act_st = 'LIBR'
                                            THEN if_abap_behv=>fc-o-disabled
                                            ELSE if_abap_behv=>fc-o-enabled )
        "End Mod V001 (CC)
        "Begin Insert V001 (CC) — FX19 — disable Delete in ENVI/LIBD/LIBR (record no longer alterable)
        %features-%delete       = COND #( WHEN lv_act_st = 'ENVI' OR lv_act_st = 'LIBD' OR lv_act_st = 'LIBR'
                                            THEN if_abap_behv=>fc-o-disabled
                                            ELSE if_abap_behv=>fc-o-enabled )
        "End Insert V001 (CC) — FX19
        "Begin Insert V001 (CC) — FX20 — disable Edit button (draft action) in ENVI/LIBD/LIBR
        %action-Edit            = COND #( WHEN lv_act_st = 'ENVI' OR lv_act_st = 'LIBD' OR lv_act_st = 'LIBR'
                                            THEN if_abap_behv=>fc-o-disabled
                                            ELSE if_abap_behv=>fc-o-enabled )
        "End Insert V001 (CC) — FX20
        "Begin Insert V001 (CC) — FX12 — apply dynamic read-only to the business key fields
        %field-ctid             = lv_key_ro
        %field-matnr            = lv_key_ro
        %field-periodyear       = lv_key_ro
        %field-periodmonth      = lv_key_ro
        "End Insert V001 (CC) — FX12
        %action-calcularshare   = COND #( WHEN lv_st_draft = 'RASO' OR lv_st_draft = 'GRAV'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-enviar          = COND #( WHEN lv_st_draft = 'GRAV'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-devolver        = COND #( WHEN lv_st_draft = 'ENVI'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-liberar         = COND #( WHEN lv_st_draft = 'ENVI'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-reabrir         = COND #( WHEN lv_st_draft = 'LIBD' OR lv_st_draft = 'LIBR'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-novaversaocarga = COND #( WHEN lv_st_draft = 'LIBR'
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
      ) TO result.
      CLEAR: lv_st_draft, lv_act_st, lv_key_ro.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateheader.
    "Begin Mod V001 (CC) — FX02/FX09 — widen initial read to bring MeHid + LoadVersion (R6)
    " FX02 needs MeHId (to exclude self) and LoadVersion (duplicate key part).
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mehid ctid matnr periodyear periodmonth loadversion )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).
    "End Mod V001 (CC) — FX02/FX09

    "Begin Insert V001 (CC) — FX09 — OPTION A: bulk-read CT V2 master data via SELECT (no cross-BO EML)
    " Resolve CtId -> CtUuid + CtStatus, and CtUuid+Matnr -> MatStatus, to validate the
    " contract and material are active. Bulk reads run BEFORE the loop; READ TABLE inside.
    TYPES: BEGIN OF ty_ct_id,
             ct_id TYPE zreing_ct2_a-ct_id,
           END OF ty_ct_id.
    TYPES: BEGIN OF ty_contract,
             ct_id     TYPE zreing_ct2_a-ct_id,
             ct_uuid   TYPE zreing_ct2_a-ct_uuid,
             ct_status TYPE zreing_ct2_a-ct_status,
           END OF ty_contract.
    TYPES: BEGIN OF ty_ct_mat_key,
             ct_uuid TYPE zreing_ct2_mat_a-ct_uuid,
             matnr   TYPE zreing_ct2_mat_a-matnr,
           END OF ty_ct_mat_key.
    TYPES: BEGIN OF ty_material,
             ct_uuid    TYPE zreing_ct2_mat_a-ct_uuid,
             matnr      TYPE zreing_ct2_mat_a-matnr,
             mat_status TYPE zreing_ct2_mat_a-mat_status,
           END OF ty_material.

    " Distinct CtIds present in the changed set
    DATA lt_ct_ids TYPE SORTED TABLE OF ty_ct_id WITH UNIQUE KEY ct_id.
    LOOP AT lt_me INTO DATA(ls_ctid).
      CHECK ls_ctid-%data-ctid IS NOT INITIAL.
      INSERT VALUE ty_ct_id( ct_id = ls_ctid-%data-ctid ) INTO TABLE lt_ct_ids.
    ENDLOOP.

    DATA lt_contracts TYPE SORTED TABLE OF ty_contract WITH UNIQUE KEY ct_id.
    IF lt_ct_ids IS NOT INITIAL.
      SELECT ct_id, ct_uuid, ct_status
        FROM zreing_ct2_a
        FOR ALL ENTRIES IN @lt_ct_ids
        WHERE ct_id = @lt_ct_ids-ct_id
        INTO TABLE @lt_contracts.
    ENDIF.

    " Distinct CtUuid+Matnr keys derived from the resolved contracts
    DATA lt_ct_mat_keys TYPE SORTED TABLE OF ty_ct_mat_key WITH UNIQUE KEY ct_uuid matnr.
    LOOP AT lt_me INTO DATA(ls_mk).
      CHECK ls_mk-%data-ctid IS NOT INITIAL AND ls_mk-%data-matnr IS NOT INITIAL.
      READ TABLE lt_contracts INTO DATA(ls_ctk)
        WITH KEY ct_id = ls_mk-%data-ctid BINARY SEARCH.
      CHECK sy-subrc = 0.
      INSERT VALUE ty_ct_mat_key( ct_uuid = ls_ctk-ct_uuid
                                  matnr   = ls_mk-%data-matnr ) INTO TABLE lt_ct_mat_keys.
    ENDLOOP.

    DATA lt_materials TYPE SORTED TABLE OF ty_material WITH UNIQUE KEY ct_uuid matnr.
    IF lt_ct_mat_keys IS NOT INITIAL.
      SELECT ct_uuid, matnr, mat_status
        FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @lt_ct_mat_keys
        WHERE ct_uuid = @lt_ct_mat_keys-ct_uuid
          AND matnr   = @lt_ct_mat_keys-matnr
        INTO TABLE @lt_materials.
    ENDIF.
    "End Insert V001 (CC) — FX09

    "Begin Mod V001 (CC) — AJ-02 — add me_status to ty_dup for RASO tolerance in FX02
    " A duplicate is another active header with the same business key (CtId+Matnr+
    " PeriodYear+PeriodMonth+LoadVersion) but a different MeHId.
    TYPES: BEGIN OF ty_dup,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             load_version TYPE zreing_me_h_a-load_version,
             me_status    TYPE zreing_me_h_a-me_status,
           END OF ty_dup.
    DATA lt_dup TYPE SORTED TABLE OF ty_dup
                 WITH NON-UNIQUE KEY ct_id matnr period_year period_month load_version me_h_id.
    IF lt_me IS NOT INITIAL.
      SELECT me_h_id, ct_id, matnr, period_year, period_month, load_version, me_status
        FROM zreing_me_h_a
        FOR ALL ENTRIES IN @lt_me
        WHERE ct_id        = @lt_me-%data-ctid
          AND matnr        = @lt_me-%data-matnr
          AND period_year  = @lt_me-%data-periodyear
          AND period_month = @lt_me-%data-periodmonth
          AND load_version = @lt_me-%data-loadversion
        INTO TABLE @lt_dup.
    ENDIF.
    "End Mod V001 (CC) — AJ-02

    LOOP AT lt_me INTO DATA(ls_me).
      IF ls_me-%data-ctid IS INITIAL.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El contrato es obligatorio (BR-ME-01)' ) )
          TO reported-zi_reingmeheader.
      ENDIF.
      IF ls_me-%data-matnr IS INITIAL.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El material es obligatorio (BR-ME-01)' ) )
          TO reported-zi_reingmeheader.
      ENDIF.
      IF ls_me-%data-periodyear IS INITIAL.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El año del período es obligatorio' ) )
          TO reported-zi_reingmeheader.
      ENDIF.
      IF ls_me-%data-periodmonth IS INITIAL.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El mes del período es obligatorio' ) )
          TO reported-zi_reingmeheader.
      ENDIF.

      " Skip business-data checks when mandatory fields are missing (already reported above)
      CHECK ls_me-%data-ctid IS NOT INITIAL
        AND ls_me-%data-matnr IS NOT INITIAL.

      "Begin Insert V001 (CC) — FX09 — validate contract active (BR-ME-01a) and material active (BR-ME-01b)
      READ TABLE lt_contracts INTO DATA(ls_contract)
        WITH KEY ct_id = ls_me-%data-ctid BINARY SEARCH.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El contrato no existe (BR-ME-01a)' ) )
          TO reported-zi_reingmeheader.
      ELSEIF ls_contract-ct_status <> 'AC'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El contrato no está activo (BR-ME-01a)' ) )
          TO reported-zi_reingmeheader.
      ELSE.
        READ TABLE lt_materials INTO DATA(ls_material)
          WITH KEY ct_uuid = ls_contract-ct_uuid
                   matnr   = ls_me-%data-matnr BINARY SEARCH.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
          APPEND VALUE #( %tky = ls_me-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = 'El material no pertenece al contrato (BR-ME-01b)' ) )
            TO reported-zi_reingmeheader.
*        ELSEIF ls_material-mat_status <> 'AC'.
*          APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
*          APPEND VALUE #( %tky = ls_me-%tky
*                          %msg = new_message_with_text(
*                            severity = if_abap_behv_message=>severity-error
*                            text     = 'El material no está activo en el contrato (BR-ME-01b)' ) )
*            TO reported-zi_reingmeheader.
        ENDIF.
      ENDIF.
      "End Insert V001 (CC) — FX09

      "Begin Insert V001 (CC) — FX02 — duplicate load detection (BR-ME-02)
      READ TABLE lt_dup INTO DATA(ls_dup)
        WITH KEY ct_id        = ls_me-%data-ctid
                 matnr        = ls_me-%data-matnr
                 period_year  = ls_me-%data-periodyear
                 period_month = ls_me-%data-periodmonth
                 load_version = ls_me-%data-loadversion
        BINARY SEARCH.
      IF sy-subrc = 0.
        DATA(lv_dup_idx) = sy-tabix.
        DATA(lv_dup_other) = xsdbool( ls_dup-me_h_id <> ls_me-%data-mehid ).
        "Begin Mod V001 (CC) — AJ-02 — track which row is the actual duplicate for RASO status check
        DATA(lv_dup_via_nxt) = abap_false.
        "End Mod V001 (CC) — AJ-02
        IF lv_dup_other = abap_false AND lv_dup_idx < lines( lt_dup ).
          READ TABLE lt_dup INTO DATA(ls_dup_nxt) INDEX lv_dup_idx + 1.
          lv_dup_other = xsdbool(
            ls_dup_nxt-ct_id        = ls_me-%data-ctid
            AND ls_dup_nxt-matnr        = ls_me-%data-matnr
            AND ls_dup_nxt-period_year  = ls_me-%data-periodyear
            AND ls_dup_nxt-period_month = ls_me-%data-periodmonth
            AND ls_dup_nxt-load_version = ls_me-%data-loadversion ).
          "Begin Mod V001 (CC) — AJ-02 — flag that the duplicate was found in ls_dup_nxt
          IF lv_dup_other = abap_true. lv_dup_via_nxt = abap_true. ENDIF.
          "End Mod V001 (CC) — AJ-02
        ENDIF.
        "Begin Mod V001 (CC) — AJ-02 — skip FX02 error when the actual duplicate is in RASO status
        " (AJ-02 in SetLoadVersion will delete it; physical DB still has the record at this point).
        " When lv_dup_via_nxt=true the duplicate is ls_dup_nxt; otherwise it is ls_dup.
        IF lv_dup_other = abap_true.
          DATA(lv_dup_status) = COND zreing_me_h_a-me_status(
            WHEN lv_dup_via_nxt = abap_true THEN ls_dup_nxt-me_status
            ELSE ls_dup-me_status ).
          IF lv_dup_status <> 'RASO'.
            APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
            APPEND VALUE #( %tky = ls_me-%tky
                            %msg = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Ya existe una carga con el mismo contrato, material, período y versión (BR-ME-02)' ) )
              TO reported-zi_reingmeheader.
          ENDIF.
        ENDIF.
        "End Mod V001 (CC) — AJ-02
      ENDIF.
      "End Insert V001 (CC) — FX02
    ENDLOOP.
  ENDMETHOD.

  METHOD setloadversion.
    "Begin Mod V001 (CC) — AJ-02 — add me_h_id + me_status to version type for RASO overwrite detection
    TYPES: BEGIN OF ty_ver_slv,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             load_version TYPE zreing_me_h_a-load_version,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             me_status    TYPE zreing_me_h_a-me_status,
           END OF ty_ver_slv.
    TYPES: BEGIN OF ty_max_slv,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             max_version  TYPE zreing_me_h_a-load_version,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             me_status    TYPE zreing_me_h_a-me_status,
           END OF ty_max_slv.
    "End Mod V001 (CC) — AJ-02

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( ctid matnr periodyear periodmonth loadversion mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    " Setear RASO en cualquier registro nuevo (MeStatus vacío)
    LOOP AT lt_me INTO DATA(ls_init).
      CHECK ls_init-%data-mestatus IS INITIAL.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %tky     = ls_init-%tky
                          mestatus = 'RASO' ) )
        REPORTED DATA(lt_rep_init).
    ENDLOOP.

    " Patrón reconocido por FAllUnsafe: IF <tabla_FAE> IS NOT INITIAL
    IF lt_me IS NOT INITIAL.
      DATA lt_ver_slv TYPE TABLE OF ty_ver_slv WITH EMPTY KEY.
      "Begin Mod V001 (CC) — AJ-02 — also fetch me_h_id + me_status for RASO overwrite
      SELECT ct_id, matnr, period_year, period_month, load_version, me_h_id, me_status
        FROM zreing_me_h_a
        FOR ALL ENTRIES IN @lt_me
        WHERE ct_id        = @lt_me-%data-ctid
          AND matnr        = @lt_me-%data-matnr
          AND period_year  = @lt_me-%data-periodyear
          AND period_month = @lt_me-%data-periodmonth
        INTO TABLE @lt_ver_slv.
      "End Mod V001 (CC) — AJ-02

      SORT lt_ver_slv BY ct_id matnr period_year period_month load_version DESCENDING.

      DATA lt_max_slv TYPE SORTED TABLE OF ty_max_slv
                      WITH UNIQUE KEY ct_id matnr period_year period_month.
      LOOP AT lt_ver_slv INTO DATA(ls_ver).
        TRY.
            "Begin Mod V001 (CC) — AJ-02 — pass me_h_id + me_status (sorted DESC, first = max)
            INSERT VALUE ty_max_slv(
              ct_id        = ls_ver-ct_id
              matnr        = ls_ver-matnr
              period_year  = ls_ver-period_year
              period_month = ls_ver-period_month
              max_version  = ls_ver-load_version
              me_h_id      = ls_ver-me_h_id
              me_status    = ls_ver-me_status ) INTO TABLE lt_max_slv.
            "End Mod V001 (CC) — AJ-02
          CATCH cx_sy_itab_duplicate_key.                   "#EC NEEDED
        ENDTRY.
      ENDLOOP.

      LOOP AT lt_me INTO DATA(ls_me).
        " Solo procesar registros con datos completos y sin versión asignada
        CHECK ls_me-%data-loadversion IS INITIAL
          AND ls_me-%data-ctid IS NOT INITIAL
          AND ls_me-%data-matnr IS NOT INITIAL
          AND ls_me-%data-periodyear IS NOT INITIAL
          AND ls_me-%data-periodmonth IS NOT INITIAL.

        READ TABLE lt_max_slv INTO DATA(ls_max)
          WITH KEY ct_id        = ls_me-%data-ctid
                   matnr        = ls_me-%data-matnr
                   period_year  = ls_me-%data-periodyear
                   period_month = ls_me-%data-periodmonth
          BINARY SEARCH.

        "Begin Mod V001 (CC) — AJ-02 — overwrite existing RASO: DELETE it and reuse its version
        IF sy-subrc = 0 AND ls_max-me_status = 'RASO'.
          " The existing record has status RASO — delete it (cascade deletes its items)
          " and assign the same LoadVersion to the new record instead of incrementing.
          MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
            ENTITY zi_reingmeheader
              DELETE FROM VALUE #( ( %tky = VALUE #( mehid = ls_max-me_h_id ) ) )
            REPORTED DATA(lt_rep_del).

          MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
            ENTITY zi_reingmeheader
              UPDATE FIELDS ( loadversion mestatus )
              WITH VALUE #( ( %tky        = ls_me-%tky
                              loadversion = ls_max-max_version
                              mestatus    = 'RASO' ) )
            REPORTED DATA(lt_rep_raso).

        ELSE.
          "End Mod V001 (CC) — AJ-02

          DATA(lv_new_ver) = COND zreing_me_h_a-load_version(
            WHEN sy-subrc <> 0 THEN '001'
            ELSE CONV #( CONV i( ls_max-max_version ) + 1 ) ).

          MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
            ENTITY zi_reingmeheader
              UPDATE FIELDS ( loadversion mestatus )
              WITH VALUE #( ( %tky        = ls_me-%tky
                              loadversion = lv_new_ver
                              mestatus    = 'RASO' ) )
            REPORTED DATA(lt_rep).

          "Begin Mod V001 (CC) — AJ-02
        ENDIF.
        "End Mod V001 (CC) — AJ-02

      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD derivemetfromctmatnr.
    " CT V2: zreing_ct2_met_a usa ct_uuid+mat_uuid como clave.
    " Se resuelve: ct2_a (ct_id->ct_uuid) + ct2_mat_a (ct_uuid+matnr->mat_uuid) + ct2_met_a
    TYPES: BEGIN OF ty_fae_ctmat,
             ct_id TYPE zreing_me_h_a-ct_id,
             matnr TYPE zreing_me_h_a-matnr,
           END OF ty_fae_ctmat.
    TYPES: BEGIN OF ty_met,
             ct_id       TYPE zreing_me_h_a-ct_id,
             matnr       TYPE zreing_me_h_a-matnr,
             metric_code TYPE zreing_ct2_met_a-metric_code,
             version_num TYPE zreing_ct2_met_a-version_num,
           END OF ty_met.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( ctid matnr )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    DATA lt_fae TYPE SORTED TABLE OF ty_fae_ctmat
                WITH UNIQUE KEY ct_id matnr.
    LOOP AT lt_me INTO DATA(ls_chk).
      CHECK ls_chk-%data-ctid IS NOT INITIAL
        AND ls_chk-%data-matnr IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_ctmat(
            ct_id = ls_chk-%data-ctid
            matnr = ls_chk-%data-matnr ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    " JOIN: ct2_a -> ct2_mat_a -> ct2_met_a resolviendo ct_id+matnr a metric
    DATA lt_met TYPE SORTED TABLE OF ty_met
                WITH UNIQUE KEY ct_id matnr.
    SELECT ct~ct_id, mat~matnr, met~metric_code, met~version_num
      FROM zreing_ct2_a     AS ct
      JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid  = ct~ct_uuid
      JOIN zreing_ct2_met_a AS met ON  met~ct_uuid  = ct~ct_uuid
                                   AND met~mat_uuid  = mat~mat_uuid
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct~ct_id       = @lt_fae-ct_id
        AND mat~matnr      = @lt_fae-matnr
        AND met~met_status = 'AC'
      INTO TABLE @lt_met.

    LOOP AT lt_me INTO DATA(ls_me).
      CHECK ls_me-%data-ctid IS NOT INITIAL
        AND ls_me-%data-matnr IS NOT INITIAL.

      READ TABLE lt_met INTO DATA(ls_met)
        WITH KEY ct_id = ls_me-%data-ctid
                 matnr = ls_me-%data-matnr
        BINARY SEARCH.
      CHECK sy-subrc = 0.

      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( metriccode metversion )
          WITH VALUE #( ( %tky       = ls_me-%tky
                          metriccode = ls_met-metric_code
                          metversion = ls_met-version_num ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

  METHOD derivectextnum.
    TYPES: BEGIN OF ty_fae_ct,
             ct_id TYPE zreing_ct2_a-ct_id,
           END OF ty_fae_ct.
    TYPES: BEGIN OF ty_ct,
             ct_id        TYPE zreing_ct2_a-ct_id,
             ext_contract TYPE zreing_ct2_a-ext_contract,
           END OF ty_ct.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( ctid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    DATA lt_fae TYPE SORTED TABLE OF ty_fae_ct
                WITH NON-UNIQUE KEY ct_id.
    LOOP AT lt_me INTO DATA(ls_chk).
      CHECK ls_chk-%data-ctid IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_ct( ct_id = ls_chk-%data-ctid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    DATA lt_ct TYPE SORTED TABLE OF ty_ct
               WITH UNIQUE KEY ct_id.
    SELECT ct_id, ext_contract
      FROM zreing_ct2_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_id = @lt_fae-ct_id
      INTO TABLE @lt_ct.

    LOOP AT lt_me INTO DATA(ls_me).
      CHECK ls_me-%data-ctid IS NOT INITIAL.

      READ TABLE lt_ct INTO DATA(ls_ct)
        WITH KEY ct_id = ls_me-%data-ctid
        BINARY SEARCH.
      CHECK sy-subrc = 0.

      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( ctextnum )
          WITH VALUE #( ( %tky     = ls_me-%tky
                          ctextnum = ls_ct-ext_contract ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

  METHOD setreleasemetadata.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus releasedby )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    DATA lv_now TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.

    LOOP AT lt_me INTO DATA(ls_me).
      "Begin Mod V001 (CC) — FX08 — set/clear release metadata depending on the new status
      " Restructured the former single CHECK into IF/ELSEIF so the GRAV transition
      " (Devolver / Reabrir) clears the release stamp instead of leaving stale data.
      IF ls_me-%data-mestatus = 'LIBD'
        AND ls_me-%data-releasedby IS INITIAL.
        MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
          ENTITY zi_reingmeheader
            UPDATE FIELDS ( releasedby releasedat )
            WITH VALUE #( ( %tky       = ls_me-%tky
                            releasedby = sy-uname
                            releasedat = lv_now ) )
          REPORTED DATA(lt_rep).
      ELSEIF ls_me-%data-mestatus = 'GRAV'.
        MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
          ENTITY zi_reingmeheader
            UPDATE FIELDS ( releasedby releasedat )
            WITH VALUE #( ( %tky       = ls_me-%tky
                            releasedby = space
                            releasedat = 0 ) )
          REPORTED DATA(lt_rep_clr).
      ENDIF.
      "End Mod V001 (CC) — FX08
    ENDLOOP.
  ENDMETHOD.

  METHOD calcularshare.
    " Tipos auxiliares
    TYPES: BEGIN OF ty_total,
             me_h_id   TYPE zreing_me_h_a-me_h_id,
             "total_val TYPE zreing_me_i_a-me_value,
             total_val TYPE p LENGTH 16 DECIMALS 6,
           END OF ty_total.
    "Begin Mod V001 (CC) — FX21 — widen header accumulator so intermediate COLLECT steps
    " don't round to total_share_pct's DEC(7,2) on every item (was causing 99.94% instead
    " of 100.00% when summing many DEC(9,6) SharePct values into a 2-decimal field).
    TYPES: BEGIN OF ty_share_hdr,
             me_h_id  TYPE zreing_me_h_a-me_h_id,
             "total_sh TYPE zreing_me_h_a-total_share_pct,
             total_sh TYPE p LENGTH 16 DECIMALS 6,
           END OF ty_share_hdr.
    "End Mod V001 (CC) — FX21
    "Begin Insert V001 (CC) — FX22 — remembers, per header, which item row absorbs the
    " rounding difference: the one with the highest SharePct. upd_index points into
    " lt_item_upd_all so the adjustment needs no second key lookup.
    TYPES: BEGIN OF ty_share_max,
             me_h_id   TYPE zreing_me_h_a-me_h_id,
             upd_index TYPE i,
             max_share TYPE p LENGTH 16 DECIMALS 6,
           END OF ty_share_max.
    "End Insert V001 (CC) — FX22
    "Begin Insert V001 (CC) — FX11 — type for metric-version variation limit lookup
    TYPES: BEGIN OF ty_mcv_key,
             metric_code TYPE zreing_mcv_a-metric_code,
             version_num TYPE zreing_mcv_a-version_num,
           END OF ty_mcv_key.
    TYPES: BEGIN OF ty_mcv,
             metric_code   TYPE zreing_mcv_a-metric_code,
             version_num   TYPE zreing_mcv_a-version_num,
             var_pct_limit TYPE zreing_mcv_a-var_pct_limit,
           END OF ty_mcv.
    "End Insert V001 (CC) — FX11

    "Begin Mod V001 (CC) — FX11 — widen initial read to bring MetricCode + MetVersion (R6)
    " Needed to look up the metric version variation limit (VarPctLimit) per header.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mehid mestatus metriccode metversion )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).
    "End Mod V001 (CC) — FX11

    " Separar válidos e inválidos — sin LOOP anidado posterior
    DATA lt_valid_keys LIKE lt_me.
    LOOP AT lt_me INTO DATA(ls_chk).
      IF ls_chk-%data-mestatus = 'RASO' OR ls_chk-%data-mestatus = 'GRAV'.
        APPEND ls_chk TO lt_valid_keys.
      ELSE.
        APPEND VALUE #( %tky = ls_chk-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_chk-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede calcular en estado RASO o GRAV' ) )
          TO reported-zi_reingmeheader.
      ENDIF.
    ENDLOOP.
    CHECK lt_valid_keys IS NOT INITIAL.

    "Begin Insert V001 (CC) — FX11 — bulk-read variation limits per (MetricCode, MetVersion)
    " Replaces the hard-coded 15% threshold. Fallback to 15 when no MCV row is found.
    DATA lt_mcv_keys TYPE SORTED TABLE OF ty_mcv_key WITH UNIQUE KEY metric_code version_num.
    LOOP AT lt_valid_keys INTO DATA(ls_mcvk).
      CHECK ls_mcvk-%data-metriccode IS NOT INITIAL.
      INSERT VALUE ty_mcv_key( metric_code = ls_mcvk-%data-metriccode
                               version_num = ls_mcvk-%data-metversion ) INTO TABLE lt_mcv_keys.
    ENDLOOP.

    DATA lt_mcv TYPE SORTED TABLE OF ty_mcv WITH UNIQUE KEY metric_code version_num.
    IF lt_mcv_keys IS NOT INITIAL.
      SELECT metric_code, version_num, var_pct_limit
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_mcv_keys
        WHERE metric_code = @lt_mcv_keys-metric_code
          AND version_num = @lt_mcv_keys-version_num
        INTO TABLE @lt_mcv.
    ENDIF.

    " Map each valid header to its variation limit (fallback 15) for use in the item loop
    TYPES: BEGIN OF ty_hdr_limit,
             me_h_id   TYPE zreing_me_h_a-me_h_id,
             var_limit TYPE zreing_mcv_a-var_pct_limit,
           END OF ty_hdr_limit.
    DATA lt_hdr_limit TYPE SORTED TABLE OF ty_hdr_limit WITH UNIQUE KEY me_h_id.
    LOOP AT lt_valid_keys INTO DATA(ls_lim).
      READ TABLE lt_mcv INTO DATA(ls_mcv)
        WITH KEY metric_code = ls_lim-%data-metriccode
                 version_num = ls_lim-%data-metversion BINARY SEARCH.
      INSERT VALUE ty_hdr_limit(
        me_h_id   = ls_lim-%data-mehid
        var_limit = COND #( WHEN sy-subrc = 0 AND ls_mcv-var_pct_limit > 0
                            THEN ls_mcv-var_pct_limit
                            ELSE 15 ) ) INTO TABLE lt_hdr_limit.
    ENDLOOP.
    "End Insert V001 (CC) — FX11

    "Begin Insert V001 (CC) — AJ-01 — Recalculate T-1/T-2 PrevValue/Prev2Value for RASO and GRAV headers
    " before computing share.
    " Uses the same bulk algorithm as SetPrevValues (SetPrevValues is on save / item context;
    " here we run it inside the action using the header context from lt_valid_keys).

    " ── AJ-01.1. Subconjunto RASO de los headers válidos ─────────────────────
    DATA lt_calc_keys LIKE lt_valid_keys.
    LOOP AT lt_valid_keys INTO DATA(ls_raso_chk).
      CHECK ls_raso_chk-%data-mestatus = 'RASO' OR ls_raso_chk-%data-mestatus = 'GRAV'.
      APPEND ls_raso_chk TO lt_calc_keys.
    ENDLOOP.

    IF lt_calc_keys IS NOT INITIAL.

      " ── AJ-01.2. Construir índice de headers RASO y GRAV con período + T-1/T-2 ────
      TYPES: BEGIN OF ty_raso_hdr_info,
               me_h_id      TYPE zreing_me_h_a-me_h_id,
               ct_id        TYPE zreing_me_h_a-ct_id,
               matnr        TYPE zreing_me_h_a-matnr,
               period_year  TYPE zreing_me_h_a-period_year,
               period_month TYPE zreing_me_h_a-period_month,
               year_t1      TYPE zreing_me_h_a-period_year,
               month_t1     TYPE zreing_me_h_a-period_month,
               year_t2      TYPE zreing_me_h_a-period_year,
               month_t2     TYPE zreing_me_h_a-period_month,
             END OF ty_raso_hdr_info.

      " Lee headers de lt_calc_keys para obtener CtId/Matnr/Período
      DATA lt_raso_hdr_keys TYPE TABLE FOR READ IMPORT zi_reingmeheader.
      LOOP AT lt_calc_keys INTO DATA(ls_rk).
        INSERT VALUE #( mehid = ls_rk-%data-mehid ) INTO TABLE lt_raso_hdr_keys.
      ENDLOOP.
      SORT lt_raso_hdr_keys BY mehid.
      DELETE ADJACENT DUPLICATES FROM lt_raso_hdr_keys COMPARING mehid.

      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          FIELDS ( mehid ctid matnr periodyear periodmonth )
          WITH CORRESPONDING #( lt_raso_hdr_keys )
        RESULT DATA(lt_raso_hdrs_full).

      DATA lt_raso_hdr_idx TYPE SORTED TABLE OF ty_raso_hdr_info WITH UNIQUE KEY me_h_id.
      DATA lv_tot1_aj TYPE i.
      DATA lv_tot2_aj TYPE i.
      LOOP AT lt_raso_hdrs_full INTO DATA(ls_rh).
        lv_tot1_aj = ( CONV i( ls_rh-%data-periodyear ) * 12 )
                         + ( CONV i( ls_rh-%data-periodmonth ) - 1 ) - 1.
        lv_tot2_aj = ( CONV i( ls_rh-%data-periodyear ) * 12 )
                         + ( CONV i( ls_rh-%data-periodmonth ) - 1 ) - 2.
        INSERT VALUE ty_raso_hdr_info(
          me_h_id      = ls_rh-%data-mehid
          ct_id        = ls_rh-%data-ctid
          matnr        = ls_rh-%data-matnr
          period_year  = ls_rh-%data-periodyear
          period_month = ls_rh-%data-periodmonth
          year_t1      = lv_tot1_aj DIV 12
          month_t1     = ( lv_tot1_aj MOD 12 ) + 1
          year_t2      = lv_tot2_aj DIV 12
          month_t2     = ( lv_tot2_aj MOD 12 ) + 1 )
        INTO TABLE lt_raso_hdr_idx.
      ENDLOOP.

      " ── AJ-01.3. Construir FAE con períodos T-1 y T-2 ────────────────────────
      TYPES: BEGIN OF ty_fae_aj01,
               ct_id        TYPE zreing_me_h_a-ct_id,
               matnr        TYPE zreing_me_h_a-matnr,
               period_year  TYPE zreing_me_h_a-period_year,
               period_month TYPE zreing_me_h_a-period_month,
             END OF ty_fae_aj01.
      DATA lt_fae_aj01 TYPE STANDARD TABLE OF ty_fae_aj01 WITH EMPTY KEY.

      LOOP AT lt_raso_hdr_idx INTO DATA(ls_rhi).
        APPEND VALUE ty_fae_aj01(
          ct_id = ls_rhi-ct_id  matnr = ls_rhi-matnr
          period_year = ls_rhi-year_t1  period_month = ls_rhi-month_t1 ) TO lt_fae_aj01.
        APPEND VALUE ty_fae_aj01(
          ct_id = ls_rhi-ct_id  matnr = ls_rhi-matnr
          period_year = ls_rhi-year_t2  period_month = ls_rhi-month_t2 ) TO lt_fae_aj01.
      ENDLOOP.

      " ── AJ-01.4. SELECT JOIN: headers LIBD + ítems (patrón idéntico a SetPrevValues) ─
      "Begin Mod V001 (CC) — AJ-01-FIX — add load_version to select max LIBD version per period
      TYPES: BEGIN OF ty_libd_hdr_aj01,
               me_h_id      TYPE zreing_me_h_a-me_h_id,
               ct_id        TYPE zreing_me_h_a-ct_id,
               matnr        TYPE zreing_me_h_a-matnr,
               period_year  TYPE zreing_me_h_a-period_year,
               period_month TYPE zreing_me_h_a-period_month,
               load_version TYPE zreing_me_h_a-load_version,
             END OF ty_libd_hdr_aj01.
      DATA lt_libd_hdrs_aj01 TYPE SORTED TABLE OF ty_libd_hdr_aj01
                             WITH UNIQUE KEY ct_id matnr period_year period_month.

      "Begin Mod V001 (CC) — ME-06 (Delta v2) — versioning key role_id -> role_category + allocation
      TYPES: BEGIN OF ty_libd_item_aj01,
               me_h_id       TYPE zreing_me_i_a-me_h_id,
               bukrs         TYPE zreing_me_i_a-bukrs,
               prctr         TYPE zreing_me_i_a-prctr,
               campana       TYPE zreing_me_i_a-campana,
               role_category TYPE zreing_me_i_a-role_category,
               allocation    TYPE zreing_me_i_a-allocation,
               " Mod 08.09.2026 EXT_AGFAGINA: se guarda el SHARE del periodo
               " anterior, no su valor. La variacion es share(T) - share(T-1),
               " no valor(T) - valor(T-1). Ver comentario en el calculo.
               me_value      TYPE zreing_me_i_a-share_pct,
             END OF ty_libd_item_aj01.
      DATA lt_libd_items_aj01 TYPE SORTED TABLE OF ty_libd_item_aj01
                              WITH NON-UNIQUE KEY me_h_id bukrs prctr campana role_category allocation.
      "End Mod V001 (CC) — ME-06 (Delta v2)

      IF lt_fae_aj01 IS NOT INITIAL.
        "Begin Mod V001 (CC) — ME-06 (Delta v2) — select role_category + allocation instead of role_id
        SELECT hdrs~me_h_id, hdrs~ct_id, hdrs~matnr,
               hdrs~period_year, hdrs~period_month, hdrs~load_version,
               itms~bukrs, itms~prctr, itms~campana,
               itms~role_category, itms~allocation, itms~share_pct AS me_value
          FROM zreing_me_h_a AS hdrs
          INNER JOIN zreing_me_i_a AS itms
            ON itms~me_h_id = hdrs~me_h_id
          FOR ALL ENTRIES IN @lt_fae_aj01
          WHERE hdrs~ct_id        = @lt_fae_aj01-ct_id
            AND hdrs~matnr        = @lt_fae_aj01-matnr
            AND hdrs~period_year  = @lt_fae_aj01-period_year
            AND hdrs~period_month = @lt_fae_aj01-period_month
            AND hdrs~me_status    = @c_status_prev_active
          INTO TABLE @DATA(lt_join_aj01).
        "End Mod V001 (CC) — ME-06 (Delta v2)

        SORT lt_join_aj01 BY ct_id matnr period_year period_month load_version DESCENDING.
        "End Mod V001 (CC) — AJ-01-FIX

        LOOP AT lt_join_aj01 ASSIGNING FIELD-SYMBOL(<ls_ja>).
          TRY.
              INSERT VALUE ty_libd_hdr_aj01(
                me_h_id      = <ls_ja>-me_h_id
                ct_id        = <ls_ja>-ct_id
                matnr        = <ls_ja>-matnr
                period_year  = <ls_ja>-period_year
                period_month = <ls_ja>-period_month
                load_version = <ls_ja>-load_version )
              INTO TABLE lt_libd_hdrs_aj01.
            CATCH cx_sy_itab_duplicate_key.                 "#EC NEEDED
          ENDTRY.
          "Begin Mod V001 (CC) — ME-06 (Delta v2) — build key with role_category + allocation
          INSERT VALUE ty_libd_item_aj01(
            me_h_id       = <ls_ja>-me_h_id
            bukrs         = <ls_ja>-bukrs
            prctr         = <ls_ja>-prctr
            campana       = <ls_ja>-campana
            role_category = <ls_ja>-role_category
            allocation    = <ls_ja>-allocation
            me_value      = <ls_ja>-me_value )
          INTO TABLE lt_libd_items_aj01.
          "End Mod V001 (CC) — ME-06 (Delta v2)
        ENDLOOP.
      ENDIF.

      " ── AJ-01.5. Leer ítems de las cabeceras a calcular desde el buffer ─────────────
      "Begin Mod V001 (CC) — ME-06 (Delta v2) — read role_category + allocation instead of roleid
      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader BY \_item
          FIELDS ( meiid mehid bukrs prctr campana rolecategory allocation )
          WITH CORRESPONDING #( lt_calc_keys )
        RESULT DATA(lt_raso_items).
      "End Mod V001 (CC) — ME-06 (Delta v2)

      " ── AJ-01.6. Construir tabla de updates prevvalue/prev2value ──────────────
      DATA lt_prev_updates TYPE TABLE FOR UPDATE zi_reingmeitem.

      LOOP AT lt_raso_items INTO DATA(ls_ri).
        READ TABLE lt_raso_hdr_idx INTO DATA(ls_rhi2)
          WITH KEY me_h_id = ls_ri-%data-mehid.
        CHECK sy-subrc = 0.

        DATA lv_prev1_aj TYPE zreing_me_i_a-me_value VALUE 0.
        DATA lv_prev2_aj TYPE zreing_me_i_a-me_value VALUE 0.

        " T-1
        READ TABLE lt_libd_hdrs_aj01 INTO DATA(ls_lh1_aj)
          WITH KEY ct_id        = ls_rhi2-ct_id
                   matnr        = ls_rhi2-matnr
                   period_year  = ls_rhi2-year_t1
                   period_month = ls_rhi2-month_t1.
        IF sy-subrc = 0.
          "Begin Mod V001 (CC) — ME-06 (Delta v2) — match T-1 item by role_category + allocation
          READ TABLE lt_libd_items_aj01 INTO DATA(ls_li1_aj)
            WITH KEY me_h_id       = ls_lh1_aj-me_h_id
                     bukrs         = ls_ri-%data-bukrs
                     prctr         = ls_ri-%data-prctr
                     campana       = ls_ri-%data-campana
                     role_category = ls_ri-%data-rolecategory
                     allocation    = ls_ri-%data-allocation.
          "End Mod V001 (CC) — ME-06 (Delta v2)
          IF sy-subrc = 0. lv_prev1_aj = ls_li1_aj-me_value. ENDIF.
        ENDIF.

        " T-2
        READ TABLE lt_libd_hdrs_aj01 INTO DATA(ls_lh2_aj)
          WITH KEY ct_id        = ls_rhi2-ct_id
                   matnr        = ls_rhi2-matnr
                   period_year  = ls_rhi2-year_t2
                   period_month = ls_rhi2-month_t2.
        IF sy-subrc = 0.
          "Begin Mod V001 (CC) — ME-06 (Delta v2) — match T-2 item by role_category + allocation
          READ TABLE lt_libd_items_aj01 INTO DATA(ls_li2_aj)
            WITH KEY me_h_id       = ls_lh2_aj-me_h_id
                     bukrs         = ls_ri-%data-bukrs
                     prctr         = ls_ri-%data-prctr
                     campana       = ls_ri-%data-campana
                     role_category = ls_ri-%data-rolecategory
                     allocation    = ls_ri-%data-allocation.
          "End Mod V001 (CC) — ME-06 (Delta v2)
          IF sy-subrc = 0. lv_prev2_aj = ls_li2_aj-me_value. ENDIF.
        ENDIF.

        APPEND VALUE #(
          %tky       = ls_ri-%tky
          prevvalue  = lv_prev1_aj
          prev2value = lv_prev2_aj ) TO lt_prev_updates.
      ENDLOOP.

      " ── AJ-01.7. Persistir al buffer transaccional ────────────────────────────
      IF lt_prev_updates IS NOT INITIAL.
        MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
          ENTITY zi_reingmeitem
            UPDATE FIELDS ( prevvalue prev2value )
            WITH lt_prev_updates
          REPORTED DATA(lt_rep_prev).
      ENDIF.

    ENDIF.
    "End Insert V001 (CC) — AJ-01

    "Begin Insert V001 (CC) — ME-06 (Delta v2) — contract receiver set for share matching (ET §11.3 / BR-CT-SOC-05)
    " El denominador del share cuenta SOLO los ítems cuya tupla
    " (bukrs, prctr, campana, role_category, allocation) pertenece al conjunto de
    " receptoras activas de CT2_REC_A del contrato. Matching sobre rec_bukrs (1:1 con rec_uuid).
    TYPES: BEGIN OF ty_set_contrato,
             ct_id         TYPE zreing_me_h_a-ct_id,
             matnr         TYPE zreing_me_h_a-matnr,
             rec_bukrs     TYPE zreing_ct2_rec_a-rec_bukrs,
             prctr         TYPE zreing_ct2_rec_a-prctr,
             campana       TYPE zreing_ct2_rec_a-campana,
             role_category TYPE zreing_ct2_rec_a-role_category,
             allocation    TYPE zreing_ct2_rec_a-allocation,
           END OF ty_set_contrato.
    DATA lt_set_contrato TYPE SORTED TABLE OF ty_set_contrato
         WITH NON-UNIQUE KEY ct_id matnr rec_bukrs prctr campana role_category allocation.

    TYPES: BEGIN OF ty_ctmat_me,
             ct_id TYPE zreing_me_h_a-ct_id,
             matnr TYPE zreing_me_h_a-matnr,
           END OF ty_ctmat_me.
    DATA lt_ctmat_me TYPE SORTED TABLE OF ty_ctmat_me WITH UNIQUE KEY ct_id matnr.
    LOOP AT lt_raso_hdr_idx INTO DATA(ls_cm_me).
      TRY.
          INSERT VALUE ty_ctmat_me( ct_id = ls_cm_me-ct_id
                                    matnr = ls_cm_me-matnr ) INTO TABLE lt_ctmat_me.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    IF lt_ctmat_me IS NOT INITIAL.
      SELECT ct~ct_id, mat~matnr,
             rec~rec_bukrs, rec~prctr, rec~campana,
             rec~role_category, rec~allocation
        FROM zreing_ct2_a           AS ct
        INNER JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid = ct~ct_uuid
        INNER JOIN zreing_ct2_rec_a AS rec ON  rec~ct_uuid  = mat~ct_uuid
                                           AND rec~mat_uuid = mat~mat_uuid
        FOR ALL ENTRIES IN @lt_ctmat_me
        WHERE ct~ct_id       = @lt_ctmat_me-ct_id
          AND mat~matnr      = @lt_ctmat_me-matnr
          AND rec~rec_status = 'AC'
        INTO TABLE @lt_set_contrato.
    ENDIF.
    "End Insert V001 (CC) — ME-06 (Delta v2)

    " READ ENTITIES único para todos los ítems de todos los headers válidos
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader BY \_item
        ALL FIELDS
        WITH CORRESPONDING #( lt_valid_keys )
      RESULT DATA(lt_all_items).

    " COLLECT totales por header en un único LOOP (sin anidamiento)
    DATA lt_totals TYPE SORTED TABLE OF ty_total
                   WITH UNIQUE KEY me_h_id.
    DATA lv_mevalue TYPE ty_total-total_val.
    LOOP AT lt_all_items INTO DATA(ls_col).
      "Begin Insert V001 (CC) — ME-06 (Delta v2) — only items in the contract set feed the denominator
      READ TABLE lt_raso_hdr_idx INTO DATA(ls_hci)
        WITH KEY me_h_id = ls_col-%tky-%key-mehid.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      READ TABLE lt_set_contrato TRANSPORTING NO FIELDS
        WITH KEY ct_id         = ls_hci-ct_id
                 matnr         = ls_hci-matnr
                 rec_bukrs     = ls_col-%data-bukrs
                 prctr         = ls_col-%data-prctr
                 campana       = ls_col-%data-campana
                 role_category = ls_col-%data-rolecategory
                 allocation    = ls_col-%data-allocation.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      "End Insert V001 (CC) — ME-06 (Delta v2)
      lv_mevalue = ls_col-%data-mevalue.
      COLLECT VALUE ty_total(
        me_h_id   = ls_col-%tky-%key-mehid
        "total_val = ls_col-%data-mevalue ) INTO lt_totals.
        total_val = lv_mevalue ) INTO lt_totals.
      CLEAR lv_mevalue.
    ENDLOOP.

    " Calcular shares y acumular TotalSharePct por header — todo en un único LOOP
    DATA lt_item_upd_all TYPE TABLE FOR UPDATE zi_reingmeitem.
    DATA lt_share_hdr    TYPE SORTED TABLE OF ty_share_hdr
                         WITH UNIQUE KEY me_h_id.
    "Begin Insert V001 (CC) — FX22 — per-header candidate row for the rounding adjustment
    DATA lt_share_max    TYPE SORTED TABLE OF ty_share_max
                         WITH UNIQUE KEY me_h_id.
    "End Insert V001 (CC) — FX22

    LOOP AT lt_all_items INTO DATA(ls_item).
      READ TABLE lt_totals INTO DATA(ls_tot)
        WITH KEY me_h_id = ls_item-%tky-%key-mehid
        BINARY SEARCH.
      CHECK sy-subrc = 0 AND ls_tot-total_val <> 0.

      "Begin Insert V001 (CC) — ME-06 (Delta v2) — items outside the contract set get share 0 (Q1)
      DATA lv_in_set TYPE abap_bool.
      lv_in_set = abap_false.
      READ TABLE lt_raso_hdr_idx INTO DATA(ls_hci2)
        WITH KEY me_h_id = ls_item-%tky-%key-mehid.
      IF sy-subrc = 0.
        READ TABLE lt_set_contrato TRANSPORTING NO FIELDS
          WITH KEY ct_id         = ls_hci2-ct_id
                   matnr         = ls_hci2-matnr
                   rec_bukrs     = ls_item-%data-bukrs
                   prctr         = ls_item-%data-prctr
                   campana       = ls_item-%data-campana
                   role_category = ls_item-%data-rolecategory
                   allocation    = ls_item-%data-allocation.
        IF sy-subrc = 0. lv_in_set = abap_true. ENDIF.
      ENDIF.
      IF lv_in_set = abap_false.
        APPEND VALUE #(
          %tky     = ls_item-%tky
          sharepct = 0
          varpct   = 0
          varpct2  = 0
          varflag  = space ) TO lt_item_upd_all.
        CONTINUE.
      ENDIF.
      "End Insert V001 (CC) — ME-06 (Delta v2)

      "Begin Insert V001 (CC) — FX11 — resolve per-header variation limit (fallback 15)
      READ TABLE lt_hdr_limit INTO DATA(ls_hdr_lim)
        WITH KEY me_h_id = ls_item-%tky-%key-mehid BINARY SEARCH.
      DATA(lv_var_limit) = COND zreing_mcv_a-var_pct_limit(
        WHEN sy-subrc = 0 THEN ls_hdr_lim-var_limit
        ELSE 15 ).
      "End Insert V001 (CC) — FX11

      " Begin Mod 03.09.2026 EXT_AGFAGINA — COMPUTE_BCD_OVERFLOW en Calcular Share%.
      " El calculo se hacia sobre variables del tipo del campo destino:
      "   lv_share  -> SharePct = DEC(9,6),  tope    999,999999
      "   lv_var_pct-> VarPct   = DEC(11,6), tope 99.999,999999
      " En ABAP, cuando el destino es tipo P los productos intermedios se evaluan
      " en el tipo del destino. Con valores reales (me_value = 9.800.000) el paso
      " intermedio me_value * 100 = 980.000.000 desborda ANTES de dividir, aunque
      " el resultado final si entraria en el campo.
      " Se calcula en variables amplias — mismo criterio que ty_total-total_val y
      " que el accumulator de FX21 — y se asigna al campo al final.
      DATA lv_calc_share TYPE p LENGTH 16 DECIMALS 6.
      DATA lv_calc_var   TYPE p LENGTH 16 DECIMALS 6.
      DATA lv_calc_var2  TYPE p LENGTH 16 DECIMALS 6.

      CLEAR: lv_calc_share, lv_calc_var, lv_calc_var2.

      lv_calc_share = ls_item-%data-mevalue * 100 / ls_tot-total_val.

      " Begin Mod 08.09.2026 EXT_AGFAGINA - la variacion pasa a ser DIFERENCIA, no ratio.
      " Definicion del funcional (hoja 37 del tracker, verificada contra las 50 celdas
      " y contra el caso DRM/199 con 6 decimales):
      "   Var % T/T-1 = valor(T) - valor(T-1)     en puntos porcentuales
      " Antes se calculaba la variacion RELATIVA:
      "   ( valor(T) - valor(T-1) ) * 100 / valor(T-1)
      " que para DRM/199 daba -1,375943 en lugar del -0,381579 esperado.
      "
      " LIMITACION CONOCIDA: esto equivale a la diferencia de SHARES solo mientras el
      " valor cargado represente el share, que es el caso de las pruebas actuales
      " (Valor(T) = 27,350593 y Share% = 27,350593 son el mismo numero).
      " Si en algun momento se cargan consumos reales (GB, licencias, etc.), la resta
      " de valores dejara de coincidir con la resta de shares y habra que traer
      " SHARE_PCT del periodo anterior: hoy el SELECT del bloque AJ-01 y el de
      " SetPrevValues solo leen ME_VALUE. Queda planteado al funcional.
      " Begin Mod 08.09.2026 EXT_AGFAGINA - la variacion es DIFERENCIA DE SHARES.
      " Definicion del funcional (hoja 37 del tracker, formula escrita en la propia
      " celda: G3 = F3 - E3 sobre las columnas de share de cada mes):
      "   Var % T/T-1 = share(T) - share(T-1)
      "   Var % T/T-2 = share(T) - share(T-2)
      "
      " Primera version de este fix restaba VALORES (mevalue - prevvalue). Daba bien
      " solo cuando el valor cargado era el propio share, que es el caso de las
      " pruebas (Valor 27,350593 = Share 27,350593). Con consumos reales no:
      " un item con me_value 9.800.000 y share 66,199233 daba una resta sin sentido.
      " Por eso ahora PREV_VALUE / PREV2_VALUE guardan el SHARE del periodo
      " anterior (ver el SELECT del bloque AJ-01 y SetPrevValues) y la resta se
      " hace contra el share del periodo actual, ya calculado en lv_calc_share.
      IF ls_item-%data-prevvalue <> 0.
        lv_calc_var = lv_calc_share - ls_item-%data-prevvalue.
      ENDIF.
      IF ls_item-%data-prev2value <> 0.
        lv_calc_var2 = lv_calc_share - ls_item-%data-prev2value.
      ENDIF.
      " End Mod 08.09.2026 EXT_AGFAGINA
      " End Mod 08.09.2026 EXT_AGFAGINA

      " Tope del campo VarPct / VarPct2 (DEC 11,6). Si la variacion real lo supera
      " se acota y se marca con W, porque el campo no puede almacenarla y asignarla
      " volveria a producir el overflow. El valor exacto se pierde: si el negocio
      " necesita representar variaciones mayores hay que ampliar el dominio.
      CONSTANTS lc_var_max TYPE p LENGTH 16 DECIMALS 6 VALUE '99999.999999'.
      IF lv_calc_var > lc_var_max.
        lv_calc_var = lc_var_max.
      ELSEIF lv_calc_var < - lc_var_max.
        lv_calc_var = - lc_var_max.
      ENDIF.
      IF lv_calc_var2 > lc_var_max.
        lv_calc_var2 = lc_var_max.
      ELSEIF lv_calc_var2 < - lc_var_max.
        lv_calc_var2 = - lc_var_max.
      ENDIF.

      DATA lv_share TYPE zi_reingmeitem-sharepct.
      lv_share = lv_calc_share.
      DATA(lv_var_pct)  = CONV zreing_me_i_a-var_pct( lv_calc_var ).
      DATA(lv_var_pct2) = CONV zreing_me_i_a-var_pct2( lv_calc_var2 ).
      " End Mod 03.09.2026 EXT_AGFAGINA
      "Begin Mod V001 (CC) — FX11 — compare against dynamic limit instead of hard-coded 15
      DATA(lv_var_flag) = COND zreing_me_i_a-var_flag(
        WHEN abs( lv_var_pct ) > lv_var_limit THEN 'W'
        ELSE space ).
      "End Mod V001 (CC) — FX11

      APPEND VALUE #(
        %tky     = ls_item-%tky
        sharepct = lv_share
        varpct   = lv_var_pct
        varpct2  = lv_var_pct2
        varflag  = lv_var_flag ) TO lt_item_upd_all.

      " Acumular TotalSharePct usando COLLECT sobre tabla auxiliar
      COLLECT VALUE ty_share_hdr(
        me_h_id  = ls_item-%tky-%key-mehid
        total_sh = lv_share ) INTO lt_share_hdr.

      "Begin Insert V001 (CC) — FX22 — remember the row that will absorb the rounding difference:
      " the item with the highest SharePct of this header. The comparison is strictly ">", so on a
      " tie (all items equal) the FIRST item wins, which is the agreed tie-breaker. "First" here
      " means first in the order READ ENTITIES returned the items, which need not match the row
      " order the user sees in the Panel de Cargas UI; that is accepted, since the agreed rule for
      " a full tie is "any line". upd_index is the index of the row just appended to
      " lt_item_upd_all. Items outside the contract set already left the loop via CONTINUE above,
      " so they can never be picked.
      IF lv_share > 0.
        READ TABLE lt_share_max ASSIGNING FIELD-SYMBOL(<ls_max>)
          WITH KEY me_h_id = ls_item-%tky-%key-mehid BINARY SEARCH.
        IF sy-subrc <> 0.
          INSERT VALUE ty_share_max(
            me_h_id   = ls_item-%tky-%key-mehid
            upd_index = lines( lt_item_upd_all )
            max_share = lv_share ) INTO TABLE lt_share_max.
        ELSEIF lv_share > <ls_max>-max_share.
          <ls_max>-upd_index = lines( lt_item_upd_all ).
          <ls_max>-max_share = lv_share.
        ENDIF.
      ENDIF.
      "End Insert V001 (CC) — FX22
    ENDLOOP.

    "Begin Insert V001 (CC) — FX22 — absorb the residual rounding difference so the SharePct of
    " every header adds up to exactly 100.
    " Each item share is rounded to SharePct's DEC(9,6) — assigning an arithmetic expression to a
    " packed type rounds commercially, it does not truncate — so the sum of the parts can land a
    " few millionths on EITHER side of 100 (observed 100.000003). With pure truncation the sum
    " could only ever fall short of 100.
    " The residual goes to the item with the highest share (first one on ties), which is the line
    " that can absorb it with the least relative distortion.
    " The adjustment is an addition: 100 - accumulated total. A total above 100 yields a negative
    " adjustment (subtracts from the line), a total below 100 a positive one (adds to it).
    " Computed on the wide DEC(16,6) accumulator (FX21), never on total_share_pct's DEC(7,2).
    " Headers with an accumulated total of 0 are skipped: by ME-06 every item can legitimately fall
    " outside the contract receiver set and get share 0 — that 0 must not be pushed up to 100.
    DATA lv_share_adj TYPE p LENGTH 16 DECIMALS 6.
    LOOP AT lt_share_hdr ASSIGNING FIELD-SYMBOL(<ls_sh_adj>).
      IF <ls_sh_adj>-total_sh = 0.
        CONTINUE.
      ENDIF.
      lv_share_adj = 100 - <ls_sh_adj>-total_sh.
      IF lv_share_adj = 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_share_max INTO DATA(ls_max_adj)
        WITH KEY me_h_id = <ls_sh_adj>-me_h_id BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_item_upd_all ASSIGNING FIELD-SYMBOL(<ls_upd_adj>)
        INDEX ls_max_adj-upd_index.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_upd_adj>-sharepct = <ls_upd_adj>-sharepct + lv_share_adj.
      " Keep the header total consistent with the adjusted items
      <ls_sh_adj>-total_sh  = 100.
    ENDLOOP.
    "End Insert V001 (CC) — FX22

    IF lt_item_upd_all IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeitem
          UPDATE FIELDS ( sharepct varpct varpct2 varflag )
          WITH lt_item_upd_all
        REPORTED DATA(lt_rep).
    ENDIF.

    " Actualizar estado y TotalSharePct de cada header — sin LOOP anidado
    LOOP AT lt_valid_keys INTO DATA(ls_me).
      READ TABLE lt_totals INTO DATA(ls_tot_hdr)
        WITH KEY me_h_id = ls_me-%data-mehid
        BINARY SEARCH.

      IF sy-subrc <> 0 OR ls_tot_hdr-total_val = 0.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'No hay ítems con valor para calcular Share%' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.

      READ TABLE lt_share_hdr INTO DATA(ls_sh)
        WITH KEY me_h_id = ls_me-%data-mehid
        BINARY SEARCH.

      DATA(lv_total_sh) = COND zreing_me_h_a-total_share_pct(
        WHEN sy-subrc = 0 THEN ls_sh-total_sh
        ELSE 0 ).

      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus totalsharepct )
          WITH VALUE #( ( %tky          = ls_me-%tky
                          mestatus      = 'GRAV'
                          totalsharepct = lv_total_sh ) )
        REPORTED DATA(lt_rep2).
    ENDLOOP.
  ENDMETHOD.

  METHOD enviar.

    "*----------------------------------------------------------------------*
* Modified by    : Oscar Ugalde (EXT_OSCUGALD)                          *
* Change ID      : V005                                                 *
* Date           : 29.06.2026                                           *
* Description    : Re-validar reglas críticas (BR-ME-01, 01a, 01b) antes*
*                  de cambiar a ENVI, usando check_business_rules. Se   *
*                  descartó EXECUTE prepare (NOT_FOUND — no invocable   *
*                  desde una acción custom).                            *
*-----------------------------------------------------------------------*

*    IF sy-uname = 'EXT_OSCUGALD'.
    " ── V005: Re-validar reglas críticas antes de Enviar ────────────────────
    DATA lt_mehids_v5  TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    DATA lt_blocked_v5 TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    LOOP AT keys INTO DATA(ls_kv5).
      TRY.
          INSERT ls_kv5-mehid INTO TABLE lt_mehids_v5.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA(lt_errors_v5) = check_business_rules( it_mehids = lt_mehids_v5 ).

    LOOP AT lt_errors_v5 INTO DATA(ls_err_v5).
      TRY.
          INSERT ls_err_v5-mehid INTO TABLE lt_blocked_v5.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
      APPEND VALUE #( %tky = VALUE #( mehid = ls_err_v5-mehid %is_draft = if_abap_behv=>mk-on )
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = ls_err_v5-msg ) )
        TO reported-zi_reingmeheader.
    ENDLOOP.

    LOOP AT lt_blocked_v5 INTO DATA(ls_blk_v5).
      APPEND VALUE #( %tky = VALUE #( mehid = ls_blk_v5 %is_draft = if_abap_behv=>mk-on ) )
        TO failed-zi_reingmeheader.
    ENDLOOP.
*    ENDIF.
    " ── Fin V005 ───────────────────────────────────────────────────────────

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    LOOP AT lt_me INTO DATA(ls_me).
      " V005: saltar headers que Prepare marcó con error
      READ TABLE lt_blocked_v5 TRANSPORTING NO FIELDS
        WITH KEY table_line = ls_me-%data-mehid.
      IF sy-subrc = 0. CONTINUE. ENDIF.

      IF ls_me-%data-mestatus <> 'GRAV'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede enviar en estado GRAV' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %tky     = ls_me-%tky
                          mestatus = 'ENVI' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD devolver.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    LOOP AT lt_me INTO DATA(ls_me).
      IF ls_me-%data-mestatus <> 'ENVI'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede devolver en estado ENVI' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %tky     = ls_me-%tky
                          mestatus = 'GRAV' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD liberar.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    DATA lt_released TYPE lcl_reing_me_refresh_buffer=>ty_mehid_tab.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)

    LOOP AT lt_result INTO DATA(ls_me).
      IF ls_me-%data-mestatus <> 'ENVI'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede liberar en estado ENVI' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %tky     = ls_me-%tky
                          mestatus = 'LIBD' ) )
        REPORTED DATA(lt_rep).
      " Begin Insert V002 (10.09.2026 | EXT_GONZALCA)
      INSERT ls_me-%tky-mehid INTO TABLE lt_released.
      " End Insert V002 (10.09.2026 | EXT_GONZALCA)
    ENDLOOP.

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    " Hand the released headers to the save phase. Calling refresh_next_periods
    " from here never worked: a MODIFY on items of headers outside the action
    " scope is rejected by RAP because those instances are not locked by the
    " request (proved in TS4 on 04.09.2026 - releasing 03/2026 of IC-0005 left
    " 04/2026 at zero and FAILED raised a warning at the user). The refresh now
    " runs in lsc_zi_reingmeheader~save_modified, where direct DB writes are
    " legal, which is the same pattern MC uses.
    " One INSERT at a time on purpose: INSERT LINES OF into a UNIQUE sorted
    " table raises CX_SY_ITAB_DUPLICATE_KEY, while the single form just returns
    " sy-subrc 4 and skips the header that was already registered.
    LOOP AT lt_released INTO DATA(lv_rel_id).
      INSERT lv_rel_id INTO TABLE lcl_reing_me_refresh_buffer=>gt_released.
    ENDLOOP.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result2).
    result = VALUE #( FOR ls IN lt_result2
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD reabrir.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mestatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    LOOP AT lt_me INTO DATA(ls_me).
      IF ls_me-%data-mestatus <> 'LIBD' AND ls_me-%data-mestatus <> 'LIBR'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede reabrir en estado LIBD o LIBR' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %tky     = ls_me-%tky
                          mestatus = 'GRAV' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD novaversaocarga.
    TYPES: BEGIN OF ty_fae_nvc,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
           END OF ty_fae_nvc.
    TYPES: BEGIN OF ty_ver_nvc,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             load_version TYPE zreing_me_h_a-load_version,
           END OF ty_ver_nvc.
    TYPES: BEGIN OF ty_max_nvc,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             max_version  TYPE zreing_me_h_a-load_version,
           END OF ty_max_nvc.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_me).

    "Begin Insert V001 (CC) — FX06 — read source items of the released headers BEFORE the loop
    " They will be copied into the freshly created header version (bulk read, READ TABLE in loop).
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader BY \_item
        "Begin Mod V001 (CC) — ME-09 (Delta v2) — copy new dimensions RoleCategory/Allocation (role_id removed)
        FIELDS ( mehid bukrs prctr campana rolecategory allocation mevalue )
        "End Mod V001 (CC) — ME-09 (Delta v2)
        WITH CORRESPONDING #( lt_me )
      RESULT DATA(lt_src_items).
    "End Insert V001 (CC) — FX06

    " Construir tabla FAE con solo claves válidas (evita FAllUnsafe)
    DATA lt_fae_nvc TYPE SORTED TABLE OF ty_fae_nvc
                    WITH UNIQUE KEY ct_id matnr period_year period_month.
    LOOP AT lt_me INTO DATA(ls_chk).
      CHECK ls_chk-%data-ctid IS NOT INITIAL
        AND ls_chk-%data-matnr IS NOT INITIAL
        AND ls_chk-%data-periodyear IS NOT INITIAL
        AND ls_chk-%data-periodmonth IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_nvc(
            ct_id        = ls_chk-%data-ctid
            matnr        = ls_chk-%data-matnr
            period_year  = ls_chk-%data-periodyear
            period_month = ls_chk-%data-periodmonth ) INTO TABLE lt_fae_nvc.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA lt_ver_nvc TYPE TABLE OF ty_ver_nvc WITH EMPTY KEY.
    IF lt_fae_nvc IS NOT INITIAL.
      SELECT ct_id, matnr, period_year, period_month, load_version
        FROM zreing_me_h_a
        FOR ALL ENTRIES IN @lt_fae_nvc
        WHERE ct_id        = @lt_fae_nvc-ct_id
          AND matnr        = @lt_fae_nvc-matnr
          AND period_year  = @lt_fae_nvc-period_year
          AND period_month = @lt_fae_nvc-period_month
        INTO TABLE @lt_ver_nvc.
    ENDIF.

    SORT lt_ver_nvc BY ct_id matnr period_year period_month load_version DESCENDING.

    DATA lt_max_nvc TYPE SORTED TABLE OF ty_max_nvc
                    WITH UNIQUE KEY ct_id matnr period_year period_month.
    LOOP AT lt_ver_nvc INTO DATA(ls_ver).
      TRY.
          INSERT VALUE ty_max_nvc(
            ct_id        = ls_ver-ct_id
            matnr        = ls_ver-matnr
            period_year  = ls_ver-period_year
            period_month = ls_ver-period_month
            max_version  = ls_ver-load_version ) INTO TABLE lt_max_nvc.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    "Begin Insert V001 (CC) — FX06 — accumulate the child items to create for all new headers
    DATA lt_item_create TYPE TABLE FOR CREATE zi_reingmeheader\_item.
    TYPES: BEGIN OF ty_hdr_map_nvc,
             me_h_id TYPE zreing_me_h_a-me_h_id,
             hdr_cid TYPE string,
           END OF ty_hdr_map_nvc.
    DATA lt_hdr_map TYPE HASHED TABLE OF ty_hdr_map_nvc WITH UNIQUE KEY me_h_id.
    "End Insert V001 (CC) — FX06

    LOOP AT lt_me INTO DATA(ls_me).
      IF ls_me-%data-mestatus <> 'LIBR'.
        APPEND VALUE #( %tky = ls_me-%tky ) TO failed-zi_reingmeheader.
        APPEND VALUE #( %tky = ls_me-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede crear nueva version desde LIBR (BR-ME-11)' ) )
          TO reported-zi_reingmeheader.
        CONTINUE.
      ENDIF.

      READ TABLE lt_max_nvc INTO DATA(ls_max)
        WITH KEY ct_id        = ls_me-%data-ctid
                 matnr        = ls_me-%data-matnr
                 period_year  = ls_me-%data-periodyear
                 period_month = ls_me-%data-periodmonth
        BINARY SEARCH.

      DATA(lv_new_ver) = COND zreing_me_h_a-load_version(
        WHEN sy-subrc <> 0 THEN '001'
        ELSE CONV #( CONV i( ls_max-max_version ) + 1 ) ).

      "Begin Mod V001 (CC) — FX06 — stable %cid for the new header so its items can reference it
      DATA(lv_hdr_cid) = |NOVA_{ ls_me-%data-ctid }_{ lv_new_ver }|.
      "End Mod V001 (CC) — FX06

      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          CREATE FIELDS ( ctid matnr periodyear periodmonth
                          loadversion mestatus metriccode metversion )
          WITH VALUE #( (
            %cid        = lv_hdr_cid
            ctid        = ls_me-%data-ctid
            matnr       = ls_me-%data-matnr
            periodyear  = ls_me-%data-periodyear
            periodmonth = ls_me-%data-periodmonth
            loadversion = lv_new_ver
            mestatus    = 'RASO'
            metriccode  = ls_me-%data-metriccode
            metversion  = ls_me-%data-metversion ) )
        REPORTED DATA(lt_rep).

      "Begin Insert V001 (CC) — FX06 — record CID mapping so post-loop pass can copy items
      INSERT VALUE ty_hdr_map_nvc( me_h_id = ls_me-%data-mehid hdr_cid = lv_hdr_cid )
        INTO TABLE lt_hdr_map.
      "End Insert V001 (CC) — FX06
    ENDLOOP.

    "Begin Insert V001 (CC) — FX06 — copy source items using the CID map (single pass, no nesting)
    LOOP AT lt_src_items INTO DATA(ls_src).
      READ TABLE lt_hdr_map INTO DATA(ls_hdr_m) WITH TABLE KEY me_h_id = ls_src-%data-mehid.
      CHECK sy-subrc = 0.
      "Begin Mod V001 (CC) — ME-09 (Delta v2) — RoleCategory/Allocation replace role_id/role_share_pct
      APPEND VALUE #(
        %cid_ref = ls_hdr_m-hdr_cid
        %target  = VALUE #( (
          %cid         = |NOVA_I_{ ls_hdr_m-hdr_cid }_{ sy-tabix }|
          bukrs        = ls_src-bukrs
          prctr        = ls_src-prctr
          campana      = ls_src-campana
          rolecategory = ls_src-rolecategory
          allocation   = ls_src-allocation
          mevalue      = ls_src-mevalue
          sharepct     = 0
          varpct       = 0
          varpct2      = 0
          varflag      = space ) ) ) TO lt_item_create.
      "End Mod V001 (CC) — ME-09 (Delta v2)
    ENDLOOP.
    "End Insert V001 (CC) — FX06

    "Begin Insert V001 (CC) — FX06 — create the copied items in a single bulk operation
    IF lt_item_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          CREATE BY \_item
          "Begin Mod V001 (CC) — ME-09 (Delta v2) — RoleCategory/Allocation replace role_id
          FIELDS ( bukrs prctr campana rolecategory allocation mevalue
                   sharepct varpct varpct2 varflag )
          "End Mod V001 (CC) — ME-09 (Delta v2)
          WITH lt_item_create
        REPORTED DATA(lt_rep_items).
    ENDIF.
    "End Insert V001 (CC) — FX06

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  "Begin Insert V001 (CC) - FX-XLS - backend Excel export (real metric-load data, 13 columns)
  METHOD exporttemplate.
    " V001 (CC) — ME-14 (Delta v2): forward the RAP metric parameter to the export handler.
    DATA(lo_hdl) = NEW zcl_reing_me_xls_hdl( ).
    DATA(lv_xstring) = lo_hdl->export_template(
      iv_period_year  = keys[ 1 ]-%param-PeriodYear
      iv_period_month = keys[ 1 ]-%param-PeriodMonth
      iv_metric_code  = keys[ 1 ]-%param-MetricCode ).

    " Encode the binary .xlsx as base64 (same contract as the CM app)
    DATA(lv_base64) = xco_cp=>xstring( lv_xstring
      )->as_string( xco_cp_binary=>text_encoding->base64 )->value.

    " Compose the file name from the requested period
    DATA(lv_year)  = keys[ 1 ]-%param-PeriodYear.
    DATA(lv_month) = keys[ 1 ]-%param-PeriodMonth.
    DATA lv_fname TYPE c LENGTH 255.
    IF lv_year IS NOT INITIAL AND lv_month IS NOT INITIAL.
      lv_fname = |CargasMetricas_{ lv_year }-{ lv_month }.xlsx|.
    ELSE.
      lv_fname = |CargasMetricas.xlsx|.
    ENDIF.

    result = VALUE #( ( %cid              = keys[ 1 ]-%cid
                        %param-FileContent = lv_base64
                        %param-FileName    = lv_fname
                        %param-MimeType    =
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ).
  ENDMETHOD.

" Begin Insert V001 (CC) — ME-17 (Delta v2)
METHOD upload.
  TYPES: BEGIN OF ty_header_db,
           ct_id         TYPE zreing_me_h_a-ct_id,
           matnr         TYPE zreing_me_h_a-matnr,
           period_year   TYPE zreing_me_h_a-period_year,
           period_month  TYPE zreing_me_h_a-period_month,
           me_h_id       TYPE zreing_me_h_a-me_h_id,
           me_status     TYPE zreing_me_h_a-me_status,
         END OF ty_header_db.
  TYPES ty_t_header_db TYPE SORTED TABLE OF ty_header_db
                       WITH UNIQUE KEY ct_id matnr period_year period_month.
  TYPES: BEGIN OF ty_row_result,
           row_number TYPE i,
           severity   TYPE c LENGTH 1,
           message    TYPE string,
         END OF ty_row_result.
  TYPES ty_t_row_result TYPE STANDARD TABLE OF ty_row_result WITH EMPTY KEY.
  TYPES: BEGIN OF ty_plan,
           ct_id         TYPE zreing_me_h_a-ct_id,
           matnr         TYPE zreing_me_h_a-matnr,
           period_year   TYPE zreing_me_h_a-period_year,
           period_month  TYPE zreing_me_h_a-period_month,
           me_h_id       TYPE zreing_me_h_a-me_h_id,
           cid           TYPE abp_behv_cid,
           is_new        TYPE abap_bool,
         END OF ty_plan.
  TYPES ty_t_plan TYPE SORTED TABLE OF ty_plan
                  WITH UNIQUE KEY ct_id matnr period_year period_month.
  " V001 (CC) — ATC P2 performance (Delta v2): flat row plan and indexed header lookup
  TYPES: BEGIN OF ty_plan_row,
           cid        TYPE abp_behv_cid,
           source_row TYPE i,
           item       TYPE zcl_reing_me_upload_hdl=>ty_item_payload,
         END OF ty_plan_row.
  TYPES ty_t_plan_row TYPE SORTED TABLE OF ty_plan_row
                      WITH NON-UNIQUE KEY cid source_row.
  TYPES: BEGIN OF ty_plan_cid_idx,
           cid     TYPE abp_behv_cid,
           me_h_id TYPE zreing_me_h_a-me_h_id,
         END OF ty_plan_cid_idx.
  TYPES ty_t_plan_cid_idx TYPE HASHED TABLE OF ty_plan_cid_idx WITH UNIQUE KEY cid.
  TYPES: BEGIN OF ty_plan_mehid_idx,
           me_h_id TYPE zreing_me_h_a-me_h_id,
           cid     TYPE abp_behv_cid,
         END OF ty_plan_mehid_idx.
  TYPES ty_t_plan_mehid_idx TYPE HASHED TABLE OF ty_plan_mehid_idx WITH UNIQUE KEY me_h_id.
  TYPES ty_t_source_row TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
  TYPES: BEGIN OF ty_item_cid_row,
           cid        TYPE abp_behv_cid,
           source_row TYPE i,
         END OF ty_item_cid_row.
  TYPES ty_t_item_cid_row TYPE HASHED TABLE OF ty_item_cid_row WITH UNIQUE KEY cid.
  TYPES: BEGIN OF ty_final_row,
           row_number TYPE i,
           severity   TYPE c LENGTH 1,
           message    TYPE string,
         END OF ty_final_row.
  TYPES ty_t_final_row TYPE HASHED TABLE OF ty_final_row WITH UNIQUE KEY row_number.

  DATA lt_rows TYPE ty_t_row_result.
  DATA lt_headers_db TYPE ty_t_header_db.
  DATA lt_plan TYPE ty_t_plan.
  DATA lt_plan_rows TYPE ty_t_plan_row.
  DATA lt_plan_cid_idx TYPE ty_t_plan_cid_idx.
  DATA lt_plan_mehid_idx TYPE ty_t_plan_mehid_idx.
  DATA lt_source_rows TYPE ty_t_source_row.
  DATA lt_item_cid_rows TYPE ty_t_item_cid_row.
  DATA lt_final_rows TYPE ty_t_final_row.
  DATA lt_new_headers TYPE TABLE FOR CREATE zi_reingmeheader.
  DATA lt_items_to_create TYPE TABLE FOR CREATE zi_reingmeheader\_item.
  DATA lt_items_to_delete TYPE TABLE FOR DELETE zi_reingmeitem.
  DATA lt_calculate TYPE TABLE FOR ACTION IMPORT zi_reingmeheader~calcularshare.
  DATA lv_event_cid TYPE abp_behv_cid.

  DATA(lv_file_content) = keys[ 1 ]-%param-FileContent.
  DATA lv_xstring TYPE xstring.
  TRY.
      lv_xstring = cl_web_http_utility=>decode_x_base64( encoded = lv_file_content ).
    CATCH cx_root INTO DATA(lx_base64).
      APPEND VALUE #( %cid = keys[ 1 ]-%cid %param-RowNumber = 0 %param-Severity = 'E'
        %param-Message = |El contenido del archivo en Base64 no es válido: { lx_base64->get_text( ) }| ) TO result.
      RETURN.
  ENDTRY.
  DATA(ls_import) = NEW zcl_reing_me_upload_hdl( )->import_file(
    iv_period_year  = keys[ 1 ]-%param-PeriodYear
    iv_period_month = keys[ 1 ]-%param-PeriodMonth
    iv_file_content = lv_xstring ).

  LOOP AT ls_import-messages INTO DATA(ls_parser_message).
    INSERT VALUE #( row_number = ls_parser_message-row_number
                    severity   = ls_parser_message-severity
                    message    = ls_parser_message-text ) INTO TABLE lt_rows.
  ENDLOOP.
  IF ls_import-is_success = abap_false.
    LOOP AT lt_rows INTO DATA(ls_parser_row).
      APPEND VALUE #( %cid = keys[ 1 ]-%cid %param-RowNumber = ls_parser_row-row_number
        %param-Severity = ls_parser_row-severity %param-Message = ls_parser_row-message ) TO result.
    ENDLOOP.
    RETURN.
  ENDIF.

  " Validate every target before the first modifying EML statement.
  SELECT ct_id, matnr, period_year, period_month, me_h_id, me_status
    FROM zreing_me_h_a
    FOR ALL ENTRIES IN @ls_import-payload
    WHERE ct_id         = @ls_import-payload-ct_id
      AND matnr         = @ls_import-payload-matnr
      AND period_year   = @ls_import-payload-period_year
      AND period_month  = @ls_import-payload-period_month
    INTO TABLE @lt_headers_db.

  LOOP AT ls_import-accepted_source_rows INTO DATA(lv_accepted_row).
    INSERT lv_accepted_row INTO TABLE lt_source_rows.
  ENDLOOP.

  LOOP AT ls_import-payload INTO DATA(ls_payload).
    READ TABLE lt_headers_db INTO DATA(ls_header_db)
      WITH TABLE KEY ct_id = ls_payload-ct_id matnr = ls_payload-matnr
                     period_year = ls_payload-period_year period_month = ls_payload-period_month.
    IF sy-subrc = 0 AND ls_header_db-me_status <> 'RASO' AND ls_header_db-me_status <> 'GRAV'.
      INSERT VALUE #( row_number = ls_payload-source_row severity = 'E'
                      message = 'La cabecera existente no es editable (se requiere estado RASO o GRAV)' )
        INTO TABLE lt_rows.
      CONTINUE.
    ENDIF.
    DATA(lv_is_new) = xsdbool( sy-subrc <> 0 ).
    READ TABLE lt_plan ASSIGNING FIELD-SYMBOL(<ls_plan>)
      WITH TABLE KEY ct_id = ls_payload-ct_id matnr = ls_payload-matnr
                     period_year = ls_payload-period_year period_month = ls_payload-period_month.
    IF sy-subrc <> 0.
      " Begin Mod (31.08.2026 | EXT_AGFAGINA) — %cid unico por cabecera.
      " El cid se armaba con sy-tabix, pero en este punto sy-tabix es el del
      " READ TABLE inmediatamente anterior — que acaba de fallar — y por lo tanto
      " vale siempre 0: TODAS las cabeceras planificadas recibian el mismo %cid
      " 'UPLOAD_0'. Con un unico contrato en el archivo no se manifestaba; con dos
      " o mas, el CREATE de RAP recibe cabeceras con %cid duplicado y la accion
      " termina en "Error de proveedor no especificado".
      " lines( lt_plan ) + 1 da un correlativo unico por cabecera planificada.
      INSERT VALUE #( ct_id = ls_payload-ct_id matnr = ls_payload-matnr
                      period_year = ls_payload-period_year period_month = ls_payload-period_month
                      me_h_id = COND #( WHEN lv_is_new = abap_false THEN ls_header_db-me_h_id )
                      cid = |UPLOAD_{ lines( lt_plan ) + 1 }| is_new = lv_is_new )
        INTO TABLE lt_plan ASSIGNING <ls_plan>.
      " End Mod (31.08.2026 | EXT_AGFAGINA)
      INSERT VALUE #( cid = <ls_plan>-cid me_h_id = <ls_plan>-me_h_id )
        INTO TABLE lt_plan_cid_idx.
      IF <ls_plan>-me_h_id IS NOT INITIAL.
        INSERT VALUE #( me_h_id = <ls_plan>-me_h_id cid = <ls_plan>-cid )
          INTO TABLE lt_plan_mehid_idx.
      ENDIF.
    ENDIF.
    INSERT VALUE #( cid = <ls_plan>-cid source_row = ls_payload-source_row item = ls_payload-item )
      INTO TABLE lt_plan_rows.
  ENDLOOP.
  READ TABLE lt_rows WITH KEY severity = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    LOOP AT lt_rows INTO DATA(ls_precheck_row).
      APPEND VALUE #( %cid = keys[ 1 ]-%cid %param-RowNumber = ls_precheck_row-row_number
        %param-Severity = ls_precheck_row-severity %param-Message = ls_precheck_row-message ) TO result.
    ENDLOOP.
    RETURN.
  ENDIF.

  " Build one request-wide EML change set. RAP must not save any change if it reports FAILED.
  LOOP AT lt_plan INTO DATA(ls_plan).
    IF ls_plan-is_new = abap_true.
      APPEND VALUE #( %cid = ls_plan-cid ctid = ls_plan-ct_id matnr = ls_plan-matnr
                      periodyear = ls_plan-period_year periodmonth = ls_plan-period_month )
        TO lt_new_headers.
    ELSE.
      APPEND VALUE #( mehid = ls_plan-me_h_id ) TO lt_calculate.
    ENDIF.
  ENDLOOP.

  READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
    ENTITY zi_reingmeheader BY \_item
      ALL FIELDS WITH CORRESPONDING #( lt_calculate )
    RESULT DATA(lt_old_items).
  LOOP AT lt_old_items INTO DATA(ls_old_item).
    APPEND VALUE #( %tky = ls_old_item-%tky ) TO lt_items_to_delete.
  ENDLOOP.

  " Create child rows from the flat plan in one pass.
  LOOP AT lt_plan_rows INTO DATA(ls_plan_row).
    DATA lv_item_cid TYPE abp_behv_cid.
    lv_item_cid = |ITEM_{ ls_plan_row-cid }_{ ls_plan_row-source_row }|.
    INSERT VALUE #( cid = lv_item_cid source_row = ls_plan_row-source_row )
      INTO TABLE lt_item_cid_rows.
    READ TABLE lt_plan_cid_idx INTO DATA(ls_create_idx)
      WITH TABLE KEY cid = ls_plan_row-cid.
    IF ls_create_idx-me_h_id IS INITIAL.
      APPEND VALUE #( %cid_ref = ls_plan_row-cid
        %target = VALUE #( ( %cid = lv_item_cid
          bukrs = ls_plan_row-item-bukrs prctr = ls_plan_row-item-prctr
          campana = ls_plan_row-item-campana rolecategory = ls_plan_row-item-role_category
          allocation = ls_plan_row-item-allocation mevalue = ls_plan_row-item-me_value ) ) )
        TO lt_items_to_create.
    ELSE.
      APPEND VALUE #( %tky-mehid = ls_create_idx-me_h_id
        %target = VALUE #( ( %cid = lv_item_cid
          bukrs = ls_plan_row-item-bukrs prctr = ls_plan_row-item-prctr
          campana = ls_plan_row-item-campana rolecategory = ls_plan_row-item-role_category
          allocation = ls_plan_row-item-allocation mevalue = ls_plan_row-item-me_value ) ) )
        TO lt_items_to_create.
    ENDIF.
  ENDLOOP.

  " Begin Mod (31.08.2026 | EXT_AGFAGINA) — CREATE sin FIELDS no transferia los datos.
  " CREATE FROM <itab> solo transfiere los campos marcados en el %control de cada
  " linea, y lt_new_headers / lt_items_to_create se arman con APPEND VALUE #( ) sin
  " setear %control: RAP creaba cabeceras e items VACIOS y disparaban todas las
  " validaciones de obligatoriedad (BR-ME-01 en la cabecera; BR-ME-14, BR-ME-15a,
  " BR-CT-SOC-03 y BR-CT-SOC-04 en el item), que el framework devolvia como
  " "Error de proveedor no especificado".
  " Declarar los campos con FIELDS ( ) hace que RAP arme el %control. Es el mismo
  " patron que ya usa NovaVersaoCarga en este pool, el unico CREATE que funcionaba.
  MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
    ENTITY zi_reingmeheader
      CREATE FIELDS ( ctid matnr periodyear periodmonth ) WITH lt_new_headers
      CREATE BY \_item
        FIELDS ( bukrs prctr campana rolecategory allocation mevalue )
        WITH lt_items_to_create
    ENTITY zi_reingmeitem DELETE FROM lt_items_to_delete
    MAPPED DATA(lt_mapped_change)
    FAILED DATA(lt_failed_change)
    REPORTED DATA(lt_reported_change).
  " End Mod (31.08.2026 | EXT_AGFAGINA)

  IF lt_failed_change IS NOT INITIAL.
    LOOP AT lt_failed_change-zi_reingmeheader ASSIGNING FIELD-SYMBOL(<ls_failed_header>).
      CLEAR lv_event_cid.
      IF <ls_failed_header>-%cid IS NOT INITIAL.
        lv_event_cid = <ls_failed_header>-%cid.
      ELSE.
        READ TABLE lt_plan_mehid_idx INTO DATA(ls_failed_header_idx)
          WITH TABLE KEY me_h_id = <ls_failed_header>-%tky-%key-mehid.
        IF sy-subrc = 0.
          lv_event_cid = ls_failed_header_idx-cid.
        ENDIF.
      ENDIF.
      IF lv_event_cid IS NOT INITIAL.
        DATA(lt_failed_header_rows) = FILTER #( lt_plan_rows WHERE cid = lv_event_cid ).
        APPEND LINES OF VALUE ty_t_row_result(
          FOR ls_failed_header_row IN lt_failed_header_rows
          ( row_number = ls_failed_header_row-source_row severity = 'E'
            message = 'Se rechazó la persistencia de la carga para esta cabecera' ) ) TO lt_rows.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_failed_change-zi_reingmeitem ASSIGNING FIELD-SYMBOL(<ls_failed_item>).
      READ TABLE lt_item_cid_rows INTO DATA(ls_failed_item_row)
        WITH TABLE KEY cid = <ls_failed_item>-%cid.
      IF sy-subrc = 0.
        APPEND VALUE #( row_number = ls_failed_item_row-source_row severity = 'E'
          message = 'Se rechazó la persistencia de la carga para este ítem' ) TO lt_rows.
      ELSE.
        READ TABLE lt_plan_mehid_idx INTO DATA(ls_failed_item_idx)
          WITH TABLE KEY me_h_id = <ls_failed_item>-%tky-%key-mehid.
        IF sy-subrc = 0.
          DATA(lt_failed_item_rows) = FILTER #( lt_plan_rows WHERE cid = ls_failed_item_idx-cid ).
          APPEND LINES OF VALUE ty_t_row_result(
            FOR ls_failed_item_header_row IN lt_failed_item_rows
            ( row_number = ls_failed_item_header_row-source_row severity = 'E'
              message = 'Se rechazó la persistencia de la carga para esta cabecera' ) ) TO lt_rows.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ELSE.
    " Newly created headers receive their technical key from the EML mapping.
    LOOP AT lt_mapped_change-zi_reingmeheader INTO DATA(ls_mapped_header).
      APPEND VALUE #( mehid = ls_mapped_header-mehid ) TO lt_calculate.
      READ TABLE lt_plan_cid_idx ASSIGNING FIELD-SYMBOL(<ls_mapped_idx>)
        WITH TABLE KEY cid = ls_mapped_header-%cid.
      IF sy-subrc = 0.
        <ls_mapped_idx>-me_h_id = ls_mapped_header-mehid.
        INSERT VALUE #( me_h_id = ls_mapped_header-mehid cid = ls_mapped_header-%cid )
          INTO TABLE lt_plan_mehid_idx.
      ENDIF.
    ENDLOOP.
    " CalcularShare is invoked as RAP action, never as a direct ABAP method call.
    MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader EXECUTE calcularshare FROM lt_calculate
      FAILED DATA(lt_failed_share)
      REPORTED DATA(lt_reported_share).
    IF lt_failed_share IS NOT INITIAL.
      LOOP AT lt_failed_share-zi_reingmeheader ASSIGNING FIELD-SYMBOL(<ls_failed_share>).
        CLEAR lv_event_cid.
        IF <ls_failed_share>-%cid IS NOT INITIAL.
          lv_event_cid = <ls_failed_share>-%cid.
        ELSE.
          READ TABLE lt_plan_mehid_idx INTO DATA(ls_failed_share_idx)
            WITH TABLE KEY me_h_id = <ls_failed_share>-%tky-%key-mehid.
          IF sy-subrc = 0.
            lv_event_cid = ls_failed_share_idx-cid.
          ENDIF.
        ENDIF.
        IF lv_event_cid IS NOT INITIAL.
          DATA(lt_failed_share_rows) = FILTER #( lt_plan_rows WHERE cid = lv_event_cid ).
          APPEND LINES OF VALUE ty_t_row_result(
            FOR ls_failed_share_row IN lt_failed_share_rows
            ( row_number = ls_failed_share_row-source_row severity = 'E'
              message = 'Se rechazó el cálculo del Share para esta cabecera' ) ) TO lt_rows.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.

  " RAP REPORTED messages affect only the rows belonging to the reported header/item.
  LOOP AT lt_reported_change-zi_reingmeheader ASSIGNING FIELD-SYMBOL(<ls_reported_change>).
    CLEAR lv_event_cid.
    IF <ls_reported_change>-%cid IS NOT INITIAL.
      lv_event_cid = <ls_reported_change>-%cid.
    ELSE.
      READ TABLE lt_plan_mehid_idx INTO DATA(ls_reported_change_idx)
        WITH TABLE KEY me_h_id = <ls_reported_change>-%tky-%key-mehid.
      IF sy-subrc = 0.
        lv_event_cid = ls_reported_change_idx-cid.
      ENDIF.
    ENDIF.
    IF lv_event_cid IS NOT INITIAL.
      DATA(lt_reported_change_rows) = FILTER #( lt_plan_rows WHERE cid = lv_event_cid ).
      APPEND LINES OF VALUE ty_t_row_result(
        FOR ls_reported_change_row IN lt_reported_change_rows
        ( row_number = ls_reported_change_row-source_row severity = 'W'
          message = <ls_reported_change>-%msg->if_message~get_text( ) ) ) TO lt_rows.
    ENDIF.
  ENDLOOP.
  LOOP AT lt_reported_change-zi_reingmeitem ASSIGNING FIELD-SYMBOL(<ls_reported_item>).
    READ TABLE lt_item_cid_rows INTO DATA(ls_reported_item_row)
      WITH TABLE KEY cid = <ls_reported_item>-%cid.
    IF sy-subrc = 0.
      APPEND VALUE #( row_number = ls_reported_item_row-source_row severity = 'W'
        message = <ls_reported_item>-%msg->if_message~get_text( ) ) TO lt_rows.
    ELSE.
      READ TABLE lt_plan_mehid_idx INTO DATA(ls_reported_item_idx)
        WITH TABLE KEY me_h_id = <ls_reported_item>-%tky-%key-mehid.
      IF sy-subrc = 0.
        DATA(lt_reported_item_rows) = FILTER #( lt_plan_rows WHERE cid = ls_reported_item_idx-cid ).
        APPEND LINES OF VALUE ty_t_row_result(
          FOR ls_reported_item_header_row IN lt_reported_item_rows
          ( row_number = ls_reported_item_header_row-source_row severity = 'W'
            message = <ls_reported_item>-%msg->if_message~get_text( ) ) ) TO lt_rows.
      ENDIF.
    ENDIF.
  ENDLOOP.
  IF lt_failed_change IS INITIAL.
    LOOP AT lt_reported_share-zi_reingmeheader ASSIGNING FIELD-SYMBOL(<ls_reported_share>).
      CLEAR lv_event_cid.
      IF <ls_reported_share>-%cid IS NOT INITIAL.
        lv_event_cid = <ls_reported_share>-%cid.
      ELSE.
        READ TABLE lt_plan_mehid_idx INTO DATA(ls_reported_share_idx)
          WITH TABLE KEY me_h_id = <ls_reported_share>-%tky-%key-mehid.
        IF sy-subrc = 0.
          lv_event_cid = ls_reported_share_idx-cid.
        ENDIF.
      ENDIF.
      IF lv_event_cid IS NOT INITIAL.
        DATA(lt_reported_share_rows) = FILTER #( lt_plan_rows WHERE cid = lv_event_cid ).
        APPEND LINES OF VALUE ty_t_row_result(
          FOR ls_reported_share_row IN lt_reported_share_rows
          ( row_number = ls_reported_share_row-source_row severity = 'W'
            message = <ls_reported_share>-%msg->if_message~get_text( ) ) ) TO lt_rows.
      ENDIF.
    ENDLOOP.
  ENDIF.

  " FAILED marks the outer static action as failed. In managed RAP the request's
  " transactional buffer is discarded and the framework does not enter save.
  IF lt_failed_change IS NOT INITIAL OR lt_failed_share IS NOT INITIAL.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid ) TO failed-zi_reingmeheader.
  ENDIF.

  " Reduce messages in one pass: first E wins, otherwise first W, otherwise S.
  LOOP AT lt_source_rows INTO DATA(lv_source_row).
    INSERT VALUE #( row_number = lv_source_row severity = 'S'
      message = 'La carga se persistió y se calculó el Share' ) INTO TABLE lt_final_rows.
  ENDLOOP.
  LOOP AT lt_rows INTO DATA(ls_result_row).
    READ TABLE lt_final_rows ASSIGNING FIELD-SYMBOL(<ls_final_row>)
      WITH TABLE KEY row_number = ls_result_row-row_number.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.
    IF ls_result_row-severity = 'E' AND <ls_final_row>-severity <> 'E'.
      <ls_final_row>-severity = 'E'.
      <ls_final_row>-message = ls_result_row-message.
    ELSEIF ls_result_row-severity = 'W' AND <ls_final_row>-severity = 'S'.
      <ls_final_row>-severity = 'W'.
      <ls_final_row>-message = ls_result_row-message.
    ENDIF.
  ENDLOOP.
  LOOP AT lt_source_rows INTO lv_source_row.
    READ TABLE lt_final_rows INTO DATA(ls_final_row)
      WITH TABLE KEY row_number = lv_source_row.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid %param-RowNumber = lv_source_row
      %param-Severity = ls_final_row-severity %param-Message = ls_final_row-message ) TO result.
  ENDLOOP.
ENDMETHOD.



" End Insert V001 (CC) — ME-17 (Delta v2)
  "End Insert V001 (CC) - FX-XLS


  METHOD check_business_rules.
    "*----------------------------------------------------------------------*
* V005 — EXT_OSCUGALD — 29.06.2026                                      *
* Re-ejecuta las reglas críticas de ValidateHeader antes de permitir    *
* Enviar. Retorna una tabla simple (mehid + mensaje) — el caller        *
* (enviar) construye failed/reported con el tipo concreto del contexto.*
*-----------------------------------------------------------------------*

    DATA lt_read_keys_v5 TYPE TABLE FOR READ IMPORT zi_reingmeheader.
    LOOP AT it_mehids INTO DATA(lv_id_v5).
      INSERT VALUE #( mehid = lv_id_v5 ) INTO TABLE lt_read_keys_v5.
    ENDLOOP.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mehid ctid matnr periodyear periodmonth loadversion )
        WITH CORRESPONDING #( lt_read_keys_v5 )
      RESULT DATA(lt_me).

    " ── Resolver contrato + material (BR-ME-01a / BR-ME-01b) ────────────────
    TYPES: BEGIN OF ty_ct_id, ct_id TYPE zreing_ct2_a-ct_id, END OF ty_ct_id.
    TYPES: BEGIN OF ty_contract,
             ct_id     TYPE zreing_ct2_a-ct_id, ct_uuid TYPE zreing_ct2_a-ct_uuid,
             ct_status TYPE zreing_ct2_a-ct_status,
           END OF ty_contract.
    TYPES: BEGIN OF ty_ct_mat_key,
             ct_uuid TYPE zreing_ct2_mat_a-ct_uuid, matnr TYPE zreing_ct2_mat_a-matnr,
           END OF ty_ct_mat_key.
    TYPES: BEGIN OF ty_material,
             ct_uuid TYPE zreing_ct2_mat_a-ct_uuid, matnr TYPE zreing_ct2_mat_a-matnr,
           END OF ty_material.

    DATA lt_ct_ids TYPE SORTED TABLE OF ty_ct_id WITH UNIQUE KEY ct_id.
    LOOP AT lt_me INTO DATA(ls_ctid).
      CHECK ls_ctid-%data-ctid IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_ct_id( ct_id = ls_ctid-%data-ctid ) INTO TABLE lt_ct_ids.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA lt_contracts TYPE SORTED TABLE OF ty_contract WITH UNIQUE KEY ct_id.
    IF lt_ct_ids IS NOT INITIAL.
      SELECT ct_id, ct_uuid, ct_status FROM zreing_ct2_a
        FOR ALL ENTRIES IN @lt_ct_ids WHERE ct_id = @lt_ct_ids-ct_id
        INTO TABLE @lt_contracts.
    ENDIF.

    DATA lt_ct_mat_keys TYPE SORTED TABLE OF ty_ct_mat_key WITH UNIQUE KEY ct_uuid matnr.
    LOOP AT lt_me INTO DATA(ls_mk).
      CHECK ls_mk-%data-ctid IS NOT INITIAL AND ls_mk-%data-matnr IS NOT INITIAL.
      READ TABLE lt_contracts INTO DATA(ls_ctk) WITH KEY ct_id = ls_mk-%data-ctid BINARY SEARCH.
      CHECK sy-subrc = 0.
      TRY.
          INSERT VALUE ty_ct_mat_key( ct_uuid = ls_ctk-ct_uuid matnr = ls_mk-%data-matnr )
            INTO TABLE lt_ct_mat_keys.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA lt_materials TYPE SORTED TABLE OF ty_material WITH UNIQUE KEY ct_uuid matnr.
    IF lt_ct_mat_keys IS NOT INITIAL.
      SELECT ct_uuid, matnr FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @lt_ct_mat_keys
        WHERE ct_uuid = @lt_ct_mat_keys-ct_uuid AND matnr = @lt_ct_mat_keys-matnr
        INTO TABLE @lt_materials.
    ENDIF.

    " ── Evaluar BR-ME-01, 01a, 01b por header ───────────────────────────────
    LOOP AT lt_me INTO DATA(ls_me).
      IF ls_me-%data-ctid IS INITIAL OR ls_me-%data-matnr IS INITIAL.
        APPEND VALUE #( mehid = ls_me-%data-mehid
          msg = 'Contrato y material son obligatorios — corrija antes de enviar (BR-ME-01)' )
          TO rt_errors.
        CONTINUE.
      ENDIF.

      READ TABLE lt_contracts INTO DATA(ls_contract)
        WITH KEY ct_id = ls_me-%data-ctid BINARY SEARCH.
      IF sy-subrc <> 0.
        APPEND VALUE #( mehid = ls_me-%data-mehid
          msg = 'El contrato no existe — corrija antes de enviar (BR-ME-01a)' )
          TO rt_errors.
        CONTINUE.
      ELSEIF ls_contract-ct_status <> 'AC'.
        APPEND VALUE #( mehid = ls_me-%data-mehid
          msg = 'El contrato no está activo — corrija antes de enviar (BR-ME-01a)' )
          TO rt_errors.
        CONTINUE.
      ENDIF.

      READ TABLE lt_materials TRANSPORTING NO FIELDS
        WITH KEY ct_uuid = ls_contract-ct_uuid matnr = ls_me-%data-matnr.
      IF sy-subrc <> 0.
        APPEND VALUE #( mehid = ls_me-%data-mehid
          msg = 'El material no pertenece al contrato — corrija antes de enviar (BR-ME-01b)' )
          TO rt_errors.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingmeitem IMPLEMENTATION.

  METHOD validateitem.
    "Begin Mod V001 (CC) — ME-07 (Delta v2) — item business key now uses RoleCategory + Allocation (role_id removed)
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeitem
        FIELDS ( mehid bukrs prctr campana rolecategory allocation mevalue )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).
    "End Mod V001 (CC) — ME-07 (Delta v2)

    "Begin Insert V001 (CC) — FX10 — bulk-read CT V2 receivers via SELECT (granularity removed by ME-07)
    " For each item we need the contract receivers (active bukrs/prctr per CtId+Matnr).
    " We resolve CtId+Matnr from the parent header, then read CT V2 tables.
    TYPES: BEGIN OF ty_hdr_ctmat,
             me_h_id TYPE zreing_me_h_a-me_h_id,
             ct_id   TYPE zreing_me_h_a-ct_id,
             matnr   TYPE zreing_me_h_a-matnr,
           END OF ty_hdr_ctmat.
    TYPES: BEGIN OF ty_receiver,
             ct_id      TYPE zreing_ct2_a-ct_id,
             matnr      TYPE zreing_ct2_mat_a-matnr,
             rec_bukrs  TYPE zreing_ct2_rec_a-rec_bukrs,
             prctr      TYPE zreing_ct2_rec_a-prctr,
             rec_status TYPE zreing_ct2_rec_a-rec_status,
           END OF ty_receiver.

    DATA lt_receivers TYPE SORTED TABLE OF ty_receiver
                      WITH NON-UNIQUE KEY ct_id matnr rec_bukrs prctr.
    " Map of header -> CtId/Matnr so the loop can resolve item->contract without re-reading
    DATA lt_hdr_ctmat TYPE SORTED TABLE OF ty_hdr_ctmat WITH UNIQUE KEY me_h_id.

    IF lt_items IS NOT INITIAL.
      " Distinct parent headers of the changed items
      DATA lt_hdr_keys TYPE TABLE FOR READ IMPORT zi_reingmeheader.
      LOOP AT lt_items INTO DATA(ls_hk).
        INSERT VALUE #( mehid = ls_hk-%data-mehid ) INTO TABLE lt_hdr_keys.
      ENDLOOP.
      SORT lt_hdr_keys BY mehid.
      DELETE ADJACENT DUPLICATES FROM lt_hdr_keys COMPARING mehid.

      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          FIELDS ( mehid ctid matnr )
          WITH CORRESPONDING #( lt_hdr_keys )
        RESULT DATA(lt_hdr).

      LOOP AT lt_hdr INTO DATA(ls_h).
        INSERT VALUE ty_hdr_ctmat(
          me_h_id = ls_h-%data-mehid
          ct_id   = ls_h-%data-ctid
          matnr   = ls_h-%data-matnr ) INTO TABLE lt_hdr_ctmat.
      ENDLOOP.

      " Distinct CtId+Matnr keys to drive the CT V2 reads
      TYPES: BEGIN OF ty_ctmat,
               ct_id TYPE zreing_ct2_a-ct_id,
               matnr TYPE zreing_ct2_mat_a-matnr,
             END OF ty_ctmat.
      DATA lt_ctmat TYPE SORTED TABLE OF ty_ctmat WITH UNIQUE KEY ct_id matnr.
      LOOP AT lt_hdr_ctmat INTO DATA(ls_cm).
        CHECK ls_cm-ct_id IS NOT INITIAL AND ls_cm-matnr IS NOT INITIAL.
        INSERT VALUE ty_ctmat( ct_id = ls_cm-ct_id matnr = ls_cm-matnr ) INTO TABLE lt_ctmat.
      ENDLOOP.

      IF lt_ctmat IS NOT INITIAL.
        " Receivers: ct2_a -> ct2_mat_a -> ct2_rec_a
        SELECT ct~ct_id, mat~matnr, rec~rec_bukrs, rec~prctr, rec~rec_status
          FROM zreing_ct2_a     AS ct
          JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid = ct~ct_uuid
          JOIN zreing_ct2_rec_a AS rec ON  rec~ct_uuid  = mat~ct_uuid
                                       AND rec~mat_uuid = mat~mat_uuid
          FOR ALL ENTRIES IN @lt_ctmat
          WHERE ct~ct_id  = @lt_ctmat-ct_id
            AND mat~matnr = @lt_ctmat-matnr
          INTO TABLE @lt_receivers.
      ENDIF.
    ENDIF.
    "End Insert V001 (CC) — FX10

    "Begin Insert V001 (CC) — FX05 — level-1 duplicate detection across the changed item set (BR-ME-18)
    " Same business key (MeHId+Bukrs+Prctr+Campana+RoleCategory+Allocation) appearing twice in this request.
    TYPES: BEGIN OF ty_item_bk,
             me_h_id       TYPE zreing_me_i_a-me_h_id,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
           END OF ty_item_bk.
    DATA lt_seen_bk TYPE SORTED TABLE OF ty_item_bk
                    WITH UNIQUE KEY me_h_id bukrs prctr campana role_category allocation.
    "End Insert V001 (CC) — FX05

    LOOP AT lt_items INTO DATA(ls_item).
      IF ls_item-%data-bukrs IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La sociedad es obligatoria (BR-ME-14)' ) )
          TO reported-zi_reingmeitem.
      ENDIF.

      " Resolve the parent contract/material for the receiver checks
      READ TABLE lt_hdr_ctmat INTO DATA(ls_hdr_cm)
        WITH KEY me_h_id = ls_item-%data-mehid BINARY SEARCH.
      DATA(lv_has_ctmat) = xsdbool( sy-subrc = 0
                                    AND ls_hdr_cm-ct_id IS NOT INITIAL
                                    AND ls_hdr_cm-matnr IS NOT INITIAL ).

      "Begin Insert V001 (CC) — FX10 — Bukrs must be an active receiver of the contract (BR-ME-14)
      IF ls_item-%data-bukrs IS NOT INITIAL AND lv_has_ctmat = abap_true.
        " Any receiver row for this bukrs (ignoring prctr) — to distinguish "not a receiver"
        READ TABLE lt_receivers TRANSPORTING NO FIELDS
          WITH KEY ct_id = ls_hdr_cm-ct_id matnr = ls_hdr_cm-matnr.
        DATA(lv_has_receivers) = xsdbool( sy-subrc = 0 ).
        IF lv_has_receivers = abap_true.
          READ TABLE lt_receivers INTO DATA(ls_rec)
            WITH KEY ct_id = ls_hdr_cm-ct_id matnr = ls_hdr_cm-matnr rec_bukrs = ls_item-%data-bukrs.
          IF sy-subrc <> 0.
            APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
            APPEND VALUE #( %tky = ls_item-%tky
                            %msg = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'La sociedad no es receptora del contrato (BR-ME-14)' ) )
              TO reported-zi_reingmeitem.
          ENDIF.
        ENDIF.
      ENDIF.
      "End Insert V001 (CC) — FX10

      "Begin Mod V001 (CC) — ME-07 (Delta v2) — Profit Center always mandatory (granularity removed); 999 = sin apertura por CeBe
      IF ls_item-%data-prctr IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El centro de beneficio es obligatorio (BR-ME-15a)' ) )
          TO reported-zi_reingmeitem.
      ELSEIF lv_has_ctmat = abap_true.
        " BR-ME-15b: Prctr must be an active receiver for CtId/Matnr/Bukrs/Prctr
        READ TABLE lt_receivers INTO DATA(ls_rec_p)
          WITH KEY ct_id     = ls_hdr_cm-ct_id
                   matnr     = ls_hdr_cm-matnr
                   rec_bukrs = ls_item-%data-bukrs
                   prctr     = ls_item-%data-prctr.
        IF sy-subrc <> 0 OR ls_rec_p-rec_status <> 'AC'.
          APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
          APPEND VALUE #( %tky = ls_item-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = 'El centro de beneficio no está activo como receptor (BR-ME-15b)' ) )
            TO reported-zi_reingmeitem.
        ENDIF.
      ENDIF.
      "End Mod V001 (CC) — ME-07 (Delta v2)

      "Begin Insert V001 (CC) — ME-07 (Delta v2) — ROLE_CATEGORY mandatory, domain (C, E) (BR-CT-SOC-03)
      IF ls_item-%data-rolecategory <> 'C' AND ls_item-%data-rolecategory <> 'E'.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La categoría de rol es obligatoria y debe ser C o E (BR-CT-SOC-03)' ) )
          TO reported-zi_reingmeitem.
      ENDIF.
      "End Insert V001 (CC) — ME-07 (Delta v2)

      "Begin Insert V001 (CC) — ME-07 (Delta v2) — ALLOCATION mandatory, domain (0, 1, 3) (BR-CT-SOC-04)
      IF ls_item-%data-allocation <> '0'
        AND ls_item-%data-allocation <> '1'
        AND ls_item-%data-allocation <> '3'.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
        APPEND VALUE #( %tky = ls_item-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El tipo de asignación es obligatorio y debe ser 0, 1 o 3 (BR-CT-SOC-04)' ) )
          TO reported-zi_reingmeitem.
      ENDIF.
      "End Insert V001 (CC) — ME-07 (Delta v2)

      "Begin Insert V001 (CC) — FX05 — level-1 in-request duplicate item (BR-ME-18)
      IF ls_item-%data-bukrs IS NOT INITIAL.
        TRY.
            INSERT VALUE ty_item_bk(
              me_h_id       = ls_item-%data-mehid
              bukrs         = ls_item-%data-bukrs
              prctr         = ls_item-%data-prctr
              campana       = ls_item-%data-campana
              role_category = ls_item-%data-rolecategory
              allocation    = ls_item-%data-allocation ) INTO TABLE lt_seen_bk.
          CATCH cx_sy_itab_duplicate_key.
            APPEND VALUE #( %tky = ls_item-%tky ) TO failed-zi_reingmeitem.
            APPEND VALUE #( %tky = ls_item-%tky
                            %msg = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Item duplicado en la carga (sociedad/centro/campana/categoria/asignacion) (BR-ME-18)' ) )
              TO reported-zi_reingmeitem.
        ENDTRY.
      ENDIF.
      "End Insert V001 (CC) — FX05
    ENDLOOP.

    "Begin Mod V001 (CC) — AJ-02 — add me_status of parent header to FX05 item duplicate check
    " Detect an existing persisted item with the same business key but a different MeIId.
    IF lt_items IS NOT INITIAL.
      TYPES: BEGIN OF ty_db_item,
               me_h_id       TYPE zreing_me_i_a-me_h_id,
               me_i_id       TYPE zreing_me_i_a-me_i_id,
               bukrs         TYPE zreing_me_i_a-bukrs,
               prctr         TYPE zreing_me_i_a-prctr,
               campana       TYPE zreing_me_i_a-campana,
               role_category TYPE zreing_me_i_a-role_category,
               allocation    TYPE zreing_me_i_a-allocation,
               me_status     TYPE zreing_me_h_a-me_status,
             END OF ty_db_item.
      DATA lt_db_items TYPE SORTED TABLE OF ty_db_item
                        WITH NON-UNIQUE KEY me_h_id bukrs prctr campana role_category allocation me_i_id.
      SELECT itm~me_h_id, itm~me_i_id, itm~bukrs, itm~prctr, itm~campana,
             itm~role_category, itm~allocation, hdr~me_status
        FROM zreing_me_i_a AS itm
        INNER JOIN zreing_me_h_a AS hdr
          ON hdr~me_h_id = itm~me_h_id
        FOR ALL ENTRIES IN @lt_items
        WHERE itm~me_h_id = @lt_items-%data-mehid
          AND itm~bukrs   = @lt_items-%data-bukrs
          AND itm~prctr   = @lt_items-%data-prctr
          AND itm~campana = @lt_items-%data-campana
          AND itm~role_category = @lt_items-%data-rolecategory
          AND itm~allocation    = @lt_items-%data-allocation
        INTO TABLE @lt_db_items.
      "End Mod V001 (CC) — AJ-02

      LOOP AT lt_items INTO DATA(ls_chk_db).
        CHECK ls_chk_db-%data-bukrs IS NOT INITIAL.
        READ TABLE lt_db_items INTO DATA(ls_db)
          WITH KEY me_h_id       = ls_chk_db-%data-mehid
                   bukrs         = ls_chk_db-%data-bukrs
                   prctr         = ls_chk_db-%data-prctr
                   campana       = ls_chk_db-%data-campana
                   role_category = ls_chk_db-%data-rolecategory
                   allocation    = ls_chk_db-%data-allocation
          BINARY SEARCH.
        IF sy-subrc = 0.
          DATA(lv_db_idx) = sy-tabix.
          DATA(lv_db_other) = xsdbool( ls_db-me_i_id <> ls_chk_db-%data-meiid ).
          IF lv_db_other = abap_false AND lv_db_idx < lines( lt_db_items ).
            READ TABLE lt_db_items INTO DATA(ls_db_nxt) INDEX lv_db_idx + 1.
            lv_db_other = xsdbool(
              ls_db_nxt-me_h_id = ls_chk_db-%data-mehid
              AND ls_db_nxt-bukrs         = ls_chk_db-%data-bukrs
              AND ls_db_nxt-prctr         = ls_chk_db-%data-prctr
              AND ls_db_nxt-campana       = ls_chk_db-%data-campana
              AND ls_db_nxt-role_category = ls_chk_db-%data-rolecategory
              AND ls_db_nxt-allocation    = ls_chk_db-%data-allocation ).
          ENDIF.
          "Begin Mod V001 (CC) — AJ-02 — skip FX05 error when item's parent header is RASO
          " (AJ-02 in SetLoadVersion will delete it; physical DB still has the record at this point).
          IF lv_db_other = abap_true AND ls_db-me_status <> 'RASO'.
            APPEND VALUE #( %tky = ls_chk_db-%tky ) TO failed-zi_reingmeitem.
            APPEND VALUE #( %tky = ls_chk_db-%tky
                            %msg = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Ya existe un item con la misma clave de negocio (BR-ME-18)' ) )
              TO reported-zi_reingmeitem.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.
    "End Mod V001 (CC) — AJ-02 (FX05 level-2)
  ENDMETHOD.

  METHOD setstatusonvaluechange.
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeitem
        FIELDS ( mehid mevalue )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    DATA lt_processed TYPE SORTED TABLE OF sysuuid_x16
                       WITH UNIQUE KEY table_line.

    LOOP AT lt_items INTO DATA(ls_item).
      READ TABLE lt_processed WITH TABLE KEY table_line = ls_item-%data-mehid
        TRANSPORTING NO FIELDS.
      CHECK sy-subrc <> 0.
      INSERT ls_item-%data-mehid INTO TABLE lt_processed.

      "Begin Mod V001 (CC) — check BOTH draft and active status for GRAV detection.
      " CalcularShare writes GRAV to draft without activating; reading only active misses that case.
      " Reading only draft misses the case where the record was last activated as GRAV.
      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          FIELDS ( mehid mestatus )
          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                          mehid     = ls_item-%data-mehid ) )
        RESULT DATA(lt_hdr_draft).
      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          FIELDS ( mehid mestatus )
          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                          mehid     = ls_item-%data-mehid ) )
        RESULT DATA(lt_hdr_act).

      DATA(lv_st_draft_hdr) = VALUE #( lt_hdr_draft[ 1 ]-%data-mestatus OPTIONAL ).
      DATA(lv_st_act_hdr)   = VALUE #( lt_hdr_act[ 1 ]-%data-mestatus OPTIONAL ).
      CHECK lv_st_draft_hdr = 'GRAV' OR lv_st_act_hdr = 'GRAV'.
      "End Mod V001 (CC)

      "Begin Insert V001 (CC) — FX07 — when value change reverts header to RASO, clear calculated item fields
      " Reset SharePct/VarPct/VarPct2/VarFlag on all items of the header so stale shares are not shown.
      "Begin Mod V001 (CC) — navigate from DRAFT header to get draft item keys for share field reset
      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader BY \_item
          FIELDS ( meiid )
          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                          mehid     = ls_item-%data-mehid ) )
        RESULT DATA(lt_clr_items).
      "End Mod V001 (CC)

      IF lt_clr_items IS NOT INITIAL.
        MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
          ENTITY zi_reingmeitem
            "Begin Mod V001 (CC) — ME-10 (Delta v2) — RoleSharePct removed from reset (field dropped in ME-01)
            UPDATE FIELDS ( sharepct varpct varpct2 varflag )
            WITH VALUE #( FOR ls_c IN lt_clr_items (
                            %tky         = ls_c-%tky
                            sharepct     = 0
                            varpct       = 0
                            varpct2      = 0
                            varflag      = space ) )
            "End Mod V001 (CC) — ME-10 (Delta v2)
          REPORTED DATA(lt_rep_clr).
      ENDIF.
      "End Insert V001 (CC) — FX07

      "Begin Mod V001 (CC) — write status to DRAFT header explicitly (active header read-only in ON MODIFY)
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeheader
          UPDATE FIELDS ( mestatus )
          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
                          mehid     = ls_item-%data-mehid
                          mestatus  = 'RASO' ) )
        REPORTED DATA(lt_rep).
      "End Mod V001 (CC)
    ENDLOOP.
  ENDMETHOD.

  "End Insert V001 (CC) — FX15

  METHOD setprevvalues.
    " Popula PrevValue (T-1) y Prev2Value (T-2) al crear ítems.
    " Replica la lógica de ZCL_REING_CM_VE_PREV adaptada a ME:
    "   Clave header: CtId + Matnr + PeriodYear + PeriodMonth
    "   Clave ítem:   Bukrs + Prctr + Campana + RoleCategory + Allocation  " V001 (CC) — ME-08 (Delta v2)
    "   Fuente:       JOIN zreing_me_h_a (me_status=LIBD) + zreing_me_i_a
    " ATC Clean Core: sin SELECT en loop, sin loops anidados.

    " ── 1. Leer ítems nuevos sin PrevValue ──────────────────────────────────
    "Begin Mod V001 (CC) — ME-08 (Delta v2) — read role_category + allocation instead of roleid (keep prevvalue)
    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeitem
        FIELDS ( mehid bukrs prctr campana rolecategory allocation prevvalue )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).
    "End Mod V001 (CC) — ME-08 (Delta v2)

    DATA lt_new TYPE TABLE FOR READ RESULT zi_reingmeheader\\zi_reingmeitem.
    LOOP AT lt_items INTO DATA(ls_chk).
      CHECK ls_chk-%data-prevvalue = 0.
      APPEND ls_chk TO lt_new.
    ENDLOOP.
    CHECK lt_new IS NOT INITIAL.

    " ── 2. Leer headers padre: CtId + Matnr + Período ───────────────────────
    DATA lt_hdr_keys TYPE TABLE FOR READ IMPORT zi_reingmeheader.
    LOOP AT lt_new INTO DATA(ls_n).
      INSERT VALUE #( mehid = ls_n-%data-mehid ) INTO TABLE lt_hdr_keys.
    ENDLOOP.
    SORT lt_hdr_keys BY mehid.
    DELETE ADJACENT DUPLICATES FROM lt_hdr_keys COMPARING mehid.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mehid ctid matnr periodyear periodmonth )
        WITH CORRESPONDING #( lt_hdr_keys )
      RESULT DATA(lt_hdrs).

    TYPES: BEGIN OF ty_hdr_info,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             year_t1      TYPE zreing_me_h_a-period_year,
             month_t1     TYPE zreing_me_h_a-period_month,
             year_t2      TYPE zreing_me_h_a-period_year,
             month_t2     TYPE zreing_me_h_a-period_month,
           END OF ty_hdr_info.
    DATA lt_hdr_idx TYPE SORTED TABLE OF ty_hdr_info WITH UNIQUE KEY me_h_id.
    DATA lv_total1 TYPE i.
    DATA lv_total2 TYPE i.

    " ── 3. Calcular T-1 y T-2 (mismo algoritmo que ZCL_REING_CM_VE_PREV) ────
    LOOP AT lt_hdrs INTO DATA(ls_h).
      lv_total1 = ( CONV i( ls_h-%data-periodyear ) * 12 )
                      + ( CONV i( ls_h-%data-periodmonth ) - 1 ) - 1.
      lv_total2 = ( CONV i( ls_h-%data-periodyear ) * 12 )
                      + ( CONV i( ls_h-%data-periodmonth ) - 1 ) - 2.
      INSERT VALUE ty_hdr_info(
        me_h_id      = ls_h-%data-mehid
        ct_id        = ls_h-%data-ctid
        matnr        = ls_h-%data-matnr
        period_year  = ls_h-%data-periodyear
        period_month = ls_h-%data-periodmonth
        year_t1      = lv_total1 DIV 12
        month_t1     = ( lv_total1 MOD 12 ) + 1
        year_t2      = lv_total2 DIV 12
        month_t2     = ( lv_total2 MOD 12 ) + 1 )
      INTO TABLE lt_hdr_idx.
    ENDLOOP.
    CHECK lt_hdr_idx IS NOT INITIAL.

    " ── 4. Construir FAE con períodos T-1 y T-2 ─────────────────────────────
    TYPES: BEGIN OF ty_fae,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
           END OF ty_fae.
    DATA lt_fae TYPE STANDARD TABLE OF ty_fae WITH EMPTY KEY.

    LOOP AT lt_hdr_idx INTO DATA(ls_hi).
      APPEND VALUE ty_fae(
        ct_id = ls_hi-ct_id  matnr = ls_hi-matnr
        period_year = ls_hi-year_t1  period_month = ls_hi-month_t1 ) TO lt_fae.
      APPEND VALUE ty_fae(
        ct_id = ls_hi-ct_id  matnr = ls_hi-matnr
        period_year = ls_hi-year_t2  period_month = ls_hi-month_t2 ) TO lt_fae.
    ENDLOOP.

    " ── 5+6. SELECT único via JOIN: headers LIBD + sus ítems ────────────────
    "Begin Mod V001 (CC) — AJ-01-FIX — add load_version to select max LIBD version per period
    TYPES: BEGIN OF ty_libd_hdr,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             load_version TYPE zreing_me_h_a-load_version,
           END OF ty_libd_hdr.
    DATA lt_libd_hdrs TYPE SORTED TABLE OF ty_libd_hdr
                      WITH UNIQUE KEY ct_id matnr period_year period_month.
    "End Mod V001 (CC) — AJ-01-FIX

    "Begin Mod V001 (CC) — ME-08 (Delta v2) — versioning key role_id -> role_category + allocation
    TYPES: BEGIN OF ty_libd_item,
             me_h_id       TYPE zreing_me_i_a-me_h_id,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
             " Mod 08.09.2026 EXT_AGFAGINA: guarda el SHARE del periodo anterior,
             " no su valor. La variacion es share(T) - share(T-1).
             me_value      TYPE zreing_me_i_a-share_pct,
           END OF ty_libd_item.
    DATA lt_libd_items TYPE SORTED TABLE OF ty_libd_item
                       WITH NON-UNIQUE KEY me_h_id bukrs prctr campana role_category allocation.
    "End Mod V001 (CC) — ME-08 (Delta v2)

    IF lt_fae IS NOT INITIAL.
      "Begin Mod V001 (CC) — AJ-01-FIX — add load_version, sort DESC to pick max version
      SELECT hdrs~me_h_id, hdrs~ct_id, hdrs~matnr,
             hdrs~period_year, hdrs~period_month, hdrs~load_version,
             itms~bukrs, itms~prctr, itms~campana,
             "Begin Mod V001 (CC) — ME-08 (Delta v2) — role_id -> role_category + allocation
             itms~role_category, itms~allocation, itms~share_pct AS me_value
             "End Mod V001 (CC) — ME-08 (Delta v2)
        FROM zreing_me_h_a AS hdrs
        INNER JOIN zreing_me_i_a AS itms
          ON itms~me_h_id = hdrs~me_h_id
        FOR ALL ENTRIES IN @lt_fae
        WHERE hdrs~ct_id        = @lt_fae-ct_id
          AND hdrs~matnr        = @lt_fae-matnr
          AND hdrs~period_year  = @lt_fae-period_year
          AND hdrs~period_month = @lt_fae-period_month
          AND hdrs~me_status    = 'LIBD'
        INTO TABLE @DATA(lt_join_result).

      SORT lt_join_result BY ct_id matnr period_year period_month load_version DESCENDING.
      "End Mod V001 (CC) — AJ-01-FIX

      LOOP AT lt_join_result ASSIGNING FIELD-SYMBOL(<ls_jr>).
        TRY.
            INSERT VALUE ty_libd_hdr(
              me_h_id      = <ls_jr>-me_h_id
              ct_id        = <ls_jr>-ct_id
              matnr        = <ls_jr>-matnr
              period_year  = <ls_jr>-period_year
              period_month = <ls_jr>-period_month
              load_version = <ls_jr>-load_version )
            INTO TABLE lt_libd_hdrs.
          CATCH cx_sy_itab_duplicate_key.                   "#EC NEEDED
        ENDTRY.
        "Begin Mod V001 (CC) — ME-08 (Delta v2) — role_id -> role_category + allocation
        INSERT VALUE ty_libd_item(
          me_h_id       = <ls_jr>-me_h_id
          bukrs         = <ls_jr>-bukrs
          prctr         = <ls_jr>-prctr
          campana       = <ls_jr>-campana
          role_category = <ls_jr>-role_category
          allocation    = <ls_jr>-allocation
          me_value      = <ls_jr>-me_value )
        INTO TABLE lt_libd_items.
        "End Mod V001 (CC) — ME-08 (Delta v2)
      ENDLOOP.
    ENDIF.

    CHECK lt_libd_hdrs IS NOT INITIAL.

    " ── 7. Emparejar y construir update (READ TABLE, sin loops anidados) ─────
    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingmeitem.

    LOOP AT lt_new INTO DATA(ls_item).

      READ TABLE lt_hdr_idx INTO DATA(ls_hdr_i)
        WITH KEY me_h_id = ls_item-%data-mehid.
      CHECK sy-subrc = 0.

      DATA lv_prev1 LIKE ls_item-%data-prevvalue VALUE 0.
      DATA lv_prev2 LIKE ls_item-%data-prevvalue VALUE 0.

      " T-1: buscar header LIBD y luego su ítem con la misma clave
      READ TABLE lt_libd_hdrs INTO DATA(ls_lh1)
        WITH KEY ct_id        = ls_hdr_i-ct_id
                 matnr        = ls_hdr_i-matnr
                 period_year  = ls_hdr_i-year_t1
                 period_month = ls_hdr_i-month_t1.
      IF sy-subrc = 0.
        "Begin Mod V001 (CC) — ME-08 (Delta v2) — match item by role_category + allocation
        READ TABLE lt_libd_items INTO DATA(ls_li1)
          WITH KEY me_h_id       = ls_lh1-me_h_id
                   bukrs         = ls_item-%data-bukrs
                   prctr         = ls_item-%data-prctr
                   campana       = ls_item-%data-campana
                   role_category = ls_item-%data-rolecategory
                   allocation    = ls_item-%data-allocation.
        "End Mod V001 (CC) — ME-08 (Delta v2)
        IF sy-subrc = 0. lv_prev1 = ls_li1-me_value. ENDIF.
      ENDIF.

      " T-2: buscar header LIBD y luego su ítem con la misma clave
      READ TABLE lt_libd_hdrs INTO DATA(ls_lh2)
        WITH KEY ct_id        = ls_hdr_i-ct_id
                 matnr        = ls_hdr_i-matnr
                 period_year  = ls_hdr_i-year_t2
                 period_month = ls_hdr_i-month_t2.
      IF sy-subrc = 0.
        "Begin Mod V001 (CC) — ME-08 (Delta v2) — match item by role_category + allocation
        READ TABLE lt_libd_items INTO DATA(ls_li2)
          WITH KEY me_h_id       = ls_lh2-me_h_id
                   bukrs         = ls_item-%data-bukrs
                   prctr         = ls_item-%data-prctr
                   campana       = ls_item-%data-campana
                   role_category = ls_item-%data-rolecategory
                   allocation    = ls_item-%data-allocation.
        "End Mod V001 (CC) — ME-08 (Delta v2)
        IF sy-subrc = 0. lv_prev2 = ls_li2-me_value. ENDIF.
      ENDIF.

      APPEND VALUE #(
        %tky       = ls_item-%tky
        prevvalue  = lv_prev1
        prev2value = lv_prev2 ) TO lt_upd.

    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
        ENTITY zi_reingmeitem
          UPDATE FIELDS ( prevvalue prev2value )
          WITH lt_upd
        REPORTED DATA(lt_rep).
    ENDIF.

  ENDMETHOD.

  "Begin Insert V001 (CC) — FX14 — item entity-level features: read header status via _Header
  METHOD get_instance_features.
    "Begin Mod V001 (CC) — FX14 fix: read ACTIVE header for status check.
    " The item draft header may carry MeStatus='' (readonly field not copied to the draft
    " snapshot), so navigating BY \_Header to the draft would always return enabled. We read
    " the header entity directly with %is_draft=mk-off using the MeHId carried by the item key.
    " Reading the header directly (instead of BY \_Header navigation with mk-off) is the
    " syntactically safer option: it does not depend on the active item existing, which would
    " not be the case for brand-new draft items.
    DATA lt_hdr_keys TYPE TABLE FOR READ IMPORT zi_reingmeheader.
    LOOP AT keys INTO DATA(ls_kk).
      INSERT VALUE #( mehid = ls_kk-%key-mehid ) INTO TABLE lt_hdr_keys.
    ENDLOOP.
    SORT lt_hdr_keys BY mehid.
    DELETE ADJACENT DUPLICATES FROM lt_hdr_keys COMPARING mehid.

    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
      ENTITY zi_reingmeheader
        FIELDS ( mehid mestatus )
        WITH VALUE #( FOR hk IN lt_hdr_keys
                      ( %is_draft = if_abap_behv=>mk-off
                        mehid     = hk-mehid ) )
      RESULT DATA(lt_hdr).
    "End Mod V001 (CC)

    TYPES: BEGIN OF ty_hdr_st,
             me_h_id   TYPE zreing_me_h_a-me_h_id,
             me_status TYPE zreing_me_h_a-me_status,
           END OF ty_hdr_st.
    DATA lt_hdr_idx TYPE SORTED TABLE OF ty_hdr_st WITH UNIQUE KEY me_h_id.
    LOOP AT lt_hdr INTO DATA(ls_hdr_raw).
      INSERT VALUE #( me_h_id   = ls_hdr_raw-mehid
                      me_status = ls_hdr_raw-mestatus )
        INTO TABLE lt_hdr_idx.
    ENDLOOP.

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_upd) = if_abap_behv=>fc-o-enabled.
      READ TABLE lt_hdr_idx INTO DATA(ls_h)
        WITH KEY me_h_id = ls_key-%key-mehid.
      IF sy-subrc = 0 AND ( ls_h-me_status = 'ENVI' OR ls_h-me_status = 'LIBD'
                         OR ls_h-me_status = 'LIBR' ).
        lv_upd = if_abap_behv=>fc-o-disabled.
      ENDIF.
      "Begin Mod V001 (CC) — FX19 — also disable Delete for items when header in ENVI/LIBD/LIBR
      APPEND VALUE #( %tky = ls_key-%tky %features-%update = lv_upd %features-%delete = lv_upd ) TO result.
      "End Mod V001 (CC) — FX19
    ENDLOOP.
  ENDMETHOD.
  "End Insert V001 (CC) — FX14

  "Begin Insert V001 (CC) — FX15 — ON SAVE counterpart of SetStatusOnValueChange (draft activation flow)
  "Begin Mod V001 (CC) — FX15 removed: the ON SAVE determination has been dropped from the BDEF
  " and its METHODS declaration commented out, so the implementation block must be commented out
  " too — an orphan METHOD without a declaration would fail activation. SetStatusOnValueChange
  " ON MODIFY now handles all cases correctly; the ON SAVE counterpart caused double-processing.
*  METHOD SetStatusOnValueChangeOnSave.
*    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
*      ENTITY zi_reingmeitem
*        FIELDS ( MeHId MeValue )
*        WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_items).
*
*    DATA lt_processed TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
*
*    LOOP AT lt_items INTO DATA(ls_item).
*      READ TABLE lt_processed WITH TABLE KEY table_line = ls_item-%data-MeHId
*        TRANSPORTING NO FIELDS.
*      CHECK sy-subrc <> 0.
*      INSERT ls_item-%data-MeHId INTO TABLE lt_processed.
*
*      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
*        ENTITY zi_reingmeheader
*          FIELDS ( MeHId MeStatus )
*          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
*                          MeHId     = ls_item-%data-MeHId ) )
*        RESULT DATA(lt_hdr).
*
*      READ TABLE lt_hdr INTO DATA(ls_hdr) INDEX 1.
*      CHECK sy-subrc = 0 AND ls_hdr-%data-MeStatus = 'GRAV'.
*
*      READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
*        ENTITY zi_reingmeheader BY \_Item
*          FIELDS ( MeIId )
*          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
*                          MeHId     = ls_item-%data-MeHId ) )
*        RESULT DATA(lt_clr_items).
*      IF lt_clr_items IS NOT INITIAL.
*        MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
*          ENTITY zi_reingmeitem
*            UPDATE FIELDS ( SharePct VarPct VarPct2 VarFlag RoleSharePct )
*            WITH VALUE #( FOR ls_c IN lt_clr_items (
*                            %tky         = ls_c-%tky
*                            SharePct     = 0
*                            VarPct       = 0
*                            VarPct2      = 0
*                            VarFlag      = space
*                            RoleSharePct = 0 ) )
*          REPORTED DATA(lt_rep_clr).
*      ENDIF.
*
*      MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
*        ENTITY zi_reingmeheader
*          UPDATE FIELDS ( MeStatus )
*          WITH VALUE #( ( %is_draft = if_abap_behv=>mk-on
*                          MeHId     = ls_item-%data-MeHId
*                          MeStatus  = 'RASO' ) )
*        REPORTED DATA(lt_rep).
*    ENDLOOP.
*  ENDMETHOD.
  "End Mod V001 (CC)
  "End Insert V001 (CC) — FX15

ENDCLASS.


* Begin Insert V002 (10.09.2026 | EXT_GONZALCA)
* Additional-save handler for the ME BO. Declared in the BDEF with
* "with additional save". Everything here runs in the SAVE phase of the RAP
* LUW: EML is forbidden, direct DB writes are the supported way to touch
* documents outside the action scope, and messages cannot reach the user.
CLASS lsc_zi_reingmeheader DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    " Only save_modified may be redefined under "with additional save": the
    " activation rejects CLEANUP ("cannot be redefined in accordance with
    " BEHAVIOR definition"). Same shape as lsc_zi_reingcarun in ZBP_REINGCARUN.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.
    METHODS refresh_next_periods
      IMPORTING it_mehids TYPE lcl_reing_me_refresh_buffer=>ty_mehid_tab.
ENDCLASS.

CLASS lsc_zi_reingmeheader IMPLEMENTATION.

  METHOD save_modified.
    " Only Liberar fills the buffer, so any other save leaves through here.
    IF lcl_reing_me_refresh_buffer=>gt_released IS INITIAL.
      RETURN.
    ENDIF.
    " Drained BEFORE use, not after: with no cleanup hook available this is the
    " only place that can guarantee the static does not leak into a later save
    " of the same session, even if the refresh below raises.
    DATA(lt_released) = lcl_reing_me_refresh_buffer=>gt_released.
    lcl_reing_me_refresh_buffer=>reset( ).
    refresh_next_periods( lt_released ).
  ENDMETHOD.

  METHOD refresh_next_periods.

    IF it_mehids IS INITIAL. RETURN. ENDIF.

    "-- 1. Periodo de las cabeceras recien liberadas
    TYPES: BEGIN OF ty_rel,
             me_h_id      TYPE zreing_me_h_a-me_h_id,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
           END OF ty_rel.
    DATA lt_rel TYPE SORTED TABLE OF ty_rel WITH UNIQUE KEY me_h_id.

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    " EML is illegal in the save phase, so the two READ ENTITIES of the original
    " become plain SELECTs. Reading transparent tables instead of CDS also keeps
    " this method clear of the AUTHORITY-CHECK(DCL) dump that a DCL-protected
    " read causes in this phase.
    TYPES: BEGIN OF ty_hkey,
             me_h_id TYPE zreing_me_h_a-me_h_id,
           END OF ty_hkey.
    DATA lt_hkey TYPE STANDARD TABLE OF ty_hkey WITH EMPTY KEY.
    lt_hkey = VALUE #( FOR lv_id IN it_mehids ( me_h_id = lv_id ) ).

    SELECT me_h_id, ct_id, matnr, period_year, period_month
      FROM zreing_me_h_a
      FOR ALL ENTRIES IN @lt_hkey
      WHERE me_h_id = @lt_hkey-me_h_id
      INTO TABLE @DATA(lt_rel_hdrs).
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)

    LOOP AT lt_rel_hdrs INTO DATA(ls_rh).
      CHECK ls_rh-ct_id IS NOT INITIAL
        AND ls_rh-matnr IS NOT INITIAL
        AND ls_rh-period_year IS NOT INITIAL
        AND ls_rh-period_month IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_rel(
            me_h_id      = ls_rh-me_h_id
            ct_id        = ls_rh-ct_id
            matnr        = ls_rh-matnr
            period_year  = ls_rh-period_year
            period_month = ls_rh-period_month ) INTO TABLE lt_rel.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    IF lt_rel IS INITIAL. RETURN. ENDIF.

    "-- 2. Periodos destino: P+1 (recibe T-1) y P+2 (recibe T-2).
    "-- Aritmetica de meses identica a SetPrevValues, para que cruce de anio igual.
    TYPES: BEGIN OF ty_tgt,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             src_me_h_id  TYPE zreing_me_h_a-me_h_id,
             offset       TYPE i,
           END OF ty_tgt.
    DATA lt_tgt TYPE SORTED TABLE OF ty_tgt
                WITH NON-UNIQUE KEY ct_id matnr period_year period_month.
    DATA lv_base TYPE i.
    DATA lv_calc TYPE i.

    LOOP AT lt_rel INTO DATA(ls_rel).
      lv_base = ( CONV i( ls_rel-period_year ) * 12 )
                  + ( CONV i( ls_rel-period_month ) - 1 ).
      DO 2 TIMES.
        lv_calc = lv_base + sy-index.
        INSERT VALUE ty_tgt(
          ct_id        = ls_rel-ct_id
          matnr        = ls_rel-matnr
          period_year  = lv_calc DIV 12
          period_month = ( lv_calc MOD 12 ) + 1
          src_me_h_id  = ls_rel-me_h_id
          offset       = sy-index ) INTO TABLE lt_tgt.
      ENDDO.
    ENDLOOP.

    "-- 3. Cabeceras e items de los periodos destino, en una sola lectura.
    "-- Se toman todos los estados: el refresco es inocuo porque T-1/T-2 y las
    "-- variaciones no participan del reparto (ver comentario de la declaracion).
    SELECT hdr~me_h_id, hdr~ct_id, hdr~matnr,
           hdr~period_year, hdr~period_month, hdr~load_version,
           hdr~metric_code, hdr~met_version,
           itm~me_i_id, itm~bukrs, itm~prctr, itm~campana,
           itm~role_category, itm~allocation, itm~me_value
      FROM zreing_me_h_a AS hdr
      INNER JOIN zreing_me_i_a AS itm ON itm~me_h_id = hdr~me_h_id
      FOR ALL ENTRIES IN @lt_tgt
      WHERE hdr~ct_id        = @lt_tgt-ct_id
        AND hdr~matnr        = @lt_tgt-matnr
        AND hdr~period_year  = @lt_tgt-period_year
        AND hdr~period_month = @lt_tgt-period_month
      INTO TABLE @DATA(lt_tgt_rows).
    IF lt_tgt_rows IS INITIAL. RETURN. ENDIF.

    "-- Version de carga mas alta por periodo destino
    SORT lt_tgt_rows BY ct_id matnr period_year period_month load_version DESCENDING.
    TYPES: BEGIN OF ty_maxv,
             ct_id        TYPE zreing_me_h_a-ct_id,
             matnr        TYPE zreing_me_h_a-matnr,
             period_year  TYPE zreing_me_h_a-period_year,
             period_month TYPE zreing_me_h_a-period_month,
             load_version TYPE zreing_me_h_a-load_version,
           END OF ty_maxv.
    DATA lt_maxv TYPE SORTED TABLE OF ty_maxv
                 WITH UNIQUE KEY ct_id matnr period_year period_month.
    LOOP AT lt_tgt_rows INTO DATA(ls_mv).
      TRY.
          INSERT VALUE ty_maxv(
            ct_id        = ls_mv-ct_id
            matnr        = ls_mv-matnr
            period_year  = ls_mv-period_year
            period_month = ls_mv-period_month
            load_version = ls_mv-load_version ) INTO TABLE lt_maxv.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    "-- 4. Valores del periodo liberado, por clave de receptora
    TYPES: BEGIN OF ty_src_val,
             me_h_id       TYPE zreing_me_i_a-me_h_id,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
             me_value      TYPE zreing_me_i_a-me_value,
           END OF ty_src_val.
    DATA lt_src_val TYPE SORTED TABLE OF ty_src_val
         WITH NON-UNIQUE KEY me_h_id bukrs prctr campana role_category allocation.

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    SELECT me_h_id, bukrs, prctr, campana, role_category, allocation, me_value
      FROM zreing_me_i_a
      FOR ALL ENTRIES IN @lt_hkey
      WHERE me_h_id = @lt_hkey-me_h_id
      INTO CORRESPONDING FIELDS OF TABLE @lt_src_val.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)
    IF lt_src_val IS INITIAL. RETURN. ENDIF.

    "-- 5. Limite de variacion por version de metrica de la cabecera DESTINO
    TYPES: BEGIN OF ty_lim_key,
             metric_code TYPE zreing_mcv_a-metric_code,
             met_version TYPE zreing_mcv_a-version_num,
           END OF ty_lim_key.
    DATA lt_lim_keys TYPE SORTED TABLE OF ty_lim_key
                     WITH UNIQUE KEY metric_code met_version.
    LOOP AT lt_tgt_rows INTO DATA(ls_lk).
      CHECK ls_lk-metric_code IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_lim_key( metric_code = ls_lk-metric_code
                                   met_version = ls_lk-met_version ) INTO TABLE lt_lim_keys.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    TYPES: BEGIN OF ty_lim,
             metric_code   TYPE zreing_mcv_a-metric_code,
             version_num   TYPE zreing_mcv_a-version_num,
             var_pct_limit TYPE zreing_mcv_a-var_pct_limit,
           END OF ty_lim.
    DATA lt_lim TYPE SORTED TABLE OF ty_lim WITH UNIQUE KEY metric_code version_num.
    IF lt_lim_keys IS NOT INITIAL.
      SELECT metric_code, version_num, var_pct_limit
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_lim_keys
        WHERE metric_code = @lt_lim_keys-metric_code
          AND version_num = @lt_lim_keys-met_version
        INTO TABLE @lt_lim.
    ENDIF.

    "-- 6. Armar los updates en un unico recorrido, sin loops anidados.
    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    TYPES: BEGIN OF ty_upd,
             me_h_id  TYPE zreing_me_i_a-me_h_id,
             me_i_id  TYPE zreing_me_i_a-me_i_id,
             offset   TYPE i,
             prev_val TYPE zreing_me_i_a-prev_value,
             var_pct  TYPE zreing_me_i_a-var_pct,
             var_flag TYPE zreing_me_i_a-var_flag,
           END OF ty_upd.
    DATA lt_upd TYPE STANDARD TABLE OF ty_upd WITH EMPTY KEY.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)
    DATA lv_calc_var TYPE p LENGTH 16 DECIMALS 6.
    CONSTANTS lc_var_max TYPE p LENGTH 16 DECIMALS 6 VALUE '99999.999999'.

    LOOP AT lt_tgt_rows INTO DATA(ls_tr).

      "-- solo la version de carga mas alta del periodo destino
      READ TABLE lt_maxv INTO DATA(ls_maxv)
        WITH TABLE KEY ct_id        = ls_tr-ct_id
                       matnr        = ls_tr-matnr
                       period_year  = ls_tr-period_year
                       period_month = ls_tr-period_month.
      IF sy-subrc <> 0 OR ls_maxv-load_version <> ls_tr-load_version. CONTINUE. ENDIF.

      "-- que periodo liberado alimenta a este destino, y con que offset
      READ TABLE lt_tgt INTO DATA(ls_t)
        WITH KEY ct_id        = ls_tr-ct_id
                 matnr        = ls_tr-matnr
                 period_year  = ls_tr-period_year
                 period_month = ls_tr-period_month.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      "-- misma receptora en el periodo liberado
      READ TABLE lt_src_val INTO DATA(ls_sv)
        WITH KEY me_h_id       = ls_t-src_me_h_id
                 bukrs         = ls_tr-bukrs
                 prctr         = ls_tr-prctr
                 campana       = ls_tr-campana
                 role_category = ls_tr-role_category
                 allocation    = ls_tr-allocation.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      READ TABLE lt_lim INTO DATA(ls_lim)
        WITH TABLE KEY metric_code = ls_tr-metric_code
                       version_num = ls_tr-met_version.
      DATA(lv_limit) = COND zreing_mcv_a-var_pct_limit(
        WHEN sy-subrc = 0 AND ls_lim-var_pct_limit > 0
        THEN ls_lim-var_pct_limit ELSE 15 ).

      "-- variacion del valor del destino contra el del periodo liberado.
      "-- Se calcula en variable amplia: el intermedio ( a - b ) * 100 desborda
      "-- si se evalua en el tipo del campo (ver fix del 03.09 en CalcularShare).
      CLEAR lv_calc_var.
      IF ls_sv-me_value <> 0.
        lv_calc_var = ( ls_tr-me_value - ls_sv-me_value ) * 100 / ls_sv-me_value.
      ENDIF.
      IF lv_calc_var > lc_var_max.
        lv_calc_var = lc_var_max.
      ELSEIF lv_calc_var < - lc_var_max.
        lv_calc_var = - lc_var_max.
      ENDIF.

      " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
      IF ls_t-offset = 1.
        "-- P+1: el periodo liberado es su T-1
        APPEND VALUE ty_upd(
          me_h_id  = ls_tr-me_h_id
          me_i_id  = ls_tr-me_i_id
          offset   = 1
          prev_val = ls_sv-me_value
          var_pct  = CONV zreing_me_i_a-var_pct( lv_calc_var )
          var_flag = COND zreing_me_i_a-var_flag(
                       WHEN abs( lv_calc_var ) > lv_limit THEN 'W' ELSE space )
        ) TO lt_upd.
      ELSE.
        "-- P+2: el periodo liberado es su T-2. VarFlag no se toca: el indicador
        "-- responde a la variacion contra T-1 (ver issue 37).
        APPEND VALUE ty_upd(
          me_h_id  = ls_tr-me_h_id
          me_i_id  = ls_tr-me_i_id
          offset   = 2
          prev_val = ls_sv-me_value
          var_pct  = CONV zreing_me_i_a-var_pct2( lv_calc_var )
        ) TO lt_upd.
      ENDIF.
      " End Mod V002 (10.09.2026 | EXT_GONZALCA)
    ENDLOOP.

    IF lt_upd IS INITIAL. RETURN. ENDIF.

    " Begin Mod V002 (10.09.2026 | EXT_GONZALCA)
    "-- 7. Persistir. Escritura directa: es la fase SAVE y el EML esta prohibido.
    " Se leen las filas completas porque UPDATE ... FROM TABLE escribe la linea
    " entera, y se parchean solo los campos del refresco. El UPDATE va fuera de
    " todo loop: una sentencia por fila reabriria el finding ATC P2 de
    " operaciones de base de datos dentro de loops.
    " Ya no hay tabla de errores: save_modified no puede reportar al usuario, y
    " el aviso que habia existia para el rechazo de RAP que este cambio elimina.
    DATA lt_full TYPE SORTED TABLE OF zreing_me_i_a
                 WITH UNIQUE KEY me_h_id me_i_id.
    SELECT * FROM zreing_me_i_a
      FOR ALL ENTRIES IN @lt_upd
      WHERE me_h_id = @lt_upd-me_h_id
        AND me_i_id = @lt_upd-me_i_id
      INTO TABLE @lt_full.
    IF lt_full IS INITIAL. RETURN. ENDIF.

    " El string template sobre utclong_current( ) dumpea CONVT_NO_NUMBER: se
    " convierte con cl_abap_tstmp, igual que el resto del paquete.
    DATA lv_now TYPE timestampl.
    lv_now = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).

    LOOP AT lt_upd INTO DATA(ls_up).
      READ TABLE lt_full ASSIGNING FIELD-SYMBOL(<ls_fu>)
        WITH TABLE KEY me_h_id = ls_up-me_h_id
                       me_i_id = ls_up-me_i_id.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      IF ls_up-offset = 1.
        <ls_fu>-prev_value  = ls_up-prev_val.
        <ls_fu>-var_pct     = ls_up-var_pct.
        <ls_fu>-var_flag    = ls_up-var_flag.
      ELSE.
        <ls_fu>-prev2_value = ls_up-prev_val.
        <ls_fu>-var_pct2    = ls_up-var_pct.
      ENDIF.
      <ls_fu>-local_last_changed_at = lv_now.
    ENDLOOP.

    UPDATE zreing_me_i_a FROM TABLE @lt_full.
    " End Mod V002 (10.09.2026 | EXT_GONZALCA)

  ENDMETHOD.

ENDCLASS.
* End Insert V002 (10.09.2026 | EXT_GONZALCA)
