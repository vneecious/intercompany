CLASS zcl_im_im_fi_int_sap01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_ex_fi_int_sap01 .
  PROTECTED SECTION.
  PRIVATE SECTION.

    " ============================================================================
    " Interés de Mora (SDFPSINIC-23382) — implementación de la BAdI FI_INT_SAP01.
    " Sólo lógica de Mora. La activación se controla por el parámetro TVARVC
    " ZFI_MORA_INT_ACTIVE (leído vía ZCL_TVARVC): si no está activo, cada método
    " de Mora hace early-return. int_formula permanece vacío.
    " ============================================================================

    TYPES:
      BEGIN OF ty_bseg_key,
        bukrs    TYPE bukrs,
        belnr    TYPE belnr_d,
        gjahr    TYPE gjahr,
        buzei    TYPE buzei,
        vbund    TYPE vbund,
        zinkz    TYPE char1,
        kostl    TYPE kostl,
        prctr    TYPE prctr,
        matnr    TYPE matnr,
        concepto TYPE xblnr1,
        waers    TYPE waers,
      END OF ty_bseg_key,
      tt_bseg_key TYPE HASHED TABLE OF ty_bseg_key
                  WITH UNIQUE KEY bukrs belnr gjahr buzei,

      BEGIN OF ty_glacct,
        provider_company_code  TYPE zint_a_md_glacct-provider_company_code,
        recipient_company_code TYPE zint_a_md_glacct-recipient_company_code,
        product                TYPE zint_a_md_glacct-product,
        gl_account1            TYPE zint_a_md_glacct-gl_account1,
        gl_account2            TYPE zint_a_md_glacct-gl_account2,
        doc_type               TYPE zint_a_md_glacct-doc_type,
      END OF ty_glacct,
      tt_glacct TYPE HASHED TABLE OF ty_glacct
                WITH UNIQUE KEY provider_company_code recipient_company_code product doc_type.

    " -- Rework AP_InterestMora_Fix: tabla prctr+kostl+amount por doc origen --
    TYPES: BEGIN OF ty_ceco_line,
             prctr  TYPE prctr,
             kostl  TYPE kostl,
             amount TYPE wrbtr,
           END OF ty_ceco_line.
    TYPES: tt_ceco_lines TYPE STANDARD TABLE OF ty_ceco_line WITH EMPTY KEY.

    DATA mt_je_post TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.

    " Buffer de mapeo origen->consolidado para ZFINT_POST_LOG (trazabilidad EF §7.2.4)
    " Estructura interna = zfint_post_log + campos de cruce (array) y numeros de
    " los documentos BAdI (AP/RR), capturados en int_post para uso en end_of_programm.
    TYPES BEGIN OF ty_post_log.
    INCLUDE TYPE zfint_post_log.
    TYPES array    TYPE int_group.
    TYPES belnr_ap TYPE belnr_d.
    TYPES belnr_rr TYPE belnr_d.
    TYPES END OF ty_post_log.
    DATA mt_post_log TYPE STANDARD TABLE OF ty_post_log.
    " Mensajes de error de las BAPIs (IR/CH); el ct_log del FINT se descarta
    " cuando cd_post_status='ERROR' (raise), por eso se capturan aqui para
    " volcarlos a ZFINT_POST_LOG en end_of_programm.
    DATA mt_err_log  TYPE STANDARD TABLE OF zfint_post_log.
    " Flag de error de contabilizacion BAPI (ROLLBACK/COMMIT en end_of_programm)
    DATA mv_post_error TYPE abap_bool.
    " [SDFPSINIC-23382] Clave completa (BKTXT) transportada de int_post a post_ap/post_reclass (AR/AP/CH).
    DATA mv_ref_key TYPE c LENGTH 25.

    " Clientes con indicador de interés TR. Se carga desde CT/IT_KNB1 y se utiliza
    " únicamente para desviar esos registros de la lógica actual de Mora.
    DATA mt_tr_knb1 TYPE fint_tt_knb1.

    CONSTANTS:
      c_tvarvc_active       TYPE tvarvc-name VALUE 'ZFI_MORA_INT_ACTIVE',
      c_doctype_ap          TYPE blart      VALUE 'IR',
      c_doctype_recl        TYPE blart      VALUE 'CH',
      c_doctype_ic          TYPE blart                     VALUE 'IC',
      c_glkey_ic            TYPE zint_a_md_glacct-doc_type VALUE 'AR',
      c_glkey_ir            TYPE zint_a_md_glacct-doc_type VALUE 'AP',
      c_glkey_ch            TYPE zint_a_md_glacct-doc_type VALUE 'RR',
      c_bus_act             TYPE c LENGTH 4 VALUE 'RFBU',
      c_ledger_recl         TYPE c LENGTH 4 VALUE '0LL1',
      c_gl_clearing         TYPE hkont      VALUE '0000469001',
      c_ccyrole_doc         TYPE c LENGTH 2 VALUE '00',
      c_tariff_late_payment TYPE zint_a_md_glacct-tariff_type VALUE '04',
      c_bp_prestadora       TYPE lifnr      VALUE 'IC0122'.

    METHODS:
      is_mora_active
        RETURNING VALUE(rv_active) TYPE abap_bool,

      remember_tr_customers
        IMPORTING
          it_knb1 TYPE fint_tt_knb1,

      is_tr_item
        IMPORTING
                  is_item      TYPE any
        RETURNING VALUE(rv_tr) TYPE abap_bool,

      call_tr_process.

    " [TR] Chamada dinâmica a um método da classe TR (ZTR_C000123_AMORT_FINANC_VEIC),
    " enviando só os itens TR. Sem dependência estática da classe.
    METHODS call_tr_class
      IMPORTING
        iv_method TYPE seocpdname
      CHANGING
        ct_items  TYPE fint_tt_intit_extf.

    CLASS-METHODS:
      get_bseg_data
        IMPORTING
          it_items       TYPE fint_tt_intit_extf
        RETURNING
          VALUE(rt_bseg) TYPE tt_bseg_key,

      get_quarter_close_date
        IMPORTING
          iv_date_ref    TYPE datum
        RETURNING
          VALUE(rv_date) TYPE datum,

      get_exchange_rate
        IMPORTING
          iv_fcurr       TYPE waers
          iv_date        TYPE datum
        RETURNING
          VALUE(rv_rate) TYPE tcurr-ukurs,

      convert_to_usd
        IMPORTING
          iv_amount     TYPE wrbtr
          iv_waers      TYPE waers
          iv_date       TYPE datum
        RETURNING
          VALUE(rv_usd) TYPE wrbtr,

      append_log_warn
        IMPORTING
          iv_msgid TYPE symsgid
          iv_msgno TYPE symsgno
          iv_msgv1 TYPE clike OPTIONAL
          iv_msgv2 TYPE clike OPTIONAL
          iv_text  TYPE clike OPTIONAL
        CHANGING
          ct_log   TYPE fint_tt_log,

      get_run_date
        IMPORTING
          it_frange      TYPE fint_frange_t
        RETURNING
          VALUE(rv_date) TYPE dats.

    METHODS:
      build_ap_document_eml
        IMPORTING
          is_t001   TYPE t001
          is_ipf    TYPE intipf
          it_accit  TYPE fint_tt_accit
          it_bseg   TYPE tt_bseg_key
          it_glacct TYPE tt_glacct,

      build_reclass_document_eml
        IMPORTING
          is_t001   TYPE t001
          is_ipf    TYPE intipf
          it_accit  TYPE fint_tt_accit
          it_bseg   TYPE tt_bseg_key
          it_glacct TYPE tt_glacct.

    METHODS:
      is_post_by_bapi
        RETURNING VALUE(rv_bapi) TYPE abap_bool.

    METHODS:
      get_bapi_post_fm
        RETURNING VALUE(rv_fm) TYPE rs38l_fnam.

    METHODS:
      post_ap_document_bapi
        IMPORTING
          is_t001     TYPE t001
          is_ipf      TYPE intipf
          is_glacct   TYPE ty_glacct
          it_cecos    TYPE tt_ceco_lines
          it_accit    TYPE fint_tt_accit
          it_acccr    TYPE fint_tt_acccr
          iv_vbund    TYPE vbund OPTIONAL
          iv_amount   TYPE wrbtr
          iv_doc_date TYPE dats OPTIONAL
          iv_testrun  TYPE abap_bool DEFAULT abap_false
        EXPORTING
          ev_error    TYPE abap_bool
          ev_doc_no   TYPE belnr_d
        CHANGING
          ct_log      TYPE fint_tt_log.

    METHODS:
      post_reclassification_bapi
        IMPORTING
          is_t001     TYPE t001
          is_ipf      TYPE intipf
          is_glacct   TYPE ty_glacct
          it_cecos    TYPE tt_ceco_lines
          it_accit    TYPE fint_tt_accit
          it_acccr    TYPE fint_tt_acccr
          iv_vbund    TYPE vbund OPTIONAL
          iv_amount   TYPE wrbtr
          iv_doc_date TYPE dats OPTIONAL
          iv_testrun  TYPE abap_bool DEFAULT abap_false
        EXPORTING
          ev_error    TYPE abap_bool
          ev_doc_no   TYPE belnr_d
        CHANGING
          ct_log      TYPE fint_tt_log.

    METHODS:
      determine_glacct
        IMPORTING
                  it_glacct        TYPE tt_glacct
                  iv_bukrs         TYPE bukrs
                  iv_vbund         TYPE vbund
                  iv_concepto      TYPE xblnr1
                  iv_doc_type      TYPE zint_a_md_glacct-doc_type
        RETURNING VALUE(rs_glacct) TYPE ty_glacct.

    METHODS:
      adjust_customer_accit
        IMPORTING
          is_t056u_ext TYPE fint_ts_t056u_ext
          iv_netdt     TYPE dats OPTIONAL
        CHANGING
          ct_accit     TYPE fint_tt_accit.

    METHODS:
      get_source_ceco
        IMPORTING
          iv_bukrs        TYPE bukrs
          iv_belnr        TYPE belnr_d
          iv_gjahr        TYPE gjahr
        RETURNING
          VALUE(rt_cecos) TYPE tt_ceco_lines.

ENDCLASS.



CLASS zcl_im_im_fi_int_sap01 IMPLEMENTATION.


  METHOD adjust_customer_accit.
    " Ajusta la linea de cliente (KOART='D') en ct_accit antes del posting del Doc1.
    " (1) UMSKZ='+': el FINT pre-popula este placeholder interno; la clave de
    "     contabilizacion 01 (Debe Cliente) no lo acepta con doc type 'IC' (msg F5761
    "     'Clave de contabilizacion 01 no permite indicador CME'). El standard CUS01
    "     evita esto reconstruyendo ct_accit; aqui se limpia puntualmente.
    " (2) ZTERM: se seta desde el indicador de interes (patron standard CUS01).
    " (3) NETDT: si viene informado (get_run_date del run FINT), se seta como fecha
    "     de vencimiento de la partida de interes (EF: 'Fecha del run FINT').
    " (1) Limpiar UMSKZ='+' en TODAS las lineas: el FINT pre-popula '+' como
    "     placeholder interno; las claves 01, 31, 50 no lo aceptan (msg F5761).
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_accit_d>)
      WHERE umskz = '+'.
      CLEAR <ls_accit_d>-umskz.
    ENDLOOP.

    " (1b) Limpiar SHKZG en lineas BSCHL='31' (IC partner intercompany): el FINT
    "      pre-popula 'S' pero PK31 deriva 'H'. Segun msg F5846: la aplicacion
    "      puede prescindir del indicador y dejar que el servicio FI lo derive.
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_accit_31>)
      WHERE bschl = '31'.
      CLEAR <ls_accit_31>-shkzg.
    ENDLOOP.

    " (2) ZTERM y NETDT: solo en la linea del cliente (KOART='D')
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_accit_c>)
      WHERE koart = 'D'.
      IF is_t056u_ext-zterm IS NOT INITIAL.
        <ls_accit_c>-zterm = is_t056u_ext-zterm.
      ENDIF.
      IF iv_netdt IS SUPPLIED AND iv_netdt IS NOT INITIAL.
        <ls_accit_c>-netdt = iv_netdt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_log_warn.
    DATA ls_log_line LIKE LINE OF ct_log.
    ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_ty>).
    ASSIGN COMPONENT 'MSGID' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_id>).
    ASSIGN COMPONENT 'MSGNO' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_no>).
    ASSIGN COMPONENT 'MSGV1' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_v1>).
    ASSIGN COMPONENT 'MSGV2' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_v2>).
    IF <f_ty> IS ASSIGNED. <f_ty> = 'W'.      ENDIF.
    IF <f_id> IS ASSIGNED. <f_id> = iv_msgid. ENDIF.
    IF <f_no> IS ASSIGNED. <f_no> = iv_msgno. ENDIF.
    IF <f_v1> IS ASSIGNED AND iv_msgv1 IS SUPPLIED. <f_v1> = iv_msgv1. ENDIF.
    IF <f_v2> IS ASSIGNED AND iv_msgv2 IS SUPPLIED. <f_v2> = iv_msgv2. ENDIF.
    IF iv_text IS SUPPLIED AND iv_text IS NOT INITIAL.
      ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_log_line TO FIELD-SYMBOL(<f_txt>).
      IF <f_txt> IS ASSIGNED. <f_txt> = iv_text. ENDIF.
    ENDIF.
    APPEND ls_log_line TO ct_log.
  ENDMETHOD.


  METHOD build_ap_document_eml.
    DATA(lv_close) = get_quarter_close_date( is_ipf-netdt ).
    DATA(lv_kursf) = get_exchange_rate( iv_fcurr = is_ipf-int_curr
                                        iv_date  = lv_close ).
    DATA(lv_htxt)  = |INT MORA IC Q{ lv_close+4(2) } { lv_close(4) }|.

    DATA ls_je TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post.
    ls_je-%cid                                = |MORA{ lines( mt_je_post ) + 1 }|.
    ls_je-%param-companycode                  = is_t001-bukrs.
    ls_je-%param-accountingdocumenttype       = c_doctype_ap.
    ls_je-%param-businesstransactiontype      = c_bus_act.
    ls_je-%param-accountingdocumentheadertext = lv_htxt.
    ls_je-%param-documentdate                 = is_ipf-netdt.
    ls_je-%param-postingdate                  = is_ipf-netdt.
    ls_je-%param-createdbyuser                = sy-uname.
    ls_je-%param-documentreferenceid          = is_ipf-int_belnr.

    DATA lv_item  TYPE n LENGTH 6 VALUE 1.
    DATA lv_matnr TYPE productnumber.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_accit>).

      READ TABLE it_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = is_t001-bukrs
                       belnr = <ls_accit>-belnr
                       gjahr = <ls_accit>-gjahr
                       buzei = <ls_accit>-buzei.
      IF <ls_bseg> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_matnr = <ls_bseg>-matnr.
      READ TABLE it_glacct ASSIGNING FIELD-SYMBOL(<ls_acc>)
        WITH TABLE KEY
          provider_company_code  = is_t001-bukrs
          recipient_company_code = CONV #( <ls_bseg>-vbund )
          product                = lv_matnr
          doc_type               = c_glkey_ir.
      IF <ls_acc> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = <ls_acc>-gl_account1
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

      APPEND VALUE #(
        glaccountlineitem = lv_item
        supplier          = CONV #( <ls_bseg>-vbund )
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount * -1
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_apitems.
      lv_item += 1.

    ENDLOOP.

    IF ls_je-%param-_glitems IS INITIAL.
      RETURN.
    ENDIF.
    APPEND ls_je TO mt_je_post.

  ENDMETHOD.


  METHOD build_reclass_document_eml.
    DATA(lv_close) = get_quarter_close_date( is_ipf-netdt ).
    DATA(lv_kursf) = get_exchange_rate( iv_fcurr = is_ipf-int_curr
                                        iv_date  = lv_close ).
    DATA(lv_htxt)  = |RECLAS INT MORA IC Q{ lv_close+4(2) } { lv_close(4) }|.

    DATA ls_je TYPE STRUCTURE FOR ACTION IMPORT i_journalentrytp~post.
    ls_je-%cid                                = |MORA{ lines( mt_je_post ) + 1 }|.
    ls_je-%param-companycode                  = is_t001-bukrs.
    ls_je-%param-accountingdocumenttype       = c_doctype_recl.
    ls_je-%param-businesstransactiontype      = c_bus_act.
    ls_je-%param-ledgergroup                  = c_ledger_recl.
    ls_je-%param-accountingdocumentheadertext = lv_htxt.
    ls_je-%param-documentdate                 = is_ipf-netdt.
    ls_je-%param-postingdate                  = is_ipf-netdt.
    ls_je-%param-createdbyuser                = sy-uname.
    ls_je-%param-documentreferenceid          = is_ipf-int_belnr.

    DATA lv_item  TYPE n LENGTH 6 VALUE 1.
    DATA lv_matnr TYPE productnumber.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_accit>).

      READ TABLE it_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = is_t001-bukrs
                       belnr = <ls_accit>-belnr
                       gjahr = <ls_accit>-gjahr
                       buzei = <ls_accit>-buzei.
      IF <ls_bseg> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      lv_matnr = <ls_bseg>-matnr.
      READ TABLE it_glacct ASSIGNING FIELD-SYMBOL(<ls_acc>)
        WITH TABLE KEY
          provider_company_code  = is_t001-bukrs
          recipient_company_code = CONV #( <ls_bseg>-vbund )
          product                = lv_matnr
          doc_type               = c_glkey_ch.
      IF <ls_acc> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = <ls_acc>-gl_account2
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

      APPEND VALUE #(
        glaccountlineitem = lv_item
        glaccount         = c_gl_clearing
        profitcenter      = <ls_bseg>-prctr
        documentitemtext  = lv_htxt
        _currencyamount   = VALUE #( (
          currencyrole           = c_ccyrole_doc
          currency               = is_ipf-int_curr
          journalentryitemamount = <ls_accit>-payment_amount * -1
          exchangerate           = lv_kursf ) )
        ) TO ls_je-%param-_glitems.
      lv_item += 1.

    ENDLOOP.

    IF ls_je-%param-_glitems IS INITIAL.
      RETURN.
    ENDIF.
    APPEND ls_je TO mt_je_post.

  ENDMETHOD.


  METHOD convert_to_usd.
    IF iv_waers = 'USD'.
      rv_usd = iv_amount.
      RETURN.
    ENDIF.
    DATA(lv_rate) = get_exchange_rate( iv_fcurr = iv_waers iv_date = iv_date ).
    IF lv_rate <> 0.
      rv_usd = iv_amount / lv_rate.
    ENDIF.
  ENDMETHOD.


  METHOD determine_glacct.
    " Determina la fila de cuentas por DOC_TYPE (EF §5.2/§6.3).
    " recipient: match exacto por VBUND; si no hay, comodín (recipient vacío).
    DATA(lv_prod) = CONV zint_a_md_glacct-product( iv_concepto ).
    DATA(lv_recp) = CONV zint_a_md_glacct-recipient_company_code( iv_vbund ).

    READ TABLE it_glacct INTO rs_glacct
      WITH KEY provider_company_code  = iv_bukrs
               recipient_company_code = lv_recp
               product                = lv_prod
               doc_type               = iv_doc_type.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    READ TABLE it_glacct INTO rs_glacct
      WITH KEY provider_company_code  = iv_bukrs
               recipient_company_code = space
               product                = lv_prod
               doc_type               = iv_doc_type.
    IF sy-subrc <> 0.
      CLEAR rs_glacct.
    ENDIF.
  ENDMETHOD.


  METHOD get_bapi_post_fm.
    DATA lv_val TYPE tvarvc-low.
    TRY.
        NEW zcl_tvarvc( )->get_parameter(
          EXPORTING i_name  = 'ZFI_MORA_BAPI_POST_FM'
          IMPORTING e_value = lv_val ).
      CATCH zcx_tvarvc.
        CLEAR lv_val.
    ENDTRY.
    rv_fm = COND #( WHEN lv_val IS NOT INITIAL THEN lv_val ELSE 'BAPI_ACC_DOCUMENT_POST' ).
  ENDMETHOD.


  METHOD get_bseg_data.
    " ZINKZ via extensión CDS ZZEX_OPACCTG_ZINKZ sobre I_OperationalAcctgDocItem
    " (campo InterestBlock). Lectura por vista LIBERADA, sin acceso directo a BSEG.
    CHECK it_items IS NOT INITIAL.

    " Item (partida) via I_OperationalAcctgDocItem + concepto del header (XBLNR)
    " via LEFT OUTER JOIN a I_JournalEntry. Ambas CDS LIBERADAS (sin BSEG/BKPF).
    SELECT item~CompanyCode            AS bukrs,
           item~AccountingDocument     AS belnr,
           item~FiscalYear             AS gjahr,
           item~AccountingDocumentItem AS buzei,
           item~PartnerCompany         AS vbund,
           item~CostCenter             AS kostl,
           item~ProfitCenter           AS prctr,
           item~Material               AS matnr,
           item~InterestBlock          AS zinkz,
           hdr~DocumentReferenceID     AS concepto,
           hdr~TransactionCurrency     AS waers
      FROM i_operationalacctgdocitem AS item
           LEFT OUTER JOIN i_journalentry AS hdr
             ON  hdr~CompanyCode        = item~CompanyCode
             AND hdr~AccountingDocument = item~AccountingDocument
             AND hdr~FiscalYear         = item~FiscalYear
      FOR ALL ENTRIES IN @it_items
      WHERE item~CompanyCode            = @it_items-bukrs
        AND item~AccountingDocument     = @it_items-belnr
        AND item~FiscalYear             = @it_items-gjahr
        AND item~AccountingDocumentItem = @it_items-buzei
      INTO CORRESPONDING FIELDS OF TABLE @rt_bseg.
  ENDMETHOD.


  METHOD get_exchange_rate.
    DATA lv_max_date TYPE i_exchangeraterawdata-ValidityStartDate.

    SELECT MAX( ValidityStartDate )
      FROM I_ExchangeRateRawData
      WHERE ExchangeRateType  = 'B'
        AND SourceCurrency    = @iv_fcurr
        AND TargetCurrency    = 'USD'
        AND ValidityStartDate <= @iv_date
      INTO @lv_max_date.

    IF sy-subrc = 0 AND lv_max_date IS NOT INITIAL.
      SELECT SINGLE ExchangeRate
        FROM I_ExchangeRateRawData
        WHERE ExchangeRateType  = 'B'
          AND SourceCurrency    = @iv_fcurr
          AND TargetCurrency    = 'USD'
          AND ValidityStartDate = @lv_max_date
        INTO @rv_rate.
    ENDIF.

    IF rv_rate IS INITIAL.
      rv_rate = 1.
    ENDIF.
  ENDMETHOD.


  METHOD get_quarter_close_date.
    DATA(lv_month) = iv_date_ref+4(2).
    CASE lv_month.
      WHEN '01' OR '02' OR '03'. rv_date = |{ iv_date_ref(4) }0331|.
      WHEN '04' OR '05' OR '06'. rv_date = |{ iv_date_ref(4) }0630|.
      WHEN '07' OR '08' OR '09'. rv_date = |{ iv_date_ref(4) }0930|.
      WHEN OTHERS.               rv_date = |{ iv_date_ref(4) }1231|.
    ENDCASE.
  ENDMETHOD.


  METHOD get_run_date.
    " Fecha del run = A_BUDAT (fecha de contabilizacion) de la pantalla FINT (IT_FRANGE).
    READ TABLE it_frange ASSIGNING FIELD-SYMBOL(<ls_fr>)
      WITH KEY fieldname = 'A_BUDAT'.
    IF sy-subrc = 0.
      READ TABLE <ls_fr>-selopt_t INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_sel>).
      IF sy-subrc = 0 AND <ls_sel>-low IS NOT INITIAL.
        rv_date = <ls_sel>-low.
        RETURN.
      ENDIF.
    ENDIF.
    IF rv_date IS INITIAL.
      " Fallback: ultimo dia del mes/año actual (robusto, sin CONV).
      DATA lv_aux TYPE d.
      lv_aux      = sy-datum.
      lv_aux+6(2) = '01'.
      lv_aux      = lv_aux + 31.
      lv_aux+6(2) = '01'.
      rv_date     = lv_aux - 1.
    ENDIF.
  ENDMETHOD.


  METHOD get_source_ceco.
    " Rework AP_InterestMora_Fix: lee TODAS las lineas de servicio con CeCo del
    " documento origen y devuelve tabla (prctr, kostl, amount) para construir
    " N lineas GL (espejo del AR) en AP/CH. Fallback prctr 999 si no hay CeCos.
    CLEAR rt_cecos.

    SELECT item~ProfitCenter AS prctr,
           item~CostCenter   AS kostl,
           abs( item~AmountInTransactionCurrency ) AS amount
      FROM i_operationalacctgdocitem AS item
      WHERE item~CompanyCode          = @iv_bukrs
        AND item~AccountingDocument   = @iv_belnr
        AND item~FiscalYear           = @iv_gjahr
        AND item~FinancialAccountType = 'S'
        AND item~CostCenter          IS NOT INITIAL
      ORDER BY item~AccountingDocumentItem
      INTO CORRESPONDING FIELDS OF TABLE @rt_cecos.

    IF rt_cecos IS INITIAL.
      APPEND VALUE #( prctr = '0000000999' ) TO rt_cecos.
    ENDIF.

*  ================= CODIGO ORIGINAL (comentado para rollback - rework AP_InterestMora_Fix 16/07/2026) =================
*    " CeCo/CeBe se heredan de la factura origen (EF §6.3). La partida abierta
*    " (linea de cliente) NO lleva CeCo; se toman de las lineas de servicio
*    " (FinancialAccountType = 'S') del MISMO documento. PROVISORIO: primera
*    " linea de servicio con centro de coste (regla a confirmar con funcional).
*    " Solo se leen CeCo/CeBe -> NO afecta el importe del interes.
*    CLEAR: ev_kostl, ev_prctr.
*    SELECT item~CostCenter, item~ProfitCenter
*      FROM i_operationalacctgdocitem AS item
*      WHERE item~CompanyCode          = @iv_bukrs
*        AND item~AccountingDocument   = @iv_belnr
*        AND item~FiscalYear           = @iv_gjahr
*        AND item~FinancialAccountType = 'S'
*        AND item~CostCenter          IS NOT INITIAL
*      ORDER BY item~AccountingDocumentItem
*      INTO ( @ev_kostl, @ev_prctr )
*      UP TO 1 ROWS.
*    ENDSELECT.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~end_of_programm.

    " [TR] Havendo documento TR na execução: nada a fazer aqui (a Mora não se aplica).
    LOOP AT it_ipf ASSIGNING FIELD-SYMBOL(<ls_ipf_tr>).
      IF is_tr_item( <ls_ipf_tr> ) = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    " Valida se a execucao esta em modo teste (A_TESTL = 'X') -> nao grava log
    IF VALUE #( it_frange[ fieldname = 'A_TESTL' ]-selopt_t[ 1 ]-low OPTIONAL ) = abap_true.
      RETURN.
    ENDIF.

    DATA lt_log_entries TYPE STANDARD TABLE OF zfint_post_log.
    DATA lv_uuid        TYPE c LENGTH 32.
    " [SDFPSINIC-23382] RUN_ID = clave de agrupacion del monitor Fiori (Nivel 1): agrupa
    " las ejecuciones por FECHA. end_of_programm corre 1 vez por run -> sy-datum estable.
    DATA lv_run_id TYPE zfint_post_log-run_id.
    lv_run_id = |RUN-{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.

    " ===== Rama BAPI: atomicidad EF (LUW unica, COMMIT/ROLLBACK WORK) =====
    IF is_post_by_bapi( ) = abap_true.
      DATA(lv_has_error) = mv_post_error.

      IF lv_has_error = abap_true.
        " Error en Doc2/Doc3 -> rollback de TODA la LUW (relanzar)
        ROLLBACK WORK.
        " Los mensajes de error se capturan en los metodos post (mt_err_log),
        " porque el ct_log del FINT se descarta cuando cd_post_status='ERROR'.
        LOOP AT mt_err_log INTO DATA(ls_berr).
          TRY.
              lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
            CATCH cx_uuid_error.
              lv_uuid = sy-datum && sy-uzeit.
          ENDTRY.
          ls_berr-log_id = lv_uuid.
          IF ls_berr-erdat IS INITIAL. ls_berr-erdat = sy-datum. ENDIF.
          IF ls_berr-erzet IS INITIAL. ls_berr-erzet = sy-uzeit. ENDIF.
          IF ls_berr-ernam IS INITIAL. ls_berr-ernam = sy-uname. ENDIF.
          APPEND ls_berr TO lt_log_entries.
        ENDLOOP.

        " [SDFPSINIC-23382] Reflejar los errores en el log estandar del FINT (SLG1)
        " con severidad real. FI_INT_LOG_FROM_BADI fuerza MSGTY = 'I' para TODO lo
        " que reciba, porque FINT_TS_LOG (tipo de CT_LOG) no tiene campo MSGTY
        " (confirmado via RTTI). Dejamos que la FM standard haga el APPEND normal
        " a Gt_log (tabla global del pool FI_INT_ERROR, tipo FINT_TT_MSGLOG - esta
        " SI tiene MSGTY) y corregimos el MSGTY de las filas recien agregadas
        " accediendo a Gt_log via ASSIGN dinamico (confirmado por debug).
        DATA lt_fint    TYPE fint_tt_log.
        DATA ls_fint    LIKE LINE OF lt_fint.
        DATA lv_logid_i TYPE fint_td_logid VALUE 'INT'.
        LOOP AT mt_err_log INTO DATA(ls_ferr).
          CLEAR ls_fint.
          ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_fint TO FIELD-SYMBOL(<f_flt>).
          ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_fint TO FIELD-SYMBOL(<f_fty>).
          ASSIGN COMPONENT 'BUKRS' OF STRUCTURE ls_fint TO FIELD-SYMBOL(<f_fbk>).
          IF <f_flt> IS ASSIGNED. <f_flt> = ls_ferr-msg_text. ENDIF.
          IF <f_fty> IS ASSIGNED. <f_fty> = ls_ferr-severity. ENDIF.
          IF <f_fbk> IS ASSIGNED. <f_fbk> = ls_ferr-bukrs.    ENDIF.
          APPEND ls_fint TO lt_fint.
        ENDLOOP.
        IF lt_fint IS NOT INITIAL.

          FIELD-SYMBOLS <ft_gt_log> TYPE fint_tt_msglog.
          ASSIGN ('(SAPLFI_INT_ERROR)GT_LOG') TO <ft_gt_log>.

          DATA(lv_fm_log) = CONV rs38l_fnam( 'FI_INT_LOG_FROM_BADI' ).
          CALL FUNCTION lv_fm_log
            EXPORTING
              id_logid = lv_logid_i
            CHANGING
              ct_log   = lt_fint.

          " [SDFPSINIC-23382] Todas las lineas del log de este run quedan con el
          " icono de ERROR (MSGTY='E'), no solo la(s) linea(s) que coincidian por
          " contenido con mt_err_log (pedido funcional 25/08: replicar icono de
          " error en todas las lineas de Gt_log). Este bloque solo se ejecuta
          " cuando ya se confirmo lv_has_error = 'X' (ver IF que lo envuelve),
          " por eso el severity fijo 'E' es seguro aqui.
          IF <ft_gt_log> IS ASSIGNED.
            LOOP AT <ft_gt_log> ASSIGNING FIELD-SYMBOL(<fs_gtlog_row>).
              <fs_gtlog_row>-msgty = 'E'.
            ENDLOOP.
          ENDIF.
        ENDIF.

      ELSE.

        IF mt_post_log IS NOT INITIAL.
          " Los 3 OK -> commit atomico de la LUW
          COMMIT WORK AND WAIT.

          DATA lv_belnr_ic TYPE belnr_d.
          DATA lv_gjahr_ic TYPE gjahr.
          DATA ls_base     TYPE zfint_post_log.
          DATA ls_row      TYPE zfint_post_log.

          " EF §7.2.4: por cada partida origen se registran los 3 documentos
          " generados (IC estandar del FINT + IR/CH de la BAdI): 1 fila por doc.
          LOOP AT mt_post_log ASSIGNING FIELD-SYMBOL(<ls_logmap>).

            " Doc1 (IC): numero asignado por el FINT, ya disponible en IT_IPF
            " (se cruza por el ARRAY del grupo). En int_post aun estaba vacio.
            CLEAR: lv_belnr_ic, lv_gjahr_ic.
            READ TABLE it_ipf ASSIGNING FIELD-SYMBOL(<ls_ipfr>)
              WITH KEY array = <ls_logmap>-array.
            IF sy-subrc = 0.
              lv_belnr_ic = <ls_ipfr>-int_belnr.
              lv_gjahr_ic = <ls_ipfr>-int_gjahr.
            ENDIF.

            " Base comun de la fila (datos de negocio de la partida origen)
            CLEAR ls_base.
            ls_base-run_status      = 'SC'.
            ls_base-doc_status      = 'AC'.
            ls_base-severity        = 'S'.
            ls_base-bukrs           = <ls_logmap>-bukrs.
            ls_base-vbund           = <ls_logmap>-vbund.
            ls_base-concepto        = <ls_logmap>-concepto.
            ls_base-source_belnr    = <ls_logmap>-source_belnr.
            ls_base-source_gjahr    = <ls_logmap>-source_gjahr.
            ls_base-int_curr        = <ls_logmap>-int_curr.
            ls_base-int_amount      = <ls_logmap>-int_amount.
            ls_base-dias_mora       = <ls_logmap>-dias_mora.
            ls_base-cons_generation = <ls_logmap>-cons_generation.
            ls_base-erdat           = sy-datum.
            ls_base-erzet           = sy-uzeit.
            ls_base-ernam           = sy-uname.

            " Fila Doc1 (IC) - documento estandar del FINT
            ls_row = ls_base.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            ls_row-log_id     = lv_uuid.
            ls_row-doc_no     = lv_belnr_ic.
            ls_row-cons_belnr = lv_belnr_ic.
            ls_row-cons_gjahr = lv_gjahr_ic.
            ls_row-doc_class  = 'IC'.   " [SDFPSINIC-23382] clase para pivot Fiori Nivel 2
            ls_row-msg_text   = |Doc IC { lv_belnr_ic } contabilizado (FINT)|.
            APPEND ls_row TO lt_log_entries.

            " Fila Doc2 (IR) - Cuentas por Pagar (BAdI)
            ls_row = ls_base.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            ls_row-log_id     = lv_uuid.
            ls_row-doc_no     = <ls_logmap>-belnr_ap.
            ls_row-cons_belnr = <ls_logmap>-belnr_ap.
            ls_row-cons_gjahr = lv_gjahr_ic.
            ls_row-doc_class  = 'IR'.   " [SDFPSINIC-23382] clase para pivot Fiori Nivel 2
            ls_row-msg_text   = |Doc IR { <ls_logmap>-belnr_ap } contabilizado (BAdI)|.
            APPEND ls_row TO lt_log_entries.

            " Fila Doc3 (CH) - Reclasificacion (BAdI)
            ls_row = ls_base.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            ls_row-log_id     = lv_uuid.
            ls_row-doc_no     = <ls_logmap>-belnr_rr.
            ls_row-cons_belnr = <ls_logmap>-belnr_rr.
            ls_row-cons_gjahr = lv_gjahr_ic.
            ls_row-doc_class  = 'CH'.   " [SDFPSINIC-23382] clase para pivot Fiori Nivel 2
            ls_row-msg_text   = |Doc CH { <ls_logmap>-belnr_rr } contabilizado (BAdI)|.
            APPEND ls_row TO lt_log_entries.
          ENDLOOP.
        ELSE.
          " Fallback: al menos un registro SC por documento de interés
          LOOP AT it_ipf ASSIGNING FIELD-SYMBOL(<ls_bipf>).
            " [TR] documentos TR nao geram log de Mora
            IF is_tr_item( <ls_bipf> ) = abap_true.
              CONTINUE.
            ENDIF.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            DATA ls_bok TYPE zfint_post_log.
            CLEAR ls_bok.
            ls_bok-log_id     = lv_uuid.
            ls_bok-run_status = 'XX'.
            ls_bok-doc_status = 'AC'.
            ls_bok-severity   = 'S'.
            ls_bok-bukrs      = <ls_bipf>-bukrs.
            ls_base-int_amount = <ls_bipf>-int_amount.
            ls_bok-msg_text   = |Doc. Test { <ls_bipf>-int_belnr } Ejecutado con Exito|.
            ls_bok-erdat      = sy-datum.
            ls_bok-erzet      = sy-uzeit.
            ls_bok-ernam      = sy-uname.
            APPEND ls_bok TO lt_log_entries.
          ENDLOOP.
        ENDIF.
      ENDIF.

      IF lt_log_entries IS NOT INITIAL.
        " [SDFPSINIC-23382] Sellar RUN_ID (agrupacion por fecha) en todas las filas del run.
        MODIFY lt_log_entries FROM VALUE #( run_id = lv_run_id ) TRANSPORTING run_id WHERE run_id IS INITIAL.
        MODIFY zfint_post_log FROM TABLE lt_log_entries.
        " LUW propia del log Z: tras el ROLLBACK/COMMIT de la LUW de documentos,
        " persistir el rastro (errores y exitos) de forma aislada.
        COMMIT WORK.
      ENDIF.
      RETURN.
    ENDIF.

    " Run sin documentos Mora -> no tocar la LUW del documento estandar del FINT.
    IF mt_je_post IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_prev_error) = abap_false.
    LOOP AT ct_log ASSIGNING FIELD-SYMBOL(<ls_chk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE <ls_chk> TO FIELD-SYMBOL(<lv_ty0>).
      IF <lv_ty0> IS ASSIGNED AND ( <lv_ty0> = 'E' OR <lv_ty0> = 'A' ).
        lv_prev_error = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    TRY.
        IF lv_prev_error = abap_true.
          ROLLBACK ENTITIES.

          LOOP AT ct_log ASSIGNING FIELD-SYMBOL(<ls_err>).
            ASSIGN COMPONENT 'MSGTY' OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_ty>).
            IF <lv_ty> IS NOT ASSIGNED. CONTINUE. ENDIF.
            IF <lv_ty> <> 'E' AND <lv_ty> <> 'A'. CONTINUE. ENDIF.

            ASSIGN COMPONENT 'MSGID'   OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_id>).
            ASSIGN COMPONENT 'MSGNO'   OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_no>).
            ASSIGN COMPONENT 'MESSAGE' OF STRUCTURE <ls_err> TO FIELD-SYMBOL(<lv_msg>).

            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.

            DATA ls_entry TYPE zfint_post_log.
            CLEAR ls_entry.
            ls_entry-log_id     = lv_uuid.
            ls_entry-run_status = 'ER'.
            ls_entry-doc_status = 'RB'.
            ls_entry-severity   = 'E'.
            IF <lv_id>  IS ASSIGNED. ls_entry-msgid    = <lv_id>.  ENDIF.
            IF <lv_no>  IS ASSIGNED. ls_entry-msgno    = <lv_no>.  ENDIF.
            IF <lv_msg> IS ASSIGNED. ls_entry-msg_text = <lv_msg>. ENDIF.
            ls_entry-erdat = sy-datum.
            ls_entry-erzet = sy-uzeit.
            ls_entry-ernam = sy-uname.
            APPEND ls_entry TO lt_log_entries.
          ENDLOOP.

          IF lt_log_entries IS NOT INITIAL.
            MODIFY zfint_post_log FROM TABLE lt_log_entries.
          ENDIF.
          RETURN.
        ENDIF.

        MODIFY ENTITIES OF i_journalentrytp PRIVILEGED
          ENTITY journalentry
          EXECUTE post FROM mt_je_post
          FAILED   DATA(ls_failed)
          REPORTED DATA(ls_reported)
          MAPPED   DATA(ls_mapped).

        IF ls_failed-journalentry IS NOT INITIAL.
          ROLLBACK ENTITIES.

          LOOP AT ls_reported-journalentry ASSIGNING FIELD-SYMBOL(<ls_rep>).
            IF <ls_rep>-%msg IS NOT BOUND. CONTINUE. ENDIF.
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            DATA ls_err_eml TYPE zfint_post_log.
            CLEAR ls_err_eml.
            ls_err_eml-log_id     = lv_uuid.
            ls_err_eml-run_status = 'ER'.
            ls_err_eml-doc_status = 'RB'.
            ls_err_eml-severity   = 'E'.
            ls_err_eml-msg_text   = <ls_rep>-%msg->if_message~get_text( ).
            ls_err_eml-erdat      = sy-datum.
            ls_err_eml-erzet      = sy-uzeit.
            ls_err_eml-ernam      = sy-uname.
            APPEND ls_err_eml TO lt_log_entries.
          ENDLOOP.

          IF lt_log_entries IS NOT INITIAL.
            MODIFY zfint_post_log FROM TABLE lt_log_entries.
          ENDIF.
          RETURN.
        ENDIF.

        COMMIT ENTITIES BEGIN
          RESPONSE OF i_journalentrytp
          FAILED   DATA(ls_save_failed)
          REPORTED DATA(ls_save_reported).

        IF ls_save_failed-journalentry IS NOT INITIAL.
          ROLLBACK ENTITIES.
          TRY.
              lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
            CATCH cx_uuid_error.
              lv_uuid = sy-datum && sy-uzeit.
          ENDTRY.
          DATA ls_cerr TYPE zfint_post_log.
          CLEAR ls_cerr.
          ls_cerr-log_id     = lv_uuid.
          ls_cerr-run_status = 'ER'.
          ls_cerr-doc_status = 'RB'.
          ls_cerr-severity   = 'E'.
          ls_cerr-msg_text   = 'Error en COMMIT ENTITIES del posting EML'.
          ls_cerr-erdat      = sy-datum.
          ls_cerr-erzet      = sy-uzeit.
          ls_cerr-ernam      = sy-uname.
          APPEND ls_cerr TO lt_log_entries.
        ELSE.
          LOOP AT ls_mapped-journalentry ASSIGNING FIELD-SYMBOL(<ls_map>).
            CONVERT KEY OF i_journalentrytp FROM <ls_map>-%pid TO DATA(ls_final_key).
            TRY.
                lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
              CATCH cx_uuid_error.
                lv_uuid = sy-datum && sy-uzeit.
            ENDTRY.
            DATA ls_ok TYPE zfint_post_log.
            CLEAR ls_ok.
            ls_ok-log_id     = lv_uuid.
            ls_ok-run_status = 'SC'.
            ls_ok-doc_status = 'AC'.
            ls_ok-severity   = 'S'.
            ls_ok-bukrs      = ls_final_key-companycode.
            ls_ok-msg_text   = |Doc { ls_final_key-accountingdocument } contabilizado correctamente|.
            ls_ok-erdat      = sy-datum.
            ls_ok-erzet      = sy-uzeit.
            ls_ok-ernam      = sy-uname.
            APPEND ls_ok TO lt_log_entries.
          ENDLOOP.
        ENDIF.
        COMMIT ENTITIES END.

      CATCH cx_root INTO DATA(lx_tech).
        ROLLBACK ENTITIES.
        TRY.
            lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
          CATCH cx_uuid_error.
            lv_uuid = sy-datum && sy-uzeit.
        ENDTRY.
        DATA ls_terr TYPE zfint_post_log.
        CLEAR ls_terr.
        ls_terr-log_id     = lv_uuid.
        ls_terr-run_status = 'ER'.
        ls_terr-doc_status = 'RB'.
        ls_terr-severity   = 'E'.
        ls_terr-msg_text   = |Error tecnico (dump) en posting Mora: { lx_tech->get_text( ) }|.
        ls_terr-erdat      = sy-datum.
        ls_terr-erzet      = sy-uzeit.
        ls_terr-ernam      = sy-uname.
        APPEND ls_terr TO lt_log_entries.
    ENDTRY.

    IF lt_log_entries IS NOT INITIAL.
      MODIFY zfint_post_log FROM TABLE lt_log_entries.
    ENDIF.

  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~get_int_sign.            ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_add_items.

    " [TR] Fora do toggle de Mora: identifica clientes TR e dispara o fluxo TR.
    remember_tr_customers( ct_knb1 ).

    " Havendo item TR: dispara o fluxo TR e ENCERRA (sem passar pela Mora).
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_tr>).
      IF is_tr_item( <ls_tr> ) = abap_true.
        call_tr_process( ).
        RETURN.
      ENDIF.
    ENDLOOP.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lt_bseg) = get_bseg_data( ct_items ).

    " --- Punto de inspección debug (validar contenido en runtime) ---
    " Poner breakpoint en la línea siguiente e inspeccionar CT_ITEMS y LT_BSEG.
    " lv_dbg_items = nro de partidas en scope; lv_dbg_bseg = nro de líneas leídas de la CDS.
    DATA(lv_dbg_items) = lines( ct_items ).
    DATA(lv_dbg_bseg)  = lines( lt_bseg ).

    DATA lt_brasil TYPE RANGE OF vbund.
    lt_brasil = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'MLB' )
      ( sign = 'I' option = 'EQ' low = 'MLE' )
      ( sign = 'I' option = 'EQ' low = 'MLM' ) ).

    DATA lt_arg TYPE RANGE OF vbund.
    lt_arg = VALUE #(
      ( sign = 'I' option = 'EQ' low = 'MSP' )
      ( sign = 'I' option = 'EQ' low = 'MLO' )
      ( sign = 'I' option = 'EQ' low = 'MPY' )
      ( sign = 'I' option = 'EQ' low = 'MPA' ) ).

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      " [TR] itens TR nao entram na logica de Mora (call_tr_process ja chamado acima)
      IF is_tr_item( <ls_item> ) = abap_true.
        CONTINUE.
      ENDIF.

      DATA(lv_exclude) = abap_false.

      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = <ls_item>-bukrs
                       belnr = <ls_item>-belnr
                       gjahr = <ls_item>-gjahr
                       buzei = <ls_item>-buzei.

      IF <ls_item>-blart = 'AJ' OR <ls_item>-blart = 'AI'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND <ls_bseg>-zinkz = '01'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND <ls_bseg>-vbund IN lt_arg.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_bseg> IS ASSIGNED AND
         ( <ls_item>-zuonr CS 'BACKOFFICE' OR
           <ls_item>-zuonr CS 'NEG MGT' ) AND
         <ls_bseg>-vbund IN lt_brasil.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_item>-blart = 'IO'.
        lv_exclude = abap_true.
      ENDIF.

      IF <ls_item>-umskz = 'F'.
        lv_exclude = abap_true.
      ENDIF.

      IF lv_exclude = abap_true.
        DELETE ct_items.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_change_items.
    " ============================================================================
    " EF SDFPSINIC-23382 §6.2 — Agrupamiento a nivel de ITEM (30/06/2026)
    " El FINT contabiliza colectando items WHERE Array = Cs_ipf-Array
    " (LFI_INT_POSTF05). Por eso el ARRAY debe estar en los ITEMS, no solo en
    " CT_SUM (INT_GROUP). Misma clave: BUKRS+VBUND+CONCEPTO+WAERS+(GJAHR+POPER run).
    " ============================================================================

    " [TR] Havendo item TR: dispara o fluxo TR e ENCERRA (sem passar pela Mora).
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_tr>).
      IF is_tr_item( <ls_tr> ) = abap_true.
        call_tr_process( ).
        RETURN.
      ENDIF.
    ENDLOOP.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lt_bseg)     = get_bseg_data( ct_items ).
    DATA(lv_run_date) = get_run_date( it_frange ).
    DATA(lv_gjahr)    = lv_run_date(4).
    DATA(lv_poper)    = lv_run_date+4(2).

    DATA lv_mora_items TYPE i.
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_count_item>).
      IF is_tr_item( <ls_count_item> ) = abap_false.
        lv_mora_items = lv_mora_items + 1.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      " [TR] itens TR nao entram na logica de Mora (call_tr_process ja chamado acima)
      IF is_tr_item( <ls_item> ) = abap_true.
        CONTINUE.
      ENDIF.

      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = <ls_item>-bukrs
                       belnr = <ls_item>-belnr
                       gjahr = <ls_item>-gjahr
                       buzei = <ls_item>-buzei.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " EF 6.2 multi-factura (21/07): SOLO se agrupa (setea array) cuando hay >1 factura
      " en el run. Con 1 sola factura NO se setea -> comportamiento single-factura (no toca AR).
      IF lv_mora_items GE 2.
        <ls_item>-array = |{ <ls_item>-bukrs }{ <ls_bseg>-vbund }{ <ls_bseg>-concepto }{ <ls_bseg>-waers }{ lv_gjahr }{ lv_poper }|.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_formula.

    " O indicador TR tambem deve passar pela formula propria desta BAdI.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    " EF SDFPSINIC-23382 §3.3/§3.4: interés solo sobre el exceso de 90 días
    " (a partir del día 91). Base de días = 365 (EF §3.3).
    IF id_days <= 90.
      cs_int_amount = 0.              " dentro de 90 días: no devenga interés
      RETURN.                          " sale ANTES de cualquier división
    ENDIF.

    " EF §3.3: base de días FIJA = 365 (confirmado con funcional 17/07/2026).
    " NO usar id_basedays: el FINT lo pasa como 365,2815789 y desvía el importe.
    DATA lv_basedays TYPE int_basedays.
    lv_basedays = 365.

    " Una sola división; denominador garantizado > 0 (365)
    cs_int_amount = id_basamt * id_rate * ( id_days - 90 ) / ( lv_basedays * 100 ).

*  === CÓDIGO ANTERIOR (comentado para rollback - fix base 365 fija 17/07/2026) ===
*    " Guarda contra división por cero (CX_SY_ZERODIVIDE): base de días debe ser > 0
*    DATA(lv_basedays) = id_basedays.
*    IF lv_basedays <= 0.
*      lv_basedays = 365.               " fallback EF §3.3
*    ENDIF.
*    cs_int_amount = id_basamt * id_rate * ( id_days - 90 ) / ( lv_basedays * 100 ).
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_group.

    " ============================================================================
    " EF SDFPSINIC-23382 §6.2 — Agrupamiento (29/06/2026)
    " Clave: BUKRS + VBUND + CONCEPTO + WAERS + (GJAHR+POPER del run)
    " - CT_SUM trae la factura origen en BUKRS_TO + REBZG/REBZJ/REBZZ
    "   (BELNR/GJAHR/BUZEI vienen vacios -> por eso el READ usa REBZ*).
    " - VBUND        = partida abierta (I_OperationalAcctgDocItem) via get_bseg_data.
    " - CONCEPTO     = XBLNR del header (I_JournalEntry) via get_header_data.
    " - GJAHR/POPER  = periodo del run (get_run_date PROVISORIO = ultimo dia mes actual).
    " ============================================================================

    " [TR] Fora do toggle de Mora: identifica clientes TR e dispara o fluxo TR.
    remember_tr_customers( it_knb1 ).

    " Havendo item TR: dispara o fluxo TR e ENCERRA (sem passar pela Mora).
    LOOP AT ct_sum ASSIGNING FIELD-SYMBOL(<ls_tr>).
      IF is_tr_item( <ls_tr> ) = abap_true.
        call_tr_process( ).
        RETURN.
      ENDIF.
    ENDLOOP.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lt_bseg) = get_bseg_data( it_items ).

    DATA(lv_run_date) = get_run_date( it_frange ).
    DATA(lv_gjahr)    = lv_run_date(4).
    DATA(lv_poper)    = lv_run_date+4(2).

    DATA lv_mora_sum TYPE i.
    LOOP AT ct_sum ASSIGNING FIELD-SYMBOL(<ls_count_sum>).
      IF is_tr_item( <ls_count_sum> ) = abap_false.
        lv_mora_sum = lv_mora_sum + 1.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_sum ASSIGNING FIELD-SYMBOL(<ls_sum>).

      " [TR] itens TR nao entram na logica de Mora (call_tr_process ja chamado acima)
      IF is_tr_item( <ls_sum> ) = abap_true.
        CONTINUE.
      ENDIF.

      " elo con la factura origen (REBZG/REBZJ/REBZZ)
      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
        WITH TABLE KEY bukrs = <ls_sum>-bukrs_to
                       belnr = <ls_sum>-rebzg
                       gjahr = <ls_sum>-rebzj
                       buzei = <ls_sum>-rebzz.
      IF sy-subrc <> 0.
        append_log_warn(
          EXPORTING iv_msgid = 'ZFI_INT' iv_msgno = '001'
                    iv_msgv1 = <ls_sum>-bukrs_to iv_msgv2 = <ls_sum>-rebzg
          CHANGING  ct_log   = ct_log ).
        CONTINUE.
      ENDIF.

      " EF 6.2 multi-factura (21/07): SOLO se agrupa (setea array) cuando hay >1 linea en ct_sum.
      IF lv_mora_sum GE 2.
        " concepto (XBLNR) ya viene en <ls_bseg>-concepto desde get_bseg_data (join header)
        <ls_sum>-array = |{ <ls_sum>-bukrs_to }{ <ls_bseg>-vbund }{ <ls_bseg>-concepto }{ <ls_sum>-int_curr }{ lv_gjahr }{ lv_poper }|.
      ENDIF.

    ENDLOOP.

* ===== CODIGO ANTERIOR (comentado 29/06/2026 — READ por chaves vazias da ct_sum) =====
*    IF is_mora_active( ) = abap_false.
*      RETURN.
*    ENDIF.
*
*    DATA(lt_bseg) = get_bseg_data( it_items ).
*
*    LOOP AT ct_sum ASSIGNING FIELD-SYMBOL(<ls_sum>).
*
*      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_bseg>)
*        WITH TABLE KEY bukrs = <ls_sum>-bukrs
*                       belnr = <ls_sum>-belnr
*                       gjahr = <ls_sum>-gjahr
*                       buzei = <ls_sum>-buzei.
*
*      IF <ls_bseg> IS ASSIGNED.
*        DATA(lv_qclose) = get_quarter_close_date( <ls_sum>-int_total_end ).
*        <ls_sum>-array = |{ <ls_sum>-bukrs }{ <ls_bseg>-vbund }{ <ls_bseg>-matnr }{ <ls_sum>-int_curr }{ lv_qclose(4) }{ lv_qclose+4(2) }|.
*      ENDIF.
*
*    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_01.             ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_02.             ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_03.             ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_modify_items.

    " A rotina dinamica TR só roda no fluxo legado sem codigo de juros TR.
    IF mt_tr_knb1 IS INITIAL.
      call_tr_class( EXPORTING iv_method = 'APPLY_MULTA'
                     CHANGING  ct_items  = ct_items ).
    ENDIF.

    " [TR] Fora do toggle de Mora: havendo item TR, dispara o fluxo TR e ENCERRA
    " (a execução TR não passa pela lógica de Mora, nem pelo is_mora_active).
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_tr>).
      IF is_tr_item( <ls_tr> ) = abap_true.
        call_tr_process( ).
        RETURN.
      ENDIF.
    ENDLOOP.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    DATA lv_umbral_usd TYPE wrbtr.
    DATA lv_moneda_usd TYPE waers.

    SELECT SINGLE Low FROM zi_tvarvc
      WHERE Name = 'ZFI_INT_MONEDA_USD' AND Type = 'P'
      INTO @lv_moneda_usd.
    IF sy-subrc <> 0.
      lv_moneda_usd = 'USD'.
    ENDIF.

    SELECT SINGLE Low FROM zi_tvarvc
      WHERE Name = 'ZFI_INT_UMBRAL_USD' AND Type = 'P'
      INTO @DATA(lv_umbral_str).
    IF sy-subrc = 0.
      lv_umbral_usd = lv_umbral_str.
    ELSE.
      lv_umbral_usd = '5000.00'.
    ENDIF.

    " Data de referência = 1º item NÃO TR (o TR não participa da Mora)
    DATA lv_ref_date TYPE datum.
    lv_ref_date = sy-datum.
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_ref>).
      IF is_tr_item( <ls_ref> ) = abap_false.
        lv_ref_date = <ls_ref>-bldat.
        EXIT.
      ENDIF.
    ENDLOOP.
    TYPES: BEGIN OF ty_cur,
             waers TYPE waers,
           END OF ty_cur.
    TYPES: BEGIN OF ty_usd_rate,
             waers TYPE waers,
             rate  TYPE i_exchangeraterawdata-exchangerate,
           END OF ty_usd_rate.
    DATA lt_curr     TYPE SORTED TABLE OF ty_cur      WITH UNIQUE KEY waers.
    DATA lt_usd_rate TYPE HASHED TABLE OF ty_usd_rate WITH UNIQUE KEY waers.

    " Monedas distintas no-USD presentes en los items
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_cur>).
      IF is_tr_item( <ls_cur> ) = abap_true.
        CONTINUE.
      ENDIF.
      IF <ls_cur>-int_curr <> lv_moneda_usd AND <ls_cur>-int_curr IS NOT INITIAL.
        INSERT VALUE #( waers = <ls_cur>-int_curr ) INTO TABLE lt_curr.
      ENDIF.
    ENDLOOP.

    " Pre-carga de tasas a USD (set-based, sin SELECT dentro de loop)
    IF lt_curr IS NOT INITIAL.
      SELECT sourcecurrency, validitystartdate, exchangerate
        FROM i_exchangeraterawdata
        FOR ALL ENTRIES IN @lt_curr
        WHERE exchangeratetype   = 'B'
          AND sourcecurrency     = @lt_curr-waers
          AND targetcurrency     = 'USD'
          AND validitystartdate <= @lv_ref_date
        INTO TABLE @DATA(lt_raw).

      SORT lt_raw BY sourcecurrency ASCENDING validitystartdate DESCENDING.
      LOOP AT lt_raw INTO DATA(ls_raw).
        INSERT VALUE #( waers = ls_raw-sourcecurrency
                        rate  = ls_raw-exchangerate ) INTO TABLE lt_usd_rate.
      ENDLOOP.
    ENDIF.

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      " [TR] itens TR nao entram na logica de Mora (call_tr_process ja chamado acima)
      IF is_tr_item( <ls_item> ) = abap_true.
        CONTINUE.
      ENDIF.

      DATA lv_int_usd TYPE wrbtr.

      IF <ls_item>-int_curr = lv_moneda_usd.
        lv_int_usd = <ls_item>-int_amount.
      ELSE.
        DATA(lv_rate) = VALUE #( lt_usd_rate[ waers = <ls_item>-int_curr ]-rate OPTIONAL ).
        IF lv_rate > 0.
          lv_int_usd = <ls_item>-int_amount / lv_rate.
        ELSE.
          lv_int_usd = <ls_item>-int_amount.
        ENDIF.
      ENDIF.

      IF lv_int_usd < lv_umbral_usd.
        DELETE ct_items.
        CONTINUE.
      ENDIF.

      " EF SDFPSINIC-23382 §3.3 — Ajuste período de gracia 90 días para display
      IF <ls_item>-int_days <= 90.
        <ls_item>-int_days = 0.
      ELSE.
        <ls_item>-int_days = <ls_item>-int_days - 90.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_post.

    " Mesmo com is_knb1-vzskz = 'TR', executar a logica propria desta BAdI.

    IF is_mora_active( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lt_bseg) = get_bseg_data( ct_items ).

    DATA lt_glacct TYPE tt_glacct.
    SELECT provider_company_code, recipient_company_code,
           product, gl_account1, gl_account2, doc_type
      FROM zint_a_md_glacct
      WHERE provider_company_code = @is_t001-bukrs
        AND tariff_type           = @c_tariff_late_payment
        AND valid_from           <= @sy-datum
        AND valid_to             >= @sy-datum
        AND is_deleted            = @abap_false
      INTO CORRESPONDING FIELDS OF TABLE @lt_glacct.

    " ===== FASE A: determinacion de cuentas por GRUPO (array) — EF §6.2 =====
    " El accit del doc de interes NO trae la ref. origen; se determina por el
    " grupo (cs_ipf-array): item origen (ct_items) -> lt_bseg -> vbund/concepto.
    DATA lv_grp_vbund    TYPE vbund.
    DATA lv_grp_concepto TYPE xblnr1.
    DATA lv_grp_prctr    TYPE prctr.
    DATA lv_grp_kostl    TYPE kostl.
    DATA lv_grp_total    TYPE wrbtr.
    DATA lt_grp_cecos    TYPE tt_ceco_lines.

    READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_gi>) WITH KEY array = cs_ipf-array.
    IF sy-subrc = 0.
      READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_gb>)
        WITH TABLE KEY bukrs = <ls_gi>-bukrs
                       belnr = <ls_gi>-belnr
                       gjahr = <ls_gi>-gjahr
                       buzei = <ls_gi>-buzei.
      IF sy-subrc = 0.
        lv_grp_vbund    = <ls_gb>-vbund.
        lv_grp_concepto = <ls_gb>-concepto.
        lv_grp_prctr    = <ls_gb>-prctr.
        lv_grp_kostl    = <ls_gb>-kostl.
        " CeCo/CeBe se heredan de la factura origen (EF §6.3): la partida abierta
        " (cliente) no lleva CeCo; se toman de las lineas de servicio del MISMO
        " documento. Anclado al doc de la linea de cliente; NO afecta el importe.
        lt_grp_cecos = get_source_ceco(
          iv_bukrs = <ls_gb>-bukrs
          iv_belnr = <ls_gb>-belnr
          iv_gjahr = <ls_gb>-gjahr ).
        " Preservar CeCo/PCtr unico para el Doc1 IC (FASE B): primera linea
        READ TABLE lt_grp_cecos INTO DATA(ls_ceco_ic) INDEX 1.
        IF sy-subrc = 0.
          lv_grp_kostl = ls_ceco_ic-kostl.
          lv_grp_prctr = ls_ceco_ic-prctr.
        ENDIF.
      ENDIF.
    ENDIF.

    " Importe total del grupo (EF §6.3: importe acumulado)
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_ti>) WHERE array = cs_ipf-array.
      lv_grp_total = lv_grp_total + <ls_ti>-int_amount.
    ENDLOOP.

    " Determinacion por DOC_TYPE (EF §5.2/§6.3): una fila por documento
    DATA(ls_ga_ic) = determine_glacct( it_glacct   = lt_glacct
                                       iv_bukrs    = is_t001-bukrs
                                       iv_vbund    = lv_grp_vbund
                                       iv_concepto = lv_grp_concepto
                                       iv_doc_type = c_glkey_ic ).   " AR -> Doc1 (IC)
    DATA(ls_ga_ir) = determine_glacct( it_glacct   = lt_glacct
                                       iv_bukrs    = is_t001-bukrs
                                       iv_vbund    = lv_grp_vbund
                                       iv_concepto = lv_grp_concepto
                                       iv_doc_type = c_glkey_ir ).   " AP -> Doc2 (IR)
    DATA(ls_ga_ch) = determine_glacct( it_glacct   = lt_glacct
                                       iv_bukrs    = is_t001-bukrs
                                       iv_vbund    = lv_grp_vbund
                                       iv_concepto = lv_grp_concepto
                                       iv_doc_type = c_glkey_ch ).   " RR -> Doc3 (CH)

    " Se requieren las 3 filas con sus cuentas para generar los 3 documentos
    DATA ls_ctx_err TYPE zfint_post_log.
    IF ls_ga_ic-gl_account1 IS INITIAL OR ls_ga_ir-gl_account1 IS INITIAL
       OR ls_ga_ch-gl_account1 IS INITIAL OR ls_ga_ch-gl_account2 IS INITIAL.
      append_log_warn(
        EXPORTING iv_msgid = 'ZFI_INT' iv_msgno = '001'
                  iv_msgv1 = is_t001-bukrs iv_msgv2 = lv_grp_vbund
                  iv_text  = |Mora: cuentas incompletas en ZINT_A_MD_GLACCT (socio { lv_grp_vbund }, concepto { lv_grp_concepto }); se requieren filas AR/AP/RR|
        CHANGING  ct_log   = ct_log ).
      " [SDFPSINIC-23382] Trazabilidad en mt_err_log: contexto del grupo (leido en end_of_programm rama error).
      " ct_log se descarta en error; mt_err_log persiste fuera de la LUW del FINT.
      CLEAR ls_ctx_err.
      ls_ctx_err-run_status    = 'ER'. ls_ctx_err-doc_status = 'RB'. ls_ctx_err-severity = 'E'.
      ls_ctx_err-bukrs         = is_t001-bukrs. ls_ctx_err-vbund = lv_grp_vbund.
      ls_ctx_err-concepto      = lv_grp_concepto. ls_ctx_err-int_curr = cs_ipf-int_curr.
      ls_ctx_err-int_amount    = lv_grp_total. ls_ctx_err-cons_generation = 1.
      ls_ctx_err-erdat         = sy-datum. ls_ctx_err-erzet = sy-uzeit. ls_ctx_err-ernam = sy-uname.
      ls_ctx_err-msg_text      = |[CUENTAS] Sin config ZINT_A_MD_GLACCT: { lv_grp_vbund }/{ lv_grp_concepto }|.
      READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_ctx1_it>) WITH KEY array = cs_ipf-array.
      IF sy-subrc <> 0. READ TABLE ct_items ASSIGNING <ls_ctx1_it> INDEX 1. ENDIF.
      IF sy-subrc = 0.
        READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_ctx1_bs>)
          WITH TABLE KEY bukrs = <ls_ctx1_it>-bukrs belnr = <ls_ctx1_it>-belnr
                         gjahr = <ls_ctx1_it>-gjahr buzei = <ls_ctx1_it>-buzei.
        IF sy-subrc = 0.
          ls_ctx_err-source_belnr = <ls_ctx1_bs>-belnr.
          ls_ctx_err-source_gjahr = <ls_ctx1_bs>-gjahr.
        ENDIF.
      ENDIF.
      APPEND ls_ctx_err TO mt_err_log.
      cd_post_status = 'ERROR'.
      mv_post_error  = abap_true.
      RETURN.
    ENDIF.

    " ===== [SDFPSINIC-23382] Referencia (clave completa) en BKTXT de cabecera AR (22/07) =====
    " Nueva definicion funcional: la CLAVE COMPLETA de agrupamiento
    " (BUKRS+VBUND+CONCEPTO+WAERS+GJAHR+POPER) va al TEXTO de cabecera (BKTXT, 25).
    " ct_acchd es changing y tiene 1 header por llamada (cs_ipf singular = 1 grupo),
    " por eso la clave (derivada de cs_ipf-array) corresponde siempre a ese header.
    " BKTXT no tiene la validacion del set ZFI_ASIGNACION_DIVERSOS (esa es del ZUONR).
    " Solo AR aqui; AP/CH se haran luego. REVERSIBLE: comentar este bloque -> BKTXT estandar.
    DATA(lv_rundate_ref) = get_run_date( it_frange ).
    CLEAR mv_ref_key.
    " Formato: BUKRS espacio VBUND espacio CONCEPTO espacio WAERS+GJAHR+POPER (juntos). Ej: 'MLA DRM ICSRV11 USD202606' (25).
    mv_ref_key = |{ is_t001-bukrs } { lv_grp_vbund } { lv_grp_concepto } { cs_ipf-int_curr }{ lv_rundate_ref(4) }{ lv_rundate_ref+4(2) }|.
    LOOP AT ct_acchd ASSIGNING FIELD-SYMBOL(<ls_archd>).
      <ls_archd>-bktxt = mv_ref_key.
    ENDLOOP.
    " ===== fin bloque reversible =====

    " ===== [SDFPSINIC-23382] Referencia (XBLNR) en items del AR (22/07) =====
    " ACCHD no tiene campo XBLNR: el standard FINT propaga ACCIT-XBLNR al BKPF-XBLNR
    " del Doc1 (AR) via AC_DOCUMENT_POST. AP/CH leen it_accit[1]-xblnr -> ref_doc_no.
    " XBLNR1 = 16 chars -> mv_ref_key (25) se trunca silenciosamente (queda
    " 'BUKRS VBUND CONCEPTO'); la clave completa permanece en BKTXT (25).
    " REVERSIBLE: comentar este bloque -> XBLNR vuelve vacio (fallback int_belnr en AP/CH).
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_ref_it>).
*      <ls_ref_it>-xblnr = mv_ref_key.
      <ls_ref_it>-xblnr = lv_grp_concepto.
    ENDLOOP.
    " ===== fin bloque reversible =====

    " ===== [SDFPSINIC-23382] Assignment (ZUONR) en items del AR (22/07) =====
    " Setea ZUONR = 'Intereses por Mora' SOLO en las lineas que estan vacias
    " (validado en TS4: sale en el documento generado). El AP/CH replican el mismo
    " valor en su ALLOC_NMBR (post_ap_document_bapi / post_reclassification_bapi).
    " REVERSIBLE: comentar este bloque -> ZUONR vuelve al estandar.
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<ls_arzu>) WHERE zuonr IS INITIAL.
      <ls_arzu>-zuonr = 'INTERESES POR MORA'.
    ENDLOOP.
    " ===== fin bloque reversible =====
    TYPES: BEGIN OF ty_index,
             posnr TYPE posnr,
             ceco  TYPE kostl,
             prctr TYPE prctr,
             wrbtr TYPE wrbtr.
    TYPES: END OF ty_index.

    CONSTANTS: lc_min TYPE wrbtr VALUE '-0.05',
               lc_max TYPE wrbtr VALUE '0.05'.

    DATA: lt_index TYPE TABLE OF ty_index.
    DATA lv_wrbtr TYPE wrbtr .

    DATA(lt_accit_idx) = ct_accit[].
    DATA(lt_acccr_r) = ct_acccr[].
    DELETE lt_acccr_r WHERE wrbtr < lc_min OR wrbtr > lc_max.

    SORT lt_accit_idx ASCENDING BY prctr DESCENDING kostl DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_accit_idx COMPARING kostl prctr.

    DATA(lt_res) = lt_accit_idx[].
    DELETE lt_res WHERE prctr NE '0000000999'.

    LOOP AT lt_res ASSIGNING FIELD-SYMBOL(<fs_res>).

      READ TABLE ct_acccr ASSIGNING FIELD-SYMBOL(<fs_r1>) WITH KEY posnr = <fs_res>-posnr.

      IF sy-subrc IS INITIAL.
        APPEND INITIAL LINE TO lt_index ASSIGNING FIELD-SYMBOL(<fs_index>).
        <fs_index>-posnr = <fs_res>-posnr.
        <fs_index>-ceco  = <fs_res>-kostl.
        <fs_index>-prctr = <fs_res>-prctr.
        <fs_index>-wrbtr = <fs_r1>-wrbtr.
      ENDIF.
    ENDLOOP.

    CLEAR lv_wrbtr.

*   Busca prctr y corrige redondeo por mayor prctr hasta la diferencia
    LOOP AT ct_accit ASSIGNING FIELD-SYMBOL(<fs_accit>).
      DATA(lv_tabix) = sy-tabix.

      READ TABLE ct_acccr ASSIGNING FIELD-SYMBOL(<fs_acccrx>) WITH KEY posnr = <fs_accit>-posnr.
      IF sy-subrc IS INITIAL.
        DATA(lv_tabix2) = sy-tabix.
      ENDIF.

      IF <fs_accit>-kostl+7(3) = '999' AND abs( <fs_acccrx>-wrbtr ) <= lc_max.
        DELETE ct_accit INDEX lv_tabix.
        DELETE ct_acccr INDEX lv_tabix2.
        CLEAR: lv_tabix, lv_tabix2.
        CONTINUE.
      ENDIF.

      lv_wrbtr = <fs_acccrx>-wrbtr + lv_wrbtr.

      IF lv_wrbtr <> 0 AND abs( lv_wrbtr ) <= lc_max.
        READ TABLE lt_index ASSIGNING <fs_index> INDEX 1."WITH KEY posnr = <fs_accit>-posnr.
        IF sy-subrc IS INITIAL.

          <fs_acccrx>-wrbtr = <fs_acccrx>-wrbtr + <fs_index>-wrbtr.
          MODIFY ct_acccr FROM <fs_acccrx> INDEX lv_tabix2.
          CLEAR: lv_tabix, lv_tabix2.
        ENDIF.
      ENDIF.
    ENDLOOP.


    IF is_post_by_bapi( ) = abap_true.
      " Doc2/Doc3 via BAPI en la misma LUW del FINT. Cada BAPI vuelca sus mensajes
      " (lt_return) a ct_log; si hay error no se continua. end_of_programm decide
      " COMMIT/ROLLBACK segun mv_post_error (atomicidad EF).
      DATA lv_err_ap   TYPE abap_bool.
      DATA lv_err_rr   TYPE abap_bool.
      DATA lv_belnr_ap TYPE belnr_d.
      DATA lv_belnr_rr TYPE belnr_d.

      " ===== FASE 1: PRE-CHECK (modo teste) de los 2 documentos BAdI =====
      " Se validan AMBOS sin postear (BAPI_ACC_DOCUMENT_CHECK). Si cualquiera
      " falla, NO se contabiliza ninguno -> atomicidad entre Doc2 y Doc3.
      post_ap_document_bapi(
        EXPORTING is_t001     = is_t001
                  is_ipf      = cs_ipf
                  is_glacct   = ls_ga_ir
                  it_cecos    = lt_grp_cecos
                  it_accit    = ct_accit
                  it_acccr    = ct_acccr
                  iv_vbund    = lv_grp_vbund
                  iv_amount   = lv_grp_total
                  iv_doc_date = get_run_date( it_frange )
                  iv_testrun  = abap_true
        IMPORTING ev_error    = lv_err_ap
        CHANGING  ct_log      = ct_log ).

      IF lv_err_ap = abap_false.
        CLEAR ct_log[].

        post_reclassification_bapi(
          EXPORTING is_t001     = is_t001
                    is_ipf      = cs_ipf
                    is_glacct   = ls_ga_ch
                    it_cecos    = lt_grp_cecos
                    it_accit    = ct_accit
                    it_acccr    = ct_acccr
                    iv_vbund    = lv_grp_vbund
                    iv_amount   = lv_grp_total
                    iv_doc_date = get_run_date( it_frange )
                    iv_testrun  = abap_true
          IMPORTING ev_error    = lv_err_rr
          CHANGING  ct_log      = ct_log ).
      ENDIF.

      IF lv_err_ap = abap_true OR lv_err_rr = abap_true.
        " Pre-check fallo -> abortar el documento COMPLETO. cd_post_status='ERROR'
        " hace que el FINT NO poste el Doc1 (IC) estandar (RAISE error antes de
        " AC_DOCUMENT_GENERATE) -> no se contabiliza NINGUNO de los 3 (atomicidad).
        " [SDFPSINIC-23382] Trazabilidad en mt_err_log: contexto del grupo
        CLEAR ls_ctx_err.
        ls_ctx_err-run_status    = 'ER'. ls_ctx_err-doc_status = 'RB'. ls_ctx_err-severity = 'E'.
        ls_ctx_err-bukrs         = is_t001-bukrs. ls_ctx_err-vbund = lv_grp_vbund.
        ls_ctx_err-concepto      = lv_grp_concepto. ls_ctx_err-int_curr = cs_ipf-int_curr.
        ls_ctx_err-int_amount    = lv_grp_total. ls_ctx_err-cons_generation = 1.
        ls_ctx_err-erdat         = sy-datum. ls_ctx_err-erzet = sy-uzeit. ls_ctx_err-ernam = sy-uname.
        ls_ctx_err-msg_text      = |[PRE-CHECK] Validacion BAPI fallo para grupo { cs_ipf-array }|.
        READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_ctx2_it>) WITH KEY array = cs_ipf-array.
        IF sy-subrc <> 0. READ TABLE ct_items ASSIGNING <ls_ctx2_it> INDEX 1. ENDIF.
        IF sy-subrc = 0.
          READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_ctx2_bs>)
            WITH TABLE KEY bukrs = <ls_ctx2_it>-bukrs belnr = <ls_ctx2_it>-belnr
                           gjahr = <ls_ctx2_it>-gjahr buzei = <ls_ctx2_it>-buzei.
          IF sy-subrc = 0.
            ls_ctx_err-source_belnr = <ls_ctx2_bs>-belnr.
            ls_ctx_err-source_gjahr = <ls_ctx2_bs>-gjahr.
          ENDIF.
        ENDIF.
        APPEND ls_ctx_err TO mt_err_log.
        cd_post_status = 'ERROR'.
        mv_post_error  = abap_true.
        RETURN.
      ENDIF.

      " ===== FASE 2: POST REAL (solo si AMBOS pasaron el pre-check) =====
      CLEAR: lv_err_ap, lv_err_rr, ct_log[].

      DATA lv_run_id TYPE zfint_post_log-run_id.
      lv_run_id = |RUN-{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.

      APPEND INITIAL LINE TO ct_log ASSIGNING FIELD-SYMBOL(<fs_log>).
      <fs_log>-bukrs = is_t001-bukrs.
      <fs_log>-ltext = lv_run_id.

      post_ap_document_bapi(
        EXPORTING is_t001     = is_t001
                  is_ipf      = cs_ipf
                  is_glacct   = ls_ga_ir
                  it_cecos    = lt_grp_cecos
                  it_accit    = ct_accit
                  it_acccr    = ct_acccr
                  iv_vbund    = lv_grp_vbund
                  iv_amount   = lv_grp_total
                  iv_doc_date = get_run_date( it_frange )
                  iv_testrun  = abap_false
        IMPORTING ev_error    = lv_err_ap
                  ev_doc_no   = lv_belnr_ap
        CHANGING  ct_log      = ct_log ).

      IF lv_err_ap = abap_false.
        post_reclassification_bapi(
          EXPORTING is_t001     = is_t001
                    is_ipf      = cs_ipf
                    is_glacct   = ls_ga_ch
                    it_cecos    = lt_grp_cecos
                    it_accit    = ct_accit
                    it_acccr    = ct_acccr
                    iv_vbund    = lv_grp_vbund
                    iv_amount   = lv_grp_total
                    iv_doc_date = get_run_date( it_frange )
                    iv_testrun  = abap_false
          IMPORTING ev_error    = lv_err_rr
                    ev_doc_no   = lv_belnr_rr
          CHANGING  ct_log      = ct_log ).
      ENDIF.

      IF lv_err_ap = abap_true OR lv_err_rr = abap_true.
        " Error en el post real (raro tras check OK) -> abortar el Doc1 tambien.
        " cd_post_status='ERROR' -> FINT no llama AC_DOCUMENT_GENERATE; los Doc2/Doc3
        " en update task no llegan al COMMIT WORK -> atomicidad 3 o ninguno.
        " [SDFPSINIC-23382] Trazabilidad en mt_err_log: contexto del grupo
        CLEAR ls_ctx_err.
        ls_ctx_err-run_status    = 'ER'. ls_ctx_err-doc_status = 'RB'. ls_ctx_err-severity = 'E'.
        ls_ctx_err-bukrs         = is_t001-bukrs. ls_ctx_err-vbund = lv_grp_vbund.
        ls_ctx_err-concepto      = lv_grp_concepto. ls_ctx_err-int_curr = cs_ipf-int_curr.
        ls_ctx_err-int_amount    = lv_grp_total. ls_ctx_err-cons_generation = 1.
        ls_ctx_err-erdat         = sy-datum. ls_ctx_err-erzet = sy-uzeit. ls_ctx_err-ernam = sy-uname.
        ls_ctx_err-msg_text      = |[POST] Error al contabilizar Doc2/Doc3 grupo { cs_ipf-array }|.
        READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_ctx3_it>) WITH KEY array = cs_ipf-array.
        IF sy-subrc <> 0. READ TABLE ct_items ASSIGNING <ls_ctx3_it> INDEX 1. ENDIF.
        IF sy-subrc = 0.
          READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_ctx3_bs>)
            WITH TABLE KEY bukrs = <ls_ctx3_it>-bukrs belnr = <ls_ctx3_it>-belnr
                           gjahr = <ls_ctx3_it>-gjahr buzei = <ls_ctx3_it>-buzei.
          IF sy-subrc = 0.
            ls_ctx_err-source_belnr = <ls_ctx3_bs>-belnr.
            ls_ctx_err-source_gjahr = <ls_ctx3_bs>-gjahr.
          ENDIF.
        ENDIF.
        APPEND ls_ctx_err TO mt_err_log.
        cd_post_status = 'ERROR'.
        mv_post_error  = abap_true.
      ELSE.
        " ===== FASE C: log origen->consolidado por grupo (EF §7.2.4) =====
        LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_li>) WHERE array = cs_ipf-array.
          READ TABLE lt_bseg ASSIGNING FIELD-SYMBOL(<ls_lb>)
            WITH TABLE KEY bukrs = <ls_li>-bukrs
                           belnr = <ls_li>-belnr
                           gjahr = <ls_li>-gjahr
                           buzei = <ls_li>-buzei.
          CHECK sy-subrc = 0.
          APPEND VALUE #(
            bukrs           = is_t001-bukrs
            vbund           = <ls_lb>-vbund
            source_belnr    = <ls_lb>-belnr
            source_gjahr    = <ls_lb>-gjahr
            concepto        = <ls_lb>-concepto
            int_curr        = cs_ipf-int_curr
            int_amount      = <ls_li>-int_amount
            " Dias sujetos a interes = dias totales - 90 de gracia (EF §3.3),
*             coherente con int_formula. Antes se grababa el total (<ls_li>-int_days).
            dias_mora       = COND #( WHEN <ls_li>-int_days > 90
                                      THEN <ls_li>-int_days - 90
                                      ELSE 0 )
*            dias_mora       = <ls_li>-int_days
            cons_generation = 1
            array           = cs_ipf-array
            belnr_ap        = lv_belnr_ap
            belnr_rr        = lv_belnr_rr
          ) TO mt_post_log.
        ENDLOOP.

        IF mt_post_log[] IS INITIAL.
          LOOP AT ct_items ASSIGNING <ls_li>.
            READ TABLE lt_bseg ASSIGNING <ls_lb>
              WITH TABLE KEY bukrs = <ls_li>-bukrs
                             belnr = <ls_li>-belnr
                             gjahr = <ls_li>-gjahr
                             buzei = <ls_li>-buzei.
            CHECK sy-subrc = 0.
            APPEND VALUE #(
              bukrs           = is_t001-bukrs
              vbund           = <ls_lb>-vbund
              source_belnr    = <ls_lb>-belnr
              source_gjahr    = <ls_lb>-gjahr
              concepto        = <ls_lb>-concepto
              int_curr        = cs_ipf-int_curr
              int_amount      = <ls_li>-int_amount
              " Dias sujetos a interes = dias totales - 90 de gracia (EF §3.3),
              " coherente con int_formula. Antes se grababa el total (<ls_li>-int_days).
              dias_mora       = COND #( WHEN <ls_li>-int_days > 90
                                        THEN <ls_li>-int_days - 90
                                        ELSE 0 )
*              dias_mora       = <ls_li>-int_days
              cons_generation = 1
              array           = cs_ipf-array
              belnr_ap        = lv_belnr_ap
              belnr_rr        = lv_belnr_rr
            ) TO mt_post_log.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ELSE.
      build_ap_document_eml(
        is_t001   = is_t001
        is_ipf    = cs_ipf
        it_accit  = ct_accit
        it_bseg   = lt_bseg
        it_glacct = lt_glacct ).

      build_reclass_document_eml(
        is_t001   = is_t001
        is_ipf    = cs_ipf
        it_accit  = ct_accit
        it_bseg   = lt_bseg
        it_glacct = lt_glacct ).
    ENDIF.


  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_options.       ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_results.       ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_spool_closed.  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_reverse.             ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_sel_mod.             ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_show_buttons.        ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_write_items.         ENDMETHOD.


  METHOD if_ex_fi_int_sap01~sort_master_data.        ENDMETHOD.


  METHOD remember_tr_customers.
    CLEAR mt_tr_knb1.
    LOOP AT it_knb1 ASSIGNING FIELD-SYMBOL(<ls_knb1>) WHERE vzskz = 'TR'.
      APPEND <ls_knb1> TO mt_tr_knb1.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_tr_item.
    rv_tr = abap_false.

    " FINT com VZSKZ = TR usa esta implementacao para todas as linhas da selecao.
    " A lista de clientes TR define o modo global e evita o filtro item a item.
    IF mt_tr_knb1 IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Reconhecimento pelo próprio item (INT_IND = 'TR'): não depende de estado
    " preenchido por outro método.
    FIELD-SYMBOLS <lv_ind> TYPE any.
    ASSIGN COMPONENT 'INT_IND' OF STRUCTURE is_item TO <lv_ind>.
    IF <lv_ind> IS ASSIGNED AND <lv_ind> = 'TR'.
      rv_tr = abap_true.
      RETURN.
    ENDIF.

    " Reserva: clientes TR memorizados (CT/IT_KNB1)
    IF mt_tr_knb1 IS INITIAL.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lv_bukrs> TYPE any.
    FIELD-SYMBOLS <lv_kunnr> TYPE any.

    ASSIGN COMPONENT 'BUKRS' OF STRUCTURE is_item TO <lv_bukrs>.
    IF <lv_bukrs> IS NOT ASSIGNED.
      ASSIGN COMPONENT 'BUKRS_TO' OF STRUCTURE is_item TO <lv_bukrs>.
    ENDIF.

    ASSIGN COMPONENT 'KUNNR' OF STRUCTURE is_item TO <lv_kunnr>.
    IF <lv_kunnr> IS NOT ASSIGNED.
      ASSIGN COMPONENT 'ACCOUNT' OF STRUCTURE is_item TO <lv_kunnr>.
    ENDIF.

    IF <lv_bukrs> IS NOT ASSIGNED OR <lv_kunnr> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    READ TABLE mt_tr_knb1 TRANSPORTING NO FIELDS
      WITH KEY bukrs = CONV bukrs( <lv_bukrs> )
               kunnr = CONV kunnr( <lv_kunnr> ).
    rv_tr = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD call_tr_process.
    CONSTANTS lc_class  TYPE seoclsname VALUE 'ZTR_C000123_AMORT_FINANC_VEIC'.
    CONSTANTS lc_method TYPE seocpdname VALUE 'PROCESS'.

    DATA ls_clskey TYPE seoclskey.
    DATA lo_object TYPE REF TO object.

    ls_clskey-clsname = lc_class.

    CALL FUNCTION 'SEO_CLASS_EXISTENCE_CHECK'
      EXPORTING
        clskey       = ls_clskey
      EXCEPTIONS
        not_existing = 1
        OTHERS       = 2.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    TRY.
        CREATE OBJECT lo_object TYPE (lc_class).
        CALL METHOD lo_object->(lc_method).
      CATCH cx_root.
        " Classe ainda sem construtor/método PROCESS compatível: não interfere no fluxo standard.
    ENDTRY.
  ENDMETHOD.


  METHOD call_tr_class.
    " Chama dinamicamente um método da classe TR enviando SÓ os itens TR.
    " Convenção: o método chamado tem o parâmetro CHANGING CT_ITEMS
    " (FINT_TT_INTIT_EXTF) e NÃO pode incluir, excluir nem reordenar linhas.
    " Só INT_AMOUNT volta à tabela original (por índice).
    " Classe inexistente ou com falha: ignora, sem afetar os demais clientes.
    CONSTANTS lc_class TYPE seoclsname VALUE 'ZTR_C000123_AMORT_FINANC_VEIC'.

    DATA(lt_tr) = VALUE fint_tt_intit_extf(
                    FOR ls_src IN ct_items WHERE ( int_ind = 'TR' ) ( ls_src ) ).
    IF lt_tr IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_clskey TYPE seoclskey.
    ls_clskey-clsname = lc_class.
    CALL FUNCTION 'SEO_CLASS_EXISTENCE_CHECK'
      EXPORTING
        clskey       = ls_clskey
      EXCEPTIONS
        not_existing = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lo_object TYPE REF TO object.
    TRY.
        CREATE OBJECT lo_object TYPE (lc_class).

        DATA(lt_ptab) = VALUE abap_parmbind_tab(
          ( name  = 'CT_ITEMS'
            kind  = cl_abap_objectdescr=>changing
            value = REF #( lt_tr ) ) ).
        CALL METHOD lo_object->(iv_method) PARAMETER-TABLE lt_ptab.

        DATA(lv_idx) = 0.
        LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_orig>) WHERE int_ind = 'TR'.
          lv_idx += 1.
          <ls_orig>-int_amount = lt_tr[ lv_idx ]-int_amount.
        ENDLOOP.
      CATCH cx_root.
        " falha na classe TR não pode afetar os demais clientes
    ENDTRY.
  ENDMETHOD.


  METHOD is_mora_active.
    DATA lv_active TYPE tvarvc-low.
    TRY.
        NEW zcl_tvarvc( )->get_parameter(
          EXPORTING i_name  = c_tvarvc_active
          IMPORTING e_value = lv_active ).
      CATCH zcx_tvarvc.
        rv_active = abap_false.   " parâmetro inexistente -> toggle desligado
        RETURN.
    ENDTRY.
    rv_active = boolc( lv_active = 'X' ).
  ENDMETHOD.


  METHOD is_post_by_bapi.
    DATA lv_val TYPE tvarvc-low.
    TRY.
        NEW zcl_tvarvc( )->get_parameter(
          EXPORTING i_name  = 'ZFI_MORA_POST_BY_BAPI'
          IMPORTING e_value = lv_val ).
      CATCH zcx_tvarvc.
        rv_bapi = abap_false.   " sin parametro -> EML (comportamiento actual)
        RETURN.
    ENDTRY.
    rv_bapi = boolc( lv_val = 'X' ).
  ENDMETHOD.


  METHOD post_ap_document_bapi.
    " Doc2 (IR) via BAPI - misma LUW (sin commit; lo controla end_of_programm)
    DATA ls_header    TYPE bapiache09.
    DATA lt_accountgl TYPE STANDARD TABLE OF bapiacgl09.
    DATA lt_accountap TYPE STANDARD TABLE OF bapiacap09.
    DATA lt_currency  TYPE STANDARD TABLE OF bapiaccr09.
    DATA lt_return    TYPE STANDARD TABLE OF bapiret2.
    DATA lv_obj_type  TYPE bapiache09-obj_type.
    DATA lv_obj_key   TYPE bapiache09-obj_key.
    DATA lv_obj_sys   TYPE bapiache09-obj_sys.

    " Fecha efectiva: netdt del FINT; si viene inicial, fallback a la fecha del run
    " (PROVISORIO - a validar con funcional)
    DATA(lv_date_eff) = is_ipf-netdt.
    IF lv_date_eff IS INITIAL.
      lv_date_eff = iv_doc_date.
    ENDIF.

    DATA(lv_close_date) = get_quarter_close_date( lv_date_eff ).
    DATA(lv_kursf) = get_exchange_rate(
      iv_fcurr = is_ipf-int_curr
      iv_date  = lv_close_date ).

    ls_header-bus_act    = c_bus_act.
    ls_header-username   = sy-uname.
    " [SDFPSINIC-23382] BKTXT = clave completa de agrupamiento (mv_ref_key, set en int_post).
    " Misma clave que el AR (cabecera). Fallback al texto estandar si viene vacia.
    ls_header-header_txt = COND #( WHEN mv_ref_key IS NOT INITIAL THEN mv_ref_key
                                   ELSE |INT MORA IC Q{ lv_close_date+4(2) } { lv_close_date(4) }| ).
    " EF §5.2/§6.3: el documento IR (AP) se contabiliza en la sociedad PRESTATARIA
    " (deudora = vbund), siendo MLA (is_t001-bukrs) el BP acreedor / trading partner.
    ls_header-comp_code  = iv_vbund.
    ls_header-doc_date   = lv_date_eff.
    ls_header-pstng_date = lv_date_eff.
    ls_header-doc_type   = c_doctype_ap.
    " [SDFPSINIC-23382] Referencia = clave de agrupamiento (viene en it_accit-xblnr,
    " seteada en int_post). Fallback a int_belnr si no viene (bloque AR comentado).
    DATA lv_ref_ap TYPE xblnr.
    IF it_accit IS NOT INITIAL.
      lv_ref_ap = it_accit[ 1 ]-xblnr.
    ENDIF.
    ls_header-ref_doc_no = COND #( WHEN lv_ref_ap IS NOT INITIAL THEN lv_ref_ap ELSE is_ipf-int_belnr ).

    CHECK iv_amount IS NOT INITIAL.

    " == Fix ct_accit (Fix_AP_Espejo_AR / 20/07): AP = espejo 1:1 del AR ==
    " Fuente = it_accit (lineas GL del AR ya distribuidas por el standard) + it_acccr
    " (importe por posnr, curtp '00'). Se EXCLUYE la linea de cliente (koart='D'):
    " el AR estandar genera 30 lineas = 29 GL + 1 cliente -> el AP espeja las 29 GL + 1 prov.
    " Importe = contrapartida del AR (amt = -WRBTR): ingreso AR(H) -> AP debito; gasto
    " AR(S) -> AP credito; balancea contra la linea de proveedor (neto). CeCo real del AR
    " traducido a la prestataria (pos 5-7 <- interlocutor is_ipf-account) si vbund <> MLA.
    " Reemplaza el intento previo con it_items (fallaba: 1 linea + CeCo vacio, prueba TS4 20/07).
    DATA lv_itm_ap   TYPE i.
    DATA lv_kostl_ln TYPE kostl.
    DATA lv_prctr_ln TYPE prctr.
    DATA lv_amt_ar   TYPE wrbtr.
    CLEAR lv_itm_ap.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_ai>) WHERE koart = 'S'.
      lv_itm_ap = lv_itm_ap + 1.

      " Importe = contrapartida (signo invertido) del AR, desde it_acccr por posnr
      CLEAR lv_amt_ar.
      READ TABLE it_acccr ASSIGNING FIELD-SYMBOL(<ls_cr>)
        WITH KEY posnr = <ls_ai>-posnr curtp = '00'.
      IF sy-subrc = 0.
        lv_amt_ar = <ls_cr>-wrbtr.
      ENDIF.

      " CeCo real del AR + traduccion a la prestataria (solo si vbund <> MLA)
      lv_kostl_ln = <ls_ai>-kostl.
      lv_prctr_ln = <ls_ai>-prctr.
      IF iv_vbund <> is_t001-bukrs
         AND lv_kostl_ln IS NOT INITIAL
         AND strlen( lv_kostl_ln )    >= 7
         AND strlen( is_ipf-account ) >= 6.
        lv_kostl_ln+4(3) = is_ipf-account+3(3).
      ENDIF.

      APPEND VALUE #( itemno_acc = lv_itm_ap
                      gl_account = is_glacct-gl_account1
                      comp_code  = iv_vbund
                      trade_id   = is_t001-bukrs
                      item_text  = ls_header-header_txt
                      profit_ctr = lv_prctr_ln
                      costcenter = lv_kostl_ln ) TO lt_accountgl.
      APPEND VALUE #( itemno_acc = lv_itm_ap
                      currency   = is_ipf-int_curr
                      amt_doccur = lv_amt_ar * -1
                      exch_rate  = lv_kursf ) TO lt_currency.
    ENDLOOP.

    " Pos. AP Haber (proveedor prestadora IC0122) - 1 linea, total negativo
    lv_itm_ap = lv_itm_ap + 1.
    APPEND VALUE #( itemno_acc = lv_itm_ap
                    vendor_no  = c_bp_prestadora
                    comp_code  = iv_vbund
                    item_text  = ls_header-header_txt ) TO lt_accountap.
    APPEND VALUE #( itemno_acc = lv_itm_ap
                    currency   = is_ipf-int_curr
                    amt_doccur = iv_amount * -1
                    exch_rate  = lv_kursf ) TO lt_currency.

    " ===== [SDFPSINIC-23382] Assignment (ALLOC_NMBR) en AP (22/07) =====
    " Validado en TS4 (debug): 'INTERESES POR MORA' (mayusculas) pasa la validacion del
    " set ZFI_ASIGNACION_DIVERSOS. Se aplica a todas las lineas GL y de proveedor del AP.
    " REVERSIBLE: comentar el bloque.
    LOOP AT lt_accountgl ASSIGNING FIELD-SYMBOL(<ls_asg_gl>).
      <ls_asg_gl>-alloc_nmbr = 'INTERESES POR MORA'.
    ENDLOOP.
    LOOP AT lt_accountap ASSIGNING FIELD-SYMBOL(<ls_asg_ap>).
      <ls_asg_ap>-alloc_nmbr = 'INTERESES POR MORA'.
    ENDLOOP.
    " ===== fin bloque reversible =====

    CHECK lt_accountgl IS NOT INITIAL.

    DATA(lv_fm) = get_bapi_post_fm( ).
    TRY.
        IF iv_testrun = abap_true.
          " Modo teste (pre-check): valida sin postear ni reservar numero.
          " FM por variable (igual que el post) para no acoplar la BAPI clasica.
          DATA(lv_fm_check) = CONV rs38l_fnam( 'BAPI_ACC_DOCUMENT_CHECK' ).
          CALL FUNCTION lv_fm_check
            EXPORTING
              documentheader = ls_header
            TABLES
              accountgl      = lt_accountgl
              accountpayable = lt_accountap
              currencyamount = lt_currency
              return         = lt_return.
        ELSE.
          CALL FUNCTION lv_fm
            EXPORTING
              documentheader = ls_header
            IMPORTING
              obj_type       = lv_obj_type
              obj_key        = lv_obj_key
              obj_sys        = lv_obj_sys
            TABLES
              accountgl      = lt_accountgl
              accountpayable = lt_accountap
              currencyamount = lt_currency
              return         = lt_return.
          " Numero del documento generado (obj_key = AWKEY = BELNR+BUKRS+GJAHR)
          ev_doc_no = lv_obj_key(10).
        ENDIF.
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #( type = 'E' message = lx_root->get_text( ) ) TO lt_return.
    ENDTRY.

    " Volcar los mensajes de la BAPI al log (LTEXT/MSGNO) SIN lanzar excepcion.
    " Marcar ev_error si hay E/A para que el caller no continue (comportamiento del catch).
    CLEAR ev_error.
    DATA ls_log LIKE LINE OF ct_log.
    IF lt_return IS NOT INITIAL.
      " Cabecera del bloque: identifica el tipo de documento (EF §5.2)
      CLEAR ls_log.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_hbk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_hty>).
      ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_htx>).
      IF <f_hbk> IS ASSIGNED. <f_hbk> = is_t001-bukrs.                       ENDIF.
      IF <f_hty> IS ASSIGNED. <f_hty> = 'I'.                                  ENDIF.
      IF <f_htx> IS ASSIGNED. <f_htx> = |[{ c_glkey_ir }] Cuentas por Pagar|. ENDIF.
      APPEND ls_log TO ct_log.
    ENDIF.
    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_ret>).
      CLEAR ls_log.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_bk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_ty>).
      ASSIGN COMPONENT 'MSGID' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_id>).
      ASSIGN COMPONENT 'MSGNO' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_no>).
      ASSIGN COMPONENT 'MSGV1' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v1>).
      ASSIGN COMPONENT 'MSGV2' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v2>).
      ASSIGN COMPONENT 'MSGV3' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v3>).
      ASSIGN COMPONENT 'MSGV4' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v4>).
      ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_tx>).
      IF <f_bk> IS ASSIGNED. <f_bk> = is_t001-bukrs.       ENDIF.
      IF <f_ty> IS ASSIGNED. <f_ty> = <ls_ret>-type.       ENDIF.
      IF <f_id> IS ASSIGNED. <f_id> = <ls_ret>-id.         ENDIF.
      IF <f_no> IS ASSIGNED. <f_no> = <ls_ret>-number.     ENDIF.
      IF <f_v1> IS ASSIGNED. <f_v1> = <ls_ret>-message_v1. ENDIF.
      IF <f_v2> IS ASSIGNED. <f_v2> = <ls_ret>-message_v2. ENDIF.
      IF <f_v3> IS ASSIGNED. <f_v3> = <ls_ret>-message_v3. ENDIF.
      IF <f_v4> IS ASSIGNED. <f_v4> = <ls_ret>-message_v4. ENDIF.
      IF <f_tx> IS ASSIGNED. <f_tx> = <ls_ret>-message.    ENDIF.
      APPEND ls_log TO ct_log.
      IF <ls_ret>-type = 'E' OR <ls_ret>-type = 'A'.
        ev_error = abap_true.
        " Registrar el mensaje de error para volcarlo a ZFINT_POST_LOG
        " (identificado por tipo de documento IR) en end_of_programm.
        APPEND VALUE #( run_status = 'ER'
                        doc_status = 'RB'
                        severity   = <ls_ret>-type
                        msgid      = <ls_ret>-id
                        msgno      = <ls_ret>-number
                        msg_text   = |[{ c_doctype_ap }] { <ls_ret>-message }|
                        bukrs      = is_t001-bukrs
                        vbund      = iv_vbund
                        int_curr   = is_ipf-int_curr
                        int_amount = iv_amount
                        erdat      = sy-datum
                        erzet      = sy-uzeit
                        ernam      = sy-uname ) TO mt_err_log.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD post_reclassification_bapi.
    " Doc3 (CH, ledger 0LL1) via BAPI - misma LUW
    DATA ls_header    TYPE bapiache09.
    DATA lt_accountgl TYPE STANDARD TABLE OF bapiacgl09.
    DATA lt_currency  TYPE STANDARD TABLE OF bapiaccr09.
    DATA lt_return    TYPE STANDARD TABLE OF bapiret2.
    DATA lv_obj_type  TYPE bapiache09-obj_type.
    DATA lv_obj_key   TYPE bapiache09-obj_key.
    DATA lv_obj_sys   TYPE bapiache09-obj_sys.

    " Fecha efectiva: netdt del FINT; si viene inicial, fallback a la fecha del run
    " (PROVISORIO - a validar con funcional)
    DATA(lv_date_eff) = is_ipf-netdt.
    IF lv_date_eff IS INITIAL.
      lv_date_eff = iv_doc_date.
    ENDIF.

    DATA(lv_close_date) = get_quarter_close_date( lv_date_eff ).
    DATA(lv_kursf) = get_exchange_rate(
      iv_fcurr = is_ipf-int_curr
      iv_date  = lv_close_date ).

    ls_header-bus_act      = c_bus_act.
    ls_header-username     = sy-uname.
    " [SDFPSINIC-23382] BKTXT = clave completa de agrupamiento (mv_ref_key, set en int_post).
    " Misma clave que el AR (cabecera). Fallback al texto estandar si viene vacia.
    ls_header-header_txt   = COND #( WHEN mv_ref_key IS NOT INITIAL THEN mv_ref_key
                                     ELSE |RECLAS INT MORA IC Q{ lv_close_date+4(2) } { lv_close_date(4) }| ).
    ls_header-comp_code    = is_t001-bukrs.
    ls_header-doc_date     = lv_date_eff.
    ls_header-pstng_date   = lv_date_eff.
    ls_header-doc_type     = c_doctype_recl.
    " [SDFPSINIC-23382] Referencia = clave de agrupamiento (viene en it_accit-xblnr,
    " seteada en int_post). Fallback a int_belnr si no viene (bloque AR comentado).
    DATA lv_ref_rr TYPE xblnr.
    IF it_accit IS NOT INITIAL.
      lv_ref_rr = it_accit[ 1 ]-xblnr.
    ENDIF.
    ls_header-ref_doc_no   = COND #( WHEN lv_ref_rr IS NOT INITIAL THEN lv_ref_rr ELSE is_ipf-int_belnr ).
    ls_header-ledger_group = c_ledger_recl.

    CHECK iv_amount IS NOT INITIAL.

    " == CH pares por CeCo (RESTAURADO 21/07): CH = espejo del AR, un par por linea GL.
    " Fuente = it_accit (lineas GL del AR consolidado por el standard) + it_acccr
    " (importe por posnr, curtp '00'). Par Debe 692196 / Haber 469001 con el MISMO
    " CeCo real del AR por linea (CH permanece en MLA, sin traducir). Importe =
    " contrapartida (-WRBTR). Ambas cuentas son coste primario (KATYP 01) y EXIGEN
    " CeCo -> la contrapartida 469001 NO puede consolidarse en 1 linea sin CeCo
    " (TS4 21/07: 'La cuenta 469001 requiere imputacion CO'). Reclasificacion CeCo-neutra.
    " Pendiente: validar con Funcional si 469001 admite contrapartida unica.
    DATA lv_itm_rr TYPE i.
    DATA lv_amt_rr TYPE wrbtr.
    CLEAR lv_itm_rr.

    LOOP AT it_accit ASSIGNING FIELD-SYMBOL(<ls_ai>) WHERE koart = 'S'.
      CLEAR lv_amt_rr.
      READ TABLE it_acccr ASSIGNING FIELD-SYMBOL(<ls_cr>)
        WITH KEY posnr = <ls_ai>-posnr curtp = '00'.
      IF sy-subrc = 0.
        lv_amt_rr = <ls_cr>-wrbtr * -1.
      ENDIF.

      " Pos. Debe (gl_account1 = 692196) - CeCo real del AR
      lv_itm_rr = lv_itm_rr + 1.
      APPEND VALUE #( itemno_acc = lv_itm_rr
                      gl_account = is_glacct-gl_account1
                      comp_code  = is_t001-bukrs
                      item_text  = ls_header-header_txt
                      profit_ctr = <ls_ai>-prctr
                      costcenter = <ls_ai>-kostl
                      trade_id   = iv_vbund ) TO lt_accountgl.
      APPEND VALUE #( itemno_acc = lv_itm_rr
                      currency   = is_ipf-int_curr
                      amt_doccur = lv_amt_rr
                      exch_rate  = lv_kursf ) TO lt_currency.

      " Pos. Haber (gl_account2 = 469001) - MISMO CeCo (reclasificacion CeCo-neutra)
      lv_itm_rr = lv_itm_rr + 1.
      APPEND VALUE #( itemno_acc = lv_itm_rr
                      gl_account = is_glacct-gl_account2
                      comp_code  = is_t001-bukrs
                      item_text  = ls_header-header_txt
                      profit_ctr = <ls_ai>-prctr
                      costcenter = <ls_ai>-kostl
                      trade_id   = iv_vbund ) TO lt_accountgl.
      APPEND VALUE #( itemno_acc = lv_itm_rr
                      currency   = is_ipf-int_curr
                      amt_doccur = lv_amt_rr * -1
                      exch_rate  = lv_kursf ) TO lt_currency.
    ENDLOOP.


    " ===== [SDFPSINIC-23382] Assignment (ALLOC_NMBR) en CH (22/07) =====
    " Validado en TS4 (debug): 'INTERESES POR MORA' (mayusculas) pasa la validacion del
    " set ZFI_ASIGNACION_DIVERSOS. Se aplica a todas las lineas GL del CH (pares
    " 692196/469001). REVERSIBLE: comentar el bloque.
    LOOP AT lt_accountgl ASSIGNING FIELD-SYMBOL(<ls_asg_rr>).
      <ls_asg_rr>-alloc_nmbr = 'INTERESES POR MORA'.
    ENDLOOP.
    " ===== fin bloque reversible =====

    CHECK lt_accountgl IS NOT INITIAL.

    DATA(lv_fm) = get_bapi_post_fm( ).
    TRY.
        IF iv_testrun = abap_true.
          " Modo teste (pre-check): valida sin postear ni reservar numero.
          " FM por variable (igual que el post) para no acoplar la BAPI clasica.
          DATA(lv_fm_check) = CONV rs38l_fnam( 'BAPI_ACC_DOCUMENT_CHECK' ).
          CALL FUNCTION lv_fm_check
            EXPORTING
              documentheader = ls_header
            TABLES
              accountgl      = lt_accountgl
              currencyamount = lt_currency
              return         = lt_return.
        ELSE.
          CALL FUNCTION lv_fm
            EXPORTING
              documentheader = ls_header
            IMPORTING
              obj_type       = lv_obj_type
              obj_key        = lv_obj_key
              obj_sys        = lv_obj_sys
            TABLES
              accountgl      = lt_accountgl
              currencyamount = lt_currency
              return         = lt_return.
          " Numero del documento generado (obj_key = AWKEY = BELNR+BUKRS+GJAHR)
          ev_doc_no = lv_obj_key(10).
        ENDIF.
      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE #( type = 'E' message = lx_root->get_text( ) ) TO lt_return.
    ENDTRY.

    " Volcar los mensajes de la BAPI al log (LTEXT/MSGNO) SIN lanzar excepcion.
    " Marcar ev_error si hay E/A para que el caller no continue (comportamiento del catch).
    CLEAR ev_error.
    DATA ls_log LIKE LINE OF ct_log.
    IF lt_return IS NOT INITIAL.
      " Cabecera del bloque: identifica el tipo de documento (EF §5.2)
      CLEAR ls_log.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_hbk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_hty>).
      ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_htx>).
      IF <f_hbk> IS ASSIGNED. <f_hbk> = is_t001-bukrs.                       ENDIF.
      IF <f_hty> IS ASSIGNED. <f_hty> = 'I'.                                  ENDIF.
      IF <f_htx> IS ASSIGNED. <f_htx> = |[{ c_glkey_ch }] Reclasificación|.   ENDIF.
      APPEND ls_log TO ct_log.
    ENDIF.
    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_ret>).
      CLEAR ls_log.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_bk>).
      ASSIGN COMPONENT 'MSGTY' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_ty>).
      ASSIGN COMPONENT 'MSGID' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_id>).
      ASSIGN COMPONENT 'MSGNO' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_no>).
      ASSIGN COMPONENT 'MSGV1' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v1>).
      ASSIGN COMPONENT 'MSGV2' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v2>).
      ASSIGN COMPONENT 'MSGV3' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v3>).
      ASSIGN COMPONENT 'MSGV4' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_v4>).
      ASSIGN COMPONENT 'LTEXT' OF STRUCTURE ls_log TO FIELD-SYMBOL(<f_tx>).
      IF <f_bk> IS ASSIGNED. <f_bk> = is_t001-bukrs.       ENDIF.
      IF <f_ty> IS ASSIGNED. <f_ty> = <ls_ret>-type.       ENDIF.
      IF <f_id> IS ASSIGNED. <f_id> = <ls_ret>-id.         ENDIF.
      IF <f_no> IS ASSIGNED. <f_no> = <ls_ret>-number.     ENDIF.
      IF <f_v1> IS ASSIGNED. <f_v1> = <ls_ret>-message_v1. ENDIF.
      IF <f_v2> IS ASSIGNED. <f_v2> = <ls_ret>-message_v2. ENDIF.
      IF <f_v3> IS ASSIGNED. <f_v3> = <ls_ret>-message_v3. ENDIF.
      IF <f_v4> IS ASSIGNED. <f_v4> = <ls_ret>-message_v4. ENDIF.
      IF <f_tx> IS ASSIGNED. <f_tx> = <ls_ret>-message.    ENDIF.
      APPEND ls_log TO ct_log.
      IF <ls_ret>-type = 'E' OR <ls_ret>-type = 'A'.
        ev_error = abap_true.
        " Registrar el mensaje de error para volcarlo a ZFINT_POST_LOG
        " (identificado por tipo de documento CH) en end_of_programm.
        APPEND VALUE #( run_status = 'ER'
                        doc_status = 'RB'
                        severity   = <ls_ret>-type
                        msgid      = <ls_ret>-id
                        msgno      = <ls_ret>-number
                        msg_text   = |[{ c_doctype_recl }] { <ls_ret>-message }|
                        bukrs      = is_t001-bukrs
                        vbund      = iv_vbund
                        int_curr   = is_ipf-int_curr
                        int_amount = iv_amount
                        erdat      = sy-datum
                        erzet      = sy-uzeit
                        ernam      = sy-uname ) TO mt_err_log.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.

