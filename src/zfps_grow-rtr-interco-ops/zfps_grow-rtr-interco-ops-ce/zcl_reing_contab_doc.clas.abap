CLASS zcl_reing_contab_doc DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_contab.

  PROTECTED SECTION.
    " V001 (CC) - CB-01: native CT inputs remain immutable monetary facts.
    DATA ms_trans_projection TYPE zif_reing_ca_types=>ty_trans_projection.
    DATA mv_use_trans TYPE abap_bool.
    DATA mv_trans_error TYPE string.
    DATA mv_trans_decimals TYPE i.
    METHODS prepare_trans_context
      IMPORTING is_projection TYPE zif_reing_ca_types=>ty_trans_projection OPTIONAL
                it_currencies TYPE zif_reing_ca_types=>tt_currency_precision OPTIONAL
                iv_eba_off TYPE abap_bool OPTIONAL.
    METHODS posting_currency RETURNING VALUE(rv_currency) TYPE waers.
    METHODS posting_line_amount
      IMPORTING iv_ar TYPE abap_bool
      RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-net_amt.
    METHODS posting_pc_snapshot
      RETURNING VALUE(rt_pcs) TYPE zif_reing_ca_types=>ty_line_pc_t.
    METHODS has_ar_context RETURNING VALUE(rv_ar) TYPE abap_bool.
    METHODS trans_is_applicable RETURNING VALUE(rv_applicable) TYPE abap_bool.
    METHODS trans_error
      IMPORTING iv_number TYPE symsgno iv_v1 TYPE symsgv OPTIONAL
                iv_v2 TYPE symsgv OPTIONAL iv_v3 TYPE symsgv OPTIONAL.
    METHODS round_trans_amount
      IMPORTING iv_amount TYPE decfloat34 iv_exact TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-net_amt.
    CONSTANTS co_prctr_default TYPE prctr VALUE '0000000999'.
    DATA ms_line_a          TYPE zreing_ca_line_a.
    DATA mt_line_pc         TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_step_a          TYPE zif_reing_ca_types=>ty_step_t.
    DATA ms_flow_step       TYPE zreing_docflow_c.
    " V001 (CC) - bug107 CONTAB: reset with every context, including an omitted value.
    DATA mv_contract_kostl TYPE kostl.
    " V001 (CC) - #121: every context assignment replaces the contract profit center.
    DATA mv_contract_prctr TYPE prctr.
    " V001 (CC) - #121: an omitted mapping context must clear the previous one.
    DATA mt_campana_map TYPE zif_reing_contab_types=>tt_campana_map.
    DATA mv_bukrs           TYPE bukrs.
    DATA mv_doc_type_code   TYPE zreing_doc_type_code.
    DATA mv_blart           TYPE blart.
    DATA mv_auto_reversal   TYPE abap_bool.
    DATA mv_reversal_reason TYPE stgrd.
    DATA mv_internal_code   TYPE c LENGTH 3.
    DATA mv_ar_partner      TYPE zc_intercorelationship-providercustomer.
    DATA mv_ar_recon_acct   TYPE hkont.
    DATA mv_ap_partner      TYPE zc_intercorelationship-providervendor.
    DATA mv_ap_recon_acct   TYPE hkont.
    " Begin Insert V002 (11.09.2026 | EXT_GONZALCA)
    " Fiscal period of the calculation run (ZREING_CA_RUN_A), loaded once per
    " step in set_context. BUDAT and the auto-reversal date derive from it
    " (ET-REING-CONTAB-001 v41 SS8.12), NOT from LINE_A-DEFER_FROM.
    DATA mv_fiscal_year     TYPE zreing_ca_run_a-fiscal_year.
    DATA mv_fiscal_period   TYPE zreing_ca_run_a-fiscal_period.
    " End Insert V002 (11.09.2026 | EXT_GONZALCA)
    DATA mo_fi_poster TYPE REF TO zif_reing_contab_fi_poster.
    DATA mt_prior_docs TYPE zif_reing_contab_types=>ty_step_result_t.
    DATA mt_role_master TYPE HASHED TABLE OF zreing_gl_roles
                           WITH UNIQUE KEY gl_role
                           WITH NON-UNIQUE SORTED KEY by_context
                           COMPONENTS posting_context.
    TYPES: BEGIN OF ty_gl_acct,
             gl_role  TYPE zreing_gl_roles-gl_role,
             saknr    TYPE saknr,
           END OF ty_gl_acct.
    DATA mt_gl_account TYPE HASHED TABLE OF ty_gl_acct
                          WITH UNIQUE KEY gl_role.

    METHODS build_header
      RETURNING VALUE(rs_header) TYPE zif_reing_contab_types=>ty_header.
    METHODS find_roles_for_step
      RETURNING VALUE(rt_roles) TYPE zif_reing_contab_types=>ty_role_resolved_t.
    METHODS build_items
      IMPORTING it_roles        TYPE zif_reing_contab_types=>ty_role_resolved_t
      RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
    " V001 (CC) - #122: use the effective item dimensions and line companies.
    METHODS build_item_text
      IMPORTING is_item TYPE zif_reing_contab_types=>ty_doc_item
      RETURNING VALUE(rv_text) TYPE zif_reing_contab_types=>ty_item_text.
    METHODS adjust_rounding
      CHANGING ct_items TYPE zif_reing_contab_types=>ty_doc_item_t.
    METHODS call_bapi
      IMPORTING is_header        TYPE zif_reing_contab_types=>ty_header
                it_items         TYPE zif_reing_contab_types=>ty_doc_item_t
                iv_mode          TYPE zreing_ca_contab_mode
      RETURNING VALUE(rs_result) TYPE zif_reing_contab_types=>ty_bapi_result.
    METHODS serialize_payload
      IMPORTING is_header      TYPE zif_reing_contab_types=>ty_header
                it_items       TYPE zif_reing_contab_types=>ty_doc_item_t
                is_result      TYPE zif_reing_contab_types=>ty_bapi_result
      RETURNING VALUE(rv_json) TYPE string.
    METHODS determine_kostl
      IMPORTING iv_campana      TYPE zreing_campana
                iv_allocation   TYPE zreing_alloc_type
                iv_prctr        TYPE prctr
                iv_kostl_rule   TYPE zreing_kostl_rule OPTIONAL
                iv_matnr        TYPE zreing_ca_line_a-matnr OPTIONAL
      RETURNING VALUE(rv_kostl) TYPE kostl.
    METHODS get_prev_step_doc_type
      IMPORTING iv_current_seq     TYPE zreing_docflow_c-seq
      RETURNING VALUE(rv_doc_type) TYPE zreing_doc_type_code
      RAISING   zcx_reing_contab.
    METHODS reverse_step
      RETURNING VALUE(rs_result) TYPE zif_reing_contab_types=>ty_step_result.

    "! Primer dia del mes siguiente al periodo fiscal informado (ET SS8.20).
    "! PROTECTED para permitir unit test via subclase.
    METHODS calc_reversal_date
      IMPORTING iv_gjahr       TYPE gjahr
                iv_period      TYPE monat
      RETURNING VALUE(rv_date) TYPE zif_reing_contab_types=>ty_header-reversal_date.
    "! Fecha de contabilizacion (ET SS8.12). PROTECTED para unit test.
    METHODS determine_budat
      RETURNING VALUE(rv_budat) TYPE zif_reing_contab_types=>ty_header-budat.
    "! Aplica el signo segun POSTING_SIDE (S=+, H=-). PROTECTED para unit test.
    METHODS apply_sign
      IMPORTING iv_amount        TYPE zreing_ca_line_a-net_amt
                iv_posting_side  TYPE shkzg
      RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-net_amt.

    " Begin Insert V009 (21.09.2026 | EXT_GONZALCA)
    "! Returns the exact signed document balance without integer intermediate rounding.
    METHODS calculate_balance
      IMPORTING it_items          TYPE zif_reing_contab_types=>ty_doc_item_t
      RETURNING VALUE(rv_balance) TYPE zreing_ca_line_a-net_amt.
    "! Returns one effective side of the document, as required for TOTAL_AMOUNT.
    METHODS calculate_total_amount
      IMPORTING it_items        TYPE zif_reing_contab_types=>ty_doc_item_t
      RETURNING VALUE(rv_total) TYPE zreing_ca_line_a-net_amt.
    " End Insert V009 (21.09.2026 | EXT_GONZALCA)

  PRIVATE SECTION.
    DATA mv_test_eba_off TYPE abap_bool.
    " V001 (CC) — fixes-053: Reimbursement company-code parameters.
    CONSTANTS co_reing_company_param
      TYPE zi_companycodeaddlinformation-companycodeparametertype
      VALUE 'ZIC003'.
    CONSTANTS co_internal_code_param
      TYPE zi_companycodeaddlinformation-companycodeparametertype
      VALUE 'ZIDMEL'.
    " Begin Insert V007 (16.09.2026 | EXT_GONZALCA)
    " Concepto interco que viaja en BSEG-ZUONR (bug tracker #73, modo d1).
    " Se resuelve UNA sola vez por documento en set_context, junto al resto de
    " la precarga, y los metodos de construccion solo lo consumen: la cabecera
    " de esta clase declara que toda lectura de BD vive fuera de los loops de
    " construccion, y build_items itera roles.
    DATA mv_alloc_nmbr TYPE dzuonr.
    " End Insert V007 (16.09.2026 | EXT_GONZALCA)
    METHODS determine_account
      IMPORTING is_role         TYPE zif_reing_contab_types=>ty_role_resolved
      RETURNING VALUE(rv_hkont) TYPE hkont.
    "! Abre un rol GL en items por profit center (LPC_A filtrado por
    "! role_category). Loop interno encapsulado (evita nested loop en build_items).
    METHODS append_gl_items
      IMPORTING is_role  TYPE zif_reing_contab_types=>ty_role_resolved
                iv_hkont TYPE hkont
      CHANGING  ct_items TYPE zif_reing_contab_types=>ty_doc_item_t.
    "! Concepto interco derivado de la descripcion del material (ET SS8.19).
    METHODS get_maktx_cleaned
      IMPORTING iv_matnr        TYPE matnr
      RETURNING VALUE(rv_alloc) TYPE dzuonr.
ENDCLASS.


CLASS zcl_reing_contab_doc IMPLEMENTATION.

  METHOD zif_reing_contab~set_context.
    ms_line_a        = is_line_a.
    mv_contract_kostl = iv_contract_kostl.
    mv_contract_prctr = iv_contract_prctr.
    IF mv_contract_prctr IS NOT INITIAL.
      mv_contract_prctr = |{ mv_contract_prctr ALPHA = IN }|.
    ENDIF.
    mt_campana_map = it_campana_map.
    " Begin Change ID V006 (16.09.2026 | EXT_GONZALCA)
    " Bug tracker #73, failure modes (c) and (d2) -- one single defect.
    " PRCTR reaches CONTAB left-aligned ('999       '): the ME load, the
    " pipeline (ZREING_CA_LPC_A) and the contract (ZREING_CT2_REC_A) all store
    " what the user typed, while SAP stores profit centres ALPHA-converted
    " (CEPC holds '0000000999', valid 19000101-99991231, verified in TS4-400).
    " Two different errors came out of that same raw value:
    "  - the Accounting Interface rejected the document with "El centro de
    "    beneficio ML00/999 no existe para 28.02.2026" (lines 0000197, 0000199,
    "    0000204 and 0000206 of RUN-202602, reported 16.09.2026);
    "  - determine_kostl builds the cost centre out of iv_prctr+7(3), and on an
    "    unpadded value those three positions are blanks, so KOSTL came out as
    "    '4591122   ' instead of '4591122999'. CSKS 4591122999 exists and is
    "    valid: the formula was right, its input was not. Do NOT "fix" the
    "    +7(3) offset -- it is correct for a 10-char PRCTR.
    " Normalising on this single assignment -- the only statement in the whole
    " CONTAB chain that fills MT_LINE_PC -- covers every consumer at once:
    " append_gl_items (both the item PRCTR and the determine_kostl input), the
    " two subclasses that inherit the buffer, and ZCL_REING_CONTAB_DOC_RECL,
    " which reclassifies the previous step's items from memory and therefore
    " propagates values that are already normalised. Converting at each point
    " of use instead would leave any future reader of MT_LINE_PC free to
    " reintroduce the defect.
    " ALPHA is idempotent, so a value that is already padded is left untouched
    " and the cases that work today do not change. The IS NOT INITIAL guard
    " keeps an empty profit centre empty rather than turning it into
    " '0000000000', which is not a valid CEPC entry.
    " Statement original, para el registro:
    "    mt_line_pc       = it_line_pc.
    mt_line_pc       = it_line_pc.
    LOOP AT mt_line_pc REFERENCE INTO DATA(lr_pc) WHERE prctr IS NOT INITIAL.
      lr_pc->prctr = |{ lr_pc->prctr ALPHA = IN }|.
    ENDLOOP.
    " End Change ID V006 (16.09.2026 | EXT_GONZALCA)
    mt_step_a        = it_step_a.
    " V001 (CC) - CB-01: reset the posting snapshot on every context change.
    " V001 (CC) - An omitted optional argument must never become explicit ON.
    IF iv_eba_off IS SUPPLIED.
      prepare_trans_context( is_projection = is_trans_projection it_currencies = it_currencies
                             iv_eba_off = iv_eba_off ).
    ELSE.
      prepare_trans_context( is_projection = is_trans_projection it_currencies = it_currencies ).
    ENDIF.
    ms_flow_step     = is_flow_step.
    mv_doc_type_code = is_flow_step-doc_type_code.
    mv_blart         = is_flow_step-blart.

    " --- Determinacion de sociedad via BUKRS_RULE (PR-01) ---
    " P -> prestadora, R -> receptora, O -> override. Default (vacio) = P.
    mv_bukrs = SWITCH bukrs( is_flow_step-bukrs_rule
      WHEN 'R' THEN is_line_a-bukrs_recv
      WHEN 'O' THEN is_flow_step-bukrs_override
      ELSE          is_line_a-bukrs_prest ).

    " Begin Insert V002 (11.09.2026 | EXT_GONZALCA)
    " Periodo fiscal del run (ET-REING-CONTAB-001 v41 SS8.12). Es la UNICA
    " fuente valida de BUDAT y de la fecha de estorno automatico; hasta este
    " fix ambos se derivaban de LINE_A-DEFER_FROM, que solo se llena en lineas
    " diferidas y vale 00000000 en el resto -> BUDAT invalido y rechazo de la
    " BAPI ("no se traspaso el campo obligatorio PSTNG_DATE", bug reportado
    " por Paola Romero el 11.09.2026 sobre RUN-202602 en TS4-400).
    " Se lee la TABLA TRANSPARENTE, no una vista I_*: toda esta cadena corre
    " dentro de lsc_zi_reingcarun~save_modified (BDEF strict ( 2 )), donde un
    " AUTHORITY-CHECK implicito por DCL aborta la LUW (ver Mod V001 abajo).
    " Una sola lectura por paso, por clave primaria, fuera de todo loop.
    SELECT SINGLE fiscal_year, fiscal_period
      FROM zreing_ca_run_a
      WHERE calc_run_id = @is_line_a-calc_run_id
      INTO ( @mv_fiscal_year, @mv_fiscal_period ).
    " End Insert V002 (11.09.2026 | EXT_GONZALCA)

    " --- Carga de config de estorno automatico (PR-02), un solo SELECT ---
    SELECT SINGLE auto_reversal, reversal_reason
      FROM zreing_op_type_c
      WHERE op_type = @is_line_a-op_type
      INTO ( @mv_auto_reversal, @mv_reversal_reason ).

    " --- Precarga de role masters del paso (evita DB en loop de roles) ---
    SELECT r~gl_role, r~descr, r~role_category, r~role_type, r~tax_type,
           r~auto_determ, r~reclassify, r~posting_context, r~role_reclas,
           r~role_memo
      FROM zreing_doctype_r AS d
      INNER JOIN zreing_gl_roles AS r ON r~gl_role = d~role_code
      WHERE d~doc_type_code = @mv_doc_type_code
      INTO CORRESPONDING FIELDS OF TABLE @mt_role_master.

    SELECT gl_role, saknr
      FROM zreing_ct2_gl_a
      WHERE ct_uuid  = @is_line_a-ct_uuid
        AND mat_uuid = @is_line_a-mat_uuid
      INTO TABLE @mt_gl_account.

    " V001 (CC) - CB-04: no company may inherit the prior internal code.
    CLEAR mv_internal_code.
    " V001 (CC) — fixes-053: Reimbursements use ZIC003, not Interco ZIC002.
    SELECT SINGLE code~companycodeparametervalue
      FROM zi_companycodeaddlinformation AS eligible
      INNER JOIN zi_companycodeaddlinformation AS code
        ON code~companycode = eligible~companycode
      WHERE eligible~companycode = @mv_bukrs
        AND eligible~companycodeparametertype = @co_reing_company_param
        AND eligible~companycodeparametervalue = @abap_true
        AND code~companycodeparametertype = @co_internal_code_param
      INTO @mv_internal_code.

    " --- D-5: Partner IC + cuentas de reconciliacion (una sola lectura c/u) ---
    " Relacion IC por company code: Provider = prestadora, Recipient = receptora.
    " (ET SS8.11) AR: customer que representa a la receptora (RecipientCustomer),
    " reconciliacion en libros de la prestadora. AP: vendor que representa a la
    " prestadora (ProviderVendor), reconciliacion en libros de la receptora.
    SELECT SINGLE recipientcustomer, providervendor
      FROM zc_intercorelationship
      WHERE providercompanycode  = @is_line_a-bukrs_prest
        AND recipientcompanycode = @is_line_a-bukrs_recv
      INTO ( @mv_ar_partner, @mv_ap_partner ).

    " Begin Mod V001 (09.09.2026 | EXT_GONZALCA)
    " Fix BEHAVIOR_ILLEGAL_STATEMENT dump (ST22 key
    " BEHAVIOR_ILLEGAL_STATEMENT_20260909_160023, TS4-400).
    " Since V018 of ZBP_REINGCARUN the whole CONTAB chain runs inside
    " lsc_zi_reingcarun~save_modified. The BDEF declares strict ( 2 ), and no
    " authorization check is allowed in the RAP save phase. I_CustomerCompany
    " and I_SupplierCompany are @AccessControl.authorizationCheck: #CHECK with a
    " DCL attached, so each SELECT fired an implicit AUTHORITY-CHECK(DCL) and the
    " kernel aborted the LUW. The two Z projections below read the same released
    " APIs with the check switched off -- same pattern as ZI_IntercoCompanyCode
    " and ZC_IntercoRelationship above, which is why those two do not dump.
    " Do NOT point these SELECTs back at the I_* views.
    " Field names and WHERE conditions are unchanged.
    IF mv_ar_partner IS NOT INITIAL.
      SELECT SINGLE reconciliationaccount
        FROM zi_reingcbcustomerrecon
        WHERE customer    = @mv_ar_partner
          AND companycode = @is_line_a-bukrs_prest
        INTO @mv_ar_recon_acct.
    ENDIF.

    IF mv_ap_partner IS NOT INITIAL.
      SELECT SINGLE reconciliationaccount
        FROM zi_reingcbsupplierrecon
        WHERE supplier    = @mv_ap_partner
          AND companycode = @is_line_a-bukrs_recv
        INTO @mv_ap_recon_acct.
    ENDIF.
    " End Mod V001 (09.09.2026 | EXT_GONZALCA)

    " Begin Insert V007 (16.09.2026 | EXT_GONZALCA)
    " Concepto interco para BSEG-ZUONR (bug tracker #73, modo d1). Se resuelve
    " aqui, con el resto de la precarga del paso, y no en build_items: el
    " material es uno solo por linea, de modo que dentro del loop de roles
    " seria una lectura de BD por rol. La disciplina anti-ATC declarada en la
    " cabecera de esta clase (toda lectura de BD fuera de los loops) se
    " mantiene intacta.
    mv_alloc_nmbr = get_maktx_cleaned( is_line_a-matnr ).
    " End Insert V007 (16.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD zif_reing_contab~is_applicable.
    " V001 (CC) - CB-01: retain errors for execute; do not silently skip them.
    IF mv_trans_error IS NOT INITIAL.
      rv_applicable = abap_true.
      RETURN.
    ENDIF.
    IF mv_use_trans = abap_true.
      rv_applicable = trans_is_applicable( ).
      RETURN.
    ENDIF.
    " Begin Insert V005 (16.09.2026 | EXT_GONZALCA)
    " Bug tracker #63, segunda mitad. Definicion de Rochelle del 16.09.2026:
    " una receptora que no participa del periodo NO se excluye de la lista, su
    " calculo en cero se interpreta como EXITO (esa mitad se resolvio en
    " ZCL_REING_CA_PIPELINE~step_pc_split, V012) y "en la aplicacion de
    " contabilizaciones se ignoran los importes con saldo cero" -- que es lo
    " que hace este metodo.
    " Devolver abap_false aca es la via LIMPIA y ya existente: process_line
    " evalua is_applicable en su paso 3d, registra un STEP_SKIP trazado y hace
    " CONTINUE, sin llamar a ninguna BAPI. Como no se genera documento,
    " rs_result-documents queda vacio, run_contab_mode calcula lv_full_ok =
    " abap_true y la linea toma el estado de exito del modo (CONT en P, SIM_OK
    " en C, LIBD en S) con FI_AWKEY vacio, que es lo correcto: no hay documento
    " FI que referenciar.
    " Ademas corre ANTES del guard de Storno (V006 de process_line), asi que
    " anular un run que contiene lineas en cero tampoco produce el falso
    " "Storno sin documento original en ZREING_CB_DOC_A".
    " Sin esto, build_items emitia igual la posicion AR/AP en 0,00 (el lado GL
    " ya saltea los ceros en append_gl_items) y el documento quedaba con una
    " unica posicion de 0,00 sin contrapartida, que es exactamente lo que la
    " Accounting Interface rechaza con "Saldo en moneda de transaccion".
    "
    " El criterio NO es solo el importe de la cabecera de linea: una linea
    " DELTA puede netear cero y aun asi mover importes ENTRE centros de
    " beneficio (combinaciones +X y -X en LINE_PC_A que se compensan). Esa
    " reclasificacion si tiene que contabilizarse, de modo que solo se ignora
    " la linea cuando la cabecera Y toda su apertura estan en cero.
    " Begin Mod V008 (17.09.2026 | EXT_GONZALCA)
    " El campo que define "sin saldo" pasa de NET_AMT a BRUTO_AMT, para seguir
    " al monto que efectivamente se postea (ver build_items / append_gl_items,
    " V008). Desde que el motor calcula retenciones, el neto puede ser menor
    " que el bruto -- y en el limite podria quedar en cero con un bruto real
    " que SI hay que contabilizar. Con el criterio anterior esa linea se
    " descartaria en silencio.
    " Statements originales, para el registro:
    "    IF ms_line_a-net_amt IS NOT INITIAL.
    "    LOOP AT mt_line_pc TRANSPORTING NO FIELDS WHERE net_amt <> 0.
    rv_applicable = abap_true.

    IF ms_line_a-bruto_amt IS NOT INITIAL.
      RETURN.
    ENDIF.

    LOOP AT mt_line_pc TRANSPORTING NO FIELDS WHERE bruto_amt <> 0.
      RETURN.
    ENDLOOP.
    " End Mod V008 (17.09.2026 | EXT_GONZALCA)

    rv_applicable = abap_false.
    " End Insert V005 (16.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD zif_reing_contab~set_prior_documents.
    mt_prior_docs = it_prior_docs.
  ENDMETHOD.

  METHOD zif_reing_contab~execute.
    IF iv_mode = 'S'.
      rs_result = reverse_step( ).
      RETURN.
    ENDIF.

    " V001 (CC) - CB-01: context rejection cannot reach the FI poster.
    IF mv_trans_error IS NOT INITIAL.
      rs_result = VALUE #( doc_type_code = mv_doc_type_code bukrs = mv_bukrs
        waers = posting_currency( ) has_error = abap_true error_msg = mv_trans_error ).
      RETURN.
    ENDIF.
    DATA(lt_roles)  = find_roles_for_step( ).
    DATA(ls_header) = build_header( ).
    DATA lt_items TYPE zif_reing_contab_types=>ty_doc_item_t.
    IF mv_use_trans = abap_true.
      TRY.
          lt_items = build_items( lt_roles ).
        CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
          trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-amount
            iv_v1 = CONV #( ms_line_a-line_num ) iv_v2 = CONV #( posting_currency( ) ) ).
      ENDTRY.
    ELSE.
      lt_items = build_items( lt_roles ).
    ENDIF.
    adjust_rounding( CHANGING ct_items = lt_items ).
    " V001 (CC) - #122: format after subclass construction and consolidation.
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_text_item>).
      <ls_text_item>-item_text = build_item_text( <ls_text_item> ).
    ENDLOOP.
    IF mv_use_trans = abap_true AND lt_items IS INITIAL AND mv_trans_error IS INITIAL.
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                   iv_v1 = CONV #( ms_line_a-line_num ) ).
    ENDIF.
    " V001 (CC) - CB-02: reject a nominal item in a different currency before FI.
    CONSTANTS lc_currency_message TYPE symsgno VALUE '004'.
    IF mv_use_trans = abap_true AND mv_trans_error IS INITIAL.
      LOOP AT lt_items INTO DATA(ls_currency_item)
        WHERE waers <> ls_header-waers.
        MESSAGE ID zif_reing_ca_c=>message_class
          TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER lc_currency_message
          WITH mv_doc_type_code ls_currency_item-item_num
               ls_currency_item-waers ls_header-waers INTO mv_trans_error.
        EXIT.
      ENDLOOP.
    ENDIF.

    IF mv_trans_error IS NOT INITIAL.
      rs_result = VALUE #( doc_type_code = mv_doc_type_code bukrs = ls_header-bukrs
        blart = ls_header-blart budat = ls_header-budat waers = ls_header-waers
        has_error = abap_true error_msg = mv_trans_error items = lt_items ).
      RETURN.
    ENDIF.

    " Begin Insert V004 (14.09.2026 | EXT_GONZALCA)
    " Gate de cuenta contable, ANTES de la BAPI.
    " determine_account resuelve la cuenta de un rol GL con
    " "VALUE #( mt_gl_account[ gl_role = ... ]-saknr OPTIONAL )": si el
    " contrato no tiene cuenta para ese rol, devuelve VACIO en silencio y la
    " posicion viaja a BAPI_ACC_DOCUMENT_CHECK sin GL_ACCOUNT. Lo que el
    " operador recibe entonces es el mensaje del estandar -- "En el parametro
    " ACCOUNTGL no se traspaso el campo obligatorio GL_ACCOUNT ; Cuenta de
    " mayor  no prevista en plan de cuentas MLIB" --, que no dice ni QUE rol
    " ni EN QUE contrato hay que cargar el dato. Caso real: RUN-202601 linea
    " 26, contrato IC-0007, documento AR, rol GEXP sin SAKNR en
    " ZREING_CT2_GL_A (TS4-400, 14.09.2026).
    " Se valida aca y no dentro de build_items porque ese metodo no declara
    " RAISING y ampliar su firma tocaria la DEFINITION de la clase; ademas
    " este es el punto donde el documento ya esta completo y todavia no se
    " llamo a ninguna BAPI.
    " El rechazo viaja por el MISMO camino que cualquier error de paso
    " (has_error + error_msg en ty_step_result), asi que process_line lo
    " registra con su add_trace( 'STEP_ERR' ) y la linea termina en SIM_ERR /
    " POST_ERR como corresponde -- no hace falta ninguna rama nueva.
    " En modo P esto ademas evita mandar a postear un documento condenado:
    " la validacion corre ANTES de la primera sentencia que registra un
    " update task, que es la regla que esta cadena ya aprendio por las malas.
    DATA lt_missing_acct TYPE string_table.
    LOOP AT lt_items INTO DATA(ls_chk_item) WHERE hkont IS INITIAL.
      DATA(lv_role_txt) = |{ ls_chk_item-role_code } ({ ls_chk_item-posting_context })|.
      IF NOT line_exists( lt_missing_acct[ table_line = lv_role_txt ] ).
        APPEND lv_role_txt TO lt_missing_acct.
      ENDIF.
    ENDLOOP.

    IF lt_missing_acct IS NOT INITIAL.
      " SIM_MESSAGE es CHAR 220 y run_contab_mode antepone su propia cabecera:
      " lo accionable (contrato + roles) va PRIMERO, la explicacion de donde
      " se carga el dato despues, para que sobreviva al truncado.
      rs_result = VALUE #(
        doc_type_code = mv_doc_type_code
        bukrs         = ls_header-bukrs
        blart         = ls_header-blart
        budat         = ls_header-budat
        waers         = ls_header-waers
        has_error     = abap_true
        error_msg     = |Contrato { ms_line_a-ct_id } / material { ms_line_a-matnr }: sin | &&
                        |cuenta contable para { concat_lines_of( table = lt_missing_acct sep = `, ` ) }. | &&
                        |Los roles GL se cargan en el contrato (ZREING_CT2_GL_A); los | &&
                        |contextos AR/AP salen de la cuenta de reconciliacion del interlocutor|
        items         = lt_items ).
      RETURN.
    ENDIF.
    " End Insert V004 (14.09.2026 | EXT_GONZALCA)

    " Begin Insert V008 (17.09.2026 | EXT_GONZALCA)
    " Gate de saldo, tambien ANTES de la BAPI. Las posiciones de un documento
    " FI tienen que sumar cero: apply_sign ya invierte el lado Haber, asi que
    " SUM( amount ) <> 0 es, literalmente, un documento descuadrado.
    " Hasta este fix no podia pasar -- todos los roles posteaban el mismo
    " importe, de modo que cada rol al Debe tenia su espejo al Haber. Desde
    " que las cuentas de impuesto llevan el importe del impuesto (Regla C, ver
    " append_gl_items V008) el descuadre es posible, y tiene una causa de
    " CONFIG muy concreta: un rol de impuesto sin TAX_TYPE en
    " ZREING_GL_ROLES. Hoy es el caso de RWHP (WHT a pagar) y RCIP (CIDE a
    " pagar), que tienen ROLE_TYPE = 'T' pero TAX_TYPE vacio: la Regla C no
    " los reconoce, postean el bruto y el asiento queda desbalanceado.
    " Se corta aca nombrando el descuadre y los roles sospechosos, en lugar de
    " recibir de la Accounting Interface el "Saldo en moneda de transaccion",
    " que no dice donde mirar.
    " Begin Mod V009 (21.09.2026 | EXT_GONZALCA)
    " The previous REDUCE inferred an integer accumulator from literal 0 and
    " rounded every intermediate sum, potentially hiding sub-unit imbalances.
    DATA(lv_balance) = calculate_balance( lt_items ).
    " End Mod V009 (21.09.2026 | EXT_GONZALCA)
    IF lv_balance <> 0.
      " Begin Insert V010 (21.09.2026 | EXT_GONZALCA)
      " Preserve runtime evidence for one-sided documents. Report only roles
      " that should have emitted an item for the LPC categories actually
      " present; category-specific roles for an absent category are not noise.
      " Tax roles remain covered by the existing TAX_TYPE diagnostic below.
      TYPES ty_role_cat_set TYPE HASHED TABLE OF zreing_role_cat
                               WITH UNIQUE KEY table_line.
      DATA lt_pc_categories TYPE ty_role_cat_set.
      DATA(lt_diag_pc) = posting_pc_snapshot( ).
      LOOP AT lt_diag_pc INTO DATA(ls_diag_pc).
        IF ls_diag_pc-bruto_amt = 0
           AND ( mv_use_trans = abap_false OR ls_diag_pc-calc_amt = 0 OR has_ar_context( ) = abap_false ).
          CONTINUE.
        ENDIF.
        INSERT ls_diag_pc-role_category INTO TABLE lt_pc_categories.
      ENDLOOP.

      DATA lt_missing_roles TYPE string_table.
      LOOP AT lt_roles INTO DATA(ls_expected_role).
        DATA(ls_expected_master) =
          VALUE #( mt_role_master[ gl_role = ls_expected_role-role_code ] OPTIONAL ).
        IF ls_expected_master-role_type = 'T'.
          CONTINUE.
        ENDIF.

        DATA(lv_role_expected) = xsdbool(
          ls_expected_role-posting_context = 'AR'
          OR ls_expected_role-posting_context = 'AP'
          OR ( ls_expected_role-role_category IS INITIAL
               AND lt_pc_categories IS NOT INITIAL )
          OR line_exists(
               lt_pc_categories[ table_line = ls_expected_role-role_category ] ) ).

        DATA(lv_expected_role) = CONV string( ls_expected_role-role_code ).
        IF lv_role_expected = abap_true
           AND NOT line_exists( lt_items[ role_code = ls_expected_role-role_code ] )
           AND NOT line_exists( lt_missing_roles[ table_line = lv_expected_role ] ).
          APPEND lv_expected_role TO lt_missing_roles.
        ENDIF.
      ENDLOOP.
      " End Insert V010 (21.09.2026 | EXT_GONZALCA)

      DATA lt_tax_no_type TYPE string_table.
      LOOP AT lt_items INTO DATA(ls_bal_item).
        DATA(ls_bal_master) = VALUE #( mt_role_master[ gl_role = ls_bal_item-role_code ] OPTIONAL ).
        DATA(lv_bal_role) = CONV string( ls_bal_item-role_code ).
        IF ls_bal_master-role_type = 'T'
           AND ls_bal_master-tax_type IS INITIAL
           AND NOT line_exists( lt_tax_no_type[ table_line = lv_bal_role ] ).
          APPEND lv_bal_role TO lt_tax_no_type.
        ENDIF.
      ENDLOOP.

      " Begin Mod V010 (21.09.2026 | EXT_GONZALCA)
      DATA lt_balance_hints TYPE string_table.
      IF lt_missing_roles IS NOT INITIAL.
        APPEND |roles esperados sin posicion | &&
               |({ concat_lines_of( table = lt_missing_roles sep = `, ` ) })|
          TO lt_balance_hints.
      ENDIF.
      IF lt_tax_no_type IS NOT INITIAL.
        APPEND |roles de impuesto sin TAX_TYPE en ZREING_GL_ROLES | &&
               |({ concat_lines_of( table = lt_tax_no_type sep = `, ` ) })|
          TO lt_balance_hints.
      ENDIF.

      DATA(lv_bal_hint) = COND string(
        WHEN lt_balance_hints IS NOT INITIAL
        THEN |: { concat_lines_of( table = lt_balance_hints sep = `; ` ) }|
        ELSE `` ).
      " End Mod V010 (21.09.2026 | EXT_GONZALCA)

      rs_result = VALUE #(
        doc_type_code = mv_doc_type_code
        bukrs         = ls_header-bukrs
        blart         = ls_header-blart
        budat         = ls_header-budat
        waers         = ls_header-waers
        has_error     = abap_true
        error_msg     = |Documento { mv_doc_type_code } descuadrado en | &&
                        |{ lv_balance } { ls_header-waers }{ lv_bal_hint }|
        items         = lt_items ).
      RETURN.
    ENDIF.
    " End Insert V008 (17.09.2026 | EXT_GONZALCA)

    DATA(ls_bapi) = call_bapi( is_header = ls_header
                               it_items  = lt_items
                               iv_mode   = iv_mode ).
    DATA(lv_json) = serialize_payload( is_header = ls_header
                                       it_items  = lt_items
                                       is_result = ls_bapi ).

    rs_result = VALUE #(
      doc_type_code = mv_doc_type_code
      bukrs         = ls_header-bukrs
      belnr         = ls_bapi-belnr
      gjahr         = ls_bapi-gjahr
      blart         = ls_header-blart
      budat         = ls_header-budat
      reversal_date = ls_header-reversal_date
      waers         = ls_header-waers
      " Begin Mod V009 (21.09.2026 | EXT_GONZALCA)
      " CONTAB v41 defines TOTAL_AMOUNT as one side, not debit plus credit.
      total_amount  = calculate_total_amount( lt_items )
      " End Mod V009 (21.09.2026 | EXT_GONZALCA)
      has_error     = ls_bapi-has_error
      error_msg     = ls_bapi-error_msg
      payload       = lv_json
      items         = lt_items ).
  ENDMETHOD.

  METHOD find_roles_for_step.
    SELECT role_code, posting_side
      FROM zreing_doctype_r
      WHERE doc_type_code = @mv_doc_type_code
      INTO TABLE @DATA(lt_cfg).

    LOOP AT lt_cfg INTO DATA(ls_c).
      DATA(ls_master) = VALUE #( mt_role_master[ gl_role = ls_c-role_code ]
                                 OPTIONAL ).
      APPEND VALUE #(
        role_code       = ls_c-role_code
        posting_side    = ls_c-posting_side
        role_category   = ls_master-role_category
        posting_context = ls_master-posting_context
        tax_type        = ls_master-tax_type
        auto_determ     = ls_master-auto_determ
        reclassify      = ls_master-reclassify ) TO rt_roles.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_header.
    rs_header = VALUE #(
      bukrs         = mv_bukrs
      blart         = mv_blart
      budat         = determine_budat( )
      bldat         = cl_abap_context_info=>get_system_date( )
      waers         = posting_currency( )
      doc_type_code = mv_doc_type_code
      header_txt    = |REING { ms_line_a-op_type } { ms_line_a-calc_run_id }| ).

    " V001 (CC) - CB-02: propagate the validated literal rate only in V2.
    IF mv_use_trans = abap_true AND mv_trans_error IS INITIAL
       AND ms_line_a-exch_rate_1 <> zif_reing_ca_c=>fx_projection-identity_rate.
      rs_header-exch_rate_1 = ms_line_a-exch_rate_1.
      rs_header-exch_rate_is_set = abap_true.
    ENDIF.

    IF mv_auto_reversal = abap_true.
      rs_header-reversal_reason = mv_reversal_reason.
      " Begin Mod V002 (11.09.2026 | EXT_GONZALCA)
      " Misma correccion que determine_budat: la fecha de estorno automatico es
      " el primer dia del mes siguiente al PERIODO FISCAL DE LA LINEA (ET SS8.20
      " leida junto con SS8.12), no al DEFER_FROM. Con DEFER_FROM = 00000000 --
      " el caso de toda linea no diferida -- esto producia REVERSAL_DATE
      " '00000101'.
      " Statement original, para el registro:
      "    rs_header-reversal_date = calc_reversal_date(
      "      iv_gjahr  = ms_line_a-defer_from(4)
      "      iv_period = ms_line_a-defer_from+4(2) ).
      rs_header-reversal_date = calc_reversal_date(
        iv_gjahr  = mv_fiscal_year
        iv_period = mv_fiscal_period ).
      " End Mod V002 (11.09.2026 | EXT_GONZALCA)
    ENDIF.
  ENDMETHOD.

  METHOD calc_reversal_date.
    CONSTANTS lc_last_month TYPE monat VALUE 12.
    DATA(lv_year)  = iv_gjahr.
    DATA(lv_month) = iv_period.
    IF lv_month >= lc_last_month.
      lv_month = 1.
      lv_year  = lv_year + 1.
    ELSE.
      lv_month = lv_month + 1.
    ENDIF.
    rv_date = |{ lv_year WIDTH = 4 PAD = '0' }| &&
              |{ lv_month WIDTH = 2 PAD = '0' }01|.
  ENDMETHOD.

  METHOD determine_budat.
    " Begin Mod V002 (11.09.2026 | EXT_GONZALCA)
    " ET-REING-CONTAB-001 v41 SS8.12: BUDAT se determina comparando el PERIODO
    " FISCAL DE LA LINEA (GJAHR + periodo, o sea ZREING_CA_RUN_A) con el mes
    " actual del sistema. Si coinciden -> hoy; si no -> ultimo dia del periodo.
    "
    " La version anterior usaba ms_line_a-DEFER_FROM como fuente del periodo.
    " DEFER_FROM es un DATS que SOLO se llena en lineas diferidas: en el resto
    " vale 00000000, con lo cual '000000' nunca igualaba al mes actual y se caia
    " a la rama ELSE con gjahr = '0000' y periodo = '00'. calc_reversal_date
    " devolvia '00000101' y el - 1 daba una fecha invalida, asi que la cabecera
    " llegaba a la BAPI con PSTNG_DATE vacio. El Accounting Interface lo reporta
    " contra la primera posicion de deudor -- de ahi el mensaje enganoso
    " "En el parametro ACCOUNTRECEIVABLE no se traspaso el campo obligatorio
    " PSTNG_DATE" (BAPIACAR09 ni siquiera tiene ese campo) que Paola Romero
    " reporto el 11.09.2026 sobre RUN-202602 en TS4-400.
    " El fallo era sistematico para TODA linea sin diferimiento y en cualquier
    " DOC_TYPE_CODE; solo se veia en AR porque process_line hace EXIT en el
    " primer paso fallido y AR es el SEQ 010 del flujo de OP_TYPE F.
    "
    " Anio y periodo se comparan por separado contra sy-datum en vez de
    " concatenarlos en un string template: FISCAL_PERIOD es NUMC 2 y el
    " template dejaria el resultado a merced de la conversion de ceros.
    " Fallback a hoy si el run no se resolvio: una fecha valida del periodo
    " corriente es preferible a repetir el rechazo de la BAPI por campo vacio.
    " Statement original, para el registro:
    "    IF ms_line_a-defer_from(6) = lv_today(6).
    "      rv_budat = lv_today.
    "    ELSE.
    "      rv_budat = calc_reversal_date( iv_gjahr  = ms_line_a-defer_from(4)
    "                                     iv_period = ms_line_a-defer_from+4(2) ) - 1.
    "    ENDIF.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    IF mv_fiscal_year IS INITIAL OR mv_fiscal_period IS INITIAL.
      rv_budat = lv_today.
    ELSEIF mv_fiscal_year   = lv_today(4)
       AND mv_fiscal_period = lv_today+4(2).
      " Periodo de la linea = mes en curso -> fecha del servidor.
      rv_budat = lv_today.
    ELSE.
      " Periodo anterior -> ultimo dia del periodo (primer dia del mes
      " siguiente, que es lo que devuelve calc_reversal_date, menos uno).
      rv_budat = calc_reversal_date( iv_gjahr  = mv_fiscal_year
                                     iv_period = mv_fiscal_period ) - 1.
    ENDIF.
    " End Mod V002 (11.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD build_items.
    " Delta v2 (CON-01): apertura plana LPC_A x rol.
    " - Roles AR/AP (contrapartida BP, SS8.11): 1 item con el TOTAL de la linea.
    " - Roles GL: 1 item por profit center de LPC_A filtrado por role_category
    "   (append_gl_items encapsula el loop interno -> sin nested loop).
    " V001 (CC) — fixes-049 (Delta v2).
    " La base monetaria se determina por POSTING_CONTEXT: AR usa CALC_AMT y
    " AP usa BRUTO_AMT. Los documentos GL se resuelven en append_gl_items.
    DATA lv_bp_amount TYPE zreing_ca_line_a-net_amt.

    LOOP AT it_roles INTO DATA(ls_role).
      DATA(lv_hkont) = determine_account( ls_role ).
      CASE ls_role-posting_context.
        WHEN 'AR' OR 'AP'.
          " Begin Insert V005 (16.09.2026 | EXT_GONZALCA)
          " Bug #63: simetria con append_gl_items, que ya saltea sus filas en
          " cero (lado GL). Una posicion AR/AP de 0,00 no aporta saldo y deja
          " el documento con una sola posicion sin contrapartida, que la
          " Accounting Interface rechaza con "Saldo en moneda de transaccion".
          " Hoy is_applicable ya descarta la linea entera antes de llegar aca,
          " asi que esto es una segunda barrera deliberada: protege el caso en
          " que la cabecera netee cero pero la apertura tenga importes (linea
          " DELTA que reclasifica entre centros de beneficio), donde el
          " documento SI se arma y la posicion AR/AP seria la unica en 0,00.
          " Begin Mod V008 (17.09.2026 | EXT_GONZALCA)
          " El monto de la posicion de cliente / proveedor pasa de NET_AMT a
          " BRUTO_AMT, y el guard de saldo cero con el.
          " Definicion de Rochelle del 17.09.2026: "el indicador X-GrossingUp
          " define si el valor va a ser incrementado o no en cuentas a pagar;
          " cuando no esta marcado, no tiene impacto en el valor del AP". O
          " sea: la retencion NO reduce lo que se cobra / paga entre
          " sociedades -- viaja por las cuentas de retencion (RWHE / RWHP),
          " que se compensan entre si.
          " Es un desvio consciente de ET-REING-CONTAB-001 SS8.7 ("AR o AP:
          " monto = LINE_A.NET_AMT"): con el neto, un documento con impuesto
          " se descuadra por el importe del impuesto, porque ni AR ni AP
          " tienen un rol que lo absorba (AR = ARIC + GEXP). Pedido a Rochelle
          " actualizar la ET.
          " En las lineas CON gross-up el importe no cambia respecto de hoy:
          " hasta este fix NET_AMT era igual a BRUTO_AMT (TAX_AMT = 0 siempre).
          " Statements originales, para el registro:
          "          IF ms_line_a-net_amt IS INITIAL.
          "          amount = apply_sign( iv_amount = ms_line_a-net_amt ... )
          lv_bp_amount = COND zreing_ca_line_a-net_amt(
            WHEN ls_role-posting_context = 'AR'
            THEN posting_line_amount( abap_true )
            ELSE posting_line_amount( abap_false ) ).

          IF lv_bp_amount IS INITIAL.
            CONTINUE.
          ENDIF.
          " End Insert V005 (16.09.2026 | EXT_GONZALCA)
          APPEND VALUE #(
            role_code       = ls_role-role_code
            posting_context = ls_role-posting_context
            hkont           = lv_hkont
            partner         = COND #( WHEN ls_role-posting_context = 'AR'
                                      THEN mv_ar_partner ELSE mv_ap_partner )
            posting_side    = ls_role-posting_side
            amount          = apply_sign( iv_amount       = lv_bp_amount
                                          iv_posting_side = ls_role-posting_side )
            waers           = posting_currency( ) ) TO rt_items.
          " End Mod V008 (17.09.2026 | EXT_GONZALCA)
        WHEN OTHERS.
          append_gl_items( EXPORTING is_role  = ls_role
                                     iv_hkont = lv_hkont
                           CHANGING  ct_items = rt_items ).
      ENDCASE.
    ENDLOOP.

    " Numeracion secuencial global de items (loop simple, no anidado).
    LOOP AT rt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-item_num = sy-tabix.
      " Begin Insert V007 (16.09.2026 | EXT_GONZALCA)
      " Concepto interco (BSEG-ZUONR) en el loop que ya existia: cubre de una
      " sola pasada los items AR/AP construidos arriba y los GL construidos en
      " append_gl_items, sin tocar la firma de ese metodo. MV_ALLOC_NMBR lo
      " resolvio set_context una unica vez por documento -- aqui no hay
      " lectura de BD. ZCL_REING_CONTAB_DOC_RECL no necesita cambio: ya
      " propaga ZUONR desde los items del paso previo (zuonr = ls_pi-zuonr),
      " de modo que hereda este valor en cuanto la base lo escribe.
      <ls_item>-zuonr = mv_alloc_nmbr.
      " End Insert V007 (16.09.2026 | EXT_GONZALCA)
    ENDLOOP.
  ENDMETHOD.

  METHOD append_gl_items.
    " Delta v2 (CON-01): un item por profit center de LPC_A cuyo role_category
    " coincide con el del rol. Monto, PRCTR, CAMPANA y ALLOCATION de esa fila;
    " KOSTL recalculado (CON-02). item_num se asigna al final en build_items.
    " Begin Mod V003 (14.09.2026 | EXT_GONZALCA)
    " A blank ROLE_CATEGORY on the role master means "category-agnostic": the
    " role posts against EVERY LPC_A row, not only the rows whose category is
    " blank too. ZREING_CA_LPC_A only ever carries 'C' (COGS) or 'E' (Expenses),
    " never blank, so the previous strict comparison left the 19 of 25 roles of
    " ZREING_GL_ROLES that have no category unable to ever produce an item.
    " For DOC_TYPE_CODE 'AR' that dropped the whole GEXP counterpart and built a
    " one-sided document, which the Accounting Interface rejects as "Saldo en
    " moneda de transaccion <net_amt>" (RUN-202602 / TS4-400, reported
    " 14.09.2026).
    " Rows with a zero amount are skipped as well. They were unreachable while
    " the category comparison was strict, but the agnostic role now matches
    " them and every buffer item becomes a BAPI line:
    " ZCL_REING_CONTAB_FI_POSTER maps them one to one with no zero-amount
    " guard. Line 0000126 of RUN-202602, for instance, carries an ALLOCATION 0
    " row of 0,00 next to the real 9.420,68 one, so GEXP would emit a 0,00
    " posting line. The balance is unaffected, but the Accounting Interface may
    " reject the document and the rejection would look like this fix having
    " failed.
    " Statement original, para el registro:
    "    LOOP AT lt_post_pc INTO DATA(ls_pc)
    "        WHERE role_category = is_role-role_category.
    DATA(lt_post_pc) = posting_pc_snapshot( ).
    DATA(lv_all_categories) = xsdbool( is_role-role_category IS INITIAL ).
    " End Mod V003 (14.09.2026 | EXT_GONZALCA)

    " Begin Mod V008 (17.09.2026 | EXT_GONZALCA)
    " Dos cambios, los dos de ET-REING-CONTAB-001 SS8.7, disparados por el bug
    " de WHT sin gross-up que reporto Rochelle el 17.09.2026:
    "
    " 1) Rol GL SIN TAX_TYPE: el monto es el BRUTO_AMT de la fila de LPC_A, no
    "    el NET_AMT. Hasta hoy los dos daban lo mismo porque TAX_AMT era
    "    siempre 0 (ningun impuesto llegaba a calcularse); en cuanto el motor
    "    calcula la retencion, el gasto reintegrado tiene que seguir siendo el
    "    bruto o el documento se descuadra por el importe del impuesto.
    "
    " 2) Rol GL CON TAX_TYPE (Regla C): el monto sale de STEP_A.OUTPUT_AMT del
    "    paso TAX de ese TAX_TYPE, prorrateado. Antes se posteaba NET_AMT en
    "    TODA cuenta de mayor sin mirar tax_type, de modo que las cuentas de
    "    impuesto de Brasil (RWHE, RCIE, RCOA, RPIA...) recibian el importe
    "    completo de la linea en lugar del impuesto. mt_step_a ya viene cargada
    "    por set_context, asi que no hace falta ninguna lectura de BD.
    "
    "    Prorrateo (por fila i del subconjunto que matchea la categoria):
    "      amount_i = OUTPUT_AMT x SHARE_ABS_i / SUM(SHARE_ABS de TODAS las
    "                 filas de LPC_A)
    "    El denominador es el TOTAL, no el del subconjunto. El texto de la ET
    "    dice "entries filtradas", pero su propio ejemplo exige lo contrario
    "    (RCIC + RCIE = 210 = OUTPUT_AMT): con el denominador del subconjunto,
    "    el rol de COGS y el de Expenses se llevarian cada uno el impuesto
    "    ENTERO y el asiento quedaria al doble contra su contrapartida.
    "    Si SHARE_ABS viene en cero en toda la apertura (dato incompleto) se
    "    prorratea por BRUTO_AMT, que da la misma proporcion.
    "    El ULTIMO item del subconjunto recibe el residuo contra el TARGET del
    "    rol (su propia porcion), no contra el OUTPUT_AMT completo: de lo
    "    contrario un rol que matchea solo parte de la apertura se llevaria el
    "    impuesto entero. Con eso la suma de los items del rol es exactamente
    "    su porcion, y la suma de los roles C + E reproduce el OUTPUT_AMT
    "    (salvo, en el peor caso, un centavo de redondeo entre categorias).
    "    Sin paso TAX para ese TAX_TYPE (CA no calculo el impuesto) la role no
    "    genera ninguna linea, como dice la ET.
    " Statements originales, para el registro:
    "      IF ls_pc-net_amt IS INITIAL ...
    "      amount = apply_sign( iv_amount = ls_pc-net_amt ... )
    DATA lv_tax_total TYPE zreing_ca_line_a-net_amt.
    DATA lv_target    TYPE zreing_ca_line_a-net_amt.
    DATA lv_denom     TYPE decfloat34.
    DATA lv_matched   TYPE decfloat34.
    DATA lv_factor    TYPE decfloat34.
    DATA lv_use_share TYPE abap_bool.
    DATA lv_matches   TYPE i.
    DATA lv_emitted   TYPE i.
    DATA lv_assigned  TYPE zreing_ca_line_a-net_amt.
    DATA lv_amount    TYPE zreing_ca_line_a-net_amt.
    " V001 (CC) — fixes-049 (Delta v2).
    " AR usa la apertura CALC_AMT; AP y documentos solo GL conservan BRUTO_AMT.
    " TAX_TYPE mantiene STEP_A.OUTPUT_AMT y su prorrateo vigente.
    DATA(lv_is_ar_document) = xsdbool(
      line_exists( mt_role_master[ KEY by_context posting_context = 'AR' ] ) ).

    IF is_role-tax_type IS NOT INITIAL.
      DATA(ls_tax_step) = VALUE #( mt_step_a[ line_num = ms_line_a-line_num
        step_category = zif_reing_ca_c=>step_category-tax tax_type = is_role-tax_type ] OPTIONAL ).
      lv_tax_total = abs( COND #( WHEN mv_use_trans = abap_true
        THEN ls_tax_step-output_trans_amt ELSE ls_tax_step-output_amt ) ).
      IF lv_tax_total IS INITIAL.
        RETURN.
      ENDIF.

      lv_denom = REDUCE decfloat34( INIT s1 = 0 FOR ls_sh IN lt_post_pc
                                    NEXT s1 = s1 + ls_sh-share_abs ).
      lv_use_share = xsdbool( lv_denom > 0 ).
      IF lv_use_share = abap_false.
        lv_denom = REDUCE decfloat34( INIT s2 = 0 FOR ls_br IN lt_post_pc
                                      NEXT s2 = s2 + ls_br-bruto_amt ).
      ENDIF.
      IF lv_denom <= 0.
        RETURN.
      ENDIF.

      " Filas que matchean y su peso: las dos condiciones son EXACTAMENTE las
      " del LOOP de abajo, para que el residuo caiga en el ultimo item real.
      lv_matches = REDUCE i( INIT n = 0 FOR ls_mt IN lt_post_pc
                             NEXT n = COND #( WHEN ls_mt-bruto_amt IS NOT INITIAL
                                               AND ( lv_all_categories = abap_true
                                                     OR ls_mt-role_category = is_role-role_category )
                                              THEN n + 1
                                              ELSE n ) ).
      IF lv_matches = 0.
        RETURN.
      ENDIF.

      lv_matched = REDUCE decfloat34(
        INIT m = 0 FOR ls_mw IN lt_post_pc
        NEXT m = COND #( WHEN ls_mw-bruto_amt IS NOT INITIAL
                          AND ( lv_all_categories = abap_true
                                OR ls_mw-role_category = is_role-role_category )
                         THEN m + COND decfloat34( WHEN lv_use_share = abap_true
                                                   THEN ls_mw-share_abs
                                                   ELSE ls_mw-bruto_amt )
                         ELSE m ) ).
      DATA(lv_target_raw) = CONV decfloat34( lv_tax_total ) * lv_matched / lv_denom.
      lv_target = COND #( WHEN mv_use_trans = abap_true
        THEN round_trans_amount( lv_target_raw ) ELSE lv_target_raw ).
    ENDIF.

    LOOP AT lt_post_pc INTO DATA(ls_pc).
      lv_amount = COND zreing_ca_line_a-net_amt(
        WHEN is_role-tax_type IS INITIAL
             AND lv_is_ar_document = abap_true
        THEN ls_pc-calc_amt
        ELSE ls_pc-bruto_amt ).

      IF lv_amount IS INITIAL
         OR ( lv_all_categories = abap_false
              AND ls_pc-role_category <> is_role-role_category ).
        CONTINUE.
      ENDIF.

      IF is_role-tax_type IS NOT INITIAL.
        lv_emitted = lv_emitted + 1.
        IF lv_emitted = lv_matches.
          lv_amount = lv_target - lv_assigned.
          IF mv_use_trans = abap_true.
            lv_amount = round_trans_amount( iv_amount = CONV #( lv_amount ) iv_exact = abap_true ).
          ENDIF.
        ELSE.
          lv_factor   = COND #( WHEN lv_use_share = abap_true
                                THEN ls_pc-share_abs
                                ELSE ls_pc-bruto_amt ).
          DATA(lv_item_raw) = CONV decfloat34( lv_tax_total ) * lv_factor / lv_denom.
          lv_amount = COND #( WHEN mv_use_trans = abap_true
            THEN round_trans_amount( lv_item_raw ) ELSE lv_item_raw ).
          lv_assigned = lv_assigned + lv_amount.
        ENDIF.
      ENDIF.
      " End Mod V008 (17.09.2026 | EXT_GONZALCA)

      " V001 (CC) - CB-01: no zero nominal positions after TAX rounding.
      IF mv_use_trans = abap_true AND lv_amount = 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        role_code       = is_role-role_code
        posting_context = is_role-posting_context
        hkont           = iv_hkont
        posting_side    = is_role-posting_side
        amount          = apply_sign( iv_amount       = lv_amount
                                      iv_posting_side = is_role-posting_side )
        waers           = posting_currency( )
        kostl           = determine_kostl( iv_campana    = ls_pc-campana
                                           iv_allocation = ls_pc-allocation
                                           iv_prctr      = ls_pc-prctr
                                            iv_kostl_rule = ms_flow_step-kostl_rule
                                            iv_matnr      = ms_line_a-matnr )
        prctr           = ls_pc-prctr
        campana         = ls_pc-campana
        allocation      = ls_pc-allocation ) TO ct_items.
    ENDLOOP.
  ENDMETHOD.

  METHOD determine_account.
    IF is_role-posting_context = 'AR'.
      rv_hkont = mv_ar_recon_acct.
      RETURN.
    ELSEIF is_role-posting_context = 'AP'.
      rv_hkont = mv_ap_recon_acct.
      RETURN.
    ENDIF.
    rv_hkont = VALUE #( mt_gl_account[ gl_role = is_role-role_code ]-saknr
                        OPTIONAL ).
  ENDMETHOD.

  METHOD determine_kostl.
    " V001 (CC) - bug107 CONTAB: contract selection precedes the formula guard.
    IF iv_kostl_rule = zif_reing_ca_c=>kostl_rule-contract.
      IF ms_flow_step-bukrs_rule <> zif_reing_ca_c=>bukrs_rule_provider.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-invalid_company
                     iv_v1 = CONV #( mv_doc_type_code ) ).
        RETURN.
      ENDIF.
      IF mv_contract_kostl IS INITIAL.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-missing_contract
                     iv_v1 = CONV #( ms_line_a-ct_id )
                     iv_v2 = CONV #( ms_line_a-matnr )
                     iv_v3 = CONV #( mv_doc_type_code ) ).
        RETURN.
      ENDIF.
      rv_kostl = mv_contract_kostl.
      RETURN.
    ENDIF.
    " V001 (CC) - #121: validate the selected step and its exact in-memory mapping.
    IF iv_kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map.
      IF ms_flow_step-bukrs_rule <> zif_reing_ca_c=>bukrs_rule_override.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-invalid_override
                     iv_v1 = CONV #( mv_doc_type_code ) ).
        RETURN.
      ENDIF.
      IF iv_matnr IS INITIAL.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-missing_map
                     iv_v1 = CONV #( mv_doc_type_code )
                     iv_v2 = CONV #( iv_campana ) iv_v3 = CONV #( iv_matnr ) ).
        RETURN.
      ENDIF.
      READ TABLE mt_campana_map WITH TABLE KEY campana_de = iv_campana matnr = iv_matnr
        INTO DATA(ls_campana_map).
      IF sy-subrc <> 0.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-missing_map
                     iv_v1 = CONV #( mv_doc_type_code )
                     iv_v2 = CONV #( iv_campana ) iv_v3 = CONV #( iv_matnr ) ).
        RETURN.
      ENDIF.
      IF ls_campana_map-campana_para IS INITIAL.
        trans_error( iv_number = zif_reing_ca_c=>kostl_message-empty_destination
                     iv_v1 = CONV #( mv_doc_type_code )
                     iv_v2 = CONV #( iv_campana ) iv_v3 = CONV #( iv_matnr ) ).
        RETURN.
      ENDIF.
    ENDIF.
    " V001 (CC) - CB-04: validate the required code only when deriving a cost center.
    CONSTANTS lc_internal_code_msg TYPE symsgno VALUE '002'.
    IF mv_internal_code IS INITIAL.
      trans_error( iv_number = lc_internal_code_msg
                   iv_v1 = CONV #( mv_doc_type_code ) iv_v2 = CONV #( mv_bukrs ) ).
      RETURN.
    ENDIF.
    IF iv_kostl_rule = zif_reing_ca_c=>kostl_rule-campana_map.
      rv_kostl = |{ ls_campana_map-campana_para }{ iv_allocation }{ mv_internal_code }{ iv_prctr+7(3) }|.
      RETURN.
    ENDIF.
    " KOSTL(10) = CAMPANA(3) + ALLOCATION(1) + INTERNAL_CODE(3) + PRCTR ult.3.
    " Delta v2 (CON-02): CAMPANA y ALLOCATION vienen de LPC_A (por linea/PC),
    " no de CT2_GL_A.campaign; ALLOCATION reemplaza al viejo TIPO (mv_tipo).
    rv_kostl = |{ iv_campana }{ iv_allocation }{ mv_internal_code }{ iv_prctr+7(3) }|.
  ENDMETHOD.

  METHOD apply_sign.
    rv_amount = COND #( WHEN iv_posting_side = 'H'
                        THEN iv_amount * -1
                        ELSE iv_amount ).
  ENDMETHOD.

  METHOD calculate_balance.
    " Begin Insert V009 (21.09.2026 | EXT_GONZALCA)
    rv_balance = REDUCE zreing_ca_line_a-net_amt(
                   INIT b = CONV zreing_ca_line_a-net_amt( 0 )
                   FOR ls_item IN it_items
                   NEXT b = b + ls_item-amount ).
    " End Insert V009 (21.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD calculate_total_amount.
    " Begin Insert V009 (21.09.2026 | EXT_GONZALCA)
    " apply_sign represents effective debits as positive amounts and credits
    " as negative amounts, including operations whose original sign is reversed.
    rv_total = REDUCE zreing_ca_line_a-net_amt(
                 INIT t = CONV zreing_ca_line_a-net_amt( 0 )
                 FOR ls_item IN it_items WHERE ( amount > 0 )
                 NEXT t = t + ls_item-amount ).
    " End Insert V009 (21.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD build_item_text.
    " V001 (CC) - #122: preserve the ET separators and stored profit center.
    rv_text = |{ is_item-role_code }{ is_item-campana }{ is_item-prctr }| &&
      | \| { ms_line_a-bukrs_prest } X { ms_line_a-bukrs_recv }|.
  ENDMETHOD.

  METHOD adjust_rounding.
    " TODO SS8.15: penny rounding entre items GL vs item BP. Requiere la
    " logica de prorrateo por PC (build_items completo). Placeholder no-op
    " hasta que build_items genere el split por profit center (EN ESPERA de
    " la definicion de shares de ME, ver Anexo 8 de la guia).
    RETURN.
  ENDMETHOD.


  METHOD zif_reing_contab~set_fi_poster.
    mo_fi_poster = io_poster.
  ENDMETHOD.


  METHOD call_bapi.
    " Delega la contabilizacion en el poster FI (ZIF_REING_CONTAB_FI_POSTER).
    " El poster real (ZCL_REING_CONTAB_FI_POSTER) es una clase Standard ABAP
    " del paquete Tier2 que aisla las BAPIs clasicas. Esta clase (Cloud) solo
    " conoce la interface, nunca la clase concreta ni su nombre.
    "
    " INYECCION OBLIGATORIA: el poster se inyecta siempre desde afuera
    " (set_fi_poster), tipicamente desde el Engine (que lo recibio del adapter
    " del Bloque E). La clase Cloud NO instancia el poster (ni por nombre
    " dinamico): nombrar la clase Tier2 desde Cloud viola la frontera Clean
    " Core (ATC priority 1). En unit tests se inyecta un mock. Si no hay poster
    " inyectado -> error controlado (no dump).
    IF mo_fi_poster IS NOT BOUND.
      rs_result = VALUE #(
        has_error = abap_true
        error_msg = |Poster FI no inyectado (set_fi_poster requerido)| ).
      RETURN.
    ENDIF.
    rs_result = mo_fi_poster->post_document(
      is_header = is_header
      it_items  = it_items
      iv_mode   = iv_mode ).
  ENDMETHOD.

  METHOD serialize_payload.
    " V001 (CC) - CB-02: retain every legacy field and add the nominal header.
    IF mv_use_trans = abap_true.
      TYPES BEGIN OF ty_nominal_payload.
      INCLUDE TYPE zif_reing_contab_types=>ty_step_result.
      TYPES header TYPE zif_reing_contab_types=>ty_header.
      TYPES END OF ty_nominal_payload.
      DATA(ls_payload) = CORRESPONDING ty_nominal_payload(
        VALUE zif_reing_contab_types=>ty_step_result(
          doc_type_code = mv_doc_type_code bukrs = is_header-bukrs
          belnr = is_result-belnr items = it_items ) ).
      ls_payload-header = is_header.
      rv_json = /ui2/cl_json=>serialize( data = ls_payload ).
      RETURN.
    ENDIF.
    rv_json = /ui2/cl_json=>serialize(
      data = VALUE zif_reing_contab_types=>ty_step_result(
               doc_type_code = mv_doc_type_code
               bukrs         = is_header-bukrs
               belnr         = is_result-belnr
               items         = it_items ) ).
  ENDMETHOD.

  METHOD get_prev_step_doc_type.
    SELECT doc_type_code
      FROM zreing_docflow_c
      WHERE op_type = @ms_line_a-op_type
        AND seq     < @iv_current_seq
      ORDER BY seq DESCENDING
      INTO @rv_doc_type
      UP TO 1 ROWS.
    ENDSELECT.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_reing_contab
        EXPORTING iv_message = |No prev step for SEQ { iv_current_seq }|.
    ENDIF.
  ENDMETHOD.

  METHOD reverse_step.
    rs_result-doc_type_code = mv_doc_type_code.
    DATA(ls_orig) = VALUE #( mt_prior_docs[ doc_type_code = mv_doc_type_code ]
                             OPTIONAL ).
    IF ls_orig-belnr IS INITIAL.
      rs_result-has_error = abap_false.
      RETURN.
    ENDIF.
    IF mo_fi_poster IS NOT BOUND.
      rs_result-has_error = abap_true.
      rs_result-error_msg = |Poster FI no inyectado (set_fi_poster requerido)|.
      RETURN.
    ENDIF.
    DATA(lv_reason) = COND stgrd( WHEN mv_reversal_reason IS NOT INITIAL
                                  THEN mv_reversal_reason ELSE '01' ).
    DATA(ls_rev) = mo_fi_poster->reverse_document(
      iv_belnr      = ls_orig-belnr
      iv_bukrs      = ls_orig-bukrs
      iv_gjahr      = ls_orig-gjahr
      iv_reason     = lv_reason
      iv_pstng_date = determine_budat( ) ).
    rs_result-bukrs         = ls_orig-bukrs.
    rs_result-belnr         = ls_orig-belnr.
    rs_result-gjahr         = ls_orig-gjahr.
    rs_result-reverse_belnr = ls_rev-belnr.
    rs_result-has_error     = ls_rev-has_error.
    rs_result-error_msg     = ls_rev-error_msg.
  ENDMETHOD.

  METHOD get_maktx_cleaned.
    " Begin Insert V007 (16.09.2026 | EXT_GONZALCA)
    " Bug tracker #73, failure mode (d1): campo "Asignacion" (BSEG-ZUONR).
    " El mensaje "Llenar Asignacion con concepto" NO viene de SAP estandar ni
    " del motor: es la validacion propia de MELI Z00 607
    " (Check GS03:ZFI_INTERCO_CONCEPTOS). TY_DOC_ITEM ya declaraba ZUONR y
    " ZCL_REING_CONTAB_FI_POSTER ya lo mapeaba a ALLOC_NMBR y a ITEM_TEXT en
    " las tres tablas BAPI (AR/AP/GL, post_document:69-87), pero NADIE lo
    " llenaba en toda la cadena: viajaba vacio y la validacion rechazaba el
    " documento.
    "
    " Regla: ET-REING-CONTAB-001 v41 SS8.19. El pseudocodigo de la ET BORRA la
    " palabra "Reintegros", lo que para ICSRV45 ("Reintegros Licencias")
    " produce "Licencias" -- y ese valor NO existe en el set
    " ZFI_INTERCO_CONCEPTOS, que contiene "REINT LICENCIAS". Implementado al
    " pie de la letra el documento seguiria rechazado, solo que con otro
    " texto. Verificado contra los 41 valores del set en TS4-400 el
    " 16.09.2026 y confirmado por Rochelle: se REEMPLAZA "Reintegros" por
    " "REINT" y el resultado se pasa a mayusculas. Asi los cuatro materiales
    " de reintegro en uso caen exactamente sobre un valor del set:
    "   ICSRV44 "Reintegros Hosting"   -> REINT HOSTING
    "   ICSRV45 "Reintegros Licencias" -> REINT LICENCIAS
    "   ICSRV46 "Reintegros Marketing" -> REINT MARKETING
    "   ICSRV47 "Reintegros Shipping"  -> REINT SHIPPING
    "
    " LIMITACION CONOCIDA -- decision funcional abierta, NO resolver aca con
    " un mapeo inventado: ICSRV48/49/50/51 ("Hosting IA", "Fraud Prevention",
    " "Licencias IA IDEs", "Licencias IA LLMs") no tienen entrada en el set, y
    " tres de ellos ademas superan los 18 caracteres de DZUONR, con lo que se
    " truncarian en silencio. Hay que ampliar el set con valores de <= 18
    " caracteres, renombrar esos materiales, o pasar a una tabla de mapeo
    " material -> concepto.
    "
    " Dos desvios deliberados respecto del pseudocodigo de la ET:
    "  - La ET lee MAKT. Este paquete es ABAP for Cloud Development y la
    "    activacion rechaza la tabla ("El uso de Tabla MAKT no esta
    "    permitido"): se lee ZI_ReingCbProductText, proyeccion propia sobre la
    "    API liberada I_ProductDescription con el DCL desactivado -- mismo
    "    patron que ZI_ReingCbCustomerRecon y ZI_ReingCbSupplierRecon, creadas
    "    para este mismo metodo en fixes-009. Apuntar el SELECT a la I_* traeria
    "    de vuelta el AUTHORITY-CHECK(DCL) que ya dumpeo esta cadena.
    "  - to_upper ANTES del REPLACE, y no al reves, para que el resultado no
    "    dependa de como este escrita la mayuscula en el maestro de materiales.
    "    Con los datos actuales el resultado es identico. Se usa to_upper y no
    "    TRANSLATE porque el ATC marca TRANSLATE como deprecado.
    SELECT SINGLE productdescription FROM zi_reingcbproducttext
      WHERE product  = @iv_matnr
        AND language = 'S'
      INTO @DATA(lv_maktx).
    IF sy-subrc <> 0.
      lv_maktx = iv_matnr.
    ENDIF.
    lv_maktx = to_upper( lv_maktx ).
    REPLACE ALL OCCURRENCES OF 'REINTEGROS' IN lv_maktx WITH 'REINT'.
    CONDENSE lv_maktx.
    rv_alloc = lv_maktx.
    " End Insert V007 (16.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD trans_error.
    IF mv_trans_error IS NOT INITIAL. RETURN. ENDIF.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER iv_number WITH iv_v1 iv_v2 iv_v3 INTO mv_trans_error.
  ENDMETHOD.

  METHOD prepare_trans_context.
    CLEAR: ms_trans_projection, mv_use_trans, mv_trans_error, mv_trans_decimals.
    DATA lv_eba_off TYPE abap_bool.
    IF iv_eba_off IS SUPPLIED.
      lv_eba_off = iv_eba_off.
    ELSE.
      TEST-SEAM cb01_doc_guard.
        lv_eba_off = zcl_reing_ca_trans_amounts=>get_eba_off( ).
      END-TEST-SEAM.
    ENDIF.
    IF zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = ms_line_a-bukrs_prest iv_eba_off = lv_eba_off ) = abap_false.
      RETURN.
    ENDIF.
    TRY.
        DATA(ls_state) = zcl_reing_ca_trans_amounts=>inspect_fx( is_line = ms_line_a it_steps = mt_step_a ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_context).
        mv_trans_error = lx_context->mv_message.
        RETURN.
    ENDTRY.
    IF ls_state-is_v2 = abap_false. RETURN. ENDIF.
    DATA(ls_source_line) = is_projection-line.
    " LOCAL preview may be degraded by the pure helper; primary CT/TRANS may not.
    ls_source_line-net_local_amt = ms_line_a-net_local_amt.
    ls_source_line-exch_rate = ms_line_a-exch_rate.
    IF is_projection-use_trans = abap_false OR ls_source_line <> ms_line_a
       OR lines( is_projection-line_pc ) <> lines( mt_line_pc )
       OR lines( is_projection-steps ) <> lines( mt_step_a ).
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                   iv_v1 = CONV #( ms_line_a-line_num ) ).
      RETURN.
    ENDIF.
    ASSIGN it_currencies[ currency = ms_line_a-trans_currency ] TO FIELD-SYMBOL(<precision>).
    IF sy-subrc <> 0.
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-currency
                   iv_v1 = CONV #( ms_line_a-trans_currency ) ).
      RETURN.
    ENDIF.
    IF <precision>-decimals < 0 OR <precision>-decimals > zif_reing_ca_c=>fx_numeric-max_currency_decimals.
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-currency
                   iv_v1 = CONV #( ms_line_a-trans_currency ) ).
      RETURN.
    ENDIF.
    mv_trans_decimals = <precision>-decimals.
    DATA(lv_same_currency) = xsdbool( ms_line_a-ct_currency = ms_line_a-trans_currency ).
    DATA(lv_expected_calc) = ms_line_a-calc_amt.
    DATA(lv_expected_bruto) = ms_line_a-bruto_amt.
    IF lv_same_currency = abap_false.
      lv_expected_calc = round_trans_amount(
         CONV decfloat34( ms_line_a-calc_amt ) * CONV decfloat34( ms_line_a-exch_rate_1 ) )
        .
      lv_expected_bruto = round_trans_amount(
         CONV decfloat34( ms_line_a-bruto_amt ) * CONV decfloat34( ms_line_a-exch_rate_1 ) ).
    ENDIF.
    IF is_projection-calc_trans_amt <> lv_expected_calc OR is_projection-bruto_trans_amt <> lv_expected_bruto.
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                   iv_v1 = CONV #( ms_line_a-line_num ) ).
      RETURN.
    ENDIF.
    TYPES tt_pc_keys TYPE HASHED TABLE OF zreing_ca_lpc_a
      WITH UNIQUE KEY calc_run_id line_num pc_seq.
    DATA lt_pc_keys TYPE tt_pc_keys.
    DATA lv_calc_sum TYPE decfloat34.
    DATA lv_bruto_sum TYPE decfloat34.
    DATA lv_net_sum TYPE decfloat34.
    LOOP AT mt_line_pc INTO DATA(ls_pc).
      INSERT ls_pc INTO TABLE lt_pc_keys.
      IF sy-subrc <> 0 OR ls_pc-calc_run_id <> ms_line_a-calc_run_id
         OR ls_pc-line_num <> ms_line_a-line_num.
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
      ASSIGN is_projection-line_pc[ calc_run_id = ls_pc-calc_run_id
        line_num = ls_pc-line_num pc_seq = ls_pc-pc_seq ] TO FIELD-SYMBOL(<projected_pc>).
      IF sy-subrc <> 0.
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
      DATA(ls_source_pc) = CORRESPONDING zreing_ca_lpc_a( <projected_pc> ).
      IF ls_source_pc-prctr IS NOT INITIAL.
        ls_source_pc-prctr = |{ ls_source_pc-prctr ALPHA = IN }|.
      ENDIF.
      ls_source_pc-net_local_amt = ls_pc-net_local_amt.
      ls_source_pc-local_currency = ls_pc-local_currency.
      IF ls_source_pc <> ls_pc
         OR ( lv_same_currency = abap_false AND ( <projected_pc>-calc_trans_amt <> round_trans_amount(
              iv_amount = CONV #( <projected_pc>-calc_trans_amt ) iv_exact = abap_true )
         OR <projected_pc>-bruto_trans_amt <> round_trans_amount(
              iv_amount = CONV #( <projected_pc>-bruto_trans_amt ) iv_exact = abap_true )
         OR <projected_pc>-net_trans_amt <> round_trans_amount(
              iv_amount = CONV #( <projected_pc>-net_trans_amt ) iv_exact = abap_true ) ) ).
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
      lv_calc_sum += <projected_pc>-calc_trans_amt.
      lv_bruto_sum += <projected_pc>-bruto_trans_amt.
      lv_net_sum += <projected_pc>-net_trans_amt.
    ENDLOOP.
    IF lv_calc_sum <> is_projection-calc_trans_amt
       OR lv_bruto_sum <> is_projection-bruto_trans_amt OR lv_net_sum <> ms_line_a-net_trans_amt.
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                   iv_v1 = CONV #( ms_line_a-line_num ) ).
      RETURN.
    ENDIF.
    TYPES tt_step_keys TYPE HASHED TABLE OF zreing_ca_step_a
      WITH UNIQUE KEY calc_run_id line_num step_num seq.
    DATA lt_step_keys TYPE tt_step_keys.
    LOOP AT is_projection-steps INTO DATA(ls_projected_step).
      INSERT ls_projected_step INTO TABLE lt_step_keys.
      IF sy-subrc <> 0.
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_step_a INTO DATA(ls_step).
      ASSIGN lt_step_keys[ calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num
        step_num = ls_step-step_num seq = ls_step-seq ] TO FIELD-SYMBOL(<projected_step>).
      IF sy-subrc <> 0.
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
      DATA(ls_source_step) = <projected_step>.
      IF ls_step-step_num = zif_reing_ca_c=>fx_step-number
         AND ls_step-seq = zif_reing_ca_c=>fx_step-local_seq.
        ls_source_step-output_amt = ls_step-output_amt.
        ls_source_step-output_currency = ls_step-output_currency.
        ls_source_step-rate_pct = ls_step-rate_pct.
        ls_source_step-step_desc = ls_step-step_desc.
      ENDIF.
      IF ls_source_step <> ls_step
         OR ( lv_same_currency = abap_false AND <projected_step>-output_trans_amt <> round_trans_amount(
              iv_amount = CONV #( <projected_step>-output_trans_amt ) iv_exact = abap_true ) ).
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-memory
                     iv_v1 = CONV #( ms_line_a-line_num ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
    IF mv_trans_error IS NOT INITIAL. RETURN. ENDIF.
    " ENGINE verifies the canonical dimensional distribution once per line.
    ms_trans_projection = is_projection.
    mv_use_trans = abap_true.
  ENDMETHOD.

  METHOD posting_currency.
    rv_currency = COND #( WHEN mv_use_trans = abap_true
      THEN ms_line_a-trans_currency ELSE ms_line_a-ct_currency ).
  ENDMETHOD.

  METHOD posting_line_amount.
    IF mv_use_trans = abap_true.
      rv_amount = COND #( WHEN iv_ar = abap_true
        THEN ms_trans_projection-calc_trans_amt ELSE ms_trans_projection-bruto_trans_amt ).
    ELSE.
      rv_amount = COND #( WHEN iv_ar = abap_true THEN ms_line_a-calc_amt ELSE ms_line_a-bruto_amt ).
    ENDIF.
  ENDMETHOD.

  METHOD posting_pc_snapshot.
    rt_pcs = mt_line_pc.
    IF mv_use_trans = abap_false. RETURN. ENDIF.
    " Only this private posting copy carries nominal TRANS; native CT stays intact.
    LOOP AT rt_pcs ASSIGNING FIELD-SYMBOL(<pc>).
      DATA(ls_trans) = ms_trans_projection-line_pc[ calc_run_id = <pc>-calc_run_id
        line_num = <pc>-line_num pc_seq = <pc>-pc_seq ].
      <pc>-calc_amt = ls_trans-calc_trans_amt.
      <pc>-bruto_amt = ls_trans-bruto_trans_amt.
      <pc>-net_amt = ls_trans-net_trans_amt.
      <pc>-ct_currency = ms_line_a-trans_currency.
    ENDLOOP.
    SORT rt_pcs BY calc_run_id line_num pc_seq.
  ENDMETHOD.

  METHOD has_ar_context.
    CONSTANTS lc_context TYPE zreing_posting_context VALUE 'AR'.
    rv_ar = xsdbool( line_exists( mt_role_master[ KEY by_context posting_context = lc_context ] ) ).
  ENDMETHOD.

  METHOD trans_is_applicable.
CONSTANTS lc_ar TYPE zreing_posting_context VALUE 'AR'.
    CONSTANTS lc_ap TYPE zreing_posting_context VALUE 'AP'.
    TYPES tt_categories TYPE HASHED TABLE OF zreing_role_cat WITH UNIQUE KEY table_line.
    TYPES: BEGIN OF ty_tax,
             tax_type TYPE zreing_tax_type,
             amount TYPE decfloat34,
           END OF ty_tax,
           tt_taxes TYPE HASHED TABLE OF ty_tax WITH UNIQUE KEY tax_type,
           BEGIN OF ty_weight,
             category TYPE zreing_role_cat,
             total TYPE decfloat34,
             last TYPE decfloat34,
             max_nonlast TYPE decfloat34,
             count TYPE i,
           END OF ty_weight,
           tt_weights TYPE HASHED TABLE OF ty_weight WITH UNIQUE KEY category.
    DATA lt_gl_categories TYPE tt_categories.
    DATA lt_tax_categories TYPE tt_categories.
    DATA lt_taxes TYPE tt_taxes.
    DATA lt_weights TYPE tt_weights.
    DATA ls_all TYPE ty_weight.
    DATA lv_gl_all TYPE abap_bool.
    DATA lv_tax_all TYPE abap_bool.
    DATA lv_movement TYPE abap_bool.
    DATA(lv_ar) = has_ar_context( ).
    DATA lv_sum_share TYPE decfloat34.
    DATA lv_sum_bruto TYPE decfloat34.
    LOOP AT ms_trans_projection-line_pc INTO DATA(ls_weight).
      lv_sum_share += ls_weight-share_abs.
      lv_sum_bruto += ls_weight-bruto_trans_amt.
    ENDLOOP.
    DATA(lv_denom) = COND decfloat34( WHEN lv_sum_share > 0 THEN lv_sum_share ELSE lv_sum_bruto ).
    LOOP AT ms_trans_projection-line_pc INTO DATA(ls_weight_pc).
      IF ls_weight_pc-bruto_trans_amt = 0.
        CONTINUE.
      ENDIF.
      DATA(lv_weight) = COND decfloat34( WHEN lv_sum_share > 0
        THEN ls_weight_pc-share_abs ELSE ls_weight_pc-bruto_trans_amt ).
      IF ls_all-count > 0.
        ls_all-max_nonlast = nmax( val1 = ls_all-max_nonlast val2 = abs( ls_all-last ) ).
      ENDIF.
      ls_all-total += lv_weight.
      ls_all-last = lv_weight.
      ls_all-count += 1.
      ASSIGN lt_weights[ category = ls_weight_pc-role_category ] TO FIELD-SYMBOL(<weight>).
      IF sy-subrc <> 0.
        INSERT VALUE #( category = ls_weight_pc-role_category ) INTO TABLE lt_weights ASSIGNING <weight>.
      ENDIF.
      IF <weight>-count > 0.
        <weight>-max_nonlast = nmax( val1 = <weight>-max_nonlast val2 = abs( <weight>-last ) ).
      ENDIF.
      <weight>-total += lv_weight.
      <weight>-last = lv_weight.
      <weight>-count += 1.
    ENDLOOP.
    LOOP AT mt_step_a INTO DATA(ls_tax) WHERE step_category = zif_reing_ca_c=>step_category-tax.
      " Match the builder's first physical TAX step for each tax type.
      INSERT VALUE #( tax_type = ls_tax-tax_type amount = abs( ls_tax-output_trans_amt ) ) INTO TABLE lt_taxes.
    ENDLOOP.
    LOOP AT mt_role_master INTO DATA(ls_role).
      CASE ls_role-posting_context.
        WHEN lc_ar.
          IF ms_trans_projection-calc_trans_amt <> 0.
            rv_applicable = abap_true. RETURN.
          ENDIF.
        WHEN lc_ap.
          IF ms_trans_projection-bruto_trans_amt <> 0.
            rv_applicable = abap_true. RETURN.
          ENDIF.
        WHEN OTHERS.
          IF ls_role-tax_type IS INITIAL.
            IF ls_role-role_category IS INITIAL.
              lv_gl_all = abap_true.
            ELSE.
              INSERT ls_role-role_category INTO TABLE lt_gl_categories.
            ENDIF.
          ELSEIF lv_denom > 0.
            DATA(ls_tax_amount) = VALUE #( lt_taxes[ tax_type = ls_role-tax_type ] OPTIONAL ).
            DATA(ls_selected) = COND ty_weight( WHEN ls_role-role_category IS INITIAL
              THEN ls_all ELSE VALUE #( lt_weights[ category = ls_role-role_category ] OPTIONAL ) ).
            IF ls_tax_amount-amount <> 0 AND ls_selected-count > 0.
              DATA(lv_target) = round_trans_amount( ls_tax_amount-amount * ls_selected-total / lv_denom ).
              DATA(lv_nonlast) = round_trans_amount( ls_tax_amount-amount * ls_selected-max_nonlast / lv_denom ).
              IF lv_target <> 0 OR lv_nonlast <> 0.
                IF ls_role-role_category IS INITIAL.
                  lv_tax_all = abap_true.
                ELSE.
                  INSERT ls_role-role_category INTO TABLE lt_tax_categories.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
      ENDCASE.
    ENDLOOP.
    IF mv_trans_error IS NOT INITIAL.
      rv_applicable = abap_true. RETURN.
    ENDIF.
    LOOP AT ms_trans_projection-line_pc INTO DATA(ls_pc).
      DATA(lv_base) = COND #( WHEN lv_ar = abap_true
        THEN ls_pc-calc_trans_amt ELSE ls_pc-bruto_trans_amt ).
      IF lv_base <> 0 OR ls_pc-calc_trans_amt <> 0 OR ls_pc-bruto_trans_amt <> 0.
        lv_movement = abap_true.
      ENDIF.
      IF ( lv_base <> 0 AND ( lv_gl_all = abap_true
             OR line_exists( lt_gl_categories[ table_line = ls_pc-role_category ] ) ) )
         OR ( ls_pc-bruto_trans_amt <> 0 AND ( lv_tax_all = abap_true
             OR line_exists( lt_tax_categories[ table_line = ls_pc-role_category ] ) ) ).
        rv_applicable = abap_true. RETURN.
      ENDIF.
    ENDLOOP.
    IF mt_role_master IS INITIAL AND ( lv_movement = abap_true
         OR ms_trans_projection-calc_trans_amt <> 0 OR ms_trans_projection-bruto_trans_amt <> 0 ).
      trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
                   iv_v1 = CONV #( ms_line_a-line_num ) ).
      rv_applicable = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD round_trans_amount.
    TRY.
        DATA(lv_rounded) = round( val = iv_amount dec = mv_trans_decimals
          mode = cl_abap_math=>round_half_up ).
        IF iv_exact = abap_true AND lv_rounded <> iv_amount.
          trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-residual
                       iv_v1 = CONV #( posting_currency( ) ) ).
          RETURN.
        ENDIF.
        rv_amount = CONV #( lv_rounded ).
        IF CONV decfloat34( rv_amount ) <> lv_rounded.
          CLEAR rv_amount.
          trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-amount
            iv_v1 = CONV #( iv_amount ) iv_v2 = CONV #( posting_currency( ) ) ).
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        trans_error( iv_number = zif_reing_ca_c=>fx_projection_message-amount
          iv_v1 = CONV #( ms_line_a-line_num ) iv_v2 = CONV #( posting_currency( ) ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

