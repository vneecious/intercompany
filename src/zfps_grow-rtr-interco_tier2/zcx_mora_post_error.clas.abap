CLASS zcx_mora_post_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA mv_bukrs    TYPE bukrs.
    DATA mv_vbund    TYPE vbund.
    DATA mv_doc_type TYPE blart.
    DATA mv_msg_text TYPE string.
    DATA mt_return   TYPE bapiret2_t.

    METHODS constructor
      IMPORTING
        !previous    LIKE previous    OPTIONAL
        !iv_bukrs    TYPE bukrs       OPTIONAL
        !iv_vbund    TYPE vbund       OPTIONAL
        !iv_doc_type TYPE blart       OPTIONAL
        !iv_msg_text TYPE string      OPTIONAL
        !it_return   TYPE bapiret2_t  OPTIONAL.

    METHODS get_return_messages
      RETURNING
        VALUE(rt_return) TYPE bapiret2_t.

    METHODS get_error_text
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcx_mora_post_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.
    mv_bukrs    = iv_bukrs.
    mv_vbund    = iv_vbund.
    mv_doc_type = iv_doc_type.
    mv_msg_text = iv_msg_text.
    mt_return   = it_return.
  ENDMETHOD.

  METHOD get_return_messages.
    rt_return = mt_return.
  ENDMETHOD.

  METHOD get_error_text.
    IF mv_msg_text IS NOT INITIAL.
      rv_text = mv_msg_text.
    ELSE.
      rv_text = |Error al contabilizar. BUKRS={ mv_bukrs } VBUND={ mv_vbund } DocType={ mv_doc_type }|.
    ENDIF.
    LOOP AT mt_return INTO DATA(ls_ret)
      WHERE type = 'E' OR type = 'A'.
      rv_text = rv_text && | | && ls_ret-message.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
