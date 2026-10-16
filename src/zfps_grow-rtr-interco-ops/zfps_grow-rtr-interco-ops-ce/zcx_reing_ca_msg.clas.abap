*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
* Date           : 09.09.2026
* Description    : CA - Mensaje RAP de texto largo (fixes-011)
* Transport      : DS4K9B5XZC
* Reference      : 5000049390
*----------------------------------------------------------------------*
* Begin Change ID V001 (09.09.2026 | EXT_GONZALCA)
* Reemplaza a cl_abap_behv=>new_message_with_text en las 20 llamadas de
* ZBP_REINGCARUN, que llegaban al frontend CORTADAS a 50 caracteres.
*
* Causa raiz del corte (verificada en el estandar):
*   method NEW_MESSAGE_WITH_TEXT.
*     obj = new_message( id = 'SABP_BEHV' number = 100 v1 = text ).
*   endmethod.
* y el mensaje SABP_BEHV/100 es literalmente "&1": UN solo placeholder.
* v1 aterriza en IF_T100_DYN_MSG~MSGV1, de tipo SYMSGV = CHAR50.
*
* Por que una clase de excepcion y no una clase utilitaria normal:
* CL_ABAP_BEHV=>NEW_MESSAGE y NEW_MESSAGE_WITH_TEXT son metodos de
* instancia PROTECTED de una clase CREATE PROTECTED, asi que solo los
* alcanza algo que herede de CL_ABAP_BEHV -- los handler/saver del pool de
* comportamiento. Una clase global no puede llamarlos. En cambio SI puede
* CONSTRUIR el objeto de mensaje: IF_ABAP_BEHV_MESSAGE incluye IF_MESSAGE,
* IF_T100_DYN_MSG e IF_T100_MESSAGE, de modo que una clase de excepcion que
* lo implemente es un %msg valido. Es la misma forma que tiene la clase
* local LCL_ABAP_BEHV_MSG de CL_ABAP_BEHV, incluido el truco de poblar
* attr1..attr4 solo cuando el tramo correspondiente no esta vacio.
*
* El mensaje propio ZREING_CA/001 es "&1 &2 &3 &4" -> 4 x 50 = 200
* caracteres utiles. Alcanzan: SIM_MESSAGE en ZREING_CA_LINE_A es CHAR220 y
* los textos reales rondan 60-90.
*
* Se usa la ruta T100 + MSGV1..4, NO una redefinicion de GET_TEXT: asi no
* dependemos de si el serializador OData V4 llama get_text( ) o reconstruye
* el texto desde T100, que es la duda que dejo descartada esa alternativa.
* End Change ID V001 (09.09.2026 | EXT_GONZALCA)
*----------------------------------------------------------------------*
CLASS zcx_reing_ca_msg DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_abap_behv_message.

    ALIASES msgty FOR if_t100_dyn_msg~msgty.
    ALIASES msgv1 FOR if_t100_dyn_msg~msgv1.
    ALIASES msgv2 FOR if_t100_dyn_msg~msgv2.
    ALIASES msgv3 FOR if_t100_dyn_msg~msgv3.
    ALIASES msgv4 FOR if_t100_dyn_msg~msgv4.

    CONSTANTS:
      BEGIN OF long_text,
        msgid TYPE symsgid VALUE 'ZREING_CA',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV1',
        attr2 TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV2',
        attr3 TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV3',
        attr4 TYPE scx_attrname VALUE 'IF_T100_DYN_MSG~MSGV4',
      END OF long_text.

    TYPES: BEGIN OF ty_parts,
             v1 TYPE symsgv,
             v2 TYPE symsgv,
             v3 TYPE symsgv,
             v4 TYPE symsgv,
           END OF ty_parts.

    "! Fabrica. Sustituto directo de new_message_with_text: mismos nombres de
    "! parametro (severity / text), asi el cambio en cada punto de llamada es
    "! el reemplazo de un unico token.
    CLASS-METHODS new
      IMPORTING severity   TYPE if_abap_behv_message=>t_severity
                             DEFAULT if_abap_behv_message=>severity-error
                text       TYPE csequence OPTIONAL
      RETURNING VALUE(obj) TYPE REF TO if_abap_behv_message.

    "! Parte un texto en 4 tramos de 50 cortando en el ultimo espacio que
    "! entra en el tramo. Publico y puro a proposito: es la logica con bordes
    "! y se cubre con ABAP Unit sin construir mensajes.
    CLASS-METHODS split
      IMPORTING text            TYPE csequence
      RETURNING VALUE(rs_parts) TYPE ty_parts.

    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL
                msgty    TYPE symsgty OPTIONAL
                msgv1    TYPE symsgv OPTIONAL
                msgv2    TYPE symsgv OPTIONAL
                msgv3    TYPE symsgv OPTIONAL
                msgv4    TYPE symsgv OPTIONAL.

  PRIVATE SECTION.
    CONSTANTS c_chunk TYPE i VALUE 50.
ENDCLASS.


CLASS zcx_reing_ca_msg IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING previous = previous.
    me->msgty = msgty.
    me->msgv1 = msgv1.
    me->msgv2 = msgv2.
    me->msgv3 = msgv3.
    me->msgv4 = msgv4.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = long_text.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.


  METHOD new.
    DATA(ls_parts) = split( text ).

    " attr1..attr4 se pueblan SOLO cuando el tramo trae contenido. Es el mismo
    " criterio de CL_ABAP_BEHV=>NEW_MESSAGE: son los nombres de atributo que
    " CX_ROOT usa para resolver &1..&4, y apuntar a un atributo vacio deja
    " basura en el texto renderizado.
    DATA(lo_msg) = NEW zcx_reing_ca_msg(
      textid = VALUE #(
                 msgid = long_text-msgid
                 msgno = long_text-msgno
                 attr1 = COND #( WHEN ls_parts-v1 IS NOT INITIAL THEN long_text-attr1 )
                 attr2 = COND #( WHEN ls_parts-v2 IS NOT INITIAL THEN long_text-attr2 )
                 attr3 = COND #( WHEN ls_parts-v3 IS NOT INITIAL THEN long_text-attr3 )
                 attr4 = COND #( WHEN ls_parts-v4 IS NOT INITIAL THEN long_text-attr4 ) )
      msgty  = SWITCH #( severity
                 WHEN if_abap_behv_message=>severity-error       THEN 'E'
                 WHEN if_abap_behv_message=>severity-warning     THEN 'W'
                 WHEN if_abap_behv_message=>severity-information THEN 'I'
                 WHEN if_abap_behv_message=>severity-success     THEN 'S'
                 ELSE 'E' )
      msgv1  = ls_parts-v1
      msgv2  = ls_parts-v2
      msgv3  = ls_parts-v3
      msgv4  = ls_parts-v4 ).

    lo_msg->if_abap_behv_message~m_severity = severity.
    obj = lo_msg.
  ENDMETHOD.


  METHOD split.
    DATA lv_rest TYPE string.
    DATA lv_head TYPE string.
    DATA lv_pos  TYPE i.
    DATA lv_take TYPE i.
    DATA lv_skip TYPE i.

    lv_rest = text.

    DO 4 TIMES.
      IF lv_rest IS INITIAL.
        EXIT.
      ENDIF.

      IF strlen( lv_rest ) <= c_chunk.
        lv_take = strlen( lv_rest ).
        lv_skip = lv_take.
      ELSE.
        " Un caracter MAS que el tramo: si en esa ventana hay un espacio, el
        " ultimo sirve de punto de corte limpio y se descarta (el mensaje
        " ZREING_CA/001 lo reinyecta como separador entre &N).
        lv_head = substring( val = lv_rest off = 0 len = c_chunk + 1 ).
        lv_pos  = find( val = lv_head sub = ` ` occ = -1 ).
        IF lv_pos > 0.
          lv_take = lv_pos.
          lv_skip = lv_pos + 1.
        ELSE.
          " Palabra unica mas larga que el tramo: no hay corte limpio posible.
          lv_take = c_chunk.
          lv_skip = c_chunk.
        ENDIF.
      ENDIF.

      CASE sy-index.
        WHEN 1. rs_parts-v1 = substring( val = lv_rest off = 0 len = lv_take ).
        WHEN 2. rs_parts-v2 = substring( val = lv_rest off = 0 len = lv_take ).
        WHEN 3. rs_parts-v3 = substring( val = lv_rest off = 0 len = lv_take ).
        WHEN 4. rs_parts-v4 = substring( val = lv_rest off = 0 len = lv_take ).
      ENDCASE.

      lv_rest = substring( val = lv_rest off = lv_skip ).
    ENDDO.
  ENDMETHOD.

ENDCLASS.
