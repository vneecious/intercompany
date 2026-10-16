INTERFACE zif_fi_items_change_zfbdt
  PUBLIC.

  TYPES: BEGIN OF ty_item,
           bukrs TYPE bukrs,
           belnr TYPE belnr_d,
           gjahr TYPE gjahr,
           buzei TYPE buzei,
           zfbdt TYPE dzfbdt,
         END OF ty_item.
  TYPES ty_t_item  TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.
  TYPES ty_r_belnr TYPE RANGE OF belnr_d.
  TYPES ty_r_blart TYPE RANGE OF blart.
  TYPES ty_r_buzei TYPE RANGE OF buzei.

  "! Resultado de error por documento (tipo propio, sin dependencia de type group)
  TYPES: BEGIN OF ty_error,
           bukrs   TYPE bukrs,
           belnr   TYPE belnr_d,
           gjahr   TYPE gjahr,
           msgty   TYPE symsgty,
           msgid   TYPE symsgid,
           msgno   TYPE symsgno,
           message TYPE bapi_msg,
         END OF ty_error.
  TYPES ty_t_error TYPE STANDARD TABLE OF ty_error WITH DEFAULT KEY.

  "! Resultado por posicion (alimenta el ALV del report) - antes/despues + estado
  TYPES: BEGIN OF ty_result,
           bukrs     TYPE bukrs,
           belnr     TYPE belnr_d,
           gjahr     TYPE gjahr,
           buzei     TYPE buzei,
           bschl     TYPE bschl,
           koart     TYPE koart,
           shkzg     TYPE shkzg,
           dmbtr     TYPE dmbtr,
           zfbdt_old TYPE dzfbdt,
           zfbdt_new TYPE dzfbdt,
           status    TYPE char12,
           message   TYPE bapi_msg,
         END OF ty_result.
  TYPES ty_t_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

  "! Verifica existencia de la sociedad via CDS liberada I_CompanyCode
  METHODS company_code_exists
    IMPORTING iv_bukrs         TYPE bukrs
    RETURNING VALUE(rv_exists) TYPE abap_bool.

  "! Selecciona documentos + ZFBDT via CDS (I_JournalEntry + I_OperationalAcctgDocItem)
  METHODS select_items
    IMPORTING iv_bukrs        TYPE bukrs
              iv_gjahr        TYPE gjahr
              it_belnr        TYPE ty_r_belnr OPTIONAL
              it_blart        TYPE ty_r_blart OPTIONAL
              it_buzei        TYPE ty_r_buzei OPTIONAL
    RETURNING VALUE(rt_items) TYPE ty_t_item.

  "! Cambia ZFBDT encapsulando el FM interno FI_ITEMS_MASS_CHANGE (motor BDC - legado)
  METHODS change_base_date
    IMPORTING it_items  TYPE ty_t_item
              iv_zfbdt  TYPE dzfbdt
    EXPORTING et_errors TYPE ty_t_error
    RAISING   zcx_mora_post_error.

  "! Cambia ZFBDT replicando la logica del estandar RFVD_CHK_CHANGE_CLEARING
  "! (UPDATE directo BSEG/ACDOCA + change docs + delta BW), masivo, salida en tabla.
  "! Validacion total previa (simulacion) y grabacion all-or-nothing en 1 LUW.
  METHODS change_base_date_direct
    IMPORTING it_items         TYPE ty_t_item
              iv_zfbdt         TYPE dzfbdt
              iv_update        TYPE abap_bool DEFAULT abap_false
    RETURNING VALUE(rt_result) TYPE ty_t_result
    RAISING   zcx_mora_post_error.

ENDINTERFACE.
