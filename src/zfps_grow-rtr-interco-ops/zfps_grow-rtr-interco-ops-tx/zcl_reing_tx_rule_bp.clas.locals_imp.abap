" V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
CLASS ltcl_tx_scope DEFINITION DEFERRED FOR TESTING.
CLASS lcl_tx_fixture IMPLEMENTATION.
ENDCLASS.

CLASS lhc_TxRule DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_tx_scope.

  PRIVATE SECTION.

    " V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
    DATA mv_isolated_test TYPE abap_bool.


    CONSTANTS:
      BEGIN OF c_status,
        active   TYPE c LENGTH 2 VALUE 'AC',
        inactive TYPE c LENGTH 2 VALUE 'IN',
      END OF c_status.

    " Buffer temporal de reglas activas para el chequeo de solape (validate_overlap).
    DATA mt_active_overlap TYPE STANDARD TABLE OF zreing_tx_rule_a WITH EMPTY KEY.

    METHODS has_overlap
      IMPORTING iv_rule_id    TYPE zreing_tx_rule_a-tx_rule_id
                iv_country    TYPE zreing_tx_rule_a-country
                iv_tax_type   TYPE zreing_tx_rule_a-tax_type
                iv_matnr      TYPE zreing_tx_rule_a-matnr
                iv_lifnr      TYPE zreing_tx_rule_a-lifnr
                iv_from       TYPE zreing_tx_rule_a-valid_from
                iv_to         TYPE zreing_tx_rule_a-valid_to
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS generate_id FOR NUMBERING
      IMPORTING entities FOR CREATE TxRule.

    METHODS set_defaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TxRule~SetDefaults.

    METHODS set_admin_fields FOR DETERMINE ON SAVE
      IMPORTING keys FOR TxRule~SetAdminFields.

    METHODS validate_country FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateCountry.

    METHODS validate_tax_type FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateTaxType.

    METHODS validate_material FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateMaterial.

    METHODS validate_supplier FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateSupplier.

    METHODS validate_rate FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateRate.

    METHODS validate_validity FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateValidity.

    METHODS validate_overlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR TxRule~ValidateOverlap.

    METHODS activateRule FOR MODIFY
      IMPORTING keys FOR ACTION TxRule~ActivateRule RESULT result.

    METHODS deactivate FOR MODIFY
      IMPORTING keys FOR ACTION TxRule~Deactivate RESULT result.

    METHODS copyRule FOR MODIFY
      IMPORTING keys FOR ACTION TxRule~CopyRule.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TxRule RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TxRule RESULT result.
    METHODS UploadRules FOR MODIFY
      IMPORTING keys FOR ACTION TxRule~UploadRules.

    METHODS DownloadTemplate FOR MODIFY
      IMPORTING keys FOR ACTION TxRule~DownloadTemplate RESULT result.

ENDCLASS.

CLASS lhc_TxRule IMPLEMENTATION.

  METHOD generate_id.
    " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
    " Early numbering: la key semantica pasa de TX-<Pais>-<Tipo>-<NNN> a
    " TX-<Tipo>-<NNN>, secuencial por TAX_TYPE (consulta A-12(3), definicion
    " del arquitecto: "Formato TX-{TaxType}-NNN (secuencial por TAX_TYPE).
    " Simple, sin ambiguedad. Los campos de matching quedan visibles en la
    " lista pero no componen el ID").
    "
    " POR QUE cambia: con COUNTRY opcional (SS4.8) el ID degeneraba en
    " "TX--PIS-001", y ademas para Brasil el pais discriminante es el de la
    " PRESTADORA, no el de la receptora, con lo que el segmento de pais perdia
    " significado.
    "
    " DECISION SOBRE LOS IDs YA EMITIDOS (15.09.2026): el formato nuevo aplica
    " SOLO a las reglas nuevas. Los IDs existentes -- 5 en DS4, 35 en TS4 -- NO
    " se renombran, y no se toca ZREING_CA_STEP_A-TX_RULE_ID, que es la traza
    " de auditoria de calculos ya contabilizados. Conviven los dos formatos.
    " El parser de abajo los ignora sin ruido: con el prefijo nuevo "TX-CIDE-",
    " un ID viejo "TX-BR-CIDE-001" deja el sufijo "E-001", que no pasa el
    " CO '0123456789', asi que cae en el CONTINUE y no interfiere con el
    " contador. Verificado contra los 5 IDs de DS4 y los 3 tipos afectados.
    TYPES: BEGIN OF ty_max,
             prefix TYPE string,
             maxnum TYPE i,
           END OF ty_max.
    DATA lt_max TYPE SORTED TABLE OF ty_max WITH UNIQUE KEY prefix.

    " 1) Un unico SELECT de todos los IDs existentes para los TaxType del lote.
    "    V009: el ambito del contador ya no incluye Country.
    DATA lt_keys TYPE TABLE OF zreing_tx_rule_a.
    LOOP AT entities INTO DATA(ls_e) WHERE TxRuleId IS INITIAL.
      APPEND VALUE #( tax_type = ls_e-TaxType ) TO lt_keys.
    ENDLOOP.

    DATA lt_ids TYPE TABLE OF zreing_tx_rule_a.
    IF lt_keys IS NOT INITIAL.
      SORT lt_keys BY tax_type.
      DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING tax_type.
      SELECT tx_rule_id, tax_type
        FROM zreing_tx_rule_a
        FOR ALL ENTRIES IN @lt_keys
        WHERE tax_type = @lt_keys-tax_type
        INTO CORRESPONDING FIELDS OF TABLE @lt_ids.
    ENDIF.

    " 2) Calcular el maximo por prefijo (sin loops anidados: un solo recorrido).
    LOOP AT lt_ids INTO DATA(ls_id).
      DATA(lv_pfx)  = |TX-{ ls_id-tax_type }-|.
      DATA(lv_plen) = strlen( lv_pfx ).
      IF strlen( ls_id-tx_rule_id ) <= lv_plen.
        CONTINUE.
      ENDIF.
      DATA(lv_sfx) = condense( CONV string( ls_id-tx_rule_id+lv_plen ) ).
      CHECK lv_sfx CO '0123456789' AND lv_sfx IS NOT INITIAL.
      DATA(lv_num) = CONV i( lv_sfx ).
      READ TABLE lt_max ASSIGNING FIELD-SYMBOL(<m>) WITH KEY prefix = lv_pfx.
      IF sy-subrc <> 0.
        INSERT VALUE #( prefix = lv_pfx maxnum = lv_num ) INTO TABLE lt_max ASSIGNING <m>.
      ELSEIF lv_num > <m>-maxnum.
        <m>-maxnum = lv_num.
      ENDIF.
    ENDLOOP.

    " 3) Asignar la key a cada instancia (incrementando el contador por prefijo en memoria).
    LOOP AT entities INTO DATA(ls_ent).
      IF ls_ent-TxRuleId IS NOT INITIAL.
        APPEND VALUE #( %cid      = ls_ent-%cid
                        %key      = ls_ent-%key
                        %is_draft = ls_ent-%is_draft ) TO mapped-txrule.
        CONTINUE.
      ENDIF.

      DATA(lv_prefix) = |TX-{ ls_ent-TaxType }-|.
      READ TABLE lt_max ASSIGNING <m> WITH KEY prefix = lv_prefix.
      IF sy-subrc <> 0.
        INSERT VALUE #( prefix = lv_prefix maxnum = 0 ) INTO TABLE lt_max ASSIGNING <m>.
      ENDIF.
      <m>-maxnum += 1.
      DATA(lv_id) = |{ lv_prefix }{ <m>-maxnum WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.

      APPEND VALUE #( %cid      = ls_ent-%cid
                      %is_draft = ls_ent-%is_draft
                      TxRuleId  = lv_id ) TO mapped-txrule.
    ENDLOOP.
    " End Change ID V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD set_defaults.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        FIELDS ( TaxType TxStatus ValidTo GrossUp )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    " Un solo SELECT del catalogo para todos los TaxType del lote.
    DATA lt_types TYPE TABLE OF zreing_tx_type_c.
    LOOP AT lt_rules INTO DATA(ls_pre) WHERE TaxType IS NOT INITIAL AND GrossUp IS INITIAL.
      APPEND VALUE #( tax_type = ls_pre-TaxType ) TO lt_types.
    ENDLOOP.

    DATA lt_gu TYPE SORTED TABLE OF zreing_tx_type_c WITH UNIQUE KEY tax_type.
    IF lt_types IS NOT INITIAL.
      SORT lt_types BY tax_type.
      DELETE ADJACENT DUPLICATES FROM lt_types COMPARING tax_type.
      SELECT tax_type, gross_up_default
        FROM zreing_tx_type_c
        FOR ALL ENTRIES IN @lt_types
        WHERE tax_type = @lt_types-tax_type
        INTO CORRESPONDING FIELDS OF TABLE @lt_gu.
    ENDIF.

    DATA lt_update TYPE TABLE FOR UPDATE ZI_ReingTXRule.

    LOOP AT lt_rules INTO DATA(ls_rule).
      DATA(lv_status)   = ls_rule-TxStatus.
      DATA(lv_valid_to) = ls_rule-ValidTo.
      DATA(lv_grossup)  = ls_rule-GrossUp.

      IF lv_status IS INITIAL.
        lv_status = c_status-active.
      ENDIF.
      IF lv_valid_to IS INITIAL.
        lv_valid_to = '99991231'.
      ENDIF.
      IF ls_rule-TaxType IS NOT INITIAL AND lv_grossup IS INITIAL.
        READ TABLE lt_gu INTO DATA(ls_gu) WITH KEY tax_type = ls_rule-TaxType.
        IF sy-subrc = 0.
          lv_grossup = ls_gu-gross_up_default.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky     = ls_rule-%tky
                      TxStatus = lv_status
                      ValidTo  = lv_valid_to
                      GrossUp  = lv_grossup ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        UPDATE FIELDS ( TxStatus ValidTo GrossUp )
        WITH lt_update.
  ENDMETHOD.

  METHOD set_admin_fields.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        FIELDS ( CreatedAt CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    GET TIME STAMP FIELD DATA(lv_now).

    DATA lt_update TYPE TABLE FOR UPDATE ZI_ReingTXRule.
    DATA ls_upd    TYPE STRUCTURE FOR UPDATE ZI_ReingTXRule.

    LOOP AT lt_rules INTO DATA(ls_rule).
      CLEAR ls_upd.
      ls_upd-%tky               = ls_rule-%tky.
      ls_upd-ChangedBy          = sy-uname.
      ls_upd-ChangedAt          = lv_now.
      ls_upd-LocalLastChangedAt = lv_now.
      IF ls_rule-CreatedAt IS INITIAL.
        ls_upd-CreatedBy = sy-uname.
        ls_upd-CreatedAt = lv_now.
      ENDIF.
      APPEND ls_upd TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        UPDATE FIELDS ( CreatedBy CreatedAt ChangedBy ChangedAt LocalLastChangedAt )
        WITH lt_update.
  ENDMETHOD.

  METHOD validate_country.
    " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4 -- specificity engine on 6 matching fields.
    "
    " Two changes here:
    "
    " 1) COUNTRY IS NO LONGER MANDATORY. It used to be rejected when empty
    "    ("El pais es obligatorio", BR-TX-02 of ET-REING-TX-001 v2, which also
    "    declares it "Siempre informado / nunca vacio"). Under the new engine an
    "    empty field is a WILDCARD that matches any country and scores 0 -- see
    "    the WHERE clause of SS4.5, "( country = @iv_country OR country = '' )".
    "    Confirmed by the architect, consulta A-12(2): "Pais obligatorio:
    "    RELAJAR. Si informado -> debe existir en T005; si vacio -> aceptar."
    "    The field stays visible in the UI, it just is not enforced any more.
    "    NOTE for the cutover (consulta A-03): rules with COUNTRY empty are
    "    unreachable TODAY, because ZCL_REING_CA_SOURCES~get_tx_rules filters
    "    "country = @iv_country". Once that filter becomes a wildcard, any such
    "    pre-existing row starts applying to EVERY country. DS4 is safe (5/5
    "    rules have a country), but TS4/PRD must be checked before the deploy:
    "    SELECT * FROM zreing_tx_rule_a WHERE country = '' AND tx_status = 'AC'.
    "
    " 2) IT NOW ALSO VALIDATES COUNTRY_PREST, BUKRS_PREST AND BUKRS_RECV.
    "    They belong in a validation of their own, but declaring one would mean
    "    adding a method to the DEFINITION of this local class, which cannot be
    "    edited over ADT (the include has to be replaced whole, by hand in
    "    Eclipse). Folding them into the existing validation keeps the change
    "    inside a method body. The BDEF trigger list was widened to the four
    "    fields accordingly. PENDING: split into validate_scope_fields whenever
    "    a change does require touching the DEFINITION anyway.
    "
    " Countries are read from I_Country and company codes from I_CompanyCode:
    " T005/T001 are blocked by Clean Core in this system, so SS4.7.1 ("FK to
    " T005 / T001") is not implementable literally.
    DATA lt_rules TYPE TABLE FOR READ RESULT zi_reingtxrule.
    " V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
    TEST-SEAM tx_scope_read.
      IF mv_isolated_test = abap_true.
        RETURN.
      ENDIF.
      READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
        ENTITY TxRule FIELDS ( Country CountryPrest BukrsPrest BukrsRecv )
        WITH CORRESPONDING #( keys )
        RESULT lt_rules.
    END-TEST-SEAM.

    " Un solo SELECT de paises existentes para todos los valores del lote --
    " ahora alimentado por los DOS campos de pais (receptora y prestadora).
    TYPES: BEGIN OF ty_c, country TYPE land1, END OF ty_c.
    DATA lt_cty TYPE TABLE OF ty_c.
    LOOP AT lt_rules INTO DATA(ls_pre).
      IF ls_pre-Country IS NOT INITIAL.
        APPEND VALUE #( country = ls_pre-Country ) TO lt_cty.
      ENDIF.
      IF ls_pre-CountryPrest IS NOT INITIAL.
        APPEND VALUE #( country = ls_pre-CountryPrest ) TO lt_cty.
      ENDIF.
    ENDLOOP.

    DATA lt_exist TYPE SORTED TABLE OF ty_c WITH UNIQUE KEY country.
    IF lt_cty IS NOT INITIAL.
      SORT lt_cty BY country.
      DELETE ADJACENT DUPLICATES FROM lt_cty COMPARING country.
      SELECT country FROM i_country WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @lt_cty
        WHERE country = @lt_cty-country
        INTO TABLE @lt_exist.
    ENDIF.

    " V009: mismo patron para las sociedades (prestadora y receptora).
    TYPES: BEGIN OF ty_b, bukrs TYPE bukrs, END OF ty_b.
    DATA lt_buk TYPE TABLE OF ty_b.
    LOOP AT lt_rules INTO DATA(ls_pre_b).
      IF ls_pre_b-BukrsPrest IS NOT INITIAL.
        APPEND VALUE #( bukrs = ls_pre_b-BukrsPrest ) TO lt_buk.
      ENDIF.
      IF ls_pre_b-BukrsRecv IS NOT INITIAL.
        APPEND VALUE #( bukrs = ls_pre_b-BukrsRecv ) TO lt_buk.
      ENDIF.
    ENDLOOP.

    DATA lt_buk_exist TYPE SORTED TABLE OF ty_b WITH UNIQUE KEY bukrs.
    IF lt_buk IS NOT INITIAL.
      SORT lt_buk BY bukrs.
      DELETE ADJACENT DUPLICATES FROM lt_buk COMPARING bukrs.
      SELECT companycode AS bukrs FROM i_companycode WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @lt_buk
        WHERE companycode = @lt_buk-bukrs
        INTO TABLE @lt_buk_exist.
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      " V009: el bloque que rechazaba el pais vacio se retiro. Lineas
      " originales conservadas como referencia:
      "    IF ls_rule-Country IS INITIAL.
      "      ... 'El pais es obligatorio' ...
      "      CONTINUE.
      "    ENDIF.
      IF ls_rule-Country IS NOT INITIAL
         AND NOT line_exists( lt_exist[ country = ls_rule-Country ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Pais { ls_rule-Country } inexistente| )
                        %element-Country = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.

      IF ls_rule-CountryPrest IS NOT INITIAL
         AND NOT line_exists( lt_exist[ country = ls_rule-CountryPrest ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Pais de prestadora { ls_rule-CountryPrest } inexistente| )
                        %element-CountryPrest = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.

      IF ls_rule-BukrsPrest IS NOT INITIAL
         AND NOT line_exists( lt_buk_exist[ bukrs = ls_rule-BukrsPrest ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Sociedad prestadora { ls_rule-BukrsPrest } inexistente| )
                        %element-BukrsPrest = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.

      IF ls_rule-BukrsRecv IS NOT INITIAL
         AND NOT line_exists( lt_buk_exist[ bukrs = ls_rule-BukrsRecv ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Sociedad receptora { ls_rule-BukrsRecv } inexistente| )
                        %element-BukrsRecv = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
    " End Change ID V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD validate_tax_type.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( TaxType )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    " Un solo SELECT del catalogo (activos) para todos los TaxType del lote.
    DATA lt_types TYPE TABLE OF zreing_tx_type_c.
    LOOP AT lt_rules INTO DATA(ls_pre) WHERE TaxType IS NOT INITIAL.
      APPEND VALUE #( tax_type = ls_pre-TaxType ) TO lt_types.
    ENDLOOP.

    DATA lt_valid TYPE SORTED TABLE OF zreing_tx_type_c WITH UNIQUE KEY tax_type.
    IF lt_types IS NOT INITIAL.
      SORT lt_types BY tax_type.
      DELETE ADJACENT DUPLICATES FROM lt_types COMPARING tax_type.
      SELECT tax_type FROM zreing_tx_type_c
        FOR ALL ENTRIES IN @lt_types
        WHERE tax_type = @lt_types-tax_type
          AND active   = 'X'
        INTO CORRESPONDING FIELDS OF TABLE @lt_valid.
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-TaxType IS INITIAL OR NOT line_exists( lt_valid[ tax_type = ls_rule-TaxType ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Tipo impositivo { ls_rule-TaxType } inexistente o inactivo| )
                        %element-TaxType = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_material.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( Matnr )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    " Un solo SELECT de materiales existentes para todos los del lote.
    TYPES: BEGIN OF ty_m, product TYPE matnr, END OF ty_m.
    DATA lt_mat TYPE TABLE OF ty_m.
    LOOP AT lt_rules INTO DATA(ls_pre) WHERE Matnr IS NOT INITIAL.
      APPEND VALUE #( product = ls_pre-Matnr ) TO lt_mat.
    ENDLOOP.

    DATA lt_exist TYPE SORTED TABLE OF ty_m WITH UNIQUE KEY product.
    IF lt_mat IS NOT INITIAL.
      SORT lt_mat BY product.
      DELETE ADJACENT DUPLICATES FROM lt_mat COMPARING product.
      SELECT product FROM i_product WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @lt_mat
        WHERE product = @lt_mat-product
        INTO TABLE @lt_exist.
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-Matnr IS INITIAL.
        CONTINUE.
      ENDIF.
      IF NOT line_exists( lt_exist[ product = ls_rule-Matnr ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Material { ls_rule-Matnr } inexistente| )
                        %element-Matnr = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_supplier.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( Lifnr )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    " Un solo SELECT de proveedores existentes para todos los del lote.
    TYPES: BEGIN OF ty_s, supplier TYPE lifnr, END OF ty_s.
    DATA lt_sup TYPE TABLE OF ty_s.
    LOOP AT lt_rules INTO DATA(ls_pre) WHERE Lifnr IS NOT INITIAL.
      APPEND VALUE #( supplier = ls_pre-Lifnr ) TO lt_sup.
    ENDLOOP.

    DATA lt_exist TYPE SORTED TABLE OF ty_s WITH UNIQUE KEY supplier.
    IF lt_sup IS NOT INITIAL.
      SORT lt_sup BY supplier.
      DELETE ADJACENT DUPLICATES FROM lt_sup COMPARING supplier.
      SELECT supplier FROM i_supplier WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @lt_sup
        WHERE supplier = @lt_sup-supplier
        INTO TABLE @lt_exist.
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-Lifnr IS INITIAL.
        CONTINUE.
      ENDIF.
      IF NOT line_exists( lt_exist[ supplier = ls_rule-Lifnr ] ).
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Proveedor { ls_rule-Lifnr } inexistente| )
                        %element-Lifnr = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_rate.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( Rate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-Rate < 0 OR ls_rule-Rate > 100.
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'La tasa debe ser de 0 a 100' )
                        %element-Rate = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_validity.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( ValidFrom ValidTo )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-ValidFrom IS INITIAL OR ls_rule-ValidTo IS INITIAL.
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Vigencia desde/hasta son obligatorias' )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on
                      ) TO reported-txrule.
        CONTINUE.
      ENDIF.
      IF ls_rule-ValidFrom > ls_rule-ValidTo.
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Vigencia Desde no puede ser mayor que Hasta' )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_overlap.
    " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4 -- the overlap scope grows from 4 to 7 fields.
    "
    " WHY THIS IS BLOCKING for Brazil (consulta A-12(1), confirmed by the
    " architect): the scope used to be COUNTRY + TAX_TYPE + MATNR + LIFNR, so
    " two rules differing ONLY in COUNTRY_PREST / BUKRS_PREST / BUKRS_RECV
    " looked identical and the app rejected the second one as a duplicate.
    " That is exactly the central use case -- "IMP_X 10% general" next to
    " "IMP_X 0% exclusion BR" (SS4.4) -- and also the rule that closes bug #69
    " (MUR -> MUR excluded from WHT while the generic UY rule keeps its 12%).
    "
    " HOW, without touching the DEFINITION: has_overlap takes the scope through
    " its signature, and adding parameters to it would mean editing the
    " DEFINITION of this local class, which cannot be done over ADT. But it
    " reads the CANDIDATES from the mt_active_overlap attribute, which is
    " TYPE STANDARD TABLE OF zreing_tx_rule_a and therefore already carries the
    " three new columns. So the candidate set is narrowed by the new fields
    " HERE, before each call, and has_overlap keeps both its signature and its
    " body untouched -- it still owns the date-overlap rule.
    DATA lt_rules TYPE TABLE FOR READ RESULT zi_reingtxrule.
    " V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
    TEST-SEAM tx_overlap_read.
      IF mv_isolated_test = abap_true.
        RETURN.
      ENDIF.
      READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
        ENTITY TxRule
          ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT lt_rules.
    END-TEST-SEAM.

    " Un solo SELECT: todas las reglas activas para los pares (country, tax_type) del lote.
    DATA lt_scope TYPE TABLE OF zreing_tx_rule_a.
    LOOP AT lt_rules INTO DATA(ls_pre) WHERE TxStatus = c_status-active.
      APPEND VALUE #( country = ls_pre-Country tax_type = ls_pre-TaxType ) TO lt_scope.
    ENDLOOP.

    IF lt_scope IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_scope BY country tax_type.
    DELETE ADJACENT DUPLICATES FROM lt_scope COMPARING country tax_type.

    " V009: +country_prest, +bukrs_prest, +bukrs_recv en la lista de campos.
    " Sin ellos, CORRESPONDING FIELDS los dejaria vacios y el filtro de abajo
    " compararia siempre contra ''.
    SELECT tx_rule_id, country, country_prest, bukrs_prest, bukrs_recv,
           tax_type, matnr, lifnr, valid_from, valid_to
      FROM zreing_tx_rule_a
      FOR ALL ENTRIES IN @lt_scope
      WHERE country   = @lt_scope-country
        AND tax_type  = @lt_scope-tax_type
        AND tx_status = @c_status-active
      INTO CORRESPONDING FIELDS OF TABLE @mt_active_overlap.

    " V009: copia completa del universo de candidatos. mt_active_overlap se
    " re-arma por regla (ver abajo), asi que el conjunto original tiene que
    " sobrevivir a la iteracion.
    DATA(lt_all_overlap) = mt_active_overlap.

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF ls_rule-TxStatus <> c_status-active.
        CONTINUE.
      ENDIF.

      " V009: candidatos que coinciden con ESTA regla en los 3 campos nuevos.
      " Table comprehension y no LOOP/DELETE: un loop aca quedaria anidado
      " dentro del LOOP AT lt_rules, que es el hallazgo P2 del ATC que bloquea
      " la liberacion a Calidad. Los campos viejos (country/tax_type/matnr/
      " lifnr) y el solape de fechas los sigue comparando has_overlap.
      mt_active_overlap = VALUE #(
        FOR ls_cand IN lt_all_overlap
        WHERE ( country_prest = ls_rule-CountryPrest
            AND bukrs_prest   = ls_rule-BukrsPrest
            AND bukrs_recv    = ls_rule-BukrsRecv )
        ( ls_cand ) ).

      " El chequeo de solape se delega a un metodo privado (evita loop anidado aqui).
      IF has_overlap( iv_rule_id  = ls_rule-TxRuleId
                      iv_country  = ls_rule-Country
                      iv_tax_type = ls_rule-TaxType
                      iv_matnr    = ls_rule-Matnr
                      iv_lifnr    = ls_rule-Lifnr
                      iv_from     = ls_rule-ValidFrom
                      iv_to       = ls_rule-ValidTo ) = abap_true.
        APPEND VALUE #( %tky = ls_rule-%tky ) TO failed-txrule.
        APPEND VALUE #( %tky = ls_rule-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Ya existe una regla activa con el mismo ambito y vigencia solapada' )
                      ) TO reported-txrule.
      ENDIF.
    ENDLOOP.

    CLEAR mt_active_overlap.
    " End Change ID V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD has_overlap.
    " Busca en la tabla de reglas activas (precargada) un solape de ambito + fechas.
    result = abap_false.
    LOOP AT mt_active_overlap TRANSPORTING NO FIELDS
         WHERE country    = iv_country
           AND tax_type   = iv_tax_type
           AND matnr      = iv_matnr
           AND lifnr      = iv_lifnr
           AND tx_rule_id <> iv_rule_id
           AND valid_from <= iv_to
           AND valid_to   >= iv_from.
      result = abap_true.
      EXIT.
    ENDLOOP.
  ENDMETHOD.

  METHOD activateRule.
    MODIFY ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        UPDATE FIELDS ( TxStatus )
        WITH VALUE #( FOR k IN keys ( %tky     = k-%tky
                                      TxStatus = c_status-active ) ).

    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    result = VALUE #( FOR r IN lt_rules ( %tky   = r-%tky
                                          %param = r ) ).
  ENDMETHOD.

  METHOD deactivate.
    MODIFY ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        UPDATE FIELDS ( TxStatus )
        WITH VALUE #( FOR k IN keys ( %tky     = k-%tky
                                      TxStatus = c_status-inactive ) ).

    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    result = VALUE #( FOR r IN lt_rules ( %tky   = r-%tky
                                          %param = r ) ).
  ENDMETHOD.

  METHOD copyRule.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_source).

    DATA lt_create TYPE TABLE FOR CREATE ZI_ReingTXRule.

    LOOP AT lt_source INTO DATA(ls_src).
      APPEND VALUE #( %cid        = |CID_{ sy-tabix }|
                      %is_draft   = if_abap_behv=>mk-on
                      Country     = ls_src-Country
                      TaxType     = ls_src-TaxType
                      Matnr       = ls_src-Matnr
                      Lifnr       = ls_src-Lifnr
                      Rate        = ls_src-Rate
                      GrossUp     = ls_src-GrossUp
                      ValidFrom   = ls_src-ValidFrom
                      ValidTo     = ls_src-ValidTo
                      TxStatus    = c_status-active
                      Description = |Copia de { ls_src-TxRuleId }|
                      Notes       = ls_src-Notes
                    ) TO lt_create.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule
        CREATE FIELDS ( Country TaxType Matnr Lifnr Rate GrossUp
                        ValidFrom ValidTo TxStatus Description Notes )
        WITH lt_create
      MAPPED mapped.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_ReingTXRule IN LOCAL MODE
      ENTITY TxRule FIELDS ( TxRuleId TxStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rules).

    DATA(lv_ca_table_exists) = abap_false.
    SELECT SINGLE @abap_true FROM i_custabapobjdirectoryentry WITH PRIVILEGED ACCESS
      WHERE abapobjecttype = 'TABL'
        AND abapobject     = 'ZREING_CA_STEP_A'
      INTO @lv_ca_table_exists.

    " Un unico SELECT (dinamico) de los IDs en uso en la tabla CA, fuera del loop.
    TYPES: BEGIN OF ty_used, tx_rule_id TYPE zreing_tx_rule_a-tx_rule_id, END OF ty_used.
    DATA lt_used TYPE SORTED TABLE OF ty_used WITH UNIQUE KEY tx_rule_id.

    IF lv_ca_table_exists = abap_true AND lt_rules IS NOT INITIAL.
      DATA lr_ids TYPE RANGE OF zreing_tx_rule_a-tx_rule_id.
      lr_ids = VALUE #( FOR r IN lt_rules
                        ( sign = 'I' option = 'EQ' low = r-TxRuleId ) ).
      TRY.
          SELECT DISTINCT tx_rule_id
            FROM ('ZREING_CA_STEP_A')
            WHERE tx_rule_id IN @lr_ids
            INTO TABLE @lt_used.
        CATCH cx_sy_dynamic_osql_error.
          CLEAR lt_used.
      ENDTRY.
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      DATA(lv_used) = xsdbool( line_exists( lt_used[ tx_rule_id = ls_rule-TxRuleId ] ) ).

      DATA(lv_delete) = COND #( WHEN lv_used = abap_true
                                THEN if_abap_behv=>fc-o-disabled
                                ELSE if_abap_behv=>fc-o-enabled ).

      APPEND VALUE #( %tky                           = ls_rule-%tky
                      %features-%action-ActivateRule = COND #( WHEN ls_rule-TxStatus = c_status-inactive
                                                               THEN if_abap_behv=>fc-o-enabled
                                                               ELSE if_abap_behv=>fc-o-disabled )
                      %features-%action-Deactivate   = COND #( WHEN ls_rule-TxStatus = c_status-active
                                                               THEN if_abap_behv=>fc-o-enabled
                                                               ELSE if_abap_behv=>fc-o-disabled )
                      %features-%delete              = lv_delete
                    ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_global_authorizations.
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD UploadRules.
    " Accion estatica: el parametro viene en keys[ 1 ]-%param
    DATA(ls_key) = keys[ 1 ].

    " --- Decodificar Base64 -> xstring ---
    DATA lv_xcontent TYPE xstring.
    TRY.
        lv_xcontent = xco_cp=>string( ls_key-%param-FileContent
          )->as_xstring( xco_cp_binary=>text_encoding->base64 )->value.
      CATCH cx_root INTO DATA(lx_b64).
        APPEND VALUE #( %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |Error al decodificar: { lx_b64->get_text( ) }| ) )
          TO reported-txrule.
        RETURN.
    ENDTRY.

    IF lv_xcontent IS INITIAL.
      APPEND VALUE #( %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'El contenido del archivo esta vacio.' ) )
        TO reported-txrule.
      RETURN.
    ENDIF.

    " --- Parsear y validar ---
    DATA(lo_hdl) = NEW zcl_reing_tx_upload_hdl( ).
    DATA(ls_imp) = lo_hdl->import_file( iv_file_content = lv_xcontent ).

    IF ls_imp-aborted = abap_true.
      APPEND VALUE #( %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = ls_imp-abort_reason ) )
        TO reported-txrule.
      RETURN.
    ENDIF.

    " Reportar resultados por fila (errores / avisos)
    LOOP AT ls_imp-results INTO DATA(ls_r).
      CASE ls_r-status.
        WHEN 'E'.
          APPEND VALUE #( %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = ls_r-message ) )
            TO reported-txrule.
        WHEN 'W'.
          APPEND VALUE #( %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-warning
                            text     = ls_r-message ) )
            TO reported-txrule.
      ENDCASE.
    ENDLOOP.

    " Si hubo errores o no hay lineas validas, no se crea nada
    DATA lv_has_err TYPE abap_bool VALUE abap_false.
    LOOP AT ls_imp-results INTO DATA(ls_e) WHERE status = 'E'.
      lv_has_err = abap_true.
      EXIT.
    ENDLOOP.
    IF lv_has_err = abap_true OR ls_imp-create_lines IS INITIAL.
      RETURN.
    ENDIF.

    " --- Crear reglas root EN DRAFT (early numbering asigna el ID) ---
    DATA lt_create TYPE TABLE FOR CREATE zi_reingtxrule.
    DATA lv_cnt TYPE i VALUE 0.

    LOOP AT ls_imp-create_lines INTO DATA(ls_line).
      lv_cnt += 1.
      " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
      " ET-REING-BR-001 v5 SS4.2 -- CountryPrest / BukrsPrest / BukrsRecv se
      " propagan desde el Excel al CREATE. Los tres puntos hay que tocarlos
      " juntos: el valor en la estructura, su flag en %control y la lista de
      " CREATE FIELDS de abajo. Si falta cualquiera de los tres, la columna
      " nueva del template se parsea y se descarta SIN ERROR, que es la falla
      " mas caras de detectar de toda esta actividad.
      APPEND VALUE #(
        %cid        = |TX_UPLOAD_{ lv_cnt }|
        %is_draft   = if_abap_behv=>mk-on
        Country     = ls_line-country
        CountryPrest = ls_line-country_prest
        BukrsPrest   = ls_line-bukrs_prest
        BukrsRecv    = ls_line-bukrs_recv
        TaxType     = ls_line-tax_type
        Matnr       = ls_line-matnr
        Lifnr       = ls_line-lifnr
        Rate        = ls_line-rate
        GrossUp     = ls_line-gross_up
        ValidFrom   = ls_line-valid_from
        ValidTo     = ls_line-valid_to
        TxStatus    = ls_line-tx_status
        Description = ls_line-description
        %control    = VALUE #(
          Country     = if_abap_behv=>mk-on
          CountryPrest = if_abap_behv=>mk-on
          BukrsPrest   = if_abap_behv=>mk-on
          BukrsRecv    = if_abap_behv=>mk-on
          TaxType     = if_abap_behv=>mk-on
          Matnr       = if_abap_behv=>mk-on
          Lifnr       = if_abap_behv=>mk-on
          Rate        = if_abap_behv=>mk-on
          GrossUp     = if_abap_behv=>mk-on
          ValidFrom   = if_abap_behv=>mk-on
          ValidTo     = if_abap_behv=>mk-on
          TxStatus    = if_abap_behv=>mk-on
          Description = if_abap_behv=>mk-on
          Notes       = if_abap_behv=>mk-on ) ) TO lt_create.
    ENDLOOP.

    DATA lt_rep TYPE RESPONSE FOR REPORTED zi_reingtxrule.
    DATA lt_fail TYPE RESPONSE FOR FAILED zi_reingtxrule.
    DATA lt_map TYPE RESPONSE FOR MAPPED zi_reingtxrule.
    " V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
    TEST-SEAM tx_upload_create.
      IF mv_isolated_test = abap_true.
        RETURN.
      ENDIF.
      MODIFY ENTITIES OF zi_reingtxrule IN LOCAL MODE
        ENTITY TxRule
          CREATE FIELDS ( Country CountryPrest BukrsPrest BukrsRecv
                          TaxType Matnr Lifnr Rate GrossUp
                          ValidFrom ValidTo TxStatus Description Notes )
          WITH lt_create
        REPORTED lt_rep
        FAILED   lt_fail
        MAPPED   lt_map.
    END-TEST-SEAM.
      " End Change ID V009 (15.09.2026 | EXT_GONZALCA)

    " Propagar mensajes de la creacion (si los hubiera)
    IF lt_rep-txrule IS NOT INITIAL.
      LOOP AT lt_rep-txrule INTO DATA(ls_rep_line).
        APPEND ls_rep_line TO reported-txrule.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD DownloadTemplate.
    " Accion estatica: genera el template .xlsx vacio con el layout A..L exacto
    " que espera read_rows, para que el usuario no tenga que armarlo a mano.
    DATA(lo_tpl_hdl) = NEW zcl_reing_tx_upload_hdl( ).
    DATA(lv_tpl_x)   = lo_tpl_hdl->export_template( ).

    IF lv_tpl_x IS INITIAL.
      APPEND VALUE #( %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'No se pudo generar el template de reglas fiscales.' ) )
        TO reported-txrule.
      RETURN.
    ENDIF.

    " Codificar a base64 (mismo contrato que UploadRules y que ME/CA/CM).
    DATA lv_tpl_b64 TYPE string.
    TRY.
        lv_tpl_b64 = xco_cp=>xstring( lv_tpl_x
          )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
      CATCH cx_root.
        APPEND VALUE #( %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Error al codificar el template.' ) )
          TO reported-txrule.
        RETURN.
    ENDTRY.

    result = VALUE #( ( %cid   = keys[ 1 ]-%cid
                        %param = VALUE #(
                          FileContent = lv_tpl_b64
                          FileName    = 'Template_Reglas_Fiscales.xlsx'
                          MimeType    = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ) ).
  ENDMETHOD.

ENDCLASS.
