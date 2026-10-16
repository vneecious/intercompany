CLASS lhc_zi_reingctcontract2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingctcontract2 RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_reingctcontract2 RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_reingctcontract2 RESULT result.
    METHODS activatecontract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract2~activatecontract RESULT result.
    METHODS inactivatecontract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract2~inactivatecontract RESULT result.
    METHODS reactivatecontract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract2~reactivatecontract RESULT result.
    METHODS archivecontract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract2~archivecontract RESULT result.
    METHODS uploadreceivers FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract2~uploadreceivers RESULT result.
    METHODS setctstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctcontract2~setctstatus.
    "Begin of mod V001 (CC) - DS4K9B5VNA - 5000047741 - EXT_GONZALCA
    "METHODS SetCtId FOR DETERMINE ON MODIFY
    "   IMPORTING keys FOR zi_reingctcontract2~SetCtId.
    METHODS setctid FOR DETERMINE ON SAVE
      IMPORTING keys FOR zi_reingctcontract2~setctid.
    "End of mod V001 (CC) - DS4K9B5VNA - 5000047741 - EXT_GONZALCA
    METHODS validatecontractheader FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcontract2~validatecontractheader.
    METHODS validateactivation FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcontract2~validateactivation.
    METHODS validateglroleconsistency FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcontract2~validateglroleconsistency.
    METHODS uploadgllines FOR MODIFY
      IMPORTING keys FOR ACTION contract~uploadgllines RESULT result.
ENDCLASS.

CLASS lhc_zi_reingctmaterial2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS calctotalamount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctmaterial2~calctotalamount.
    METHODS setmatdesc FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctmaterial2~setmatdesc.
    METHODS setmatwaers FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctmaterial2~setmatwaers.
    METHODS validatematnr FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctmaterial2~validatematnr.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingctmaterial2 RESULT result.
ENDCLASS.

CLASS lhc_zi_reingctoptype2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_month_days,
             year           TYPE i,
             month          TYPE i,
             days_in_period TYPE i,
           END OF ty_month_days.
    TYPES tt_month_days TYPE STANDARD TABLE OF ty_month_days WITH EMPTY KEY.

    METHODS autocreatelinkedoptype FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~autocreatelinkedoptype.
    METHODS determineopinstancenum FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~determineopinstancenum.
    METHODS setoptypewaers FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~setoptypewaers.
    METHODS validateoptypefields FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctoptype2~validateoptypefields.
    METHODS calcinstallments FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~calcinstallments.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingctoptype2 RESULT result.
    METHODS generatecronlines FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~generatecronlines.
    METHODS build_month_table
      IMPORTING
        iv_from_y        TYPE i
        iv_from_m        TYPE i
        iv_from_d        TYPE i
        iv_to_y          TYPE i
        iv_to_m          TYPE i
        iv_to_d          TYPE i
      RETURNING
        VALUE(rt_months) TYPE tt_month_days.
    METHODS calcmonthpct
      IMPORTING
        iv_days_month TYPE i
        iv_total_days TYPE i
        iv_is_last    TYPE abap_bool
        iv_pct_acum   TYPE decfloat34
      RETURNING
        VALUE(rv_pct) TYPE decfloat34.
    " V001 (CC) - #111: complete the business key before a rate is created.
    METHODS numberoprates FOR NUMBERING
      IMPORTING entities FOR CREATE OpType\_OpRates.
    METHODS syncoprates FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~syncoprates.
    METHODS validatemanualrates FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctoptype2~validatemanualrates.
    METHODS setoptypedescr FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~setoptypedescr.
    METHODS setmeperiodoffsetdefault FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype2~setmeperiodoffsetdefault.
    METHODS validatemeperiodoffset FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctoptype2~validatemeperiodoffset.
    METHODS setexchratetypedefault FOR DETERMINE ON MODIFY
      IMPORTING keys FOR optype~setexchratetypedefault.
ENDCLASS.

CLASS lhc_zi_reingctgl2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setglseq FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctgl2~setglseq.
    METHODS setglroledefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctgl2~setglroledefaults.
    METHODS setgloptypedescr FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctgloptype2~setgloptypedescr.
    METHODS setglopglrole FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctgloptype2~setglopglrole.
    METHODS validateoptype FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctgloptype2~validateoptype.
    METHODS validatenoduplicateglrole FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctgl2~validatenoduplicateglrole.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingctgl2 RESULT result.
ENDCLASS.

CLASS lhc_zi_reingctmetric2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setmetricseq FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctmetric2~setmetricseq.
    METHODS setmetstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctmetric2~setmetstatus.
    METHODS validatemetricdates FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctmetric2~validatemetricdates.
ENDCLASS.

CLASS lhc_zi_reingctcron2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    " V001 (CC) - #111: derive and validate the schedule instance from its option.
    METHODS setcroninstance FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Cron~SetCronInstance.
    METHODS validatecroninstance FOR VALIDATE ON SAVE
      IMPORTING keys FOR Cron~ValidateCronInstance.
    METHODS setcronstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctcron2~setcronstatus.
    METHODS validatecronsum FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcron2~validatecronsum.
    METHODS syncchildcron FOR DETERMINE ON SAVE
      IMPORTING keys FOR zi_reingctcron2~syncchildcron.
ENDCLASS.

CLASS lhc_zi_reingctreceiver2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setreceiverdefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctreceiver2~setreceiverdefaults.
    METHODS setreceiverstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctreceiver2~setreceiverstatus.
    METHODS validatenoduplicatereceiver FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctreceiver2~validatenoduplicatereceiver.
    METHODS syncopratesonreceiver FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctreceiver2~syncopratesonreceiver.
ENDCLASS.


CLASS lsc_zi_reingctcontract2 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
  PRIVATE SECTION.
    METHODS get_uuid RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
ENDCLASS.

CLASS lhc_zi_reingctcontract2 IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
    result = VALUE #(
      FOR key IN keys
      ( %tky                       = key-%tky
        %update                    = if_abap_behv=>auth-allowed
        %delete                    = if_abap_behv=>auth-allowed
        %action-activatecontract   = if_abap_behv=>auth-allowed
        %action-inactivatecontract = if_abap_behv=>auth-allowed
        %action-reactivatecontract = if_abap_behv=>auth-allowed
        %action-archivecontract    = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    result = VALUE #(
      FOR ls IN lt_ct LET lv_st = ls-%data-ctstatus IN (
        %tky                       = ls-%tky
        %action-activatecontract   = COND #( WHEN lv_st = 'BO'
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-inactivatecontract = COND #( WHEN lv_st = 'AC'
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-reactivatecontract = COND #( WHEN lv_st = 'IN'
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-archivecontract    = COND #( WHEN lv_st = 'IN'
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) ).
  ENDMETHOD.

  METHOD setctstatus.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctstatus IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ctstatus = 'BO' ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctstatus ) WITH lt_update
        REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setctid.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    DATA lt_new_ids LIKE lt_ct.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctid IS INITIAL.
        APPEND ls_ct TO lt_new_ids.
      ENDIF.
    ENDLOOP.
    IF lt_new_ids IS INITIAL. RETURN. ENDIF.

    SELECT ct_id FROM zreing_ct2_a
      WHERE ct_id LIKE 'IC-%'
      INTO TABLE @DATA(lt_ids).

    DATA lv_max_num TYPE i VALUE 0.
    LOOP AT lt_ids INTO DATA(ls_id).
      "Begin of mod V001 (CC) - DS4K9B5VNA - 5000047741 - EXT_GONZALCA
      "Fix A: condense trailing blanks of the char(10) suffix before CO/CONV.
      "DATA(lv_suffix) = ls_id-ct_id+3.
      "IF lv_suffix CO '0123456789'.
      DATA(lv_suffix) = condense( CONV string( ls_id-ct_id+3 ) ).
      IF lv_suffix IS NOT INITIAL AND lv_suffix CO '0123456789'.
        "End of mod V001 (CC) - DS4K9B5VNA - 5000047741 - EXT_GONZALCA
        DATA(lv_candidate) = CONV i( lv_suffix ).
        IF lv_candidate > lv_max_num.
          lv_max_num = lv_candidate.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_new_ids INTO DATA(ls_new).
      lv_max_num += 1.
      APPEND VALUE #(
        %tky = ls_new-%tky
        ctid = |IC-{ lv_max_num WIDTH = 4 ALIGN = RIGHT PAD = '0' }| ) TO lt_update.
    ENDLOOP.
    MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctid ) WITH lt_update
      REPORTED DATA(lt_rep).
  ENDMETHOD.

  METHOD validatecontractheader.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( lifnr bukrs validfrom validto )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-lifnr IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'El proveedor es obligatorio' ) ) TO reported-contract.
      ENDIF.
      IF ls_ct-%data-bukrs IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'La sociedad de origen es obligatoria' ) ) TO reported-contract.
      ENDIF.
      IF ls_ct-%data-validfrom IS NOT INITIAL AND ls_ct-%data-validto IS NOT INITIAL
         AND ls_ct-%data-validfrom >= ls_ct-%data-validto.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha fin debe ser posterior a fecha inicio' ) ) TO reported-contract.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateactivation.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctuuid ctstatus validfrom validto )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    DATA lt_bo LIKE lt_ct.
    LOOP AT lt_ct INTO DATA(ls_ct_f).
      IF ls_ct_f-%data-ctstatus = 'BO'.
        APPEND ls_ct_f TO lt_bo.
      ENDIF.
    ENDLOOP.
    IF lt_bo IS INITIAL. RETURN. ENDIF.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 BY \_materials ALL FIELDS
      WITH CORRESPONDING #( lt_bo ) RESULT DATA(lt_all_mats).
    DATA lt_has_mat TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    LOOP AT lt_all_mats INTO DATA(ls_mat).
      TRY.
          INSERT ls_mat-%data-ctuuid INTO TABLE lt_has_mat.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.
    LOOP AT lt_bo INTO DATA(ls_ct).
      IF ls_ct-%data-validfrom IS INITIAL OR ls_ct-%data-validto IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Vigencia incompleta' ) ) TO reported-contract.
      ENDIF.
      IF NOT line_exists( lt_has_mat[ table_line = ls_ct-%data-ctuuid ] ).
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Debe tener al menos 1 material' ) ) TO reported-contract.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateglroleconsistency.

    TYPES ty_role_cat TYPE zreing_ct2_rec_a-role_category.
    TYPES: BEGIN OF ty_catalog_row,
             gl_role         TYPE zreing_gl_roles-gl_role,
             role_category   TYPE zreing_gl_roles-role_category,
             role_type       TYPE zreing_gl_roles-role_type,
             tax_type        TYPE zreing_gl_roles-tax_type,
             posting_context TYPE zreing_gl_roles-posting_context,
           END OF ty_catalog_row.
    TYPES: BEGIN OF ty_grp,
             role_type       TYPE zreing_gl_roles-role_type,
             tax_type        TYPE zreing_gl_roles-tax_type,
             posting_context TYPE zreing_gl_roles-posting_context,
           END OF ty_grp.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY contract BY \_materials
        FIELDS ( ctuuid matuuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_materials).

    CHECK lt_materials IS NOT INITIAL.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY material BY \_receivers
        FIELDS ( ctuuid matuuid rolecategory )
        WITH CORRESPONDING #( lt_materials )
      RESULT DATA(lt_receivers).

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY material BY \_gllines
        FIELDS ( ctuuid matuuid gluuid glrole )
        WITH CORRESPONDING #( lt_materials )
      RESULT DATA(lt_gl_lines).

    CHECK lt_receivers IS NOT INITIAL.
    CHECK lt_gl_lines  IS NOT INITIAL.

    DATA: lt_glrole_rng TYPE RANGE OF zreing_gl_roles-gl_role.
    LOOP AT lt_gl_lines ASSIGNING FIELD-SYMBOL(<gl_r>).
      READ TABLE lt_glrole_rng WITH KEY low = <gl_r>-%data-glrole TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <gl_r>-%data-glrole ) TO lt_glrole_rng.
      ENDIF.
    ENDLOOP.

    DATA: lt_catalog TYPE HASHED TABLE OF ty_catalog_row WITH UNIQUE KEY gl_role.
    SELECT gl_role, role_category, role_type, tax_type, posting_context
      FROM zreing_gl_roles
      WHERE gl_role IN @lt_glrole_rng
      INTO TABLE @lt_catalog.

    DATA: lt_recv_cats TYPE SORTED TABLE OF ty_role_cat WITH UNIQUE KEY table_line,
          lt_groups    TYPE SORTED TABLE OF ty_grp
                       WITH UNIQUE KEY role_type tax_type posting_context,
          lt_grp_cats  TYPE SORTED TABLE OF ty_role_cat WITH UNIQUE KEY table_line,
          lt_reported  TYPE HASHED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    DO lines( lt_materials ) TIMES.
      ASSIGN lt_materials[ sy-index ] TO FIELD-SYMBOL(<mat>).

      CLEAR: lt_recv_cats, lt_groups.

      LOOP AT lt_receivers ASSIGNING FIELD-SYMBOL(<recv>).
        IF <recv>-%data-ctuuid  = <mat>-%data-ctuuid
        AND <recv>-%data-matuuid = <mat>-%data-matuuid.
          CHECK <recv>-%data-rolecategory IS NOT INITIAL.
          IF NOT line_exists( lt_recv_cats[ table_line = <recv>-%data-rolecategory ] ).
            INSERT <recv>-%data-rolecategory INTO TABLE lt_recv_cats.
          ENDIF.
        ENDIF.
      ENDLOOP.

      CHECK lines( lt_recv_cats ) >= 2.

      DATA(lv_any_explicit) = abap_false.
      LOOP AT lt_gl_lines ASSIGNING FIELD-SYMBOL(<gl_c>).
        IF <gl_c>-%data-ctuuid  = <mat>-%data-ctuuid
        AND <gl_c>-%data-matuuid = <mat>-%data-matuuid.
          DATA(ls_c) = VALUE #( lt_catalog[ gl_role = <gl_c>-%data-glrole ] OPTIONAL ).
          IF ls_c-role_category IS NOT INITIAL.
            lv_any_explicit = abap_true.
            EXIT.
          ENDIF.
        ENDIF.
      ENDLOOP.

      CHECK lv_any_explicit = abap_true.

      LOOP AT lt_gl_lines ASSIGNING FIELD-SYMBOL(<gl_g>).
        IF <gl_g>-%data-ctuuid  = <mat>-%data-ctuuid
        AND <gl_g>-%data-matuuid = <mat>-%data-matuuid.
          DATA(ls_g) = VALUE #( lt_catalog[ gl_role = <gl_g>-%data-glrole ] OPTIONAL ).
          CHECK ls_g-role_category IS NOT INITIAL.
          IF NOT line_exists( lt_groups[ role_type       = ls_g-role_type
                                         tax_type        = ls_g-tax_type
                                         posting_context = ls_g-posting_context ] ).
            INSERT VALUE #( role_type       = ls_g-role_type
                            tax_type        = ls_g-tax_type
                            posting_context = ls_g-posting_context ) INTO TABLE lt_groups.
          ENDIF.
        ENDIF.
      ENDLOOP.

      DO lines( lt_groups ) TIMES.
        ASSIGN lt_groups[ sy-index ] TO FIELD-SYMBOL(<grp>).

        CLEAR lt_grp_cats.

        LOOP AT lt_gl_lines ASSIGNING FIELD-SYMBOL(<gl_gc>).
          IF <gl_gc>-%data-ctuuid  = <mat>-%data-ctuuid
          AND <gl_gc>-%data-matuuid = <mat>-%data-matuuid.
            DATA(ls_gc) = VALUE #( lt_catalog[ gl_role = <gl_gc>-%data-glrole ] OPTIONAL ).
            IF ls_gc-role_category IS NOT INITIAL
            AND ls_gc-role_type       = <grp>-role_type
            AND ls_gc-tax_type        = <grp>-tax_type
            AND ls_gc-posting_context = <grp>-posting_context.
              IF NOT line_exists( lt_grp_cats[ table_line = ls_gc-role_category ] ).
                INSERT ls_gc-role_category INTO TABLE lt_grp_cats.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.

        DATA(lv_incomplete) = abap_false.
        LOOP AT lt_recv_cats ASSIGNING FIELD-SYMBOL(<rcat>).
          IF NOT line_exists( lt_grp_cats[ table_line = <rcat> ] ).
            lv_incomplete = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.

        CHECK lv_incomplete = abap_true.

        LOOP AT lt_gl_lines ASSIGNING FIELD-SYMBOL(<gl_e>).
          IF <gl_e>-%data-ctuuid  = <mat>-%data-ctuuid
          AND <gl_e>-%data-matuuid = <mat>-%data-matuuid.
            DATA(ls_e) = VALUE #( lt_catalog[ gl_role = <gl_e>-%data-glrole ] OPTIONAL ).
            IF ls_e-role_category IS NOT INITIAL
            AND ls_e-role_type       = <grp>-role_type
            AND ls_e-tax_type        = <grp>-tax_type
            AND ls_e-posting_context = <grp>-posting_context.
              IF line_exists( lt_reported[ table_line = <gl_e>-%data-gluuid ] ).
                CONTINUE.
              ENDIF.
              INSERT <gl_e>-%data-gluuid INTO TABLE lt_reported.
              APPEND VALUE #( %tky = <gl_e>-%tky ) TO failed-gl.
              APPEND VALUE #(
                %tky            = <gl_e>-%tky
                %element-glrole = if_abap_behv=>mk-on
                %msg            = new_message_with_text(
                  severity = if_abap_behv_message=>severity-error
                  text     = |Combinacion tipo/impuesto/contexto incompleta: falta la categoria correspondiente| )
              ) TO reported-gl.
            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDDO.

    ENDDO.

  ENDMETHOD.

  METHOD activatecontract.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctstatus <> 'BO'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Solo Borrador puede activarse' ) ) TO reported-contract.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = ls_ct-%tky ctstatus = 'AC' ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res (
      %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD inactivatecontract.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctstatus <> 'AC'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Solo Activo puede inactivarse' ) ) TO reported-contract.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = ls_ct-%tky ctstatus = 'IN' ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res (
      %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD reactivatecontract.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctstatus <> 'IN'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Solo Inactivo puede reactivarse' ) ) TO reported-contract.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = ls_ct-%tky ctstatus = 'AC' ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res (
      %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD archivecontract.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctstatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-ctstatus <> 'IN'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-contract.
        APPEND VALUE #( %tky = ls_ct-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Solo Inactivo puede archivarse' ) ) TO reported-contract.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = ls_ct-%tky ctstatus = 'AR' ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( ctstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res (
      %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD uploadreceivers.
    DATA(ls_key)      = keys[ 1 ].
    DATA(lv_ct_uuid)  = ls_key-%tky-ctuuid.
    DATA(lv_mat_uuid) = ls_key-%param-matuuid.

    " --- Decodificar Base64 -> xstring ---
    DATA lv_xcontent TYPE xstring.
    TRY.
        lv_xcontent = xco_cp=>string( ls_key-%param-filecontent
          )->as_xstring( xco_cp_binary=>text_encoding->base64 )->value.
      CATCH cx_root INTO DATA(lx_b64).
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |Error al decodificar: { lx_b64->get_text( ) }| ) )
          TO reported-contract.
        RETURN.
    ENDTRY.

    IF lv_xcontent IS INITIAL.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'El contenido del archivo está vacío.' ) )
        TO reported-contract.
      RETURN.
    ENDIF.

    " --- Parsear y validar ---
    DATA(lo_hdl) = NEW zcl_reing_ct_recv_upload_hdl( ).
    DATA(ls_imp) = lo_hdl->import_file(
      iv_ct_uuid      = lv_ct_uuid
      iv_mat_uuid     = lv_mat_uuid
      iv_file_content = lv_xcontent ).

    IF ls_imp-aborted = abap_true.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = ls_imp-abort_reason ) )
        TO reported-contract.
      RETURN.
    ENDIF.

    LOOP AT ls_imp-results INTO DATA(ls_res).
      CASE ls_res-status.
        WHEN 'E'.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = ls_res-message ) )
            TO reported-contract.
        WHEN 'W'.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-warning
                            text     = ls_res-message ) )
            TO reported-contract.
      ENDCASE.
    ENDLOOP.

    DATA lv_has_errors TYPE abap_bool VALUE abap_false.
    LOOP AT ls_imp-results INTO DATA(ls_err) WHERE status = 'E'.
      lv_has_errors = abap_true.
      EXIT.
    ENDLOOP.
    IF lv_has_errors = abap_true OR ls_imp-create_lines IS INITIAL.
      RETURN.
    ENDIF.

    " --- Crear Receivers ---
    DATA lt_create TYPE TABLE FOR CREATE zi_reingctcontract2\\material\_receivers.
    DATA ls_row    LIKE LINE OF lt_create.
    DATA lt_tgt    LIKE ls_row-%target.
    DATA lv_cnt    TYPE i VALUE 0.

    LOOP AT ls_imp-create_lines INTO DATA(ls_line).
      lv_cnt += 1.
      APPEND VALUE #(
        %cid         = |RECV_UPLOAD_{ lv_cnt }|
        %is_draft    = ls_key-%is_draft
        recbukrs     = ls_line-rec_bukrs
        prctr        = ls_line-prctr
        country      = ls_line-country
        campana      = ls_line-campana
        rolecategory = ls_line-role_category
        allocation   = ls_line-allocation ) TO lt_tgt.
    ENDLOOP.

    APPEND VALUE #(
      %key-ctuuid  = lv_ct_uuid
      %key-matuuid = lv_mat_uuid
      %is_draft    = ls_key-%is_draft
      %target      = lt_tgt ) TO lt_create.

    MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2
        CREATE BY \_receivers
        FIELDS ( recbukrs prctr country campana rolecategory allocation )
        WITH lt_create
      REPORTED DATA(lt_rep)
      FAILED   DATA(lt_fail)
      MAPPED   DATA(lt_map).

    " --- Mensaje de resumen (una sola linea de exito, no una por fila) ---
    APPEND VALUE #( %tky = ls_key-%tky
                    %msg = new_message_with_text(
                      severity = if_abap_behv_message=>severity-success
                      text     = |{ lines( ls_imp-create_lines ) } sociedades receptoras importadas correctamente.| ) )
      TO reported-contract.

    " --- Resultado: devolver el Contract ($self) ---
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).

    result = VALUE #( FOR ls IN lt_res
                      ( %tky   = ls-%tky
                        %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.



  METHOD uploadgllines.
    DATA(ls_key)      = keys[ 1 ].
    DATA(lv_ct_uuid)  = ls_key-%tky-ctuuid.
    DATA(lv_mat_uuid) = ls_key-%param-matuuid.

    " --- Decodificar Base64 -> xstring ---
    DATA lv_xcontent TYPE xstring.
    TRY.
        lv_xcontent = xco_cp=>string( ls_key-%param-filecontent
          )->as_xstring( xco_cp_binary=>text_encoding->base64 )->value.
      CATCH cx_root INTO DATA(lx_b64).
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |Error al decodificar: { lx_b64->get_text( ) }| ) )
          TO reported-contract.
        RETURN.
    ENDTRY.

    IF lv_xcontent IS INITIAL.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'El contenido del archivo está vacío.' ) )
        TO reported-contract.
      RETURN.
    ENDIF.

    " --- Parsear y validar ---
    DATA(lo_hdl) = NEW zcl_reing_ct_gl_upload_hdl( ).
    DATA(ls_imp) = lo_hdl->import_file(
      iv_ct_uuid      = lv_ct_uuid
      iv_mat_uuid     = lv_mat_uuid
      iv_file_content = lv_xcontent ).

    IF ls_imp-aborted = abap_true.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = ls_imp-abort_reason ) )
        TO reported-contract.
      RETURN.
    ENDIF.

    LOOP AT ls_imp-results INTO DATA(ls_res).
      CASE ls_res-status.
        WHEN 'E'.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = ls_res-message ) )
            TO reported-contract.
        WHEN 'W'.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-warning
                            text     = ls_res-message ) )
            TO reported-contract.
      ENDCASE.
    ENDLOOP.

    DATA lv_has_errors TYPE abap_bool VALUE abap_false.
    LOOP AT ls_imp-results INTO DATA(ls_err) WHERE status = 'E'.
      lv_has_errors = abap_true.
      EXIT.
    ENDLOOP.
    IF lv_has_errors = abap_true OR ls_imp-create_lines IS INITIAL.
      RETURN.
    ENDIF.

    " --- Crear Lineas GL ---
    DATA lt_create TYPE TABLE FOR CREATE zi_reingctcontract2\\material\_gllines.
    DATA ls_row    LIKE LINE OF lt_create.
    DATA lt_tgt    LIKE ls_row-%target.
    DATA lv_cnt    TYPE i VALUE 0.

    LOOP AT ls_imp-create_lines INTO DATA(ls_line).
      lv_cnt += 1.
      APPEND VALUE #(
        %cid       = |GL_UPLOAD_{ lv_cnt }|
        %is_draft  = ls_key-%is_draft
        glrole     = ls_line-gl_role
        saknr      = ls_line-saknr
        reclassify = ls_line-reclassify ) TO lt_tgt.
    ENDLOOP.

    APPEND VALUE #(
      %key-ctuuid  = lv_ct_uuid
      %key-matuuid = lv_mat_uuid
      %is_draft    = ls_key-%is_draft
      %target      = lt_tgt ) TO lt_create.

    MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2
        CREATE BY \_gllines
        FIELDS ( glrole saknr  reclassify )
        WITH lt_create
      REPORTED DATA(lt_rep)
      FAILED   DATA(lt_fail)
      MAPPED   DATA(lt_map).

    " --- Estado = AC en las lineas creadas (CA-08 / RV-10) ---
    IF lt_map-gl IS NOT INITIAL.
      DATA lt_upd_st TYPE TABLE FOR UPDATE zi_reingctcontract2\\gl.
      LOOP AT lt_map-gl INTO DATA(ls_mapped).
        APPEND VALUE #(
          %tky      = ls_mapped-%tky
          glstatus  = 'AC' ) TO lt_upd_st.
      ENDLOOP.
      IF lt_upd_st IS NOT INITIAL.
        MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
          ENTITY zi_reingctgl2 UPDATE FIELDS ( glstatus )
          WITH lt_upd_st REPORTED DATA(lt_rep_st).
      ENDIF.
    ENDIF.

    " --- Mensaje de resumen (una sola linea de exito, no una por fila) ---
    APPEND VALUE #( %tky = ls_key-%tky
                    %msg = new_message_with_text(
                      severity = if_abap_behv_message=>severity-success
                      text     = |{ lines( ls_imp-create_lines ) } lineas GL importadas correctamente.| ) )
      TO reported-contract.

    " --- Resultado: devolver el Contract ($self) ---
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res_self).

    result = VALUE #( FOR ls IN lt_res_self
                      ( %tky   = ls-%tky
                        %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctmaterial2 IMPLEMENTATION.

  METHOD calctotalamount.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 FIELDS ( ctuuid amount )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_mats).
    DATA lt_uuids TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_mats INTO DATA(ls_mat_r).
      APPEND VALUE #(
        sign = 'I' option = 'EQ' low = ls_mat_r-%data-ctuuid ) TO lt_uuids.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_uuids COMPARING low.
    IF lt_uuids IS INITIAL. RETURN. ENDIF.
    DATA lt_totals TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    SELECT ct_uuid, SUM( amount ) AS amount FROM zreing_ct2_mat_a
      WHERE ct_uuid IN @lt_uuids
      GROUP BY ct_uuid
      INTO CORRESPONDING FIELDS OF TABLE @lt_totals.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctuuid )
      WITH VALUE #( FOR ls IN lt_uuids ( ctuuid = ls-low ) )
      RESULT DATA(lt_ct).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\contract.
    LOOP AT lt_ct INTO DATA(ls_ct).
      READ TABLE lt_totals INTO DATA(ls_tot)
        WITH KEY ct_uuid = ls_ct-%data-ctuuid.
      APPEND VALUE #(
        %tky        = ls_ct-%tky
        totalamount = COND #( WHEN sy-subrc = 0 THEN ls_tot-amount ELSE 0 )
      ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcontract2 UPDATE FIELDS ( totalamount )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setmatdesc.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 FIELDS ( matnr matdesc )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_mats).
    DATA lt_pending LIKE lt_mats.
    LOOP AT lt_mats INTO DATA(ls_m).
      IF ls_m-%data-matnr IS NOT INITIAL AND ls_m-%data-matdesc IS INITIAL.
        APPEND ls_m TO lt_pending.
      ENDIF.
    ENDLOOP.
    IF lt_pending IS INITIAL. RETURN. ENDIF.
    DATA lt_matnrs TYPE RANGE OF matnr.
    LOOP AT lt_pending INTO DATA(ls_p).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_p-%data-matnr ) TO lt_matnrs.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_matnrs COMPARING low.
    SELECT product, productdescription FROM i_productdescription
      WHERE product IN @lt_matnrs AND language = @sy-langu
      INTO TABLE @DATA(lt_descs).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\material.
    LOOP AT lt_pending INTO DATA(ls_pend).
      READ TABLE lt_descs INTO DATA(ls_desc)
        WITH KEY product = ls_pend-%data-matnr.
      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky    = ls_pend-%tky
          matdesc = ls_desc-productdescription ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctmaterial2 UPDATE FIELDS ( matdesc )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setmatwaers.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 FIELDS ( ctuuid waers )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_mats).
    DATA lt_new LIKE lt_mats.
    LOOP AT lt_mats INTO DATA(ls_m).
      IF ls_m-%data-waers IS INITIAL.
        APPEND ls_m TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.
    DATA lt_range_ct TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-ctuuid ) TO lt_range_ct.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct COMPARING low.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctuuid waers )
      WITH VALUE #( FOR ls IN lt_range_ct ( ctuuid = ls-low ) )
      RESULT DATA(lt_ct).
    DATA lt_waers TYPE HASHED TABLE OF zreing_ct2_a
      WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-waers IS NOT INITIAL.
        INSERT VALUE zreing_ct2_a(
          ct_uuid = ls_ct-%data-ctuuid
          waers   = ls_ct-%data-waers ) INTO TABLE lt_waers.
      ENDIF.
    ENDLOOP.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\material.
    LOOP AT lt_new INTO DATA(ls_upd).
      READ TABLE lt_waers INTO DATA(ls_w)
        WITH TABLE KEY ct_uuid = ls_upd-%data-ctuuid.
      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky  = ls_upd-%tky
          waers = ls_w-waers ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctmaterial2 UPDATE FIELDS ( waers )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD validatematnr.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 FIELDS ( matnr )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_mats).
    LOOP AT lt_mats INTO DATA(ls_mat).
      IF ls_mat-%data-matnr IS INITIAL.
        APPEND VALUE #( %tky = ls_mat-%tky ) TO failed-material.
        APPEND VALUE #( %tky = ls_mat-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'El codigo de material es obligatorio' ) ) TO reported-material.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_receivers
        FIELDS ( ctuuid matuuid recbukrs )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_receivers).

    DATA lt_has_recv TYPE HASHED TABLE OF sysuuid_x16
      WITH UNIQUE KEY table_line.
    LOOP AT lt_receivers INTO DATA(ls_r).
      TRY.
          INSERT ls_r-%data-matuuid INTO TABLE lt_has_recv.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.

    result = VALUE #(
      FOR ls IN keys (
        %tky             = ls-%tky
        %assoc-_optypes  = COND #(
          WHEN line_exists( lt_has_recv[ table_line = ls-%key-matuuid ] )
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctoptype2 IMPLEMENTATION.

  METHOD numberoprates.
    " V001 (CC) - #111: early numbering handles generated and manual create-by-association.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY OpType
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum )
        WITH CORRESPONDING #( entities )
      RESULT DATA(lt_options).
    SORT lt_options BY %is_draft ctuuid matuuid optype opuuid.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY OpType BY \_OpRates
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum bukrsrecv )
        WITH CORRESPONDING #( entities ) RESULT DATA(lt_existing_rates).
    SORT lt_existing_rates BY %is_draft ctuuid matuuid optype opuuid bukrsrecv opinstancenum.

    " V001 (CC) - #111 ATC: resolve each parent once and process a flat receiver list.
    DATA ls_entity LIKE LINE OF entities.
    TYPES: BEGIN OF ty_rate_request,
             option   LIKE LINE OF lt_options,
             is_draft LIKE ls_entity-%is_draft,
             resolved TYPE abap_bool,
             target   LIKE LINE OF ls_entity-%target,
           END OF ty_rate_request.
    TYPES tt_rate_request TYPE STANDARD TABLE OF ty_rate_request WITH EMPTY KEY.
    DATA lt_requests TYPE tt_rate_request.

    LOOP AT entities INTO ls_entity.
      READ TABLE lt_options INTO DATA(ls_option)
        WITH KEY %is_draft = ls_entity-%is_draft
                 ctuuid = ls_entity-ctuuid
                 matuuid = ls_entity-matuuid
                 optype = ls_entity-optype
                 opuuid = ls_entity-opuuid
        BINARY SEARCH.
      DATA(lv_resolved) = xsdbool( sy-subrc = 0 AND ls_option-opinstancenum IS NOT INITIAL ).
      APPEND LINES OF VALUE tt_rate_request(
        FOR ls_child IN ls_entity-%target
        ( option = ls_option is_draft = ls_entity-%is_draft
          resolved = lv_resolved target = ls_child ) ) TO lt_requests.
    ENDLOOP.

    LOOP AT lt_requests INTO DATA(ls_request).
      ls_option = ls_request-option.
      DATA(ls_target) = ls_request-target.
      IF ls_request-resolved = abap_false.
        APPEND VALUE #( %cid = ls_target-%cid %is_draft = ls_request-is_draft ) TO failed-oprate.
        APPEND VALUE #(
          %cid = ls_target-%cid %is_draft = ls_request-is_draft
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'No se pudo resolver la instancia de la operacion para la tasa manual' ) ) TO reported-oprate.
        CONTINUE.
      ENDIF.
      READ TABLE lt_existing_rates INTO DATA(ls_existing_rate)
        WITH KEY %is_draft = ls_request-is_draft
                 ctuuid = ls_option-ctuuid matuuid = ls_option-matuuid
                 optype = ls_option-optype opuuid = ls_option-opuuid
                 bukrsrecv = ls_target-bukrsrecv BINARY SEARCH.
      IF ( sy-subrc = 0 AND ls_existing_rate-opinstancenum <> ls_option-opinstancenum )
        OR ( ls_target-opinstancenum IS NOT INITIAL
          AND ls_target-opinstancenum <> ls_option-opinstancenum ).
        " Preserve existing keys/amounts; inconsistent legacy rates require explicit regularization.
        APPEND VALUE #( %cid = ls_target-%cid %is_draft = ls_request-is_draft ) TO failed-oprate.
        APPEND VALUE #(
          %cid = ls_target-%cid %is_draft = ls_request-is_draft
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'La tasa tiene una instancia inconsistente; regularice los datos antes de crearla' ) ) TO reported-oprate.
        CONTINUE.
      ENDIF.
      APPEND VALUE #(
        %cid = ls_target-%cid %is_draft = ls_request-is_draft
        ctuuid = ls_option-ctuuid matuuid = ls_option-matuuid
        optype = ls_option-optype opuuid = ls_option-opuuid
        opinstancenum = ls_option-opinstancenum bukrsrecv = ls_target-bukrsrecv ) TO mapped-oprate.
    ENDLOOP.
  ENDMETHOD.


  METHOD determineopinstancenum.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 FIELDS ( ctuuid matuuid optype opinstancenum )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).

    "-- Separar: D y NC no calculan MAX, copian del padre
    "-- Solo procesar independientes (no D ni NC)
    DATA lt_new_opts LIKE lt_opts.
    LOOP AT lt_opts INTO DATA(ls_opt).
      IF ls_opt-%data-opinstancenum = '000'
        AND ls_opt-%data-optype <> 'D'
        AND ls_opt-%data-optype <> 'NC'.
        APPEND ls_opt TO lt_new_opts.
      ENDIF.
    ENDLOOP.

    IF lt_new_opts IS INITIAL. RETURN. ENDIF.

    DATA lt_range_ct  TYPE RANGE OF sysuuid_x16.
    DATA lt_range_mat TYPE RANGE OF sysuuid_x16.
    DATA lt_range_op  TYPE RANGE OF zreing_ct2_opt_a-op_type.
    LOOP AT lt_new_opts INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-ctuuid )  TO lt_range_ct.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-matuuid ) TO lt_range_mat.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-optype )  TO lt_range_op.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct  COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_mat COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_op  COMPARING low.

    TYPES: BEGIN OF ty_max,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             maxnum   TYPE zreing_ct2_opt_a-op_instance_num,
           END OF ty_max.
    DATA lt_maxnums TYPE HASHED TABLE OF ty_max
      WITH UNIQUE KEY ct_uuid mat_uuid op_type.

    SELECT ct_uuid, mat_uuid, op_type,
           MAX( op_instance_num ) AS maxnum
      FROM zreing_ct2_opt_a
      WHERE ct_uuid  IN @lt_range_ct
        AND mat_uuid IN @lt_range_mat
        AND op_type  IN @lt_range_op
      GROUP BY ct_uuid, mat_uuid, op_type
      INTO TABLE @DATA(lt_raw_a).

    LOOP AT lt_raw_a INTO DATA(ls_a).
      INSERT VALUE ty_max(
        ct_uuid  = ls_a-ct_uuid
        mat_uuid = ls_a-mat_uuid
        op_type  = ls_a-op_type
        maxnum   = ls_a-maxnum ) INTO TABLE lt_maxnums.
    ENDLOOP.

    SELECT ctuuid, matuuid, optype,
           MAX( opinstancenum ) AS maxnum
      FROM zreing_ct2_opt_d
      WHERE ctuuid  IN @lt_range_ct
        AND matuuid IN @lt_range_mat
        AND optype  IN @lt_range_op
      GROUP BY ctuuid, matuuid, optype
      INTO TABLE @DATA(lt_raw_d).

    LOOP AT lt_raw_d INTO DATA(ls_d).
      READ TABLE lt_maxnums INTO DATA(ls_m)
        WITH TABLE KEY
          ct_uuid  = ls_d-ctuuid
          mat_uuid = ls_d-matuuid
          op_type  = ls_d-optype.
      IF sy-subrc = 0.
        IF ls_d-maxnum > ls_m-maxnum.
          ls_m-maxnum = ls_d-maxnum.
          MODIFY TABLE lt_maxnums FROM ls_m.
        ENDIF.
      ELSE.
        INSERT VALUE ty_max(
          ct_uuid  = ls_d-ctuuid
          mat_uuid = ls_d-matuuid
          op_type  = ls_d-optype
          maxnum   = ls_d-maxnum ) INTO TABLE lt_maxnums.
      ENDIF.
    ENDLOOP.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    LOOP AT lt_new_opts INTO DATA(ls_upd).
      READ TABLE lt_maxnums INTO DATA(ls_mx)
        WITH TABLE KEY
          ct_uuid  = ls_upd-%data-ctuuid
          mat_uuid = ls_upd-%data-matuuid
          op_type  = ls_upd-%data-optype.
      APPEND VALUE #(
        %tky          = ls_upd-%tky
        opinstancenum = COND #( WHEN sy-subrc = 0
                                THEN ls_mx-maxnum + 1
                                ELSE 1 )
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 UPDATE FIELDS ( opinstancenum )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.

  ENDMETHOD.

  METHOD autocreatelinkedoptype.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opuuid deferfrom deferto
                 exchratetype waers disttype installments opinstancenum parentinstanceid )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).

    "-- Filtrar solo A y F
    DATA lt_relevant LIKE lt_opts.
    LOOP AT lt_opts INTO DATA(ls_o).
      IF ls_o-%data-optype = 'A' OR ls_o-%data-optype = 'F'.
        APPEND ls_o TO lt_relevant.
      ENDIF.
    ENDLOOP.
    IF lt_relevant IS INITIAL. RETURN. ENDIF.

    " Begin Mod 31.08.2026 EXT_AGFAGINA - hijo duplicado y con instancia errada.
    " Antes se resolvia la instancia del padre y la existencia del hijo con tres
    " SELECT a ZREING_CT2_OPT_A / ZREING_CT2_OPT_D, o sea contra lo PERSISTIDO.
    " Cuando el padre se crea en el mismo ciclo de determinacion eso fallaba:
    "   1) el hijo creado en el buffer no figura aun en la draft, el chequeo de
    "      existencia no lo veia y se creaba una segunda vez;
    "   2) la instancia del padre tampoco estaba, se caia al default '001' y el
    "      hijo nacia con la instancia equivocada.
    " Observado en TS4: un F instancia 003 genero dos NC instancia 001.
    " Era un defecto preexistente pero quedaba tapado: sin tipo de cambio por
    " defecto, el CONTINUE de mas abajo cortaba antes de crear nada.
    " Ahora se leen los tipos de operacion del material desde el BUFFER, que si
    " incluye lo creado en este mismo ciclo.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_optypes
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum parentinstanceid )
        WITH VALUE #( FOR ls_m IN lt_relevant
          ( %is_draft    = ls_m-%is_draft
            %key-ctuuid  = ls_m-%data-ctuuid
            %key-matuuid = ls_m-%data-matuuid ) )
      RESULT DATA(lt_all_opts).

    TYPES: BEGIN OF ty_exist,
             ctuuid        TYPE sysuuid_x16,
             matuuid       TYPE sysuuid_x16,
             optype        TYPE zreing_ct2_opt_a-op_type,
             opinstancenum TYPE zreing_ct2_opt_a-op_instance_num,
             opuuid        TYPE sysuuid_x16,
             parentinstanceid TYPE sysuuid_x16,
           END OF ty_exist.
    DATA lt_exist TYPE HASHED TABLE OF ty_exist
      WITH UNIQUE KEY ctuuid matuuid optype opinstancenum.

    LOOP AT lt_all_opts INTO DATA(ls_ao).
      TRY.
          INSERT VALUE ty_exist(
            ctuuid        = ls_ao-%data-ctuuid
            matuuid       = ls_ao-%data-matuuid
            optype        = ls_ao-%data-optype
            opinstancenum = ls_ao-%data-opinstancenum
            opuuid        = ls_ao-%data-opuuid
            parentinstanceid = ls_ao-%data-parentinstanceid ) INTO TABLE lt_exist.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.
    " End Mod 31.08.2026 EXT_AGFAGINA

    " Begin Mod 01.09.2026 EXT_AGFAGINA - el tipo de cambio del hijo sale del
    " catalogo. Antes se copiaba del padre (y para A se hardcodeaba 'H'), asi que
    " el NC siempre terminaba con el tipo de cambio del F en lugar del que define
    " ZREING_OP_TYPE_C.DEFAULT_EXCH_RATE_TYPE para el propio NC.
    " La ET (BR-CT-04) pide justamente que se lea del catalogo, sin hardcodeo.
    SELECT op_type, default_exch_rate_type
      FROM zreing_op_type_c
      WHERE parent_type <> @space
        AND active      = @abap_true
      INTO TABLE @DATA(lt_cfg_child).
    " End Mod 01.09.2026 EXT_AGFAGINA

    DATA lt_create TYPE TABLE FOR CREATE zi_reingctcontract2\\material\_optypes.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.

    LOOP AT lt_relevant INTO DATA(ls_opt).

      DATA(lv_linked) = SWITCH zreing_ct2_opt_a-op_type(
        ls_opt-%data-optype
        WHEN 'A' THEN 'D'
        WHEN 'F' THEN 'NC'
        ELSE '' ).

      IF lv_linked IS INITIAL. CONTINUE. ENDIF.

      "-- Para F/NC: esperar a que ExchRateType esté definido
      IF ls_opt-%data-optype = 'F' AND ls_opt-%data-exchratetype IS INITIAL.
        CONTINUE.
      ENDIF.

      " Begin Mod 01.09.2026 EXT_AGFAGINA - tipo de cambio del hijo desde el
      " catalogo, por el tipo del HIJO (no del padre). Si el catalogo no tiene
      " valor para ese tipo, se cae a heredar el del padre como antes.
      READ TABLE lt_cfg_child INTO DATA(ls_cfg_child)
        WITH KEY op_type = lv_linked.
      DATA(lv_exch) = COND zreing_ct2_opt_a-exch_rate_type(
        WHEN sy-subrc = 0 AND ls_cfg_child-default_exch_rate_type IS NOT INITIAL
        THEN ls_cfg_child-default_exch_rate_type
        ELSE ls_opt-%data-exchratetype ).
      " End Mod 01.09.2026 EXT_AGFAGINA

      " Begin Mod 31.08.2026 EXT_AGFAGINA - instancia tomada del propio padre.
      " La instancia ya viene en el READ inicial; no hay que ir a buscarla a la
      " draft. Si todavia esta en blanco, DetermineOpInstanceNum no corrio aun:
      " se sale y se espera al re-disparo por el trigger field OpInstanceNum, en
      " lugar de inventar '001' como hacia el codigo anterior.
      DATA(lv_inst) = ls_opt-%data-opinstancenum.
      IF lv_inst IS INITIAL OR lv_inst = '000'.
        CONTINUE.
      ENDIF.

      "-- Ya existe el hijo con esa instancia? (chequeo contra el buffer)
      READ TABLE lt_exist INTO DATA(ls_linked)
        WITH TABLE KEY
          ctuuid        = ls_opt-%data-ctuuid
          matuuid       = ls_opt-%data-matuuid
          optype        = lv_linked
          opinstancenum = lv_inst.

      IF sy-subrc = 0.
        " Begin Mod 01.09.2026 EXT_AGFAGINA - propagar los datos de devengamiento
        " al hijo ya existente. El hijo se crea junto con el padre, cuando el padre
        " todavia no tiene fechas ni distribucion cargadas, asi que nacia vacio y
        " nadie lo completaba despues. Ahora, cuando el padre recibe o cambia esos
        " campos, se los pasa al hijo.
        " El cronograma del hijo NO se copia linea por linea: al actualizarle
        " DeferFrom / DeferTo / DistType se dispara GenerateCronLines sobre el
        " propio hijo y lo genera con los mismos datos, que da el mismo resultado.
        APPEND VALUE #(
          %is_draft     = ls_opt-%is_draft
          %key-ctuuid   = ls_opt-%data-ctuuid
          %key-matuuid  = ls_opt-%data-matuuid
          %key-optype   = lv_linked
          %key-opuuid   = ls_linked-opuuid
          exchratetype  = lv_exch
          opinstancenum = lv_inst
          parentinstanceid = ls_opt-%data-opuuid
          deferfrom     = ls_opt-%data-deferfrom
          deferto       = ls_opt-%data-deferto
          disttype      = ls_opt-%data-disttype
          installments  = ls_opt-%data-installments
          waers         = ls_opt-%data-waers
        ) TO lt_update.
        " End Mod 01.09.2026 EXT_AGFAGINA
        CONTINUE.
      ENDIF.
      " End Mod 31.08.2026 EXT_AGFAGINA

      "-- No existe: crear
      APPEND VALUE #(
        %key-ctuuid  = ls_opt-%data-ctuuid
        %key-matuuid = ls_opt-%data-matuuid
        %is_draft    = ls_opt-%is_draft
        %target      = VALUE #( (
          %cid          = |LINKED{ ls_opt-%data-ctuuid
                           }{ ls_opt-%data-matuuid
                           }{ lv_linked
                           }{ ls_opt-%data-opuuid }|
          %is_draft     = ls_opt-%is_draft
          optype        = lv_linked
          deferfrom     = ls_opt-%data-deferfrom
          deferto       = ls_opt-%data-deferto
          exchratetype  = lv_exch
          waers         = ls_opt-%data-waers
          disttype      = ls_opt-%data-disttype
          installments  = ls_opt-%data-installments
          opinstancenum = lv_inst
          parentinstanceid = ls_opt-%data-opuuid ) )
      ) TO lt_create.

      " Begin Mod 31.08.2026 EXT_AGFAGINA - registrar el hijo recien planificado
      " para que otra vuelta dentro del mismo ciclo no lo vuelva a crear.
      TRY.
          INSERT VALUE ty_exist(
            ctuuid        = ls_opt-%data-ctuuid
            matuuid       = ls_opt-%data-matuuid
            optype        = lv_linked
            opinstancenum = lv_inst
            parentinstanceid = ls_opt-%data-opuuid ) INTO TABLE lt_exist.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
      " End Mod 31.08.2026 EXT_AGFAGINA

    ENDLOOP.

    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctmaterial2
          CREATE BY \_optypes
          FIELDS ( optype deferfrom deferto exchratetype
                   waers disttype installments opinstancenum parentinstanceid )
          WITH lt_create
        REPORTED DATA(lt_rep_c).
    ENDIF.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          UPDATE FIELDS ( exchratetype opinstancenum parentinstanceid
                          deferfrom deferto disttype installments waers )
          WITH lt_update
        REPORTED DATA(lt_rep_u).
    ENDIF.

  ENDMETHOD.

  METHOD setoptypewaers.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 FIELDS ( ctuuid matuuid waers )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).
    DATA lt_new LIKE lt_opts.
    LOOP AT lt_opts INTO DATA(ls_o).
      IF ls_o-%data-waers IS INITIAL.
        APPEND ls_o TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.
    DATA lt_range_ct TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-ctuuid ) TO lt_range_ct.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct COMPARING low.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2 FIELDS ( ctuuid waers )
      WITH VALUE #( FOR ls IN lt_range_ct ( ctuuid = ls-low ) )
      RESULT DATA(lt_ct).
    DATA lt_waers TYPE HASHED TABLE OF zreing_ct2_a
      WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-waers IS NOT INITIAL.
        INSERT VALUE zreing_ct2_a(
          ct_uuid = ls_ct-%data-ctuuid
          waers   = ls_ct-%data-waers ) INTO TABLE lt_waers.
      ENDIF.
    ENDLOOP.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    LOOP AT lt_new INTO DATA(ls_upd).
      READ TABLE lt_waers INTO DATA(ls_w)
        WITH TABLE KEY ct_uuid = ls_upd-%data-ctuuid.
      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky  = ls_upd-%tky
          waers = ls_w-waers ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 UPDATE FIELDS ( waers )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD validateoptypefields.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( optype deferfrom deferto disttype installments exchratetype )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).
    LOOP AT lt_opts INTO DATA(ls_opt).
      IF ls_opt-%data-optype <> 'A'. CONTINUE. ENDIF.
      IF ls_opt-%data-deferfrom IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-optype.
        APPEND VALUE #( %tky = ls_opt-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha Inicio Devengamiento es obligatoria' ) ) TO reported-optype.
      ENDIF.
      IF ls_opt-%data-deferto IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-optype.
        APPEND VALUE #( %tky = ls_opt-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha Fin Devengamiento es obligatoria' ) ) TO reported-optype.
      ENDIF.
      IF ls_opt-%data-disttype IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-optype.
        APPEND VALUE #( %tky = ls_opt-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Tipo de Distribucion es obligatorio' ) ) TO reported-optype.
      ENDIF.
      IF ls_opt-%data-exchratetype IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-optype.
        APPEND VALUE #( %tky = ls_opt-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Tipo de Cambio es obligatorio' ) ) TO reported-optype.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD calcinstallments.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opinstancenum disttype deferfrom deferto )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    LOOP AT lt_opts INTO DATA(ls_opt).
      IF ls_opt-%data-disttype <> 'L'. CONTINUE. ENDIF.
      IF ls_opt-%data-deferfrom IS INITIAL OR ls_opt-%data-deferto IS INITIAL. CONTINUE. ENDIF.
      IF ls_opt-%data-deferfrom >= ls_opt-%data-deferto. CONTINUE. ENDIF.
      DATA(lv_year_from)  = CONV i( ls_opt-%data-deferfrom(4) ).
      DATA(lv_month_from) = CONV i( ls_opt-%data-deferfrom+4(2) ).
      DATA(lv_year_to)    = CONV i( ls_opt-%data-deferto(4) ).
      DATA(lv_month_to)   = CONV i( ls_opt-%data-deferto+4(2) ).
      DATA(lv_installments) = ( lv_year_to - lv_year_from ) * 12
                              + ( lv_month_to - lv_month_from )
                              + 1.
      APPEND VALUE #(
        %tky         = ls_opt-%tky
        installments = lv_installments ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 UPDATE FIELDS ( installments )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( disttype optype )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).

    result = VALUE #(
      FOR ls IN lt_opts (
        %tky                = ls-%tky
        %field-installments = COND #(
          WHEN ls-%data-disttype = 'L' OR ls-%data-optype <> 'A'
          THEN if_abap_behv=>fc-f-read_only
          ELSE if_abap_behv=>fc-f-unrestricted )
        %assoc-_cron        = COND #(
          WHEN ls-%data-disttype = 'L'
          THEN if_abap_behv=>fc-o-disabled
          ELSE if_abap_behv=>fc-o-enabled )
        %field-exchratetype = if_abap_behv=>fc-f-unrestricted
        %field-deferfrom    = COND #(
          WHEN ls-%data-optype = 'A'
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )
        %field-deferto      = COND #(
          WHEN ls-%data-optype = 'A'
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )
        %field-disttype     = COND #(
          WHEN ls-%data-optype = 'A'
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )
        %field-waers        = COND #(
          WHEN ls-%data-optype = 'A'
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )
      ) ).
  ENDMETHOD.

  METHOD generatecronlines.
    " V001 (CC) - Devengo: regenerate only planned schedule rows.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum disttype deferfrom deferto )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts_all).

    DATA lt_opts_l LIKE lt_opts_all.
    LOOP AT lt_opts_all INTO DATA(ls_o_all).
      " V001 (CC) - #111: wait for numbering instead of creating instance 000.
      IF ls_o_all-%data-disttype  =  'L'
      AND ls_o_all-%data-opinstancenum IS NOT INITIAL
      AND ls_o_all-%data-deferfrom IS NOT INITIAL
      AND ls_o_all-%data-deferto   IS NOT INITIAL
      AND ls_o_all-%data-deferfrom <  ls_o_all-%data-deferto.
        APPEND ls_o_all TO lt_opts_l.
      ENDIF.
    ENDLOOP.
    IF lt_opts_l IS INITIAL. RETURN. ENDIF.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 BY \_cron
        ALL FIELDS
        WITH CORRESPONDING #( lt_opts_l )
      RESULT DATA(lt_cron_exist)
      FAILED DATA(lt_failed_read).

    TYPES: BEGIN OF ty_cron_key,
             ctuuid     TYPE sysuuid_x16,
             matuuid    TYPE sysuuid_x16,
             optype     TYPE zreing_ct2_crn_a-op_type,
             opuuid     TYPE sysuuid_x16,
             cronyear   TYPE zreing_ct2_crn_a-cron_year,
             cronmonth  TYPE zreing_ct2_crn_a-cron_month,
           END OF ty_cron_key.
    TYPES: BEGIN OF ty_desired,
             ctuuid     TYPE sysuuid_x16,
             matuuid    TYPE sysuuid_x16,
             optype     TYPE zreing_ct2_crn_a-op_type,
             opuuid     TYPE sysuuid_x16,
             cronyear   TYPE zreing_ct2_crn_a-cron_year,
             cronmonth  TYPE zreing_ct2_crn_a-cron_month,
             opinstancenum TYPE zreing_ct2_crn_a-op_instance_num,
             percentage TYPE zreing_ct2_crn_a-percentage,
           END OF ty_desired.
    DATA lt_existing_keys TYPE HASHED TABLE OF ty_cron_key
      WITH UNIQUE KEY ctuuid matuuid optype opuuid cronyear cronmonth.
    DATA lt_desired TYPE HASHED TABLE OF ty_desired
      WITH UNIQUE KEY ctuuid matuuid optype opuuid cronyear cronmonth.

    LOOP AT lt_cron_exist INTO DATA(ls_existing_key).
      INSERT VALUE ty_cron_key(
        ctuuid    = ls_existing_key-%data-ctuuid
        matuuid   = ls_existing_key-%data-matuuid
        optype    = ls_existing_key-%data-optype
        opuuid    = ls_existing_key-%data-opuuid
        cronyear  = ls_existing_key-%data-cronyear
        cronmonth = ls_existing_key-%data-cronmonth ) INTO TABLE lt_existing_keys.
    ENDLOOP.

    DATA lt_create     TYPE TABLE FOR CREATE zi_reingctcontract2\\optype\_cron.
    DATA ls_create     LIKE LINE OF lt_create.
    DATA lt_target     LIKE ls_create-%target.
    DATA lt_months     TYPE tt_month_days.
    DATA ls_month      TYPE ty_month_days.
    DATA ls_opt        TYPE STRUCTURE FOR READ RESULT zi_reingctcontract2\\optype.
    DATA lv_total_days TYPE i.
    DATA lv_lines      TYPE i.
    DATA lv_pct_acum   TYPE decfloat34.
    DATA lv_pct        TYPE decfloat34.

    LOOP AT lt_opts_l INTO ls_opt.
      lt_months = build_month_table(
        iv_from_y = CONV i( ls_opt-%data-deferfrom(4) )
        iv_from_m = CONV i( ls_opt-%data-deferfrom+4(2) )
        iv_from_d = CONV i( ls_opt-%data-deferfrom+6(2) )
        iv_to_y   = CONV i( ls_opt-%data-deferto(4) )
        iv_to_m   = CONV i( ls_opt-%data-deferto+4(2) )
        iv_to_d   = CONV i( ls_opt-%data-deferto+6(2) ) ).

      lv_total_days = REDUCE i(
        INIT s = 0
        FOR m IN lt_months
        NEXT s = s + m-days_in_period ).
      IF lv_total_days = 0. CONTINUE. ENDIF.

      lv_lines    = lines( lt_months ).
      lv_pct_acum = 0.
      CLEAR lt_target.

      DO lv_lines TIMES.
        ls_month = lt_months[ sy-index ].
        lv_pct = calcmonthpct(
          iv_days_month = ls_month-days_in_period
          iv_total_days = lv_total_days
          iv_is_last    = COND #( WHEN sy-index = lv_lines
                                  THEN abap_true ELSE abap_false )
          iv_pct_acum   = lv_pct_acum ).
        lv_pct_acum += lv_pct.

        INSERT VALUE ty_desired(
          ctuuid     = ls_opt-%data-ctuuid
          matuuid    = ls_opt-%data-matuuid
          optype     = ls_opt-%data-optype
          opuuid     = ls_opt-%data-opuuid
          cronyear   = CONV #( ls_month-year )
          cronmonth  = CONV #( ls_month-month )
          opinstancenum = ls_opt-%data-opinstancenum
          percentage = lv_pct ) INTO TABLE lt_desired.

        IF NOT line_exists( lt_existing_keys[
          ctuuid    = ls_opt-%data-ctuuid
          matuuid   = ls_opt-%data-matuuid
          optype    = ls_opt-%data-optype
          opuuid    = ls_opt-%data-opuuid
          cronyear  = CONV #( ls_month-year )
          cronmonth = CONV #( ls_month-month ) ] ).
          APPEND VALUE #(
            %cid       = |CRN{ ls_opt-%data-opuuid }{ ls_month-year }{ ls_month-month }|
            %is_draft  = ls_opt-%is_draft
            cronyear   = CONV #( ls_month-year )
            cronmonth  = CONV #( ls_month-month )
            opinstancenum = ls_opt-%data-opinstancenum
            percentage = lv_pct ) TO lt_target.
        ENDIF.
      ENDDO.

      IF lt_target IS NOT INITIAL.
        APPEND VALUE #(
          %key-ctuuid  = ls_opt-%data-ctuuid
          %key-matuuid = ls_opt-%data-matuuid
          %key-optype  = ls_opt-%data-optype
          %key-opuuid  = ls_opt-%data-opuuid
          %is_draft    = ls_opt-%is_draft
          %target      = lt_target ) TO lt_create.
      ENDIF.
    ENDLOOP.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\cron.
    DATA lt_delete TYPE TABLE FOR DELETE zi_reingctcontract2\\cron.
    LOOP AT lt_cron_exist INTO DATA(ls_existing).
      READ TABLE lt_desired INTO DATA(ls_desired)
        WITH TABLE KEY
          ctuuid    = ls_existing-%data-ctuuid
          matuuid   = ls_existing-%data-matuuid
          optype    = ls_existing-%data-optype
          opuuid    = ls_existing-%data-opuuid
          cronyear  = ls_existing-%data-cronyear
          cronmonth = ls_existing-%data-cronmonth.
      IF sy-subrc = 0.
        IF ls_existing-%data-cronstatus <> 'EX'
        AND ls_existing-%data-cronstatus <> 'CA'.
          APPEND VALUE #( %tky       = ls_existing-%tky
                          opinstancenum = ls_desired-opinstancenum
                          percentage = ls_desired-percentage ) TO lt_update.
        ENDIF.
      ELSEIF ls_existing-%data-cronstatus <> 'EX'
         AND ls_existing-%data-cronstatus <> 'CA'.
        APPEND VALUE #( %tky = ls_existing-%tky ) TO lt_delete.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcron2
          UPDATE FIELDS ( percentage opinstancenum )
          WITH lt_update
        REPORTED DATA(lt_rep_upd).
    ENDIF.
    IF lt_delete IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcron2
          DELETE FROM lt_delete
        REPORTED DATA(lt_rep_del).
    ENDIF.
    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          CREATE BY \_cron
            FIELDS ( cronyear cronmonth percentage opinstancenum )
            WITH lt_create
        REPORTED DATA(lt_rep_cr).
    ENDIF.
  ENDMETHOD.

  METHOD build_month_table.
    DATA lt_months TYPE tt_month_days.
    DATA(lv_cur_y) = iv_from_y.
    DATA(lv_cur_m) = iv_from_m.
    WHILE lv_cur_y < iv_to_y
       OR ( lv_cur_y = iv_to_y AND lv_cur_m <= iv_to_m ).
      DATA(lv_days_in_month) = SWITCH i( lv_cur_m
        WHEN 1 OR 3 OR 5 OR 7 OR 8 OR 10 OR 12 THEN 31
        WHEN 4 OR 6 OR 9 OR 11                  THEN 30
        WHEN 2 THEN
          COND i( WHEN lv_cur_y MOD 400 = 0 THEN 29
                  WHEN lv_cur_y MOD 100 = 0 THEN 28
                  WHEN lv_cur_y MOD 4   = 0 THEN 29
                  ELSE                           28 ) ).
      DATA(lv_day_start) = COND i(
        WHEN lv_cur_y = iv_from_y AND lv_cur_m = iv_from_m
        THEN iv_from_d ELSE 1 ).
      DATA(lv_day_end) = COND i(
        WHEN lv_cur_y = iv_to_y AND lv_cur_m = iv_to_m
        THEN iv_to_d ELSE lv_days_in_month ).
      APPEND VALUE ty_month_days(
        year           = lv_cur_y
        month          = lv_cur_m
        days_in_period = lv_day_end - lv_day_start + 1
      ) TO lt_months.
      lv_cur_m += 1.
      IF lv_cur_m > 12.
        lv_cur_m = 1.
        lv_cur_y += 1.
      ENDIF.
    ENDWHILE.
    rt_months = lt_months.
  ENDMETHOD.

  METHOD calcmonthpct.
    IF iv_is_last = abap_true.
      rv_pct = 100 - iv_pct_acum.
    ELSE.
      rv_pct = round( val = iv_days_month * 100 / iv_total_days
                      dec = 2 ).
    ENDIF.
  ENDMETHOD.

  METHOD syncoprates.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum exchratetype )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts_all).

    DATA lt_opts_m    LIKE lt_opts_all.
    DATA lt_opts_no_m LIKE lt_opts_all.
    LOOP AT lt_opts_all INTO DATA(ls_o_all).
      IF ls_o_all-%data-exchratetype = 'M'.
        APPEND ls_o_all TO lt_opts_m.
      ELSE.
        APPEND ls_o_all TO lt_opts_no_m.
      ENDIF.
    ENDLOOP.

    IF lt_opts_no_m IS NOT INITIAL.
      READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 BY \_oprates
          ALL FIELDS
          WITH CORRESPONDING #( lt_opts_no_m )
        RESULT DATA(lt_rates_del).
      IF lt_rates_del IS NOT INITIAL.
        MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
          ENTITY zi_reingctoprate2
            DELETE FROM VALUE #( FOR ls_rd IN lt_rates_del ( %tky = ls_rd-%tky ) )
          REPORTED DATA(lt_rep_del).
      ENDIF.
    ENDIF.

    " V001 (CC) - #111: create rates only after the exact option is numbered.
    DELETE lt_opts_m WHERE %data-opinstancenum IS INITIAL.
    IF lt_opts_m IS INITIAL. RETURN. ENDIF.

    DATA lt_range_mat TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_opts_m INTO DATA(ls_om_r) WHERE %is_draft = if_abap_behv=>mk-on.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_om_r-%data-matuuid )
        TO lt_range_mat.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_mat COMPARING low.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_receivers
        FIELDS ( ctuuid matuuid recbukrs )
        WITH VALUE #( FOR ls_om IN lt_opts_m
          ( %is_draft    = ls_om-%is_draft
            %key-ctuuid  = ls_om-%data-ctuuid
            %key-matuuid = ls_om-%data-matuuid ) )
      RESULT DATA(lt_receivers).

    TYPES: BEGIN OF ty_recv,
             ct_uuid   TYPE sysuuid_x16,
             mat_uuid  TYPE sysuuid_x16,
             rec_bukrs TYPE zreing_ct_o_r_a-bukrs_recv,
             is_draft  TYPE abap_bool,
           END OF ty_recv.
    DATA lt_recv_all TYPE SORTED TABLE OF ty_recv
      WITH NON-UNIQUE KEY ct_uuid mat_uuid.
    DATA lt_recv_keys TYPE HASHED TABLE OF ty_recv
      WITH UNIQUE KEY ct_uuid mat_uuid rec_bukrs.

    LOOP AT lt_receivers INTO DATA(ls_rv_eml).
      TRY.
          INSERT VALUE ty_recv(
            ct_uuid   = ls_rv_eml-%data-ctuuid
            mat_uuid  = ls_rv_eml-%data-matuuid
            rec_bukrs = ls_rv_eml-%data-recbukrs
            is_draft  = ls_rv_eml-%is_draft ) INTO TABLE lt_recv_keys.
          INSERT VALUE ty_recv(
            ct_uuid   = ls_rv_eml-%data-ctuuid
            mat_uuid  = ls_rv_eml-%data-matuuid
            rec_bukrs = ls_rv_eml-%data-recbukrs
            is_draft  = ls_rv_eml-%is_draft ) INTO TABLE lt_recv_all.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.

    " Keep the existing draft fallback scoped to draft options only.
    IF lt_range_mat IS NOT INITIAL.
    SELECT ctuuid, matuuid, recbukrs
      FROM zreing_ct2_rec_d
      WHERE matuuid IN @lt_range_mat
      INTO TABLE @DATA(lt_draft_recv).

    LOOP AT lt_draft_recv INTO DATA(ls_dr).
      TRY.
          INSERT VALUE ty_recv(
            ct_uuid   = ls_dr-ctuuid
            mat_uuid  = ls_dr-matuuid
            rec_bukrs = ls_dr-recbukrs
            is_draft  = abap_true ) INTO TABLE lt_recv_keys.
          INSERT VALUE ty_recv(
            ct_uuid   = ls_dr-ctuuid
            mat_uuid  = ls_dr-matuuid
            rec_bukrs = ls_dr-recbukrs
            is_draft  = abap_true ) INTO TABLE lt_recv_all.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.

    ENDIF.

    IF lt_recv_all IS INITIAL. RETURN. ENDIF.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 BY \_oprates
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum bukrsrecv )
        WITH CORRESPONDING #( lt_opts_m )
      RESULT DATA(lt_rates_exist).

    TYPES: BEGIN OF ty_rate_key,
             ct_uuid         TYPE sysuuid_x16,
             mat_uuid        TYPE sysuuid_x16,
             op_type         TYPE zreing_ct2_opt_a-op_type,
             op_uuid         TYPE sysuuid_x16,
             op_instance_num TYPE zreing_ct2_opt_a-op_instance_num,
             bukrs_recv      TYPE zreing_ct_o_r_a-bukrs_recv,
           END OF ty_rate_key.
    DATA lt_exist_hash TYPE HASHED TABLE OF ty_rate_key
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid op_instance_num bukrs_recv.
    LOOP AT lt_rates_exist INTO DATA(ls_re).
      INSERT VALUE ty_rate_key(
        ct_uuid         = ls_re-%data-ctuuid
        mat_uuid        = ls_re-%data-matuuid
        op_type         = ls_re-%data-optype
        op_uuid         = ls_re-%data-opuuid
        op_instance_num = ls_re-%data-opinstancenum
        bukrs_recv      = ls_re-%data-bukrsrecv ) INTO TABLE lt_exist_hash.
    ENDLOOP.

    TYPES: BEGIN OF ty_mat_range,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             idx_from TYPE i,
             idx_to   TYPE i,
           END OF ty_mat_range.
    DATA lt_mat_ranges TYPE HASHED TABLE OF ty_mat_range
      WITH UNIQUE KEY ct_uuid mat_uuid.
    DATA lv_prev_ct   TYPE sysuuid_x16.
    DATA lv_prev_mat  TYPE sysuuid_x16.
    DATA lv_from_idx  TYPE i VALUE 1.
    DATA lv_total_rcv TYPE i.
    DATA ls_rv_scan   TYPE ty_recv.
    lv_total_rcv = lines( lt_recv_all ).

    DO lv_total_rcv TIMES.
      ls_rv_scan = lt_recv_all[ sy-index ].
      IF ls_rv_scan-ct_uuid <> lv_prev_ct
        OR ls_rv_scan-mat_uuid <> lv_prev_mat.
        IF lv_prev_mat IS NOT INITIAL.
          INSERT VALUE ty_mat_range(
            ct_uuid  = lv_prev_ct
            mat_uuid = lv_prev_mat
            idx_from = lv_from_idx
            idx_to   = sy-index - 1 ) INTO TABLE lt_mat_ranges.
        ENDIF.
        lv_from_idx = sy-index.
        lv_prev_ct  = ls_rv_scan-ct_uuid.
        lv_prev_mat = ls_rv_scan-mat_uuid.
      ENDIF.
      IF sy-index = lv_total_rcv.
        INSERT VALUE ty_mat_range(
          ct_uuid  = ls_rv_scan-ct_uuid
          mat_uuid = ls_rv_scan-mat_uuid
          idx_from = lv_from_idx
          idx_to   = sy-index ) INTO TABLE lt_mat_ranges.
      ENDIF.
    ENDDO.

    DATA lt_create_opr TYPE TABLE FOR CREATE zi_reingctcontract2\\optype\_oprates.
    DATA ls_row_opr    LIKE LINE OF lt_create_opr.
    DATA lt_tgt_opr    LIKE ls_row_opr-%target.
    DATA ls_opt        TYPE STRUCTURE FOR READ RESULT zi_reingctcontract2\\optype.
    DATA ls_rv         TYPE ty_recv.
    DATA ls_range      TYPE ty_mat_range.
    DATA lv_cid        TYPE i.
    DATA lv_count      TYPE i.

    LOOP AT lt_opts_m INTO ls_opt.
      CLEAR lt_tgt_opr.
      lv_cid = 0.

      READ TABLE lt_mat_ranges INTO ls_range
        WITH TABLE KEY
          ct_uuid  = ls_opt-%data-ctuuid
          mat_uuid = ls_opt-%data-matuuid.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      lv_count = ls_range-idx_to - ls_range-idx_from + 1.

      DO lv_count TIMES.
        ls_rv = lt_recv_all[ ls_range-idx_from + sy-index - 1 ].

        READ TABLE lt_exist_hash TRANSPORTING NO FIELDS
          WITH TABLE KEY
            ct_uuid         = ls_opt-%data-ctuuid
            mat_uuid        = ls_opt-%data-matuuid
            op_type         = ls_opt-%data-optype
            op_uuid         = ls_opt-%data-opuuid
            op_instance_num = ls_opt-%data-opinstancenum
            bukrs_recv      = ls_rv-rec_bukrs.
        IF sy-subrc = 0. CONTINUE. ENDIF.

        lv_cid += 1.
        APPEND VALUE #(
          %cid           = |OPR{ ls_opt-%data-ctuuid
                           }{ ls_opt-%data-optype
                           }{ ls_opt-%data-opuuid
                           }{ ls_rv-rec_bukrs
                           }{ lv_cid }|
          %is_draft      = ls_opt-%is_draft
          bukrsrecv      = ls_rv-rec_bukrs
          opinstancenum  = ls_opt-%data-opinstancenum
          manualexchrate = 0 ) TO lt_tgt_opr.
      ENDDO.

      IF lt_tgt_opr IS INITIAL. CONTINUE. ENDIF.

      APPEND VALUE #(
        %key-ctuuid  = ls_opt-%data-ctuuid
        %key-matuuid = ls_opt-%data-matuuid
        %key-optype  = ls_opt-%data-optype
        %key-opuuid  = ls_opt-%data-opuuid
        %is_draft    = ls_opt-%is_draft
        %target      = lt_tgt_opr ) TO lt_create_opr.
    ENDLOOP.

    IF lt_create_opr IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          CREATE BY \_oprates
          FIELDS ( bukrsrecv manualexchrate opinstancenum )
          WITH lt_create_opr
        REPORTED DATA(lt_rep_cr).
    ENDIF.
  ENDMETHOD.

  METHOD validatemanualrates.
    " V001 (CC) - CT-01 (Brazil): keep active and draft contexts separate.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum exchratetype )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts).

    DATA lt_opts_m LIKE lt_opts.
    LOOP AT lt_opts INTO DATA(ls_o).
      IF ls_o-%data-exchratetype = 'M'.
        APPEND ls_o TO lt_opts_m.
      ENDIF.
    ENDLOOP.
    IF lt_opts_m IS INITIAL. RETURN. ENDIF.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 BY \_oprates
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum bukrsrecv manualexchrate )
        WITH CORRESPONDING #( lt_opts_m )
      RESULT DATA(lt_rates).

    TYPES: BEGIN OF ty_rate,
             ct_uuid          TYPE sysuuid_x16,
             is_draft         TYPE abp_behv_flag,
             mat_uuid         TYPE sysuuid_x16,
             op_type          TYPE zreing_ct2_opt_a-op_type,
             op_uuid          TYPE sysuuid_x16,
             op_instance_num  TYPE zreing_ct2_opt_a-op_instance_num,
             bukrs_recv       TYPE zreing_ct_o_r_a-bukrs_recv,
             manual_exch_rate TYPE zreing_ct_o_r_a-manual_exch_rate,
           END OF ty_rate.
    DATA lt_rates_sorted TYPE SORTED TABLE OF ty_rate
          WITH NON-UNIQUE KEY ct_uuid mat_uuid op_type op_uuid op_instance_num is_draft.
    LOOP AT lt_rates INTO DATA(ls_rt).
      INSERT VALUE ty_rate(
        ct_uuid          = ls_rt-%data-ctuuid
        is_draft         = ls_rt-%is_draft
        mat_uuid         = ls_rt-%data-matuuid
        op_type          = ls_rt-%data-optype
        op_uuid          = ls_rt-%data-opuuid
        op_instance_num  = ls_rt-%data-opinstancenum
        bukrs_recv       = ls_rt-%data-bukrsrecv
        manual_exch_rate = ls_rt-%data-manualexchrate ) INTO TABLE lt_rates_sorted.
    ENDLOOP.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_receivers
        FIELDS ( ctuuid matuuid recbukrs )
        WITH VALUE #( FOR ls_om IN lt_opts_m
          ( %key-ctuuid  = ls_om-%data-ctuuid
            %key-matuuid = ls_om-%data-matuuid
            %is_draft   = ls_om-%is_draft ) )
      RESULT DATA(lt_receivers).

    TYPES: BEGIN OF ty_recv_val,
             ct_uuid   TYPE sysuuid_x16,
             is_draft  TYPE abp_behv_flag,
             mat_uuid  TYPE sysuuid_x16,
             rec_bukrs TYPE zreing_ct_o_r_a-bukrs_recv,
           END OF ty_recv_val.
    DATA lt_recv_sorted TYPE SORTED TABLE OF ty_recv_val
      WITH NON-UNIQUE KEY ct_uuid mat_uuid is_draft.
    LOOP AT lt_receivers INTO DATA(ls_recv_v).
      INSERT VALUE ty_recv_val(
        ct_uuid   = ls_recv_v-%data-ctuuid
        is_draft  = ls_recv_v-%is_draft
        mat_uuid  = ls_recv_v-%data-matuuid
        rec_bukrs = ls_recv_v-%data-recbukrs ) INTO TABLE lt_recv_sorted.
    ENDLOOP.

    TYPES: BEGIN OF ty_mat_range_v,
             ct_uuid  TYPE sysuuid_x16,
             is_draft TYPE abp_behv_flag,
             mat_uuid TYPE sysuuid_x16,
             idx_from TYPE i,
             idx_to   TYPE i,
           END OF ty_mat_range_v.
    DATA lt_mat_ranges TYPE HASHED TABLE OF ty_mat_range_v
      WITH UNIQUE KEY ct_uuid mat_uuid is_draft.
    DATA lv_prev_ct  TYPE sysuuid_x16.
    DATA lv_prev_mat TYPE sysuuid_x16.
    DATA lv_prev_draft TYPE abp_behv_flag.
    DATA lv_from_idx TYPE i VALUE 1.
    DATA lv_total_rv TYPE i.
    DATA ls_rv_scan  TYPE ty_recv_val.
    lv_total_rv = lines( lt_recv_sorted ).

    DO lv_total_rv TIMES.
      ls_rv_scan = lt_recv_sorted[ sy-index ].
      IF ls_rv_scan-ct_uuid <> lv_prev_ct
        OR ls_rv_scan-mat_uuid <> lv_prev_mat
        OR ls_rv_scan-is_draft <> lv_prev_draft.
        IF lv_prev_mat IS NOT INITIAL.
          INSERT VALUE ty_mat_range_v(
            ct_uuid  = lv_prev_ct
            mat_uuid = lv_prev_mat
            is_draft = lv_prev_draft
            idx_from = lv_from_idx
            idx_to   = sy-index - 1 ) INTO TABLE lt_mat_ranges.
        ENDIF.
        lv_from_idx = sy-index.
        lv_prev_ct  = ls_rv_scan-ct_uuid.
        lv_prev_mat = ls_rv_scan-mat_uuid.
        lv_prev_draft = ls_rv_scan-is_draft.
      ENDIF.
      IF sy-index = lv_total_rv.
        INSERT VALUE ty_mat_range_v(
          ct_uuid  = ls_rv_scan-ct_uuid
          mat_uuid = ls_rv_scan-mat_uuid
          is_draft = ls_rv_scan-is_draft
          idx_from = lv_from_idx
          idx_to   = sy-index ) INTO TABLE lt_mat_ranges.
      ENDIF.
    ENDDO.

    DATA ls_opt_m  TYPE STRUCTURE FOR READ RESULT zi_reingctcontract2\\optype.
    DATA ls_rv_v   TYPE ty_recv_val.
    DATA ls_range  TYPE ty_mat_range_v.
    DATA lv_count  TYPE i.

    LOOP AT lt_opts_m INTO ls_opt_m.
      READ TABLE lt_mat_ranges INTO ls_range
        WITH TABLE KEY
          ct_uuid  = ls_opt_m-%data-ctuuid
          mat_uuid = ls_opt_m-%data-matuuid
          is_draft = ls_opt_m-%is_draft.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      lv_count = ls_range-idx_to - ls_range-idx_from + 1.

      DO lv_count TIMES.
        ls_rv_v = lt_recv_sorted[ ls_range-idx_from + sy-index - 1 ].

        READ TABLE lt_rates_sorted INTO DATA(ls_rate_cur)
          WITH KEY
            ct_uuid         = ls_opt_m-%data-ctuuid
            mat_uuid        = ls_opt_m-%data-matuuid
            op_type         = ls_opt_m-%data-optype
            op_uuid         = ls_opt_m-%data-opuuid
            op_instance_num = ls_opt_m-%data-opinstancenum
            is_draft        = ls_opt_m-%is_draft
            bukrs_recv      = ls_rv_v-rec_bukrs.

        IF sy-subrc <> 0 OR ls_rate_cur-manual_exch_rate = 0.
          APPEND VALUE #( %tky = ls_opt_m-%tky ) TO failed-optype.
          APPEND VALUE #( %tky = ls_opt_m-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = |Sociedad { ls_rv_v-rec_bukrs } sin tasa manual cargada| )
          ) TO reported-optype.
        ENDIF.
      ENDDO.
    ENDLOOP.
  ENDMETHOD.

  METHOD setoptypedescr.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( optype exchratetype )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts).

    IF lt_opts IS INITIAL. RETURN. ENDIF.

    DATA lt_range_optype    TYPE RANGE OF zreing_op_types-op_type.
    DATA lt_range_exchrate  TYPE RANGE OF zreing_exrt_type.

    LOOP AT lt_opts INTO DATA(ls_opt_r).
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_opt_r-%data-optype ) TO lt_range_optype.
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_opt_r-%data-exchratetype ) TO lt_range_exchrate.
    ENDLOOP.

    DELETE ADJACENT DUPLICATES FROM lt_range_optype   COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_exchrate COMPARING low.

    SELECT op_type, descr
      FROM zreing_op_types
      WHERE op_type IN @lt_range_optype
      INTO TABLE @DATA(lt_op_descr).

    SELECT exchratetype, exchratetypedesc
      FROM zi_reingexrttypevh
      WHERE exchratetype IN @lt_range_exchrate
      INTO TABLE @DATA(lt_exch_descr).

    DATA lt_update     TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    DATA lv_op_descr   TYPE zreing_op_types-descr.
    DATA lv_exch_descr TYPE string.

    LOOP AT lt_opts INTO DATA(ls_opt).
      READ TABLE lt_op_descr INTO DATA(ls_op)
        WITH KEY op_type = ls_opt-%data-optype.
      lv_op_descr = COND #( WHEN sy-subrc = 0 THEN ls_op-descr ELSE '' ).

      READ TABLE lt_exch_descr INTO DATA(ls_exch)
        WITH KEY exchratetype = ls_opt-%data-exchratetype.
      lv_exch_descr = COND #( WHEN sy-subrc = 0 THEN ls_exch-exchratetypedesc ELSE '' ).

      APPEND VALUE #(
        %tky                   = ls_opt-%tky
        optypedescr            = lv_op_descr
        exchratedescr          = CONV #( lv_exch_descr )
        %control-optypedescr   = if_abap_behv=>mk-on
        %control-exchratedescr = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          UPDATE FIELDS ( optypedescr exchratedescr )
          WITH lt_update
        REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setmeperiodoffsetdefault.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 FIELDS ( optype meperiodoffset )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    LOOP AT lt_opts INTO DATA(ls_opt).
      IF ls_opt-%data-meperiodoffset IS INITIAL.
        " Begin Mod 02.09.2026 EXT_AGFAGINA - default por tipo de operacion.
        " Definicion funcional (Rochelle, mail 01.09.2026): 00 para P y 01 para
        " todos los demas tipos. Antes se asignaba 00 a todos, con lo cual un F
        " nuevo leia el mes actual cuando le corresponde el anterior.
        " Viene de la unificacion del delta v2.0: los campos REF_PERIOD_OP_P y
        " REF_PERIOD_OP_F tenian defaults distintos (P = mes actual,
        " F = mes anterior) y al unificarse en ME_PERIOD_OFFSET esa distincion
        " se habia perdido. El usuario puede cambiarlo en pantalla.
        DATA(lv_offset) = COND zreing_ct2_opt_a-me_period_offset(
          WHEN ls_opt-%data-optype = 'P' THEN '00' ELSE '01' ).
        APPEND VALUE #( %tky = ls_opt-%tky
                        meperiodoffset = lv_offset ) TO lt_update.
        " End Mod 02.09.2026 EXT_AGFAGINA
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 UPDATE FIELDS ( meperiodoffset )
        WITH lt_update REPORTED DATA(lt_rep_def).
    ENDIF.
  ENDMETHOD.

  METHOD validatemeperiodoffset.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 FIELDS ( meperiodoffset )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts).
    LOOP AT lt_opts INTO DATA(ls_opt).
      IF ls_opt-%data-meperiodoffset <> '00' AND ls_opt-%data-meperiodoffset <> '01'.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-optype.
        APPEND VALUE #( %tky = ls_opt-%tky
          %element-meperiodoffset = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Offset de período inválido (debe ser 00 o 01)' ) ) TO reported-optype.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

    " Begin Mod 31.08.2026 EXT_AGFAGINA - issues 46 y 45 del tracker.
  " Aplica el tipo de cambio por defecto que el funcional configura por tipo de
  " operacion en ZREING_OP_TYPE_C (vista de mantenimiento SM30 ZREING_OP_TYP_CV).
  " Antes ningun punto del BO leia DEFAULT_EXCH_RATE_TYPE y el campo quedaba
  " vacio al crear. Solo completa cuando el usuario no informo un valor.
  " Efecto sobre el issue 45: AutoCreateLinkedOpType hace CONTINUE cuando F tiene
  " ExchRateType vacio, por eso el hijo NC tampoco se creaba. Al quedar el default
  " seteado, el trigger de field ExchRateType vuelve a disparar esa determinacion
  " y el hijo se crea.
  " El resto del BO de CT sigue leyendo el catalogo legacy ZREING_OP_TYPES
  " (descripciones y value helps); aqui se usa OP_TYPE_C porque es la unica de las
  " dos que tiene el campo. La consolidacion de ambos catalogos es CAT-01..07.
  METHOD setexchratetypedefault.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 FIELDS ( optype exchratetype )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_opts_ex).

    DATA lt_pending_ex LIKE lt_opts_ex.
    LOOP AT lt_opts_ex INTO DATA(ls_o_ex).
      IF ls_o_ex-%data-exchratetype IS INITIAL
        AND ls_o_ex-%data-optype IS NOT INITIAL.
        APPEND ls_o_ex TO lt_pending_ex.
      ENDIF.
    ENDLOOP.
    IF lt_pending_ex IS INITIAL. RETURN. ENDIF.

    DATA lt_range_op_ex TYPE RANGE OF zreing_ct2_opt_a-op_type.
    LOOP AT lt_pending_ex INTO DATA(ls_p_ex).
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_p_ex-%data-optype ) TO lt_range_op_ex.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_op_ex COMPARING low.

    SELECT op_type, default_exch_rate_type
      FROM zreing_op_type_c
      WHERE op_type IN @lt_range_op_ex
      INTO TABLE @DATA(lt_cfg_ex).

    DATA lt_update_ex TYPE TABLE FOR UPDATE zi_reingctcontract2\\optype.
    LOOP AT lt_pending_ex INTO DATA(ls_upd_ex).
      READ TABLE lt_cfg_ex INTO DATA(ls_cfg_ex)
        WITH KEY op_type = ls_upd_ex-%data-optype.
      IF sy-subrc = 0 AND ls_cfg_ex-default_exch_rate_type IS NOT INITIAL.
        APPEND VALUE #(
          %tky         = ls_upd_ex-%tky
          exchratetype = ls_cfg_ex-default_exch_rate_type ) TO lt_update_ex.
      ENDIF.
    ENDLOOP.

    IF lt_update_ex IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2 UPDATE FIELDS ( exchratetype )
        WITH lt_update_ex REPORTED DATA(lt_rep_ex).
    ENDIF.
  ENDMETHOD.
  " End Mod 31.08.2026 EXT_AGFAGINA

ENDCLASS.

CLASS lhc_zi_reingctgl2 IMPLEMENTATION.

  METHOD setglseq.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgl2 FIELDS ( ctuuid matuuid gluuid glseq )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_gl).
    DATA lt_new LIKE lt_gl.
    LOOP AT lt_gl INTO DATA(ls_gl).
      IF ls_gl-%data-glseq = '000'.
        APPEND ls_gl TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.
    DATA lt_range_ct  TYPE RANGE OF sysuuid_x16.
    DATA lt_range_mat TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-ctuuid )  TO lt_range_ct.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-matuuid ) TO lt_range_mat.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct  COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_mat COMPARING low.
    TYPES: BEGIN OF ty_max,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             maxseq   TYPE zreing_ct2_gl_a-gl_seq,
           END OF ty_max.
    DATA lt_max TYPE HASHED TABLE OF ty_max WITH UNIQUE KEY ct_uuid mat_uuid.
    SELECT ct_uuid, mat_uuid, MAX( gl_seq ) AS maxseq
      FROM zreing_ct2_gl_a
      WHERE ct_uuid  IN @lt_range_ct
        AND mat_uuid IN @lt_range_mat
      GROUP BY ct_uuid, mat_uuid
      INTO TABLE @DATA(lt_active).
    LOOP AT lt_active INTO DATA(ls_a).
      INSERT VALUE ty_max( ct_uuid = ls_a-ct_uuid mat_uuid = ls_a-mat_uuid maxseq = ls_a-maxseq )
        INTO TABLE lt_max.
    ENDLOOP.
    SELECT ctuuid, matuuid, MAX( glseq ) AS maxseq
      FROM zreing_ct2_gl_d
      WHERE ctuuid  IN @lt_range_ct
        AND matuuid IN @lt_range_mat
      GROUP BY ctuuid, matuuid
      INTO TABLE @DATA(lt_draft).
    LOOP AT lt_draft INTO DATA(ls_d).
      READ TABLE lt_max INTO DATA(ls_m)
        WITH TABLE KEY ct_uuid = ls_d-ctuuid mat_uuid = ls_d-matuuid.
      IF sy-subrc = 0.
        IF ls_d-maxseq > ls_m-maxseq.
          ls_m-maxseq = ls_d-maxseq.
          MODIFY TABLE lt_max FROM ls_m.
        ENDIF.
      ELSE.
        INSERT VALUE ty_max( ct_uuid = ls_d-ctuuid mat_uuid = ls_d-matuuid maxseq = ls_d-maxseq )
          INTO TABLE lt_max.
      ENDIF.
    ENDLOOP.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\gl.
    DATA lv_counter TYPE i VALUE 0.
    LOOP AT lt_new INTO DATA(ls_new).
      lv_counter += 1.
      READ TABLE lt_max INTO DATA(ls_mx)
        WITH TABLE KEY ct_uuid = ls_new-%data-ctuuid mat_uuid = ls_new-%data-matuuid.
      DATA(lv_base) = COND zreing_ct2_gl_a-gl_seq(
        WHEN sy-subrc = 0 THEN ls_mx-maxseq ELSE '000' ).
      APPEND VALUE #( %tky = ls_new-%tky glseq = lv_base + lv_counter ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctgl2 UPDATE FIELDS ( glseq )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setglroledefaults.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgl2
        FIELDS ( glrole )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_gl).

    IF lt_gl IS INITIAL. RETURN. ENDIF.

    DATA lt_range_role TYPE RANGE OF zreing_ct2_gl_a-gl_role.
    LOOP AT lt_gl INTO DATA(ls_gl_r).
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_gl_r-%data-glrole ) TO lt_range_role.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_role COMPARING low.

    SELECT gl_role, auto_determ, reclassify
      FROM zreing_gl_roles
      WHERE gl_role IN @lt_range_role
      INTO TABLE @DATA(lt_roles).

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\gl.
    LOOP AT lt_gl INTO DATA(ls_gl).
      READ TABLE lt_roles INTO DATA(ls_role)
        WITH KEY gl_role = ls_gl-%data-glrole.
      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky       = ls_gl-%tky
          autodeterm = ls_role-auto_determ
          reclassify = ls_role-reclassify
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctgl2
          UPDATE FIELDS ( autodeterm reclassify )
          WITH lt_update
        REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setgloptypedescr.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgloptype2 FIELDS ( optype )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ops).

    DATA lt_pending LIKE lt_ops.
    LOOP AT lt_ops INTO DATA(ls_o).
      IF ls_o-%data-optype IS NOT INITIAL.
        APPEND ls_o TO lt_pending.
      ENDIF.
    ENDLOOP.
    IF lt_pending IS INITIAL. RETURN. ENDIF.

    "-- Recopilar tipos unicos para SELECT masivo con WHERE
    DATA lt_range_op TYPE RANGE OF zreing_op_types-op_type.
    LOOP AT lt_pending INTO DATA(ls_p).
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_p-%data-optype ) TO lt_range_op.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_op COMPARING low.

    SELECT op_type, descr
      FROM zreing_op_types
      WHERE op_type IN @lt_range_op
      INTO TABLE @DATA(lt_descr).

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\gloptype.
    DATA lv_descr  TYPE zreing_op_types-descr.

    LOOP AT lt_pending INTO DATA(ls_upd).
      READ TABLE lt_descr INTO DATA(ls_d)
        WITH KEY op_type = ls_upd-%data-optype.
      lv_descr = COND #( WHEN sy-subrc = 0 THEN ls_d-descr ELSE '' ).
      APPEND VALUE #(
        %tky        = ls_upd-%tky
        optypedescr = lv_descr
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctgloptype2 UPDATE FIELDS ( optypedescr )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setglopglrole.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgloptype2 FIELDS ( ctuuid matuuid gluuid glrole )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ops).

    DATA lt_new LIKE lt_ops.
    LOOP AT lt_ops INTO DATA(ls_o).
      IF ls_o-%data-glrole IS INITIAL.
        APPEND ls_o TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.

    DATA lt_range_gl TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-gluuid ) TO lt_range_gl.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_gl COMPARING low.

    "-- Tipo propio para el resultado del SELECT
    TYPES: BEGIN OF ty_gl_role,
             gluuid TYPE sysuuid_x16,
             glrole TYPE zreing_ct2_gl_d-glrole,
           END OF ty_gl_role.

    DATA lt_hash TYPE HASHED TABLE OF ty_gl_role
      WITH UNIQUE KEY gluuid.

    SELECT gluuid, glrole
      FROM zreing_ct2_gl_d
      WHERE gluuid IN @lt_range_gl
      INTO TABLE @DATA(lt_gl_roles).

    LOOP AT lt_gl_roles INTO DATA(ls_gl).
      INSERT VALUE ty_gl_role(
        gluuid = ls_gl-gluuid
        glrole = ls_gl-glrole ) INTO TABLE lt_hash.
    ENDLOOP.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\gloptype.
    LOOP AT lt_new INTO DATA(ls_upd).
      READ TABLE lt_hash INTO DATA(ls_gl_r)
        WITH TABLE KEY gluuid = ls_upd-%data-gluuid.
      IF sy-subrc = 0 AND ls_gl_r-glrole IS NOT INITIAL.
        APPEND VALUE #(
          %tky   = ls_upd-%tky
          glrole = ls_gl_r-glrole
        ) TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctgloptype2 UPDATE FIELDS ( glrole )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.

  ENDMETHOD.

  METHOD validateoptype.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgloptype2 FIELDS ( optype glrole )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ops).

    IF lt_ops IS INITIAL. RETURN. ENDIF.

    DATA lt_range_role TYPE RANGE OF zreing_role_op-gl_role.
    DATA lt_range_op   TYPE RANGE OF zreing_role_op-op_type.

    LOOP AT lt_ops INTO DATA(ls_o).
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_o-%data-glrole ) TO lt_range_role.
      APPEND VALUE #( sign = 'I' option = 'EQ'
                      low  = ls_o-%data-optype ) TO lt_range_op.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_role COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_op   COMPARING low.

    "-- Tipo propio para el resultado del SELECT
    TYPES: BEGIN OF ty_role_op,
             gl_role TYPE zreing_role_op-gl_role,
             op_type TYPE zreing_role_op-op_type,
           END OF ty_role_op.

    DATA lt_valid_hash TYPE HASHED TABLE OF ty_role_op
      WITH UNIQUE KEY gl_role op_type.

    SELECT gl_role, op_type
      FROM zreing_role_op
      WHERE gl_role IN @lt_range_role
        AND op_type IN @lt_range_op
      INTO TABLE @DATA(lt_valid).

    LOOP AT lt_valid INTO DATA(ls_v).
      INSERT VALUE ty_role_op(
        gl_role = ls_v-gl_role
        op_type = ls_v-op_type ) INTO TABLE lt_valid_hash.
    ENDLOOP.

    LOOP AT lt_ops INTO DATA(ls_op).
      IF ls_op-%data-optype IS INITIAL.
        APPEND VALUE #( %tky = ls_op-%tky ) TO failed-gloptype.
        APPEND VALUE #( %tky = ls_op-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'El tipo de operacion es obligatorio' )
        ) TO reported-gloptype.
        CONTINUE.
      ENDIF.

      READ TABLE lt_valid_hash TRANSPORTING NO FIELDS
        WITH TABLE KEY
          gl_role = ls_op-%data-glrole
          op_type = ls_op-%data-optype.

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_op-%tky ) TO failed-gloptype.
        APPEND VALUE #( %tky = ls_op-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = |Tipo { ls_op-%data-optype } no valido para rol { ls_op-%data-glrole }| )
        ) TO reported-gloptype.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgl2
        FIELDS ( ctuuid autodeterm )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_gl).

    result = VALUE #(
      FOR ls IN lt_gl (
        %tky              = ls-%tky
        %field-autodeterm = if_abap_behv=>fc-f-read_only
        %field-reclassify = if_abap_behv=>fc-f-read_only
        " Mod 03.09.2026 EXT_AGFAGINA: la cuenta de mayor se bloquea cuando el rol
        " determina la cuenta automaticamente. AutoDeterm llega heredado del
        " catalogo ZREING_GL_ROLES por SetGlRoleDefaults, asi que alcanza con el
        " campo de la propia linea y no hace falta releer el catalogo.
        %field-saknr      = COND #( WHEN ls-%data-autodeterm = 'X'
                                    THEN if_abap_behv=>fc-f-read_only
                                    ELSE if_abap_behv=>fc-f-unrestricted )
      ) ).
  ENDMETHOD.

  METHOD validatenoduplicateglrole.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctgl2
        FIELDS ( ctuuid matuuid glrole )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_gl).

    " BR-CT-GL-01: un rol GL no puede repetirse por contrato+material
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_gllines
        FIELDS ( ctuuid matuuid glrole )
        WITH VALUE #( FOR ls IN lt_gl ( %key-ctuuid = ls-%data-ctuuid %key-matuuid = ls-%data-matuuid ) )
      RESULT DATA(lt_all_gl).

    TYPES: BEGIN OF ty_key,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             gl_role  TYPE zreing_ct2_gl_a-gl_role,
             count    TYPE i,
           END OF ty_key.
    DATA lt_count TYPE HASHED TABLE OF ty_key
      WITH UNIQUE KEY ct_uuid mat_uuid gl_role.

    LOOP AT lt_all_gl INTO DATA(ls_all).
      READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<c>) WITH TABLE KEY
        ct_uuid = ls_all-%data-ctuuid mat_uuid = ls_all-%data-matuuid
        gl_role = ls_all-%data-glrole.
      IF sy-subrc = 0.
        <c>-count += 1.
      ELSE.
        INSERT VALUE #( ct_uuid = ls_all-%data-ctuuid mat_uuid = ls_all-%data-matuuid
          gl_role = ls_all-%data-glrole count = 1 ) INTO TABLE lt_count.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_gl INTO DATA(ls_gl).
      READ TABLE lt_count INTO DATA(ls_cnt) WITH TABLE KEY
        ct_uuid = ls_gl-%data-ctuuid mat_uuid = ls_gl-%data-matuuid
        gl_role = ls_gl-%data-glrole.
      IF sy-subrc = 0 AND ls_cnt-count > 1.
        APPEND VALUE #( %tky = ls_gl-%tky ) TO failed-gl.
        APPEND VALUE #( %tky = ls_gl-%tky
          %element-glrole = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = |Rol GL { ls_gl-%data-glrole } duplicado para el material| ) ) TO reported-gl.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctmetric2 IMPLEMENTATION.

  METHOD setmetricseq.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmetric2 FIELDS ( ctuuid matuuid metuuid metricseq )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_met).
    DATA lt_new LIKE lt_met.
    LOOP AT lt_met INTO DATA(ls_met).
      IF ls_met-%data-metricseq = '000'.
        APPEND ls_met TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.
    DATA lt_range_ct  TYPE RANGE OF sysuuid_x16.
    DATA lt_range_mat TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-ctuuid )  TO lt_range_ct.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-matuuid ) TO lt_range_mat.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct  COMPARING low.
    DELETE ADJACENT DUPLICATES FROM lt_range_mat COMPARING low.
    TYPES: BEGIN OF ty_max,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             maxseq   TYPE zreing_ct2_met_a-metric_seq,
           END OF ty_max.
    DATA lt_max TYPE HASHED TABLE OF ty_max WITH UNIQUE KEY ct_uuid mat_uuid.
    SELECT ct_uuid, mat_uuid, MAX( metric_seq ) AS maxseq
      FROM zreing_ct2_met_a
      WHERE ct_uuid  IN @lt_range_ct
        AND mat_uuid IN @lt_range_mat
      GROUP BY ct_uuid, mat_uuid
      INTO TABLE @DATA(lt_active).
    LOOP AT lt_active INTO DATA(ls_a).
      INSERT VALUE ty_max( ct_uuid = ls_a-ct_uuid mat_uuid = ls_a-mat_uuid maxseq = ls_a-maxseq )
        INTO TABLE lt_max.
    ENDLOOP.
    SELECT ctuuid, matuuid, MAX( metricseq ) AS maxseq
      FROM zreing_ct2_met_d
      WHERE ctuuid  IN @lt_range_ct
        AND matuuid IN @lt_range_mat
      GROUP BY ctuuid, matuuid
      INTO TABLE @DATA(lt_draft).
    LOOP AT lt_draft INTO DATA(ls_d).
      READ TABLE lt_max INTO DATA(ls_m)
        WITH TABLE KEY ct_uuid = ls_d-ctuuid mat_uuid = ls_d-matuuid.
      IF sy-subrc = 0.
        IF ls_d-maxseq > ls_m-maxseq.
          ls_m-maxseq = ls_d-maxseq.
          MODIFY TABLE lt_max FROM ls_m.
        ENDIF.
      ELSE.
        INSERT VALUE ty_max( ct_uuid = ls_d-ctuuid mat_uuid = ls_d-matuuid maxseq = ls_d-maxseq )
          INTO TABLE lt_max.
      ENDIF.
    ENDLOOP.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\metric.
    DATA lv_counter TYPE i VALUE 0.
    LOOP AT lt_new INTO DATA(ls_new).
      lv_counter += 1.
      READ TABLE lt_max INTO DATA(ls_mx)
        WITH TABLE KEY ct_uuid = ls_new-%data-ctuuid mat_uuid = ls_new-%data-matuuid.
      DATA(lv_base) = COND zreing_ct2_met_a-metric_seq(
        WHEN sy-subrc = 0 THEN ls_mx-maxseq ELSE '000' ).
      APPEND VALUE #( %tky = ls_new-%tky metricseq = lv_base + lv_counter ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctmetric2 UPDATE FIELDS ( metricseq )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setmetstatus.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmetric2
        FIELDS ( ctuuid matuuid metuuid validfrom validto )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_met).
    DATA lv_today  TYPE sy-datum.
    DATA lv_status TYPE zreing_ct2_met_a-met_status.
    lv_today = sy-datum.
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\metric.
    LOOP AT lt_met INTO DATA(ls_met).
      lv_status = COND #(
        WHEN ls_met-%data-validfrom IS INITIAL OR ls_met-%data-validto IS INITIAL
          THEN 'BO'
        WHEN lv_today < ls_met-%data-validfrom
          THEN 'FU'
        WHEN lv_today > ls_met-%data-validto
          THEN 'EX'
        ELSE 'AC' ).
      APPEND VALUE #(
        %tky      = ls_met-%tky
        metstatus = lv_status ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctmetric2 UPDATE FIELDS ( metstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.




  METHOD validatemetricdates.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmetric2
        FIELDS ( ctuuid matuuid metuuid validfrom validto  )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_met).
    IF lt_met IS INITIAL. RETURN. ENDIF.
    DATA lt_range_ct TYPE RANGE OF sysuuid_x16.
    LOOP AT lt_met INTO DATA(ls_m).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_m-%data-ctuuid ) TO lt_range_ct.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_range_ct COMPARING low.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcontract2
        FIELDS ( ctuuid validfrom validto )
        WITH VALUE #( FOR ls_ct_key IN lt_range_ct ( ctuuid = ls_ct_key-low ) )
      RESULT DATA(lt_ct).
    TYPES: BEGIN OF ty_ct,
             ct_uuid    TYPE sysuuid_x16,
             valid_from TYPE zreing_ct2_a-valid_from,
             valid_to   TYPE zreing_ct2_a-valid_to,
           END OF ty_ct.
    DATA lt_ct_hash TYPE HASHED TABLE OF ty_ct
      WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_ct INTO DATA(ls_ct).
      INSERT VALUE ty_ct(
        ct_uuid    = ls_ct-%data-ctuuid
        valid_from = ls_ct-%data-validfrom
        valid_to   = ls_ct-%data-validto ) INTO TABLE lt_ct_hash.
    ENDLOOP.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_metrics
        FIELDS ( ctuuid matuuid metuuid validfrom validto )
        WITH VALUE #( FOR ls_key IN lt_met
          ( %key-ctuuid = ls_key-%data-ctuuid %key-matuuid = ls_key-%data-matuuid ) )
      RESULT DATA(lt_all_met).
    TYPES: BEGIN OF ty_met,
             ct_uuid    TYPE sysuuid_x16,
             mat_uuid   TYPE sysuuid_x16,
             met_uuid   TYPE sysuuid_x16,
             valid_from TYPE zreing_ct2_met_a-valid_from,
             valid_to   TYPE zreing_ct2_met_a-valid_to,
           END OF ty_met.
    DATA lt_all_sorted TYPE SORTED TABLE OF ty_met
      WITH NON-UNIQUE KEY ct_uuid mat_uuid.
    LOOP AT lt_all_met INTO DATA(ls_am).
      INSERT VALUE ty_met(
        ct_uuid    = ls_am-%data-ctuuid
        mat_uuid   = ls_am-%data-matuuid
        met_uuid   = ls_am-%data-metuuid
        valid_from = ls_am-%data-validfrom
        valid_to   = ls_am-%data-validto ) INTO TABLE lt_all_sorted.
    ENDLOOP.
    LOOP AT lt_met INTO DATA(ls_met).
      IF ls_met-%data-validfrom IS INITIAL.
        APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
        APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha Inicio de vigencia es obligatoria' ) ) TO reported-metric.
        CONTINUE.
      ENDIF.
      IF ls_met-%data-validto IS INITIAL.
        APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
        APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha Fin de vigencia es obligatoria' ) ) TO reported-metric.
        CONTINUE.
      ENDIF.
      IF ls_met-%data-validfrom >= ls_met-%data-validto.
        APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
        APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Fecha Fin debe ser posterior a Fecha Inicio' ) ) TO reported-metric.
        CONTINUE.
      ENDIF.
      READ TABLE lt_ct_hash INTO DATA(ls_ct_r)
        WITH TABLE KEY ct_uuid = ls_met-%data-ctuuid.
      IF sy-subrc = 0
        AND ls_ct_r-valid_from IS NOT INITIAL
        AND ls_ct_r-valid_to   IS NOT INITIAL.
        IF ls_met-%data-validfrom < ls_ct_r-valid_from.
          APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
          APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = |Fecha Inicio anterior a la vigencia del contrato ({ ls_ct_r-valid_from DATE = USER })| )
          ) TO reported-metric.
        ENDIF.
        IF ls_met-%data-validto > ls_ct_r-valid_to.
          APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
          APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = |Fecha Fin posterior a la vigencia del contrato ({ ls_ct_r-valid_to DATE = USER })| )
          ) TO reported-metric.
        ENDIF.
      ENDIF.
      DATA lv_overlap      TYPE abap_bool VALUE abap_false.
      DATA lv_overlap_from TYPE zreing_ct2_met_a-valid_from.
      DATA lv_overlap_to   TYPE zreing_ct2_met_a-valid_to.
      READ TABLE lt_all_sorted INTO DATA(ls_first)
        WITH KEY ct_uuid  = ls_met-%data-ctuuid
                 mat_uuid = ls_met-%data-matuuid.
      DATA(lv_idx) = sy-tabix.
      WHILE lv_idx <= lines( lt_all_sorted ) AND lv_overlap = abap_false.
        DATA(ls_check) = lt_all_sorted[ lv_idx ].
        lv_idx += 1.
        IF ls_check-ct_uuid <> ls_met-%data-ctuuid
          OR ls_check-mat_uuid <> ls_met-%data-matuuid.
          EXIT.
        ENDIF.
        IF ls_check-met_uuid = ls_met-%data-metuuid. CONTINUE. ENDIF.
        IF ls_check-valid_from IS INITIAL OR ls_check-valid_to IS INITIAL. CONTINUE. ENDIF.
        IF ls_met-%data-validfrom <= ls_check-valid_to
          AND ls_met-%data-validto >= ls_check-valid_from.
          lv_overlap      = abap_true.
          lv_overlap_from = ls_check-valid_from.
          lv_overlap_to   = ls_check-valid_to.
        ENDIF.
      ENDWHILE.
      IF lv_overlap = abap_true.
        APPEND VALUE #( %tky = ls_met-%tky ) TO failed-metric.
        APPEND VALUE #( %tky = ls_met-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = |Vigencia solapada con otra metrica ({ lv_overlap_from DATE = USER
                  } - { lv_overlap_to DATE = USER })| ) ) TO reported-metric.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctcron2 IMPLEMENTATION.

  METHOD setcroninstance.
    " V001 (CC) - #111: derive a non-key field from the exact parent in the same draft context.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY Cron FIELDS ( ctuuid matuuid optype opuuid opinstancenum cronstatus )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_cron).
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY OpType FIELDS ( ctuuid matuuid optype opuuid opinstancenum )
        WITH VALUE #( FOR ls_c IN lt_cron
          ( %is_draft = ls_c-%is_draft ctuuid = ls_c-ctuuid matuuid = ls_c-matuuid
            optype = ls_c-optype opuuid = ls_c-opuuid ) ) RESULT DATA(lt_options).
    SORT lt_options BY %is_draft ctuuid matuuid optype opuuid.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\cron.
    LOOP AT lt_cron INTO DATA(ls_cron).
      IF ls_cron-cronstatus = 'EX' OR ls_cron-cronstatus = 'CA'.
        CONTINUE.
      ENDIF.
      READ TABLE lt_options INTO DATA(ls_option)
        WITH KEY %is_draft = ls_cron-%is_draft ctuuid = ls_cron-ctuuid matuuid = ls_cron-matuuid
                 optype = ls_cron-optype opuuid = ls_cron-opuuid BINARY SEARCH.
      IF sy-subrc = 0 AND ls_option-opinstancenum IS NOT INITIAL
        AND ls_cron-opinstancenum <> ls_option-opinstancenum.
        APPEND VALUE #( %tky = ls_cron-%tky opinstancenum = ls_option-opinstancenum ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY Cron UPDATE FIELDS ( opinstancenum ) WITH lt_update
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.

  METHOD validatecroninstance.
    " V001 (CC) - #111: no unresolved or cross-instance schedule may be saved.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY Cron FIELDS ( ctuuid matuuid optype opuuid opinstancenum )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_cron).
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY OpType FIELDS ( ctuuid matuuid optype opuuid opinstancenum )
        WITH VALUE #( FOR ls_c IN lt_cron
          ( %is_draft = ls_c-%is_draft ctuuid = ls_c-ctuuid matuuid = ls_c-matuuid
            optype = ls_c-optype opuuid = ls_c-opuuid ) ) RESULT DATA(lt_options).
    SORT lt_options BY %is_draft ctuuid matuuid optype opuuid.

    LOOP AT lt_cron INTO DATA(ls_cron).
      READ TABLE lt_options INTO DATA(ls_option)
        WITH KEY %is_draft = ls_cron-%is_draft ctuuid = ls_cron-ctuuid matuuid = ls_cron-matuuid
                 optype = ls_cron-optype opuuid = ls_cron-opuuid BINARY SEARCH.
      IF sy-subrc <> 0 OR ls_option-opinstancenum IS INITIAL
        OR ls_cron-opinstancenum <> ls_option-opinstancenum.
        APPEND VALUE #( %tky = ls_cron-%tky ) TO failed-cron.
        APPEND VALUE #(
          %tky = ls_cron-%tky %element-opinstancenum = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'La instancia del cronograma debe coincidir con la operacion del contrato' ) ) TO reported-cron.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD setcronstatus.
    " V001 (CC) - Every newly created installment starts planned.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcron2
        FIELDS ( cronstatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_cron).

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\cron.
    LOOP AT lt_cron INTO DATA(ls_cron) WHERE %data-cronstatus IS INITIAL.
      APPEND VALUE #( %tky       = ls_cron-%tky
                      cronstatus = 'PL' ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcron2
          UPDATE FIELDS ( cronstatus )
          WITH lt_update
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.

  " Begin Mod 01.09.2026 EXT_AGFAGINA - propagacion del cronograma al hijo.
  " Con distribucion Lineal el hijo genera su cronograma solo (GenerateCronLines
  " se dispara al recibir las fechas). Pero con distribucion NO Lineal el
  " cronograma se carga a mano y esa carga no dispara AutoCreateLinkedOpType,
  " porque las lineas son de otra entidad. Esta determinacion cubre ese caso:
  " al guardar, replica en el hijo las lineas del padre.
  " Guard anti-recursion: solo propaga desde tipos PADRE, es decir los que no
  " tienen PARENT_TYPE informado en ZREING_OP_TYPE_C. Las lineas que esta misma
  " determinacion crea en el hijo no vuelven a propagarse.
  METHOD syncchildcron.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcron2 FIELDS ( ctuuid matuuid optype opuuid )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_ck).
    IF lt_ck IS INITIAL. RETURN. ENDIF.

    SELECT op_type, parent_type
      FROM zreing_op_type_c
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_cfg).
    IF lt_cfg IS INITIAL. RETURN. ENDIF.

    "-- Mapa padre -> hijo
    TYPES: BEGIN OF ty_map,
             parent TYPE zreing_ct2_opt_a-op_type,
             child  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_map.
    DATA lt_child_of TYPE HASHED TABLE OF ty_map WITH UNIQUE KEY parent.

    LOOP AT lt_cfg INTO DATA(ls_cfg).
      IF ls_cfg-parent_type IS INITIAL. CONTINUE. ENDIF.
      TRY.
          INSERT VALUE ty_map( parent = ls_cfg-parent_type
                               child  = ls_cfg-op_type ) INTO TABLE lt_child_of.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.
    IF lt_child_of IS INITIAL. RETURN. ENDIF.

    "-- OpTypes padre tocados. Si el tipo no figura como padre en el catalogo
    "-- no se propaga: eso corta la recursion sobre las lineas del propio hijo.
    TYPES: BEGIN OF ty_par,
             ctuuid  TYPE sysuuid_x16,
             matuuid TYPE sysuuid_x16,
             optype  TYPE zreing_ct2_opt_a-op_type,
             opuuid  TYPE sysuuid_x16,
             isdraft TYPE abap_bool,
           END OF ty_par.
    DATA lt_par TYPE HASHED TABLE OF ty_par
      WITH UNIQUE KEY ctuuid matuuid opuuid.

    LOOP AT lt_ck INTO DATA(ls_ck).
      READ TABLE lt_child_of TRANSPORTING NO FIELDS
        WITH TABLE KEY parent = ls_ck-%data-optype.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      TRY.
          INSERT VALUE ty_par(
            ctuuid  = ls_ck-%data-ctuuid
            matuuid = ls_ck-%data-matuuid
            optype  = ls_ck-%data-optype
            opuuid  = ls_ck-%data-opuuid
            isdraft = ls_ck-%is_draft ) INTO TABLE lt_par.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.
    IF lt_par IS INITIAL. RETURN. ENDIF.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum disttype )
        WITH VALUE #( FOR ls_p IN lt_par
          ( %is_draft    = ls_p-isdraft
            %key-ctuuid  = ls_p-ctuuid
            %key-matuuid = ls_p-matuuid
            %key-optype  = ls_p-optype
            %key-opuuid  = ls_p-opuuid ) )
      RESULT DATA(lt_pdata).

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_optypes
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum )
        WITH VALUE #( FOR ls_m IN lt_par
          ( %is_draft    = ls_m-isdraft
            %key-ctuuid  = ls_m-ctuuid
            %key-matuuid = ls_m-matuuid ) )
      RESULT DATA(lt_all_opts).

    TYPES: BEGIN OF ty_optkey,
             ctuuid  TYPE sysuuid_x16,
             matuuid TYPE sysuuid_x16,
             optype  TYPE zreing_ct2_opt_a-op_type,
             inst    TYPE zreing_ct2_opt_a-op_instance_num,
             opuuid  TYPE sysuuid_x16,
           END OF ty_optkey.
    DATA lt_optkey TYPE HASHED TABLE OF ty_optkey
      WITH UNIQUE KEY ctuuid matuuid optype inst.

    LOOP AT lt_all_opts INTO DATA(ls_ao).
      TRY.
          INSERT VALUE ty_optkey(
            ctuuid  = ls_ao-%data-ctuuid
            matuuid = ls_ao-%data-matuuid
            optype  = ls_ao-%data-optype
            inst    = ls_ao-%data-opinstancenum
            opuuid  = ls_ao-%data-opuuid ) INTO TABLE lt_optkey.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.

    "-- Pares a sincronizar. Con distribucion Lineal no se copia: el hijo genera
    "-- su cronograma solo via GenerateCronLines.
    TYPES: BEGIN OF ty_pair,
             popuuid   TYPE sysuuid_x16,
             pctuuid   TYPE sysuuid_x16,
             pmatuuid  TYPE sysuuid_x16,
             poptype   TYPE zreing_ct2_opt_a-op_type,
             childtyp  TYPE zreing_ct2_opt_a-op_type,
             childuuid TYPE sysuuid_x16,
             childinst TYPE zreing_ct2_opt_a-op_instance_num,
             isdraft   TYPE abap_bool,
           END OF ty_pair.
    DATA lt_pairs TYPE HASHED TABLE OF ty_pair WITH UNIQUE KEY popuuid.

    LOOP AT lt_pdata INTO DATA(ls_pd).
      " V001 (CC) - #111: the child retains its own UUID and resolved instance.
      IF ls_pd-%data-disttype = 'L' OR ls_pd-%data-opinstancenum IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE lt_child_of INTO DATA(ls_map)
        WITH TABLE KEY parent = ls_pd-%data-optype.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      READ TABLE lt_optkey INTO DATA(ls_okey)
        WITH TABLE KEY
          ctuuid  = ls_pd-%data-ctuuid
          matuuid = ls_pd-%data-matuuid
          optype  = ls_map-child
          inst    = ls_pd-%data-opinstancenum.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      TRY.
          INSERT VALUE ty_pair(
            popuuid   = ls_pd-%data-opuuid
            pctuuid   = ls_pd-%data-ctuuid
            pmatuuid  = ls_pd-%data-matuuid
            poptype   = ls_pd-%data-optype
            childtyp  = ls_map-child
            childuuid = ls_okey-opuuid
            childinst = ls_okey-inst
            isdraft   = ls_pd-%is_draft ) INTO TABLE lt_pairs.
        CATCH cx_sy_itab_duplicate_key.                  "#EC NOHANDLER
      ENDTRY.
    ENDLOOP.
    IF lt_pairs IS INITIAL. RETURN. ENDIF.

    "-- Lineas de los padres y de los hijos: una sola lectura de cada lado
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 BY \_cron
        FIELDS ( ctuuid matuuid optype opuuid cronyear cronmonth percentage )
        WITH VALUE #( FOR ls_s IN lt_pairs
          ( %is_draft    = ls_s-isdraft
            %key-ctuuid  = ls_s-pctuuid
            %key-matuuid = ls_s-pmatuuid
            %key-optype  = ls_s-poptype
            %key-opuuid  = ls_s-popuuid ) )
      RESULT DATA(lt_src).

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctoptype2 BY \_cron
        FIELDS ( ctuuid matuuid optype opuuid cronyear cronmonth percentage cronstatus )
        WITH VALUE #( FOR ls_o IN lt_pairs
          ( %is_draft    = ls_o-isdraft
            %key-ctuuid  = ls_o-pctuuid
            %key-matuuid = ls_o-pmatuuid
            %key-optype  = ls_o-childtyp
            %key-opuuid  = ls_o-childuuid ) )
      RESULT DATA(lt_old).

    "-- Aplanar las lineas del padre junto con el hijo destino
    TYPES: BEGIN OF ty_flat,
             childuuid TYPE sysuuid_x16,
             childinst TYPE zreing_ct2_opt_a-op_instance_num,
             ctuuid    TYPE sysuuid_x16,
             matuuid   TYPE sysuuid_x16,
             childtyp  TYPE zreing_ct2_opt_a-op_type,
             isdraft   TYPE abap_bool,
             cronyear  TYPE zreing_ct2_crn_a-cron_year,
             cronmonth TYPE zreing_ct2_crn_a-cron_month,
             pct       TYPE zreing_ct2_crn_a-percentage,
           END OF ty_flat.
    DATA lt_flat TYPE STANDARD TABLE OF ty_flat WITH EMPTY KEY.

    LOOP AT lt_src INTO DATA(ls_src).
      READ TABLE lt_pairs INTO DATA(ls_pair)
        WITH TABLE KEY popuuid = ls_src-%data-opuuid.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      APPEND VALUE ty_flat(
        childuuid = ls_pair-childuuid
        childinst = ls_pair-childinst
        ctuuid    = ls_pair-pctuuid
        matuuid   = ls_pair-pmatuuid
        childtyp  = ls_pair-childtyp
        isdraft   = ls_pair-isdraft
        cronyear  = ls_src-%data-cronyear
        cronmonth = ls_src-%data-cronmonth
        pct       = ls_src-%data-percentage ) TO lt_flat.
    ENDLOOP.

    SORT lt_flat BY childuuid cronyear cronmonth.

    " V001 (CC) - Preserve executed/cancelled child installments.
    TYPES: BEGIN OF ty_old_key,
             opuuid    TYPE sysuuid_x16,
             cronyear  TYPE zreing_ct2_crn_a-cron_year,
             cronmonth TYPE zreing_ct2_crn_a-cron_month,
           END OF ty_old_key.
    DATA lt_old_keys TYPE HASHED TABLE OF ty_old_key
      WITH UNIQUE KEY opuuid cronyear cronmonth.
    DATA lt_del TYPE TABLE FOR DELETE zi_reingctcontract2\\cron.
    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingctcontract2\\cron.

    LOOP AT lt_old INTO DATA(ls_old).
      INSERT VALUE ty_old_key(
        opuuid    = ls_old-%data-opuuid
        cronyear  = ls_old-%data-cronyear
        cronmonth = ls_old-%data-cronmonth ) INTO TABLE lt_old_keys.

      READ TABLE lt_flat INTO DATA(ls_match)
        WITH KEY childuuid = ls_old-%data-opuuid
                 cronyear  = ls_old-%data-cronyear
                 cronmonth = ls_old-%data-cronmonth
        BINARY SEARCH.
      IF sy-subrc = 0.
        IF ls_old-%data-cronstatus <> 'EX'
        AND ls_old-%data-cronstatus <> 'CA'.
          APPEND VALUE #( %tky       = ls_old-%tky
                          opinstancenum = ls_match-childinst
                          percentage = ls_match-pct ) TO lt_upd.
        ENDIF.
      ELSEIF ls_old-%data-cronstatus <> 'EX'
         AND ls_old-%data-cronstatus <> 'CA'.
        APPEND VALUE #( %tky = ls_old-%tky ) TO lt_del.
      ENDIF.
    ENDLOOP.

    "-- Agrupar por hijo en un unico recorrido, sin anidar loops
    DATA lt_new  TYPE TABLE FOR CREATE zi_reingctcontract2\\optype\_cron.
    DATA ls_new  LIKE LINE OF lt_new.
    DATA lv_prev TYPE sysuuid_x16.

    LOOP AT lt_flat INTO DATA(ls_f).
      IF line_exists( lt_old_keys[
           opuuid    = ls_f-childuuid
           cronyear  = ls_f-cronyear
           cronmonth = ls_f-cronmonth ] ).
        CONTINUE.
      ENDIF.
      IF ls_f-childuuid <> lv_prev.
        IF lv_prev IS NOT INITIAL.
          APPEND ls_new TO lt_new.
        ENDIF.
        CLEAR ls_new.
        ls_new-%key-ctuuid  = ls_f-ctuuid.
        ls_new-%key-matuuid = ls_f-matuuid.
        ls_new-%key-optype  = ls_f-childtyp.
        ls_new-%key-opuuid  = ls_f-childuuid.
        ls_new-%is_draft    = ls_f-isdraft.
        lv_prev = ls_f-childuuid.
      ENDIF.
      APPEND VALUE #(
        %cid       = |CRNCP{ ls_f-childuuid }{ ls_f-cronyear }{ ls_f-cronmonth }|
        %is_draft  = ls_f-isdraft
        cronyear   = ls_f-cronyear
        cronmonth  = ls_f-cronmonth
        opinstancenum = ls_f-childinst
        percentage = ls_f-pct ) TO ls_new-%target.
    ENDLOOP.
    IF lv_prev IS NOT INITIAL.
      APPEND ls_new TO lt_new.
    ENDIF.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcron2
          UPDATE FIELDS ( percentage opinstancenum )
          WITH lt_upd
        REPORTED DATA(lt_rep_u).
    ENDIF.

    IF lt_del IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctcron2 DELETE FROM lt_del
        REPORTED DATA(lt_rep_d).
    ENDIF.

    IF lt_new IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          CREATE BY \_cron
          FIELDS ( cronyear cronmonth percentage opinstancenum )
          WITH lt_new
        REPORTED DATA(lt_rep_c).
    ENDIF.

  ENDMETHOD.
  " End Mod 01.09.2026 EXT_AGFAGINA

  METHOD validatecronsum.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctcron2 FIELDS ( ctuuid matuuid optype opuuid percentage )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cron).
    TYPES: BEGIN OF ty_sum,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             op_type  TYPE zreing_ct2_crn_a-op_type,
             op_uuid  TYPE sysuuid_x16,
             total    TYPE zreing_ct2_crn_a-percentage,
           END OF ty_sum.
    DATA lt_sums TYPE HASHED TABLE OF ty_sum
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid.
    LOOP AT lt_cron INTO DATA(ls_c).
      READ TABLE lt_sums INTO DATA(ls_sum)
        WITH TABLE KEY
          ct_uuid  = ls_c-%data-ctuuid
          mat_uuid = ls_c-%data-matuuid
          op_type  = ls_c-%data-optype
          op_uuid  = ls_c-%data-opuuid.
      IF sy-subrc = 0.
        ls_sum-total += ls_c-%data-percentage.
        MODIFY TABLE lt_sums FROM ls_sum.
      ELSE.
        INSERT VALUE ty_sum(
          ct_uuid  = ls_c-%data-ctuuid
          mat_uuid = ls_c-%data-matuuid
          op_type  = ls_c-%data-optype
          op_uuid  = ls_c-%data-opuuid
          total    = ls_c-%data-percentage ) INTO TABLE lt_sums.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_cron INTO DATA(ls_cron).
      READ TABLE lt_sums INTO ls_sum
        WITH TABLE KEY
          ct_uuid  = ls_cron-%data-ctuuid
          mat_uuid = ls_cron-%data-matuuid
          op_type  = ls_cron-%data-optype
          op_uuid  = ls_cron-%data-opuuid.
      IF sy-subrc = 0 AND ls_sum-total <> 100.
        APPEND VALUE #( %tky = ls_cron-%tky ) TO failed-cron.
        APPEND VALUE #( %tky = ls_cron-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'La suma de porcentajes debe ser exactamente 100% por partida' ) ) TO reported-cron.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctreceiver2 IMPLEMENTATION.

  METHOD setreceiverdefaults.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctreceiver2 FIELDS ( recbukrs country prctr )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_rec).
    DATA lt_new LIKE lt_rec.
    LOOP AT lt_rec INTO DATA(ls_rec).
      IF ls_rec-%data-recbukrs IS NOT INITIAL AND ls_rec-%data-country IS INITIAL.
        APPEND ls_rec TO lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS INITIAL. RETURN. ENDIF.
    DATA lt_bukrs TYPE RANGE OF bukrs.
    LOOP AT lt_new INTO DATA(ls_n).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_n-%data-recbukrs ) TO lt_bukrs.
    ENDLOOP.
    DELETE ADJACENT DUPLICATES FROM lt_bukrs COMPARING low.
    SELECT companycode, country FROM i_companycode
      WHERE companycode IN @lt_bukrs
      INTO TABLE @DATA(lt_t001).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\receiver.
    LOOP AT lt_new INTO DATA(ls_upd).
      READ TABLE lt_t001 INTO DATA(ls_t001)
        WITH KEY companycode = ls_upd-%data-recbukrs.
      IF sy-subrc = 0.
        APPEND VALUE #(
          %tky    = ls_upd-%tky
          country = ls_t001-country ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctreceiver2 UPDATE FIELDS ( country )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD setreceiverstatus.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctreceiver2 FIELDS ( recstatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_rec).
    DATA lt_update TYPE TABLE FOR UPDATE zi_reingctcontract2\\receiver.
    LOOP AT lt_rec INTO DATA(ls_rec).
      IF ls_rec-%data-recstatus IS INITIAL.
        APPEND VALUE #( %tky = ls_rec-%tky recstatus = 'AC' ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctreceiver2 UPDATE FIELDS ( recstatus )
        WITH lt_update REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD validatenoduplicatereceiver.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctreceiver2
        FIELDS ( ctuuid matuuid recbukrs prctr campana rolecategory allocation )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_rec).

    " BR-CT-SOC-03/04: valores válidos (mandatory ya cubre que no estén vacíos)
    LOOP AT lt_rec INTO DATA(ls_val).
      IF ls_val-%data-rolecategory <> 'C' AND ls_val-%data-rolecategory <> 'E'.
        APPEND VALUE #( %tky = ls_val-%tky ) TO failed-receiver.
        APPEND VALUE #( %tky = ls_val-%tky %element-rolecategory = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
            text = 'Categoría de gasto inválida (C o E)' ) ) TO reported-receiver.
      ENDIF.
      IF ls_val-%data-allocation <> '0' AND ls_val-%data-allocation <> '1'
         AND ls_val-%data-allocation <> '3'.
        APPEND VALUE #( %tky = ls_val-%tky ) TO failed-receiver.
        APPEND VALUE #( %tky = ls_val-%tky %element-allocation = if_abap_behv=>mk-on
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
            text = 'Asignación inválida (0, 1 o 3)' ) ) TO reported-receiver.
      ENDIF.
    ENDLOOP.

    " BR-CT-SOC-05: unicidad de la tupla ampliada (conteo sobre TODOS los receptores del material)
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_receivers
        FIELDS ( ctuuid matuuid recbukrs prctr campana rolecategory allocation )
        WITH VALUE #( FOR ls IN lt_rec ( %key-ctuuid = ls-%data-ctuuid %key-matuuid = ls-%data-matuuid ) )
      RESULT DATA(lt_all_rec).

    TYPES: BEGIN OF ty_key,
             ct_uuid       TYPE sysuuid_x16, mat_uuid TYPE sysuuid_x16,
             rec_bukrs     TYPE zreing_ct2_rec_a-rec_bukrs, prctr TYPE zreing_ct2_rec_a-prctr,
             campana       TYPE zreing_ct2_rec_a-campana, role_category TYPE zreing_ct2_rec_a-role_category,
             allocation    TYPE zreing_ct2_rec_a-allocation, count TYPE i,
           END OF ty_key.
    DATA lt_count TYPE HASHED TABLE OF ty_key
      WITH UNIQUE KEY ct_uuid mat_uuid rec_bukrs prctr campana role_category allocation.

    LOOP AT lt_all_rec INTO DATA(ls_all).
      READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<c>) WITH TABLE KEY
        ct_uuid = ls_all-%data-ctuuid mat_uuid = ls_all-%data-matuuid
        rec_bukrs = ls_all-%data-recbukrs prctr = ls_all-%data-prctr
        campana = ls_all-%data-campana role_category = ls_all-%data-rolecategory
        allocation = ls_all-%data-allocation.
      IF sy-subrc = 0.
        <c>-count += 1.
      ELSE.
        INSERT VALUE #( ct_uuid = ls_all-%data-ctuuid mat_uuid = ls_all-%data-matuuid
      rec_bukrs = ls_all-%data-recbukrs prctr = ls_all-%data-prctr campana = ls_all-%data-campana
      role_category = ls_all-%data-rolecategory allocation = ls_all-%data-allocation
      count = 1 ) INTO TABLE lt_count.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_rec INTO DATA(ls_rec).
      READ TABLE lt_count INTO DATA(ls_cnt) WITH TABLE KEY
        ct_uuid = ls_rec-%data-ctuuid mat_uuid = ls_rec-%data-matuuid
        rec_bukrs = ls_rec-%data-recbukrs prctr = ls_rec-%data-prctr
        campana = ls_rec-%data-campana role_category = ls_rec-%data-rolecategory
        allocation = ls_rec-%data-allocation.
      IF sy-subrc = 0 AND ls_cnt-count > 1.
        APPEND VALUE #( %tky = ls_rec-%tky ) TO failed-receiver.
        APPEND VALUE #( %tky = ls_rec-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = |Combinación duplicada: Soc { ls_rec-%data-recbukrs } / CeBe { ls_rec-%data-prctr } / Camp { ls_rec-%data-campana } / Cat { ls_rec-%data-rolecategory } / Asig { ls_rec-%data-allocation }| ) ) TO reported-receiver.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD syncopratesonreceiver.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctreceiver2
        FIELDS ( ctuuid matuuid recbukrs )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rec_all).
    IF lt_rec_all IS INITIAL. RETURN. ENDIF.

    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY zi_reingctmaterial2 BY \_optypes
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum exchratetype )
        WITH VALUE #( FOR ls_ra IN lt_rec_all
          ( %is_draft    = ls_ra-%is_draft
            %key-ctuuid  = ls_ra-%data-ctuuid
            %key-matuuid = ls_ra-%data-matuuid ) )
      RESULT DATA(lt_opts_all).

    DATA lt_opts_m LIKE lt_opts_all.
    LOOP AT lt_opts_all INTO DATA(ls_oa).
      " V001 (CC) - #111: use the numbered option when adding a receiver rate.
      IF ls_oa-%data-exchratetype = 'M' AND ls_oa-%data-opinstancenum IS NOT INITIAL.
        APPEND ls_oa TO lt_opts_m.
      ENDIF.
    ENDLOOP.
    IF lt_opts_m IS INITIAL. RETURN. ENDIF.

    " V001 (CC) - #111: repeated determinations must preserve an existing manual rate.
    READ ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
      ENTITY OpType BY \_OpRates
        FIELDS ( ctuuid matuuid optype opuuid opinstancenum bukrsrecv )
        WITH CORRESPONDING #( lt_opts_m ) RESULT DATA(lt_existing_rates).
    SORT lt_existing_rates BY %is_draft ctuuid matuuid optype opuuid opinstancenum bukrsrecv.

    TYPES: BEGIN OF ty_recv_opr,
             ct_uuid   TYPE sysuuid_x16,
             mat_uuid  TYPE sysuuid_x16,
             rec_bukrs TYPE zreing_ct_o_r_a-bukrs_recv,
             is_draft  TYPE abap_bool,
           END OF ty_recv_opr.
    DATA lt_recv_sorted TYPE SORTED TABLE OF ty_recv_opr
      WITH NON-UNIQUE KEY ct_uuid mat_uuid.
    LOOP AT lt_rec_all INTO DATA(ls_ra2).
      INSERT VALUE ty_recv_opr(
        ct_uuid   = ls_ra2-%data-ctuuid
        mat_uuid  = ls_ra2-%data-matuuid
        rec_bukrs = ls_ra2-%data-recbukrs
        is_draft  = ls_ra2-%is_draft ) INTO TABLE lt_recv_sorted.
    ENDLOOP.

    TYPES: BEGIN OF ty_mat_range_o,
             ct_uuid  TYPE sysuuid_x16,
             mat_uuid TYPE sysuuid_x16,
             idx_from TYPE i,
             idx_to   TYPE i,
           END OF ty_mat_range_o.
    DATA lt_mat_ranges TYPE HASHED TABLE OF ty_mat_range_o
      WITH UNIQUE KEY ct_uuid mat_uuid.
    DATA lv_prev_ct  TYPE sysuuid_x16.
    DATA lv_prev_mat TYPE sysuuid_x16.
    DATA lv_from_idx TYPE i VALUE 1.
    DATA lv_total_ro TYPE i.
    DATA ls_rv_scan  TYPE ty_recv_opr.
    lv_total_ro = lines( lt_recv_sorted ).

    DO lv_total_ro TIMES.
      ls_rv_scan = lt_recv_sorted[ sy-index ].
      IF ls_rv_scan-ct_uuid <> lv_prev_ct
        OR ls_rv_scan-mat_uuid <> lv_prev_mat.
        IF lv_prev_mat IS NOT INITIAL.
          INSERT VALUE ty_mat_range_o(
            ct_uuid  = lv_prev_ct
            mat_uuid = lv_prev_mat
            idx_from = lv_from_idx
            idx_to   = sy-index - 1 ) INTO TABLE lt_mat_ranges.
        ENDIF.
        lv_from_idx = sy-index.
        lv_prev_ct  = ls_rv_scan-ct_uuid.
        lv_prev_mat = ls_rv_scan-mat_uuid.
      ENDIF.
      IF sy-index = lv_total_ro.
        INSERT VALUE ty_mat_range_o(
          ct_uuid  = ls_rv_scan-ct_uuid
          mat_uuid = ls_rv_scan-mat_uuid
          idx_from = lv_from_idx
          idx_to   = sy-index ) INTO TABLE lt_mat_ranges.
      ENDIF.
    ENDDO.

    DATA lt_create_opr TYPE TABLE FOR CREATE zi_reingctcontract2\\optype\_oprates.
    DATA ls_opt_m      TYPE STRUCTURE FOR READ RESULT zi_reingctcontract2\\optype.
    DATA lt_tgt_opr    LIKE LINE OF lt_create_opr.
    DATA ls_rv_o       TYPE ty_recv_opr.
    DATA ls_range      TYPE ty_mat_range_o.
    DATA lv_cid        TYPE i VALUE 0.
    DATA lv_count      TYPE i.

    LOOP AT lt_opts_m INTO ls_opt_m.
      DATA lt_tgt LIKE lt_tgt_opr-%target.
      CLEAR lt_tgt.

      READ TABLE lt_mat_ranges INTO ls_range
        WITH TABLE KEY
          ct_uuid  = ls_opt_m-%data-ctuuid
          mat_uuid = ls_opt_m-%data-matuuid.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      lv_count = ls_range-idx_to - ls_range-idx_from + 1.

      DO lv_count TIMES.
        ls_rv_o = lt_recv_sorted[ ls_range-idx_from + sy-index - 1 ].
        READ TABLE lt_existing_rates TRANSPORTING NO FIELDS
          WITH KEY %is_draft = ls_opt_m-%is_draft
                   ctuuid = ls_opt_m-ctuuid matuuid = ls_opt_m-matuuid
                   optype = ls_opt_m-optype opuuid = ls_opt_m-opuuid
                   opinstancenum = ls_opt_m-opinstancenum bukrsrecv = ls_rv_o-rec_bukrs
          BINARY SEARCH.
        IF sy-subrc = 0. CONTINUE. ENDIF.
        lv_cid += 1.
        APPEND VALUE #(
          %cid           = |REC{ ls_opt_m-%data-ctuuid
                           }{ ls_opt_m-%data-optype
                           }{ ls_rv_o-rec_bukrs
                           }{ lv_cid }|
          %is_draft      = ls_opt_m-%is_draft
          bukrsrecv      = ls_rv_o-rec_bukrs
          opinstancenum  = ls_opt_m-%data-opinstancenum
          manualexchrate = 0 ) TO lt_tgt.
      ENDDO.

      IF lt_tgt IS INITIAL. CONTINUE. ENDIF.

      APPEND VALUE #(
        %key-ctuuid  = ls_opt_m-%data-ctuuid
        %key-matuuid = ls_opt_m-%data-matuuid
        %key-optype  = ls_opt_m-%data-optype
        %key-opuuid  = ls_opt_m-%data-opuuid
        %is_draft    = ls_opt_m-%is_draft
        %target      = lt_tgt ) TO lt_create_opr.
    ENDLOOP.

    IF lt_create_opr IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract2 IN LOCAL MODE
        ENTITY zi_reingctoptype2
          CREATE BY \_oprates
          FIELDS ( bukrsrecv manualexchrate opinstancenum )
          WITH lt_create_opr
        REPORTED DATA(lt_rep_cr).
    ENDIF.
  ENDMETHOD.


ENDCLASS.

CLASS lsc_zi_reingctcontract2 IMPLEMENTATION.

  METHOD save_modified.
    DATA lv_now TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.

    DATA lt_hist_ins TYPE TABLE OF zreing_c2_hist_a WITH EMPTY KEY.

    " === CONTRACT ===
    DATA lt_ct_keys     TYPE TABLE OF zreing_ct2_a WITH EMPTY KEY.
    DATA lt_ct_prev     TYPE HASHED TABLE OF zreing_ct2_a WITH UNIQUE KEY ct_uuid.
    DATA lt_ct_prev_raw TYPE TABLE OF zreing_ct2_a WITH EMPTY KEY.

    LOOP AT update-contract INTO DATA(ls_ct_buf).
      APPEND VALUE zreing_ct2_a( ct_uuid = ls_ct_buf-ctuuid ) TO lt_ct_keys.
    ENDLOOP.

    IF lt_ct_keys IS NOT INITIAL.
      SELECT ct_uuid, lifnr, bukrs, ext_contract, valid_from, valid_to,
             waers, responsible, email_contact, renewal_days, comments, ct_status
        FROM zreing_ct2_a
        FOR ALL ENTRIES IN @lt_ct_keys
        WHERE ct_uuid = @lt_ct_keys-ct_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_ct_prev_raw.
      LOOP AT lt_ct_prev_raw INTO DATA(ls_ct_db).
        INSERT ls_ct_db INTO TABLE lt_ct_prev.
      ENDLOOP.

      LOOP AT update-contract INTO DATA(ls_ct_upd).
        READ TABLE lt_ct_prev INTO DATA(ls_ct_old)
          WITH TABLE KEY ct_uuid = ls_ct_upd-ctuuid.
        CHECK sy-subrc = 0.

        IF ls_ct_upd-%control-lifnr = if_abap_behv=>mk-on
        AND ls_ct_upd-lifnr <> ls_ct_old-lifnr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Proveedor'
            value_old = ls_ct_old-lifnr value_new = ls_ct_upd-lifnr ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-bukrs = if_abap_behv=>mk-on
        AND ls_ct_upd-bukrs <> ls_ct_old-bukrs.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Soc. Origen'
            value_old = ls_ct_old-bukrs value_new = ls_ct_upd-bukrs ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-extcontract = if_abap_behv=>mk-on
        AND ls_ct_upd-extcontract <> ls_ct_old-ext_contract.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'N. Contrato Externo'
            value_old = ls_ct_old-ext_contract value_new = ls_ct_upd-extcontract ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-validfrom = if_abap_behv=>mk-on
        AND ls_ct_upd-validfrom <> ls_ct_old-valid_from.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Vigencia Desde'
            value_old = ls_ct_old-valid_from value_new = ls_ct_upd-validfrom ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-validto = if_abap_behv=>mk-on
        AND ls_ct_upd-validto <> ls_ct_old-valid_to.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Vigencia Hasta'
            value_old = ls_ct_old-valid_to value_new = ls_ct_upd-validto ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-waers = if_abap_behv=>mk-on
        AND ls_ct_upd-waers <> ls_ct_old-waers.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Moneda'
            value_old = ls_ct_old-waers value_new = ls_ct_upd-waers ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-responsible = if_abap_behv=>mk-on
        AND ls_ct_upd-responsible <> ls_ct_old-responsible.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Responsable'
            value_old = ls_ct_old-responsible value_new = ls_ct_upd-responsible ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-emailcontact = if_abap_behv=>mk-on
        AND ls_ct_upd-emailcontact <> ls_ct_old-email_contact.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Correo Contacto'
            value_old = ls_ct_old-email_contact value_new = ls_ct_upd-emailcontact ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-renewaldays = if_abap_behv=>mk-on
        AND ls_ct_upd-renewaldays <> ls_ct_old-renewal_days.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Alerta Renovacion'
            value_old = |{ ls_ct_old-renewal_days }|
            value_new = |{ ls_ct_upd-renewaldays }| ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-comments = if_abap_behv=>mk-on
        AND ls_ct_upd-comments <> ls_ct_old-comments.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = 'UPDATE' field_name = 'Comentarios'
            value_old = ls_ct_old-comments value_new = ls_ct_upd-comments ) TO lt_hist_ins.
        ENDIF.
        IF ls_ct_upd-%control-ctstatus = if_abap_behv=>mk-on
        AND ls_ct_upd-ctstatus <> ls_ct_old-ct_status.
          DATA(lv_ct_action) = COND zreing_c2_hist_a-action(
            WHEN ls_ct_upd-ctstatus = 'AC' THEN 'ACTIVATE'
            WHEN ls_ct_upd-ctstatus = 'IN' THEN 'INACTIVATE'
            WHEN ls_ct_upd-ctstatus = 'AR' THEN 'ARCHIVE'
            ELSE 'UPDATE' ).
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_ct_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'CONTRACT' entity_key = ls_ct_upd-ctuuid
            action = lv_ct_action field_name = 'Estado'
            value_old = ls_ct_old-ct_status value_new = ls_ct_upd-ctstatus ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === MATERIAL ===
    DATA lt_mat_keys     TYPE TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    DATA lt_mat_prev     TYPE HASHED TABLE OF zreing_ct2_mat_a WITH UNIQUE KEY ct_uuid mat_uuid.
    DATA lt_mat_prev_raw TYPE TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.

    LOOP AT update-material INTO DATA(ls_mat_buf).
      APPEND VALUE zreing_ct2_mat_a(
        ct_uuid  = ls_mat_buf-ctuuid
        mat_uuid = ls_mat_buf-matuuid ) TO lt_mat_keys.
    ENDLOOP.

    IF lt_mat_keys IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, matnr, amount, kostl, prctr, saknr
        FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @lt_mat_keys
        WHERE ct_uuid  = @lt_mat_keys-ct_uuid
          AND mat_uuid = @lt_mat_keys-mat_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_mat_prev_raw.
      LOOP AT lt_mat_prev_raw INTO DATA(ls_mat_db).
        INSERT ls_mat_db INTO TABLE lt_mat_prev.
      ENDLOOP.

      LOOP AT update-material INTO DATA(ls_mat_upd).
        READ TABLE lt_mat_prev INTO DATA(ls_mat_old)
          WITH TABLE KEY ct_uuid = ls_mat_upd-ctuuid mat_uuid = ls_mat_upd-matuuid.
        CHECK sy-subrc = 0.
        DATA(lv_mat_key) = |MAT:{ ls_mat_upd-matuuid }|.

        IF ls_mat_upd-%control-matnr = if_abap_behv=>mk-on
        AND ls_mat_upd-matnr <> ls_mat_old-matnr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_mat_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'MATERIAL' entity_key = lv_mat_key
            action = 'UPDATE' field_name = 'Material'
            value_old = ls_mat_old-matnr value_new = ls_mat_upd-matnr ) TO lt_hist_ins.
        ENDIF.
        IF ls_mat_upd-%control-amount = if_abap_behv=>mk-on
        AND ls_mat_upd-amount <> ls_mat_old-amount.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_mat_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'MATERIAL' entity_key = lv_mat_key
            action = 'UPDATE' field_name = 'Monto'
            value_old = |{ ls_mat_old-amount }|
            value_new = |{ ls_mat_upd-amount }| ) TO lt_hist_ins.
        ENDIF.
        IF ls_mat_upd-%control-kostl = if_abap_behv=>mk-on
        AND ls_mat_upd-kostl <> ls_mat_old-kostl.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_mat_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'MATERIAL' entity_key = lv_mat_key
            action = 'UPDATE' field_name = 'Centro de Costo'
            value_old = ls_mat_old-kostl value_new = ls_mat_upd-kostl ) TO lt_hist_ins.
        ENDIF.
        IF ls_mat_upd-%control-prctr = if_abap_behv=>mk-on
        AND ls_mat_upd-prctr <> ls_mat_old-prctr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_mat_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'MATERIAL' entity_key = lv_mat_key
            action = 'UPDATE' field_name = 'Centro de Beneficio'
            value_old = ls_mat_old-prctr value_new = ls_mat_upd-prctr ) TO lt_hist_ins.
        ENDIF.
        IF ls_mat_upd-%control-saknr = if_abap_behv=>mk-on
        AND ls_mat_upd-saknr <> ls_mat_old-saknr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_mat_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'MATERIAL' entity_key = lv_mat_key
            action = 'UPDATE' field_name = 'Cuenta Mayor'
            value_old = ls_mat_old-saknr value_new = ls_mat_upd-saknr ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === OPTYPE ===
    DATA lt_opt_keys     TYPE TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
    DATA lt_opt_prev     TYPE HASHED TABLE OF zreing_ct2_opt_a WITH UNIQUE KEY ct_uuid mat_uuid op_uuid.
    DATA lt_opt_prev_raw TYPE TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.

    LOOP AT update-optype INTO DATA(ls_opt_buf).
      APPEND VALUE zreing_ct2_opt_a(
        ct_uuid  = ls_opt_buf-ctuuid
        mat_uuid = ls_opt_buf-matuuid
        op_uuid  = ls_opt_buf-opuuid ) TO lt_opt_keys.
    ENDLOOP.

    IF lt_opt_keys IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_uuid, op_type, exch_rate_type,
             defer_from, defer_to, dist_type, installments, waers,
             me_period_offset
        FROM zreing_ct2_opt_a
        FOR ALL ENTRIES IN @lt_opt_keys
        WHERE ct_uuid  = @lt_opt_keys-ct_uuid
          AND mat_uuid = @lt_opt_keys-mat_uuid
          AND op_uuid  = @lt_opt_keys-op_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_opt_prev_raw.
      LOOP AT lt_opt_prev_raw INTO DATA(ls_opt_db).
        INSERT ls_opt_db INTO TABLE lt_opt_prev.
      ENDLOOP.

      LOOP AT update-optype INTO DATA(ls_opt_upd).
        READ TABLE lt_opt_prev INTO DATA(ls_opt_old)
          WITH TABLE KEY
            ct_uuid  = ls_opt_upd-ctuuid
            mat_uuid = ls_opt_upd-matuuid
            op_uuid  = ls_opt_upd-opuuid.
        CHECK sy-subrc = 0.
        DATA(lv_opt_key) = |OPT:{ ls_opt_upd-optype }|.

        IF ls_opt_upd-%control-exchratetype = if_abap_behv=>mk-on
        AND ls_opt_upd-exchratetype <> ls_opt_old-exch_rate_type.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Tipo de Cambio'
            value_old = ls_opt_old-exch_rate_type value_new = ls_opt_upd-exchratetype ) TO lt_hist_ins.
        ENDIF.
        IF ls_opt_upd-%control-deferfrom = if_abap_behv=>mk-on
        AND ls_opt_upd-deferfrom <> ls_opt_old-defer_from.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Inicio Devengamiento'
            value_old = ls_opt_old-defer_from value_new = ls_opt_upd-deferfrom ) TO lt_hist_ins.
        ENDIF.
        IF ls_opt_upd-%control-deferto = if_abap_behv=>mk-on
        AND ls_opt_upd-deferto <> ls_opt_old-defer_to.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Fin Devengamiento'
            value_old = ls_opt_old-defer_to value_new = ls_opt_upd-deferto ) TO lt_hist_ins.
        ENDIF.
        IF ls_opt_upd-%control-disttype = if_abap_behv=>mk-on
        AND ls_opt_upd-disttype <> ls_opt_old-dist_type.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Tipo Distribucion'
            value_old = ls_opt_old-dist_type value_new = ls_opt_upd-disttype ) TO lt_hist_ins.
        ENDIF.
        IF ls_opt_upd-%control-installments = if_abap_behv=>mk-on
        AND ls_opt_upd-installments <> ls_opt_old-installments.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Cuotas'
            value_old = |{ ls_opt_old-installments }|
            value_new = |{ ls_opt_upd-installments }| ) TO lt_hist_ins.
        ENDIF.
        " Begin Mod 03.09.2026 EXT_AGFAGINA - faltaban Moneda y Offset de Periodo.
        " Ambos son de carga manual (field features:instance / mandatory) y no se
        " estaban comparando, asi que sus cambios no dejaban rastro en el historial.
        IF ls_opt_upd-%control-waers = if_abap_behv=>mk-on
        AND ls_opt_upd-waers <> ls_opt_old-waers.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Moneda'
            value_old = ls_opt_old-waers value_new = ls_opt_upd-waers ) TO lt_hist_ins.
        ENDIF.
        IF ls_opt_upd-%control-meperiodoffset = if_abap_behv=>mk-on
        AND ls_opt_upd-meperiodoffset <> ls_opt_old-me_period_offset.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opt_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPTYPE' entity_key = lv_opt_key
            action = 'UPDATE' field_name = 'Offset Periodo Metrica'
            value_old = ls_opt_old-me_period_offset
            value_new = ls_opt_upd-meperiodoffset ) TO lt_hist_ins.
        ENDIF.
        " End Mod 03.09.2026 EXT_AGFAGINA
      ENDLOOP.
    ENDIF.

    " === METRIC ===
    DATA lt_met_keys     TYPE TABLE OF zreing_ct2_met_a WITH EMPTY KEY.
    DATA lt_met_prev     TYPE HASHED TABLE OF zreing_ct2_met_a WITH UNIQUE KEY ct_uuid mat_uuid met_uuid.
    DATA lt_met_prev_raw TYPE TABLE OF zreing_ct2_met_a WITH EMPTY KEY.

    LOOP AT update-metric INTO DATA(ls_met_buf).
      APPEND VALUE zreing_ct2_met_a(
        ct_uuid  = ls_met_buf-ctuuid
        mat_uuid = ls_met_buf-matuuid
        met_uuid = ls_met_buf-metuuid ) TO lt_met_keys.
    ENDLOOP.

    IF lt_met_keys IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, met_uuid, metric_code, version_num,
                   valid_from, valid_to
             FROM zreing_ct2_met_a
             FOR ALL ENTRIES IN @lt_met_keys
             WHERE ct_uuid  = @lt_met_keys-ct_uuid
               AND mat_uuid = @lt_met_keys-mat_uuid
               AND met_uuid = @lt_met_keys-met_uuid
             INTO CORRESPONDING FIELDS OF TABLE @lt_met_prev_raw.
      LOOP AT lt_met_prev_raw INTO DATA(ls_met_db).
        INSERT ls_met_db INTO TABLE lt_met_prev.
      ENDLOOP.

      LOOP AT update-metric INTO DATA(ls_met_upd).
        READ TABLE lt_met_prev INTO DATA(ls_met_old)
          WITH TABLE KEY
            ct_uuid  = ls_met_upd-ctuuid
            mat_uuid = ls_met_upd-matuuid
            met_uuid = ls_met_upd-metuuid.
        CHECK sy-subrc = 0.
        DATA(lv_met_key) = |MET:{ ls_met_upd-metriccode }/{ ls_met_upd-versionnum }|.

        IF ls_met_upd-%control-metriccode = if_abap_behv=>mk-on
        AND ls_met_upd-metriccode <> ls_met_old-metric_code.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_met_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'METRIC' entity_key = lv_met_key
            action = 'UPDATE' field_name = 'Codigo Metrica'
            value_old = ls_met_old-metric_code value_new = ls_met_upd-metriccode ) TO lt_hist_ins.
        ENDIF.
        IF ls_met_upd-%control-versionnum = if_abap_behv=>mk-on
        AND ls_met_upd-versionnum <> ls_met_old-version_num.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_met_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'METRIC' entity_key = lv_met_key
            action = 'UPDATE' field_name = 'Version'
            value_old = ls_met_old-version_num value_new = ls_met_upd-versionnum ) TO lt_hist_ins.
        ENDIF.
        IF ls_met_upd-%control-validfrom = if_abap_behv=>mk-on
        AND ls_met_upd-validfrom <> ls_met_old-valid_from.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_met_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'METRIC' entity_key = lv_met_key
            action = 'UPDATE' field_name = 'Vigencia Desde'
            value_old = ls_met_old-valid_from value_new = ls_met_upd-validfrom ) TO lt_hist_ins.
        ENDIF.
        IF ls_met_upd-%control-validto = if_abap_behv=>mk-on
        AND ls_met_upd-validto <> ls_met_old-valid_to.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_met_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'METRIC' entity_key = lv_met_key
            action = 'UPDATE' field_name = 'Vigencia Hasta'
            value_old = ls_met_old-valid_to value_new = ls_met_upd-validto ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === RECEIVER ===
    DATA lt_rec_keys     TYPE TABLE OF zreing_ct2_rec_a WITH EMPTY KEY.
    DATA lt_rec_prev     TYPE HASHED TABLE OF zreing_ct2_rec_a WITH UNIQUE KEY ct_uuid mat_uuid rec_uuid.
    DATA lt_rec_prev_raw TYPE TABLE OF zreing_ct2_rec_a WITH EMPTY KEY.

    LOOP AT update-receiver INTO DATA(ls_rec_buf).
      APPEND VALUE zreing_ct2_rec_a(
              ct_uuid  = ls_rec_buf-ctuuid
              mat_uuid = ls_rec_buf-matuuid
              rec_uuid = ls_rec_buf-recuuid ) TO lt_rec_keys.
    ENDLOOP.

    IF lt_rec_keys IS NOT INITIAL.
      " Begin Mod 03.09.2026 EXT_AGFAGINA - historial de receptoras.
      " Dos defectos:
      "  1) el SELECT no traia REC_UUID, y lt_rec_prev es HASHED con clave
      "     ct_uuid + mat_uuid + rec_uuid. El rec_uuid quedaba vacio y el
      "     READ TABLE de mas abajo nunca encontraba la fila: el CHECK cortaba
      "     siempre y el bloque no registraba NADA, ni siquiera las fechas.
      "  2) solo se comparaban ValidFrom y ValidTo. Los campos que el usuario
      "     realmente edita (Sociedad, CeBe, Campana, Categoria, Asignacion) no
      "     se miraban, por eso cambiar una campana no dejaba rastro.
      " Se registran unicamente los campos de carga manual. Country y RecStatus
      " quedan afuera a proposito: los escriben SetReceiverDefaults y
      " SetReceiverStatus, y anotarlos llenaria el historial de ruido.
      SELECT ct_uuid, mat_uuid, rec_uuid, rec_bukrs, prctr, campana,
             role_category, allocation, valid_from, valid_to
        FROM zreing_ct2_rec_a
        FOR ALL ENTRIES IN @lt_rec_keys
        WHERE ct_uuid  = @lt_rec_keys-ct_uuid
          AND mat_uuid = @lt_rec_keys-mat_uuid
          AND rec_uuid = @lt_rec_keys-rec_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_rec_prev_raw.
      LOOP AT lt_rec_prev_raw INTO DATA(ls_rec_db).
        INSERT ls_rec_db INTO TABLE lt_rec_prev.
      ENDLOOP.

      LOOP AT update-receiver INTO DATA(ls_rec_upd).
        READ TABLE lt_rec_prev INTO DATA(ls_rec_old)
                  WITH TABLE KEY
                    ct_uuid  = ls_rec_upd-ctuuid
                    mat_uuid = ls_rec_upd-matuuid
                    rec_uuid = ls_rec_upd-recuuid.
        CHECK sy-subrc = 0.
        DATA(lv_rec_key) = |REC:{ ls_rec_upd-recbukrs }|.

        IF ls_rec_upd-%control-recbukrs = if_abap_behv=>mk-on
        AND ls_rec_upd-recbukrs <> ls_rec_old-rec_bukrs.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Sociedad Receptora'
            value_old = ls_rec_old-rec_bukrs value_new = ls_rec_upd-recbukrs ) TO lt_hist_ins.
        ENDIF.
        IF ls_rec_upd-%control-prctr = if_abap_behv=>mk-on
        AND ls_rec_upd-prctr <> ls_rec_old-prctr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Centro de Beneficio'
            value_old = ls_rec_old-prctr value_new = ls_rec_upd-prctr ) TO lt_hist_ins.
        ENDIF.
        IF ls_rec_upd-%control-campana = if_abap_behv=>mk-on
        AND ls_rec_upd-campana <> ls_rec_old-campana.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Campana'
            value_old = ls_rec_old-campana value_new = ls_rec_upd-campana ) TO lt_hist_ins.
        ENDIF.
        IF ls_rec_upd-%control-rolecategory = if_abap_behv=>mk-on
        AND ls_rec_upd-rolecategory <> ls_rec_old-role_category.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Categoria de Gasto'
            value_old = ls_rec_old-role_category value_new = ls_rec_upd-rolecategory ) TO lt_hist_ins.
        ENDIF.
        IF ls_rec_upd-%control-allocation = if_abap_behv=>mk-on
        AND ls_rec_upd-allocation <> ls_rec_old-allocation.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Allocation'
            value_old = ls_rec_old-allocation value_new = ls_rec_upd-allocation ) TO lt_hist_ins.
        ENDIF.
        " End Mod 03.09.2026 EXT_AGFAGINA
        IF ls_rec_upd-%control-validfrom = if_abap_behv=>mk-on
        AND ls_rec_upd-validfrom <> ls_rec_old-valid_from.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Vigencia Desde'
            value_old = ls_rec_old-valid_from value_new = ls_rec_upd-validfrom ) TO lt_hist_ins.
        ENDIF.
        IF ls_rec_upd-%control-validto = if_abap_behv=>mk-on
        AND ls_rec_upd-validto <> ls_rec_old-valid_to.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_rec_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'RECEIVER' entity_key = lv_rec_key
            action = 'UPDATE' field_name = 'Vigencia Hasta'
            value_old = ls_rec_old-valid_to value_new = ls_rec_upd-validto ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === GL ===
    DATA lt_gl_keys     TYPE TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    DATA lt_gl_prev     TYPE HASHED TABLE OF zreing_ct2_gl_a WITH UNIQUE KEY ct_uuid mat_uuid gl_uuid.
    DATA lt_gl_prev_raw TYPE TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.

    LOOP AT update-gl INTO DATA(ls_gl_buf).
      APPEND VALUE zreing_ct2_gl_a(
        ct_uuid  = ls_gl_buf-ctuuid
        mat_uuid = ls_gl_buf-matuuid
        gl_uuid  = ls_gl_buf-gluuid ) TO lt_gl_keys.
    ENDLOOP.

    IF lt_gl_keys IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, gl_uuid, gl_role, saknr, op_type
        FROM zreing_ct2_gl_a
        FOR ALL ENTRIES IN @lt_gl_keys
        WHERE ct_uuid  = @lt_gl_keys-ct_uuid
          AND mat_uuid = @lt_gl_keys-mat_uuid
          AND gl_uuid  = @lt_gl_keys-gl_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_gl_prev_raw.
      LOOP AT lt_gl_prev_raw INTO DATA(ls_gl_db).
        INSERT ls_gl_db INTO TABLE lt_gl_prev.
      ENDLOOP.

      LOOP AT update-gl INTO DATA(ls_gl_upd).
        READ TABLE lt_gl_prev INTO DATA(ls_gl_old)
          WITH TABLE KEY
            ct_uuid  = ls_gl_upd-ctuuid
            mat_uuid = ls_gl_upd-matuuid
            gl_uuid  = ls_gl_upd-gluuid.
        CHECK sy-subrc = 0.
        DATA(lv_gl_key) = |GL:{ ls_gl_upd-glrole }|.

        IF ls_gl_upd-%control-glrole = if_abap_behv=>mk-on
        AND ls_gl_upd-glrole <> ls_gl_old-gl_role.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_gl_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'GL' entity_key = lv_gl_key
            action = 'UPDATE' field_name = 'Rol GL'
            value_old = ls_gl_old-gl_role value_new = ls_gl_upd-glrole ) TO lt_hist_ins.
        ENDIF.
        IF ls_gl_upd-%control-saknr = if_abap_behv=>mk-on
        AND ls_gl_upd-saknr <> ls_gl_old-saknr.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_gl_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'GL' entity_key = lv_gl_key
            action = 'UPDATE' field_name = 'Cuenta Mayor'
            value_old = ls_gl_old-saknr value_new = ls_gl_upd-saknr ) TO lt_hist_ins.
        ENDIF.
        IF ls_gl_upd-%control-optype = if_abap_behv=>mk-on
        AND ls_gl_upd-optype <> ls_gl_old-op_type.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_gl_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'GL' entity_key = lv_gl_key
            action = 'UPDATE' field_name = 'Tipo Operacion'
            value_old = ls_gl_old-op_type value_new = ls_gl_upd-optype ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === OPRATE ===
    DATA lt_opr_keys     TYPE TABLE OF zreing_ct_o_r_a WITH EMPTY KEY.
    DATA lt_opr_prev     TYPE HASHED TABLE OF zreing_ct_o_r_a WITH UNIQUE KEY ct_uuid mat_uuid op_uuid bukrs_recv.
    DATA lt_opr_prev_raw TYPE TABLE OF zreing_ct_o_r_a WITH EMPTY KEY.

    LOOP AT update-oprate INTO DATA(ls_opr_buf).
      APPEND VALUE zreing_ct_o_r_a(
        ct_uuid    = ls_opr_buf-ctuuid
        mat_uuid   = ls_opr_buf-matuuid
        op_uuid    = ls_opr_buf-opuuid
        bukrs_recv = ls_opr_buf-bukrsrecv ) TO lt_opr_keys.
    ENDLOOP.

    IF lt_opr_keys IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_uuid, bukrs_recv, manual_exch_rate
        FROM zreing_ct_o_r_a
        FOR ALL ENTRIES IN @lt_opr_keys
        WHERE ct_uuid    = @lt_opr_keys-ct_uuid
          AND mat_uuid   = @lt_opr_keys-mat_uuid
          AND op_uuid    = @lt_opr_keys-op_uuid
          AND bukrs_recv = @lt_opr_keys-bukrs_recv
        INTO CORRESPONDING FIELDS OF TABLE @lt_opr_prev_raw.
      LOOP AT lt_opr_prev_raw INTO DATA(ls_opr_db).
        INSERT ls_opr_db INTO TABLE lt_opr_prev.
      ENDLOOP.

      LOOP AT update-oprate INTO DATA(ls_opr_upd).
        READ TABLE lt_opr_prev INTO DATA(ls_opr_old)
          WITH TABLE KEY
            ct_uuid    = ls_opr_upd-ctuuid
            mat_uuid   = ls_opr_upd-matuuid
            op_uuid    = ls_opr_upd-opuuid
            bukrs_recv = ls_opr_upd-bukrsrecv.
        CHECK sy-subrc = 0.

        IF ls_opr_upd-%control-manualexchrate = if_abap_behv=>mk-on
        AND ls_opr_upd-manualexchrate <> ls_opr_old-manual_exch_rate.
          APPEND VALUE zreing_c2_hist_a(
            ct_uuid = ls_opr_upd-ctuuid hist_uuid = get_uuid( )
            changed_at = lv_now changed_by = sy-uname
            entity_level = 'OPRATE' entity_key = |RATE:{ ls_opr_upd-bukrsrecv }|
            action = 'UPDATE' field_name = 'Tasa Manual'
            value_old = |{ ls_opr_old-manual_exch_rate }|
            value_new = |{ ls_opr_upd-manualexchrate }| ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " === INSERT historial ===
    IF lt_hist_ins IS NOT INITIAL.
      INSERT zreing_c2_hist_a FROM TABLE @lt_hist_ins.
    ENDIF.

  ENDMETHOD.




  METHOD get_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        CLEAR rv_uuid.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
