*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Procesadora Reclasificacion (ZZZ)      *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Subclase de ZCL_REING_CONTAB_DOC para pasos de reclasificacion
* (DOC_TYPE_CODE = ZZZ / ACTZZZ). Config en DOCTYPE_C.PROCESSING_CLASS.
*
* A diferencia del procesamiento normal (que calcula montos de LINE_PC_A),
* esta subclase LEE los valores exactos del paso anterior y genera pares
* de lineas credito/debito para mover montos de cuentas transitorias a
* definitivas (ET SS8a).
*
* Fuente del paso previo: DOCUMENTOS EN MEMORIA del run actual (inyectados
* por el Engine via set_prior_documents), NO ZREING_CB_DOC_A. Motivo: por
* la optimizacion anti-ATC del Engine (buffer + INSERT unico al final), el
* paso previo del mismo run todavia no esta persistido cuando se evalua
* este paso. Leer de memoria es fiel a la ET (misma logica de negocio),
* correcto (dato disponible) y mas performante (cero SELECT).
*
* Redefine is_applicable (paso previo exitoso), build_items (pares C/D) y
* set_prior_documents (captura del contexto en memoria).
*----------------------------------------------------------------------*
CLASS zcl_reing_contab_doc_recl DEFINITION
  PUBLIC
  INHERITING FROM zcl_reing_contab_doc
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_reing_contab~is_applicable        REDEFINITION.

  PROTECTED SECTION.
    METHODS build_items REDEFINITION.
    " V001 (CC) - #122: inherit the single approved item-text formatter.

  PRIVATE SECTION.
    " V001 (CC) - #121: aggregate only equivalent final ZZZ/Z positions.
    METHODS consolidate_mapped_items
      IMPORTING it_items TYPE zif_reing_contab_types=>ty_doc_item_t
      RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
    " V001 (CC) - #125: configured GL roles determine a unique counterpart.
    TYPES: BEGIN OF ty_counter_resolution,
             role TYPE zif_reing_contab_types=>ty_role_resolved,
             candidate_count TYPE i,
             self_only TYPE abap_bool,
           END OF ty_counter_resolution.
    METHODS resolve_counter_role
      IMPORTING it_roles TYPE zif_reing_contab_types=>ty_role_resolved_t
                iv_category TYPE zreing_role_cat
                iv_target_role TYPE zreing_role_code
      RETURNING VALUE(rs_resolution) TYPE ty_counter_resolution.
    "! Localiza el step_result del paso inmediatamente anterior en el run,
    "! usando el DOC_TYPE_CODE previo de DOCFLOW_C. Devuelve OPTIONAL vacio
    "! si no existe (no posteo o no aplico).
    METHODS get_prev_step_result
      RETURNING VALUE(rs_prev) TYPE zif_reing_contab_types=>ty_step_result
      RAISING   zcx_reing_contab.
ENDCLASS.


CLASS zcl_reing_contab_doc_recl IMPLEMENTATION.

  METHOD zif_reing_contab~is_applicable.
    " V001 (CC) — fixes-050 (Delta v2).
    " The reclassification step applies only when the successful preceding
    " document contains a non-zero item explicitly marked for reclassification.
    " This prevents an empty BAPI call when the configured WHT rate is zero.
    rv_applicable = abap_false.

    TRY.
        DATA(ls_prev) = get_prev_step_result( ).
      CATCH zcx_reing_contab.
        RETURN.
    ENDTRY.

    IF ls_prev-doc_type_code IS INITIAL
       OR ls_prev-has_error = abap_true
       OR ls_prev-items IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_prev_items) = ls_prev-items.
    SELECT gl_role, reclassify
      FROM zreing_gl_roles
      FOR ALL ENTRIES IN @lt_prev_items
      WHERE gl_role = @lt_prev_items-role_code
      INTO TABLE @DATA(lt_prev_role_master).

    LOOP AT lt_prev_items INTO DATA(ls_prev_item) WHERE amount <> 0.
      IF line_exists( lt_prev_role_master[
           gl_role    = ls_prev_item-role_code
           reclassify = abap_true ] ).
        rv_applicable = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_prev_step_result.
    " DOC_TYPE_CODE del paso anterior (helper de la clase base) y su
    " step_result dentro de los documentos del run (memoria).
    DATA(lv_prev_dtc) = get_prev_step_doc_type( ms_flow_step-seq ).
    rs_prev = VALUE #( mt_prior_docs[ doc_type_code = lv_prev_dtc ] OPTIONAL ).
  ENDMETHOD.


  METHOD build_items.
    " V001 (CC) - CB-03: reject incomplete roles before any FI call.
    CONSTANTS co_recl_target_missing TYPE symsgno VALUE '424'.
    CONSTANTS co_recl_counter_missing TYPE symsgno VALUE '425'.
    CONSTANTS co_recl_roles_equal TYPE symsgno VALUE '426'.
    CONSTANTS co_recl_ambiguous TYPE symsgno VALUE '010'.
    CONSTANTS co_recl_target_not_gl TYPE symsgno VALUE '011'.
    " V001 (CC) — fixes-049 (Delta v2).
    " V001 (CC) - #125: the prior marked item supplies amount and currency.
    " The current document supplies target and counterpart roles and sides.
    " TAX_TYPE does not restrict a reclassification counterpart.
    DATA lv_item TYPE n LENGTH 3.
    DATA(lv_contract_pc) = xsdbool( mv_doc_type_code = zif_reing_ca_c=>contab_doc_type-reclassification
      AND ms_flow_step-kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map ).
    DATA lt_prev_role_master TYPE HASHED TABLE OF zreing_gl_roles
      WITH UNIQUE KEY gl_role.

    DATA ls_prev TYPE zif_reing_contab_types=>ty_step_result.
    TRY.
        ls_prev = get_prev_step_result( ).
      CATCH zcx_reing_contab.
        RETURN.
    ENDTRY.

    DATA(lt_prev_items) = ls_prev-items.
    IF lt_prev_items IS INITIAL.
      RETURN.
    ENDIF.

    " Una sola lectura masiva, fuera del loop de items.
    SELECT gl_role, role_category, tax_type, reclassify, posting_context,
           role_reclas
      FROM zreing_gl_roles
      FOR ALL ENTRIES IN @lt_prev_items
      WHERE gl_role = @lt_prev_items-role_code
      INTO CORRESPONDING FIELDS OF TABLE @lt_prev_role_master.

    LOOP AT lt_prev_items INTO DATA(ls_pi).
      DATA(ls_source_master) = VALUE zreing_gl_roles(
        lt_prev_role_master[ gl_role = ls_pi-role_code ] OPTIONAL ).
      IF ls_source_master-reclassify <> abap_true.
        CONTINUE.
      ENDIF.

      " V001 (CC) - CB-03: zero WHT never requires reclassification roles.
      DATA(lv_amount) = CONV zreing_ca_line_a-net_amt( abs( ls_pi-amount ) ).
      IF lv_amount IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_target_role_code) =
        CONV zreing_role_code( ls_source_master-role_reclas ).
      DATA(ls_target_role) = VALUE zif_reing_contab_types=>ty_role_resolved(
        it_roles[ role_code = lv_target_role_code ] OPTIONAL ).
      " V001 (CC) - #125: never choose by tax type, role name or row order.
      DATA(lv_config_message) = CONV symsgno( space ).
      IF ls_target_role-role_code IS INITIAL.
        lv_config_message = co_recl_target_missing.
      ELSEIF ls_target_role-posting_context <> 'GL'.
        lv_config_message = co_recl_target_not_gl.
      ELSE.
        DATA(ls_resolution) = resolve_counter_role(
          it_roles = it_roles iv_category = ls_source_master-role_category
          iv_target_role = lv_target_role_code ).
        DATA(ls_counter_role) = ls_resolution-role.
        CASE ls_resolution-candidate_count.
          WHEN 0.
            lv_config_message = COND #(
              WHEN ls_resolution-self_only = abap_true THEN co_recl_roles_equal
              ELSE co_recl_counter_missing ).
          WHEN 1.
            " The single configured candidate is the complete resolution.
          WHEN OTHERS.
            lv_config_message = co_recl_ambiguous.
        ENDCASE.
      ENDIF.

      IF lv_config_message IS NOT INITIAL.
        IF mv_trans_error IS INITIAL.
          CASE lv_config_message.
            WHEN co_recl_ambiguous.
              MESSAGE ID zif_reing_ca_c=>message_class
                TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER lv_config_message
                WITH mv_doc_type_code ls_pi-role_code ls_resolution-candidate_count
                     ls_source_master-role_category INTO mv_trans_error.
            WHEN co_recl_target_not_gl.
              MESSAGE ID zif_reing_ca_c=>message_class
                TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER lv_config_message
                WITH mv_doc_type_code ls_pi-role_code lv_target_role_code INTO mv_trans_error.
            WHEN OTHERS.
              MESSAGE ID zif_reing_ca_c=>message_class
                TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER lv_config_message
                WITH mv_doc_type_code ls_pi-role_code lv_target_role_code
                     ls_source_master-role_category INTO mv_trans_error.
          ENDCASE.
        ENDIF.
        RETURN.
      ENDIF.

      " V001 (CC) - #121: Rochelle's clarification applies only to ZZZ/Z.
      DATA(lv_prctr) = ls_pi-prctr.
      IF lv_contract_pc = abap_true.
        " Keep the existing invalid-company error even when the new field is empty.
        IF ms_flow_step-bukrs_rule = zif_reing_ca_c=>bukrs_rule_override
           AND mv_contract_prctr IS INITIAL.
          trans_error( iv_number = zif_reing_ca_c=>recl_message-missing_contract_prctr iv_v1 = CONV #( ms_line_a-ct_id )
            iv_v2 = CONV #( ms_line_a-matnr ) iv_v3 = CONV #( mv_doc_type_code ) ).
          RETURN.
        ENDIF.
        lv_prctr = mv_contract_prctr.
      ENDIF.

      " V001 (CC) — fixes-052: reclassification cost centers belong to ZZZ.
      " Functional clarification supersedes fixes-051 and requires both ZZZ
      " positions to use the internal code of the document header company.
      " V001 (CC) - #121: source cost-center prefix wins over campaign metadata for Z.
      DATA(lv_campana_de) = COND zreing_campana(
        WHEN ms_flow_step-kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map
        THEN ls_pi-kostl+0(3) ELSE ls_pi-campana ).
      DATA(lv_kostl) = determine_kostl(
        iv_campana    = lv_campana_de
        iv_allocation = ls_pi-allocation
        iv_prctr      = lv_prctr
        iv_kostl_rule = ms_flow_step-kostl_rule
        iv_matnr      = ms_line_a-matnr ).

      DATA(lv_target_acct) = VALUE hkont(
        mt_gl_account[ gl_role = ls_target_role-role_code ]-saknr OPTIONAL ).
      DATA(lv_counter_acct) = VALUE hkont(
        mt_gl_account[ gl_role = ls_counter_role-role_code ]-saknr OPTIONAL ).

      IF lv_contract_pc = abap_false.
        lv_item = lv_item + 1.
      ENDIF.
      APPEND VALUE #(
        item_num        = lv_item
        role_code       = ls_target_role-role_code
        posting_context = ls_target_role-posting_context
        hkont           = lv_target_acct
        posting_side    = ls_target_role-posting_side
        amount          = apply_sign(
                            iv_amount       = lv_amount
                            iv_posting_side = ls_target_role-posting_side )
        waers           = ls_pi-waers
        kostl           = lv_kostl
        prctr           = lv_prctr
        campana         = ls_pi-campana
        allocation      = ls_pi-allocation
        zuonr           = ls_pi-zuonr ) TO rt_items.

      IF lv_contract_pc = abap_false.
        lv_item = lv_item + 1.
      ENDIF.
      APPEND VALUE #(
        item_num        = lv_item
        role_code       = ls_counter_role-role_code
        posting_context = ls_counter_role-posting_context
        hkont           = lv_counter_acct
        posting_side    = ls_counter_role-posting_side
        amount          = apply_sign(
                            iv_amount       = lv_amount
                            iv_posting_side = ls_counter_role-posting_side )
        waers           = ls_pi-waers
        kostl           = lv_kostl
        prctr           = lv_prctr
        campana         = ls_pi-campana
        allocation      = ls_pi-allocation
        zuonr           = ls_pi-zuonr ) TO rt_items.
    ENDLOOP.
    IF lv_contract_pc = abap_true AND mv_trans_error IS INITIAL.
      rt_items = consolidate_mapped_items( rt_items ).
    ENDIF.
  ENDMETHOD.




  METHOD resolve_counter_role.
    " V001 (CC) - #125: pure resolution over the current configured roles.
    DATA lv_target_in_category TYPE abap_bool.
    LOOP AT it_roles INTO DATA(ls_role)
      WHERE posting_context = 'GL' AND role_category = iv_category.
      IF ls_role-role_code = iv_target_role.
        lv_target_in_category = abap_true.
        CONTINUE.
      ENDIF.
      rs_resolution-candidate_count += 1.
      rs_resolution-role = ls_role.
    ENDLOOP.
    rs_resolution-self_only = xsdbool(
      rs_resolution-candidate_count = 0 AND lv_target_in_category = abap_true ).
    IF rs_resolution-candidate_count <> 1.
      CLEAR rs_resolution-role.
    ENDIF.
  ENDMETHOD.

  METHOD consolidate_mapped_items.
    " V001 (CC) - #121: retain complete dimensions, first occurrence and exact totals.
    TYPES: BEGIN OF ty_group,
             item TYPE zif_reing_contab_types=>ty_doc_item,
             total TYPE decfloat34,
             first_position TYPE i,
           END OF ty_group,
           tt_groups TYPE HASHED TABLE OF ty_group WITH UNIQUE KEY
             item-role_code item-posting_context item-hkont item-partner
             item-posting_side item-waers item-kostl item-prctr item-campana
             item-allocation item-zuonr,
           tt_ordered TYPE STANDARD TABLE OF ty_group WITH EMPTY KEY.
    DATA groups TYPE tt_groups.
    DATA position TYPE i.
    TRY.
        LOOP AT it_items INTO DATA(item).
          position += 1.
          ASSIGN groups[ KEY primary_key COMPONENTS
            item-role_code = item-role_code item-posting_context = item-posting_context
            item-hkont = item-hkont item-partner = item-partner
            item-posting_side = item-posting_side item-waers = item-waers
            item-kostl = item-kostl item-prctr = item-prctr item-campana = item-campana
            item-allocation = item-allocation item-zuonr = item-zuonr ] TO FIELD-SYMBOL(<group>).
          IF sy-subrc = 0.
            <group>-total += CONV decfloat34( item-amount ).
          ELSE.
            INSERT VALUE #( item = item total = CONV decfloat34( item-amount )
              first_position = position ) INTO TABLE groups.
          ENDIF.
        ENDLOOP.
        IF lines( groups ) > zif_reing_ca_c=>recl_max_document_items.
          trans_error( iv_number = zif_reing_ca_c=>recl_message-grouped_item_limit iv_v1 = CONV #( mv_doc_type_code ) ).
          RETURN.
        ENDIF.
        DATA(ordered) = CORRESPONDING tt_ordered( groups ).
        SORT ordered BY first_position.
        LOOP AT ordered INTO DATA(group).
          group-item-item_num = sy-tabix.
          group-item-amount = CONV zreing_ca_line_a-net_amt( group-total ).
          APPEND group-item TO rt_items.
        ENDLOOP.
      CATCH cx_sy_arithmetic_error cx_sy_conversion_error.
        CLEAR rt_items.
        trans_error( iv_number = zif_reing_ca_c=>recl_message-grouped_amount_overflow iv_v1 = CONV #( mv_doc_type_code ) ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

