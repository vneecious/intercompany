CLASS zcl_mm_create_po DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CLASS-METHODS get_instance
      RETURNING
        VALUE(ro_instance) TYPE REF TO zcl_mm_create_po .
    CLASS-METHODS call_bapi_po_create
      IMPORTING
        !is_header        TYPE zi_intercoproposal
      EXPORTING
        !ev_purchaseorder TYPE ebeln .
    CLASS-METHODS call_bapi_mock
      IMPORTING
        !is_header        TYPE zi_intercoproposal OPTIONAL
      EXPORTING
        !ev_purchaseorder TYPE ebeln .
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_mm_create_po .

    METHODS mapping_data_po
      IMPORTING
        !is_header TYPE zi_intercoproposal
        !is_item   TYPE zfi_proposalitem_add .
ENDCLASS.



CLASS zcl_mm_create_po IMPLEMENTATION.


  METHOD call_bapi_po_create.


*    DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
*    DATA lv_product              TYPE zfi_proposalitem_add-product.
*    DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
*    DATA lv_flow                 TYPE zfi_proposalitem_add-flow.
*
*    DATA: ls_poheader   TYPE bapimepoheader,
*          ls_poheaderx  TYPE bapimepoheaderx,
*          lt_poitem     TYPE STANDARD TABLE OF bapimepoitem,
*          ls_poitem     TYPE bapimepoitem,
*          lt_POITEMX    TYPE STANDARD TABLE OF bapimepoitemx,
*          ls_poitemx    TYPE bapimepoitemx,
*          lt_poaccount  TYPE STANDARD TABLE OF bapimepoaccount,
*          ls_poaccount  TYPE bapimepoaccount,
*          lt_POACCOUNTX TYPE STANDARD TABLE OF bapimepoaccountx,
*          ls_POACCOUNTX TYPE bapimepoaccountx,
*          lt_POCOND     TYPE STANDARD TABLE OF bapimepocond,
*          ls_POCOND     TYPE bapimepocond,
*          lt_pOCONDX    TYPE STANDARD TABLE OF bapimepocondx,
*          ls_pOCONDX    TYPE bapimepocondx.
*
*    LOOP AT it_items INTO DATA(ls_items).
*      " Verifico si corresponde nueva cabecera e inicializacion de items.
*      IF lv_providercompanycode <> ls_items-providercompanycode   OR
*         lv_product <> ls_items-product                           OR
*         lv_recipientcompanycode <> ls_items-recipientcompanycode OR
*         lv_flow <> ls_items-flow.
*        lv_providercompanycode  = ls_items-providercompanycode.
*        lv_product              = ls_items-product.
*        lv_recipientcompanycode = ls_items-recipientcompanycode.
*        lv_flow                 = ls_items-flow.
*
*        IF ls_poheader IS NOT INITIAL AND
*           lt_poitem[] IS NOT INITIAL.

    "Call Bapi
*          CALL FUNCTION 'BAPI_PO_CREATE1' DESTINATION 'NONE'
*            EXPORTING
*              poheader         = ls_poheader
*              poheaderx        = ls_poheaderx
*              no_price_from_po = abap_true
*            IMPORTING
*              exppurchaseorder = ev_purchaseorder
*            TABLES
*              return           = et_return
*              poitem           = lt_poitem
*              poitemx          = lt_poitemx
*              poaccount        = lt_poaccount
*              poaccountx       = lt_poaccountx
*              pocond           = lt_pocond
*              pocondx          = lt_pocondx.

*          IF ev_purchaseorder IS NOT INITIAL.
**        supplier_inv( ).  "Genera Factura
*          ENDIF.
**
*          FREE: ls_poheader,
*                lt_poitem,
*                lt_poaccount,
*                lt_POCOND.
*
*
*
*
*        ENDIF.
*      ENDIF.
*    ENDLOOP.


  ENDMETHOD.


  METHOD get_instance.

    ro_instance = COND #( WHEN zcl_mm_create_po=>go_instance IS BOUND
                           THEN zcl_mm_create_po=>go_instance
                         ELSE NEW zcl_mm_create_po(  )  ).
    go_instance = ro_instance.

  ENDMETHOD.


  METHOD call_bapi_mock.

***    "BAPI_PO_CHANGE Agregar condiciones de precios
***
***    DATA: lt_POCOND  TYPE STANDARD TABLE OF bapimepocond,
***          ls_POCOND  TYPE bapimepocond,
***          lt_pOCONDX TYPE STANDARD TABLE OF bapimepocondx,
***          ls_pOCONDX TYPE bapimepocondx,
***          lt_return  TYPE STANDARD TABLE OF bapiret2.
***
***    "Pricing
***    ls_POCOND-itm_number = '000010'.
***    ls_POCOND-cond_type  = 'ZBAS'.
***    ls_POCOND-cond_value  = '21227.03'.
***    ls_pocond-currenckey  = 'USD'.
***    ls_pocond-change_id   = 'I'.
***    APPEND ls_POCOND TO lt_pocond.
***
***    ls_POCOND-itm_number = '000010'.
***    ls_POCOND-cond_type  = 'ZMUP'.
***    ls_POCOND-cond_value  = '1698.16'.
***    ls_pocond-currenckey  = 'USD'.
***    ls_pocond-change_id   = 'I'.
***    APPEND ls_POCOND TO lt_pocond.
***
***    ls_pOCONDX-itm_number = '000010'.
***    ls_pOCONDX-itm_numberx = abap_true.
***    ls_pOCONDX-condtype    = ABap_true.
***    ls_pOCONDX-cond_value  = abap_true.
***    ls_pOCONDX-currency    = abap_true.
***    APPEND ls_pocondx TO lt_pocondx.
***
***    ls_pOCONDX-itm_number = '000010'.
***    ls_pOCONDX-itm_numberx = abap_true.
***    ls_pOCONDX-condtype    = ABap_true.
***    ls_pOCONDX-cond_value  = abap_true.
***    ls_pOCONDX-currency    = abap_true.
***    APPEND ls_pocondx TO lt_pocondx.
***
***    CALL FUNCTION 'BAPI_PO_CHANGE' DESTINATION 'NONE'
***      EXPORTING
***        purchaseorder = '4700001015'
***      TABLES
***        return        = lt_return
***        pocond        = lt_pocond
***        pocondx       = lt_pocondx.
**********************************************************************
***    DATA: ls_poheader   TYPE bapimepoheader,
***          ls_poheaderx  TYPE bapimepoheaderx,
***          lt_poitem     TYPE STANDARD TABLE OF bapimepoitem,
***          ls_poitem     TYPE bapimepoitem,
***          lt_POITEMX    TYPE STANDARD TABLE OF bapimepoitemx,
***          ls_poitemx    TYPE bapimepoitemx,
***          lt_poaccount  TYPE STANDARD TABLE OF bapimepoaccount,
***          ls_poaccount  TYPE bapimepoaccount,
***          lt_POACCOUNTX TYPE STANDARD TABLE OF bapimepoaccountx,
***          ls_POACCOUNTX TYPE bapimepoaccountx,
***          lt_POCOND     TYPE STANDARD TABLE OF bapimepocond,
***          ls_POCOND     TYPE bapimepocond,
***          lt_pOCONDX    TYPE STANDARD TABLE OF bapimepocondx,
***          ls_pOCONDX    TYPE bapimepocondx.
***
***    "Header
***    ls_poheader-comp_code = 'DRM'.
***    ls_poheader-doc_type  = 'ZINT'.
***    ls_poheader-vendor    = 'IC0145'.
***    ls_poheader-purch_org = 'IDRM'.
***    ls_poheader-pur_group = 'ZIC'.
***    ls_poheader-currency  = 'USD'.
***    ls_poheader-doc_date  = '20240228'.
***    ls_poheaderx-comp_code    = abap_true.
***    ls_poheaderx-doc_type     = abap_true.
***    ls_poheaderx-created_by   = abap_true.
***    ls_poheaderx-vendor       = abap_true.
***    ls_poheaderx-purch_org    = abap_true.
***    ls_poheaderx-pur_group    = abap_true.
***    ls_poheaderx-currency     = abap_true.
***    ls_poheaderx-doc_date     = abap_true.
***
***    "Items
***    ls_poitem-po_item   = '00010'.
****    ls_poitem-material  = 'ICSRV17'.
***    ls_poitem-material_external = 'ICSRV17'.
***    ls_poitem-plant     = 'IDRM'.
***    ls_poitem-quantity  = '100'.
***    ls_poitem-net_price    = '22925.19'.
***    ls_poitem-price_unit   = '100'.
***    ls_poitem-item_cat     = '0'.
***    ls_poitem-acctasscat   = 'K'.
***    ls_poitem-distrib      = '3'.
***    ls_poitem-part_inv     = '2'.
***    ls_poitem-ir_ind       = abap_true.
***    ls_poitem-no_rounding  = abap_true.
***    APPEND ls_poitem TO lt_poitem.
***    ls_poitemx-po_item       = '00010'.
***    ls_poitemx-po_itemx      = abap_true.
****    ls_poitemx-material      = abap_true.
***    ls_poitemx-material_external = abap_true.
***    ls_poitemx-plant         = abap_true.
***    ls_poitemx-quantity      = abap_true.
***    ls_poitemx-net_price     = abap_true.
***    ls_poitemx-price_unit    = abap_true.
***    ls_poitemx-item_cat      = abap_true.
***    ls_poitemx-acctasscat    = abap_true.
***    ls_poitemx-distrib       = abap_true.
***    ls_poitemx-part_inv      = abap_true.
***    ls_poitemx-gr_ind        = abap_true.
***    ls_poitemx-ir_ind        = abap_true.
***    ls_poitemx-gr_basediv    = abap_true.
***    ls_poitemx-no_rounding   = abap_true.
***    APPEND ls_poitemx TO lt_poitemx.
***
***    "Accounting
***    ls_poaccount-po_item    = '00010'.
***    ls_poaccount-serial_no  = '01'.
***    ls_poaccount-net_value  = '21227.03'.
***    ls_poaccount-gl_account = '693141'.
***    ls_poaccount-costcenter = '9541108100'.
***    APPEND ls_poaccount TO lt_poaccount.
***    ls_poaccountx-po_item    = '00010'.
***    ls_poaccountx-serial_no  = '01'.
***    ls_poaccountx-net_value  = abap_true.
***    ls_poaccountx-gl_account = abap_true.
***    ls_poaccountx-costcenter = abap_true.
***    APPEND ls_poaccountx TO lt_poaccountx.
***
***    ls_poaccount-po_item    = '00010'.
***    ls_poaccount-serial_no  = '02'.
***    ls_poaccount-net_value  = '1698.16'.
***    ls_poaccount-gl_account = '693142'.
***    ls_poaccount-costcenter = '9541108100'.
***    APPEND ls_poaccount TO lt_poaccount.
***    ls_poaccountx-po_item    = '00010'.
***    ls_poaccountx-serial_no  = '02'.
***    ls_poaccountx-net_value  = abap_true.
***    ls_poaccountx-gl_account = abap_true.
***    ls_poaccountx-costcenter = abap_true.
***    APPEND ls_poaccountx TO lt_poaccountx.
***
***    "Pricing
***    ls_POCOND-itm_number = '000010'.
***    ls_POCOND-cond_type  = 'ZBAS'.
***    ls_POCOND-cond_value  = '21227.03'.
***    APPEND ls_POCOND TO lt_pocond.
***
***    ls_POCOND-itm_number = '000010'.
***    ls_POCOND-cond_type  = 'ZMUP'.
***    ls_POCOND-cond_value  = '1698.16'.
***    APPEND ls_POCOND TO lt_pocond.

***    CALL FUNCTION 'BAPI_PO_CREATE1' DESTINATION 'NONE' "#EC CI_USAGE_OK[2438131]
***      EXPORTING
***        poheader         = ls_poheader
***        poheaderx        = ls_poheaderx
***        no_price_from_po = abap_true
***      IMPORTING
***        exppurchaseorder = ev_purchaseorder
***      TABLES
***        return           = et_return
***        poitem           = lt_poitem
***        poitemx          = lt_poitemx
***        poaccount        = lt_poaccount
***        poaccountx       = lt_poaccountx
***        pocond           = lt_pocond
***        pocondx          = lt_pocondx.
  ENDMETHOD.


  METHOD mapping_data_po.
  ENDMETHOD.
ENDCLASS.
