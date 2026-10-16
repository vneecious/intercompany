CLASS lsc_zi_reingmcversion DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
  PRIVATE SECTION.
    METHODS get_uuid RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
ENDCLASS.

CLASS lsc_zi_reingmcversion IMPLEMENTATION.

 METHOD save_modified.
    DATA lv_now TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.

    DATA lt_metric_codes TYPE SORTED TABLE OF zreing_mcv_a-metric_code
                          WITH UNIQUE KEY table_line.

    LOOP AT create-zi_reingmcversion INTO DATA(ls_create).
      INSERT ls_create-MetricCode INTO TABLE lt_metric_codes.
    ENDLOOP.
    LOOP AT update-zi_reingmcversion INTO DATA(ls_upd).
      INSERT ls_upd-MetricCode INTO TABLE lt_metric_codes.
    ENDLOOP.
    LOOP AT delete-zi_reingmcversion INTO DATA(ls_del).
      INSERT ls_del-MetricCode INTO TABLE lt_metric_codes.
    ENDLOOP.

    " === Nueva Version via flag IsNewVersion ===
    DATA lt_new_ver_ins TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    DATA lt_header_data TYPE SORTED TABLE OF zreing_mc_a
                         WITH UNIQUE KEY metric_code.

    DATA lt_flag_keys TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    LOOP AT update-zi_reingmcversion INTO DATA(ls_flag_chk).
      CHECK ls_flag_chk-IsNewVersion = 'X'.
      APPEND VALUE zreing_mcv_a(
        metric_code = ls_flag_chk-MetricCode
        version_num = ls_flag_chk-VersionNum ) TO lt_flag_keys.
    ENDLOOP.

    IF lt_flag_keys IS NOT INITIAL.
      DATA lt_orig_vers TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
      SELECT *
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_flag_keys
        WHERE metric_code = @lt_flag_keys-metric_code
          AND version_num = @lt_flag_keys-version_num
        INTO CORRESPONDING FIELDS OF TABLE @lt_orig_vers.

      DATA lt_max_flag TYPE HASHED TABLE OF zreing_mcv_a
                        WITH UNIQUE KEY metric_code.
      DATA lt_all_flag TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
      SELECT metric_code, version_num
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_flag_keys
        WHERE metric_code = @lt_flag_keys-metric_code
          AND version_num <> '000'
        INTO CORRESPONDING FIELDS OF TABLE @lt_all_flag.

      LOOP AT lt_all_flag INTO DATA(ls_af).
        READ TABLE lt_max_flag INTO DATA(ls_mf)
          WITH TABLE KEY metric_code = ls_af-metric_code.
        IF sy-subrc <> 0.
          INSERT VALUE zreing_mcv_a(
            metric_code = ls_af-metric_code
            version_num = ls_af-version_num )
            INTO TABLE lt_max_flag.
        ELSEIF ls_af-version_num > ls_mf-version_num.
          ls_mf-version_num = ls_af-version_num.
          MODIFY TABLE lt_max_flag FROM ls_mf.
        ENDIF.
      ENDLOOP.

      LOOP AT lt_orig_vers INTO DATA(ls_orig).
        READ TABLE lt_max_flag INTO DATA(ls_mf2)
          WITH TABLE KEY metric_code = ls_orig-metric_code.
        DATA(lv_new_num) = COND zreing_mcv_a-version_num(
          WHEN sy-subrc = 0 THEN ls_mf2-version_num + 1
          ELSE '001' ).

        DATA(lv_change_reason) = CONV zreing_mcv_a-change_reason( '' ).

        APPEND VALUE zreing_mcv_a(
          metric_code     = ls_orig-metric_code
          version_num     = lv_new_num
          version_status  = 'D'
          data_source_ver = ls_orig-data_source_ver
          change_reason   = lv_change_reason
          valid_from      = cl_abap_context_info=>get_system_date( )
          valid_to        = '99991231'
          var_pct_limit   = ls_orig-var_pct_limit
          metric_desc     = ls_orig-metric_desc
          metric_type     = ls_orig-metric_type
          " Begin Mod 03.09.2026 EXT_AGFAGINA - copiar tambien los campos de texto.
          " La nueva version se crea con un INSERT directo a la base, fuera del
          " ciclo de RAP, asi que las determinaciones SetMetricTypeText y
          " SetStatusTexts (on modify) NUNCA se disparan para esta fila.
          " Resultado: METRIC_TYPE viajaba bien pero METRIC_TYPE_TXT quedaba vacio
          " y el campo Tipo se veia en blanco en la segunda version en adelante.
          " Verificado en TS4: todas las versiones 001 tenian el texto, ninguna
          " version posterior lo tenia (M-0004 v002/v003, M-0006 v002).
          " VERSION_STATUS_TXT si aparecia cargado, pero por otra via: al activar
          " la version se ejecuta ActivateVersion, que pasa por RAP y dispara la
          " determinacion. El tipo no se vuelve a tocar nunca, por eso quedaba asi.
          metric_type_txt    = ls_orig-metric_type_txt
          version_status_txt = 'Draft'
          metric_status_txt  = ls_orig-metric_status_txt
          " End Mod 03.09.2026 EXT_AGFAGINA
          data_source     = ls_orig-data_source
          responsible     = ls_orig-responsible
          created_by      = sy-uname
          created_at      = lv_now
          changed_by      = sy-uname
          changed_at      = lv_now ) TO lt_new_ver_ins.
      ENDLOOP.

      IF lt_new_ver_ins IS NOT INITIAL.
        INSERT zreing_mcv_a FROM TABLE @lt_new_ver_ins.
        LOOP AT lt_new_ver_ins INTO DATA(ls_nvi).
          INSERT ls_nvi-metric_code INTO TABLE lt_metric_codes.
          READ TABLE lt_header_data TRANSPORTING NO FIELDS
            WITH TABLE KEY metric_code = ls_nvi-metric_code.
          IF sy-subrc <> 0.
            INSERT VALUE zreing_mc_a(
              metric_code  = ls_nvi-metric_code
              metric_desc  = ls_nvi-metric_desc
              metric_type  = ls_nvi-metric_type
              data_source  = ls_nvi-data_source
              responsible  = ls_nvi-responsible ) INTO TABLE lt_header_data.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.

    CHECK lt_metric_codes IS NOT INITIAL.

    " === FIX VERSION_NUM ===
    DATA lt_fix_codes TYPE SORTED TABLE OF zreing_mcv_a-metric_code
                       WITH UNIQUE KEY table_line.
    LOOP AT create-zi_reingmcversion INTO DATA(ls_cr_chk).
      CHECK ls_cr_chk-VersionNum = '000'.
      INSERT ls_cr_chk-MetricCode INTO TABLE lt_fix_codes.
    ENDLOOP.

    IF lt_fix_codes IS NOT INITIAL.
      DATA lt_existing_vers TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
      SELECT metric_code, version_num
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_fix_codes
        WHERE metric_code = @lt_fix_codes-table_line
          AND version_num <> '000'
        INTO CORRESPONDING FIELDS OF TABLE @lt_existing_vers.

      DATA lt_max_by_mc TYPE HASHED TABLE OF zreing_mcv_a
                          WITH UNIQUE KEY metric_code.
      LOOP AT lt_existing_vers INTO DATA(ls_ev).
        READ TABLE lt_max_by_mc INTO DATA(ls_mx)
          WITH TABLE KEY metric_code = ls_ev-metric_code.
        IF sy-subrc <> 0.
          INSERT VALUE zreing_mcv_a(
            metric_code = ls_ev-metric_code
            version_num = ls_ev-version_num )
            INTO TABLE lt_max_by_mc.
        ELSEIF ls_ev-version_num > ls_mx-version_num.
          ls_mx-version_num = ls_ev-version_num.
          MODIFY TABLE lt_max_by_mc FROM ls_mx.
        ENDIF.
      ENDLOOP.

      DATA lt_new_vers TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
      DATA ls_new_ver  TYPE zreing_mcv_a.
      LOOP AT create-zi_reingmcversion INTO DATA(ls_cr_fix).
        CHECK ls_cr_fix-VersionNum = '000'.

        READ TABLE lt_max_by_mc INTO DATA(ls_max_mc)
          WITH TABLE KEY metric_code = ls_cr_fix-MetricCode.
        DATA(lv_new_num2) = COND zreing_mcv_a-version_num(
          WHEN sy-subrc <> 0 THEN '001'
          ELSE ls_max_mc-version_num + 1 ).

        ls_new_ver = VALUE zreing_mcv_a(
          metric_code     = ls_cr_fix-MetricCode
          version_num     = lv_new_num2
          version_status  = ls_cr_fix-VersionStatus
          data_source_ver = ls_cr_fix-DataSourceVer
          change_reason   = ls_cr_fix-ChangeReason
          valid_from      = ls_cr_fix-ValidFrom
          valid_to        = ls_cr_fix-ValidTo
          var_pct_limit   = ls_cr_fix-VarPctLimit
          metric_desc     = ls_cr_fix-MetricDesc
          metric_type     = 'M'
          data_source     = ls_cr_fix-DataSource
          responsible     = ls_cr_fix-Responsible
          created_by      = COND #( WHEN ls_cr_fix-CreatedBy IS NOT INITIAL
                                    THEN ls_cr_fix-CreatedBy ELSE sy-uname )
          created_at      = COND #( WHEN ls_cr_fix-CreatedAt IS NOT INITIAL
                                    THEN ls_cr_fix-CreatedAt ELSE lv_now )
          changed_by      = sy-uname
          changed_at      = lv_now ).
        APPEND ls_new_ver TO lt_new_vers.

        READ TABLE lt_max_by_mc INTO ls_max_mc
          WITH TABLE KEY metric_code = ls_cr_fix-MetricCode.
        IF sy-subrc = 0.
          ls_max_mc-version_num = lv_new_num2.
          MODIFY TABLE lt_max_by_mc FROM ls_max_mc.
        ELSE.
          INSERT VALUE zreing_mcv_a(
            metric_code = ls_cr_fix-MetricCode
            version_num = lv_new_num2 )
            INTO TABLE lt_max_by_mc.
        ENDIF.
      ENDLOOP.

      IF lt_new_vers IS NOT INITIAL.
        INSERT zreing_mcv_a FROM TABLE @lt_new_vers.
      ENDIF.
    ENDIF.

    DATA lt_all_vers TYPE SORTED TABLE OF zreing_mcv_a
                      WITH NON-UNIQUE KEY metric_code.
    SELECT metric_code, version_num, version_status
      FROM zreing_mcv_a
      FOR ALL ENTRIES IN @lt_metric_codes
      WHERE metric_code = @lt_metric_codes-table_line
        AND version_num <> '000'
      INTO CORRESPONDING FIELDS OF TABLE @lt_all_vers.

    LOOP AT update-zi_reingmcversion INTO DATA(ls_upd_status).
      CHECK ls_upd_status-VersionStatus IS NOT INITIAL.
      READ TABLE lt_all_vers ASSIGNING FIELD-SYMBOL(<ls_ver_upd>)
        WITH KEY metric_code = ls_upd_status-MetricCode
                 version_num = ls_upd_status-VersionNum.
      IF sy-subrc = 0.
        <ls_ver_upd>-version_status = ls_upd_status-VersionStatus.
      ELSE.
        INSERT VALUE zreing_mcv_a(
          metric_code    = ls_upd_status-MetricCode
          version_num    = ls_upd_status-VersionNum
          version_status = ls_upd_status-VersionStatus )
          INTO TABLE lt_all_vers.
      ENDIF.
    ENDLOOP.

    DATA lt_existing TYPE SORTED TABLE OF zreing_mc_a
                      WITH UNIQUE KEY metric_code.
    SELECT metric_code, metric_desc, metric_type, data_source, responsible
      FROM zreing_mc_a
      FOR ALL ENTRIES IN @lt_metric_codes
      WHERE metric_code = @lt_metric_codes-table_line
      INTO CORRESPONDING FIELDS OF TABLE @lt_existing.

    LOOP AT create-zi_reingmcversion INTO DATA(ls_cr).
      READ TABLE lt_header_data TRANSPORTING NO FIELDS
        WITH TABLE KEY metric_code = ls_cr-MetricCode.
      IF sy-subrc <> 0.
        INSERT VALUE zreing_mc_a(
          metric_code  = ls_cr-MetricCode
          metric_desc  = ls_cr-MetricDesc
          metric_type  = 'M'
          data_source  = ls_cr-DataSource
          responsible  = ls_cr-Responsible ) INTO TABLE lt_header_data.
      ENDIF.
    ENDLOOP.

    LOOP AT update-zi_reingmcversion INTO DATA(ls_ud).
      READ TABLE lt_header_data INTO DATA(ls_hd_upd)
        WITH TABLE KEY metric_code = ls_ud-MetricCode.
      IF sy-subrc <> 0.
        INSERT VALUE zreing_mc_a(
          metric_code  = ls_ud-MetricCode
          metric_desc  = ls_ud-MetricDesc
          metric_type  = ls_ud-MetricType
          data_source  = ls_ud-DataSource
          responsible  = ls_ud-Responsible ) INTO TABLE lt_header_data.
      ELSE.
        ls_hd_upd-metric_desc  = ls_ud-MetricDesc.
        ls_hd_upd-metric_type  = ls_ud-MetricType.
        ls_hd_upd-data_source  = ls_ud-DataSource.
        ls_hd_upd-responsible  = ls_ud-Responsible.
        MODIFY TABLE lt_header_data FROM ls_hd_upd.
      ENDIF.
    ENDLOOP.

    DATA lt_mc_insert TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
    DATA lt_mc_update TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
    DATA lt_mc_delete TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.

    LOOP AT lt_metric_codes INTO DATA(lv_mc).
      DATA(lt_vers_mc) = FILTER #( lt_all_vers USING KEY primary_key
                                   WHERE metric_code = lv_mc ).

      IF lt_vers_mc IS INITIAL.
        APPEND VALUE zreing_mc_a( metric_code = lv_mc ) TO lt_mc_delete.
        CONTINUE.
      ENDIF.

      DATA(lv_has_active) = xsdbool(
        REDUCE abap_bool(
          INIT found = abap_false
          FOR v IN lt_vers_mc
          NEXT found = COND #( WHEN v-version_status = 'A'
                               THEN abap_true ELSE found )
        ) = abap_true ).

      DATA(lv_status) = COND zreing_mcv_a-version_status(
        WHEN lv_has_active = abap_true THEN 'A' ELSE 'I' ).

      DATA(lv_max_ver2) = REDUCE zreing_mcv_a-version_num(
        INIT mx = CONV zreing_mcv_a-version_num( '000' )
        FOR v IN lt_vers_mc
        NEXT mx = COND #( WHEN v-version_num > mx
                          THEN v-version_num ELSE mx ) ).

      READ TABLE lt_header_data INTO DATA(ls_hd)
        WITH TABLE KEY metric_code = lv_mc.
      DATA(lv_desc)        = COND zreing_mc_a-metric_desc(
                               WHEN sy-subrc = 0 THEN ls_hd-metric_desc ).
      DATA(lv_type)        = COND zreing_mc_a-metric_type(
                               WHEN sy-subrc = 0 THEN ls_hd-metric_type ).
      DATA(lv_data_source) = COND zreing_mc_a-data_source(
                               WHEN sy-subrc = 0 THEN ls_hd-data_source ).
      DATA(lv_responsible) = COND zreing_mc_a-responsible(
                               WHEN sy-subrc = 0 THEN ls_hd-responsible ).

      READ TABLE lt_existing INTO DATA(ls_ex)
        WITH TABLE KEY metric_code = lv_mc.
      IF sy-subrc = 0.
        IF lv_desc IS INITIAL.        lv_desc        = ls_ex-metric_desc.  ENDIF.
        IF lv_type IS INITIAL.        lv_type        = ls_ex-metric_type.  ENDIF.
        IF lv_data_source IS INITIAL. lv_data_source = ls_ex-data_source.  ENDIF.
        IF lv_responsible IS INITIAL. lv_responsible = ls_ex-responsible.  ENDIF.
      ENDIF.

      IF line_exists( lt_existing[ metric_code = lv_mc ] ).
        APPEND VALUE zreing_mc_a(
          metric_code   = lv_mc
          metric_desc   = lv_desc
          metric_type   = lv_type
          data_source   = lv_data_source
          responsible   = lv_responsible
          status        = lv_status
          last_vers_num = lv_max_ver2
          changed_by    = sy-uname
          changed_at    = lv_now ) TO lt_mc_update.
      ELSE.
        APPEND VALUE zreing_mc_a(
          metric_code   = lv_mc
          metric_desc   = lv_desc
          metric_type   = 'M'
          data_source   = lv_data_source
          responsible   = lv_responsible
          status        = lv_status
          last_vers_num = lv_max_ver2
          created_by    = sy-uname
          created_at    = lv_now
          changed_by    = sy-uname
          changed_at    = lv_now ) TO lt_mc_insert.
      ENDIF.
    ENDLOOP.

    IF lt_mc_delete IS NOT INITIAL.
      DELETE zreing_mc_a FROM TABLE @lt_mc_delete.
    ENDIF.
    IF lt_mc_insert IS NOT INITIAL.
      INSERT zreing_mc_a FROM TABLE @lt_mc_insert.
    ENDIF.
    IF lt_mc_update IS NOT INITIAL.
      UPDATE zreing_mc_a FROM TABLE @lt_mc_update.
    ENDIF.

    " === HISTORIAL DE CAMBIOS ===
    " Campos auditables: MetricDesc, DataSource, DataSourceVer,
    "                    ChangeReason, Responsible, VarPctLimit, VersionStatus
    DATA lt_hist_keys TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    LOOP AT update-zi_reingmcversion INTO DATA(ls_h_chk).
      APPEND VALUE zreing_mcv_a(
        metric_code = ls_h_chk-MetricCode
        version_num = ls_h_chk-VersionNum ) TO lt_hist_keys.
    ENDLOOP.

    IF lt_hist_keys IS NOT INITIAL.
      " Leer valores anteriores en DB antes del update — bulk SELECT
      DATA lt_prev_vals TYPE HASHED TABLE OF zreing_mcv_a
                         WITH UNIQUE KEY metric_code version_num.
      SELECT metric_code, version_num, metric_desc, data_source,
             data_source_ver, change_reason, responsible,
             var_pct_limit, version_status
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_hist_keys
        WHERE metric_code = @lt_hist_keys-metric_code
          AND version_num = @lt_hist_keys-version_num
        INTO CORRESPONDING FIELDS OF TABLE @lt_prev_vals.

      DATA lt_hist_ins TYPE TABLE OF zreing_mc_hist_a WITH EMPTY KEY.

      LOOP AT update-zi_reingmcversion INTO DATA(ls_upd_h).
        READ TABLE lt_prev_vals INTO DATA(ls_prev)
          WITH TABLE KEY metric_code = ls_upd_h-MetricCode
                         version_num = ls_upd_h-VersionNum.
        CHECK sy-subrc = 0.

        " Comparar campo por campo y acumular diferencias
        IF ls_upd_h-%control-MetricDesc = if_abap_behv=>mk-on
        AND ls_upd_h-MetricDesc <> ls_prev-metric_desc.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Nombre'
            value_old   = ls_prev-metric_desc
            value_new   = ls_upd_h-MetricDesc ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-DataSource = if_abap_behv=>mk-on
        AND ls_upd_h-DataSource <> ls_prev-data_source.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Fuente'
            value_old   = ls_prev-data_source
            value_new   = ls_upd_h-DataSource ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-DataSourceVer = if_abap_behv=>mk-on
        AND ls_upd_h-DataSourceVer <> ls_prev-data_source_ver.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Version Fuente'
            value_old   = ls_prev-data_source_ver
            value_new   = ls_upd_h-DataSourceVer ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-ChangeReason = if_abap_behv=>mk-on
        AND ls_upd_h-ChangeReason <> ls_prev-change_reason.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Motivo de Cambio'
            value_old   = ls_prev-change_reason
            value_new   = ls_upd_h-ChangeReason ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-Responsible = if_abap_behv=>mk-on
        AND ls_upd_h-Responsible <> ls_prev-responsible.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Responsable'
            value_old   = ls_prev-responsible
            value_new   = ls_upd_h-Responsible ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-VarPctLimit = if_abap_behv=>mk-on
        AND ls_upd_h-VarPctLimit <> ls_prev-var_pct_limit.
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = 'UPDATE'
            field_name  = 'Var. Lim. %'
            value_old   = |{ ls_prev-var_pct_limit }|
            value_new   = |{ ls_upd_h-VarPctLimit }| ) TO lt_hist_ins.
        ENDIF.

        IF ls_upd_h-%control-VersionStatus = if_abap_behv=>mk-on
        AND ls_upd_h-VersionStatus <> ls_prev-version_status.
          DATA(lv_action) = COND zreing_mc_hist_a-action(
            WHEN ls_upd_h-VersionStatus = 'A' THEN 'ACTIVATE'
            WHEN ls_upd_h-VersionStatus = 'I' THEN 'INACTIVATE'
            ELSE 'UPDATE' ).
          APPEND VALUE zreing_mc_hist_a(
            metric_code = ls_upd_h-MetricCode
            version_num = ls_upd_h-VersionNum
            hist_uuid   = get_uuid( )
            changed_at  = lv_now
            changed_by  = sy-uname
            action      = lv_action
            field_name  = 'Estado Version'
            value_old   = ls_prev-version_status
            value_new   = ls_upd_h-VersionStatus ) TO lt_hist_ins.
        ENDIF.
      ENDLOOP.

      IF lt_hist_ins IS NOT INITIAL.
        INSERT zreing_mc_hist_a FROM TABLE @lt_hist_ins.
      ENDIF.
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

CLASS lhc_zi_reingmcversion DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_reingmcversion RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_reingmcversion RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingmcversion RESULT result.

    METHODS validate_required_fields FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmcversion~validaterequiredfields.

    METHODS validate_version_deletion FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmcversion~validateversiondeletion.

    METHODS set_validity_dates FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmcversion~setvaliditydates.

    METHODS set_status_texts FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmcversion~setstatustexts.

    METHODS update_metric_header FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmcversion~updatemetricheader.

    METHODS activate_version FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmcversion~activateversion RESULT result.

    METHODS inactivate_version FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmcversion~inactivateversion RESULT result.

    METHODS new_version FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingmcversion~newversion RESULT result.

    METHODS validate_duplicate_metric_code FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmcversion~validateduplicatemetriccode.

    METHODS validate_no_active_contracts FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmcversion~validatenoactivecontracts.

    METHODS validate_single_active_version FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingmcversion~validatesingleactiveversion.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE zi_reingmcversion.

      METHODS set_metric_type_text FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingmcversion~setmetrictypetext.

ENDCLASS.

CLASS lhc_zi_reingmcversion IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
    result = VALUE #(
      FOR key IN keys
      ( %tky                      = key-%tky
        %update                   = if_abap_behv=>auth-allowed
        %delete                   = if_abap_behv=>auth-allowed
        %action-ActivateVersion   = if_abap_behv=>auth-allowed
        %action-InactivateVersion = if_abap_behv=>auth-allowed
        %action-NewVersion        = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( VersionStatus IsLatestVersion )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    DATA lt_ct_keys TYPE TABLE OF zreing_ct2_met_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_v_ct).
      APPEND VALUE zreing_ct2_met_a(
        metric_code = ls_v_ct-%data-MetricCode
        version_num = ls_v_ct-%data-VersionNum ) TO lt_ct_keys.
    ENDLOOP.

    DATA lt_with_contracts TYPE HASHED TABLE OF zreing_mcv_a
                            WITH UNIQUE KEY metric_code version_num.
    IF lt_ct_keys IS NOT INITIAL.
      SELECT DISTINCT cm~metric_code, cm~version_num
        FROM zreing_ct2_met_a AS cm
        INNER JOIN zreing_ct2_a AS ct
          ON  ct~ct_uuid   = cm~ct_uuid
          AND ct~ct_status = 'AC'
        FOR ALL ENTRIES IN @lt_ct_keys
        WHERE cm~metric_code = @lt_ct_keys-metric_code
          AND cm~version_num = @lt_ct_keys-version_num
        INTO TABLE @DATA(lt_ct_raw).
      LOOP AT lt_ct_raw INTO DATA(ls_ct).
        INSERT VALUE zreing_mcv_a(
          metric_code = ls_ct-metric_code
          version_num = ls_ct-version_num )
          INTO TABLE lt_with_contracts.
      ENDLOOP.
    ENDIF.

    result = VALUE #(
      FOR ls IN lt_versions
      LET lv_status    = ls-%data-VersionStatus
          lv_is_latest = ls-%data-IsLatestVersion
          lv_is_new    = xsdbool( ls-%is_draft    = if_abap_behv=>mk-on
                                  AND lv_is_latest = abap_false )
          lv_has_ct    = xsdbool( line_exists(
                           lt_with_contracts[ metric_code = ls-%data-MetricCode
                                              version_num = ls-%data-VersionNum ] ) )
      IN (
        %tky = ls-%tky

        %action-ActivateVersion   = COND #(
          WHEN lv_status = 'A'        THEN if_abap_behv=>fc-o-disabled
          WHEN lv_is_new = abap_true  THEN if_abap_behv=>fc-o-disabled
          WHEN lv_is_latest <> 'X'   THEN if_abap_behv=>fc-o-disabled
          ELSE                             if_abap_behv=>fc-o-enabled )

        %action-InactivateVersion = COND #(
          WHEN lv_status <> 'A'      THEN if_abap_behv=>fc-o-disabled
          WHEN lv_has_ct = abap_true THEN if_abap_behv=>fc-o-disabled
          ELSE                            if_abap_behv=>fc-o-enabled )

        %action-NewVersion        = COND #(
          WHEN lv_status = 'D'       THEN if_abap_behv=>fc-o-disabled
          WHEN lv_is_new = abap_true THEN if_abap_behv=>fc-o-disabled
          ELSE                            if_abap_behv=>fc-o-enabled )

        %action-Edit              = COND #(
          WHEN lv_status = 'A' AND lv_has_ct = abap_true
                                   THEN if_abap_behv=>fc-o-disabled
          ELSE                          if_abap_behv=>fc-o-enabled )

        %update                   = COND #(
          WHEN lv_status = 'A' AND lv_has_ct = abap_true
                                   THEN if_abap_behv=>fc-o-disabled
          ELSE                          if_abap_behv=>fc-o-enabled )

        %delete                   = COND #(
          WHEN lv_status = 'A' AND lv_has_ct = abap_true
                                   THEN if_abap_behv=>fc-o-disabled
          ELSE                          if_abap_behv=>fc-o-enabled )
      ) ).
  ENDMETHOD.

  METHOD update_metric_header.
    " Patron SAP (setStatustoNew): determination on modify { create; update; }
    " Setea MetricType = 'M' en el transactional buffer inmediatamente
    " Asi el valor es visible en el draft antes de guardar
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode MetricType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    LOOP AT lt_versions INTO DATA(ls_ver)
      WHERE %data-MetricType <> 'M'.
      MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
        ENTITY zi_reingmcversion
          UPDATE FIELDS ( MetricType )
          WITH VALUE #( ( %tky       = ls_ver-%tky
                          MetricType = 'M' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

METHOD validate_required_fields.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode MetricDesc DataSource DataSourceVer ChangeReason VarPctLimit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    LOOP AT lt_versions INTO DATA(ls_ver).
      IF ls_ver-%data-MetricCode IS INITIAL.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El codigo de metrica es obligatorio' ) )
          TO reported-zi_reingmcversion.
      ENDIF.

      IF ls_ver-%data-MetricDesc IS INITIAL.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El nombre de la metrica es obligatorio' ) )
          TO reported-zi_reingmcversion.
      ENDIF.

      IF ls_ver-%data-DataSource IS INITIAL.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La fuente de datos es obligatoria' ) )
          TO reported-zi_reingmcversion.
      ENDIF.

      IF ls_ver-%data-ChangeReason IS INITIAL.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El motivo del cambio es obligatorio' ) )
          TO reported-zi_reingmcversion.
      ENDIF.

      IF ls_ver-%data-DataSourceVer IS INITIAL.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La version fuente es obligatoria' ) )
          TO reported-zi_reingmcversion.
      ENDIF.

      IF ls_ver-%data-VarPctLimit < 0.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El limite de variacion porcentual no puede ser negativo' ) )
          TO reported-zi_reingmcversion.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_version_deletion.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    " Collect all metric codes, single bulk SELECT - avoids SELECT inside LOOP
    DATA lt_keys TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_ver).
      APPEND VALUE zreing_mc_a(
        metric_code = ls_ver-%data-MetricCode ) TO lt_keys.
    ENDLOOP.

    DATA lt_used_metrics TYPE HASHED TABLE OF zreing_mcv_a-metric_code
                          WITH UNIQUE KEY table_line.
    IF lt_keys IS NOT INITIAL.
      DATA lt_used_raw TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
      " TODO Sprint 3: habilitar cuando exista tabla zreing_run_metric_a
      " SELECT DISTINCT metric_code
      "   FROM zreing_run_metric_a
      "   FOR ALL ENTRIES IN @lt_keys
      "   WHERE metric_code = @lt_keys-metric_code
      "     AND run_status  = 'C'
      "   INTO CORRESPONDING FIELDS OF TABLE @lt_used_raw.
      LOOP AT lt_used_raw INTO DATA(ls_used).
        INSERT ls_used-metric_code INTO TABLE lt_used_metrics.
      ENDLOOP.
    ENDIF.

    LOOP AT lt_versions INTO ls_ver.
      IF line_exists( lt_used_metrics[ table_line = ls_ver-%data-MetricCode ] ).
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La métrica fue usada en una ejecución PRGI y no puede eliminarse' ) )
          TO reported-zi_reingmcversion.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_validity_dates.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum VersionStatus ValidFrom ValidTo
                 ChangeReason CreatedBy CreatedAt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_uname) = sy-uname.
    DATA lv_now    TYPE tzntstmpl.
    GET TIME STAMP FIELD lv_now.

    DATA lt_need_num TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_v).
      CHECK ls_v-%data-VersionNum = '000'.
      APPEND VALUE zreing_mcv_a(
        metric_code = ls_v-%data-MetricCode ) TO lt_need_num.
    ENDLOOP.

    DATA lt_max_vers TYPE HASHED TABLE OF zreing_mcv_a
                      WITH UNIQUE KEY metric_code.
    IF lt_need_num IS NOT INITIAL.
      DATA lt_db_vers TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
      SELECT metric_code, version_num
        FROM zreing_mcv_a
        FOR ALL ENTRIES IN @lt_need_num
        WHERE metric_code = @lt_need_num-metric_code
          AND version_num <> '000'
        INTO CORRESPONDING FIELDS OF TABLE @lt_db_vers.

      LOOP AT lt_db_vers INTO DATA(ls_db).
        READ TABLE lt_max_vers INTO DATA(ls_mx)
          WITH TABLE KEY metric_code = ls_db-metric_code.
        IF sy-subrc <> 0.
          INSERT VALUE zreing_mcv_a(
            metric_code = ls_db-metric_code
            version_num = ls_db-version_num )
            INTO TABLE lt_max_vers.
        ELSEIF ls_db-version_num > ls_mx-version_num.
          ls_mx-version_num = ls_db-version_num.
          MODIFY TABLE lt_max_vers FROM ls_mx.
        ENDIF.
      ENDLOOP.
    ENDIF.

    MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        UPDATE FIELDS ( VersionNum VersionStatus ValidFrom ValidTo
                        ChangeReason CreatedBy CreatedAt ChangedBy ChangedAt )
        WITH VALUE #(
          FOR ls IN lt_versions
          LET lv_new_num = COND zreing_mcv_a-version_num(
                             WHEN ls-%data-VersionNum <> '000'
                             THEN ls-%data-VersionNum
                             ELSE COND #(
                               WHEN line_exists( lt_max_vers[ metric_code = ls-%data-MetricCode ] )
                               THEN lt_max_vers[ metric_code = ls-%data-MetricCode ]-version_num + 1
                               ELSE '001' ) )
              lv_status = COND zreing_mcv_a-version_status(
                            WHEN ls-%data-VersionStatus IS INITIAL THEN 'D'
                            ELSE ls-%data-VersionStatus )
              lv_from   = COND zreing_mcv_a-valid_from(
                            WHEN ls-%data-ValidFrom IS NOT INITIAL THEN ls-%data-ValidFrom
                            ELSE lv_today )
              lv_to     = COND zreing_mcv_a-valid_to(
                            WHEN ls-%data-VersionStatus = 'I' THEN lv_today
                            WHEN ls-%data-ValidTo IS INITIAL  THEN '99991231'
                            ELSE ls-%data-ValidTo )
              lv_reason = COND zreing_mcv_a-change_reason(
                            WHEN ls-%data-ChangeReason IS INITIAL THEN 'Primera version'
                            ELSE ls-%data-ChangeReason )
              lv_crby   = COND syuname(
                            WHEN ls-%data-CreatedBy IS INITIAL THEN lv_uname
                            ELSE ls-%data-CreatedBy )
              lv_crat   = COND tzntstmpl(
                            WHEN ls-%data-CreatedAt IS INITIAL THEN lv_now
                            ELSE ls-%data-CreatedAt )
          IN ( %tky          = ls-%tky
               VersionNum    = lv_new_num
               VersionStatus = lv_status
               ValidFrom     = lv_from
               ValidTo       = lv_to
               ChangeReason  = lv_reason
               CreatedBy     = lv_crby
               CreatedAt     = lv_crat
               ChangedBy     = lv_uname
               ChangedAt     = lv_now ) )
      REPORTED DATA(lt_rep).
  ENDMETHOD.

  METHOD activate_version.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum VersionStatus IsLatestVersion )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    DATA lt_to_activate TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_ver).
      IF ls_ver-%data-VersionStatus = 'A'.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La version ya esta activa' ) )
          TO reported-zi_reingmcversion.
        CONTINUE.
      ENDIF.
      IF ls_ver-%data-IsLatestVersion <> 'X'.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |BR-04: Solo es posible activar la ultima version de la metrica { ls_ver-%data-MetricCode }| ) )
          TO reported-zi_reingmcversion.
        CONTINUE.
      ENDIF.
      APPEND VALUE zreing_mcv_a(
        metric_code = ls_ver-%data-MetricCode
        version_num = ls_ver-%data-VersionNum ) TO lt_to_activate.
    ENDLOOP.

    CHECK lt_to_activate IS NOT INITIAL.

    LOOP AT lt_versions INTO DATA(ls_v5).
      IF NOT line_exists( lt_to_activate[ metric_code = ls_v5-%data-MetricCode
                                          version_num = ls_v5-%data-VersionNum ] ).
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
        ENTITY zi_reingmcversion
          UPDATE FIELDS ( VersionStatus )
          WITH VALUE #( ( %tky = ls_v5-%tky VersionStatus = 'A' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.

    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result
      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res-%data ) ) ).
  ENDMETHOD.

  METHOD inactivate_version.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum VersionStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    " BR-02: verificar contratos activos en CT V2
    " Jerarquia V2: ct2_met_a -> ct2_mat_a -> ct2_a (join por ct_uuid)
    DATA lt_ct_keys TYPE TABLE OF zreing_ct2_met_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_ver).
      APPEND VALUE zreing_ct2_met_a(
        metric_code = ls_ver-%data-MetricCode
        version_num = ls_ver-%data-VersionNum ) TO lt_ct_keys.
    ENDLOOP.

    DATA lt_blocked TYPE HASHED TABLE OF zreing_mcv_a
                     WITH UNIQUE KEY metric_code version_num.
    IF lt_ct_keys IS NOT INITIAL.
      SELECT DISTINCT cm~metric_code, cm~version_num
        FROM zreing_ct2_met_a AS cm
        INNER JOIN zreing_ct2_a AS ct
          ON ct~ct_uuid   = cm~ct_uuid
         AND ct~ct_status = 'AC'
        FOR ALL ENTRIES IN @lt_ct_keys
        WHERE cm~metric_code = @lt_ct_keys-metric_code
          AND cm~version_num = @lt_ct_keys-version_num
        INTO TABLE @DATA(lt_blocked_raw).
      LOOP AT lt_blocked_raw INTO DATA(ls_b).
        INSERT VALUE zreing_mcv_a(
          metric_code = ls_b-metric_code
          version_num = ls_b-version_num )
          INTO TABLE lt_blocked.
      ENDLOOP.
    ENDIF.

    LOOP AT lt_versions INTO ls_ver.
      IF ls_ver-%data-VersionStatus = 'I'.
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La versión ya está inactiva' ) )
          TO reported-zi_reingmcversion.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_blocked[ metric_code = ls_ver-%data-MetricCode
                                  version_num = ls_ver-%data-VersionNum ] ).
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Existen contratos activos vinculados a esta versión (BR-02)' ) )
          TO reported-zi_reingmcversion.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
        ENTITY zi_reingmcversion
          UPDATE FIELDS ( VersionStatus )
          WITH VALUE #( ( %tky = ls_ver-%tky VersionStatus = 'I' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.

    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
      ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD new_version.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum VersionStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    " Setear flag IsNewVersion en el buffer transaccional
    " save_modified se encarga de crear la nueva version en DB
    MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        UPDATE FIELDS ( IsNewVersion )
        WITH VALUE #( FOR key IN keys
          ( %tky         = key-%tky
            IsNewVersion = 'X' ) )
      REPORTED DATA(lt_rep).

    " Retornar $self — TC-MC-063 se resuelve desde front via LastVersNum
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
      ( %tky   = ls-%tky
        %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD validate_duplicate_metric_code.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_v).

    " Collect all codes first, single bulk SELECT - avoids SELECT inside LOOP
    DATA lt_codes TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
    LOOP AT lt_v INTO DATA(ls_v).
      CHECK ls_v-%data-MetricCode IS NOT INITIAL.
      APPEND VALUE zreing_mc_a( metric_code = ls_v-%data-MetricCode ) TO lt_codes.
    ENDLOOP.

    DATA lt_existing_mc TYPE HASHED TABLE OF zreing_mc_a-metric_code
                          WITH UNIQUE KEY table_line.
    IF lt_codes IS NOT INITIAL.
      SELECT metric_code
        FROM zreing_mc_a
        FOR ALL ENTRIES IN @lt_codes
        WHERE metric_code = @lt_codes-metric_code
        INTO TABLE @DATA(lt_found).
      LOOP AT lt_found INTO DATA(ls_found).
        INSERT ls_found-metric_code INTO TABLE lt_existing_mc.
      ENDLOOP.
    ENDIF.

    LOOP AT lt_v INTO ls_v.
      CHECK ls_v-%data-MetricCode IS NOT INITIAL.
      IF line_exists( lt_existing_mc[ table_line = ls_v-%data-MetricCode ] ).
        APPEND VALUE #( %tky = ls_v-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_v-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Ya existe una métrica con el código { ls_v-%data-MetricCode }. Las versiones deben gestionarse dentro de la métrica original.| ) )
          TO reported-zi_reingmcversion.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_no_active_contracts.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricCode VersionNum VersionStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    " Solo aplica a versiones que ya estan activas (no a las que se estan activando ahora)
    " Las versiones que se estan activando se validan en activate_version
    DATA lt_ct_keys TYPE TABLE OF zreing_ct2_met_a WITH EMPTY KEY.
    LOOP AT lt_versions INTO DATA(ls_ver).
      CHECK ls_ver-%data-VersionStatus = 'A'.
      APPEND VALUE zreing_ct2_met_a(
        metric_code = ls_ver-%data-MetricCode
        version_num = ls_ver-%data-VersionNum ) TO lt_ct_keys.
    ENDLOOP.

    CHECK lt_ct_keys IS NOT INITIAL.

    DATA lt_active_ct TYPE HASHED TABLE OF zreing_mcv_a
                       WITH UNIQUE KEY metric_code version_num.

    SELECT DISTINCT cm~metric_code, cm~version_num
      FROM zreing_ct2_met_a AS cm
      INNER JOIN zreing_ct2_a AS ct
        ON ct~ct_uuid   = cm~ct_uuid
       AND ct~ct_status = 'AC'
      FOR ALL ENTRIES IN @lt_ct_keys
      WHERE cm~metric_code = @lt_ct_keys-metric_code
        AND cm~version_num = @lt_ct_keys-version_num
      INTO TABLE @DATA(lt_active_raw).

    LOOP AT lt_active_raw INTO DATA(ls_a).
      INSERT VALUE zreing_mcv_a(
        metric_code = ls_a-metric_code
        version_num = ls_a-version_num )
        INTO TABLE lt_active_ct.
    ENDLOOP.

    LOOP AT lt_versions INTO ls_ver.
      CHECK ls_ver-%data-VersionStatus = 'A'.
      IF line_exists( lt_active_ct[ metric_code = ls_ver-%data-MetricCode
                                    version_num = ls_ver-%data-VersionNum ] ).
        APPEND VALUE #( %tky = ls_ver-%tky ) TO failed-zi_reingmcversion.
        APPEND VALUE #( %tky = ls_ver-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'BR-01: Version con contratos activos, no editable' ) )
          TO reported-zi_reingmcversion.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_single_active_version.
    " TC-MC-059: Multiples versiones activas simultaneas permitidas por diseno.
    " Validacion deshabilitada.
  ENDMETHOD.

 METHOD earlynumbering_create.
    " Paso 1: ya tienen clave -> mapear tal cual (2do llamado en draft save sequence)
    LOOP AT entities INTO DATA(entity_with_key)
      WHERE MetricCode IS NOT INITIAL.
      APPEND CORRESPONDING #( entity_with_key )
        TO mapped-zi_reingmcversion.
    ENDLOOP.

    " Paso 2: sin clave -> calcular siguiente MetricCode
    DATA(entities_wo_key) = entities.
    DELETE entities_wo_key WHERE MetricCode IS NOT INITIAL.
    CHECK entities_wo_key IS NOT INITIAL.

    DATA lv_max_num TYPE i VALUE 0.
    DATA lt_mc_all TYPE HASHED TABLE OF zreing_mc_a
                    WITH UNIQUE KEY metric_code.

    " Buscar maximo en header
    DATA lt_mc TYPE TABLE OF zreing_mc_a WITH EMPTY KEY.
    SELECT metric_code FROM zreing_mc_a
      WHERE metric_code LIKE 'M-%'
      INTO CORRESPONDING FIELDS OF TABLE @lt_mc.
    LOOP AT lt_mc INTO DATA(ls_h).
      TRY.
          INSERT VALUE zreing_mc_a( metric_code = ls_h-metric_code )
            INTO TABLE lt_mc_all.
        CATCH cx_sy_itab_duplicate_key. ##NEEDED
      ENDTRY.
    ENDLOOP.

    " Buscar maximo en versiones (cubre casos donde header aun no fue creado)
    DATA lt_mc_vers TYPE TABLE OF zreing_mcv_a WITH EMPTY KEY.
    SELECT metric_code FROM zreing_mcv_a
      WHERE metric_code LIKE 'M-%'
      INTO CORRESPONDING FIELDS OF TABLE @lt_mc_vers.
    LOOP AT lt_mc_vers INTO DATA(ls_v).
      TRY.
          INSERT VALUE zreing_mc_a( metric_code = ls_v-metric_code )
            INTO TABLE lt_mc_all.
        CATCH cx_sy_itab_duplicate_key. ##NEEDED
      ENDTRY.
    ENDLOOP.

    " Buscar maximo en draft table (cubre drafts pendientes)
    DATA lt_mc_draft TYPE TABLE OF zreing_mcv_d WITH EMPTY KEY.
    SELECT metriccode FROM zreing_mcv_d
      WHERE metriccode LIKE 'M-%'
      INTO CORRESPONDING FIELDS OF TABLE @lt_mc_draft.
    LOOP AT lt_mc_draft INTO DATA(ls_d).
      TRY.
          INSERT VALUE zreing_mc_a( metric_code = ls_d-metriccode )
            INTO TABLE lt_mc_all.
        CATCH cx_sy_itab_duplicate_key. ##NEEDED
      ENDTRY.
    ENDLOOP.

    LOOP AT lt_mc_all INTO DATA(ls_mc).
      DATA(lv_suffix) = ls_mc-metric_code+2.
      TRY.
          DATA(lv_num) = CONV i( lv_suffix ).
          IF lv_num > lv_max_num.
            lv_max_num = lv_num.
          ENDIF.
        CATCH cx_sy_conversion_no_number.
      ENDTRY.
    ENDLOOP.

    DATA lv_nxt TYPE i.
    lv_nxt = lv_max_num + 1.

    LOOP AT entities_wo_key INTO DATA(entity).
      " M-XXXX: 'M-' + 4 digitos = 6 chars, largo del campo CHAR(6)
      DATA(lv_code) = |M-{ lv_nxt WIDTH = 4 ALIGN = RIGHT PAD = '0' }|.

      APPEND VALUE #(
        %cid       = entity-%cid
        %is_draft  = entity-%is_draft
        MetricCode = lv_code
        VersionNum = '001' )
        TO mapped-zi_reingmcversion.

      lv_nxt = lv_nxt + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_status_texts.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( VersionStatus MetricStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    IF lt_versions IS INITIAL. RETURN. ENDIF.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingmcversion\\zi_reingmcversion.

    LOOP AT lt_versions INTO DATA(ls_ver).
      APPEND VALUE #(
        %tky              = ls_ver-%tky
        VersionStatusText = COND #(
          WHEN ls_ver-%data-VersionStatus = 'A' THEN 'Activa'
          WHEN ls_ver-%data-VersionStatus = 'I' THEN 'Inactiva'
          WHEN ls_ver-%data-VersionStatus = 'D' THEN 'Draft'
          ELSE ls_ver-%data-VersionStatus )
        MetricStatusText  = COND #(
          WHEN ls_ver-%data-MetricStatus = 'A' THEN 'Activa'
          WHEN ls_ver-%data-MetricStatus = 'I' THEN 'Inactiva'
          ELSE ls_ver-%data-MetricStatus )
        %control-VersionStatusText = if_abap_behv=>mk-on
        %control-MetricStatusText  = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
        ENTITY zi_reingmcversion
          UPDATE FIELDS ( VersionStatusText MetricStatusText )
          WITH lt_update
        REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

METHOD set_metric_type_text.
    READ ENTITIES OF zi_reingmcversion IN LOCAL MODE
      ENTITY zi_reingmcversion
        FIELDS ( MetricType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    IF lt_versions IS INITIAL. RETURN. ENDIF.

    DATA lt_update TYPE TABLE FOR UPDATE zi_reingmcversion\\zi_reingmcversion.

    LOOP AT lt_versions INTO DATA(ls_ver).
      APPEND VALUE #(
        %tky           = ls_ver-%tky
        MetricTypeText = COND #(
          WHEN ls_ver-%data-MetricType = 'M' THEN 'Manual'
          ELSE ls_ver-%data-MetricType )
        %control-MetricTypeText = if_abap_behv=>mk-on
      ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingmcversion IN LOCAL MODE
        ENTITY zi_reingmcversion
          UPDATE FIELDS ( MetricTypeText )
          WITH lt_update
        REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
