" Begin Mod 01.10.2026 EXT_AGFAGINA - mensajes de mas de 50 caracteres.
" En este sistema el mensaje estandar que usa new_message_with_text (SABP_BEHV
" 100) tiene como texto solo "&1": de las cuatro variables de 50 caracteres en
" las que se reparte el texto, se muestra unicamente la primera. Todo mensaje
" de mas de 50 caracteres se cortaba (ej. "El monto acumulado de A (800000.00)
" supera" y nada mas). Se usa ZREING_CM 000 = "&1&2&3&4" (hasta 200 caracteres).
" SPLIT reparte el texto en las cuatro variables. El T100 descarta los blancos
" finales de cada variable: si un corte cae justo despues de un espacio, las
" palabras quedarian pegadas. Por eso se corta antes del espacio y el espacio
" pasa al comienzo del bloque siguiente, donde si se conserva.
CLASS lcl_msg DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_vars,
             v1 TYPE symsgv,
             v2 TYPE symsgv,
             v3 TYPE symsgv,
             v4 TYPE symsgv,
           END OF ty_vars.
    CLASS-METHODS split
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rs_vars) TYPE ty_vars.
ENDCLASS.

CLASS lcl_msg IMPLEMENTATION.
  METHOD split.
    DATA lt_parts TYPE STANDARD TABLE OF symsgv WITH EMPTY KEY.
    DATA(lv_rest) = iv_text.
    DO 4 TIMES.
      IF lv_rest IS INITIAL.
        EXIT.
      ENDIF.
      DATA(lv_len) = nmin( val1 = 50 val2 = strlen( lv_rest ) ).
      WHILE lv_len > 1 AND lv_len < strlen( lv_rest )
            AND substring( val = lv_rest off = lv_len - 1 len = 1 ) = ` `.
        lv_len = lv_len - 1.
      ENDWHILE.
      APPEND CONV symsgv( substring( val = lv_rest len = lv_len ) ) TO lt_parts.
      lv_rest = substring( val = lv_rest off = lv_len ).
    ENDDO.
    rs_vars-v1 = VALUE #( lt_parts[ 1 ] OPTIONAL ).
    rs_vars-v2 = VALUE #( lt_parts[ 2 ] OPTIONAL ).
    rs_vars-v3 = VALUE #( lt_parts[ 3 ] OPTIONAL ).
    rs_vars-v4 = VALUE #( lt_parts[ 4 ] OPTIONAL ).
  ENDMETHOD.
ENDCLASS.
" End Mod 01.10.2026 EXT_AGFAGINA

CLASS lhc_Period DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Period RESULT result.
    METHODS InitializePeriod FOR MODIFY
      IMPORTING keys FOR ACTION Period~InitializePeriod RESULT result.
    METHODS UploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION Period~UploadExcel RESULT result.
    METHODS ExportTemplate FOR MODIFY
      IMPORTING keys FOR ACTION Period~ExportTemplate RESULT result.
    " Mod 01.10.2026 EXT_AGFAGINA: mensaje de hasta 200 caracteres (ZREING_CM 000).
    METHODS msg
      IMPORTING iv_text       TYPE string
                iv_severity   TYPE if_abap_behv_message=>t_severity
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_Period IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD msg.
    " Mod 01.10.2026 EXT_AGFAGINA - ver comentario de lcl_msg.
    DATA(ls_v) = lcl_msg=>split( iv_text ).
    ro_msg = new_message( id       = 'ZREING_CM'
                          number   = '000'
                          severity = iv_severity
                          v1       = ls_v-v1
                          v2       = ls_v-v2
                          v3       = ls_v-v3
                          v4       = ls_v-v4 ).
  ENDMETHOD.

  METHOD InitializePeriod.
    DATA(lv_year)  = keys[ 1 ]-%param-PeriodYear.
    DATA(lv_month) = keys[ 1 ]-%param-PeriodMonth.

    SELECT SINGLE period_year, period_month
      FROM zreing_cm_period
      WHERE period_year  = @lv_year
        AND period_month = @lv_month
      INTO @DATA(ls_existing).

    IF sy-subrc <> 0.
      GET TIME STAMP FIELD DATA(lv_created_at).
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY Period
          CREATE FIELDS ( PeriodYear PeriodMonth CreatedBy CreatedAt )
          WITH VALUE #( ( %cid        = 'NEW_PERIOD'
                          PeriodYear  = lv_year
                          PeriodMonth = lv_month
                          CreatedBy   = sy-uname
                          CreatedAt   = lv_created_at ) )
        REPORTED DATA(ls_rep)
        FAILED   DATA(ls_fail)
        MAPPED   DATA(ls_map).
    ENDIF.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY Period ALL FIELDS
        WITH VALUE #( ( PeriodYear  = lv_year
                        PeriodMonth = lv_month ) )
      RESULT DATA(lt_period)
      FAILED DATA(ls_failed_read).

    result = VALUE #( FOR ls IN lt_period
                      ( %cid              = keys[ 1 ]-%cid
                        %param-PeriodYear  = ls-PeriodYear
                        %param-PeriodMonth = ls-PeriodMonth ) ).
  ENDMETHOD.

  METHOD UploadExcel.

    DATA(ls_key)   = keys[ 1 ].
    DATA(lv_year)  = ls_key-%tky-PeriodYear.
    DATA(lv_month) = ls_key-%tky-PeriodMonth.

    " ----- Decodificar Base64 -> xstring -----
    DATA lv_xcontent TYPE xstring.
    TRY.
        lv_xcontent = xco_cp=>string( ls_key-%param-FileContent
          )->as_xstring( xco_cp_binary=>text_encoding->base64 )->value.
      CATCH cx_root INTO DATA(lx_b64).
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |Error al decodificar el archivo: { lx_b64->get_text( ) }| ) )
          TO reported-period.
        RETURN.
    ENDTRY.

    IF lv_xcontent IS INITIAL.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'El contenido del archivo esta vacio (FileContent).' ) )
        TO reported-period.
      RETURN.
    ENDIF.

    " ----- Parsear Excel y validar filas (N1 + N2) -----
    DATA(lo_hdl) = NEW zcl_reing_cm_upload_hdl( ).
    DATA(ls_imp) = lo_hdl->import_file(
      iv_period_year  = lv_year
      iv_period_month = lv_month
      iv_file_content = lv_xcontent ).

    " ----- Abortar si falla validacion estructural N1 -----
    IF ls_imp-aborted = abap_true.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = msg( iv_text     = ls_imp-abort_reason
                                  iv_severity = if_abap_behv_message=>severity-error ) )
        TO reported-period.
      RETURN.
    ENDIF.

    " ----- Abortar si alguna fila tiene error N2 (no se importa nada) -----
    DATA lt_err_lines TYPE TABLE OF string.
    LOOP AT ls_imp-results INTO DATA(ls_err) WHERE status = 'E'.
      APPEND |Fila { ls_err-row_number }: { ls_err-message }| TO lt_err_lines.
    ENDLOOP.

    " Mod 01.10.2026 EXT_AGFAGINA: los mensajes del import van por msg( ), que
    " admite hasta 200 caracteres. Con new_message_with_text se cortaban en 50.
    IF lt_err_lines IS NOT INITIAL.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = msg( iv_text     = |El Excel tiene { lines( lt_err_lines ) } error(es). No se importó ninguna línea. Revise y vuelva a cargar.|
                                  iv_severity = if_abap_behv_message=>severity-error ) )
        TO reported-period.
      LOOP AT lt_err_lines INTO DATA(lv_err_txt).
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = msg( iv_text     = lv_err_txt
                                    iv_severity = if_abap_behv_message=>severity-error ) )
          TO reported-period.
      ENDLOOP.
      RETURN.
    ENDIF.

    " Begin Mod 08.09.2026 EXT_AGFAGINA - los avisos N2 se reportan ANTES del RETURN.
    " El bloque de avisos estaba mas abajo, despues del "IF create_lines IS INITIAL.
    " RETURN. ENDIF.". Cuando TODAS las filas se descartaban por duplicadas
    " (create_lines vacio), la accion salia antes de reportar y el usuario no veia
    " nada: ni error ni aviso. Es el caso de un Excel de una sola fila ya existente.
    LOOP AT ls_imp-results INTO DATA(ls_res_w) WHERE status = 'W'.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = msg( iv_text     = |Fila { ls_res_w-row_number }: { ls_res_w-message }|
                                  iv_severity = if_abap_behv_message=>severity-warning ) )
        TO reported-period.
    ENDLOOP.

    " ----- Si no hay filas validas para crear: salir (los avisos ya se reportaron) -----
    IF ls_imp-create_lines IS INITIAL.
      IF ls_imp-results IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-warning
                          text     = 'El archivo no contiene filas para importar.' ) )
          TO reported-period.
      ENDIF.
      RETURN.
    ENDIF.
    " End Mod 08.09.2026 EXT_AGFAGINA

    " ----- Asegurar que el Period ACTIVO exista (crear con mk-off si falta) -----
    SELECT SINGLE period_year, period_month
      FROM zreing_cm_period
      WHERE period_year  = @lv_year
        AND period_month = @lv_month
      INTO @DATA(ls_per_exist).

    IF sy-subrc <> 0.
      GET TIME STAMP FIELD DATA(lv_created_at).
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY Period
          CREATE FIELDS ( PeriodYear PeriodMonth CreatedBy CreatedAt )
          WITH VALUE #( ( %cid        = 'ACT_PERIOD'
                          %is_draft   = if_abap_behv=>mk-off
                          PeriodYear  = lv_year
                          PeriodMonth = lv_month
                          CreatedBy   = sy-uname
                          CreatedAt   = lv_created_at ) )
        REPORTED DATA(ls_rep_per)
        FAILED   DATA(ls_fail_per).
    ENDIF.

    " Begin Mod 08.09.2026 EXT_AGFAGINA - separar altas de actualizaciones.
    " El handler marca con CM_H_ID las lineas cuya combinacion ya existe en un
    " estado modificable (GRAV/PEND/ERR): esas PISAN el registro en lugar de
    " crear uno nuevo. Las que vienen sin CM_H_ID son altas.
    DATA lt_upd_lines TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT ls_imp-create_lines INTO DATA(ls_upd_src) WHERE cm_h_id IS NOT INITIAL.
      APPEND VALUE #(
        %is_draft = if_abap_behv=>mk-off
        CmHId     = ls_upd_src-cm_h_id
        CtUuid    = ls_upd_src-ct_uuid
        CtExtNum  = ls_upd_src-ct_ext_num
        MatUuid   = ls_upd_src-mat_uuid
        Matnr     = ls_upd_src-matnr
        OpType    = ls_upd_src-op_type
        " Mod 01.10.2026 EXT_AGFAGINA - defecto 109.
        OpInstanceNum = ls_upd_src-op_instance_num
        DeferType = ls_upd_src-defer_type
        Amount    = ls_upd_src-amount
        DeltaFlag = ls_upd_src-delta_flag ) TO lt_upd_lines.
    ENDLOOP.

    IF lt_upd_lines IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader
          UPDATE FIELDS ( CtUuid CtExtNum MatUuid Matnr
                          OpType OpInstanceNum DeferType Amount DeltaFlag )
          WITH lt_upd_lines
        REPORTED DATA(ls_rep_upd)
        FAILED   DATA(ls_fail_upd).

      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-success
                        text     = |{ lines( lt_upd_lines ) } registro(s) existente(s) actualizado(s) con los nuevos valores.| ) )
        TO reported-period.
    ENDIF.
    " End Mod 08.09.2026 EXT_AGFAGINA

    " ----- Crear los CMHeaders ACTIVOS via CREATE BY \_Items (mk-off) -----
    " El padre (Period) ya existe -> se referencia por su CLAVE, no por %cid_ref.
    DATA lt_create TYPE TABLE FOR CREATE zi_reingcmperiod\_Items.
    DATA lv_cnt TYPE i VALUE 0.

    LOOP AT ls_imp-create_lines INTO DATA(ls_line) WHERE cm_h_id IS INITIAL.
      lv_cnt = lv_cnt + 1.
      APPEND VALUE #(
                %is_draft   = if_abap_behv=>mk-off
                PeriodYear  = lv_year
                PeriodMonth = lv_month
                %target = VALUE #( (
                  %is_draft   = if_abap_behv=>mk-off
                  %cid        = |UPLOAD_{ lv_cnt }|
                  PeriodYear  = lv_year
                  PeriodMonth = lv_month
                  CtUuid      = ls_line-ct_uuid
                  CtExtNum    = ls_line-ct_ext_num
                  MatUuid     = ls_line-mat_uuid
                  Matnr       = ls_line-matnr
                  OpType      = ls_line-op_type
                  " Mod 01.10.2026 EXT_AGFAGINA - defecto 109.
                  OpInstanceNum = ls_line-op_instance_num
                  DeferType   = ls_line-defer_type
                  Amount      = ls_line-amount
                  DeltaFlag   = ls_line-delta_flag
                  CmStatus    = 'PEND'
                ) )
              ) TO lt_create.
    ENDLOOP.

    MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY Period
        CREATE BY \_Items
          FIELDS ( PeriodYear PeriodMonth
                   CtUuid CtExtNum MatUuid Matnr
                   OpType OpInstanceNum DeferType Amount DeltaFlag CmStatus )
          WITH lt_create
      REPORTED DATA(ls_rep2)
      FAILED   DATA(ls_fail2)
      MAPPED   DATA(ls_map2).

    " ----- Crear las receptoras participantes (CMRecv) por linea con receptoras -----
    " Indice cid->CmHId de los headers recien creados (acceso O(log n), sin scan en loop)
    TYPES: BEGIN OF ty_cid_map,
             cid   TYPE abp_behv_cid,
             cmhid TYPE zreing_cm_h_a-cm_h_id,
           END OF ty_cid_map.
    DATA lt_cid_map TYPE SORTED TABLE OF ty_cid_map WITH UNIQUE KEY cid.
    lt_cid_map = VALUE #( FOR ls_m IN ls_map2-cmheader
                          WHERE ( CmHId IS NOT INITIAL )
                          ( cid = ls_m-%cid cmhid = ls_m-CmHId ) ).

    DATA lt_create_recv TYPE TABLE FOR CREATE zi_reingcmheader\_Receivers.
    DATA lv_cnt_r TYPE i VALUE 0.
    " Mod 08.09.2026 EXT_AGFAGINA: mismo filtro que el loop de creacion. Sin el,
    " los contadores se desalinean y el %cid UPLOAD_n apuntaria a otra linea.
    LOOP AT ls_imp-create_lines INTO DATA(ls_line_r) WHERE cm_h_id IS INITIAL.
      lv_cnt_r = lv_cnt_r + 1.
      CHECK ls_line_r-receptoras IS NOT INITIAL.
      READ TABLE lt_cid_map INTO DATA(ls_cid)
        WITH KEY cid = |UPLOAD_{ lv_cnt_r }|.
      CHECK sy-subrc = 0.
      " %target armado con expresion FOR (sin loop anidado)
      APPEND VALUE #(
        %is_draft = if_abap_behv=>mk-off
        CmHId     = ls_cid-cmhid
        %target = VALUE #( FOR lv_b IN ls_line_r-receptoras INDEX INTO lv_i
          ( %is_draft = if_abap_behv=>mk-off
            %cid      = |RECV_{ lv_cnt_r }_{ lv_i }|
            BukrsRecv = lv_b ) )
      ) TO lt_create_recv.
    ENDLOOP.

    IF lt_create_recv IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader
          CREATE BY \_Receivers
            FIELDS ( BukrsRecv )
            WITH lt_create_recv
        REPORTED DATA(ls_rep_r)
        FAILED   DATA(ls_fail_r).
    ENDIF.

    " Mod 08.09.2026 EXT_AGFAGINA: el bloque de avisos N2 se movio al inicio del
    " metodo, antes del RETURN por create_lines vacio. Ver comentario de arriba.

    " ----- RESULT: leer los CMHeaders creados y devolverlos (activos) -----
    DATA lt_new_keys TYPE TABLE FOR READ IMPORT zi_reingcmheader.
    lt_new_keys = VALUE #( FOR ls_m IN ls_map2-cmheader
                           WHERE ( CmHId IS NOT INITIAL )
                           ( CmHId     = ls_m-CmHId
                             %is_draft = if_abap_behv=>mk-off ) ).

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader ALL FIELDS
        WITH lt_new_keys
      RESULT DATA(lt_new_cm).

    result = VALUE #( FOR ls IN lt_new_cm
                      ( %tky   = ls_key-%tky
                        %param = ls ) ).

  ENDMETHOD.




  METHOD ExportTemplate.
    " Genera el template Excel de 10 columnas (vacío) y lo devuelve en base64.
    DATA(lo_hdl) = NEW zcl_reing_cm_upload_hdl( ).
    DATA(lv_xstring) = lo_hdl->export_template(
      iv_period_year  = keys[ 1 ]-%param-PeriodYear
      iv_period_month = keys[ 1 ]-%param-PeriodMonth ).

    " Codificar xstring -> base64
    DATA(lv_base64) = xco_cp=>xstring( lv_xstring
      )->as_string( xco_cp_binary=>text_encoding->base64 )->value.

    " Nombre de archivo con el período (si vino en el parámetro)
    DATA(lv_year)  = keys[ 1 ]-%param-PeriodYear.
    DATA(lv_month) = keys[ 1 ]-%param-PeriodMonth.
    DATA lv_fname TYPE c LENGTH 255.
    IF lv_year IS NOT INITIAL AND lv_month IS NOT INITIAL.
      lv_fname = |plantilla_carga_CM_{ lv_year }-{ lv_month }.xlsx|.
    ELSE.
      lv_fname = |plantilla_carga_CM.xlsx|.
    ENDIF.

    result = VALUE #( ( %cid   = keys[ 1 ]-%cid
                        %param-FileContent = lv_base64
                        %param-FileName    = lv_fname
                        %param-MimeType    =
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_CMHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    CLASS-DATA gt_log_buffer TYPE STANDARD TABLE OF zreing_cm_log.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR CMHeader RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR CMHeader RESULT result.
    METHODS Devolver FOR MODIFY
      IMPORTING keys FOR ACTION CMHeader~Devolver RESULT result.
    METHODS Enviar FOR MODIFY
      IMPORTING keys FOR ACTION CMHeader~Enviar RESULT result.
    METHODS Liberar FOR MODIFY
      IMPORTING keys FOR ACTION CMHeader~Liberar RESULT result.
    METHODS DeriveContractData FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CMHeader~DeriveContractData.
    METHODS DeriveCurrency FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CMHeader~DeriveCurrency.
    METHODS DeriveLoadSeq FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CMHeader~DeriveLoadSeq.
    METHODS DeriveSupersede FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CMHeader~DeriveSupersede.
    METHODS DeriveStatus FOR DETERMINE ON SAVE
      IMPORTING keys FOR CMHeader~DeriveStatus.
    METHODS ValidateAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateAmount.
    METHODS ValidateContract FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateContract.
    METHODS ValidateDeferType FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateDeferType.
    METHODS ValidateNotFinalized FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateNotFinalized.
    METHODS ValidateDeferTypeExistsInCT FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateDeferTypeExistsInCT.
    METHODS ValidateDeltaFlag FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateDeltaFlag.
    METHODS ValidateMaterial FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateMaterial.
    METHODS ValidateNoAccountingDoc FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateNoAccountingDoc.
    METHODS ValidateOpType FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateOpType.
    METHODS ValidateUniqueness FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateUniqueness.
    " Mod 29.09.2026 EXT_AGFAGINA - CR-002 / BR-CM-14 (Ceiling Rule).
    METHODS ValidateCeilingAmount FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateCeilingAmount.
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion (instancia).
    METHODS DeriveOpInstance FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CMHeader~DeriveOpInstance.
    METHODS ValidateOpInstance FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMHeader~ValidateOpInstance.
    " Mod 01.10.2026 EXT_AGFAGINA: mensaje de hasta 200 caracteres (ZREING_CM 000).
    METHODS msg
      IMPORTING iv_text       TYPE string
                iv_severity   TYPE if_abap_behv_message=>t_severity
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
    TYPES tt_keys TYPE TABLE FOR UPDATE zi_reingcmheader.
    METHODS write_log
      IMPORTING it_keys        TYPE tt_keys
                iv_action_code TYPE zreing_cm_log-action_code.
ENDCLASS.

CLASS lhc_CMHeader IMPLEMENTATION.

  METHOD get_global_authorizations.
    " CMHeader es lock dependent — sin global auth propia
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CmStatus AccountingDoc CtUuid MatUuid OpType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_cm)
      FAILED DATA(ls_failed).

    " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002: no borrar un tope con dependiente.
    " Definicion de Vinicius (29.09.2026): no se puede borrar un registro de un
    " tipo que es tope de otro (ej. F, tope de A) mientras exista un dependiente
    " para el mismo contrato + material + periodo. Primero hay que borrar la A.
    " Se resuelve con control de instancia (Borrar deshabilitado) en vez de una
    " validacion: en un borrado el registro ya no se puede leer para validarlo, y
    " asi el usuario ve la restriccion antes de intentarlo.
    " Los hermanos se leen por la asociacion al Period, en el mismo estado que la
    " instancia: si la A se borra en el mismo borrador, la F se habilita.
    DATA lt_blocked TYPE HASHED TABLE OF zreing_cm_h_a-cm_h_id WITH UNIQUE KEY table_line.
    TYPES: BEGIN OF ty_ceil_fc,
             op_type         TYPE zreing_op_types-op_type,
             ceiling_op_type TYPE zreing_op_types-ceiling_op_type,
           END OF ty_ceil_fc.
    DATA lt_ceil_fc TYPE HASHED TABLE OF ty_ceil_fc WITH UNIQUE KEY op_type.
    SELECT op_type, ceiling_op_type FROM zreing_op_types
      WHERE ceiling_op_type <> @space
      INTO TABLE @lt_ceil_fc.
    IF lt_ceil_fc IS NOT INITIAL AND lt_cm IS NOT INITIAL.
      READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader BY \_Period
          FIELDS ( PeriodYear PeriodMonth )
          WITH CORRESPONDING #( keys )
        RESULT DATA(lt_per_fc).
      SORT lt_per_fc BY %tky.
      DELETE ADJACENT DUPLICATES FROM lt_per_fc COMPARING %tky.

      READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY Period BY \_Items
          FIELDS ( CtUuid MatUuid OpType CmStatus )
          WITH CORRESPONDING #( lt_per_fc )
        RESULT DATA(lt_items_fc).

      " Topes que tienen al menos un dependiente vivo, en una sola pasada: por cada
      " registro de un tipo con tope se marca (contrato, material, tipo tope).
      TYPES: BEGIN OF ty_top_fc,
               ct_uuid  TYPE zreing_cm_h_a-ct_uuid,
               mat_uuid TYPE zreing_cm_h_a-mat_uuid,
               op_type  TYPE zreing_cm_h_a-op_type,
             END OF ty_top_fc.
      DATA lt_top_fc TYPE HASHED TABLE OF ty_top_fc WITH UNIQUE KEY ct_uuid mat_uuid op_type.
      LOOP AT lt_items_fc INTO DATA(ls_it_fc) WHERE CmStatus <> 'SUPS' AND CmStatus <> 'ERR'.
        READ TABLE lt_ceil_fc INTO DATA(ls_cf) WITH TABLE KEY op_type = ls_it_fc-OpType.
        IF sy-subrc = 0.
          INSERT VALUE #( ct_uuid  = ls_it_fc-CtUuid
                          mat_uuid = ls_it_fc-MatUuid
                          op_type  = ls_cf-ceiling_op_type ) INTO TABLE lt_top_fc.
        ENDIF.
      ENDLOOP.

      LOOP AT lt_cm INTO DATA(ls_cm_fc).
        IF line_exists( lt_top_fc[ ct_uuid  = ls_cm_fc-CtUuid
                                   mat_uuid = ls_cm_fc-MatUuid
                                   op_type  = ls_cm_fc-OpType ] ).
          INSERT ls_cm_fc-CmHId INTO TABLE lt_blocked.
        ENDIF.
      ENDLOOP.
    ENDIF.
    " End Mod 29.09.2026 EXT_AGFAGINA

    " Begin Mod 12.09.2026 EXT_AGFAGINA - contemplar la instancia NUEVA.
    " El boton "Agregar" no hacia nada: la linea se creaba pero con TODOS los
    " campos en read_only y %update/%delete deshabilitados.
    " Causa: CmStatus lo asigna DeriveStatus, que es "on save". En una instancia
    " recien creada el campo esta VACIO, no coincide con 'PEND'/'GRAV'/'ERR' y
    " cada COND cae en el ELSE. Resultado: fila inservible.
    " Se agrega "lv_st IS INITIAL" a las condiciones para tratar el alta como un
    " registro editable. Es el mismo defecto que FX18 en ME (get_instance_features
    " de ZBP_REINGMEHEADER), donde el control se resolvio con el mismo criterio.
    result = VALUE #(
      FOR ls_cm IN lt_cm
      LET lv_st  = ls_cm-CmStatus
          lv_edt = COND abap_bool( WHEN ls_cm-CmStatus IS INITIAL
                                     OR ls_cm-CmStatus = 'PEND'
                                     OR ls_cm-CmStatus = 'GRAV'
                                     OR ls_cm-CmStatus = 'ERR'
                                   THEN abap_true ELSE abap_false ) IN
      ( %tky             = ls_cm-%tky
        %update          = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
        %field-CtUuid    = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-mandatory
                                   ELSE if_abap_behv=>fc-f-read_only )
        " Mod 12.09.2026 EXT_AGFAGINA: CtExtNum y Matnr son los campos que la UI
        " expone con value help. Siguen la misma regla que CtUuid / MatUuid.
        %field-CtExtNum  = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-mandatory
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-Matnr     = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-mandatory
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-MatUuid   = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-mandatory
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-OpType    = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-mandatory
                                   ELSE if_abap_behv=>fc-f-read_only )
        " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion. No es
        " obligatorio en pantalla porque DeriveOpInstance lo completa cuando hay una
        " sola opcion; si hay varias, lo exige ValidateOpInstance con su mensaje.
        %field-OpInstanceNum = COND #( WHEN lv_edt = abap_true
                                       THEN if_abap_behv=>fc-f-unrestricted
                                       ELSE if_abap_behv=>fc-f-read_only )
        %field-DeferType = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-unrestricted
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-Amount    = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-unrestricted
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-Currency  = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-unrestricted
                                   ELSE if_abap_behv=>fc-f-read_only )
        %field-DeltaFlag = COND #( WHEN lv_edt = abap_true
                                   THEN if_abap_behv=>fc-f-unrestricted
                                   ELSE if_abap_behv=>fc-f-read_only )
        %action-Enviar   = COND #( WHEN lv_st = 'GRAV'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
        %action-Liberar  = COND #( WHEN lv_st = 'ENVI'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
        %action-Devolver = COND #( WHEN lv_st = 'ENVI' OR lv_st = 'LIBD'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
        %delete          = COND #( WHEN lv_edt = abap_true
                                     AND ls_cm-AccountingDoc IS INITIAL
                                     " Mod 29.09.2026 EXT_AGFAGINA - CR-002: tope con dependiente
                                     AND NOT line_exists( lt_blocked[ table_line = ls_cm-CmHId ] )
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
      ) ).
    " End Mod 12.09.2026 EXT_AGFAGINA
  ENDMETHOD.

  METHOD Enviar.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    DATA lt_valid TYPE TABLE FOR UPDATE zi_reingcmheader.
    GET TIME STAMP FIELD DATA(lv_now_env).
    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-CmStatus <> 'GRAV'.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede enviar en estado GRAV (BR-CM-08)' ) )
          TO reported-cmheader.
      ELSE.
        APPEND VALUE #( %key          = ls_cm-%key
                        CmStatus      = 'ENVI'
                        CmStatusText  = 'Enviado'
                        SentBy        = sy-uname
                        SentAt        = lv_now_env ) TO lt_valid.
      ENDIF.
    ENDLOOP.

    IF lt_valid IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CmStatus CmStatusText SentBy SentAt )
        WITH lt_valid REPORTED DATA(lt_rep).
      write_log( it_keys = CORRESPONDING #( lt_valid ) iv_action_code = 'ENVIAR' ).
    ENDIF.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
                      ( %key   = ls-%key
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  METHOD Liberar.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    DATA lt_valid TYPE TABLE FOR UPDATE zi_reingcmheader.
    GET TIME STAMP FIELD DATA(lv_now_lib).
    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-CmStatus <> 'ENVI'.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede liberar en estado ENVI (BR-CM-10)' ) )
          TO reported-cmheader.
      ELSE.
        APPEND VALUE #( %key          = ls_cm-%key
                        CmStatus      = 'LIBD'
                        CmStatusText  = 'Liberado'
                        ReleasedBy    = sy-uname
                        ReleasedAt    = lv_now_lib ) TO lt_valid.
      ENDIF.
    ENDLOOP.

    IF lt_valid IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CmStatus CmStatusText ReleasedBy ReleasedAt )
        WITH lt_valid REPORTED DATA(lt_rep).
      write_log( it_keys = CORRESPONDING #( lt_valid ) iv_action_code = 'LIBERAR' ).
    ENDIF.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
                      ( %key   = ls-%key
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  METHOD Devolver.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CmStatus AccountingDoc )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    DATA lt_valid TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-CmStatus <> 'ENVI' AND ls_cm-CmStatus <> 'LIBD'.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo se puede devolver en estado ENVI o LIBD (BR-CM-11)' ) )
          TO reported-cmheader.
        CONTINUE.
      ENDIF.
      IF ls_cm-CmStatus = 'LIBD' AND ls_cm-AccountingDoc IS NOT INITIAL.
        APPEND VALUE #( %key = ls_cm-%key
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-warning
                          text     = |Registro con doc. { ls_cm-AccountingDoc } no será devuelto| ) )
          TO reported-cmheader.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %key         = ls_cm-%key
                      CmStatus     = 'GRAV'
                      CmStatusText = 'Grabado' ) TO lt_valid.
    ENDLOOP.

    IF lt_valid IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CmStatus CmStatusText )
        WITH lt_valid REPORTED DATA(lt_rep).
      write_log( it_keys = CORRESPONDING #( lt_valid ) iv_action_code = 'DEVOLVER' ).
    ENDIF.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader ALL FIELDS
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR ls IN lt_result
                      ( %key   = ls-%key
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  METHOD write_log.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CmHId PeriodYear PeriodMonth CtExtNum Matnr OpType
                 DeferType LoadSeq Amount Currency CmStatus )
        WITH CORRESPONDING #( it_keys )
      RESULT DATA(lt_cm).

    IF lt_cm IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT lt_cm INTO DATA(ls_cm).
      DATA lv_uuid TYPE sysuuid_x16.
      TRY.
          lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          CONTINUE.
      ENDTRY.

      APPEND VALUE zreing_cm_log(
        log_id       = lv_uuid
        cm_h_id      = ls_cm-CmHId
        period_year  = ls_cm-PeriodYear
        period_month = ls_cm-PeriodMonth
        action_code  = iv_action_code
        ct_ext_num   = ls_cm-CtExtNum
        matnr        = ls_cm-Matnr
        op_type      = ls_cm-OpType
        defer_type   = ls_cm-DeferType
        load_seq     = ls_cm-LoadSeq
        amount       = ls_cm-Amount
        currency     = ls_cm-Currency
        cm_status    = ls_cm-CmStatus
        action_user  = sy-uname
        action_at    = lv_now ) TO gt_log_buffer.
    ENDLOOP.

  ENDMETHOD.

  METHOD DeriveContractData.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    " --- Derivar CtExtNum desde CtUuid ---
    DATA lt_fae TYPE SORTED TABLE OF zreing_ct2_a WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE CtUuid IS NOT INITIAL.
      TRY.
          INSERT VALUE zreing_ct2_a( ct_uuid = ls_cm-CtUuid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA lt_ct TYPE SORTED TABLE OF zreing_ct2_a WITH UNIQUE KEY ct_uuid.
    IF lt_fae IS NOT INITIAL.
      SELECT ct_uuid, ct_id FROM zreing_ct2_a
        FOR ALL ENTRIES IN @lt_fae
        WHERE ct_uuid = @lt_fae-ct_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_ct.
    ENDIF.

    " --- Derivar Matnr desde (CtUuid, MatUuid) ---
    TYPES: BEGIN OF ty_fae_mat,
             ct_uuid  TYPE zreing_ct2_mat_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_mat_a-mat_uuid,
           END OF ty_fae_mat.
    DATA lt_fae_mat TYPE SORTED TABLE OF ty_fae_mat WITH UNIQUE KEY ct_uuid mat_uuid.
    LOOP AT lt_cm INTO ls_cm WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_mat( ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid )
            INTO TABLE lt_fae_mat.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    TYPES: BEGIN OF ty_mat_res,
             ct_uuid  TYPE zreing_ct2_mat_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_mat_a-mat_uuid,
             matnr    TYPE zreing_ct2_mat_a-matnr,
           END OF ty_mat_res.
    DATA lt_mat TYPE SORTED TABLE OF ty_mat_res WITH UNIQUE KEY ct_uuid mat_uuid.
    IF lt_fae_mat IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, matnr FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @lt_fae_mat
        WHERE ct_uuid  = @lt_fae_mat-ct_uuid
          AND mat_uuid = @lt_fae_mat-mat_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_mat.
    ENDIF.

    " --- Construir update con ambos campos derivados ---
    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingcmheader.
    DATA ls_line LIKE LINE OF lt_upd.
    LOOP AT lt_cm INTO ls_cm WHERE CtUuid IS NOT INITIAL.
      CLEAR ls_line.
      ls_line-%tky = ls_cm-%tky.
      DATA(lv_any) = abap_false.

      READ TABLE lt_ct INTO DATA(ls_ct) WITH KEY ct_uuid = ls_cm-CtUuid.
      IF sy-subrc = 0.
        ls_line-CtExtNum = ls_ct-ct_id.
        lv_any = abap_true.
      ENDIF.

      IF ls_cm-MatUuid IS NOT INITIAL.
        READ TABLE lt_mat INTO DATA(ls_mat)
          WITH KEY ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid.
        IF sy-subrc = 0.
          ls_line-Matnr = ls_mat-matnr.
          lv_any = abap_true.
        ENDIF.
      ENDIF.

      IF lv_any = abap_true.
        APPEND ls_line TO lt_upd.
      ENDIF.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CtExtNum Matnr )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD DeriveCurrency.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid Currency )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    DATA lt_fae TYPE SORTED TABLE OF zreing_ct2_a WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE CtUuid IS NOT INITIAL AND Currency IS INITIAL.
      TRY.
          INSERT VALUE zreing_ct2_a( ct_uuid = ls_cm-CtUuid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    SELECT ct_uuid, waers FROM zreing_ct2_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid = @lt_fae-ct_uuid
      INTO TABLE @DATA(lt_ct).

    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT lt_cm INTO ls_cm WHERE CtUuid IS NOT INITIAL AND Currency IS INITIAL.
      READ TABLE lt_ct INTO DATA(ls_ct) WITH KEY ct_uuid = ls_cm-CtUuid.
      CHECK sy-subrc = 0.
      APPEND VALUE #( %key     = ls_cm-%key
                      Currency = ls_ct-waers ) TO lt_upd.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( Currency )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD DeriveLoadSeq.
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la secuencia es por combinacion
    " INCLUYENDO la instancia. Cada activacion (A 002, A 003) lleva su propia serie.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CtUuid MatUuid OpType OpInstanceNum DeferType PeriodYear PeriodMonth )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    " Mod 01.10.2026 EXT_AGFAGINA: sin instancia todavia no se calcula. En la carga
    " manual DeriveOpInstance la completa en la misma ronda; esta determinacion se
    " vuelve a disparar con el cambio de OpInstanceNum (ver BDEF).
    DELETE lt_cm WHERE OpInstanceNum IS INITIAL.
    CHECK lt_cm IS NOT INITIAL.

    TYPES: BEGIN OF ty_fae_seq,
             ct_uuid         TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid        TYPE zreing_cm_h_a-mat_uuid,
             op_type         TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type      TYPE zreing_cm_h_a-defer_type,
             period_year     TYPE zreing_cm_h_a-period_year,
             period_month    TYPE zreing_cm_h_a-period_month,
           END OF ty_fae_seq.
    TYPES: BEGIN OF ty_existing_seq,
             ct_uuid         TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid        TYPE zreing_cm_h_a-mat_uuid,
             op_type         TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type      TYPE zreing_cm_h_a-defer_type,
             period_year     TYPE zreing_cm_h_a-period_year,
             period_month    TYPE zreing_cm_h_a-period_month,
             load_seq        TYPE zreing_cm_h_a-load_seq,
           END OF ty_existing_seq.

    DATA lt_fae TYPE TABLE OF ty_fae_seq WITH EMPTY KEY.
    LOOP AT lt_cm INTO DATA(ls_cm).
      APPEND VALUE ty_fae_seq(
        ct_uuid         = ls_cm-CtUuid
        mat_uuid        = ls_cm-MatUuid
        op_type         = ls_cm-OpType
        op_instance_num = ls_cm-OpInstanceNum
        defer_type      = ls_cm-DeferType
        period_year     = ls_cm-PeriodYear
        period_month    = ls_cm-PeriodMonth ) TO lt_fae.
    ENDLOOP.

    DATA lt_existing TYPE TABLE OF ty_existing_seq WITH EMPTY KEY.
    SELECT ct_uuid, mat_uuid, op_type, op_instance_num, defer_type, period_year, period_month, load_seq
      FROM zreing_cm_h_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid         = @lt_fae-ct_uuid
        AND mat_uuid        = @lt_fae-mat_uuid
        AND op_type         = @lt_fae-op_type
        AND op_instance_num = @lt_fae-op_instance_num
        AND defer_type      = @lt_fae-defer_type
        AND period_year     = @lt_fae-period_year
        AND period_month    = @lt_fae-period_month
      INTO TABLE @lt_existing.

    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT lt_cm INTO ls_cm.
      DATA(lv_max) = REDUCE zreing_cm_h_a-load_seq(
        INIT max = CONV zreing_cm_h_a-load_seq( '000' )
        FOR ls IN lt_existing
        WHERE ( ct_uuid         = ls_cm-CtUuid
            AND mat_uuid        = ls_cm-MatUuid
            AND op_type         = ls_cm-OpType
            AND op_instance_num = ls_cm-OpInstanceNum
            AND defer_type      = ls_cm-DeferType
            AND period_year     = ls_cm-PeriodYear
            AND period_month    = ls_cm-PeriodMonth )
        NEXT max = COND #( WHEN ls-load_seq > max THEN ls-load_seq ELSE max ) ).

      APPEND VALUE #( %key    = ls_cm-%key
                      LoadSeq = lv_max + 1 ) TO lt_upd.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( LoadSeq )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD DeriveSupersede.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CtUuid MatUuid OpType OpInstanceNum DeferType PeriodYear PeriodMonth DeltaFlag )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la sustitucion es por combinacion
    " INCLUYENDO la instancia. Sin instancia no se ejecuta: los registros anteriores
    " al cambio tienen la instancia vacia y se marcarian como SUPS por error.
    DELETE lt_cm WHERE OpInstanceNum IS INITIAL.
    CHECK lt_cm IS NOT INITIAL.

    TYPES: BEGIN OF ty_fae_sup,
             ct_uuid         TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid        TYPE zreing_cm_h_a-mat_uuid,
             op_type         TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type      TYPE zreing_cm_h_a-defer_type,
             period_year     TYPE zreing_cm_h_a-period_year,
             period_month    TYPE zreing_cm_h_a-period_month,
           END OF ty_fae_sup.

    DATA lt_fae TYPE TABLE OF ty_fae_sup WITH EMPTY KEY.
    LOOP AT lt_cm INTO DATA(ls_cm).
      " Begin Mod 09.09.2026 EXT_AGFAGINA - una carga DELTA no sustituye a la anterior.
      " La ET de CM ya lo define: "si existe LIBD SIN DELTA: LIBD -> SUPS". La
      " condicion del delta nunca se implemento, y no se notaba porque el import
      " descartaba las lineas delta antes de llegar a crear nada.
      " Al habilitarlas (08.09.2026), el registro liberado original pasaba a SUPS:
      " caso real IC-0008 / P en 02/2026, donde la carga de 180.000 quedo Suprimida
      " al ingresar el delta de 2.000.
      " Un delta es una carga INCREMENTAL: la original sigue vigente y ambas
      " conviven, distinguidas por LOAD_SEQ. Solo una recarga sin delta sustituye.
      IF ls_cm-DeltaFlag = 'X'.
        CONTINUE.
      ENDIF.
      " End Mod 09.09.2026 EXT_AGFAGINA
      APPEND VALUE ty_fae_sup(
        ct_uuid         = ls_cm-CtUuid
        mat_uuid        = ls_cm-MatUuid
        op_type         = ls_cm-OpType
        op_instance_num = ls_cm-OpInstanceNum
        defer_type      = ls_cm-DeferType
        period_year     = ls_cm-PeriodYear
        period_month    = ls_cm-PeriodMonth ) TO lt_fae.
    ENDLOOP.

    " Mod 09.09.2026 EXT_AGFAGINA: control imprescindible. Si TODAS las lineas del
    " request son delta, lt_fae queda vacia, y un FOR ALL ENTRIES sobre tabla vacia
    " ignora el WHERE y devolveria TODOS los registros LIBD del sistema, que se
    " marcarian como SUPS.
    CHECK lt_fae IS NOT INITIAL.

    TYPES: BEGIN OF ty_libd,
             cm_h_id TYPE zreing_cm_h_a-cm_h_id,
           END OF ty_libd.

    DATA lt_libd TYPE TABLE OF ty_libd WITH EMPTY KEY.
    SELECT cm_h_id
      FROM zreing_cm_h_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid      = @lt_fae-ct_uuid
        AND mat_uuid     = @lt_fae-mat_uuid
        AND op_type      = @lt_fae-op_type
        AND defer_type   = @lt_fae-defer_type
        AND period_year  = @lt_fae-period_year
        AND period_month = @lt_fae-period_month
        AND op_instance_num = @lt_fae-op_instance_num
        AND cm_status    = 'LIBD'
      INTO TABLE @lt_libd.

    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT lt_libd INTO DATA(ls_libd).
      APPEND VALUE #( %key         = VALUE #( CmHId = ls_libd-cm_h_id )
                      CmStatus     = 'SUPS'
                      CmStatusText = 'Suprimido' ) TO lt_upd.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CmStatus CmStatusText )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD DeriveStatus.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CtUuid MatUuid OpType DeferType DeltaFlag Amount CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    DATA lt_eval LIKE lt_cm.
    LOOP AT lt_cm INTO DATA(ls_chk).
      IF ls_chk-CmStatus = 'PEND' OR ls_chk-CmStatus = 'GRAV'
         OR ls_chk-CmStatus = 'ERR' OR ls_chk-CmStatus IS INITIAL.
        APPEND ls_chk TO lt_eval.
      ENDIF.
    ENDLOOP.
    CHECK lt_eval IS NOT INITIAL.

    TYPES: BEGIN OF ty_fae_op,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_fae_op.
    DATA lt_fae_op TYPE SORTED TABLE OF ty_fae_op WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    DATA lt_op_keys TYPE SORTED TABLE OF zreing_op_types-op_type WITH UNIQUE KEY table_line.

    LOOP AT lt_eval INTO DATA(ls_cm).
      IF ls_cm-CtUuid IS NOT INITIAL AND ls_cm-MatUuid IS NOT INITIAL AND ls_cm-OpType IS NOT INITIAL.
        TRY.
            INSERT VALUE ty_fae_op( ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid
                                    op_type = ls_cm-OpType ) INTO TABLE lt_fae_op.
          CATCH cx_sy_itab_duplicate_key.                   "#EC NEEDED
        ENDTRY.
      ENDIF.
      IF ls_cm-DeltaFlag = 'X' AND ls_cm-OpType IS NOT INITIAL.
        INSERT CONV zreing_op_types-op_type( ls_cm-OpType ) INTO TABLE lt_op_keys.
      ENDIF.
    ENDLOOP.

    TYPES: BEGIN OF ty_opt,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_opt.
    DATA lt_opt TYPE SORTED TABLE OF ty_opt WITH NON-UNIQUE KEY ct_uuid mat_uuid op_type.
    IF lt_fae_op IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_type FROM zreing_ct2_opt_a
        FOR ALL ENTRIES IN @lt_fae_op
        WHERE ct_uuid  = @lt_fae_op-ct_uuid
          AND mat_uuid = @lt_fae_op-mat_uuid
          AND op_type  = @lt_fae_op-op_type
        INTO CORRESPONDING FIELDS OF TABLE @lt_opt.
    ENDIF.

    DATA lt_cat TYPE SORTED TABLE OF zreing_op_types WITH NON-UNIQUE KEY op_type.
    IF lt_op_keys IS NOT INITIAL.
      SELECT op_type, permite_delta FROM zreing_op_types
        FOR ALL ENTRIES IN @lt_op_keys
        WHERE op_type = @lt_op_keys-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_cat.
    ENDIF.

    DATA lt_upd  TYPE TABLE FOR UPDATE zi_reingcmheader.
    DATA lv_text TYPE zreing_cm_h_a-cm_status_text.

    LOOP AT lt_eval INTO ls_cm.
      DATA lv_is_err TYPE abap_bool.
      lv_is_err = abap_false.

      IF ls_cm-OpType IS INITIAL.
        lv_is_err = abap_true.
      ELSE.
        READ TABLE lt_opt TRANSPORTING NO FIELDS
          WITH KEY ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid op_type = ls_cm-OpType.
        IF sy-subrc <> 0.
          lv_is_err = abap_true.
        ENDIF.
      ENDIF.

      IF lv_is_err = abap_false.
        IF ls_cm-OpType = 'A'.
          IF ls_cm-DeferType IS INITIAL OR ( ls_cm-DeferType <> 'P' AND ls_cm-DeferType <> 'B' ).
            lv_is_err = abap_true.
          ENDIF.
        ELSEIF ls_cm-DeferType IS NOT INITIAL.
          lv_is_err = abap_true.
        ENDIF.
      ENDIF.

      IF lv_is_err = abap_false AND ls_cm-DeltaFlag = 'X'.
        READ TABLE lt_cat INTO DATA(ls_cat) WITH KEY op_type = ls_cm-OpType.
        IF sy-subrc <> 0 OR ls_cat-permite_delta <> 'X'.
          lv_is_err = abap_true.
        ENDIF.
      ENDIF.

      DATA lv_new TYPE zreing_cm_h_a-cm_status.
      IF lv_is_err = abap_true.
        lv_new  = 'ERR'.
        lv_text = 'Error'.
      ELSEIF ls_cm-Amount IS NOT INITIAL AND ls_cm-Amount <> 0.
        lv_new  = 'GRAV'.
        lv_text = 'Grabado'.
      ELSE.
        lv_new  = 'PEND'.
        lv_text = 'Pendiente'.
      ENDIF.

      CHECK ls_cm-CmStatus <> lv_new.
      APPEND VALUE #( %key = ls_cm-%key CmStatus = lv_new CmStatusText = lv_text ) TO lt_upd.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( CmStatus CmStatusText )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
  ENDMETHOD.

  METHOD ValidateContract.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    DATA lt_fae TYPE SORTED TABLE OF zreing_ct2_a WITH UNIQUE KEY ct_uuid.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE CtUuid IS NOT INITIAL.
      TRY.
          INSERT VALUE zreing_ct2_a( ct_uuid = ls_cm-CtUuid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    TYPES: BEGIN OF ty_ct_res,
             ct_uuid   TYPE zreing_ct2_a-ct_uuid,
             ct_status TYPE zreing_ct2_a-ct_status,
           END OF ty_ct_res.
    DATA lt_ct TYPE TABLE OF ty_ct_res WITH EMPTY KEY.
    IF lt_fae IS NOT INITIAL.
      SELECT ct_uuid, ct_status FROM zreing_ct2_a
        FOR ALL ENTRIES IN @lt_fae
        WHERE ct_uuid = @lt_fae-ct_uuid
        INTO TABLE @lt_ct.
    ENDIF.

    LOOP AT lt_cm INTO ls_cm.
      IF ls_cm-CtUuid IS INITIAL.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_CT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El contrato es obligatorio (BR-CM-02)' ) )
          TO reported-cmheader.
        CONTINUE.
      ENDIF.
      READ TABLE lt_ct INTO DATA(ls_ct) WITH KEY ct_uuid = ls_cm-CtUuid.
      IF sy-subrc <> 0 OR ls_ct-ct_status <> 'AC'.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_CT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Contrato inexistente o inactivo (BR-CM-02)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateMaterial.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    TYPES: BEGIN OF ty_fae_mat,
             ct_uuid  TYPE zreing_ct2_mat_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_mat_a-mat_uuid,
           END OF ty_fae_mat.

    DATA lt_fae TYPE SORTED TABLE OF ty_fae_mat
                WITH UNIQUE KEY ct_uuid mat_uuid.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_mat(
            ct_uuid  = ls_cm-CtUuid
            mat_uuid = ls_cm-MatUuid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    TYPES: BEGIN OF ty_mat_res,
             ct_uuid  TYPE zreing_ct2_mat_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_mat_a-mat_uuid,
           END OF ty_mat_res.
    DATA lt_mat TYPE TABLE OF ty_mat_res WITH EMPTY KEY.
    IF lt_fae IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @lt_fae
        WHERE ct_uuid  = @lt_fae-ct_uuid
          AND mat_uuid = @lt_fae-mat_uuid
        INTO TABLE @lt_mat.
    ENDIF.

    LOOP AT lt_cm INTO ls_cm.
      IF ls_cm-MatUuid IS INITIAL.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_MAT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El material es obligatorio (BR-CM-03)' ) )
          TO reported-cmheader.
        CONTINUE.
      ENDIF.
      READ TABLE lt_mat INTO DATA(ls_mat)
        WITH KEY ct_uuid  = ls_cm-CtUuid
                 mat_uuid = ls_cm-MatUuid.
      IF sy-subrc <> 0.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_MAT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Material no configurado para este contrato (BR-CM-03)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateOpType.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid OpType )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    TYPES: BEGIN OF ty_fae_op,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_fae_op.

    DATA lt_fae TYPE SORTED TABLE OF ty_fae_op
                WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_cm INTO DATA(ls_cm)
      WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL AND OpType IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_op(
            ct_uuid  = ls_cm-CtUuid
            mat_uuid = ls_cm-MatUuid
            op_type  = ls_cm-OpType ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    TYPES: BEGIN OF ty_op_res,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_op_res.
    DATA lt_op TYPE TABLE OF ty_op_res WITH EMPTY KEY.
    IF lt_fae IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_type FROM zreing_ct2_opt_a
        FOR ALL ENTRIES IN @lt_fae
        WHERE ct_uuid  = @lt_fae-ct_uuid
          AND mat_uuid = @lt_fae-mat_uuid
          AND op_type  = @lt_fae-op_type
        INTO TABLE @lt_op.
    ENDIF.

    LOOP AT lt_cm INTO ls_cm.
      IF ls_cm-OpType IS INITIAL.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_OP'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El tipo de operación es obligatorio (BR-CM-04)' ) )
          TO reported-cmheader.
        CONTINUE.
      ENDIF.
      READ TABLE lt_op INTO DATA(ls_optype)
        WITH KEY ct_uuid  = ls_cm-CtUuid
                 mat_uuid = ls_cm-MatUuid
                 op_type  = ls_cm-OpType.
      IF sy-subrc <> 0.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_OP'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Tipo de operación no válido para CT/Material (BR-CM-04)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateAmount.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( Amount CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-CmStatus = 'ENVI' AND ( ls_cm-Amount IS INITIAL OR ls_cm-Amount = 0 ).
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_AMT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El monto es obligatorio al enviar (BR-CM-01)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateDeltaFlag.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( OpType DeltaFlag )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    DATA lt_fae TYPE SORTED TABLE OF zreing_op_types WITH UNIQUE KEY op_type.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE DeltaFlag = 'X'.
      TRY.
          INSERT VALUE zreing_op_types( op_type = ls_cm-OpType ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    SELECT op_type, permite_delta FROM zreing_op_types
      FOR ALL ENTRIES IN @lt_fae
      WHERE op_type = @lt_fae-op_type
      INTO TABLE @DATA(lt_op).

    LOOP AT lt_cm INTO ls_cm WHERE DeltaFlag = 'X'.
      READ TABLE lt_op INTO DATA(ls_op) WITH KEY op_type = ls_cm-OpType.
      IF sy-subrc <> 0 OR ls_op-permite_delta <> 'X'.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_DELTA'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Este tipo de operación no permite delta (BR-CM-07)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateUniqueness.
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la combinacion incluye la instancia.
    " Sin ella, la A 002 y la A 003 del mismo contrato y periodo serian "duplicadas".
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CtUuid MatUuid OpType OpInstanceNum DeferType PeriodYear PeriodMonth DeltaFlag CmHId )
        WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    TYPES: BEGIN OF ty_fae_uniq,
             ct_uuid         TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid        TYPE zreing_cm_h_a-mat_uuid,
             op_type         TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type      TYPE zreing_cm_h_a-defer_type,
             period_year     TYPE zreing_cm_h_a-period_year,
             period_month    TYPE zreing_cm_h_a-period_month,
           END OF ty_fae_uniq.

    DATA lt_fae TYPE TABLE OF ty_fae_uniq WITH EMPTY KEY.
    LOOP AT lt_cm INTO DATA(ls_cm) WHERE DeltaFlag IS INITIAL.
      APPEND VALUE ty_fae_uniq(
        ct_uuid         = ls_cm-CtUuid
        mat_uuid        = ls_cm-MatUuid
        op_type         = ls_cm-OpType
        op_instance_num = ls_cm-OpInstanceNum
        defer_type      = ls_cm-DeferType
        period_year     = ls_cm-PeriodYear
        period_month    = ls_cm-PeriodMonth ) TO lt_fae.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    TYPES: BEGIN OF ty_existing_uniq,
             cm_h_id         TYPE zreing_cm_h_a-cm_h_id,
             ct_uuid         TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid        TYPE zreing_cm_h_a-mat_uuid,
             op_type         TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type      TYPE zreing_cm_h_a-defer_type,
             period_year     TYPE zreing_cm_h_a-period_year,
             period_month    TYPE zreing_cm_h_a-period_month,
           END OF ty_existing_uniq.

    DATA lt_existing TYPE TABLE OF ty_existing_uniq WITH EMPTY KEY.
    SELECT cm_h_id, ct_uuid, mat_uuid, op_type, op_instance_num, defer_type, period_year, period_month
      FROM zreing_cm_h_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid         = @lt_fae-ct_uuid
        AND mat_uuid        = @lt_fae-mat_uuid
        AND op_type         = @lt_fae-op_type
        AND op_instance_num = @lt_fae-op_instance_num
        AND defer_type      = @lt_fae-defer_type
        AND period_year     = @lt_fae-period_year
        AND period_month    = @lt_fae-period_month
        AND cm_status IN ( 'GRAV', 'ENVI' )
      INTO TABLE @lt_existing.

    LOOP AT lt_cm INTO ls_cm WHERE DeltaFlag IS INITIAL.
      READ TABLE lt_existing INTO DATA(ls_ex)
        WITH KEY ct_uuid         = ls_cm-CtUuid
                 mat_uuid        = ls_cm-MatUuid
                 op_type         = ls_cm-OpType
                 op_instance_num = ls_cm-OpInstanceNum
                 defer_type      = ls_cm-DeferType
                 period_year     = ls_cm-PeriodYear
                 period_month    = ls_cm-PeriodMonth.
      IF sy-subrc = 0 AND ls_ex-cm_h_id <> ls_cm-CmHId.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_UNIQ'
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text     = 'Ya existe un registro activo para esta combinación (BR-CM-06)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD msg.
    " Mod 01.10.2026 EXT_AGFAGINA - ver comentario de lcl_msg.
    DATA(ls_v) = lcl_msg=>split( iv_text ).
    ro_msg = new_message( id       = 'ZREING_CM'
                          number   = '000'
                          severity = iv_severity
                          v1       = ls_v-v1
                          v2       = ls_v-v2
                          v3       = ls_v-v3
                          v4       = ls_v-v4 ).
  ENDMETHOD.

  METHOD ValidateCeilingAmount.
    " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002 / BR-CM-14 (Ceiling Rule).
    " Misma regla que el import (ZCL_REING_CM_UPLOAD_HDL), para la carga manual:
    "   a) un tipo con tope (ZREING_OP_TYPES-CEILING_OP_TYPE, ej. A -> F) requiere
    "      que exista el tope para el mismo contrato + material + periodo, y su
    "      suma no puede superarlo;
    "   b) el tope no puede quedar por debajo del dependiente (ej. bajar una F con
    "      una A ya cargada). Definido por Vinicius el 29.09.2026.
    " Las sumas se arman con TODOS los registros del periodo leidos por la
    " asociacion al Period, en el mismo estado que la instancia (draft o activo):
    " asi entran los cambios sin guardar de la misma pantalla.
    " No suman SUPS ni ERR. Sin reglas de moneda: montos tal cual.
    " El codigo nunca referencia tipos concretos: todo sale del catalogo.
    TYPES: BEGIN OF ty_ceil,
             op_type         TYPE zreing_op_types-op_type,
             ceiling_op_type TYPE zreing_op_types-ceiling_op_type,
           END OF ty_ceil.
    DATA lt_ceil TYPE HASHED TABLE OF ty_ceil WITH UNIQUE KEY op_type.
    SELECT op_type, ceiling_op_type FROM zreing_op_types
      WHERE ceiling_op_type <> @space
      INTO TABLE @lt_ceil.
    IF lt_ceil IS INITIAL.
      RETURN.
    ENDIF.

    " Mod 01.10.2026 EXT_AGFAGINA: descripciones para los mensajes
    " ("Activación supera a Facturación" en vez de "A supera el de F").
    TYPES: BEGIN OF ty_name,
             op_type TYPE zreing_op_types-op_type,
             descr   TYPE zreing_op_types-descr,
           END OF ty_name.
    DATA lt_name TYPE HASHED TABLE OF ty_name WITH UNIQUE KEY op_type.
    SELECT op_type, descr FROM zreing_op_types
      WHERE op_type IS NOT INITIAL
      INTO TABLE @lt_name.
    DATA lv_nm_self  TYPE string.
    DATA lv_nm_other TYPE string.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader
        FIELDS ( CtUuid MatUuid OpType Amount CmStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_cm).

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader BY \_Period
        FIELDS ( PeriodYear PeriodMonth )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_per).
    SORT lt_per BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_per COMPARING %tky.

    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY Period BY \_Items
        FIELDS ( CtUuid MatUuid OpType Amount CmStatus )
        WITH CORRESPONDING #( lt_per )
      RESULT DATA(lt_items).

    TYPES: BEGIN OF ty_tot,
             ct_uuid  TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid TYPE zreing_cm_h_a-mat_uuid,
             op_type  TYPE zreing_cm_h_a-op_type,
             total    TYPE p LENGTH 16 DECIMALS 2,
           END OF ty_tot.
    DATA lt_tot TYPE HASHED TABLE OF ty_tot WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_items INTO DATA(ls_it) WHERE CmStatus <> 'SUPS' AND CmStatus <> 'ERR'.
      READ TABLE lt_tot ASSIGNING FIELD-SYMBOL(<ls_tot>)
        WITH TABLE KEY ct_uuid  = ls_it-CtUuid
                       mat_uuid = ls_it-MatUuid
                       op_type  = ls_it-OpType.
      IF sy-subrc = 0.
        <ls_tot>-total = <ls_tot>-total + ls_it-Amount.
      ELSE.
        INSERT VALUE #( ct_uuid  = ls_it-CtUuid
                        mat_uuid = ls_it-MatUuid
                        op_type  = ls_it-OpType
                        total    = ls_it-Amount ) INTO TABLE lt_tot.
      ENDIF.
    ENDLOOP.

    " Para el control b): por cada tope (contrato, material, tipo tope), el total
    " del dependiente MAS ALTO. La regla es por tipo (cada dependiente contra su
    " tope), asi que se toma el maximo y no la suma de dependientes. Se arma en una
    " sola pasada para no recorrer el catalogo dentro del loop de registros.
    TYPES: BEGIN OF ty_dep,
             ct_uuid  TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid TYPE zreing_cm_h_a-mat_uuid,
             op_type  TYPE zreing_cm_h_a-op_type,
             dep_type TYPE zreing_cm_h_a-op_type,
             total    TYPE p LENGTH 16 DECIMALS 2,
           END OF ty_dep.
    DATA lt_dep TYPE HASHED TABLE OF ty_dep WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_tot INTO DATA(ls_t).
      READ TABLE lt_ceil INTO DATA(ls_tc) WITH TABLE KEY op_type = ls_t-op_type.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_dep ASSIGNING FIELD-SYMBOL(<ls_dep>)
        WITH TABLE KEY ct_uuid  = ls_t-ct_uuid
                       mat_uuid = ls_t-mat_uuid
                       op_type  = ls_tc-ceiling_op_type.
      IF sy-subrc <> 0.
        INSERT VALUE #( ct_uuid  = ls_t-ct_uuid
                        mat_uuid = ls_t-mat_uuid
                        op_type  = ls_tc-ceiling_op_type
                        dep_type = ls_t-op_type
                        total    = ls_t-total ) INTO TABLE lt_dep.
      ELSEIF ls_t-total > <ls_dep>-total.
        <ls_dep>-dep_type = ls_t-op_type.
        <ls_dep>-total    = ls_t-total.
      ENDIF.
    ENDLOOP.

    DATA lv_dep TYPE p LENGTH 16 DECIMALS 2.
    DATA lv_top TYPE p LENGTH 16 DECIMALS 2.

    LOOP AT lt_cm INTO DATA(ls_cm).
      APPEND VALUE #( %tky = ls_cm-%tky %state_area = 'VAL_CEIL' ) TO reported-cmheader.
      IF ls_cm-CmStatus = 'SUPS' OR ls_cm-CmStatus = 'ERR'.
        CONTINUE.
      ENDIF.

      " a) El tipo del registro tiene tope.
      READ TABLE lt_ceil INTO DATA(ls_c) WITH TABLE KEY op_type = ls_cm-OpType.
      IF sy-subrc = 0.
        " Mod 01.10.2026 EXT_AGFAGINA: nombres del tipo y de su tope.
        lv_nm_self = ls_cm-OpType.
        READ TABLE lt_name INTO DATA(ls_nm) WITH TABLE KEY op_type = ls_cm-OpType.
        IF sy-subrc = 0.
          IF ls_nm-descr IS NOT INITIAL.
            lv_nm_self = to_mixed( val = condense( CONV string( ls_nm-descr ) ) ).
          ENDIF.
        ENDIF.
        lv_nm_other = ls_c-ceiling_op_type.
        READ TABLE lt_name INTO ls_nm WITH TABLE KEY op_type = ls_c-ceiling_op_type.
        IF sy-subrc = 0.
          IF ls_nm-descr IS NOT INITIAL.
            lv_nm_other = to_mixed( val = condense( CONV string( ls_nm-descr ) ) ).
          ENDIF.
        ENDIF.

        IF NOT line_exists( lt_tot[ ct_uuid  = ls_cm-CtUuid
                                    mat_uuid = ls_cm-MatUuid
                                    op_type  = ls_c-ceiling_op_type ] ).
          APPEND VALUE #( %tky = ls_cm-%tky ) TO failed-cmheader.
          APPEND VALUE #( %tky = ls_cm-%tky
                          %state_area     = 'VAL_CEIL'
                          %element-OpType = if_abap_behv=>mk-on
                          %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                      iv_text     = |{ lv_nm_self } requiere que exista { lv_nm_other } para el mismo | &&
                                                    |contrato, material y período (BR-CM-14).| ) )
            TO reported-cmheader.
          CONTINUE.
        ENDIF.
        lv_dep = VALUE #( lt_tot[ ct_uuid  = ls_cm-CtUuid
                                  mat_uuid = ls_cm-MatUuid
                                  op_type  = ls_cm-OpType ]-total OPTIONAL ).
        lv_top = lt_tot[ ct_uuid  = ls_cm-CtUuid
                         mat_uuid = ls_cm-MatUuid
                         op_type  = ls_c-ceiling_op_type ]-total.
        IF lv_dep > lv_top.
          APPEND VALUE #( %tky = ls_cm-%tky ) TO failed-cmheader.
          APPEND VALUE #( %tky = ls_cm-%tky
                          %state_area     = 'VAL_CEIL'
                          %element-Amount = if_abap_behv=>mk-on
                          %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                      iv_text     = |{ lv_nm_self } ({ lv_dep NUMBER = USER }) supera a { lv_nm_other } | &&
                                                    |({ lv_top NUMBER = USER }) del mismo contrato, material y período (BR-CM-14).| ) )
            TO reported-cmheader.
          CONTINUE.
        ENDIF.
      ENDIF.

      " b) El tipo del registro es tope de otro: no puede quedar por debajo.
      READ TABLE lt_dep INTO DATA(ls_dp)
        WITH TABLE KEY ct_uuid  = ls_cm-CtUuid
                       mat_uuid = ls_cm-MatUuid
                       op_type  = ls_cm-OpType.
      IF sy-subrc = 0.
        lv_top = VALUE #( lt_tot[ ct_uuid  = ls_cm-CtUuid
                                  mat_uuid = ls_cm-MatUuid
                                  op_type  = ls_cm-OpType ]-total OPTIONAL ).
        IF ls_dp-total > lv_top.
          " Mod 01.10.2026 EXT_AGFAGINA: nombres del tope y del dependiente.
          lv_nm_self = ls_cm-OpType.
          READ TABLE lt_name INTO DATA(ls_nm2) WITH TABLE KEY op_type = ls_cm-OpType.
          IF sy-subrc = 0.
            IF ls_nm2-descr IS NOT INITIAL.
              lv_nm_self = to_mixed( val = condense( CONV string( ls_nm2-descr ) ) ).
            ENDIF.
          ENDIF.
          lv_nm_other = ls_dp-dep_type.
          READ TABLE lt_name INTO ls_nm2 WITH TABLE KEY op_type = ls_dp-dep_type.
          IF sy-subrc = 0.
            IF ls_nm2-descr IS NOT INITIAL.
              lv_nm_other = to_mixed( val = condense( CONV string( ls_nm2-descr ) ) ).
            ENDIF.
          ENDIF.
          APPEND VALUE #( %tky = ls_cm-%tky ) TO failed-cmheader.
          APPEND VALUE #( %tky = ls_cm-%tky
                          %state_area     = 'VAL_CEIL'
                          %element-Amount = if_abap_behv=>mk-on
                          %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                      iv_text     = |{ lv_nm_self } ({ lv_top NUMBER = USER }) no puede quedar por debajo | &&
                                                    |de lo ya cargado de { lv_nm_other } ({ ls_dp-total NUMBER = USER }) | &&
                                                    |del mismo contrato, material y período (BR-CM-14).| ) )
            TO reported-cmheader.
        ENDIF.
      ENDIF.
    ENDLOOP.
    " End Mod 29.09.2026 EXT_AGFAGINA
  ENDMETHOD.

  METHOD DeriveOpInstance.
    " Begin Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion.
    " Si la instancia esta vacia o no existe para el contrato + material + tipo, y
    " el contrato tiene UNA sola opcion de ese tipo, se completa con esa. Cubre F,
    " P y NC (siempre 001) y los contratos con una unica activacion. Con varias
    " opciones no se adivina: lo pide ValidateOpInstance.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid OpType OpInstanceNum )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    TYPES: BEGIN OF ty_key,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_key.
    DATA lt_fae TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_cm INTO DATA(ls_cm)
      WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL AND OpType IS NOT INITIAL.
      INSERT VALUE #( ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid op_type = ls_cm-OpType )
        INTO TABLE lt_fae.
    ENDLOOP.
    IF lt_fae IS INITIAL.
      RETURN.
    ENDIF.

    SELECT ct_uuid, mat_uuid, op_type, op_instance_num FROM zreing_ct2_opt_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid  = @lt_fae-ct_uuid
        AND mat_uuid = @lt_fae-mat_uuid
        AND op_type  = @lt_fae-op_type
      INTO TABLE @DATA(lt_opt).

    TYPES: BEGIN OF ty_cnt,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             cnt      TYPE i,
             inst     TYPE zreing_ct2_opt_a-op_instance_num,
           END OF ty_cnt.
    DATA lt_cnt TYPE HASHED TABLE OF ty_cnt WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    TYPES: BEGIN OF ty_inst,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             inst     TYPE zreing_ct2_opt_a-op_instance_num,
           END OF ty_inst.
    DATA lt_inst TYPE HASHED TABLE OF ty_inst WITH UNIQUE KEY ct_uuid mat_uuid op_type inst.
    LOOP AT lt_opt INTO DATA(ls_o).
      INSERT VALUE #( ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid
                      op_type = ls_o-op_type inst = ls_o-op_instance_num ) INTO TABLE lt_inst.
      READ TABLE lt_cnt ASSIGNING FIELD-SYMBOL(<ls_cnt>)
        WITH TABLE KEY ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid op_type = ls_o-op_type.
      IF sy-subrc = 0.
        <ls_cnt>-cnt = <ls_cnt>-cnt + 1.
      ELSE.
        INSERT VALUE #( ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid op_type = ls_o-op_type
                        cnt = 1 inst = ls_o-op_instance_num ) INTO TABLE lt_cnt.
      ENDIF.
    ENDLOOP.

    DATA lt_upd TYPE TABLE FOR UPDATE zi_reingcmheader.
    LOOP AT lt_cm INTO ls_cm
      WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL AND OpType IS NOT INITIAL.
      " La instancia informada existe: no se toca.
      IF ls_cm-OpInstanceNum IS NOT INITIAL
         AND line_exists( lt_inst[ ct_uuid  = ls_cm-CtUuid
                                   mat_uuid = ls_cm-MatUuid
                                   op_type  = ls_cm-OpType
                                   inst     = ls_cm-OpInstanceNum ] ).
        CONTINUE.
      ENDIF.
      READ TABLE lt_cnt INTO DATA(ls_c)
        WITH TABLE KEY ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid op_type = ls_cm-OpType.
      IF sy-subrc = 0 AND ls_c-cnt = 1 AND ls_c-inst <> ls_cm-OpInstanceNum.
        APPEND VALUE #( %tky = ls_cm-%tky OpInstanceNum = ls_c-inst ) TO lt_upd.
      ENDIF.
    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcmperiod IN LOCAL MODE
        ENTITY CMHeader UPDATE FIELDS ( OpInstanceNum )
        WITH lt_upd REPORTED DATA(lt_rep).
    ENDIF.
    " End Mod 01.10.2026 EXT_AGFAGINA
  ENDMETHOD.

  METHOD ValidateOpInstance.
    " Begin Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion.
    " La instancia tiene que existir en el contrato para ese material y tipo. Si
    " esta vacia y hay varias opciones, se pide indicando cuales. Si el contrato no
    " tiene ese tipo, no se informa aca: ya lo rechaza ValidateOpType (BR-CM-04).
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid OpType OpInstanceNum CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm).

    TYPES: BEGIN OF ty_key,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_key.
    DATA lt_fae TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_cm INTO DATA(ls_cm)
      WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL AND OpType IS NOT INITIAL.
      INSERT VALUE #( ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid op_type = ls_cm-OpType )
        INTO TABLE lt_fae.
    ENDLOOP.
    IF lt_fae IS INITIAL.
      RETURN.
    ENDIF.

    SELECT ct_uuid, mat_uuid, op_type, op_instance_num FROM zreing_ct2_opt_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid  = @lt_fae-ct_uuid
        AND mat_uuid = @lt_fae-mat_uuid
        AND op_type  = @lt_fae-op_type
      INTO TABLE @DATA(lt_opt).

    " Por clave: cantidad de opciones y la lista para el mensaje ("2, 3").
    TYPES: BEGIN OF ty_cnt,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             cnt      TYPE i,
             list     TYPE string,
           END OF ty_cnt.
    DATA lt_cnt TYPE HASHED TABLE OF ty_cnt WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    TYPES: BEGIN OF ty_inst,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             inst     TYPE zreing_ct2_opt_a-op_instance_num,
           END OF ty_inst.
    DATA lt_inst TYPE HASHED TABLE OF ty_inst WITH UNIQUE KEY ct_uuid mat_uuid op_type inst.
    SORT lt_opt BY ct_uuid mat_uuid op_type op_instance_num.
    LOOP AT lt_opt INTO DATA(ls_o).
      INSERT VALUE #( ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid
                      op_type = ls_o-op_type inst = ls_o-op_instance_num ) INTO TABLE lt_inst.
      READ TABLE lt_cnt ASSIGNING FIELD-SYMBOL(<ls_cnt>)
        WITH TABLE KEY ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid op_type = ls_o-op_type.
      IF sy-subrc = 0.
        <ls_cnt>-cnt  = <ls_cnt>-cnt + 1.
        <ls_cnt>-list = |{ <ls_cnt>-list }, { ls_o-op_instance_num ALPHA = OUT }|.
      ELSE.
        INSERT VALUE #( ct_uuid = ls_o-ct_uuid mat_uuid = ls_o-mat_uuid op_type = ls_o-op_type
                        cnt = 1 list = |{ ls_o-op_instance_num ALPHA = OUT }| ) INTO TABLE lt_cnt.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_cm INTO ls_cm.
      APPEND VALUE #( %tky = ls_cm-%tky %state_area = 'VAL_INST' ) TO reported-cmheader.
      IF ls_cm-CtUuid IS INITIAL OR ls_cm-MatUuid IS INITIAL OR ls_cm-OpType IS INITIAL
         OR ls_cm-CmStatus = 'SUPS'.
        CONTINUE.
      ENDIF.
      READ TABLE lt_cnt INTO DATA(ls_c)
        WITH TABLE KEY ct_uuid = ls_cm-CtUuid mat_uuid = ls_cm-MatUuid op_type = ls_cm-OpType.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF ls_cm-OpInstanceNum IS INITIAL.
        APPEND VALUE #( %tky = ls_cm-%tky ) TO failed-cmheader.
        APPEND VALUE #( %tky = ls_cm-%tky
                        %state_area            = 'VAL_INST'
                        %element-OpInstanceNum = if_abap_behv=>mk-on
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text     = |El contrato tiene { ls_c-cnt } opciones del tipo { ls_cm-OpType } para | &&
                                                  |este material ({ ls_c-list }): indique el número de activación.| ) )
          TO reported-cmheader.
      ELSEIF NOT line_exists( lt_inst[ ct_uuid  = ls_cm-CtUuid
                                       mat_uuid = ls_cm-MatUuid
                                       op_type  = ls_cm-OpType
                                       inst     = ls_cm-OpInstanceNum ] ).
        APPEND VALUE #( %tky = ls_cm-%tky ) TO failed-cmheader.
        APPEND VALUE #( %tky = ls_cm-%tky
                        %state_area            = 'VAL_INST'
                        %element-OpInstanceNum = if_abap_behv=>mk-on
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                    iv_text     = |El número de activación { ls_cm-OpInstanceNum ALPHA = OUT } no existe en el | &&
                                                  |contrato para el tipo { ls_cm-OpType } (disponibles: { ls_c-list }).| ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
    " End Mod 01.10.2026 EXT_AGFAGINA
  ENDMETHOD.

  METHOD ValidateNoAccountingDoc.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( AccountingDoc )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-AccountingDoc IS NOT INITIAL.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_ACCDOC'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'No se puede modificar con documento contable (BR-CM-09)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateDeferType.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( OpType DeferType )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-OpType = 'A'.
        IF ls_cm-DeferType IS INITIAL OR
           ( ls_cm-DeferType <> 'P' AND ls_cm-DeferType <> 'B' ).
          APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_DEFER'
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = 'Tipo Dev. P o B obligatorio para Op. A (BR-CM-12)' ) )
            TO reported-cmheader.
        ENDIF.
      ELSE.
        IF ls_cm-DeferType IS NOT INITIAL.
          APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_DEFER'
                          %msg = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = 'Tipo Dev. solo aplica para Op. tipo A (BR-CM-12)' ) )
            TO reported-cmheader.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateDeferTypeExistsInCT.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CtUuid MatUuid OpType DeferType )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    TYPES: BEGIN OF ty_fae_def,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
           END OF ty_fae_def.

    DATA lt_fae TYPE SORTED TABLE OF ty_fae_def
                WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_cm INTO DATA(ls_cm)
      WHERE DeferType IS NOT INITIAL AND OpType = 'A'.
      TRY.
          INSERT VALUE ty_fae_def(
            ct_uuid  = ls_cm-CtUuid
            mat_uuid = ls_cm-MatUuid
            op_type  = ls_cm-OpType ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.
    CHECK lt_fae IS NOT INITIAL.

    SELECT ct_uuid, mat_uuid, op_type FROM zreing_ct2_opt_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid  = @lt_fae-ct_uuid
        AND mat_uuid = @lt_fae-mat_uuid
        AND op_type  = @lt_fae-op_type
      INTO TABLE @DATA(lt_opt).

    LOOP AT lt_cm INTO ls_cm WHERE DeferType IS NOT INITIAL AND OpType = 'A'.
      READ TABLE lt_opt INTO DATA(ls_opt)
        WITH KEY ct_uuid  = ls_cm-CtUuid
                 mat_uuid = ls_cm-MatUuid
                 op_type  = ls_cm-OpType.
      IF sy-subrc <> 0.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_DEFER_CT'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Activación de devengamiento no existe en CT (BR-CM-13)' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

 METHOD ValidateNotFinalized.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMHeader FIELDS ( CmStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_cm) FAILED DATA(ls_failed).

    LOOP AT lt_cm INTO DATA(ls_cm).
      IF ls_cm-CmStatus = 'ENVI' OR ls_cm-CmStatus = 'LIBD' OR ls_cm-CmStatus = 'SUPS'.
        APPEND VALUE #( %key = ls_cm-%key ) TO failed-cmheader.
        APPEND VALUE #( %key = ls_cm-%key %state_area = 'VAL_FINAL'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'No se puede modificar un registro Enviado, Liberado o Suprimido' ) )
          TO reported-cmheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_CMRecv DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS ValidateBukrsRecv FOR VALIDATE ON SAVE
      IMPORTING keys FOR CMRecv~ValidateBukrsRecv.
ENDCLASS.

CLASS lhc_CMRecv IMPLEMENTATION.
  METHOD ValidateBukrsRecv.
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMRecv FIELDS ( CmHId BukrsRecv )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_recv).

    " Navegar al header (respeta draft) para obtener contrato + material
    READ ENTITIES OF zi_reingcmperiod IN LOCAL MODE
      ENTITY CMRecv BY \_Header
        FIELDS ( CmHId CtUuid MatUuid )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_hdr).

    " Pre-carga de receptoras validas del contrato/material (una sola lectura DB, sin SELECT en loop)
    TYPES: BEGIN OF ty_fae_ct,
             ct_uuid  TYPE zreing_ct2_rec_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_rec_a-mat_uuid,
           END OF ty_fae_ct.
    DATA lt_fae TYPE SORTED TABLE OF ty_fae_ct WITH UNIQUE KEY ct_uuid mat_uuid.
    LOOP AT lt_hdr INTO DATA(ls_h) WHERE CtUuid IS NOT INITIAL AND MatUuid IS NOT INITIAL.
      TRY.
          INSERT VALUE ty_fae_ct( ct_uuid = ls_h-CtUuid mat_uuid = ls_h-MatUuid ) INTO TABLE lt_fae.
        CATCH cx_sy_itab_duplicate_key.                     "#EC NEEDED
      ENDTRY.
    ENDLOOP.

    DATA lt_valid_recv TYPE SORTED TABLE OF zreing_ct2_rec_a
                       WITH NON-UNIQUE KEY ct_uuid mat_uuid rec_bukrs.
    IF lt_fae IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, rec_bukrs FROM zreing_ct2_rec_a
        FOR ALL ENTRIES IN @lt_fae
        WHERE ct_uuid  = @lt_fae-ct_uuid
          AND mat_uuid = @lt_fae-mat_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_valid_recv.
    ENDIF.

    LOOP AT lt_recv INTO DATA(ls_recv).
      IF ls_recv-BukrsRecv IS INITIAL.
        CONTINUE.
      ENDIF.

      READ TABLE lt_hdr INTO DATA(ls_hdr) WITH KEY CmHId = ls_recv-CmHId.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Lectura en memoria (pre-cargado): sin SELECT dentro del loop
      READ TABLE lt_valid_recv TRANSPORTING NO FIELDS
        WITH KEY ct_uuid   = ls_hdr-CtUuid
                 mat_uuid  = ls_hdr-MatUuid
                 rec_bukrs = ls_recv-BukrsRecv.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_recv-%tky ) TO failed-cmrecv.
        APPEND VALUE #( %tky = ls_recv-%tky
          %element-BukrsRecv = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Sociedad { ls_recv-BukrsRecv }: no es receptora del contrato/material (CM-05)| ) )
          TO reported-cmrecv.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_ReingCMPeriod DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
  PRIVATE SECTION.
    " Mod 02.10.2026 EXT_AGFAGINA - defecto 518: una fila de historial por cambio.
    TYPES tt_log TYPE STANDARD TABLE OF zreing_cm_log WITH EMPTY KEY.
    METHODS add_change
      IMPORTING is_rec    TYPE zreing_cm_h_a
                iv_action TYPE zreing_cm_log-action_code
                iv_field  TYPE zreing_cm_log-field_name
                iv_old    TYPE string
                iv_new    TYPE string
                iv_now    TYPE timestampl
      CHANGING  ct_log    TYPE tt_log.
ENDCLASS.

CLASS lsc_ZI_ReingCMPeriod IMPLEMENTATION.
  METHOD save_modified.
    " Begin Mod 02.10.2026 EXT_AGFAGINA - defecto 518: historial de cambios (ET 7.9).
    " La ET pide un historial con usuario, fecha/hora, campo, valor anterior y valor
    " nuevo, incluyendo los registros SUPS. Hasta ahora ZREING_CM_LOG solo guardaba
    " las acciones Enviar/Liberar/Devolver (foto del registro, sin campo ni valores):
    " un cambio de monto no dejaba rastro.
    " Mismo patron que Contratos (lsc_zi_reingctcontract2->save_modified): en el
    " grabado adicional la base todavia tiene los valores anteriores, asi que se
    " leen y se compara campo por campo contra lo que se va a grabar. Solo se toma
    " un campo si viene marcado en %control Y su valor cambio.
    " Se usa la misma tabla del log de acciones, ampliada con FIELD_NAME /
    " VALUE_OLD / VALUE_NEW, asi el historial del periodo y el del registro son uno.
    DATA lt_log TYPE tt_log.

    " 1) Acciones (Enviar/Liberar/Devolver): las arma write_log en el handler.
    lt_log = lhc_CMHeader=>gt_log_buffer.
    CLEAR lhc_CMHeader=>gt_log_buffer.

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    " 2) Valores anteriores de los registros modificados o borrados.
    DATA lt_keys TYPE SORTED TABLE OF zreing_cm_h_a-cm_h_id WITH UNIQUE KEY table_line.
    LOOP AT update-cmheader INTO DATA(ls_uk).
      INSERT ls_uk-CmHId INTO TABLE lt_keys.
    ENDLOOP.
    LOOP AT delete-cmheader INTO DATA(ls_dk).
      INSERT ls_dk-CmHId INTO TABLE lt_keys.
    ENDLOOP.
    DATA lt_old TYPE HASHED TABLE OF zreing_cm_h_a WITH UNIQUE KEY cm_h_id.
    IF lt_keys IS NOT INITIAL.
      SELECT * FROM zreing_cm_h_a
        FOR ALL ENTRIES IN @lt_keys
        WHERE cm_h_id = @lt_keys-table_line
        INTO TABLE @lt_old.
    ENDIF.

    " 3) Altas: una fila con el monto inicial.
    LOOP AT create-cmheader INTO DATA(ls_cre).
      DATA(ls_new_rec) = VALUE zreing_cm_h_a(
        cm_h_id         = ls_cre-CmHId
        period_year     = ls_cre-PeriodYear
        period_month    = ls_cre-PeriodMonth
        ct_ext_num      = ls_cre-CtExtNum
        matnr           = ls_cre-Matnr
        op_type         = ls_cre-OpType
        op_instance_num = ls_cre-OpInstanceNum
        defer_type      = ls_cre-DeferType
        load_seq        = ls_cre-LoadSeq
        amount          = ls_cre-Amount
        currency        = ls_cre-Currency
        cm_status       = ls_cre-CmStatus ).
      add_change( EXPORTING is_rec = ls_new_rec iv_action = 'CREAR' iv_field = 'Monto'
                            iv_old = `` iv_new = |{ ls_cre-Amount }| iv_now = lv_now
                  CHANGING  ct_log = lt_log ).
    ENDLOOP.

    " 4) Cambios: una fila por campo modificado.
    LOOP AT update-cmheader INTO DATA(ls_upd).
      READ TABLE lt_old INTO DATA(ls_old) WITH TABLE KEY cm_h_id = ls_upd-CmHId.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF ls_upd-%control-CtExtNum = if_abap_behv=>mk-on AND ls_upd-CtExtNum <> ls_old-ct_ext_num.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Contrato'
                              iv_old = |{ ls_old-ct_ext_num }| iv_new = |{ ls_upd-CtExtNum }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-Matnr = if_abap_behv=>mk-on AND ls_upd-Matnr <> ls_old-matnr.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Material'
                              iv_old = |{ ls_old-matnr }| iv_new = |{ ls_upd-Matnr }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-OpType = if_abap_behv=>mk-on AND ls_upd-OpType <> ls_old-op_type.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Tipo de operación'
                              iv_old = |{ ls_old-op_type }| iv_new = |{ ls_upd-OpType }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-OpInstanceNum = if_abap_behv=>mk-on AND ls_upd-OpInstanceNum <> ls_old-op_instance_num.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Nro. Activación'
                              iv_old = |{ ls_old-op_instance_num ALPHA = OUT }|
                              iv_new = |{ ls_upd-OpInstanceNum ALPHA = OUT }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-DeferType = if_abap_behv=>mk-on AND ls_upd-DeferType <> ls_old-defer_type.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Padrón/Bonificación'
                              iv_old = |{ ls_old-defer_type }| iv_new = |{ ls_upd-DeferType }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-Amount = if_abap_behv=>mk-on AND ls_upd-Amount <> ls_old-amount.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Monto'
                              iv_old = |{ ls_old-amount }| iv_new = |{ ls_upd-Amount }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-Currency = if_abap_behv=>mk-on AND ls_upd-Currency <> ls_old-currency.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Moneda'
                              iv_old = |{ ls_old-currency }| iv_new = |{ ls_upd-Currency }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      IF ls_upd-%control-DeltaFlag = if_abap_behv=>mk-on AND ls_upd-DeltaFlag <> ls_old-delta_flag.
        add_change( EXPORTING is_rec = ls_old iv_action = 'MODIFICAR' iv_field = 'Delta'
                              iv_old = |{ ls_old-delta_flag }| iv_new = |{ ls_upd-DeltaFlag }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
      " Sustitucion por una nueva carga (DeriveSupersede): la ET pide que el
      " historial muestre los registros SUPS. Los demas cambios de estado ya los
      " registra write_log (acciones) o son derivados del sistema (PEND/GRAV).
      IF ls_upd-%control-CmStatus = if_abap_behv=>mk-on AND ls_upd-CmStatus = 'SUPS'
         AND ls_old-cm_status <> 'SUPS'.
        add_change( EXPORTING is_rec = ls_old iv_action = 'SUSTITUIR' iv_field = 'Estado'
                              iv_old = |{ ls_old-cm_status }| iv_new = |{ ls_upd-CmStatus }| iv_now = lv_now
                    CHANGING  ct_log = lt_log ).
      ENDIF.
    ENDLOOP.

    " 5) Bajas: una fila con el ultimo monto.
    LOOP AT delete-cmheader INTO DATA(ls_del).
      READ TABLE lt_old INTO ls_old WITH TABLE KEY cm_h_id = ls_del-CmHId.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      add_change( EXPORTING is_rec = ls_old iv_action = 'BORRAR' iv_field = 'Monto'
                            iv_old = |{ ls_old-amount }| iv_new = `` iv_now = lv_now
                  CHANGING  ct_log = lt_log ).
    ENDLOOP.

    IF lt_log IS NOT INITIAL.
      INSERT zreing_cm_log FROM TABLE @lt_log.
    ENDIF.
    " End Mod 02.10.2026 EXT_AGFAGINA
  ENDMETHOD.

  METHOD add_change.
    " Mod 02.10.2026 EXT_AGFAGINA - defecto 518. La fila lleva ademas la foto del
    " registro (contrato, material, tipo, monto, estado) para poder filtrar el
    " historial del periodo sin cruzar con ZREING_CM_H_A.
    DATA lv_uuid TYPE sysuuid_x16.
    TRY.
        lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.
    APPEND VALUE zreing_cm_log(
      log_id       = lv_uuid
      cm_h_id      = is_rec-cm_h_id
      period_year  = is_rec-period_year
      period_month = is_rec-period_month
      action_code  = iv_action
      ct_ext_num   = is_rec-ct_ext_num
      matnr        = is_rec-matnr
      op_type      = is_rec-op_type
      defer_type   = is_rec-defer_type
      load_seq     = is_rec-load_seq
      amount       = is_rec-amount
      currency     = is_rec-currency
      cm_status    = is_rec-cm_status
      action_user  = sy-uname
      action_at    = iv_now
      field_name   = iv_field
      value_old    = iv_old
      value_new    = iv_new ) TO ct_log.
  ENDMETHOD.
ENDCLASS.
