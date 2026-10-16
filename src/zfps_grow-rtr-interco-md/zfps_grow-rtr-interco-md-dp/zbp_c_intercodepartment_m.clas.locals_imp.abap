CLASS lhc_rule DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS lc_state_area TYPE string VALUE 'VALIDATE_DUPLICATED'.

    " una fila por regla candidata, deduplicada por Item (UUID)
    TYPES: BEGIN OF ty_candidate,
             item          TYPE zint_a_md_dpi-item,
             dpto          TYPE zint_a_md_dpi-dpto,
             company_code  TYPE zint_a_md_dpi-company_code,
             product       TYPE zint_a_md_dpi-product,
             p_and_l_id    TYPE zint_a_md_dpi-p_and_l_id,
             profit_center TYPE zint_a_md_dpi-profit_center,
           END OF ty_candidate.

    TYPES tt_candidate TYPE SORTED TABLE OF ty_candidate
                       WITH UNIQUE KEY item.

    " indice de colisiones: una fila por combinacion, con la cantidad de
    " reglas distintas que la usan y hasta dos departamentos involucrados
    TYPES: BEGIN OF ty_collision,
             company_code  TYPE zint_a_md_dpi-company_code,
             product       TYPE zint_a_md_dpi-product,
             p_and_l_id    TYPE zint_a_md_dpi-p_and_l_id,
             profit_center TYPE zint_a_md_dpi-profit_center,
             cnt           TYPE i,
             dpto1         TYPE zint_a_md_dpi-dpto,
             dpto2         TYPE zint_a_md_dpi-dpto,
           END OF ty_collision.

    TYPES tt_collision TYPE SORTED TABLE OF ty_collision
                       WITH UNIQUE KEY company_code product p_and_l_id profit_center.

    METHODS ValidateDuplicated FOR VALIDATE ON SAVE
      IMPORTING keys FOR Rule~ValidateDuplicated.

ENDCLASS.

CLASS lhc_rule IMPLEMENTATION.

  METHOD ValidateDuplicated.
***    READ ENTITIES OF zc_intercodepartment_m IN LOCAL MODE
***    ENTITY rule
***    FIELDS ( item companycode department pandlid product profitcenter )
***    WITH CORRESPONDING #( keys )
***     RESULT DATA(department_rules).
***
***    LOOP AT keys REFERENCE INTO DATA(key).
***
***      DATA(duplicate_rules) = department_rules.
***      DELETE duplicate_rules WHERE item <> key->item.
***
***      IF lines(  duplicate_rules ) > 0.
***        APPEND VALUE #( %tky = key->%tky ) TO failed-department.
***        APPEND VALUE #( %tky        = key->%tky
***                        %state_area = 'VALIDATE_DUPLICATED'
***                        %msg        = new_message(
***                                        id       = 'ZFI_INTERCO'
***                                        number   = 212
***                                        severity = if_abap_behv_message=>severity-error )
***        ) TO reported-rule.
***
***      ENDIF.
***
***    ENDLOOP.

    "-------------------------------------------------------------------
    " DF-512 / S 5000052272
    " La combinacion Sociedad + Material + P&L + Centro de beneficio debe
    " ser unica en TODA la tabla de reglas, no solo dentro del mismo
    " departamento. Se controla contra:
    "   a) lo ya persistido en ZINT_A_MD_DPI (cualquier depto activo)
    "   b) las propias filas del lote que se graba (carga masiva)
    " Quedan excluidos los deptos marcados como borrados (IS_DELETED).
    "-------------------------------------------------------------------
    " Se arma un indice de colisiones por combinacion en una sola pasada y
    " cada regla se resuelve con un unico acceso por clave, sin LOOPs anidados.
    DATA: lt_candidates TYPE tt_candidate,
          lt_collisions TYPE tt_collision,
          lt_r_pandl    TYPE RANGE OF zint_a_md_dpi-p_and_l_id,
          lv_dup_depto  TYPE zint_a_md_dpi-dpto.

    " 1. Obtener datos del Draft (altas y modificaciones, incl. carga masiva)
    READ ENTITIES OF zc_intercodepartment_m IN LOCAL MODE
      ENTITY Rule
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_current_rules).

    IF lt_current_rules IS INITIAL. RETURN. ENDIF.

    " 2. Normalizacion de los valores de entrada y armado de candidatos.
    "    Las filas del lote entran primero: para una regla que se esta
    "    modificando, sus valores priman sobre los de la base.
    DATA(lt_norm) = lt_current_rules.

    LOOP AT lt_norm ASSIGNING FIELD-SYMBOL(<ls_norm>).

      CONDENSE: <ls_norm>-CompanyCode,
                <ls_norm>-Product,
                <ls_norm>-PAndLId,
                <ls_norm>-ProfitCenter.

      IF <ls_norm>-Product CO '0123456789' AND <ls_norm>-Product IS NOT INITIAL.
        <ls_norm>-Product = |{ <ls_norm>-Product ALPHA = IN }|.
      ENDIF.

      IF <ls_norm>-ProfitCenter CO '0123456789' AND <ls_norm>-ProfitCenter IS NOT INITIAL.
        <ls_norm>-ProfitCenter = |{ <ls_norm>-ProfitCenter ALPHA = IN }|.
      ENDIF.

      INSERT VALUE #( item          = <ls_norm>-Item
                      dpto          = <ls_norm>-Department
                      company_code  = <ls_norm>-CompanyCode
                      product       = <ls_norm>-Product
                      p_and_l_id    = <ls_norm>-PAndLId
                      profit_center = <ls_norm>-ProfitCenter )
             INTO TABLE lt_candidates.

      APPEND VALUE #( sign = 'I' option = 'EQ' low = <ls_norm>-PAndLId ) TO lt_r_pandl.

    ENDLOOP.

    SORT lt_r_pandl BY low.
    DELETE ADJACENT DUPLICATES FROM lt_r_pandl COMPARING low.

    " 3. Reglas ya persistidas en CUALQUIER departamento activo
    SELECT i~dpto, i~item, i~company_code, i~product, i~p_and_l_id, i~profit_center
      FROM zint_a_md_dpi AS i
      INNER JOIN zint_a_md_dph AS h ON h~depto = i~dpto
      WHERE i~p_and_l_id IN @lt_r_pandl
        AND h~is_deleted  = @abap_false
      INTO TABLE @DATA(lt_db_duplicates).

    LOOP AT lt_db_duplicates ASSIGNING FIELD-SYMBOL(<fs_db>).

      CONDENSE: <fs_db>-company_code,
                <fs_db>-product,
                <fs_db>-p_and_l_id,
                <fs_db>-profit_center.

      " si el Item ya vino del lote se descarta (sy-subrc = 4): gana el draft
      INSERT VALUE #( item          = <fs_db>-item
                      dpto          = <fs_db>-dpto
                      company_code  = <fs_db>-company_code
                      product       = <fs_db>-product
                      p_and_l_id    = <fs_db>-p_and_l_id
                      profit_center = <fs_db>-profit_center )
             INTO TABLE lt_candidates.

    ENDLOOP.

    " 4. Indice de colisiones por combinacion, en una sola pasada
    LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<ls_cand>).

      READ TABLE lt_collisions ASSIGNING FIELD-SYMBOL(<ls_col>)
           WITH TABLE KEY company_code  = <ls_cand>-company_code
                          product       = <ls_cand>-product
                          p_and_l_id    = <ls_cand>-p_and_l_id
                          profit_center = <ls_cand>-profit_center.

      IF sy-subrc <> 0.
        INSERT VALUE #( company_code  = <ls_cand>-company_code
                        product       = <ls_cand>-product
                        p_and_l_id    = <ls_cand>-p_and_l_id
                        profit_center = <ls_cand>-profit_center
                        cnt           = 1
                        dpto1         = <ls_cand>-dpto )
               INTO TABLE lt_collisions.
        CONTINUE.
      ENDIF.

      <ls_col>-cnt = <ls_col>-cnt + 1.

      " se retiene el primer departamento distinto, para poder informarlo
      IF <ls_col>-dpto2 IS INITIAL AND <ls_cand>-dpto <> <ls_col>-dpto1.
        <ls_col>-dpto2 = <ls_cand>-dpto.
      ENDIF.

    ENDLOOP.

    " 5. Control: un unico acceso por clave para cada regla del lote
    LOOP AT lt_norm REFERENCE INTO DATA(ls_rule).

      "LIMPIEZA
      APPEND VALUE #( %tky        = ls_rule->%tky
                      %state_area = lc_state_area ) TO reported-rule.

      READ TABLE lt_collisions REFERENCE INTO DATA(ls_col)
           WITH TABLE KEY company_code  = ls_rule->CompanyCode
                          product       = ls_rule->Product
                          p_and_l_id    = ls_rule->PAndLId
                          profit_center = ls_rule->ProfitCenter.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " cnt incluye a la propia regla: hay duplicado solo si hay mas de una
      IF ls_col->cnt <= 1.
        CONTINUE.
      ENDIF.

      " se prioriza informar el choque contra otro departamento
      IF ls_col->dpto1 <> ls_rule->Department.
        lv_dup_depto = ls_col->dpto1.
      ELSEIF ls_col->dpto2 IS NOT INITIAL.
        lv_dup_depto = ls_col->dpto2.
      ELSE.
        lv_dup_depto = ls_rule->Department.
      ENDIF.

      APPEND VALUE #( %tky = ls_rule->%tky ) TO failed-rule.

      IF lv_dup_depto <> ls_rule->Department.

        " duplicado en OTRO departamento
        " sin %state_area: debe ser un transition message para que el
        " framework OData lo asocie a la clave marcada en failed-rule
        APPEND VALUE #( %tky        = ls_rule->%tky
                        %msg        = new_message( id       = 'ZFI_INTERCO'
                                                   number   = '216'
                                                   severity = if_abap_behv_message=>severity-error
                                                   v1       = ls_rule->PAndLId
                                                   v2       = lv_dup_depto
                                                   v3       = ls_rule->CompanyCode
                                                   v4       = ls_rule->Product )
                        %element-CompanyCode = if_abap_behv=>mk-on
                        %element-Product     = if_abap_behv=>mk-on
                        %element-PAndLId     = if_abap_behv=>mk-on
                        ) TO reported-rule.
      ELSE.

        " duplicado dentro del mismo departamento (comportamiento previo)
        APPEND VALUE #( %tky        = ls_rule->%tky
                        %msg        = new_message( id = 'ZFI_INTERCO' number = '212' severity = if_abap_behv_message=>severity-error )
                        %element-CompanyCode = if_abap_behv=>mk-on
                        %element-Product     = if_abap_behv=>mk-on
                        %element-PAndLId     = if_abap_behv=>mk-on
                        ) TO reported-rule.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zc_intercodepartment_m DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zc_intercodepartment_m IMPLEMENTATION.

  METHOD save_modified.
    IF create-department IS NOT INITIAL OR
       update-department IS NOT INITIAL OR
       delete-department IS NOT INITIAL.
*      zcl_interco=>log->save(
*        iv_tablename = 'ZINT_A_MD_DPH'
*        iv_objectid = 'ZINT_A_MD_DP'
*        it_creates   = create-department
*        it_updates   = update-department
*        it_deletes   = delete-department ).
    ENDIF.

    IF create-rule IS NOT INITIAL OR
       update-rule IS NOT INITIAL OR
       delete-rule IS NOT INITIAL.
*      zcl_interco=>log->save(
*        iv_tablename = 'ZINT_A_MD_DPI'
*        iv_objectid = 'ZINT_A_MD_DP'
*        it_creates   = create-rule
*        it_updates   = update-rule
*        it_deletes   = delete-rule ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_department DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR department RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR department RESULT result.
    METHODS delete FOR MODIFY
      IMPORTING keys FOR ACTION department~delete.
    METHODS ValidateDuplicated FOR VALIDATE ON SAVE
      IMPORTING keys FOR Department~ValidateDuplicated.

ENDCLASS.

CLASS lhc_department IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD delete.
    READ ENTITIES OF zc_intercodepartment_m IN LOCAL MODE
          ENTITY department
          ALL FIELDS WITH CORRESPONDING #( keys )
              RESULT DATA(current_items).

    MODIFY ENTITIES OF zc_intercodepartment_m IN LOCAL MODE
           ENTITY department
              UPDATE FIELDS ( isdeleted )
                 WITH VALUE #( FOR key IN keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 isdeleted = abap_true ) ).
  ENDMETHOD.

  METHOD ValidateDuplicated.

*    SELECT zi_intercodepartment~department, COUNT( * ) AS count FROM zi_intercodepartment
*      INNER JOIN @keys AS _keys ON _keys~department = zi_intercodepartment~department
*            GROUP BY zi_intercodepartment~department
*      INTO TABLE @DATA(duplicate_department).
*
*    LOOP AT keys REFERENCE INTO DATA(key).
*
*      IF line_exists( duplicate_department[ department = key->department ] ).
*        APPEND VALUE #( %tky = key->%tky ) TO failed-department.
*        APPEND VALUE #( %tky        = key->%tky
*                        %state_area = 'VALIDATE_DUPLICATED'
*                        %msg        = new_message(
*                                        id       = 'ZFI_INTERCO'
*                                        number   = 212
*                                        severity = if_abap_behv_message=>severity-error )
*        ) TO reported-department.
*      ENDIF.
*
*    ENDLOOP.
    " Optimización Clean Core para el Padre (Department)
    SELECT depto FROM zint_a_md_dph
      FOR ALL ENTRIES IN @keys
      WHERE depto = @keys-department
      INTO TABLE @DATA(lt_existing_depts).

    LOOP AT keys REFERENCE INTO DATA(key).

      APPEND VALUE #( %tky = key->%tky %state_area = 'VALIDATE_DUPLICATED' )
             TO reported-department.

      IF line_exists( lt_existing_depts[ depto = key->department ] ).

        APPEND VALUE #( %tky = key->%tky ) TO failed-department.

        APPEND VALUE #( %tky        = key->%tky
                        %state_area = 'VALIDATE_DUPLICATED'
                        %msg        = new_message(
                                        id       = 'ZFI_INTERCO'
                                        number   = '212'
                                        severity = if_abap_behv_message=>severity-error )
                        %element-Department = if_abap_behv=>mk-on
        ) TO reported-department.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
