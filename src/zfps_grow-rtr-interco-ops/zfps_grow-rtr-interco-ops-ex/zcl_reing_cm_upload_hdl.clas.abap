CLASS zcl_reing_cm_upload_hdl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_line_status,
        ok      TYPE c LENGTH 1 VALUE 'S',
        error   TYPE c LENGTH 1 VALUE 'E',
        warning TYPE c LENGTH 1 VALUE 'W',
      END OF gc_line_status.

    TYPES:
      tt_bukrs_recv TYPE STANDARD TABLE OF zreing_cm_recv_a-bukrs_recv WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_create_line,
        " Mod 08.09.2026 EXT_AGFAGINA: si cm_h_id viene informado, la linea NO se
        " crea sino que ACTUALIZA el registro existente. Vacio = alta nueva.
        cm_h_id    TYPE zreing_cm_h_a-cm_h_id,
        ct_uuid    TYPE zreing_cm_h_a-ct_uuid,
        ct_ext_num TYPE zreing_cm_h_a-ct_ext_num,
        mat_uuid   TYPE zreing_cm_h_a-mat_uuid,
        matnr      TYPE zreing_cm_h_a-matnr,
        op_type    TYPE zreing_cm_h_a-op_type,
        " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion.
        op_instance_num TYPE zreing_cm_h_a-op_instance_num,
        defer_type TYPE zreing_cm_h_a-defer_type,
        amount     TYPE zreing_cm_h_a-amount,
        delta_flag TYPE zreing_cm_h_a-delta_flag,
        cm_status  TYPE zreing_cm_h_a-cm_status,
        receptoras TYPE tt_bukrs_recv,
      END OF ty_create_line,
      tt_create_line TYPE STANDARD TABLE OF ty_create_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_result_line,
        row_number TYPE i,
        ct_ext_num TYPE zreing_cm_h_a-ct_ext_num,
        matnr      TYPE zreing_cm_h_a-matnr,
        op_type    TYPE zreing_cm_h_a-op_type,
        status     TYPE c LENGTH 1,
        message    TYPE string,
      END OF ty_result_line,
      tt_result_line TYPE STANDARD TABLE OF ty_result_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_import_result,
        aborted      TYPE abap_boolean,
        abort_reason TYPE string,
        results      TYPE tt_result_line,
        create_lines TYPE tt_create_line,
      END OF ty_import_result.

    METHODS import_file
      IMPORTING iv_period_year   TYPE zreing_cm_h_a-period_year
                iv_period_month  TYPE zreing_cm_h_a-period_month
                iv_file_content  TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_import_result.

    METHODS export_template
      IMPORTING iv_period_year         TYPE zreing_cm_h_a-period_year OPTIONAL
                iv_period_month        TYPE zreing_cm_h_a-period_month OPTIONAL
      RETURNING VALUE(rv_file_content) TYPE xstring.

  PRIVATE SECTION.

    " Titulos del template — alineados con ET-REING-CM-001 seccion 6.1.
    CONSTANTS:
      gc_title_contrato TYPE string VALUE 'Contrato',
      gc_title_material TYPE string VALUE 'Material',
      gc_title_tipo_op  TYPE string VALUE 'Tipo Operación',
      gc_title_tipo_dev TYPE string VALUE 'Bonif',
      gc_title_monto    TYPE string VALUE 'Monto',
      gc_title_delta    TYPE string VALUE 'Delta?',
      " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: el template ya tenia la columna
      " pero no se leia, y el numero de activacion cargado se descartaba.
      gc_title_nro_act  TYPE string VALUE 'Número de Activación',
      gc_title_recept   TYPE string VALUE 'Receptoras'.

    " Devengamiento: no se pre-carga en el template porque se deriva de la
    " activacion (ver BR-CM-13 en ZBP_REINGCMPERIOD).
    CONSTANTS gc_optype_deveng TYPE zreing_op_types-op_type VALUE 'D'.

    TYPES:
      BEGIN OF ty_raw_row,
        contrato   TYPE string,
        material   TYPE string,
        tipo_op    TYPE string,
        tipo_dev   TYPE string,
        monto      TYPE string,
        delta      TYPE string,
        receptoras TYPE string,
        " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: columna "Número de Activación".
        nro_act    TYPE string,
        " Mod 29.09.2026 EXT_AGFAGINA - CR-002: fila real del Excel y prioridad de
        " proceso. Las filas se reordenan (el tope F antes que el dependiente A),
        " asi que el numero de fila no puede salir del orden de proceso.
        row_num    TYPE i,
        sort_prio  TYPE i,
      END OF ty_raw_row,
      tt_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

    " Catalogo de tipos de operacion (descripcion normalizada -> codigo)
    TYPES:
      BEGIN OF ty_optype_desc,
        descr_norm TYPE string,
        op_type    TYPE zreing_op_types-op_type,
      END OF ty_optype_desc,
      tt_optype_desc TYPE SORTED TABLE OF ty_optype_desc WITH UNIQUE KEY descr_norm
                       WITH NON-UNIQUE SORTED KEY by_code COMPONENTS op_type.

    METHODS read_rows
      IMPORTING iv_file_content TYPE xstring
      EXPORTING et_rows         TYPE tt_raw_row
                ev_ok           TYPE abap_boolean
                ev_reason       TYPE string.

    " Normaliza texto para match tolerante: mayusculas, sin acentos
    METHODS normalize_text
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rv_result) TYPE string.

    " Resuelve el codigo de tipo de operacion desde el texto descriptivo
    METHODS resolve_op_type
      IMPORTING iv_text           TYPE string
                it_catalog        TYPE tt_optype_desc
      RETURNING VALUE(rv_op_type) TYPE zreing_op_types-op_type.

    " Parseo de receptoras (string separado por comas) -> tabla de sociedades
    METHODS parse_receptoras
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rt_result) TYPE tt_bukrs_recv.
ENDCLASS.


CLASS zcl_reing_cm_upload_hdl IMPLEMENTATION.

  METHOD import_file.

    DATA lt_rows TYPE tt_raw_row.
    read_rows(
      EXPORTING iv_file_content = iv_file_content
      IMPORTING et_rows         = lt_rows
                ev_ok           = DATA(lv_ok)
                ev_reason       = DATA(lv_reason) ).

    IF lv_ok = abap_false.
      rs_result-aborted      = abap_true.
      rs_result-abort_reason = lv_reason.
      RETURN.
    ENDIF.

    "--- Catalogo de tipos de operacion: descripcion normalizada -> codigo ---
    " WHERE sobre la clave (op_type nunca es inicial): trae todo el catalogo.
    SELECT op_type, descr, permite_delta, ceiling_op_type FROM zreing_op_types
      WHERE op_type IS NOT INITIAL
      INTO TABLE @DATA(lt_optype_all).

    DATA lt_op_desc TYPE tt_optype_desc.
    DATA lt_optype_cat TYPE SORTED TABLE OF zreing_op_types WITH UNIQUE KEY op_type.
    LOOP AT lt_optype_all INTO DATA(ls_opt_all).
      INSERT VALUE ty_optype_desc(
        descr_norm = normalize_text( CONV string( ls_opt_all-descr ) )
        op_type    = ls_opt_all-op_type ) INTO TABLE lt_op_desc.
      INSERT VALUE zreing_op_types(
        op_type         = ls_opt_all-op_type
        " Mod 01.10.2026 EXT_AGFAGINA: la descripcion se usa en los mensajes de
        " BR-CM-14 ("Activación supera a Facturación" en vez de "A supera a F").
        descr           = ls_opt_all-descr
        permite_delta   = ls_opt_all-permite_delta
        ceiling_op_type = ls_opt_all-ceiling_op_type ) INTO TABLE lt_optype_cat.
    ENDLOOP.

    "--- Resolver codigo de tipo op por linea (texto -> codigo) ---
    " Se guarda en la propia fila (campo tipo_op pasa a contener el codigo).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_resolve>) WHERE tipo_op IS NOT INITIAL.
      <ls_resolve>-tipo_op = resolve_op_type(
        iv_text = <ls_resolve>-tipo_op it_catalog = lt_op_desc ).
    ENDLOOP.

    " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002 (Ceiling Rule), ordenar filas.
    " La validacion BR-CM-14 de un tipo con tope (ej. A, tope F) necesita que las
    " lineas del tope en el MISMO archivo ya esten procesadas y sumadas. Por eso
    " primero van los tipos sin tope (prioridad 0) y despues los que tienen tope
    " (prioridad 1). El SORT es estable: dentro de cada grupo se respeta el orden
    " del archivo. Los mensajes usan row_num, la fila real del Excel.
    " La ET contempla cadenas de mas de un nivel (X -> A -> F); hoy la unica
    " relacion configurada es A -> F, asi que alcanza con dos niveles.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_prio>).
      <ls_prio>-sort_prio = 0.
      READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_prio_cat>)
        WITH KEY op_type = <ls_prio>-tipo_op.
      IF sy-subrc = 0.
        IF <ls_prio_cat>-ceiling_op_type IS NOT INITIAL.
          <ls_prio>-sort_prio = 1.
        ENDIF.
      ENDIF.
    ENDLOOP.
    SORT lt_rows STABLE BY sort_prio ASCENDING.
    " End Mod 29.09.2026 EXT_AGFAGINA

    "--- Recoleccion de claves del Excel para lectura en bloque ---
    DATA lt_ct_keys TYPE SORTED TABLE OF zreing_ct2_a-ct_id WITH UNIQUE KEY table_line.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE contrato IS NOT INITIAL.
      INSERT CONV zreing_ct2_a-ct_id( <ls_row>-contrato ) INTO TABLE lt_ct_keys.
    ENDLOOP.

    DATA lt_contract TYPE SORTED TABLE OF zreing_ct2_a
                     WITH UNIQUE KEY ct_id.
    DATA lt_mat TYPE SORTED TABLE OF zreing_ct2_mat_a
                WITH UNIQUE KEY ct_uuid matnr.
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la clave incluye la instancia. Antes
    " era UNIQUE por contrato + material + tipo y de dos activaciones (A 002 / A 003)
    " quedaba una sola. La lectura por tipo sigue funcionando: es prefijo de la clave.
    DATA lt_opt TYPE SORTED TABLE OF zreing_ct2_opt_a
                WITH UNIQUE KEY ct_uuid mat_uuid op_type op_instance_num.

    IF lt_ct_keys IS NOT INITIAL.
      " Lectura unica via JOIN (contrato + material + tipo op.), filtrada por los CT del Excel
      SELECT ct~ct_uuid, ct~ct_id, ct~ct_status, ct~waers,
             mat~mat_uuid, mat~matnr,
             opt~op_type, opt~op_instance_num
        FROM zreing_ct2_a AS ct
        LEFT OUTER JOIN zreing_ct2_mat_a AS mat
          ON  mat~ct_uuid = ct~ct_uuid
        LEFT OUTER JOIN zreing_ct2_opt_a AS opt
          ON  opt~ct_uuid  = mat~ct_uuid
          AND opt~mat_uuid = mat~mat_uuid
        FOR ALL ENTRIES IN @lt_ct_keys
        WHERE ct~ct_id = @lt_ct_keys-table_line
        INTO TABLE @DATA(lt_join).

      " Deduplicacion via UNIQUE key: el INSERT ignora duplicados (sy-subrc=4),
      " sin READ previo ni scan dentro del loop.
      LOOP AT lt_join ASSIGNING FIELD-SYMBOL(<ls_join>).
        INSERT VALUE #( ct_uuid   = <ls_join>-ct_uuid
                        ct_id     = <ls_join>-ct_id
                        ct_status = <ls_join>-ct_status
                        waers     = <ls_join>-waers ) INTO TABLE lt_contract.
        IF <ls_join>-mat_uuid IS NOT INITIAL.
          INSERT VALUE #( ct_uuid  = <ls_join>-ct_uuid
                          mat_uuid = <ls_join>-mat_uuid
                          matnr    = <ls_join>-matnr ) INTO TABLE lt_mat.
        ENDIF.
        IF <ls_join>-op_type IS NOT INITIAL.
          INSERT VALUE #( ct_uuid         = <ls_join>-ct_uuid
                          mat_uuid        = <ls_join>-mat_uuid
                          op_type         = <ls_join>-op_type
                          op_instance_num = <ls_join>-op_instance_num ) INTO TABLE lt_opt.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Begin Mod 01.10.2026 EXT_AGFAGINA - defecto 109: opciones por tipo.
    " Por contrato + material + tipo: cuantas instancias hay, la unica (si hay una)
    " y la lista para los mensajes ("2, 3"). Se arma una vez, sin loop anidado.
    TYPES: BEGIN OF ty_inst_cnt,
             ct_uuid  TYPE zreing_ct2_opt_a-ct_uuid,
             mat_uuid TYPE zreing_ct2_opt_a-mat_uuid,
             op_type  TYPE zreing_ct2_opt_a-op_type,
             cnt      TYPE i,
             single   TYPE zreing_ct2_opt_a-op_instance_num,
             list     TYPE string,
           END OF ty_inst_cnt.
    DATA lt_inst_cnt TYPE HASHED TABLE OF ty_inst_cnt WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_opt INTO DATA(ls_opt_cnt).
      READ TABLE lt_inst_cnt ASSIGNING FIELD-SYMBOL(<ls_ic>)
        WITH TABLE KEY ct_uuid  = ls_opt_cnt-ct_uuid
                       mat_uuid = ls_opt_cnt-mat_uuid
                       op_type  = ls_opt_cnt-op_type.
      IF sy-subrc = 0.
        <ls_ic>-cnt  = <ls_ic>-cnt + 1.
        <ls_ic>-list = |{ <ls_ic>-list }, { ls_opt_cnt-op_instance_num ALPHA = OUT }|.
      ELSE.
        INSERT VALUE #( ct_uuid  = ls_opt_cnt-ct_uuid
                        mat_uuid = ls_opt_cnt-mat_uuid
                        op_type  = ls_opt_cnt-op_type
                        cnt      = 1
                        single   = ls_opt_cnt-op_instance_num
                        list     = |{ ls_opt_cnt-op_instance_num ALPHA = OUT }| ) INTO TABLE lt_inst_cnt.
      ENDIF.
    ENDLOOP.
    " End Mod 01.10.2026 EXT_AGFAGINA

    " Begin Mod 08.09.2026 EXT_AGFAGINA - se trae CM_H_ID y se amplian los estados.
    " Antes solo se miraban GRAV/ENVI/LIBD y todos se descartaban. Ahora:
    "   GRAV / PEND / ERR  -> la linea PISA el registro existente (update)
    "   ENVI / LIBD / SUPS -> no se puede pisar: aviso y descarte (salvo delta)
    " Se agregan PEND y ERR porque antes ni se detectaban: una recarga corregida
    " creaba una segunda linea y quedaban las dos.
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: la instancia es parte de la clave.
    DATA lt_existing TYPE SORTED TABLE OF zreing_cm_h_a
                     WITH NON-UNIQUE KEY ct_uuid mat_uuid op_type op_instance_num defer_type.
    SELECT cm_h_id, ct_uuid, mat_uuid, op_type, op_instance_num, defer_type, cm_status, amount
      FROM zreing_cm_h_a
      WHERE period_year  = @iv_period_year
        AND period_month = @iv_period_month
        AND cm_status IN ( 'PEND', 'GRAV', 'ERR', 'ENVI', 'LIBD' )
      INTO CORRESPONDING FIELDS OF TABLE @lt_existing.
    " End Mod 08.09.2026 EXT_AGFAGINA

    " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002 (Ceiling Rule), totales del periodo.
    " Suma de lo ya grabado por contrato + material + tipo de operacion. Se arma
    " una sola vez con los registros existentes que el import ya lee (sin SELECT
    " nuevo) y durante el loop se actualiza con cada linea aceptada, para que
    " una A del archivo se compare contra la F grabada MAS la F del mismo archivo.
    " No suman los SUPS (el SELECT no los trae) ni los ERR, que no son cargas
    " validas (criterio acordado con Vinicius el 29.09.2026).
    " Sin reglas de moneda: se comparan los montos tal cual (Vinicius, 29.09.2026).
    " last_row = ultima fila del archivo que toco ese total (0 = ninguna).
    TYPES: BEGIN OF ty_ceil_tot,
             ct_uuid  TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid TYPE zreing_cm_h_a-mat_uuid,
             op_type  TYPE zreing_cm_h_a-op_type,
             total    TYPE p LENGTH 16 DECIMALS 2,
             last_row TYPE i,
           END OF ty_ceil_tot.
    DATA lt_ceil_tot TYPE HASHED TABLE OF ty_ceil_tot
                     WITH UNIQUE KEY ct_uuid mat_uuid op_type.
    LOOP AT lt_existing INTO DATA(ls_ex_tot).
      IF ls_ex_tot-cm_status = 'ERR'.
        CONTINUE.
      ENDIF.
      READ TABLE lt_ceil_tot ASSIGNING FIELD-SYMBOL(<ls_tot>)
        WITH TABLE KEY ct_uuid  = ls_ex_tot-ct_uuid
                       mat_uuid = ls_ex_tot-mat_uuid
                       op_type  = ls_ex_tot-op_type.
      IF sy-subrc = 0.
        <ls_tot>-total = <ls_tot>-total + ls_ex_tot-amount.
      ELSE.
        INSERT VALUE #( ct_uuid  = ls_ex_tot-ct_uuid
                        mat_uuid = ls_ex_tot-mat_uuid
                        op_type  = ls_ex_tot-op_type
                        total    = ls_ex_tot-amount ) INTO TABLE lt_ceil_tot.
      ENDIF.
    ENDLOOP.
    " End Mod 29.09.2026 EXT_AGFAGINA

    "--- Validacion por linea (N2). Sin SELECT en loop, sin loops anidados ---
    DATA lv_rownum TYPE i VALUE 1.
    LOOP AT lt_rows ASSIGNING <ls_row>.
      " Mod 29.09.2026 EXT_AGFAGINA - CR-002: las filas estan reordenadas, el
      " numero de fila de los mensajes sale del Excel y no del orden de proceso.
      lv_rownum = <ls_row>-row_num.

      " Begin Mod 09.09.2026 EXT_AGFAGINA - normalizar la marca de Delta.
      " La columna "Delta?" se comparaba contra 'X' en mayuscula exacta, en tres
      " lugares: la validacion BR-CM-07, el chequeo de duplicados y el valor que
      " se persiste. Si el usuario escribe 'x' en minuscula (caso real: archivo de
      " 09/2026 de IC-0007), fallaba todo a la vez:
      "   - no se reconocia como delta y la linea se descartaba por duplicada
      "   - no se validaba que el tipo de operacion admitiera delta
      "   - de haberse grabado, DELTA_FLAG quedaba en minuscula
      " Se normaliza una sola vez aca, igual que ya se hace con la columna Bonif.
      <ls_row>-delta = to_upper( condense( <ls_row>-delta ) ).
      " End Mod 09.09.2026 EXT_AGFAGINA

      " Derivar DEFER_TYPE desde columna 'Tipo Dev.' (ET 6.1).
      " Valores validos: P (Padron) o B (Bonificacion). Solo aplica a Op. tipo A.
      " Si viene vacio o invalido para tipo A: default P (BR-CM-12 lo validara en save).
      DATA lv_defer TYPE zreing_cm_h_a-defer_type.
      CLEAR lv_defer.
      IF <ls_row>-tipo_op = 'A'.
        " Columna 'Bonif': flag 'X' = Bonificacion (B). Vacio = Padron (P).
        " Se tolera 'B'/'P' literal por robustez.
        DATA(lv_bonif_raw) = to_upper( condense( <ls_row>-tipo_dev ) ).
        IF lv_bonif_raw = 'X' OR lv_bonif_raw = 'B'.
          lv_defer = 'B'.
        ELSE.
          lv_defer = 'P'.
        ENDIF.
      ENDIF.

      DATA(ls_res) = VALUE ty_result_line(
        row_number = lv_rownum
        ct_ext_num = <ls_row>-contrato
        op_type    = <ls_row>-tipo_op ).

      IF <ls_row>-contrato IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Contrato obligatorio (BR-CM-02)'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      READ TABLE lt_contract ASSIGNING FIELD-SYMBOL(<ls_ct>)
        WITH KEY ct_id = <ls_row>-contrato.
      IF sy-subrc <> 0.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Contrato inexistente (BR-CM-02)'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      IF <ls_ct>-ct_status <> 'AC'.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Contrato inactivo (BR-CM-02)'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      IF <ls_row>-material IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Material obligatorio (BR-CM-03)'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      READ TABLE lt_mat ASSIGNING FIELD-SYMBOL(<ls_mat>)
        WITH KEY ct_uuid = <ls_ct>-ct_uuid
                 matnr   = CONV matnr( <ls_row>-material ).
      IF sy-subrc <> 0.
        ls_res-matnr   = <ls_row>-material.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Material no configurado para el contrato (BR-CM-03)'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      ls_res-matnr = <ls_mat>-matnr.

      " A partir de aqui contrato y material estan resueltos (UUIDs validos).
      " Errores en Tipo Op./Tipo Dev./Delta NO descartan: se persiste en ERR.
      DATA lv_err_msg TYPE string.
      CLEAR lv_err_msg.

      IF <ls_row>-tipo_op IS INITIAL.
        " tipo_op vacio = no se pudo resolver el texto contra el catalogo
        lv_err_msg = 'Tipo Op. invalido o no reconocido (BR-CM-04)'.
      ELSE.
        READ TABLE lt_opt TRANSPORTING NO FIELDS
          WITH KEY ct_uuid  = <ls_ct>-ct_uuid
                   mat_uuid = <ls_mat>-mat_uuid
                   op_type  = <ls_row>-tipo_op.
        IF sy-subrc <> 0.
          lv_err_msg = 'Tipo Op. no valido para CT/Material (BR-CM-04)'.
        ENDIF.
      ENDIF.

      " Begin Mod 01.10.2026 EXT_AGFAGINA - defecto 109: numero de activacion.
      " Columna "Número de Activación":
      "   - vacia y el contrato tiene UNA sola opcion del tipo -> se toma esa
      "     (F, P, NC siempre 001; contratos con una unica activacion);
      "   - vacia y hay varias                                 -> error, se pide cual;
      "   - informada                                          -> tiene que existir.
      " Excel puede devolver un numero como "2" o "2.0": se toleran ceros decimales.
      DATA lv_inst TYPE zreing_cm_h_a-op_instance_num.
      CLEAR lv_inst.
      IF lv_err_msg IS INITIAL.
        READ TABLE lt_inst_cnt INTO DATA(ls_ic_row)
          WITH TABLE KEY ct_uuid  = <ls_ct>-ct_uuid
                         mat_uuid = <ls_mat>-mat_uuid
                         op_type  = <ls_row>-tipo_op.
        DATA(lv_nro_raw) = condense( <ls_row>-nro_act ).
        IF lv_nro_raw CS '.'.
          SPLIT lv_nro_raw AT '.' INTO DATA(lv_nro_int) DATA(lv_nro_dec).
          IF lv_nro_dec CO '0'.
            lv_nro_raw = lv_nro_int.
          ENDIF.
        ENDIF.
        IF lv_nro_raw IS INITIAL.
          IF ls_ic_row-cnt = 1.
            lv_inst = ls_ic_row-single.
          ELSE.
            lv_err_msg = |El contrato tiene { ls_ic_row-cnt } opciones del tipo { <ls_row>-tipo_op } | &&
                         |para este material ({ ls_ic_row-list }): indique cuál en la columna | &&
                         |"Número de Activación".|.
          ENDIF.
        ELSEIF lv_nro_raw CN '0123456789'.
          lv_err_msg = |Número de Activación no numérico: '{ lv_nro_raw }'.|.
        ELSE.
          lv_inst = lv_nro_raw.
          IF NOT line_exists( lt_opt[ ct_uuid         = <ls_ct>-ct_uuid
                                      mat_uuid        = <ls_mat>-mat_uuid
                                      op_type         = <ls_row>-tipo_op
                                      op_instance_num = lv_inst ] ).
            lv_err_msg = |El número de activación { lv_nro_raw } no existe en el contrato para el | &&
                         |tipo { <ls_row>-tipo_op } (disponibles: { ls_ic_row-list }).|.
          ENDIF.
        ENDIF.
      ENDIF.
      " End Mod 01.10.2026 EXT_AGFAGINA

      " Delta solo permitido para tipos con permite_delta = X
      IF lv_err_msg IS INITIAL AND <ls_row>-delta = 'X'.
        READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_cat>)
          WITH KEY op_type = <ls_row>-tipo_op.
        IF sy-subrc <> 0 OR <ls_cat>-permite_delta <> 'X'.
          lv_err_msg = 'Este tipo de operacion no permite delta (BR-CM-07)'.
        ENDIF.
      ENDIF.

      " Begin Mod 08.09.2026 EXT_AGFAGINA - las lineas con delta NO son duplicados.
      " Definicion del funcional: si se carga una combinacion que ya existe pero la
      " linea viene marcada como delta, debe permitirse y generar una LINEA NUEVA,
      " no descartarse. Es una carga diferencial, no una recarga.
      " Antes el chequeo de duplicados no miraba DELTA_FLAG: comparaba solo por
      " ct_uuid + mat_uuid + op_type + defer_type, asi que cualquier recarga de la
      " misma combinacion se descartaba en silencio, con delta o sin el.
      " La convivencia de varias lineas la resuelve LOAD_SEQ, que la determinacion
      " DeriveLoadSeq asigna como MAX + 1 al crear. Por eso se pueden cargar N
      " deltas sucesivos sin chocar entre si.
      " Sin delta el comportamiento no cambia: se sigue avisando y descartando,
      " segun la ET de CM (N2 - Aviso: registro ENVI/LIBD ya existe).
      " Begin Mod 08.09.2026 EXT_AGFAGINA - pisar o descartar segun el estado.
      " Reglas confirmadas por el funcional:
      "  - linea con delta 'X'          -> siempre alta nueva (carga diferencial).
      "                                    La convivencia la resuelve LOAD_SEQ.
      "  - existe en GRAV / PEND / ERR  -> se PISA con los valores nuevos (update).
      "  - existe en ENVI / LIBD        -> no se puede pisar: aviso y descarte.
      " El valor anterior no se pierde del todo: queda en ZREING_CM_LOG.
      DATA lv_upd_cmhid TYPE zreing_cm_h_a-cm_h_id.
      CLEAR lv_upd_cmhid.

      " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: se busca por instancia, y solo si la
      " linea no tiene error: si no, un aviso de "ya existe" de un registro viejo
      " (instancia vacia) podia tapar un error de numero de activacion.
      IF <ls_row>-delta <> 'X' AND lv_err_msg IS INITIAL.
        READ TABLE lt_existing INTO DATA(ls_exist)
          WITH KEY ct_uuid         = <ls_ct>-ct_uuid
                   mat_uuid        = <ls_mat>-mat_uuid
                   op_type         = <ls_row>-tipo_op
                   op_instance_num = lv_inst
                   defer_type      = lv_defer.
        IF sy-subrc = 0.
          IF ls_exist-cm_status = 'ENVI' OR ls_exist-cm_status = 'LIBD'.
            ls_res-status  = gc_line_status-warning.
            ls_res-message = 'Ya existe registro ENVI/LIBD para la combinacion: no se importa'.
            APPEND ls_res TO rs_result-results.
            CONTINUE.
          ELSE.
            " GRAV / PEND / ERR: la linea nueva reemplaza los valores del registro
            lv_upd_cmhid = ls_exist-cm_h_id.
          ENDIF.
        ENDIF.
      ENDIF.
      " End Mod 08.09.2026 EXT_AGFAGINA
      " End Mod 08.09.2026 EXT_AGFAGINA

      IF lv_err_msg IS NOT INITIAL.
        " No se persiste la linea con error: solo se reporta para abortar el import.
        ls_res-status  = gc_line_status-error.
        ls_res-message = lv_err_msg.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Begin Mod 08.09.2026 EXT_AGFAGINA - conversion de monto protegida.
      " Dos problemas en la linea original "CONV zreing_cm_h_a-amount( monto )":
      "  1) No tolera notacion cientifica. Excel (en particular la version de Mac)
      "     guarda 100000000 como "1.0E8", y el CONV a DEC(15,2) reventaba con
      "     CONVT_NO_NUMBER. Dump real en TS4 el 08.09.2026 con el template propio.
      "  2) La conversion no estaba protegida: CUALQUIER texto no numerico en la
      "     columna Monto producia un dump en lugar de un mensaje de linea.
      " Se convierte primero a float, que si acepta notacion cientifica, y se
      " envuelve en TRY para reportar la fila en vez de abortar el proceso.
      DATA lv_amount_chk TYPE zreing_cm_h_a-amount.
      DATA lv_monto_f    TYPE f.
      CLEAR: lv_amount_chk, lv_monto_f.

      DATA(lv_monto_raw) = condense( <ls_row>-monto ).
      IF lv_monto_raw IS NOT INITIAL.
        TRY.
            lv_monto_f    = lv_monto_raw.
            lv_amount_chk = lv_monto_f.
          CATCH cx_sy_conversion_no_number.
            ls_res-status  = gc_line_status-error.
            ls_res-message = |Monto no numerico: '{ lv_monto_raw }'. Use solo digitos | &&
                             |y punto decimal, sin separador de miles.|.
            APPEND ls_res TO rs_result-results.
            CONTINUE.
        ENDTRY.
      ENDIF.

      " Ignorar lineas con monto 0 (o vacio) — no se crea el registro
      IF lv_amount_chk IS INITIAL OR lv_amount_chk = 0.
      " End Mod 08.09.2026 EXT_AGFAGINA
        ls_res-status  = gc_line_status-warning.
        ls_res-message = 'Monto 0 o vacio: linea ignorada'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.


      " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002 / BR-CM-14 ValidateCeilingAmount.
      " Si el tipo de la linea tiene tope (ZREING_OP_TYPES-CEILING_OP_TYPE, ej. A -> F):
      "   a) debe existir alguna carga del tope para el mismo contrato + material +
      "      periodo, grabada o en este mismo archivo;
      "   b) la suma del tipo (grabado + archivo + esta linea) no puede superar la
      "      suma del tope.
      " Si la linea pisa un registro existente (GRAV/PEND), su monto viejo sale de la
      " suma: si no, el mismo registro se contaria dos veces y se rechazaria una
      " recarga valida. Un ERR no sumaba, asi que no se descuenta.
      " El codigo nunca referencia tipos concretos: todo sale del catalogo.
      DATA lv_repl_amt  TYPE p LENGTH 16 DECIMALS 2.
      DATA lv_cur_total TYPE p LENGTH 16 DECIMALS 2.
      DATA lv_ceiling   TYPE zreing_op_types-ceiling_op_type.
      CLEAR: lv_repl_amt, lv_cur_total, lv_ceiling.

      IF lv_upd_cmhid IS NOT INITIAL AND ls_exist-cm_status <> 'ERR'.
        lv_repl_amt = ls_exist-amount.
      ENDIF.

      READ TABLE lt_ceil_tot ASSIGNING <ls_tot>
        WITH TABLE KEY ct_uuid  = <ls_ct>-ct_uuid
                       mat_uuid = <ls_mat>-mat_uuid
                       op_type  = <ls_row>-tipo_op.
      IF sy-subrc = 0.
        lv_cur_total = <ls_tot>-total.
      ENDIF.
      lv_cur_total = lv_cur_total - lv_repl_amt + lv_amount_chk.

      READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_ceil_cat>)
        WITH KEY op_type = <ls_row>-tipo_op.
      IF sy-subrc = 0.
        lv_ceiling = <ls_ceil_cat>-ceiling_op_type.
      ENDIF.

      IF lv_ceiling IS NOT INITIAL.
        " Mod 01.10.2026 EXT_AGFAGINA: el mensaje usa las descripciones del
        " catalogo y los montos con formato ("Activación (800.000,00) supera a
        " Facturación (115.062,00)") en vez de "A (800000.00) supera el de F".
        " Redaccion sin articulos de genero: los tipos salen de la configuracion.
        DATA lv_t_name TYPE string.
        DATA lv_c_name TYPE string.
        lv_t_name = to_mixed( val = condense( CONV string( <ls_ceil_cat>-descr ) ) ).
        IF lv_t_name IS INITIAL.
          lv_t_name = <ls_row>-tipo_op.
        ENDIF.
        lv_c_name = lv_ceiling.
        READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_cn>)
          WITH TABLE KEY op_type = lv_ceiling.
        IF sy-subrc = 0.
          IF <ls_cn>-descr IS NOT INITIAL.
            lv_c_name = to_mixed( val = condense( CONV string( <ls_cn>-descr ) ) ).
          ENDIF.
        ENDIF.

        READ TABLE lt_ceil_tot ASSIGNING FIELD-SYMBOL(<ls_ceil_tot>)
          WITH TABLE KEY ct_uuid  = <ls_ct>-ct_uuid
                         mat_uuid = <ls_mat>-mat_uuid
                         op_type  = lv_ceiling.
        IF sy-subrc <> 0.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |{ lv_t_name } requiere que exista { lv_c_name } para el mismo contrato, | &&
                           |material y período: cargue { lv_c_name } antes o en el mismo archivo (BR-CM-14).|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
        IF lv_cur_total > <ls_ceil_tot>-total.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |{ lv_t_name } ({ lv_cur_total NUMBER = USER }) supera a { lv_c_name } | &&
                           |({ <ls_ceil_tot>-total NUMBER = USER }) del mismo contrato, material y período (BR-CM-14).|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
      ENDIF.

      " Linea aceptada: su monto pasa a formar parte del total de su tipo, para que
      " las lineas siguientes del archivo lo tengan en cuenta.
      READ TABLE lt_ceil_tot ASSIGNING <ls_tot>
        WITH TABLE KEY ct_uuid  = <ls_ct>-ct_uuid
                       mat_uuid = <ls_mat>-mat_uuid
                       op_type  = <ls_row>-tipo_op.
      IF sy-subrc = 0.
        <ls_tot>-total    = lv_cur_total.
        <ls_tot>-last_row = lv_rownum.
      ELSE.
        INSERT VALUE #( ct_uuid  = <ls_ct>-ct_uuid
                        mat_uuid = <ls_mat>-mat_uuid
                        op_type  = <ls_row>-tipo_op
                        total    = lv_cur_total
                        last_row = lv_rownum ) INTO TABLE lt_ceil_tot.
      ENDIF.
      " End Mod 29.09.2026 EXT_AGFAGINA

      " Parsear receptoras (opcional, separadas por coma) — sin loop anidado
      DATA(lt_recept) = parse_receptoras( <ls_row>-receptoras ).

      ls_res-status  = gc_line_status-ok.
      ls_res-message = 'OK'.
      APPEND ls_res TO rs_result-results.

      APPEND VALUE ty_create_line(
              cm_h_id    = lv_upd_cmhid
              ct_uuid    = <ls_ct>-ct_uuid
              ct_ext_num = <ls_ct>-ct_id
              mat_uuid   = <ls_mat>-mat_uuid
              matnr      = <ls_mat>-matnr
              op_type    = <ls_row>-tipo_op
              op_instance_num = lv_inst
              defer_type = lv_defer
              " Mod 08.09.2026 EXT_AGFAGINA: se reusa el valor ya convertido y
              " validado arriba. Antes habia un segundo CONV sobre el string
              " crudo, con el mismo riesgo de CONVT_NO_NUMBER.
              amount     = lv_amount_chk
              delta_flag = <ls_row>-delta
              cm_status  = 'PEND'
              receptoras = lt_recept ) TO rs_result-create_lines.

    ENDLOOP.

    " Begin Mod 29.09.2026 EXT_AGFAGINA - CR-002 / BR-CM-14, el tope no puede bajar.
    " Caso inverso a la validacion de cada linea: el archivo trae una F que PISA una
    " F grabada con un monto menor, y la A del periodo ya estaba grabada (no viene
    " en el archivo, asi que nunca se valido contra la F nueva). Sin este control la
    " A quedaria por encima del tope sin que nada lo detecte.
    " Se evalua al final, con los totales ya completos. Solo se reporta cuando el
    " tope fue tocado por este archivo (last_row > 0): una inconsistencia previa
    " que el archivo no causo no debe bloquear la carga.
    " El error va en la ultima fila del tope; como todo error aborta el import,
    " no se graba ninguna linea.
    LOOP AT lt_ceil_tot ASSIGNING FIELD-SYMBOL(<ls_dep>).
      READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_dep_cat>)
        WITH KEY op_type = <ls_dep>-op_type.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF <ls_dep_cat>-ceiling_op_type IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE lt_ceil_tot ASSIGNING FIELD-SYMBOL(<ls_top>)
        WITH TABLE KEY ct_uuid  = <ls_dep>-ct_uuid
                       mat_uuid = <ls_dep>-mat_uuid
                       op_type  = <ls_dep_cat>-ceiling_op_type.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF <ls_top>-last_row > 0 AND <ls_dep>-total > <ls_top>-total.
        " Mod 01.10.2026 EXT_AGFAGINA: descripciones del catalogo y montos con formato.
        DATA lv_dep_name TYPE string.
        DATA lv_top_name TYPE string.
        lv_dep_name = to_mixed( val = condense( CONV string( <ls_dep_cat>-descr ) ) ).
        IF lv_dep_name IS INITIAL.
          lv_dep_name = <ls_dep>-op_type.
        ENDIF.
        lv_top_name = <ls_top>-op_type.
        READ TABLE lt_optype_cat ASSIGNING FIELD-SYMBOL(<ls_top_cat>)
          WITH TABLE KEY op_type = <ls_top>-op_type.
        IF sy-subrc = 0.
          IF <ls_top_cat>-descr IS NOT INITIAL.
            lv_top_name = to_mixed( val = condense( CONV string( <ls_top_cat>-descr ) ) ).
          ENDIF.
        ENDIF.
        APPEND VALUE ty_result_line(
          row_number = <ls_top>-last_row
          op_type    = <ls_top>-op_type
          status     = gc_line_status-error
          message    = |Con esta carga, { lv_top_name } ({ <ls_top>-total NUMBER = USER }) quedaría por | &&
                       |debajo de lo ya cargado de { lv_dep_name } ({ <ls_dep>-total NUMBER = USER }) | &&
                       |del mismo contrato, material y período (BR-CM-14).| )
          TO rs_result-results.
      ENDIF.
    ENDLOOP.
    " End Mod 29.09.2026 EXT_AGFAGINA

  ENDMETHOD.


  METHOD normalize_text.
    " Mayusculas + quitar acentos + comprimir espacios
    rv_result = to_upper( condense( iv_text ) ).
    REPLACE ALL OCCURRENCES OF 'Á' IN rv_result WITH 'A'.
    REPLACE ALL OCCURRENCES OF 'É' IN rv_result WITH 'E'.
    REPLACE ALL OCCURRENCES OF 'Í' IN rv_result WITH 'I'.
    REPLACE ALL OCCURRENCES OF 'Ó' IN rv_result WITH 'O'.
    REPLACE ALL OCCURRENCES OF 'Ú' IN rv_result WITH 'U'.
    REPLACE ALL OCCURRENCES OF 'Ñ' IN rv_result WITH 'N'.
    REPLACE ALL OCCURRENCES OF 'Ü' IN rv_result WITH 'U'.
  ENDMETHOD.


  METHOD resolve_op_type.
    " Match tolerante del texto contra las descripciones del catalogo.
    " Si no matchea, devuelve vacio (la linea caera en ERR).
    DATA(lv_norm) = normalize_text( iv_text ).

    " 1) Match exacto contra descripcion normalizada
    READ TABLE it_catalog INTO DATA(ls_cat) WITH KEY descr_norm = lv_norm.
    IF sy-subrc = 0.
      rv_op_type = ls_cat-op_type.
      RETURN.
    ENDIF.

    " 2) Si el texto ya es un codigo valido (ej. "F", "A"), aceptarlo.
    "    Acceso por clave secundaria ordenada (by_code), sin scan secuencial.
    DATA(lv_code_norm) = to_upper( condense( iv_text ) ).
    READ TABLE it_catalog INTO DATA(ls_code)
      WITH KEY by_code COMPONENTS op_type = lv_code_norm.
    IF sy-subrc = 0.
      rv_op_type = ls_code-op_type.
      RETURN.
    ENDIF.

    CLEAR rv_op_type.
  ENDMETHOD.


  METHOD read_rows.
    ev_ok = abap_true.

    TRY.
        DATA(lo_read) = xco_cp_xlsx=>document->for_file_content( iv_file_content
                          )->read_access( ).
        DATA(lo_sheet) = lo_read->get_workbook( )->worksheet->at_position( 1 ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudo abrir el archivo Excel'.
        RETURN.
    ENDTRY.

    " Leer fila de titulos (A:J = 10 columnas del formato objetivo)
    DATA(lo_hdr_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'N' )
      )->to_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    TYPES: BEGIN OF ty_row10,
             c1  TYPE string, c2  TYPE string, c3  TYPE string,
             c4  TYPE string, c5  TYPE string, c6  TYPE string,
             c7  TYPE string, c8  TYPE string, c9  TYPE string,
             c10 TYPE string, c11 TYPE string, c12 TYPE string,
             c13 TYPE string, c14 TYPE string,
           END OF ty_row10.
    DATA lt_hdr TYPE STANDARD TABLE OF ty_row10 WITH EMPTY KEY.

    TRY.
        lo_sheet->select( lo_hdr_pattern
          )->row_stream(
          )->operation->write_to( REF #( lt_hdr )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudo leer la fila de titulos'.
        RETURN.
    ENDTRY.

    DATA(ls_hdr) = VALUE ty_row10( lt_hdr[ 1 ] OPTIONAL ).

    " Construir mapa titulo -> indice de columna
    TYPES: BEGIN OF ty_colmap,
             title TYPE string,
             col   TYPE i,
           END OF ty_colmap.
    DATA lt_colmap TYPE SORTED TABLE OF ty_colmap WITH UNIQUE KEY title.
    DATA lt_hdr_seq TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_hdr_seq = VALUE #( ( condense( ls_hdr-c1 ) ) ( condense( ls_hdr-c2 ) )
                          ( condense( ls_hdr-c3 ) ) ( condense( ls_hdr-c4 ) )
                          ( condense( ls_hdr-c5 ) ) ( condense( ls_hdr-c6 ) )
                          ( condense( ls_hdr-c7 ) ) ( condense( ls_hdr-c8 ) )
                          ( condense( ls_hdr-c9 ) ) ( condense( ls_hdr-c10 ) )
                          ( condense( ls_hdr-c11 ) ) ( condense( ls_hdr-c12 ) )
                          ( condense( ls_hdr-c13 ) ) ( condense( ls_hdr-c14 ) ) ).
    DATA lv_idx TYPE i.
    LOOP AT lt_hdr_seq ASSIGNING FIELD-SYMBOL(<lv_title>).
      lv_idx = sy-tabix.
      IF <lv_title> IS NOT INITIAL.
        INSERT VALUE #( title = <lv_title> col = lv_idx ) INTO TABLE lt_colmap.
      ENDIF.
    ENDLOOP.

    " Validacion N1: columnas obligatorias presentes
    DATA lt_required TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_required = VALUE #( ( gc_title_contrato )
                           ( gc_title_material )
                           ( gc_title_tipo_op )
                           ( gc_title_monto ) ).
    LOOP AT lt_required ASSIGNING FIELD-SYMBOL(<lv_req>).
      READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = <lv_req>.
      IF sy-subrc <> 0.
        ev_ok     = abap_false.
        ev_reason = |Columna obligatoria faltante: { <lv_req> }|.
        CLEAR et_rows.
        RETURN.
      ENDIF.
    ENDLOOP.

    " Leer filas de datos (A2:J*)
    DATA(lo_data_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'N' )
      )->get_pattern( ).

    DATA lt_data TYPE STANDARD TABLE OF ty_row10 WITH EMPTY KEY.
    TRY.
        lo_sheet->select( lo_data_pattern
          )->row_stream(
          )->operation->write_to( REF #( lt_data )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudieron leer las filas de datos'.
        RETURN.
    ENDTRY.

    DATA(lv_col_contrato) = VALUE #( lt_colmap[ title = gc_title_contrato ]-col OPTIONAL ).
    DATA(lv_col_material) = VALUE #( lt_colmap[ title = gc_title_material ]-col OPTIONAL ).
    DATA(lv_col_tipo_op)  = VALUE #( lt_colmap[ title = gc_title_tipo_op ]-col OPTIONAL ).
    DATA(lv_col_monto)    = VALUE #( lt_colmap[ title = gc_title_monto ]-col OPTIONAL ).
    DATA(lv_col_delta)    = VALUE #( lt_colmap[ title = gc_title_delta    ]-col OPTIONAL ).
    DATA(lv_col_tipo_dev) = VALUE #( lt_colmap[ title = gc_title_tipo_dev ]-col OPTIONAL ).
    DATA(lv_col_recept)   = VALUE #( lt_colmap[ title = gc_title_recept   ]-col OPTIONAL ).
    " Mod 01.10.2026 EXT_AGFAGINA - defecto 109. Opcional: un archivo sin la
    " columna sigue siendo valido (la instancia se resuelve si hay una sola).
    DATA(lv_col_nro_act)  = VALUE #( lt_colmap[ title = gc_title_nro_act  ]-col OPTIONAL ).

    FIELD-SYMBOLS <lv_cell> TYPE string.
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      " Mod 29.09.2026 EXT_AGFAGINA - CR-002: fila real del Excel (los datos
      " empiezan en la fila 2). Se toma antes de saltear filas vacias.
      DATA(lv_xls_row) = sy-tabix + 1.
      IF <ls_data>-c1 IS INITIAL AND <ls_data>-c2 IS INITIAL
      AND <ls_data>-c3 IS INITIAL AND <ls_data>-c4 IS INITIAL
      AND <ls_data>-c5 IS INITIAL AND <ls_data>-c6 IS INITIAL
      AND <ls_data>-c7 IS INITIAL AND <ls_data>-c8 IS INITIAL
      AND <ls_data>-c9 IS INITIAL AND <ls_data>-c10 IS INITIAL
      AND <ls_data>-c11 IS INITIAL AND <ls_data>-c12 IS INITIAL
      AND <ls_data>-c13 IS INITIAL AND <ls_data>-c14 IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_out) = VALUE ty_raw_row( row_num = lv_xls_row ).

      IF lv_col_contrato > 0.
        ASSIGN COMPONENT lv_col_contrato OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0.
          " Mod 29.09.2026 EXT_AGFAGINA - DF-555: la celda puede traer codigo y
          " N. Contrato Externo ("IC-0008 - GITHUB ENTERPRSE"). Se toma el primer
          " bloque antes del espacio, que es el codigo. Un archivo con solo el
          " codigo resuelve igual. No se busca por numero externo a proposito:
          " no es unico y puede estar vacio.
          SPLIT condense( <lv_cell> ) AT space INTO DATA(lv_ct_tok) DATA(lv_ct_rest).
          ls_out-contrato = to_upper( lv_ct_tok ).
        ENDIF.
      ENDIF.
      IF lv_col_material > 0.
        ASSIGN COMPONENT lv_col_material OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-material = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_tipo_op > 0.
        ASSIGN COMPONENT lv_col_tipo_op OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-tipo_op = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_monto > 0.
        ASSIGN COMPONENT lv_col_monto OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-monto = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_delta > 0.
        ASSIGN COMPONENT lv_col_delta OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-delta = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_tipo_dev > 0.
        ASSIGN COMPONENT lv_col_tipo_dev OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-tipo_dev = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_recept > 0.
        ASSIGN COMPONENT lv_col_recept OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-receptoras = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_nro_act > 0.
        ASSIGN COMPONENT lv_col_nro_act OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-nro_act = condense( <lv_cell> ). ENDIF.
      ENDIF.

      APPEND ls_out TO et_rows.
    ENDLOOP.

  ENDMETHOD.


  METHOD export_template.
    " Genera template de 13 columnas. Con periodo: pre-carga combinaciones
    " Contrato x Material x Tipo Op. de contratos AC vigentes en el mes.
    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_cursor) = lo_sheet->cursor(
      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).

    lo_cursor->get_cell( )->value->write_from( 'Contrato' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Sociedad Prestadora' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Proveedor' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Descripción de Proveedor' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Material' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Descripción de Material' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Tipo Operación' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Descripción de Tipo Operación' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Número de Activación' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Monto' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Moneda' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Delta?' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Bonif' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Receptoras' ).

    IF iv_period_year IS INITIAL OR iv_period_month IS INITIAL.
      rv_file_content = lo_write->get_file_content( ).
      RETURN.
    ENDIF.

    " Vigencia: contrato activo en cualquier momento del mes del periodo.
    DATA(lv_first_day) = CONV d( |{ iv_period_year }{ iv_period_month }01| ).
    DATA(lv_last_day)  = CONV d( lv_first_day ).
    lv_last_day = lv_last_day + 31.
    lv_last_day = lv_last_day - ( lv_last_day+6(2) ).  " ultimo dia del mes del periodo

    " Mod 29.09.2026 EXT_AGFAGINA - DF-555: se trae el N. Contrato Externo.
    SELECT ct~ct_id, ct~ext_contract, ct~bukrs, ct~lifnr, ct~waers,
           mat~matnr, mat~mat_desc,
           opt~op_type, opt~op_type_descr,
           " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: una fila por instancia.
           opt~op_instance_num
      FROM zreing_ct2_a AS ct
      INNER JOIN zreing_ct2_mat_a AS mat
        ON mat~ct_uuid = ct~ct_uuid
      INNER JOIN zreing_ct2_opt_a AS opt
        ON  opt~ct_uuid  = mat~ct_uuid
        AND opt~mat_uuid = mat~mat_uuid
      WHERE ct~ct_status  = 'AC'
        AND ct~valid_from <= @lv_last_day
        AND ct~valid_to   >= @lv_first_day
        AND opt~op_type   <> @gc_optype_deveng   " el devengamiento se deriva de la activacion
      ORDER BY ct~ct_id, mat~matnr, opt~op_type, opt~op_instance_num
      INTO TABLE @DATA(lt_combos).

    IF lt_combos IS INITIAL.
      rv_file_content = lo_write->get_file_content( ).
      RETURN.
    ENDIF.

    " Nombres de proveedor (I_Supplier) en bloque, sin SELECT en loop.
    DATA lt_lifnr TYPE SORTED TABLE OF zreing_ct2_a-lifnr WITH UNIQUE KEY table_line.
    LOOP AT lt_combos ASSIGNING FIELD-SYMBOL(<ls_c>) WHERE lifnr IS NOT INITIAL.
      INSERT <ls_c>-lifnr INTO TABLE lt_lifnr.
    ENDLOOP.

    DATA lt_supplier TYPE SORTED TABLE OF i_supplier WITH NON-UNIQUE KEY supplier.
    IF lt_lifnr IS NOT INITIAL.
      SELECT supplier, suppliername
        FROM i_supplier
        FOR ALL ENTRIES IN @lt_lifnr
        WHERE supplier = @lt_lifnr-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_supplier.
    ENDIF.

    DATA lv_supp_name TYPE i_supplier-suppliername.
    LOOP AT lt_combos ASSIGNING <ls_c>.
      lo_cursor = lo_sheet->cursor(
        io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
        io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( CONV i( sy-tabix + 1 ) ) ).

      CLEAR lv_supp_name.
      READ TABLE lt_supplier ASSIGNING FIELD-SYMBOL(<ls_sup>)
        WITH KEY supplier = <ls_c>-lifnr.
      IF sy-subrc = 0.
        lv_supp_name = <ls_sup>-suppliername.
      ENDIF.

      " Begin Mod 29.09.2026 EXT_AGFAGINA - DF-555: codigo + N. Contrato Externo.
      " El pedido era reemplazar el codigo por el numero externo, pero el numero
      " externo NO identifica un contrato: en TS4 IC-0008 e IC-0017 tienen los dos
      " "GITHUB ENTERPRSE" (ambos activos), e IC-0003 / IC-0004 no tienen numero
      " externo. Con solo ese dato el import no sabria a que contrato cargar.
      " Se muestran los dos en la misma celda ("IC-0008 - GITHUB ENTERPRSE") y
      " read_rows toma el codigo del primer bloque. No se agrega una columna nueva
      " porque read_rows lee 14 columnas (A:N) y el template ya tiene 14: la
      " columna Receptoras quedaria fuera del rango y se perderia sin aviso.
      DATA(lv_ct_cell) = COND string(
        WHEN <ls_c>-ext_contract IS INITIAL
        THEN condense( CONV string( <ls_c>-ct_id ) )
        ELSE |{ condense( CONV string( <ls_c>-ct_id ) ) } - { condense( CONV string( <ls_c>-ext_contract ) ) }| ).
      lo_cursor->get_cell( )->value->write_from( lv_ct_cell ).
      " End Mod 29.09.2026 EXT_AGFAGINA
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-bukrs ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-lifnr ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( lv_supp_name ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-matnr ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-mat_desc ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-op_type ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-op_type_descr ) ).
      " Mod 01.10.2026 EXT_AGFAGINA - defecto 109: "Número de Activación" (antes vacia).
      " Se escribe como numero, sin ceros a la izquierda: 2 y no 002.
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV i( <ls_c>-op_instance_num ) ).
      " Begin Mod 08.09.2026 EXT_AGFAGINA - Monto se escribe NUMERICO, no como texto.
      " Antes la celda se generaba con write_from( '' ), o sea un string vacio: Excel
      " la marcaba como celda de TEXTO y el numero que despues escribia el usuario
      " quedaba como texto, con los problemas de formato consiguientes.
      " Escribiendo un 0 numerico la celda queda tipada como numero y lo conserva
      " cuando el usuario reemplaza el valor.
      " El 0 no genera registros: import_file ignora las lineas con monto 0 o vacio
      " y lo informa como aviso, asi que sirve tambien de recordatorio de completarlo.
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV decfloat34( 0 ) ).
      " End Mod 08.09.2026 EXT_AGFAGINA
      lo_cursor->move_right( )->get_cell( )->value->write_from( CONV string( <ls_c>-waers ) ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( '' ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( '' ).
      lo_cursor->move_right( )->get_cell( )->value->write_from( '' ).
    ENDLOOP.

    rv_file_content = lo_write->get_file_content( ).
  ENDMETHOD.


  METHOD parse_receptoras.
    CHECK iv_text IS NOT INITIAL.
    SPLIT iv_text AT ',' INTO TABLE DATA(lt_raw).
    LOOP AT lt_raw INTO DATA(lv_raw).
      DATA(lv_b) = condense( lv_raw ).
      IF lv_b IS NOT INITIAL.
        APPEND CONV zreing_cm_recv_a-bukrs_recv( |{ lv_b ALPHA = IN }| ) TO rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
