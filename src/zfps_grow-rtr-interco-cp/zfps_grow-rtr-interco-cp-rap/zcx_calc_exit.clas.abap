CLASS zcx_calc_exit DEFINITION
  PUBLIC
  INHERITING FROM cx_sadl_exit
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF entity_not_known,
        msgid TYPE symsgid VALUE '<MY_MESSAGE_ID>',
        msgno TYPE symsgno VALUE '<MY_MESSAGE_NR>',
        attr1 TYPE scx_attrname VALUE '<ATTR1>',
        attr2 TYPE scx_attrname VALUE '<ATTR2>',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF entity_not_known .
    CONSTANTS:
      BEGIN OF error_generating_documents,
        msgid TYPE symsgid VALUE 'ZINT_MSG_INTERCO_CP',
        msgno TYPE symsgno VALUE '018',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF error_generating_documents .
    CONSTANTS:
      BEGIN OF error_canceling_documents,
        msgid TYPE symsgid VALUE 'ZINT_MSG_INTERCO_CP',
        msgno TYPE symsgno VALUE '019',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF error_canceling_documents.
*Ini EXT_OSCUGALD - Sin configuración de Flujo
    CONSTANTS:
      BEGIN OF flow_config_not_found,
        msgid TYPE symsgid    VALUE 'ZINT_MSG_INTERCO_CP',
        msgno TYPE symsgno    VALUE '031',
        attr1 TYPE scx_attrname VALUE 'MV_PROVIDER',
        attr2 TYPE scx_attrname VALUE 'MV_RECIPIENT',
        attr3 TYPE scx_attrname VALUE 'MV_PRODUCT',
        attr4 TYPE scx_attrname VALUE 'MV_PROFITCENTER',
      END OF flow_config_not_found.

    DATA mv_provider     TYPE bukrs.
    DATA mv_recipient    TYPE bukrs.
    DATA mv_product      TYPE matnr.
    DATA mv_profitcenter TYPE prctr.
*Fin
    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .

    METHODS constructor
      IMPORTING
        !textid          LIKE if_t100_message=>t100key OPTIONAL
        !previous        LIKE previous OPTIONAL
*Ini EXT_OSCUGALD - Sin configuración de Flujo
        !mv_provider     TYPE bukrs OPTIONAL
        !mv_recipient    TYPE bukrs OPTIONAL
        !mv_product      TYPE matnr OPTIONAL
        !mv_profitcenter TYPE prctr OPTIONAL.
*Fin
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_calc_exit IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
*Ini EXT_OSCUGALD - Sin configuración de Flujo
    " Atributos para sustitución dinámica de mensaje 031
    me->mv_provider     = mv_provider.
    me->mv_recipient    = mv_recipient.
    me->mv_product      = mv_product.
    me->mv_profitcenter = mv_profitcenter.
*Fin
  ENDMETHOD.
ENDCLASS.
