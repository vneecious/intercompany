*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Motor orquestador *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Motor orquestador de CONTAB (ET-REING-CONTAB-001 v39 SS7).
* Punto de entrada: process_line( is_line_a, it_line_pc, it_step_a, iv_mode )
* Ejecuta el flujo completo (DOCFLOW_C) para UN LINE_A y devuelve
* ty_process_result con los documentos generados y el status global.
*
* Desviaciones ET->real codificadas aqui (ver GUIA-DISENO-F4-CONTAB):
*   - D-1: validate_preconditions acepta los estados REALES de CA
*          (C->SIM_PROC, P->POST_PROC, S->ANUL_PROC), no CONT_PROC/REV_PROC.
*   - Tabla de flujo real: ZREING_DOCFLOW_C (no zreing_doc_flow_c de la ET).
*   - Persistencia en ZREING_CB_DOC_A / _ITEM_A / _TRC_A (naming D-6).
*
* Diseno anti-ATC (regla "no DB en loop across modularization units"):
*   - Las clases procesadoras (DOCTYPE_C.PROCESSING_CLASS) se PRECARGAN de
*     una sola vez (preload_processor_classes) en un diccionario en memoria
*     antes del loop; instantiate_processor lee de memoria, sin SELECT.
*   - La persistencia se BUFFERiza durante el loop (build_* -> tablas
*     internas) y se vuelca con INSERT masivo unico al final (persist_all).
*   Ambas cosas eliminan las operaciones DB dentro del LOOP y ademas son
*   mas eficientes. Semanticamente equivalente a "persistir por paso" (ET
*   SS7.6): en contexto RAP el COMMIT lo gestiona el save sequence, no hay
*   commit por paso, y el resultado in-memory esta completo antes del volcado.
*
* Dependencia pendiente (Bloque C): la clase procesadora ZCL_REING_CONTAB_DOC
* y subclases _INT/_RECL todavia no existen. Se crean dinamicamente por
* nombre, asi que este Engine compila y activa sin ellas; en ejecucion
* fallara de forma controlada (ZCX_REING_CONTAB) hasta que existan.
*----------------------------------------------------------------------*
CLASS zcl_reing_contab_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " V001 (CC) - GAP-001 (Delta v2): bulk FI check, pure classification.
    TYPES tt_reversal_docs TYPE STANDARD TABLE OF zreing_cb_doc_a WITH EMPTY KEY.
    TYPES: BEGIN OF ty_journal,
             companycode                TYPE bukrs,
             accountingdocument         TYPE belnr_d,
             fiscalyear                 TYPE gjahr,
             isreversed                 TYPE abap_bool,
             reversedocument            TYPE belnr_d,
             reversedocumentfiscalyear  TYPE gjahr,
           END OF ty_journal,
           tt_journal TYPE STANDARD TABLE OF ty_journal WITH EMPTY KEY.
    TYPES: BEGIN OF ty_reversal_check,
             calc_run_id TYPE zreing_calc_run_id,
             line_num    TYPE zreing_line_num,
             state       TYPE c LENGTH 1,
             message     TYPE string,
           END OF ty_reversal_check,
           tt_reversal_check TYPE STANDARD TABLE OF ty_reversal_check WITH EMPTY KEY.
    " N=no local FI, R=all reversed, P=pending FI, E=inconsistent/unreadable.
    CLASS-METHODS precheck_reversal
      IMPORTING it_lines TYPE zif_reing_ca_types=>ty_line_t
      RETURNING VALUE(rt_check) TYPE tt_reversal_check.
    CLASS-METHODS classify_reversal
      IMPORTING it_lines   TYPE zif_reing_ca_types=>ty_line_t
                it_docs    TYPE tt_reversal_docs
                it_journal TYPE tt_journal
      EXPORTING et_check   TYPE tt_reversal_check
                et_sync    TYPE tt_reversal_docs.

    "! Inyecta el poster FI que se propagara a cada procesadora creada.
    "! El Engine (Cloud) NO instancia el poster Tier2; lo recibe desde afuera
    "! (adapter del Bloque E, o un mock en unit tests) y lo pasa a cada
    "! procesadora tras crearla. Si no se inyecta, las procesadoras devuelven
    "! el error controlado "Poster FI no inyectado" en modo P/S.
    METHODS set_fi_poster
      IMPORTING
        io_poster TYPE REF TO zif_reing_contab_fi_poster.

    METHODS process_line
      IMPORTING
        is_line_a        TYPE zreing_ca_line_a
        it_line_pc       TYPE zif_reing_ca_types=>ty_line_pc_t
        it_step_a        TYPE zif_reing_ca_types=>ty_step_t
        iv_mode          TYPE zreing_ca_contab_mode
      RETURNING
        VALUE(rs_result) TYPE zif_reing_contab_types=>ty_process_result
      RAISING
        zcx_reing_contab.

    " Begin Insert V003 (08.09.2026 | EXT_GONZALCA)
    "! Precarga TODA la configuracion que el Engine necesita, de una sola vez
    "! y con lecturas masivas. Debe invocarse UNA vez por accion, ANTES del
    "! "LOOP AT keys" de simulate/post/storno.
    "!
    "! Motivo (blocker ATC, 08.09.2026): el Engine se instancia POR LINEA
    "! dentro del LOOP de run_contab_mode, y cada instancia hacia sus propias
    "! lecturas (DOCFLOW_C, DOCTYPE_C, OP_TYPE_C, CB_DOC_A) y sus propios
    "! INSERT. El check "Search DB Operations in loops across modularization
    "! units" lo marcaba con 28 errores de prioridad 1 que impedian liberar la
    "! orden de transporte. Mismo patron ya usado en el proyecto por
    "! ZCL_REING_CA_OPTYPE_FACTORY=>WARM_CACHE, que ZCL_REING_CA_PIPELINE
    "! invoca antes de su propio LOOP AT it_scope.
    "!
    "! Se resolvio con estado ESTATICO en vez de parametros para no alterar la
    "! firma de run_contab_mode ni de prefetch_contab_data: ambas viven en la
    "! definicion de la clase local LHC_ZI_REINGCARUN y las invocan
    "! directamente los 7 tests de LTCL_CONTAB_ACTIONS.
    "!
    "! @parameter it_lines | Lineas del scope completo de la accion; de aca se
    "!                       derivan los OP_TYPE distintos y los pares
    "!                       (calc_run_id, line_num) para los documentos
    "!                       originales del modo Storno.
    CLASS-METHODS warm_config
      IMPORTING
        it_lines TYPE zif_reing_ca_types=>ty_line_t.

    "! Vuelca a BD los documentos/posiciones/traces acumulados por TODAS las
    "! lineas procesadas, con un INSERT masivo por tabla. Debe invocarse UNA
    "! vez por accion, DESPUES del "LOOP AT keys" -- dentro del loop, el
    "! INSERT volveria a quedar anidado y el finding ATC reaparece.
    CLASS-METHODS flush_documents
      RAISING
        zcx_reing_contab.
    " End Insert V003 (08.09.2026 | EXT_GONZALCA)

  PRIVATE SECTION.
    " V001 (CC) - CB-01: precision is shared; projections are local per line.
    CLASS-DATA gt_trans_currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    CLASS-DATA gv_test_eba_off TYPE abap_bool.
    " V001 (CC) - Action snapshot shared by precision preload and line instances.
    CLASS-DATA gv_eba_off TYPE abap_bool VALUE abap_true.
    DATA mv_eba_off TYPE abap_bool VALUE abap_true.
    CLASS-METHODS warm_trans_precision
      IMPORTING it_lines TYPE zif_reing_ca_types=>ty_line_t.
    METHODS project_trans_context
      IMPORTING is_line TYPE zreing_ca_line_a
                it_pcs TYPE zif_reing_ca_types=>ty_line_pc_t
                it_steps TYPE zif_reing_ca_types=>ty_step_t
                iv_mode TYPE zreing_ca_contab_mode
      RETURNING VALUE(rs_projection) TYPE zif_reing_ca_types=>ty_trans_projection
      RAISING zcx_reing_contab.
    CLASS-METHODS reject_trans_context
      IMPORTING iv_number TYPE symsgno iv_line TYPE zreing_line_num
      RAISING zcx_reing_contab.
    " Diccionario doc_type_code -> processing_class (precargado, sin SELECT en loop).
    TYPES: BEGIN OF ty_class_map,
             doc_type_code    TYPE zreing_doc_type_code,
             processing_class TYPE zreing_processing_class,
           END OF ty_class_map.
    TYPES ty_class_map_t TYPE HASHED TABLE OF ty_class_map
            WITH UNIQUE KEY doc_type_code.

    " Begin Insert V003 (08.09.2026 | EXT_GONZALCA)
    " Configuracion precargada por warm_config -- ESTATICA y compartida por
    " todas las instancias del Engine de una misma accion (se crea una por
    " linea, ver run_contab_mode). Los metodos de lectura de abajo filtran
    " estas tablas en memoria: NINGUNO vuelve a tocar la base.
    " NO agregar un fallback "si esta vacia, hacer SELECT": eso reintroduce
    " exactamente el finding ATC que este cambio elimina. Si falta la
    " configuracion, load_flow_config ya falla con un mensaje explicito.
    " V001 (CC) - bug107 CONTAB: one bulk lookup outside line and step loops.
    CLASS-DATA gt_contract_kostl TYPE zif_reing_contab_types=>tt_contract_kostl.
    " V001 (CC) - #122: exact header identity for every document format.
    CLASS-DATA gt_contract_text TYPE zif_reing_contab_types=>tt_contract_text.
    " V001 (CC) - #121: scope-limited mapping cache, never read inside processing loops.
    CLASS-DATA gt_campana_map TYPE zif_reing_contab_types=>tt_campana_map.
    CLASS-DATA gt_flow_all      TYPE zif_reing_contab_types=>ty_flow_t.
    CLASS-DATA gt_doctype_all   TYPE STANDARD TABLE OF zreing_doctype_c WITH EMPTY KEY.
    CLASS-DATA gt_optype_all    TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    CLASS-DATA gt_orig_docs_all TYPE STANDARD TABLE OF zreing_cb_doc_a  WITH EMPTY KEY.

    " Acumuladores de persistencia de TODA la accion. persist_all (por linea)
    " vuelca aca sus buffers de instancia, y flush_documents (una vez, fuera
    " del LOOP AT keys) los escribe a BD.
    CLASS-DATA gt_doc_pending   TYPE STANDARD TABLE OF zreing_cb_doc_a  WITH EMPTY KEY.
    CLASS-DATA gt_item_pending  TYPE STANDARD TABLE OF zreing_cb_item_a WITH EMPTY KEY.
    CLASS-DATA gt_trace_pending TYPE STANDARD TABLE OF zreing_cb_trc_a  WITH EMPTY KEY.
    " End Insert V003 (08.09.2026 | EXT_GONZALCA)

    " Contexto de la linea en curso (seteado al inicio de process_line).
    DATA ms_line_a  TYPE zreing_ca_line_a.
    DATA mt_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_step_a  TYPE zif_reing_ca_types=>ty_step_t.
    DATA mv_mode    TYPE zreing_ca_contab_mode.

    " Poster FI inyectado (set_fi_poster), propagado a cada procesadora.
    DATA mo_fi_poster TYPE REF TO zif_reing_contab_fi_poster.

    " Diccionario de clases procesadoras precargado.
    DATA mt_class_map TYPE ty_class_map_t.

    " Buffers de persistencia de LA LINEA en curso (process_line los limpia en
    " cada llamada). persist_all los traslada a los acumuladores estaticos.
    DATA mt_doc_buffer  TYPE STANDARD TABLE OF zreing_cb_doc_a  WITH EMPTY KEY.
    DATA mt_item_buffer TYPE STANDARD TABLE OF zreing_cb_item_a WITH EMPTY KEY.
    DATA mt_traces      TYPE zif_reing_contab_types=>ty_trace_t.

    "! Lee y ordena los pasos activos de DOCFLOW_C para el OP_TYPE.
    "! V003: filtra GT_FLOW_ALL en memoria; ya no accede a BD.
    "! @parameter iv_reverse | abap_true en modo Storno -> orden inverso
    METHODS load_flow_config
      IMPORTING
        iv_op_type     TYPE zreing_op_type
        iv_reverse     TYPE abap_bool
      RETURNING
        VALUE(rt_flow) TYPE zif_reing_contab_types=>ty_flow_t
      RAISING
        zcx_reing_contab.

    "! Arma el diccionario processing_class de los DOC_TYPE_CODE del flujo y
    "! valida su integridad. V003: filtra GT_DOCTYPE_ALL; ya no accede a BD.
    METHODS preload_processor_classes
      IMPORTING
        it_flow TYPE zif_reing_contab_types=>ty_flow_t
      RAISING
        zcx_reing_contab.

    "! Instancia dinamica de la clase procesadora (lee del diccionario
    "! precargado; NO accede a BD).
    METHODS instantiate_processor
      IMPORTING
        is_flow_step   TYPE zreing_docflow_c
      RETURNING
        VALUE(ro_proc) TYPE REF TO zif_reing_contab
      RAISING
        zcx_reing_contab.

    "! Gatekeeping: valida LINE_STATUS vs modo (D-1, estados reales de CA).
    METHODS validate_preconditions
      IMPORTING
        is_line_a TYPE zreing_ca_line_a
        iv_mode   TYPE zreing_ca_contab_mode
      RAISING
        zcx_reing_contab.

    "! Guard modo Storno: rechaza OP_TYPE con AUTO_REVERSAL (ET SS7.6.2).
    "! V003: lee GT_OPTYPE_ALL en memoria; ya no accede a BD.
    METHODS check_auto_reversal_guard
      IMPORTING
        is_line_a TYPE zreing_ca_line_a
      RAISING
        zcx_reing_contab.

    "! Agrega al buffer la cabecera + items de un paso exitoso (sin BD).
    METHODS buffer_document
      IMPORTING
        is_line_a     TYPE zreing_ca_line_a
        is_doc_result TYPE zif_reing_contab_types=>ty_step_result.

    "! V003: ya NO escribe a BD. Traslada los buffers de la linea a los
    "! acumuladores estaticos; el INSERT lo hace flush_documents.
    METHODS persist_all
      IMPORTING
        is_line_a TYPE zreing_ca_line_a
      RAISING
        zcx_reing_contab.

    "! Registra un evento en el buffer de traces (sin BD).
    METHODS add_trace
      IMPORTING
        iv_type  TYPE csequence
        iv_msg   TYPE csequence OPTIONAL
        iv_belnr TYPE belnr_d OPTIONAL
        iv_dtc   TYPE zreing_doc_type_code OPTIONAL.

    "! Modo Storno: documentos originales posteados (status OK) del LINE_A,
    "! que se inyectan a las procesadoras para que reverse_step encuentre el
    "! belnr/bukrs/gjahr a revertir.
    "! V003: filtra GT_ORIG_DOCS_ALL en memoria; ya no accede a BD.
    METHODS load_original_docs
      IMPORTING
        is_line_a          TYPE zreing_ca_line_a
      RETURNING
        VALUE(rt_orig)     TYPE zif_reing_contab_types=>ty_step_result_t.

ENDCLASS.


CLASS zcl_reing_contab_engine IMPLEMENTATION.


  METHOD precheck_reversal.
    CHECK it_lines IS NOT INITIAL.
    DATA lt_docs TYPE tt_reversal_docs.
    DATA lt_journal TYPE tt_journal.
    DATA lt_run_rng TYPE RANGE OF zreing_calc_run_id.
    DATA lt_line_rng TYPE RANGE OF zreing_line_num.
    lt_run_rng = VALUE #( FOR ls_r IN it_lines
      ( sign = 'I' option = 'EQ' low = ls_r-calc_run_id ) ).
    lt_line_rng = VALUE #( FOR ls_n IN it_lines
      ( sign = 'I' option = 'EQ' low = ls_n-line_num ) ).
    " PAYLOAD is STRING: no FAE projection of full headers. Exact pair below.
    TRY.
    SELECT * FROM zreing_cb_doc_a
      WHERE calc_run_id IN @lt_run_rng AND line_num IN @lt_line_rng
        AND ( status = 'OK' OR status = 'RV' )
        AND simulated = @abap_false AND belnr <> @space
      INTO TABLE @lt_docs.
    IF lt_docs IS NOT INITIAL.
      " V001 (CC) - GAP-001: full FI-key join, avoid chained SELECT/FAE.
      SELECT DISTINCT JE~CompanyCode, JE~AccountingDocument, JE~FiscalYear,
             JE~IsReversed, JE~ReverseDocument, JE~ReverseDocumentFiscalYear
        FROM I_JournalEntry AS JE
        INNER JOIN zreing_cb_doc_a AS D
          ON JE~CompanyCode = D~bukrs AND JE~AccountingDocument = D~belnr
         AND JE~FiscalYear = D~gjahr
        WHERE D~calc_run_id IN @lt_run_rng AND D~line_num IN @lt_line_rng
          AND ( D~status = 'OK' OR D~status = 'RV' )
          AND D~simulated = @abap_false AND D~belnr <> @space
        INTO CORRESPONDING FIELDS OF TABLE @lt_journal.
    ENDIF.
      CATCH cx_root INTO DATA(lx_fi_read).
        rt_check = VALUE #( FOR ls_failed_read IN it_lines
          ( calc_run_id = ls_failed_read-calc_run_id line_num = ls_failed_read-line_num
            state = 'E' message = |No se pudo verificar FI: { lx_fi_read->get_text( ) }| ) ).
        RETURN.
    ENDTRY.
    classify_reversal(
      EXPORTING it_lines = it_lines it_docs = lt_docs it_journal = lt_journal
      IMPORTING et_check = rt_check et_sync = DATA(lt_sync) ).
    LOOP AT lt_sync INTO DATA(ls_sync).
      READ TABLE gt_doc_pending ASSIGNING FIELD-SYMBOL(<ls_pending>)
        WITH KEY calc_run_id = ls_sync-calc_run_id line_num = ls_sync-line_num
                 doc_type_code = ls_sync-doc_type_code.
      IF sy-subrc = 0.
        <ls_pending> = ls_sync.
      ELSE.
        APPEND ls_sync TO gt_doc_pending.
      ENDIF.
      DELETE gt_orig_docs_all WHERE calc_run_id = ls_sync-calc_run_id
        AND line_num = ls_sync-line_num AND doc_type_code = ls_sync-doc_type_code.
      " V001 (CC) - GAP-001: retain every external reversal fiscal-year link.
      READ TABLE lt_journal INTO DATA(ls_synced_fi)
        WITH KEY companycode = ls_sync-bukrs accountingdocument = ls_sync-belnr
                 fiscalyear = ls_sync-gjahr.
      IF sy-subrc = 0.
        APPEND VALUE #( calc_run_id = ls_sync-calc_run_id line_num = ls_sync-line_num
          trace_typ = 'EXT_REV' doc_type_code = ls_sync-doc_type_code contab_mode = 'S'
          belnr = ls_sync-belnr created_by = sy-uname
          created_at = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
          message = |Reversa FI externa: { ls_sync-bukrs }/{ ls_sync-belnr }/{ ls_sync-gjahr } -> |
            && |{ ls_synced_fi-reversedocument }/{ ls_synced_fi-reversedocumentfiscalyear }| )
          TO gt_trace_pending.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD classify_reversal.
    CLEAR: et_check, et_sync.
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(ls_check) = VALUE ty_reversal_check(
        calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num state = 'N' ).
      DATA(lt_docs_line) = VALUE tt_reversal_docs( FOR ls_d IN it_docs
        WHERE ( calc_run_id = ls_line-calc_run_id AND line_num = ls_line-line_num
                AND simulated = abap_false AND belnr IS NOT INITIAL
                AND ( status = 'OK' OR status = 'RV' ) )
        ( ls_d ) ).
      DATA lv_pending TYPE i.
      CLEAR lv_pending.
      IF lt_docs_line IS INITIAL AND ls_line-fi_awkey IS NOT INITIAL.
        ls_check-state = 'E'.
        ls_check-message = 'Referencia FI sin cabecera local: verificar documentos antes de anular'.
      ENDIF.
      DATA lv_index TYPE i.
      lv_index = 1.
      DO lines( lt_docs_line ) TIMES.
        READ TABLE lt_docs_line INTO DATA(ls_doc) INDEX lv_index.
        lv_index = lv_index + 1.
        IF ls_doc-status <> 'OK' AND ls_doc-status <> 'RV'.
          CONTINUE.
        ENDIF.
        READ TABLE it_journal INTO DATA(ls_journal)
          WITH KEY companycode = ls_doc-bukrs accountingdocument = ls_doc-belnr
                   fiscalyear = ls_doc-gjahr.
        IF sy-subrc <> 0.
          ls_check-state = 'E'.
          ls_check-message = |No se pudo verificar FI { ls_doc-bukrs }/{ ls_doc-belnr }/{ ls_doc-gjahr }|.
          CONTINUE.
        ENDIF.
        IF ls_journal-isreversed = abap_true.
          IF ls_journal-reversedocument IS INITIAL
             OR ls_journal-reversedocumentfiscalyear IS INITIAL.
            ls_check-state = 'E'.
            ls_check-message = |FI revertido sin clave de reversa { ls_doc-bukrs }/{ ls_doc-belnr }/{ ls_doc-gjahr }|.
            CONTINUE.
          ENDIF.
          IF ls_doc-status <> 'RV' OR ls_doc-reverse_belnr <> ls_journal-reversedocument.
            " Full original header, including money, payload and original fiscal year.
            ls_doc-status = 'RV'.
            ls_doc-reverse_belnr = ls_journal-reversedocument.
            APPEND ls_doc TO et_sync.
            IF ls_check-state <> 'E'.
              ls_check-message = |Reversa FI externa sincronizada: { ls_doc-bukrs }/|
                && |{ ls_doc-belnr }/{ ls_doc-gjahr } -> { ls_journal-reversedocument }/|
                && |{ ls_journal-reversedocumentfiscalyear }|.
            ENDIF.
          ENDIF.
        ELSEIF ls_doc-status = 'RV'.
          ls_check-state = 'E'.
          ls_check-message = |Cabecera RV sin reversa efectiva en FI: { ls_doc-bukrs }/{ ls_doc-belnr }/{ ls_doc-gjahr }|.
        ELSE.
          lv_pending = lv_pending + 1.
        ENDIF.
      ENDDO.
      IF ls_check-state <> 'E' AND lt_docs_line IS NOT INITIAL.
        ls_check-state = COND #( WHEN lv_pending = 0 THEN 'R' ELSE 'P' ).
      ENDIF.
      APPEND ls_check TO et_check.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_fi_poster.
    mo_fi_poster = io_poster.
  ENDMETHOD.


  METHOD process_line.
    " V001 (CC) - Never re-read the bypass in a line or document loop.
    mv_eba_off = gv_eba_off.
    " --- Guardar contexto y limpiar buffers ---
    ms_line_a  = is_line_a.
    mt_line_pc = it_line_pc.
    mt_step_a  = it_step_a.
    mv_mode    = iv_mode.
    CLEAR: mt_traces, mt_doc_buffer, mt_item_buffer, mt_class_map.

    rs_result = VALUE #(
      calc_run_id = is_line_a-calc_run_id
      line_num    = is_line_a-line_num
      op_type     = is_line_a-op_type
      mode        = iv_mode ).

    " --- Paso 2: validar pre-condiciones (gatekeeping, D-1) ---
    validate_preconditions( is_line_a = is_line_a
                            iv_mode   = iv_mode ).

    " --- Guard modo Storno (AUTO_REVERSAL, ET SS7.6.2) ---
    IF iv_mode = 'S'.
      check_auto_reversal_guard( is_line_a ).
    ENDIF.

    " --- Paso 1: cargar flujo (invertido si Storno) ---
    DATA(lt_flow) = load_flow_config(
      iv_op_type = is_line_a-op_type
      iv_reverse = COND #( WHEN iv_mode = 'S' THEN abap_true
                           ELSE abap_false ) ).

    " Begin Insert V006 (09.09.2026 | EXT_GONZALCA)
    " Guard H-3, movido aca desde flush_documents. Un flujo que repite un
    " DOC_TYPE_CODE pide dos filas con la misma clave de ZREING_CB_DOC_A
    " (calc_run_id + line_num + doc_type_code), que la PK no puede sostener.
    " TIENE que detectarse ANTES del loop de pasos: a partir de ahi las
    " procesadoras registran los CALL FUNCTION IN UPDATE TASK del posteo FI, y
    " fallar despues dejaria documentos FI reales posteados sin ninguna fila en
    " CB_DOC_A -- una inconsistencia contable silenciosa, peor que el dump que
    " este fix elimina.
    " Se rechaza la LINEA, no el lote: la excepcion la captura run_contab_mode
    " POR LINEA, asi que el resto del scope se sigue procesando. Esa es ademas
    " la unica via por la que el motivo llega al operador -- run_contab_mode
    " arma su mensaje con los CONTADORES de documentos y NO lee
    " rs_result-error_msg.
    " OJO: al lanzar aca no se ejecuta persist_all, asi que este rechazo NO
    " queda registrado en TRC_A. El mensaje si llega a la UI, a
    " LINE_A-SIM_MESSAGE y a LOG_A por el CATCH de run_contab_mode, que es lo
    " que importa para el operador; la traza se sacrifica a proposito para no
    " escribir nada en una linea que no se proceso.
    " Esto NO arregla ANT: ZREING_DOCFLOW_C tiene ANTIND15 en SEQ 030 y 040,
    " asi que ANT sigue sin poder contabilizar hasta que se decida la
    " contradiccion de PK de la ET SS4.4.3. Solo deja de dumpear y de arriesgar
    " posteos sin registro.
    DATA lt_dtc      TYPE STANDARD TABLE OF zreing_doc_type_code WITH EMPTY KEY.
    DATA lv_prev_dtc TYPE zreing_doc_type_code.
    DATA lv_dup_dtc  TYPE zreing_doc_type_code.
    lt_dtc = VALUE #( FOR ls_f IN lt_flow ( ls_f-doc_type_code ) ).
    SORT lt_dtc BY table_line.
    LOOP AT lt_dtc INTO DATA(lv_dtc).
      IF lv_dtc = lv_prev_dtc.
        lv_dup_dtc = lv_dtc.
        EXIT.
      ENDIF.
      lv_prev_dtc = lv_dtc.
    ENDLOOP.

    IF lv_dup_dtc IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |Flujo de OP_TYPE { is_line_a-op_type } invalido: | &&
                       |DOC_TYPE_CODE { lv_dup_dtc } aparece en mas de un paso. | &&
                       |La PK de ZREING_CB_DOC_A no admite dos documentos del mismo | &&
                       |tipo en una linea (H-3, ET SS4.4.3). Corregir ZREING_DOCFLOW_C|.
    ENDIF.
    " End Insert V006 (09.09.2026 | EXT_GONZALCA)

    " --- Precarga de clases procesadoras (un solo SELECT, fuera del loop) ---
    preload_processor_classes( lt_flow ).

    " --- Modo S: precargar documentos originales de BD (un solo SELECT,
    "     fuera del loop) para inyectarlos a las procesadoras. En C/P queda
    "     vacio (los prior docs son los generados en el run, en memoria). ---
    DATA lt_orig_docs TYPE zif_reing_contab_types=>ty_step_result_t.
    IF iv_mode = 'S'.
      lt_orig_docs = load_original_docs( is_line_a ).
    ENDIF.

    " V001 (CC) - fixes-058: a posted non-zero line must have a FI original.
    " Zero-balance lines legitimately have no document to reverse.
    IF iv_mode = 'S' AND lt_orig_docs IS INITIAL.
      DATA(lv_has_amount) = xsdbool( is_line_a-bruto_amt <> 0 ).
      IF lv_has_amount = abap_false.
        LOOP AT it_line_pc TRANSPORTING NO FIELDS WHERE bruto_amt <> 0.
          lv_has_amount = abap_true.
          EXIT.
        ENDLOOP.
      ENDIF.
      IF lv_has_amount = abap_true.
        RAISE EXCEPTION TYPE zcx_reing_contab
          EXPORTING
            iv_message = |Storno sin documentos FI originales para |
                      && |{ is_line_a-calc_run_id }/{ is_line_a-line_num }|.
      ENDIF.
    ENDIF.

    " V001 (CC) - CB-01: fail before the first poster, never reproject Storno.
    DATA(ls_trans_projection) = project_trans_context(
      is_line = is_line_a it_pcs = it_line_pc it_steps = it_step_a iv_mode = iv_mode ).

    " V001 (CC) - bug107 CONTAB: scalar context from the exact cached UUID pair.
    DATA(lv_contract_kostl) = VALUE kostl( gt_contract_kostl[
      ct_uuid = is_line_a-ct_uuid mat_uuid = is_line_a-mat_uuid ]-kostl OPTIONAL ).

    " V001 (CC) - #121: one exact cached identity supplies both contract fields.
    DATA(lv_contract_prctr) = VALUE prctr( gt_contract_kostl[
      ct_uuid = is_line_a-ct_uuid mat_uuid = is_line_a-mat_uuid ]-prctr OPTIONAL ).

    " V001 (CC) - #122: use the scoped contract header, never CT_ID/material.
    DATA(lv_contract_ext) = VALUE zreing_ct_ext_num( gt_contract_text[
      ct_uuid = is_line_a-ct_uuid ]-ext_contract OPTIONAL ).

    " --- Paso 3: iterar pasos del flujo (sin BD adentro) ---
    LOOP AT lt_flow INTO DATA(ls_step).

      " 3a/3b. Instanciar procesadora (desde diccionario precargado).
      DATA(lo_proc) = instantiate_processor( is_flow_step = ls_step ).

      " Begin Insert V008 (21.09.2026 | EXT_GONZALCA)
      " Intra-company lines keep their accounting line but generate only the
      " processor configured for interdivisional documents. Without this
      " mutually exclusive routing, AR/AP ran first and failed while resolving
      " an intercompany partner for a company against itself, so INT was never
      " reached. The processor class remains configuration-driven: this guard
      " recognizes the existing INT subclass and does not hardcode OP_TYPE or
      " DOC_TYPE_CODE. It applies to Check, Post and Storno consistently.
      IF is_line_a-bukrs_prest = is_line_a-bukrs_recv
         AND lo_proc IS NOT INSTANCE OF zcl_reing_contab_doc_int.
        add_trace( iv_type = 'STEP_SKIP'
                   iv_dtc  = ls_step-doc_type_code ).
        CONTINUE.
      ENDIF.
      " End Insert V008 (21.09.2026 | EXT_GONZALCA)

      " 3c. Contexto del paso.
      lo_proc->set_context(
        is_line_a    = is_line_a
        it_line_pc   = it_line_pc
        it_step_a    = it_step_a
        is_flow_step = ls_step
        is_trans_projection = ls_trans_projection
        it_currencies = gt_trans_currencies
        iv_contract_kostl = lv_contract_kostl
        it_campana_map = gt_campana_map
        iv_contract_prctr = lv_contract_prctr
        iv_contract_ext = lv_contract_ext
        iv_eba_off = COND #( WHEN iv_mode = zif_reing_ca_c=>contab_mode-storno
                            THEN abap_true ELSE mv_eba_off ) ).

      " 3c-bis. Documentos disponibles del run inyectados a la procesadora.
      "  - Modo S: documentos ORIGINALES de BD (para revertir).
      "  - Modo C/P: documentos ya generados en el run, en memoria (para _RECL).
      " Un unico origen segun modo; nunca hay DB dentro del loop (ambos se
      " precargaron antes: lt_orig_docs de BD, rs_result-documents en memoria).
      lo_proc->set_prior_documents(
        COND #( WHEN iv_mode = 'S' THEN lt_orig_docs
                ELSE rs_result-documents ) ).

      " 3d. In Storno, reverse only FI documents actually posted for this step.
      " Creation applicability needs prior items, which are absent in Storno.
      " Missing steps were skipped during Post or belong to a partial Post.
      IF iv_mode = 'S'.
        IF NOT line_exists( lt_orig_docs[
                              doc_type_code = ls_step-doc_type_code ] ).
          add_trace( iv_type = 'STEP_SKIP'
                     iv_dtc  = ls_step-doc_type_code ).
          CONTINUE.
        ENDIF.
      ELSEIF lo_proc->is_applicable( ) = abap_false.
        add_trace( iv_type = 'STEP_SKIP'
                   iv_dtc  = ls_step-doc_type_code ).
        CONTINUE.
      ENDIF.

      " Begin Insert V006 (09.09.2026 | EXT_GONZALCA)
      " Modo S: buffer_document reconstruye la cabecera desde la fila original
      " de GT_ORIG_DOCS_ALL, y ese metodo no puede propagar un error (no
      " declara RAISING y ampliar su firma tocaria la definicion de la clase),
      " asi que la puerta esta aca.
      " Se valida ANTES de execute( ) por robustez, no porque hoy haga falta:
      " en modo S execute( ) delega en reverse_step, que llama al poster FI
      " (BAPI_ACC_DOCUMENT_REV_POST en update task) pero SOLO si encuentra el
      " documento original en mt_prior_docs -- sin original hace RETURN antes
      " de tocar el poster, o sea que el caso detectado aca no postea nada.
      " Validar antes evita que esa seguridad dependa del early-return interno
      " de otra clase, que puede cambiar sin que nadie mire este metodo.
      " Sin este control reverse_step devuelve has_error = abap_false con belnr
      " vacio, y la linea se reportaria OK sin haber anulado ni escrito nada.
      " No se agrega documento a rs_result: no se genero ninguno.
      IF iv_mode = 'S'
     AND NOT line_exists( gt_orig_docs_all[ calc_run_id   = is_line_a-calc_run_id
                                            line_num      = is_line_a-line_num
                                            doc_type_code = ls_step-doc_type_code ] ).
        add_trace( iv_type = 'STEP_ERR'
                   iv_dtc  = ls_step-doc_type_code
                   iv_msg  = |Storno sin documento original en ZREING_CB_DOC_A| ).
        rs_result-has_error = abap_true.
        rs_result-error_msg = |Storno de { ls_step-doc_type_code }: no hay documento | &&
                              |original persistido en ZREING_CB_DOC_A|.
        EXIT.
      ENDIF.
      " End Insert V006 (09.09.2026 | EXT_GONZALCA)

      " 3e. Ejecutar segun modo.
      DATA(ls_doc_result) = lo_proc->execute( iv_mode = iv_mode ).

      " 3f. Error -> marcar y salir del loop (persistencia unica tras el loop).
      IF ls_doc_result-has_error = abap_true.
        add_trace( iv_type = 'STEP_ERR'
                   iv_msg  = ls_doc_result-error_msg
                   iv_dtc  = ls_step-doc_type_code ).
        rs_result-has_error = abap_true.
        rs_result-error_msg = ls_doc_result-error_msg.
        APPEND ls_doc_result TO rs_result-documents.
        EXIT.
      ENDIF.

      " 3g. Exito -> bufferizar + trace + acumular resultado.
      buffer_document( is_line_a     = is_line_a
                       is_doc_result = ls_doc_result ).
      add_trace( iv_type  = 'STEP_OK'
                 iv_belnr = ls_doc_result-belnr
                 iv_dtc   = ls_step-doc_type_code ).
      APPEND ls_doc_result TO rs_result-documents.

    ENDLOOP.

    " --- Paso 4: volcar buffers a BD (INSERT masivo unico, fuera del loop).
    "     Se ejecuta siempre: tanto en flujo completo exitoso como en
    "     abort por error (persiste lo bufferizado hasta el paso fallido,
    "     que el storno podra revertir - ET SS7.6). ---
    " V001 (CC) - GAP-001: a changed flow must not silently abandon a FI original.
    IF iv_mode = 'S' AND rs_result-has_error = abap_false.
      LOOP AT lt_orig_docs INTO DATA(ls_required).
        IF NOT line_exists( rs_result-documents[
             doc_type_code = ls_required-doc_type_code has_error = abap_false ] ).
          rs_result-has_error = abap_true.
          rs_result-error_msg = |Documento FI pendiente fuera del flujo de reversa: { ls_required-doc_type_code }|.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
    persist_all( is_line_a ).
  ENDMETHOD.


  METHOD load_flow_config.
    " Begin Mod V003 (08.09.2026 | EXT_GONZALCA)
    " Filtra en memoria GT_FLOW_ALL (precargado por warm_config) en vez de
    " leer DOCFLOW_C. Ver la nota de warm_config: el SELECT que vivia aca se
    " ejecutaba una vez POR LINEA y era uno de los 28 errores ATC que
    " bloqueaban la liberacion de la orden.
    " Sentencia original conservada como referencia:
    "    SELECT * FROM zreing_docflow_c
    "      WHERE op_type = @iv_op_type AND active = 'X'
    "      INTO TABLE @rt_flow.
    rt_flow = VALUE #( FOR ls_f IN gt_flow_all
                       WHERE ( op_type = iv_op_type )
                       ( ls_f ) ).

    IF rt_flow IS INITIAL.
      " El mensaje distingue los dos casos posibles, porque el diagnostico es
      " distinto: sin configuracion precargada el problema es de CODIGO (falta
      " la llamada a warm_config); con ella precargada el problema es de DATO
      " (falta el flujo en DOCFLOW_C).
      IF gt_flow_all IS INITIAL.
        RAISE EXCEPTION TYPE zcx_reing_contab
          EXPORTING
            iv_message = |Configuracion de flujos no precargada: | &&
                         |ZCL_REING_CONTAB_ENGINE=>WARM_CONFIG no fue invocado antes | &&
                         |de procesar lineas (OP_TYPE { iv_op_type })|.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |No flow configuration found for OP_TYPE { iv_op_type }|.
    ENDIF.
    " End Mod V003 (08.09.2026 | EXT_GONZALCA)

    IF iv_reverse = abap_true.
      SORT rt_flow BY seq DESCENDING.
    ELSE.
      SORT rt_flow BY seq ASCENDING.
    ENDIF.
  ENDMETHOD.


  METHOD preload_processor_classes.
    IF it_flow IS INITIAL.
      RETURN.
    ENDIF.

    " Begin Mod V003 (08.09.2026 | EXT_GONZALCA)
    " Filtra en memoria GT_DOCTYPE_ALL (precargado por warm_config) en vez de
    " leer DOCTYPE_C. El SELECT que vivia aca se ejecutaba una vez POR LINEA y
    " era uno de los 28 errores ATC que bloqueaban la liberacion de la orden.
    " Sentencia original conservada como referencia:
    "    SELECT doc_type_code, processing_class
    "      FROM zreing_doctype_c
    "      FOR ALL ENTRIES IN @it_flow
    "      WHERE doc_type_code = @it_flow-doc_type_code
    "      INTO TABLE @DATA(lt_dt).
    CLEAR mt_class_map.
    LOOP AT it_flow INTO DATA(ls_step_map).
      IF line_exists( mt_class_map[ doc_type_code = ls_step_map-doc_type_code ] ).
        CONTINUE.
      ENDIF.
      READ TABLE gt_doctype_all INTO DATA(ls_dt)
        WITH KEY doc_type_code = ls_step_map-doc_type_code.
      IF sy-subrc = 0.
        INSERT VALUE ty_class_map( doc_type_code    = ls_dt-doc_type_code
                                   processing_class = ls_dt-processing_class )
          INTO TABLE mt_class_map.
      ENDIF.
    ENDLOOP.
    " End Mod V003 (08.09.2026 | EXT_GONZALCA)

    " Begin Insert V002 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : validacion de integridad del mapping ANTES de procesar.
    " Motivo (hallazgo H-1, verificado en DS4-200 el 03 y 08.09.2026): los
    " 16 registros de ZREING_DOCTYPE_C apuntaban a ZCL_REING_CONTAB_DOC_AR /
    " _AP / _GL, tres clases que NO EXISTEN y que la ET CONTAB nunca
    " definio (ET-REING-CONTAB-001 v41 SS4.4.1 mapea a
    " ZCL_REING_CONTAB_DOC / _INT / _RECL, y SS8.1 dice "existen tres clases
    " concretas"). El sintoma que llegaba al usuario era
    " "Cannot instantiate processing class ZCL_REING_CONTAB_DOC_AR"
    " repetido por cada linea seleccionada, sin decir de que flujo ni de que
    " paso venia, y ocultando que los pasos SIGUIENTES tambien estaban mal:
    " corregir solo el primero hacia avanzar el error al siguiente.
    " Ahora se validan TODOS los pasos del flujo de una sola pasada y se
    " informan juntos, con OP_TYPE / SEQ / DOC_TYPE_CODE / clase, que es lo
    " que hace falta para corregir el customizing en una sola intervencion.
    " La existencia se comprueba por RTTI y no instanciando: describe_by_name
    " no ejecuta el constructor, asi que la validacion no tiene efectos
    " laterales. Que la clase IMPLEMENTE ZIF_REING_CONTAB lo sigue
    " garantizando el CREATE OBJECT tipado de instantiate_processor.
    DATA lt_bad TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    LOOP AT it_flow INTO DATA(ls_step_chk).
      READ TABLE mt_class_map INTO DATA(ls_map_chk)
        WITH KEY doc_type_code = ls_step_chk-doc_type_code.

      IF sy-subrc <> 0 OR ls_map_chk-processing_class IS INITIAL.
        APPEND |{ ls_step_chk-op_type }/{ ls_step_chk-seq }/| &&
               |{ ls_step_chk-doc_type_code }: sin clase en DOCTYPE_C| TO lt_bad.
        CONTINUE.
      ENDIF.

      DATA lo_descr TYPE REF TO cl_abap_typedescr.
      cl_abap_typedescr=>describe_by_name(
        EXPORTING  p_name         = ls_map_chk-processing_class
        RECEIVING  p_descr_ref    = lo_descr
        EXCEPTIONS type_not_found = 1
                   OTHERS         = 2 ).
      IF sy-subrc <> 0.
        APPEND |{ ls_step_chk-op_type }/{ ls_step_chk-seq }/| &&
               |{ ls_step_chk-doc_type_code }: la clase | &&
               |{ ls_map_chk-processing_class } no existe| TO lt_bad.
      ENDIF.
    ENDLOOP.

    IF lt_bad IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |Customizing de CONTAB invalido en { lines( lt_bad ) } paso(s) | &&
                       |del flujo -- corregir ZREING_DOCTYPE_C: | &&
                       |{ concat_lines_of( table = lt_bad sep = ` | ` ) }|.
    ENDIF.
    " End Insert V002 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.


  METHOD instantiate_processor.
    " Lee la clase del diccionario precargado (sin acceso a BD).
    DATA(ls_map) = VALUE #( mt_class_map[ doc_type_code = is_flow_step-doc_type_code ]
                            OPTIONAL ).

    " Begin Mod V002 (08.09.2026 | EXT_GONZALCA)
    " Los dos mensajes de abajo decian solo el DOC_TYPE_CODE o solo el
    " nombre de la clase, y se repetian identicos por cada linea del scope
    " sin indicar de que flujo ni de que paso venia el problema. Ahora
    " llevan OP_TYPE / SEQ / DOC_TYPE_CODE / clase.
    " Nota: la validacion de integridad del mapping completo se hace antes,
    " una sola vez por flujo, en preload_processor_classes -- estos dos
    " RAISE quedan como red de seguridad para el caso en que la clase exista
    " pero no sea instanciable (privada, abstracta, constructor que falla) o
    " no implemente ZIF_REING_CONTAB, que es lo que el CREATE OBJECT tipado
    " detecta y RTTI no.
    DATA(lv_where) = |{ is_flow_step-op_type }/{ is_flow_step-seq }/| &&
                     |{ is_flow_step-doc_type_code }|.

    IF ls_map-processing_class IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |Paso { lv_where }: no hay PROCESSING_CLASS configurada en | &&
                       |ZREING_DOCTYPE_C|.
    ENDIF.

    " Instanciacion dinamica. La clase debe implementar ZIF_REING_CONTAB.
    TRY.
        CREATE OBJECT ro_proc TYPE (ls_map-processing_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_reing_contab
          EXPORTING
            iv_message = |Paso { lv_where }: no se pudo instanciar | &&
                         |{ ls_map-processing_class } -- verificar que exista, sea | &&
                         |publica e implemente ZIF_REING_CONTAB|
            previous   = lx_create.
    ENDTRY.
    " End Mod V002 (08.09.2026 | EXT_GONZALCA)

    " Propagar el poster FI inyectado (si lo hay). El Engine no lo instancia
    " (frontera Cloud/Tier2); lo recibio de set_fi_poster (adapter o test).
    IF mo_fi_poster IS BOUND.
      ro_proc->set_fi_poster( mo_fi_poster ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_preconditions.
    " D-1: se validan los estados REALES del dominio de CA, no los
    " CONT_PROC/REV_PROC idealizados de la ET. CA transiciona el estado
    " antes de invocar; CONTAB valida como gatekeeping.
    DATA(lv_expected) = SWITCH zreing_ca_line_status( iv_mode
      WHEN 'C' THEN 'SIM_PROC'     " Check / Simular
      WHEN 'P' THEN 'POST_PROC'    " Post / Contabilizar
      WHEN 'S' THEN 'ANUL_PROC'    " Storno / Anular
      ELSE space ).

    IF lv_expected = space.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |Invalid mode { iv_mode }|.
    ENDIF.

    IF is_line_a-line_status <> lv_expected.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |LINE_STATUS { is_line_a-line_status } invalid for mode { iv_mode } (expected { lv_expected })|.
    ENDIF.
  ENDMETHOD.


  METHOD check_auto_reversal_guard.
    " OP_TYPE con AUTO_REVERSAL es estornado por SAP FI automaticamente en
    " REVERSAL_DATE; la anulacion manual no aplica (ET SS7.6.2). PR-02 ya
    " agrego el campo AUTO_REVERSAL a ZREING_OP_TYPE_C.
    " Begin Mod V003 (08.09.2026 | EXT_GONZALCA)
    " Lee GT_OPTYPE_ALL (precargado por warm_config) en vez de la base. El
    " SELECT SINGLE que vivia aca se ejecutaba una vez POR LINEA en modo
    " Storno y era uno de los 28 errores ATC que bloqueaban la liberacion.
    " Sentencia original conservada como referencia:
    "    SELECT SINGLE auto_reversal FROM zreing_op_type_c
    "      WHERE op_type = @is_line_a-op_type
    "      INTO @DATA(lv_auto_rev).
    READ TABLE gt_optype_all INTO DATA(ls_optype)
      WITH KEY op_type = is_line_a-op_type.
    IF sy-subrc = 0 AND ls_optype-auto_reversal = abap_true.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |OP_TYPE { is_line_a-op_type } usa anulacion automatica SAP; corregir via calculo delta (PERMITE_DELTA)|.
    ENDIF.
    " End Mod V003 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.


  METHOD buffer_document.
    " Modo Check (simulacion) TAMBIEN se persiste (ET SS7.6.1): DOC_A con
    " SIMULATED=X y BELNR vacio, mas items, para que MON muestre el
    " resultado sin re-ejecutar. Solo cambia que no hay documento FI real.
    " Begin Mod V004 (09.09.2026 | EXT_GONZALCA)
    " Fix CONVT_NO_NUMBER dump: the previous string-template form rendered
    " UTCLONG in human readable shape, which is not a numeric literal, so the
    " conversion to TIMESTAMPL raised CX_SY_CONVERSION_NO_NUMBER on every run.
    " UTCLONG2TSTMP returns TIMESTAMPL and matches CREATED_AT exactly -- do not
    " switch to the _SHORT variant, it drops the fractional seconds.
    DATA(lv_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    " End Mod V004 (09.09.2026 | EXT_GONZALCA)
    DATA(lv_simulated) = COND abap_bool( WHEN mv_mode = 'C' THEN abap_true
                                         ELSE abap_false ).
    DATA(lv_belnr) = COND belnr_d( WHEN mv_mode = 'C' THEN space
                                   ELSE is_doc_result-belnr ).
    DATA(lv_status) = SWITCH #( mv_mode
                        WHEN 'C' THEN 'SI'    " simulado
                        WHEN 'S' THEN 'RV'    " reversado
                        ELSE 'OK' ).

    " Begin Insert V006 (09.09.2026 | EXT_GONZALCA)
    " STORNO: la cabecera se reconstruye a partir de la fila ORIGINAL, no de
    " is_doc_result. reverse_step solo devuelve doc_type_code / bukrs / belnr /
    " gjahr / reverse_belnr -- no llena items, total_amount, blart, budat,
    " waers ni payload. Armarla desde el resultado del paso dejaba esos campos
    " vacios, lo que era inocuo mientras flush_documents usaba INSERT (dumpeaba
    " sobre la PK existente y el dato quedaba intacto) pero es DESTRUCTIVO con
    " el MODIFY de V006: el upsert pisaria importe, moneda, fecha y payload del
    " documento posteado, y MON mostraria el anulado en 0.
    " Solo se sobrescriben los campos propios de la anulacion. created_by y
    " created_at conservan los del posteo: son la auditoria del documento, no
    " del storno, y el storno ya queda registrado en TRC_A con su propio
    " timestamp y usuario.
    IF mv_mode = 'S'.
      DATA(ls_orig) = VALUE #( gt_orig_docs_all[
                                 calc_run_id   = is_line_a-calc_run_id
                                 line_num      = is_line_a-line_num
                                 doc_type_code = is_doc_result-doc_type_code ]
                               OPTIONAL ).
      IF ls_orig-calc_run_id IS INITIAL.
        " Anular algo que no quedo persistido es una inconsistencia. No se
        " fabrica una cabecera vacia y no se escribe nada para este paso; el
        " intento queda en TRC_A. Este metodo no puede propagar el error
        " (no declara RAISING y ampliar su firma tocaria la definicion de la
        " clase), asi que la puerta real esta en process_line, que ya valida
        " la existencia del original antes de llamar aca.
        add_trace( iv_type = 'STEP_ERR'
                   iv_dtc  = is_doc_result-doc_type_code
                   iv_msg  = |Storno sin documento original en ZREING_CB_DOC_A| ).
        RETURN.
      ENDIF.
      ls_orig-status        = lv_status.
      ls_orig-reverse_belnr = is_doc_result-reverse_belnr.
      ls_orig-reversal_date = is_doc_result-reversal_date.
      APPEND ls_orig TO mt_doc_buffer.
      " El Storno no genera posiciones nuevas: las del documento original se
      " conservan tal cual. flush_documents ya no borra por la presencia del
      " buffer de items sino por el conjunto de claves de documento del lote,
      " asi que no quedan colgadas ni se borran de mas.
      RETURN.
    ENDIF.
    " End Insert V006 (09.09.2026 | EXT_GONZALCA)

    " --- Cabecera DOC_A al buffer (modos C y P) ---
    APPEND VALUE #(
      calc_run_id   = is_line_a-calc_run_id
      line_num      = is_line_a-line_num
      doc_type_code = is_doc_result-doc_type_code
      bukrs         = is_doc_result-bukrs
      belnr         = lv_belnr
      gjahr         = is_doc_result-gjahr
      blart         = is_doc_result-blart
      budat         = is_doc_result-budat
      reversal_date = is_doc_result-reversal_date
      waers         = is_doc_result-waers
      total_amount  = is_doc_result-total_amount
      num_items     = lines( is_doc_result-items )
      status        = lv_status
      simulated     = lv_simulated
      reverse_belnr = is_doc_result-reverse_belnr
      payload       = is_doc_result-payload
      created_by    = sy-uname
      created_at    = lv_ts ) TO mt_doc_buffer.

    " --- Items DOC_ITEM_A al buffer ---
    LOOP AT is_doc_result-items INTO DATA(ls_it).
      APPEND VALUE #(
        calc_run_id   = is_line_a-calc_run_id
        line_num      = is_line_a-line_num
        doc_type_code = is_doc_result-doc_type_code
        item_num      = ls_it-item_num
        role_code     = ls_it-role_code
        hkont         = ls_it-hkont
        posting_side  = ls_it-posting_side
        amount        = ls_it-amount
        waers         = ls_it-waers
        kostl         = ls_it-kostl
        prctr         = ls_it-prctr
        campana       = ls_it-campana
        allocation    = ls_it-allocation
        zuonr         = ls_it-zuonr ) TO mt_item_buffer.
    ENDLOOP.
  ENDMETHOD.


  METHOD persist_all.
    " Begin Mod V004 (09.09.2026 | EXT_GONZALCA)
    " Fix CONVT_NO_NUMBER dump (ST22 key CONVT_NO_NUMBER_20260909_103757).
    " Same defect as in BUFFER_DOCUMENT: the previous string-template form
    " rendered UTCLONG in human readable shape, which is not a numeric
    " literal, so the conversion to TIMESTAMPL raised
    " CX_SY_CONVERSION_NO_NUMBER. This method runs unconditionally per line,
    " so the dump hit every Simulate/Post/Storno run.
    DATA(lv_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    " End Mod V004 (09.09.2026 | EXT_GONZALCA)

    " Volcar traces al buffer de TRACE_A (transformacion in-memory, sin BD).
    DATA lt_trc TYPE STANDARD TABLE OF zreing_cb_trc_a.
    lt_trc = VALUE #(
      FOR ls_tr IN mt_traces
      ( calc_run_id   = is_line_a-calc_run_id
        line_num      = is_line_a-line_num
        trace_seq     = ls_tr-trace_seq
        trace_typ     = ls_tr-trace_typ
        doc_type_code = ls_tr-doc_type_code
        contab_mode   = mv_mode
        belnr         = ls_tr-belnr
        message       = ls_tr-message
        created_by    = sy-uname
        created_at    = lv_ts ) ).

    " Begin Mod V003 (08.09.2026 | EXT_GONZALCA)
    " Este metodo ya NO escribe a base. Traslada los buffers de ESTA linea a
    " los acumuladores estaticos de la accion; el INSERT masivo unico lo hace
    " flush_documents, invocado fuera del LOOP AT keys.
    " Motivo: los 3 INSERT que vivian aca producian 12 de los 28 errores ATC
    " del check "Search DB Operations in loops across modularization units"
    " (el Engine se instancia POR LINEA dentro del LOOP de run_contab_mode),
    " y esos errores bloqueaban la liberacion de la orden de transporte.
    " El control de SY-SUBRC del fix V002 se mudo a flush_documents, con su
    " justificacion completa.
    " Semantica preservada: persist_all se sigue llamando SIEMPRE, tanto en
    " flujo exitoso como en abort por error (ET SS7.6), asi que lo bufferizado
    " hasta el paso fallido sigue llegando a BD -- solo que unos milisegundos
    " despues, al cerrar la accion.
    " Bloque original conservado como referencia:
    "    IF mt_doc_buffer IS NOT INITIAL.
    "      INSERT zreing_cb_doc_a FROM TABLE @mt_doc_buffer.
    "      IF sy-subrc <> 0. RAISE EXCEPTION ... ENDIF.
    "    ENDIF.
    "    IF mt_item_buffer IS NOT INITIAL.
    "      INSERT zreing_cb_item_a FROM TABLE @mt_item_buffer.
    "      IF sy-subrc <> 0. RAISE EXCEPTION ... ENDIF.
    "    ENDIF.
    "    IF lt_trc IS NOT INITIAL.
    "      INSERT zreing_cb_trc_a FROM TABLE @lt_trc.
    "    ENDIF.
    APPEND LINES OF mt_doc_buffer  TO gt_doc_pending.
    APPEND LINES OF mt_item_buffer TO gt_item_pending.
    APPEND LINES OF lt_trc         TO gt_trace_pending.
    " End Mod V003 (08.09.2026 | EXT_GONZALCA)

    CLEAR: mt_doc_buffer, mt_item_buffer, mt_traces.
  ENDMETHOD.


  METHOD add_trace.
    DATA(lv_seq) = lines( mt_traces ) + 1.
    APPEND VALUE #(
      trace_seq     = lv_seq
      trace_typ     = iv_type
      doc_type_code = iv_dtc
      belnr         = iv_belnr
      message       = iv_msg ) TO mt_traces.
  ENDMETHOD.


  METHOD load_original_docs.
    " Documentos posteados (status OK) del LINE_A, mapeados a ty_step_result
    " con los campos que reverse_step necesita.
    " Begin Mod V003 (08.09.2026 | EXT_GONZALCA)
    " Filtra en memoria GT_ORIG_DOCS_ALL (precargado por warm_config, ya con
    " el filtro status = 'OK') en vez de leer CB_DOC_A. El SELECT que vivia
    " aca se ejecutaba una vez POR LINEA en modo Storno y era uno de los 28
    " errores ATC que bloqueaban la liberacion de la orden.
    " Sentencia original conservada como referencia:
    "    SELECT doc_type_code, bukrs, belnr, gjahr
    "      FROM zreing_cb_doc_a
    "      WHERE calc_run_id = @is_line_a-calc_run_id
    "        AND line_num    = @is_line_a-line_num
    "        AND status      = 'OK'
    "      INTO TABLE @DATA(lt_docs).
    rt_orig = VALUE #(
      FOR ls_d IN gt_orig_docs_all
      WHERE ( calc_run_id = is_line_a-calc_run_id
              AND line_num = is_line_a-line_num )
      ( doc_type_code = ls_d-doc_type_code
        bukrs         = ls_d-bukrs
        belnr         = ls_d-belnr
        gjahr         = ls_d-gjahr ) ).
    " End Mod V003 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD warm_config.
    " Begin Change ID V003 (08.09.2026 | EXT_GONZALCA)
    " Unico punto con acceso a BD de lectura del Engine. Las sentencias son
    " masivas y viven FUERA de todo loop: este metodo se invoca una sola vez
    " por accion.
    " Ver la nota extensa de la declaracion (motivo: 28 errores ATC del check
    " "Search DB Operations in loops across modularization units" que
    " bloqueaban la liberacion de la orden de transporte).
    "
    " El CLEAR inicial es obligatorio: los atributos son ESTATICOS y
    " sobreviven entre llamadas dentro del mismo roll area. Sin el, una
    " segunda accion en la misma sesion arrastraria la configuracion y --
    " peor -- los documentos pendientes de la anterior.
    " Begin Mod V005 (09.09.2026 | EXT_GONZALCA)
    " The call site moved: since V018 of ZBP_REINGCARUN this method is no
    " longer called from the action handler but from
    " lsc_zi_reingcarun~save_modified, which runs warm_config, then
    " run_contab_mode per queued job, then flush_documents -- all three
    " consecutively inside the SAVE phase. That makes the CLEAR above safe by
    " construction: nothing runs between the CLEAR and the flush.
    " End Mod V005 (09.09.2026 | EXT_GONZALCA)
    CLEAR: gt_flow_all, gt_doctype_all, gt_optype_all, gt_orig_docs_all,
           gt_doc_pending, gt_item_pending, gt_trace_pending, gt_trans_currencies, gt_contract_kostl, gt_campana_map, gt_contract_text.
    gv_eba_off = abap_true.

    IF it_lines IS INITIAL.
      RETURN.
    ENDIF.

    " V001 (CC) - Resolve once per nonempty action, before all business loops.
    TEST-SEAM eba_engine_switch.
      gv_eba_off = zcl_reing_ca_trans_amounts=>get_eba_off( ).
    END-TEST-SEAM.
    " V001 (CC) - CB-01: bulk precision lookup before any document/line loop.
    warm_trans_precision( it_lines ).

    " V001 (CC) - #122: one bulk read, after the nonempty-scope guard.
    SELECT ct_uuid, ext_contract
      FROM zreing_ct2_a
      FOR ALL ENTRIES IN @it_lines
      WHERE ct_uuid = @it_lines-ct_uuid
      INTO TABLE @gt_contract_text.

    " OP_TYPEs distintos del scope completo. Begin Mod V006: el mismo loop
    " arma tambien los rangos de run y linea que usa la lectura de
    " documentos originales de mas abajo.
    DATA lt_op_rng   TYPE RANGE OF zreing_op_type.
    DATA lt_run_rng  TYPE RANGE OF zreing_calc_run_id.
    DATA lt_line_rng TYPE RANGE OF zreing_line_num.
    LOOP AT it_lines INTO DATA(ls_line).
      IF NOT line_exists( lt_op_rng[ low = ls_line-op_type ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_line-op_type ) TO lt_op_rng.
      ENDIF.
      IF NOT line_exists( lt_run_rng[ low = ls_line-calc_run_id ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_line-calc_run_id ) TO lt_run_rng.
      ENDIF.
      IF NOT line_exists( lt_line_rng[ low = ls_line-line_num ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_line-line_num ) TO lt_line_rng.
      ENDIF.
    ENDLOOP.

    IF lt_op_rng IS NOT INITIAL.
      " SELECT * deliberado: load_flow_config devuelve la fila COMPLETA de
      " DOCFLOW_C (ty_flow_t) y las procesadoras leen BLART / BUKRS_RULE /
      " BUKRS_OVERRIDE de is_flow_step. Proyectar columnas romperia
      " set_context.
      SELECT * FROM zreing_docflow_c                       "#EC CI_ALL_FIELDS_NEEDED
        WHERE op_type IN @lt_op_rng
          AND active  = 'X'
        INTO TABLE @gt_flow_all.

      SELECT * FROM zreing_op_type_c                       "#EC CI_ALL_FIELDS_NEEDED
        WHERE op_type IN @lt_op_rng
        INTO TABLE @gt_optype_all.
    ENDIF.

    " V001 (CC) - bug107 CONTAB: a missing pair remains missing; never match MATNR.
    IF line_exists( gt_flow_all[ kostl_rule = zif_reing_ca_c=>kostl_rule-contract ] )
       OR line_exists( gt_flow_all[ doc_type_code = zif_reing_ca_c=>contab_doc_type-reclassification
         kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map ] ).
      SELECT ct_uuid, mat_uuid, kostl, prctr
        FROM zreing_ct2_mat_a
        FOR ALL ENTRIES IN @it_lines
        WHERE ct_uuid = @it_lines-ct_uuid AND mat_uuid = @it_lines-mat_uuid
        INTO TABLE @gt_contract_kostl.
    ENDIF.

    " V001 (CC) - #121: reclassification supplies its source prefix only at runtime.
    " Warm all campaigns of the scoped materials once, with a nonempty FAE driver.
    IF line_exists( gt_flow_all[ kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map ] ).
      SELECT campana_de, matnr, campana_para
        FROM zreing_cmp_map_c
        FOR ALL ENTRIES IN @it_lines
        WHERE matnr = @it_lines-matnr
        INTO TABLE @gt_campana_map.
    ENDIF.

    " DOCTYPE_C acotada a los DOC_TYPE_CODE que los flujos del scope
    " realmente referencian. Se resuelve DESPUES de leer DOCFLOW_C porque el
    " range sale de ahi. Una primera version leia la tabla entera (son 16
    " filas de customizing) pero el ATC lo marca con prioridad 2 -- "Ninguna
    " condicion WHERE" -- y tiene razon: el tamano de una tabla de
    " customizing no es un contrato, puede crecer.
    IF gt_flow_all IS NOT INITIAL.
      DATA lt_dt_rng TYPE RANGE OF zreing_doc_type_code.
      LOOP AT gt_flow_all INTO DATA(ls_flow).
        IF NOT line_exists( lt_dt_rng[ low = ls_flow-doc_type_code ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_flow-doc_type_code ) TO lt_dt_rng.
        ENDIF.
      ENDLOOP.

      SELECT * FROM zreing_doctype_c                       "#EC CI_ALL_FIELDS_NEEDED
        WHERE doc_type_code IN @lt_dt_rng
        INTO TABLE @gt_doctype_all.
    ENDIF.

    " Documentos originales posteados: solo los usa el modo Storno, pero se
    " leen siempre porque warm_config no conoce el modo y el costo es una
    " lectura por clave primaria sobre el scope ya acotado.
    " Begin Mod V006 (09.09.2026 | EXT_GONZALCA)
    " Dos cambios respecto de V003, ambos por el mismo motivo: desde V006 la
    " cabecera del Storno se RECONSTRUYE a partir de esta fila
    " (ver buffer_document), porque flush_documents pasa a usar MODIFY y un
    " upsert armado desde reverse_step pisaria el documento posteado con
    " campos vacios.
    "   1. Lista de columnas ampliada a los campos de negocio que el Storno
    "      debe preservar (importe, moneda, blart, budat, num_items, payload,
    "      created_by/at). V003 traia solo 6 y con MODIFY eso era destructivo.
    "   2. FOR ALL ENTRIES reemplazado por dos rangos IN. La semantica
    "      DISTINCT de FOR ALL ENTRIES hace que la columna LOB PAYLOAD sea
    "      inviable: el check del servidor responde "Columns with type STRING,
    "      RAWSTRING, LRAW, LCHR (like "PAYLOAD") should not be used in the
    "      SELECT clause due to the DISTINCT semantics of FOR ALL ENTRIES".
    "      Los rangos sobre-leen por producto cartesiano, y eso es inofensivo:
    "      load_original_docs y buffer_document ya matchean la clave exacta en
    "      memoria. Sigue siendo UNA sentencia masiva fuera de todo loop.
    SELECT calc_run_id, line_num, doc_type_code, bukrs, belnr, gjahr,
           blart, budat, reversal_date, waers, total_amount, num_items,
           status, simulated, reverse_belnr, payload, created_by, created_at
      FROM zreing_cb_doc_a
      WHERE calc_run_id IN @lt_run_rng
        AND line_num    IN @lt_line_rng
        AND status      = 'OK'
        AND simulated   = @abap_false
        AND belnr       <> @space
      INTO CORRESPONDING FIELDS OF TABLE @gt_orig_docs_all.
    " End Mod V006 (09.09.2026 | EXT_GONZALCA)
    " End Change ID V003 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD flush_documents.
    " Begin Change ID V003 (08.09.2026 | EXT_GONZALCA)
    " Unico punto de escritura del Engine. Una sentencia masiva por tabla, con
    " TODAS las lineas de la accion acumuladas -- antes cada instancia (una por
    " linea) hacia sus propios 3 INSERT dentro del LOOP, lo que producia 12 de
    " los 28 errores ATC que bloqueaban la liberacion.
    " Begin Mod V005 (09.09.2026 | EXT_GONZALCA)
    " CALL THIS FROM lsc_zi_reingcarun~save_modified, NOT from an action
    " handler. The BDEF declares strict ( 2 ): during the RAP interaction phase
    " a direct INSERT/UPDATE/DELETE is forbidden and the kernel raises
    " BEHAVIOR_ILLEGAL_STATEMENT (ST22 BEHAVIOR_ILLEGAL_STATEMENT_20260909_120904).
    " The caller must catch ZCX_REING_CONTAB: leaving a BEHAVIOR implementation
    " via RAISE EXCEPTION is itself a contract violation, and save_modified runs
    " past the point of no return.
    " End Mod V005 (09.09.2026 | EXT_GONZALCA)
    " Begin Mod V006 (09.09.2026 | EXT_GONZALCA)
    " Fix dump DBSQL_DUPLICATE_KEY_ERROR (ST22 key ..._20260909_181050). Ninguna
    " de las tres PK puede representar el INTENTO, asi que una segunda accion
    " sobre la misma linea colisionaba. Se hace idempotente sin tocar DDIC:
    "   DOC_A  -> MODIFY. Lo que cambia entre intentos son campos NO clave.
    "   ITEM_A -> borrado exacto + INSERT. MODIFY no sirve: ITEM_NUM es parte
    "             de la PK y la cabecera guarda num_items, asi que un intento
    "             con menos posiciones dejaria las sobrantes del anterior.
    "   TRC_A  -> renumerado continuando desde el maximo persistido. Ni
    "             ACCEPTING DUPLICATE KEYS (perderia la traza del reintento) ni
    "             MODIFY (pisaria la del intento fallido) son aceptables.
    "
    " DOS FASES ESTRICTAS. Fase 1 lee, prepara y valida; fase 2 solo escribe,
    " con sentencias que no pueden fallar por dato. Cualquier rechazo del lote
    " ocurre antes de la primera escritura, para que el metodo vuelva a ser
    " todo-o-nada: el llamador corre en la fase SAVE, captura la excepcion y
    " sigue, asi que un rechazo a mitad de camino dejaria estado parcial que
    " nadie puede revertir.
    "
    " Patron "sobre-leer y matchear exacto": acotar una sentencia a un conjunto
    " de pares (calc_run_id, line_num) no se puede expresar como tuplas en ABAP
    " SQL, y hacerlo con una sentencia por par dentro de un loop reabriria el
    " finding ATC P2 "Search DB Operations in loops across modularization
    " units" (BUG-003). Los dos SELECT usan dos rangos IN, que sobre-leen por
    " producto cartesiano, y el match exacto se hace en memoria. Sobre-leer es
    " inofensivo; sobre-BORRAR no lo seria, y por eso el DELETE trabaja sobre
    " la lista de PK exactas y no sobre los rangos.
    " Leer es legal en la fase SAVE: warm_config ya hace lecturas masivas desde
    " save_modified desde V018. Lo que fixes-009 prohibio es AUTHORITY-CHECK(DCL).
    " El control H-3 (DOC_TYPE_CODE repetido en un flujo) NO vive aca: se movio
    " a process_line, antes del loop de pasos, porque cuando este metodo corre
    " las procesadoras ya registraron los CALL FUNCTION IN UPDATE TASK del
    " posteo FI y rechazar el lote a esta altura dejaria documentos FI reales
    " sin ninguna fila en CB_DOC_A.
    " End Mod V006 (09.09.2026 | EXT_GONZALCA)

    TYPES: BEGIN OF ty_doc_key,
             calc_run_id   TYPE zreing_calc_run_id,
             line_num      TYPE zreing_line_num,
             doc_type_code TYPE zreing_doc_type_code,
           END OF ty_doc_key.

    DATA lt_doc_key    TYPE HASHED TABLE OF ty_doc_key
           WITH UNIQUE KEY calc_run_id line_num doc_type_code.
    DATA lt_item_scope TYPE HASHED TABLE OF ty_doc_key
           WITH UNIQUE KEY calc_run_id line_num doc_type_code.
    " Filas completas de ZREING_CB_ITEM_A y no una estructura de 4 campos:
    " DELETE ... FROM TABLE exige un row type compatible con la tabla de base
    " ("The type or row type of LT_ITEM_DEL cannot be converted to table
    " ZREING_CB_ITEM_A in the key part"). Solo se llenan los campos de la PK,
    " que son los unicos que la sentencia evalua.
    DATA lt_item_del   TYPE STANDARD TABLE OF zreing_cb_item_a WITH EMPTY KEY.
    DATA lt_trc_new    TYPE STANDARD TABLE OF zreing_cb_trc_a  WITH EMPTY KEY.
    DATA lt_r_run      TYPE RANGE OF zreing_calc_run_id.
    DATA lt_r_line     TYPE RANGE OF zreing_line_num.
    DATA lv_prev_run   TYPE zreing_calc_run_id.
    DATA lv_prev_line  TYPE zreing_line_num.
    DATA lv_seq        TYPE i.
    DATA lv_overflow   TYPE abap_bool.
    DATA lv_ovf_line   TYPE zreing_line_num.
    " Begin Insert V007 (10.09.2026 | EXT_GONZALCA)
    " Which key collided. The abort below used to report only that "the batch
    " carries two documents with the same key", which leaves the operator
    " scanning N lines by hand to find the offending one.
    DATA ls_dup_key    TYPE ty_doc_key.
    DATA lv_dup_found  TYPE abap_bool.
    " End Insert V007 (10.09.2026 | EXT_GONZALCA)

    IF gt_doc_pending   IS INITIAL
   AND gt_item_pending  IS INITIAL
   AND gt_trace_pending IS INITIAL.
      RETURN.
    ENDIF.

    " ================= FASE 1: leer, preparar, validar =================

    " Claves de documento del lote. lt_item_scope excluye las anulaciones:
    " un documento reversado conserva las posiciones del posteo que anula
    " (buffer_document reconstruye su cabecera desde la fila original, con su
    " num_items real), asi que borrarlas dejaria la cabecera mintiendo.
    LOOP AT gt_doc_pending ASSIGNING FIELD-SYMBOL(<ls_doc>).
      DATA(ls_key) = VALUE ty_doc_key( calc_run_id   = <ls_doc>-calc_run_id
                                       line_num      = <ls_doc>-line_num
                                       doc_type_code = <ls_doc>-doc_type_code ).
      INSERT ls_key INTO TABLE lt_doc_key.
      " Begin Insert V007 (10.09.2026 | EXT_GONZALCA)
      " INSERT INTO a UNIQUE KEY table returns 4 on collision. Keep the FIRST
      " one only: it is the one the operator has to look at, and later
      " collisions are usually the same root cause repeated.
      IF sy-subrc <> 0 AND lv_dup_found = abap_false.
        lv_dup_found = abap_true.
        ls_dup_key   = ls_key.
      ENDIF.
      " End Insert V007 (10.09.2026 | EXT_GONZALCA)
      IF <ls_doc>-status <> 'RV'.
        INSERT ls_key INTO TABLE lt_item_scope.
      ENDIF.
    ENDLOOP.

    " Red de ultimo recurso, no camino normal: process_line ya rechaza la
    " linea cuyo flujo repite un DOC_TYPE_CODE. Llegar aca significa que esa
    " puerta fallo, y entonces el MODIFY perderia un documento en silencio.
    " Se rechaza el lote avisando que los documentos FI pueden estar posteados.
    IF lines( lt_doc_key ) <> lines( gt_doc_pending ).
      CLEAR: gt_doc_pending, gt_item_pending, gt_trace_pending.
      " Begin Mod V007 (10.09.2026 | EXT_GONZALCA)
      " The colliding key goes FIRST on purpose: lsc_zi_reingcarun~save_modified
      " truncates long messages (see V020 there), so whatever has to survive the
      " cut has to be at the front.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING
          iv_message = |Clave duplicada { ls_dup_key-calc_run_id }/| &&
                       |{ ls_dup_key-line_num }/{ ls_dup_key-doc_type_code }: | &&
                       |el lote trae dos documentos con la misma clave de | &&
                       |ZREING_CB_DOC_A. No se persistio nada, pero los | &&
                       |documentos FI pueden haber quedado posteados|.
      " End Mod V007 (10.09.2026 | EXT_GONZALCA)
    ENDIF.

    " Posiciones del intento anterior que este lote reescribe.
    IF lt_item_scope IS NOT INITIAL.
      lt_r_run  = VALUE #( FOR ls_k1 IN lt_item_scope
                           ( sign = 'I' option = 'EQ' low = ls_k1-calc_run_id ) ).
      lt_r_line = VALUE #( FOR ls_k2 IN lt_item_scope
                           ( sign = 'I' option = 'EQ' low = ls_k2-line_num ) ).

      SELECT calc_run_id, line_num, doc_type_code, item_num
        FROM zreing_cb_item_a
        WHERE calc_run_id IN @lt_r_run
          AND line_num    IN @lt_r_line
        INTO TABLE @DATA(lt_item_exist).

      LOOP AT lt_item_exist ASSIGNING FIELD-SYMBOL(<ls_ie>).
        IF line_exists( lt_item_scope[ calc_run_id   = <ls_ie>-calc_run_id
                                       line_num      = <ls_ie>-line_num
                                       doc_type_code = <ls_ie>-doc_type_code ] ).
          APPEND VALUE #( calc_run_id   = <ls_ie>-calc_run_id
                          line_num      = <ls_ie>-line_num
                          doc_type_code = <ls_ie>-doc_type_code
                          item_num      = <ls_ie>-item_num ) TO lt_item_del.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Renumerado de traces. Los rangos salen del buffer de traces y NO de las
    " claves de documento: una simulacion que falla en el primer paso deja 0
    " documentos y N traces, que es justamente el caso que dumpeaba.
    IF gt_trace_pending IS NOT INITIAL.
      CLEAR: lt_r_run, lt_r_line.
      lt_r_run  = VALUE #( FOR ls_t1 IN gt_trace_pending
                           ( sign = 'I' option = 'EQ' low = ls_t1-calc_run_id ) ).
      lt_r_line = VALUE #( FOR ls_t2 IN gt_trace_pending
                           ( sign = 'I' option = 'EQ' low = ls_t2-line_num ) ).

      SELECT calc_run_id, line_num, MAX( trace_seq ) AS max_seq
        FROM zreing_cb_trc_a
        WHERE calc_run_id IN @lt_r_run
          AND line_num    IN @lt_r_line
        GROUP BY calc_run_id, line_num
        INTO TABLE @DATA(lt_trc_max).

      " STABLE y sin trace_seq: dentro de una linea el buffer ya viene en el
      " orden cronologico de los pasos del flujo, y ordenar por trace_seq
      " entrelazaria los dos intentos si la misma (run, linea) aparece en dos
      " jobs del mismo changeset.
      SORT gt_trace_pending STABLE BY calc_run_id line_num.

      LOOP AT gt_trace_pending ASSIGNING FIELD-SYMBOL(<ls_tp>).
        IF <ls_tp>-calc_run_id <> lv_prev_run
        OR <ls_tp>-line_num    <> lv_prev_line.
          lv_prev_run  = <ls_tp>-calc_run_id.
          lv_prev_line = <ls_tp>-line_num.
          lv_seq = VALUE #( lt_trc_max[ calc_run_id = lv_prev_run
                                        line_num    = lv_prev_line ]-max_seq
                            DEFAULT 0 ).
        ENDIF.

        lv_seq = lv_seq + 1.

        " ZREING_TRACE_SEQ es NUMC(4) -> techo 9999. Se marca y se sale del
        " loop; el rechazo se lanza despues, porque el CLEAR del buffer no se
        " puede hacer dentro del LOOP que lo recorre ("The table
        " GT_TRACE_PENDING cannot be deleted or overwritten within a LOOP
        " across itself"). Igual se rechaza en la fase 1, sin haber escrito.
        IF lv_seq > 9999.
          lv_overflow = abap_true.
          lv_ovf_line = <ls_tp>-line_num.
          EXIT.
        ENDIF.

        <ls_tp>-trace_seq = lv_seq.
        APPEND <ls_tp> TO lt_trc_new.
      ENDLOOP.

      IF lv_overflow = abap_true.
        CLEAR: gt_doc_pending, gt_item_pending, gt_trace_pending.
        RAISE EXCEPTION TYPE zcx_reing_contab
          EXPORTING
            iv_message = |La linea { lv_ovf_line } supero las 9999 trazas | &&
                         |acumuladas (techo de ZREING_TRACE_SEQ): indica un numero | &&
                         |anormal de reintentos. No se persistio nada de esta accion|.
      ENDIF.
    ENDIF.

    " ================= FASE 2: escribir =================
    " Sin controles de SY-SUBRC: los que habia eran codigo muerto. Sin
    " ACCEPTING DUPLICATE KEYS, un INSERT duplicado levanta CX_SY_OPEN_SQL_DB
    " y no devuelve 4, asi que el IF nunca se ejecutaba -- eso era el defecto
    " que V002 creyo estar corrigiendo. Aca no se agregan controles nuevos
    " porque ninguna de estas cuatro sentencias puede fallar por dato: el
    " upsert no colisiona, el DELETE trabaja sobre PK leidas en esta misma LUW
    " y los dos INSERT escriben claves que la fase 1 dejo libres. Un fallo duro
    " de base levanta excepcion de clase y no se disimula.
    IF gt_doc_pending IS NOT INITIAL.
      MODIFY zreing_cb_doc_a FROM TABLE @gt_doc_pending.
    ENDIF.

    IF lt_item_del IS NOT INITIAL.
      DELETE zreing_cb_item_a FROM TABLE @lt_item_del.
    ENDIF.

    IF gt_item_pending IS NOT INITIAL.
      INSERT zreing_cb_item_a FROM TABLE @gt_item_pending.
    ENDIF.

    IF lt_trc_new IS NOT INITIAL.
      INSERT zreing_cb_trc_a FROM TABLE @lt_trc_new.
    ENDIF.

    CLEAR: gt_doc_pending, gt_item_pending, gt_trace_pending.
    " End Change ID V003 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD warm_trans_precision.
    CLEAR gt_trans_currencies.
    DATA lv_eba_off TYPE abap_bool.
    TEST-SEAM cb01_precision_guard.
      lv_eba_off = gv_eba_off.
    END-TEST-SEAM.
    TYPES tt_currency_keys TYPE HASHED TABLE OF waers WITH UNIQUE KEY table_line.
    DATA lt_keys TYPE tt_currency_keys.
    LOOP AT it_lines INTO DATA(ls_line).
      IF zcl_reing_ca_trans_amounts=>is_eba_enabled(
        iv_bukrs_prest = ls_line-bukrs_prest iv_eba_off = lv_eba_off ) = abap_false.
        CONTINUE.
      ENDIF.
      IF ls_line-trans_currency IS NOT INITIAL.
        INSERT ls_line-trans_currency INTO TABLE lt_keys.
      ENDIF.
      IF ls_line-local_currency IS NOT INITIAL.
        INSERT ls_line-local_currency INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL. RETURN. ENDIF.
    SELECT currency, decimals FROM i_currency
      FOR ALL ENTRIES IN @lt_keys
      WHERE currency = @lt_keys-table_line
      INTO CORRESPONDING FIELDS OF TABLE @gt_trans_currencies.
  ENDMETHOD.

  METHOD reject_trans_context.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER iv_number WITH iv_line INTO DATA(lv_text).
    RAISE EXCEPTION TYPE zcx_reing_contab EXPORTING iv_message = lv_text.
  ENDMETHOD.

  METHOD project_trans_context.
    IF iv_mode = zif_reing_ca_c=>contab_mode-storno. RETURN. ENDIF.
    DATA lv_eba_off TYPE abap_bool.
    TEST-SEAM cb01_projection_guard.
      lv_eba_off = mv_eba_off.
    END-TEST-SEAM.
    IF zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = is_line-bukrs_prest iv_eba_off = lv_eba_off ) = abap_false.
      RETURN.
    ENDIF.
    TRY.
        rs_projection = zcl_reing_ca_trans_amounts=>project_line(
          is_line = is_line it_line_pc = it_pcs it_steps = it_steps
          it_currencies = gt_trans_currencies iv_eba_off = lv_eba_off ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_projection).
        RAISE EXCEPTION TYPE zcx_reing_contab EXPORTING iv_message = lx_projection->mv_message.
    ENDTRY.
    IF rs_projection-use_trans = abap_false. RETURN. ENDIF.
    IF lines( rs_projection-line_pc ) <> lines( it_pcs )
       OR lines( rs_projection-steps ) <> lines( it_steps ).
      reject_trans_context( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                            iv_line = is_line-line_num ).
    ENDIF.
    DATA lt_stored_pcs TYPE zif_reing_ca_types=>tt_trans_pc.
    lt_stored_pcs = CORRESPONDING #( it_pcs ).
    LOOP AT rs_projection-line_pc INTO DATA(ls_expected_pc).
      DATA(ls_stored_pc) = lt_stored_pcs[ calc_run_id = ls_expected_pc-calc_run_id
        line_num = ls_expected_pc-line_num pc_seq = ls_expected_pc-pc_seq ].
      IF ls_expected_pc-bruto_trans_amt <> ls_stored_pc-bruto_trans_amt
         OR ls_expected_pc-net_trans_amt <> ls_stored_pc-net_trans_amt.
        reject_trans_context( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                              iv_line = is_line-line_num ).
      ENDIF.
    ENDLOOP.
    TYPES tt_step_snapshot TYPE HASHED TABLE OF zreing_ca_step_a
      WITH UNIQUE KEY calc_run_id line_num step_num seq.
    DATA lt_stored_steps TYPE tt_step_snapshot.
    INSERT LINES OF it_steps INTO TABLE lt_stored_steps.
    LOOP AT rs_projection-steps INTO DATA(ls_expected_step).
      DATA(ls_stored_step) = lt_stored_steps[ calc_run_id = ls_expected_step-calc_run_id
        line_num = ls_expected_step-line_num step_num = ls_expected_step-step_num seq = ls_expected_step-seq ].
      IF ls_expected_step-output_trans_amt <> ls_stored_step-output_trans_amt.
        reject_trans_context( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                              iv_line = is_line-line_num ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

